extends Node
## RPC layer of a network match – the only place with match RPCs (PLAN.md F.3).
## Inputs go client -> host, snapshots host -> clients, both unreliable_ordered: a lost
## packet is simply replaced by the next one, resending old state would only add delay.
## Security (PLAN.md section S): sender identity comes from the network layer, packets are
## size-checked in NetCodec and rate-limited per client.

signal input_received(peer_id: int, frames: Array[InputFrame])
signal snapshot_received(snapshot: Dictionary)
signal projectile_spawned(id: int, origin: Vector2, direction: Vector2, weapon_id: StringName)
signal projectile_removed(id: int)
signal kill_announced(killer_slot: int, streak: int)
signal effect_spawned(ability_id: StringName, owner_peer_id: int, seq: int, position: Vector2)

## A legit client sends 60/s; anything far above is dropped.
const MAX_INPUT_PACKETS_PER_SECOND := 150
## Clients repeat "loaded" until the first snapshot arrives (the host may still be loading).
const LOADED_RETRY_SECONDS := 0.5

## Host: clients whose match scene is ready to receive snapshots.
var _loaded_peers: Dictionary[int, bool] = {}
var _packet_counts: Dictionary[int, int] = {}
var _rate_window_start_ms := 0
var _got_snapshot := false
## Debug-only fake latency/packet loss (see LagSimulator); a no-op unless enabled.
var lag := LagSimulator.from_command_line()


func _ready() -> void:
	multiplayer.peer_disconnected.connect(func(id: int) -> void: _loaded_peers.erase(id))
	if not multiplayer.is_server():
		_announce_loaded()


func _process(_delta: float) -> void:
	lag.flush()


func send_input(data: PackedByteArray) -> void:
	_send(func() -> void: _receive_input.rpc_id(1, data))


func broadcast_snapshot(data: PackedByteArray) -> void:
	_send(func() -> void:
		for peer_id in _loaded_peers:
			_receive_snapshot.rpc_id(peer_id, data))


## Host: shot/removal events are reliable – a missing bullet would be confusing.
func send_projectile_spawned(id: int, origin: Vector2, direction: Vector2, weapon_id: StringName) -> void:
	_send(func() -> void:
		for peer_id in _loaded_peers:
			_receive_projectile_spawned.rpc_id(peer_id, id, origin, direction, weapon_id), true)


func send_projectile_removed(id: int) -> void:
	_send(func() -> void:
		for peer_id in _loaded_peers:
			_receive_projectile_removed.rpc_id(peer_id, id), true)


func send_kill_announced(killer_slot: int, streak: int) -> void:
	_send(func() -> void:
		for peer_id in _loaded_peers:
			_receive_kill_announced.rpc_id(peer_id, killer_slot, streak), true)


## Host: an ability left a cloud/platform (AreaEffects); reliable so everyone sees it.
func send_effect_spawned(ability_id: StringName, owner_peer_id: int, seq: int, at: Vector2) -> void:
	_send(func() -> void:
		for peer_id in _loaded_peers:
			_receive_effect_spawned.rpc_id(peer_id, ability_id, owner_peer_id, seq, at), true)


## Sends only while the match runs: once it has ended the other side may already have
## left the match scene, and RPCs to the missing MatchNet node would only log errors.
## Checked at send time, so packets delayed by the LagSimulator are covered too.
func _send(action: Callable, reliable: bool = false) -> void:
	lag.run(func() -> void:
		if Session.phase == Session.Phase.IN_MATCH:
			action.call(), reliable)


func _announce_loaded() -> void:
	while not _got_snapshot and is_inside_tree():
		_client_loaded.rpc_id(1)
		await get_tree().create_timer(LOADED_RETRY_SECONDS).timeout


@rpc("any_peer", "call_remote", "reliable")
func _client_loaded() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and Session.phase == Session.Phase.IN_MATCH and Session.players.has(sender):
		_loaded_peers[sender] = true


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_input(data: PackedByteArray) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or not _loaded_peers.has(sender) or _rate_exceeded(sender):
		return
	var frames := NetCodec.decode_input(data)
	if not frames.is_empty():
		lag.run(input_received.emit.bind(sender, frames))


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_snapshot(data: PackedByteArray) -> void:
	var snapshot := NetCodec.decode_snapshot(data)
	if not snapshot.is_empty():
		_got_snapshot = true
		lag.run(snapshot_received.emit.bind(snapshot))


@rpc("authority", "call_remote", "reliable")
func _receive_projectile_spawned(id: int, origin: Vector2, direction: Vector2, weapon_id: StringName) -> void:
	lag.run(projectile_spawned.emit.bind(id, origin, direction, weapon_id), true)


@rpc("authority", "call_remote", "reliable")
func _receive_projectile_removed(id: int) -> void:
	lag.run(projectile_removed.emit.bind(id), true)


@rpc("authority", "call_remote", "reliable")
func _receive_kill_announced(killer_slot: int, streak: int) -> void:
	if Session.phase != Session.Phase.IN_MATCH or killer_slot < 0 or killer_slot >= Session.MAX_PLAYERS \
			or streak < 1 or streak > 65535:
		return
	lag.run(kill_announced.emit.bind(killer_slot, streak), true)


@rpc("authority", "call_remote", "reliable")
func _receive_effect_spawned(ability_id: StringName, owner_peer_id: int, seq: int, at: Vector2) -> void:
	if Session.phase != Session.Phase.IN_MATCH or ContentDB.get_ability(ability_id) == null \
			or not Session.players.has(owner_peer_id) or seq < 0 or seq > 0xFFFF or not at.is_finite():
		return
	lag.run(effect_spawned.emit.bind(ability_id, owner_peer_id, seq, at), true)


func _rate_exceeded(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - _rate_window_start_ms >= 1000:
		_rate_window_start_ms = now
		_packet_counts.clear()
	_packet_counts[peer_id] = _packet_counts.get(peer_id, 0) + 1
	return _packet_counts[peer_id] > MAX_INPUT_PACKETS_PER_SECOND
