class_name MatchClient
extends RefCounted
## Client side of a network match (M4): every physics tick it reconciles the own player
## with the newest host snapshot, then predicts the own input at once (ClientPrediction)
## and sends it with the recent history (redundancy against packet loss), and predicts the
## hits of other players' bullets on the own player (HitPrediction). Remote players get
## EVERY snapshot for smooth playback (RemoteView). Used by MatchController.

## Whole seconds of the countdown, from the newest snapshot.
var countdown_display := 0
## Lava surface from the newest snapshot (-1 = no lava on this arena).
var lava_y := -1
var stats := NetStats.new()
## The match's arena: moving platforms are shown where the own player meets them.
var arena: Arena
## Newest snapshot, applied on the next physics tick (see physics_tick).
var pending_snapshot: Dictionary = {}
var last_snapshot_tick := -1

var _players: Dictionary[int, Player]
var _local_peer_id := 0
var _net: Node
var _weapons: WeaponSystem
var _net_log: NetLog
var _input_seq := 0
## Own input history, newest first.
var _input_history: Array[InputFrame] = []
var _prediction := ClientPrediction.new()
var _hits := HitPrediction.new()
## From this time (msec) the own movement is predicted, see _apply_snapshot.
var _movement_starts_ms := 0
## Host tick of the newest snapshot and the own input it had processed last (tick_for).
var _base_tick := 0
var _base_seq := 0


## players is the match's live peer_id -> Player dictionary; net is MatchNet.
func _init(players: Dictionary[int, Player], local_peer_id: int, net: Node, weapons: WeaponSystem, net_log: NetLog) -> void:
	_players = players
	_local_peer_id = local_peer_id
	_net = net
	_weapons = weapons
	_net_log = net_log
	if _weapons:
		_weapons.remote_shot_spawned.connect(_on_remote_shot)
	if _net:
		_net.projectile_removed.connect(_hits.on_removed)
		_net.hit_confirmed.connect(_hits.on_confirmed)


## move_and_slide() uses the engine physics delta, so the replay must run on a physics tick.
func physics_tick(delta: float) -> void:
	if not pending_snapshot.is_empty():
		_apply_snapshot(pending_snapshot)
		pending_snapshot = {}
	_send_local_input(delta)


func receive_snapshot(snapshot: Dictionary) -> void:
	if Session.phase != Session.Phase.IN_MATCH:
		return
	var tick: int = snapshot.tick
	if last_snapshot_tick >= 0 and (tick == last_snapshot_tick or ((tick - last_snapshot_tick) & 0xFFFFFFFF) >= 0x80000000):
		_net_log.record_snapshot_dropped()
		return
	last_snapshot_tick = tick
	var now := Time.get_ticks_msec()
	_net_log.record_snapshot_arrival(now)
	# Remote players get EVERY snapshot (a bunch keeps all its positions); the own player
	# is reconciled with the newest one on the next physics tick. Ping counts from arrival.
	for state: Dictionary in snapshot.states:
		for player in _players.values():
			if player.slot == state.slot:
				if player.peer_id == _local_peer_id:
					stats.record_ack(state.last_seq, now)
				else:
					player.receive_state(state, SnapshotTimeline.tick_ms(tick))
	pending_snapshot = snapshot


## Diagnostics: display delay / measured jitter of each remote player's timeline.
func interpolation_text() -> String:
	var parts: PackedStringArray = []
	for player: Player in _players.values():
		if player.remote_view and player.remote_view.timeline:
			var timeline := player.remote_view.timeline
			parts.append("slot%d:%d/%d" % [player.slot, timeline.delay_ms, timeline.clock.jitter_ms()])
	return "interp_ms(delay/jitter) " + " ".join(parts)


## Inputs start with the first snapshot: only then is the host's match scene (MatchNet)
## loaded, so no input arrives at a missing node (log noise with 6 players starting at once).
## Nobody moves during the countdown anyway.
func _send_local_input(delta: float) -> void:
	var local_player: Player = _players.get(_local_peer_id)
	if local_player == null or last_snapshot_tick < 0:
		return
	_input_seq = (_input_seq + 1) & 0xFFFF
	var frame := InputFrame.sample_local(local_player)
	frame.seq = _input_seq
	frame.tick = tick_for(_input_seq)
	if _prediction.predict(local_player, frame, delta, Time.get_ticks_msec() < _movement_starts_ms):
		if local_player.fired_this_tick:
			_weapons.spawn_predicted(local_player, frame)  # the shot appears now, the host confirms it later
		_predict_hits(local_player)
	_input_history.push_front(frame)
	if _input_history.size() > NetCodec.INPUT_HISTORY:
		_input_history.pop_back()
	stats.record_input_sent(_input_seq, Time.get_ticks_msec())
	_net.send_input(NetCodec.encode_input(_input_history))
	if arena:  # also while dead, so the platforms keep moving
		arena.place_platforms(tick_for(_input_seq))


## Host tick an own input is (or will be) simulated at: the host takes one input per tick,
## so it is the newest snapshot's tick plus the inputs sent after the one it had processed.
## Used for moving platforms; a host catching up or waiting makes it a tick or two off,
## which the next snapshot corrects.
func tick_for(seq: int) -> int:
	return _base_tick + (((seq - _base_seq + 0x8000) & 0xFFFF) - 0x8000)



## Bullets of other players' hitting the own pending inputs: the knockback starts now (or the
## inputs are replayed from an earlier hit). A replay can move us into another bullet, so
## repeat while new hits turn up.
func _predict_hits(player: Player) -> void:
	for attempt in 4:
		var index := _hits.detect(player, _prediction.history())
		if index < 0:
			return
		_prediction.replay_from(player, index, _hits)


## Another player's bullet (host spawn event with the host tick): remember its path up to
## the first wall for hit prediction.
func _on_remote_shot(id: int, origin: Vector2, direction: Vector2, weapon: WeaponData, tick: int, shooter_slot: int) -> void:
	var me: Player = _players.get(_local_peer_id)
	if me == null or not me.is_inside_tree():
		return
	var team := Teams.NONE
	for player: Player in _players.values():
		if player.slot == shooter_slot:
			team = player.team
	var end := origin + direction.normalized() * weapon.max_range
	var query := PhysicsRayQueryParameters2D.create(origin, end, Projectile.WORLD_MASK)
	var wall := me.get_world_2d().direct_space_state.intersect_ray(query)
	var length := origin.distance_to(wall.position) if not wall.is_empty() else weapon.max_range
	_hits.add_shot(id, origin, direction, weapon, tick, team, length)


func _apply_snapshot(snapshot: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	countdown_display = ceili(snapshot.countdown / 10.0)
	lava_y = snapshot.get("lava", -1)
	# Inputs sent from this time on reach the host after its countdown ended, so predict
	# them as moving (roughly: time left - round trip + half a snapshot interval).
	_movement_starts_ms = now + snapshot.countdown * 100 - maxi(stats.ping_ms(), 0) + 16 if snapshot.countdown > 0 else 0
	for state: Dictionary in snapshot.states:
		for player in _players.values():
			if player.slot == state.slot and player.peer_id == _local_peer_id:
				_base_tick = snapshot.tick
				_base_seq = state.last_seq
				_net_log.record_correction(_prediction.reconcile(player, state, tick_for, _hits, snapshot.tick))
