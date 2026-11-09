extends Node2D
## Runs a match. Offline practice and network matches share one flow (PLAN.md D.1):
## the authority (host, or this computer in practice) simulates every player from inputs
## and sends snapshots; clients predict their own movement and interpolate opponents.
## Network matches: countdown, lives, elimination, winner -> results -> same lobby (T.1).
## Practice: endless lives and no countdown. The client side lives in MatchClient.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"
const LOBBY_PATH := "res://src/ui/lobby.tscn"
const RESULTS_PATH := "res://src/ui/results.tscn"
## Pause between the deciding fall and the results screen.
const RESULTS_DELAY := 1.5
## Host waits this long before leaving the match scene (see _on_session_phase_changed).
const SCENE_CHANGE_GRACE := 0.5
## A snapshot every physics tick (60 Hz): lower latency and smoother remote players
## (~4-14 kB/s per client).
const SNAPSHOT_EVERY_TICKS := 1
## Peer id of the practice dummy (real peer ids are always positive).
const PRACTICE_DUMMY_ID := -1
## Host: client-controlled players are drawn at least this far behind their simulation
## (their inputs can arrive in bunches; hits always use the real position).
const HOST_DISPLAY_MIN_DELAY_MS := 20.0

var _arena: Arena
var _weapons := WeaponSystem.new()
var _abilities := AbilitySystem.new()
var _effects := AreaEffects.new()
var _score := MatchScore.new()
var _rules: MatchRules = ContentDB.match_rules()
var _networked := false
var _is_authority := true
## peer_id -> Player
var _players: Dictionary[int, Player] = {}
var _tick := 0
## Seconds before players may move (authority); whole seconds shown on clients.
var _countdown := 0.0
var _countdown_display := 0
var _match_over := false
## Set once the scene switch to results/lobby is scheduled (only one may run).
var _leaving := false
## Authority: peer ids in the order they ran out of lives (for the ranking).
var _elimination_order: Array[int] = []

# Authority: inputs received from clients, peer_id -> InputBuffer.
var _inputs: Dictionary[int, InputBuffer] = {}
## Network clients only: prediction, input sending and snapshots.
var _client: MatchClient
## Practice only: walks the target around without letting it fall off on its own.
var _dummy: PracticeDummy
## Rising lava of the arena (Peklo), or null.
var _lava: Lava
var _net_log := NetLog.new()

@onready var _net: Node = $MatchNet
@onready var _hud: MatchHud = $Hud/MatchHud


func _ready() -> void:
	_networked = Session.phase == Session.Phase.IN_MATCH
	_arena = ContentDB.arena_or_default(Session.arena_id if _networked else Settings.practice_arena).scene.instantiate()
	add_child(_arena)
	_lava = _arena.lava()
	if _lava:
		_lava.started_rising.connect(func() -> void: _hud.show_alert(tr("LAVA_RISING")))
	add_child(_weapons)
	_weapons.setup(_net if _networked else null)
	add_child(_effects)
	_weapons.player_hit.connect(_on_player_hit)
	_abilities.player_hit.connect(_on_player_hit)
	_effects.player_blown.connect(_on_player_hit)  # a fall after Krügermann's gas counts for him
	_is_authority = not _networked or multiplayer.is_server()
	_effects.setup(_net if _networked else null, _is_authority)
	if _networked and not _is_authority:  # own shots are predicted on clients
		_weapons.local_slot = Session.match_slots.get(multiplayer.get_unique_id(), -1)
		_client = MatchClient.new(_players, multiplayer.get_unique_id(), _net, _weapons, _net_log)
	if _networked:
		for peer_id: int in Session.match_slots:
			_spawn(peer_id, Session.match_slots[peer_id], Session.players.get(peer_id, {}).get("name", "?"))
		for player in _players.values():
			player.lives = _rules.lives
		_countdown = _rules.countdown_seconds
		Session.players_changed.connect(_remove_departed_players)
		_remove_departed_players()  # someone may have left while the match scene was loading
		Session.phase_changed.connect(_on_session_phase_changed)
		Session.ended.connect(func(_message: String) -> void: get_tree().change_scene_to_file.call_deferred(MAIN_MENU_PATH))
		_net.input_received.connect(_on_input_received)
		if _client:
			_net.snapshot_received.connect(_client.receive_snapshot)
			_net_log.client_extra = _client.interpolation_text
		_net.kill_announced.connect(_on_kill_announced)
		_net_log.peer_stats = func(peer_id: int) -> Dictionary: return EnetDirectConnector.peer_stats(multiplayer.multiplayer_peer, peer_id)
		_net_log.traffic = func() -> Dictionary: return EnetDirectConnector.take_traffic(multiplayer.multiplayer_peer)
		EnetDirectConnector.take_traffic(multiplayer.multiplayer_peer)  # start counting with the match
		if _net.lag.is_enabled():
			$Hud/HintLabel.text = tr("DEBUG_FAKE_LAG").format({"lag": _net.lag.rtt_ms, "loss": _net.lag.loss_percent})
	else:
		_spawn(multiplayer.get_unique_id(), 0, Settings.player_name)
		# A practice target: walks around (PracticeDummy), never shoots; only hits knock it off.
		_spawn(PRACTICE_DUMMY_ID, 1, tr("PRACTICE_DUMMY"))
		_dummy = PracticeDummy.new(_players[PRACTICE_DUMMY_ID])


