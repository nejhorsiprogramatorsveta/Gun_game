extends Node2D
## Runs a match. Offline practice and network matches share one flow (PLAN.md D.1):
## the authority (host, or this computer in practice) simulates every player from inputs
## and sends snapshots; clients predict their own movement and interpolate opponents.
## Network matches: countdown, lives, elimination, winner -> results -> same lobby (T.1).
## Practice: endless lives and no countdown.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"
const LOBBY_PATH := "res://src/ui/lobby.tscn"
const RESULTS_PATH := "res://src/ui/results.tscn"
## Pause between the deciding fall and the results screen.
const RESULTS_DELAY := 1.5
## Host waits this long before leaving the match scene (see _on_session_phase_changed).
const SCENE_CHANGE_GRACE := 0.5
## 60 Hz physics -> 30 Hz snapshots.
const SNAPSHOT_EVERY_TICKS := 2
## Peer id of the practice dummy (real peer ids are always positive).
const PRACTICE_DUMMY_ID := -1

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
## Authority: peer ids in the order they ran out of lives (for the ranking).
var _elimination_order: Array[int] = []

# Authority: inputs received from clients, peer_id -> InputBuffer.
var _inputs: Dictionary[int, InputBuffer] = {}

# Client: own input history (newest first) for redundancy against packet loss.
var _input_seq := 0
var _input_history: Array[InputFrame] = []
var _prediction := ClientPrediction.new()
var _last_snapshot_tick := -1
var _pending_snapshot: Dictionary = {}
var _stats := NetStats.new()
var _net_log := NetLog.new()

@onready var _net: Node = $MatchNet
@onready var _hud: MatchHud = $Hud/MatchHud


func _ready() -> void:
	_networked = Session.phase == Session.Phase.IN_MATCH
	_arena = ContentDB.arena_or_default(Session.arena_id if _networked else Settings.practice_arena).scene.instantiate()
	add_child(_arena)
	add_child(_weapons)
	_weapons.setup(_net if _networked else null)
	add_child(_effects)
	_weapons.player_hit.connect(_on_player_hit)
	_abilities.player_hit.connect(_on_player_hit)
	_is_authority = not _networked or multiplayer.is_server()
	_effects.setup(_net if _networked else null, _is_authority)
	if _networked:
		for peer_id: int in Session.match_slots:
			_spawn(peer_id, Session.match_slots[peer_id], Session.players.get(peer_id, {}).get("name", "?"))
		for player in _players.values():
			player.lives = _rules.lives
		_countdown = _rules.countdown_seconds
		Session.players_changed.connect(_remove_departed_players)
		Session.phase_changed.connect(_on_session_phase_changed)
		Session.ended.connect(func(_message: String) -> void: get_tree().change_scene_to_file.call_deferred(MAIN_MENU_PATH))
		_net.input_received.connect(_on_input_received)
		_net.snapshot_received.connect(_on_snapshot_received)
		_net.kill_announced.connect(_on_kill_announced)
		if _net.lag.is_enabled():
			$Hud/HintLabel.text = tr("DEBUG_FAKE_LAG").format({"lag": _net.lag.rtt_ms, "loss": _net.lag.loss_percent})
	else:
		_spawn(multiplayer.get_unique_id(), 0, Settings.player_name)
		# A practice target: never sends input, so it just stands, falls and gets knocked back.
		_spawn(PRACTICE_DUMMY_ID, 1, tr("PRACTICE_DUMMY"))


func _spawn(peer_id: int, slot: int, display_name: String) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	var chosen: String = Session.players.get(peer_id, {}).get("character", "") if _networked \
			else (Settings.practice_character if peer_id != PRACTICE_DUMMY_ID else "")
	var character := ContentDB.practice_character(chosen)
	player.setup(character, slot, peer_id, display_name)
	player.effects = _effects
	add_child(player)
	var spawns := _arena.spawn_points()
	player.reset_to(spawns[slot % spawns.size()])
	_players[peer_id] = player


func _physics_process(delta: float) -> void:
	if _networked and Session.phase != Session.Phase.IN_MATCH:
		return
	if _is_authority:
		_simulate_tick(delta)
	else:
		if not _pending_snapshot.is_empty():
			_apply_snapshot(_pending_snapshot)
			_pending_snapshot = {}
		_send_local_input(delta)
	_hud.show_state(_players.values(), _countdown_display, _networked)
	_hud.show_ping(_stats.ping_ms() if not _is_authority else -1)
	if _networked:
		var report := _net_log.tick(Time.get_ticks_msec(), _is_authority, Engine.get_frames_per_second(),
				_stats.ping_ms(), _inputs, _players)
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
	if phase != Session.Phase.RESULTS and phase != Session.Phase.LOBBY:
		return
	# Packets sent just before the other side learned the match ended may still be on
	# their way; keep MatchNet alive a moment so they do not hit a missing node.
	await get_tree().create_timer(SCENE_CHANGE_GRACE).timeout
	get_tree().change_scene_to_file.call_deferred(RESULTS_PATH if phase == Session.Phase.RESULTS else LOBBY_PATH)


