extends Node2D
## Runs a match. Offline practice and network matches share one flow (PLAN.md D.1):
## the authority (host, or this computer in practice) simulates every player from inputs
## and sends snapshots; clients only send their input and display the snapshots.

const ARENA_SCENE := preload("res://src/arenas/arena_rooftops.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"
## 60 Hz physics -> 30 Hz snapshots.
const SNAPSHOT_EVERY_TICKS := 2
## Caps the extra delay if a client's packets arrive in a burst.
const MAX_PENDING_INPUTS := 6

var _arena: Arena
var _rules: MatchRules = ContentDB.match_rules()
var _networked := false
var _is_authority := true
## peer_id -> Player
var _players: Dictionary[int, Player] = {}
var _tick := 0

# Authority: inputs received from clients.
var _pending_inputs: Dictionary[int, Array] = {}
var _current_input: Dictionary[int, InputFrame] = {}
var _newest_seq: Dictionary[int, int] = {}

# Client: own input history (newest first) for redundancy against packet loss.
var _input_seq := 0
var _input_history: Array[InputFrame] = []

@onready var _net: Node = $MatchNet


func _ready() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	_networked = Session.phase == Session.Phase.IN_MATCH
	_is_authority = not _networked or multiplayer.is_server()
	if _networked:
		for peer_id: int in Session.match_slots:
			_spawn(peer_id, Session.match_slots[peer_id], Session.players.get(peer_id, {}).get("name", "?"))
		Session.players_changed.connect(_remove_departed_players)
		Session.ended.connect(func(_message: String) -> void: get_tree().change_scene_to_file.call_deferred(MAIN_MENU_PATH))
		_net.input_received.connect(_on_input_received)
		_net.snapshot_received.connect(_on_snapshot_received)
		if _net.lag.is_enabled():
			$Hud/HintLabel.text = tr("DEBUG_FAKE_LAG").format({"lag": _net.lag.rtt_ms, "loss": _net.lag.loss_percent})
	else:
		_spawn(multiplayer.get_unique_id(), 0, Settings.player_name)


func _spawn(peer_id: int, slot: int, display_name: String) -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(ContentDB.default_character(), slot, peer_id, display_name)
	add_child(player)
	var spawns := _arena.spawn_points()
	player.reset_to(spawns[slot % spawns.size()])
	_players[peer_id] = player


func _physics_process(delta: float) -> void:
	if _is_authority:
		_simulate_tick(delta)
	else:
		_send_local_input()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _networked:
			Session.leave()  # Session.ended then returns to the menu
		else:
			get_tree().change_scene_to_file(MAIN_MENU_PATH)


# --- Authority ---------------------------------------------------------------

func _simulate_tick(delta: float) -> void:
	_tick += 1
	for peer_id in _players:
		var player := _players[peer_id]
		if not player.visible:
			continue
		player.simulate(_input_for(peer_id, player), delta)
		if _arena.is_out_of_bounds(player.position):
			_respawn_later(player)
	if _networked and _tick % SNAPSHOT_EVERY_TICKS == 0:
		var states: Array[Dictionary] = []
		for player in _players.values():
			states.append(player.snapshot_state())
		_net.broadcast_snapshot(NetCodec.encode_snapshot(_tick, states))


## One input per tick per player; if a client's packet is late, its last input repeats.
func _input_for(peer_id: int, player: Player) -> InputFrame:
	if peer_id == multiplayer.get_unique_id():
		return InputFrame.sample_local(player)
	var queue: Array = _pending_inputs.get(peer_id, [])
	if not queue.is_empty():
		_current_input[peer_id] = queue.pop_front()
	return _current_input.get(peer_id, InputFrame.new())


func _on_input_received(peer_id: int, frames: Array[InputFrame]) -> void:
	if not _players.has(peer_id):
		return
	var queue: Array = _pending_inputs.get_or_add(peer_id, [])
	var newest: int = _newest_seq.get(peer_id, -1)
	# frames are newest first; queue the ones we have not seen yet, oldest first.
	for i in range(frames.size() - 1, -1, -1):
		var frame := frames[i]
		var is_first_packet := newest == -1
		if (is_first_packet and i == 0) or (not is_first_packet and NetCodec.seq_newer(frame.seq, newest)):
			queue.append(frame)
			newest = frame.seq
	while queue.size() > MAX_PENDING_INPUTS:
		queue.pop_front()
	_newest_seq[peer_id] = newest


func _respawn_later(player: Player) -> void:
	player.set_active(false)
	await get_tree().create_timer(_rules.respawn_delay).timeout
	if not is_instance_valid(player):
		return
	player.reset_to(_arena.spawn_points().pick_random())
	player.set_active(true)


# --- Client --------------------------------------------------------------------

func _send_local_input() -> void:
	var local_player: Player = _players.get(multiplayer.get_unique_id())
	if local_player == null:
		return
	_input_seq = (_input_seq + 1) & 0xFFFF
	var frame := InputFrame.sample_local(local_player)
	frame.seq = _input_seq
	_input_history.push_front(frame)
	if _input_history.size() > NetCodec.INPUT_HISTORY:
		_input_history.pop_back()
	_net.send_input(NetCodec.encode_input(_input_history))


func _on_snapshot_received(snapshot: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	for state: Dictionary in snapshot.states:
		for player in _players.values():
			if player.slot == state.slot:
				player.receive_state(state, now)


# --- Both ------------------------------------------------------------------------

func _remove_departed_players() -> void:
	for peer_id in _players.keys():
		if not Session.players.has(peer_id):
			_players[peer_id].queue_free()
			_players.erase(peer_id)
			_pending_inputs.erase(peer_id)
			_current_input.erase(peer_id)
			_newest_seq.erase(peer_id)