func _spawn(peer_id: int, slot: int, display_name: String) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	var chosen: String = Session.players.get(peer_id, {}).get("character", "") if _networked \
			else (Settings.practice_character if peer_id != PRACTICE_DUMMY_ID else "")
	var character := ContentDB.practice_character(chosen)
	player.setup(character, slot, peer_id, display_name)
	if _networked and Session.team_mode:
		player.set_team(int(Session.players.get(peer_id, {}).get("team", Teams.NONE)))
		_effects.teams[peer_id] = player.team
	player.effects = _effects
	add_child(player)
	var spawns := _arena.spawn_points()
	player.reset_to(spawns[slot % spawns.size()])
	_players[peer_id] = player
	# Remote players get their own playback timeline (RemoteView). On the host this only
	# smooths how client-controlled players are drawn (tiny minimum delay).
	if _networked and peer_id != multiplayer.get_unique_id():
		player.remote_view = RemoteView.new(SnapshotTimeline.new() if not _is_authority else SnapshotTimeline.new(HOST_DISPLAY_MIN_DELAY_MS))


func _physics_process(delta: float) -> void:
	if _networked and Session.phase != Session.Phase.IN_MATCH:
		return
	if _is_authority:
		_simulate_tick(delta)
	elif _client:
		_client.physics_tick(delta)
		_countdown_display = _client.countdown_display
		if _lava and _client.lava_y >= 0:
			_lava.show_level(_client.lava_y)
	var ping := _client.stats.ping_ms() if _client else -1
	_hud.show_state(_players.values(), _countdown_display, _networked)
	_hud.show_ping(ping)
	if _networked:
		var report := _net_log.tick(Time.get_ticks_msec(), _is_authority, Engine.get_frames_per_second(),
				ping, _inputs, _players)
		if not report.is_empty():
			print(report)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if not _networked:
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
	elif Session.is_host():
		Session.return_to_lobby()  # ends the match for everyone, the lobby stays
	else:
		Session.leave()  # Session.ended then returns to the menu


func _on_session_phase_changed(phase: Session.Phase) -> void:
	if (phase != Session.Phase.RESULTS and phase != Session.Phase.LOBBY) or _leaving:
		return
	_leaving = true
	# Packets sent just before the other side learned the match ended may still be on
	# their way; keep MatchNet alive a moment so they do not hit a missing node.
	await get_tree().create_timer(SCENE_CHANGE_GRACE).timeout
	# Use the phase from NOW: it may have moved on (results -> lobby) during the wait.
	if Session.phase == Session.Phase.RESULTS or Session.phase == Session.Phase.LOBBY:
		get_tree().change_scene_to_file.call_deferred(RESULTS_PATH if Session.phase == Session.Phase.RESULTS else LOBBY_PATH)


# --- Authority ---------------------------------------------------------------

