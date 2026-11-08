class_name MatchClient
extends RefCounted
## Client side of a network match (M4): every physics tick it reconciles the own player
## with the newest host snapshot, then predicts the own input at once (ClientPrediction)
## and sends it with the recent history (redundancy against packet loss). Remote players
## get EVERY snapshot for smooth playback (RemoteView). Used by MatchController.

## Whole seconds of the countdown, from the newest snapshot.
var countdown_display := 0
var stats := NetStats.new()
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
## From this time (msec) the own movement is predicted, see _apply_snapshot.
var _movement_starts_ms := 0


## players is the match's live peer_id -> Player dictionary; net is MatchNet.
func _init(players: Dictionary[int, Player], local_peer_id: int, net: Node, weapons: WeaponSystem, net_log: NetLog) -> void:
	_players = players
	_local_peer_id = local_peer_id
	_net = net
	_weapons = weapons
	_net_log = net_log


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


func _send_local_input(delta: float) -> void:
	var local_player: Player = _players.get(_local_peer_id)
	if local_player == null:
		return
	_input_seq = (_input_seq + 1) & 0xFFFF
	var frame := InputFrame.sample_local(local_player)
	frame.seq = _input_seq
	if _prediction.predict(local_player, frame, delta, Time.get_ticks_msec() < _movement_starts_ms) and local_player.fired_this_tick:
		_weapons.spawn_predicted(local_player, frame)  # the shot appears now, the host confirms it later
	_input_history.push_front(frame)
	if _input_history.size() > NetCodec.INPUT_HISTORY:
		_input_history.pop_back()
	stats.record_input_sent(_input_seq, Time.get_ticks_msec())
	_net.send_input(NetCodec.encode_input(_input_history))


func _apply_snapshot(snapshot: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	countdown_display = ceili(snapshot.countdown / 10.0)
	# Inputs sent from this time on reach the host after its countdown ended, so predict
	# them as moving (roughly: time left - round trip + half a snapshot interval).
	_movement_starts_ms = now + snapshot.countdown * 100 - maxi(stats.ping_ms(), 0) + 16 if snapshot.countdown > 0 else 0
	for state: Dictionary in snapshot.states:
		for player in _players.values():
			if player.slot == state.slot and player.peer_id == _local_peer_id:
				_net_log.record_correction(_prediction.reconcile(player, state))