# --- Authority ---------------------------------------------------------------

func _simulate_tick(delta: float) -> void:
	_tick += 1
	_countdown = maxf(_countdown - delta, 0.0)
	_countdown_display = ceili(_countdown)
	var frozen := _countdown > 0.0
	for peer_id in _players:
		var player := _players[peer_id]
		# Read the input even while dead, so the queue does not fill up and delay the respawn.
		var input := _input_for(peer_id, player)
		if not player.visible:
			continue
		if frozen:
			input = InputFrame.create(0, 0, input.aim, input.seq)  # only aiming during the countdown
		player.simulate(input, delta)
		player.invulnerable_time = maxf(player.invulnerable_time - delta, 0.0)
		player.invulnerable = player.invulnerable_time > 0.0
		_weapons.try_fire(player, input, delta)
		_abilities.tick(player, _players.values())
		if _arena.is_out_of_bounds(player.position):
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
			_net.broadcast_snapshot(NetCodec.encode_snapshot(_tick, _countdown_display, states))


## One input per tick per player; if a client's packet is late, its last input repeats.
func _input_for(peer_id: int, player: Player) -> InputFrame:
	if peer_id == multiplayer.get_unique_id():
		return InputFrame.sample_local(player)
	return _inputs.get_or_add(peer_id, InputBuffer.new()).next()


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
		player.lives -= 1
		if player.lives <= 0:
			_elimination_order.append(player.peer_id)
			return
	_respawn_later(player)


func _on_player_hit(attacker_peer_id: int, victim: Player) -> void:
	if not _match_over:
		_score.record_hit(_players.get(attacker_peer_id), victim)


func _on_kill_announced(killer_slot: int, streak: int) -> void:
	for player in _players.values():
		if player.slot == killer_slot:
			_hud.show_kill(player.display_name, streak)
			return


func _respawn_later(player: Player) -> void:
	await get_tree().create_timer(_rules.respawn_delay).timeout
	if not is_instance_valid(player) or _match_over:
		return
	var occupied: Array[Vector2] = []
	for other: Player in _players.values():
		if other.visible:
			occupied.append(other.position)
	player.reset_to(_arena.free_spawn_point(occupied))
	player.invulnerable_time = _rules.respawn_invulnerability
	player.invulnerable = true
	player.set_active(true)


## The match ends when at most one player has lives left (also if the others left).
func _check_match_end() -> void:
	if _match_over:
		return
	var alive := _players.values().filter(func(player: Player) -> bool: return player.lives > 0)
	if alive.size() > 1:
		return
	_match_over = true
	var ranking: Array = alive
	for i in range(_elimination_order.size() - 1, -1, -1):
		if _players.has(_elimination_order[i]):
			ranking.append(_players[_elimination_order[i]])
	var results: Array = []
	for i in ranking.size():
		results.append({"name": ranking[i].display_name, "place": i + 1, "lives": ranking[i].lives,
				"kills": ranking[i].kills, "deaths": ranking[i].deaths})
	await get_tree().create_timer(RESULTS_DELAY).timeout
	Session.end_match(results)


# --- Client --------------------------------------------------------------------

func _send_local_input(delta: float) -> void:
	var local_player: Player = _players.get(multiplayer.get_unique_id())
	if local_player == null:
		return
	_input_seq = (_input_seq + 1) & 0xFFFF
	var frame := InputFrame.sample_local(local_player)
	frame.seq = _input_seq
	_prediction.predict(local_player, frame, delta, _countdown_display > 0)
	_input_history.push_front(frame)
	if _input_history.size() > NetCodec.INPUT_HISTORY:
		_input_history.pop_back()
	_stats.record_input_sent(_input_seq, Time.get_ticks_msec())
	_net.send_input(NetCodec.encode_input(_input_history))


func _on_snapshot_received(snapshot: Dictionary) -> void:
	if Session.phase != Session.Phase.IN_MATCH:
		return
	var tick: int = snapshot.tick
	if _last_snapshot_tick >= 0 and (tick == _last_snapshot_tick or ((tick - _last_snapshot_tick) & 0xFFFFFFFF) >= 0x80000000):
		return
	_last_snapshot_tick = tick
	_net_log.record_snapshot_arrival(Time.get_ticks_msec())
	_pending_snapshot = snapshot


## move_and_slide() uses the engine physics delta, so replay must run on a physics tick.
func _apply_snapshot(snapshot: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	_countdown_display = snapshot.countdown
	for state: Dictionary in snapshot.states:
		for player in _players.values():
			if player.slot == state.slot:
				if player.peer_id == multiplayer.get_unique_id():
					_net_log.record_correction(_prediction.reconcile(player, state))
					_stats.record_ack(state.last_seq, now)
				else:
					player.receive_state(state, now)


# --- Both ------------------------------------------------------------------------

func _remove_departed_players() -> void:
	for peer_id in _players.keys():
		if not Session.players.has(peer_id):
			_score.remove_player(peer_id)
			_players[peer_id].queue_free()
			_players.erase(peer_id)
			_inputs.erase(peer_id)