func _simulate_tick(delta: float) -> void:
	_tick += 1
	_countdown = maxf(_countdown - delta, 0.0)
	_countdown_display = ceili(_countdown)
	var frozen := _countdown > 0.0
	if _lava and not frozen:
		_lava.tick(_players.values(), _rules.lives, _networked, delta)
	for peer_id in _players:
		var player := _players[peer_id]
		# Read the inputs even while dead, so the queue does not fill up and delay the respawn.
		var inputs := _inputs_for(peer_id, player, delta)
		if not player.visible:
			continue
		for i in inputs.size():  # 0-4 inputs, each simulated exactly once (InputBuffer)
			var input := InputFrame.create(0, 0, inputs[i].aim, inputs[i].seq) if frozen else inputs[i]
			player.simulate(input, delta)
			_weapons.spawn_shot(player, input, inputs.size() - 1 - i)
			_abilities.tick(player, _players.values())
		if not inputs.is_empty() and player.remote_view:
			player.record_for_display()
		player.invulnerable_time = maxf(player.invulnerable_time - delta, 0.0)
		player.invulnerable = player.invulnerable_time > 0.0
		if _lava and _lava.touches(player):
			_on_player_fell(player)  # lava: a life lost at once
		elif _arena.is_out_of_bounds(player.position):
			player.out_of_bounds_time += delta
			if player.out_of_bounds_time >= _rules.out_of_bounds_grace:
				_on_player_fell(player)
		else:
			player.out_of_bounds_time = 0.0
	if _networked:
		_check_match_end()
		if _tick % SNAPSHOT_EVERY_TICKS == 0:
			var states: Array[Dictionary] = []
			for player in _players.values():
				states.append(player.snapshot_state())
			_net.broadcast_snapshot(NetCodec.encode_snapshot(_tick, ceili(_countdown * 10.0), states, roundi(_lava.level) if _lava else -1))


## The inputs to simulate this tick: the local player's own, the practice dummy's, or what
## a client's InputBuffer releases (none while its next input is late).
func _inputs_for(peer_id: int, player: Player, delta: float) -> Array[InputFrame]:
	var inputs: Array[InputFrame] = []
	if peer_id == multiplayer.get_unique_id():
		inputs.append(InputFrame.sample_local(player))
	elif peer_id == PRACTICE_DUMMY_ID:
		inputs.append(_dummy.next_input(delta))
	else:
		inputs = _inputs.get_or_add(peer_id, InputBuffer.new()).take_for_tick()
	return inputs


func _on_input_received(peer_id: int, frames: Array[InputFrame]) -> void:
	if Session.phase != Session.Phase.IN_MATCH or not _players.has(peer_id):
		return
	_inputs.get_or_add(peer_id, InputBuffer.new()).push(frames)


func _on_player_fell(player: Player) -> void:
	if not _match_over:
		var event := _score.record_death(player, _players, Time.get_ticks_msec())
		if event.killer_slot >= 0:
			_on_kill_announced(event.killer_slot, event.streak)
			if _networked:
				_net.send_kill_announced(event.killer_slot, event.streak)
	player.set_active(false)
	if _networked:
		DiagLog.event("match", "fall slot%d lives_left=%d" % [player.slot, player.lives - 1])
		player.lives -= 1
		if player.lives <= 0:
			_elimination_order.append(player.peer_id)
			return
	_respawn_later(player)


func _on_player_hit(attacker_peer_id: int, victim: Player) -> void:
	if not _match_over:
		_score.record_hit(_players.get(attacker_peer_id), victim)


func _on_kill_announced(killer_slot: int, streak: int) -> void:
	if _networked:
		DiagLog.event("match", "kill by slot%d streak=%d" % [killer_slot, streak])
	for player in _players.values():
		if player.slot == killer_slot:
			var popup := KillPopup.new()
			popup.setup(streak)
			player.add_child(popup)
			return


func _respawn_later(player: Player) -> void:
	await get_tree().create_timer(_rules.respawn_delay).timeout
	if not is_instance_valid(player) or _match_over:
		return
	var occupied: Array[Vector2] = []
	for other: Player in _players.values():
		if other.visible:
			occupied.append(other.position)
	player.reset_to(_arena.free_spawn_point(occupied, _lava.safe_feet_y() if _lava else INF))
	player.invulnerable_time = _rules.respawn_invulnerability
	player.invulnerable = true
	player.set_active(true)


## The match ends when at most one player (2 v 2: one team) has lives left, also if the
## others left.
func _check_match_end() -> void:
	if _match_over:
		return
	var alive := _players.values().filter(func(player: Player) -> bool: return player.lives > 0)
	if not MatchRanking.is_decided(alive, Session.team_mode):
		return
	_match_over = true
	var eliminated: Array = []
	for peer_id in _elimination_order:
		if _players.has(peer_id):
			eliminated.append(_players[peer_id])
	var results := MatchRanking.results(alive, eliminated, Session.team_mode)
	await get_tree().create_timer(RESULTS_DELAY).timeout
	Session.end_match(results)


# --- Both ------------------------------------------------------------------------

func _remove_departed_players() -> void:
	for peer_id in _players.keys():
		if not Session.players.has(peer_id):
			_score.remove_player(peer_id)
			_players[peer_id].queue_free()
			_players.erase(peer_id)
			_inputs.erase(peer_id)
