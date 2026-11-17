class_name RocketSystem
extends Node2D
## Host-owned homing rockets. Clients only display the host's bounded state stream.

signal player_hit(owner_peer_id: int, target: Player)

const STATE_EVERY_TICKS := 3
const MAX_RETIRED := 256

var _net: Node
var _is_authority := true
var _players: Dictionary[int, Player] = {}
var _rockets: Dictionary[int, HomingRocket] = {}
var _retired: Dictionary[int, bool] = {}
var _next_id := 1
var _last_tick := -1
var _sent_live_state := false


func setup(net: Node, is_authority: bool, players: Dictionary[int, Player]) -> void:
	_net = net
	_is_authority = is_authority
	_players = players
	if _net and not _is_authority:
		_net.rocket_state_received.connect(_on_remote_state)
		_net.rocket_exploded.connect(_on_remote_exploded)


## Called after the usual ability cooldown/press logic, only by the authority.
func spawn_for(player: Player) -> void:
	if not _is_authority or not player.ability_started or not player.character.ability is HomingRocketAbility \
			or _rockets.size() >= RocketCodec.MAX_ROCKETS:
		return
	var direction := InputFrame.aim_to_vector(player.aim)
	var rocket := _add(_next_id, player.peer_id, player.team, player.global_position,
			direction, player.character.ability as HomingRocketAbility)
	var target := rocket.nearest_target(_players.values())
	if target and not target.global_position.is_equal_approx(player.global_position):
		rocket.direction = player.global_position.direction_to(target.global_position)
	rocket.position += rocket.direction * Player.GUN_LENGTH
	_next_id += 1


## After player movement, before their snapshots: explosion knockback is in that frame.
func tick(delta: float, host_tick: int) -> void:
	if not _is_authority:
		return
	for rocket in _rockets.values():
		rocket.advance(delta, _players.values())
	if _net and host_tick % STATE_EVERY_TICKS == 0 and (not _rockets.is_empty() or _sent_live_state):
		var states: Array[Dictionary] = []
		for rocket in _rockets.values():
			states.append({"id": rocket.id, "owner_peer_id": rocket.owner_peer_id,
					"position": rocket.global_position, "direction": rocket.direction, "speed": rocket.speed})
		_net.send_rocket_state(RocketCodec.encode(host_tick, states))
		_sent_live_state = not states.is_empty()


func _physics_process(delta: float) -> void:
	if _is_authority:
		return
	for rocket in _rockets.values():
		rocket.advance(delta, [])


func _add(id: int, owner_id: int, team: int, at: Vector2, direction: Vector2, ability: HomingRocketAbility) -> HomingRocket:
	var rocket := HomingRocket.new()
	rocket.setup(id, at, direction, ability, owner_id, team, _is_authority)
	rocket.player_hit.connect(func(peer_id: int, target: Player) -> void: player_hit.emit(peer_id, target))
	rocket.exploded.connect(_on_exploded)
	_rockets[id] = rocket
	add_child(rocket)
	return rocket


func _on_exploded(rocket: HomingRocket) -> void:
	_rockets.erase(rocket.id)
	_show_blast(rocket.global_position, rocket.ability)
	if _net and _is_authority:
		_net.send_rocket_exploded(rocket.id, rocket.global_position)


func _on_remote_state(snapshot: Dictionary) -> void:
	if snapshot.tick <= _last_tick:
		return
	_last_tick = snapshot.tick
	var present: Dictionary[int, bool] = {}
	var ability := ContentDB.get_ability(&"homing_rocket") as HomingRocketAbility
	if ability == null:
		return
	for state: Dictionary in snapshot.rockets:
		present[state.id] = true
		# An already fired rocket survives its owner's departure, like a bullet.
		# The bounded state is sent only by the authority, not by the owner.
		if _retired.has(state.id):
			continue
		var rocket: HomingRocket = _rockets.get(state.id)
		if rocket == null:
			rocket = _add(state.id, state.owner_peer_id, Teams.NONE, state.position, state.direction, ability)
		rocket.position = state.position
		rocket.direction = state.direction
		rocket.speed = state.speed
		rocket.queue_redraw()
	for id in _rockets.keys():
		if not present.has(id):
			_rockets[id].queue_free()
			_rockets.erase(id)


func _on_remote_exploded(id: int, at: Vector2) -> void:
	if _retired.has(id):
		return
	_retired[id] = true
	if _retired.size() > MAX_RETIRED:
		_retired.erase(_retired.keys()[0])
	if _rockets.has(id):
		_rockets[id].queue_free()
		_rockets.erase(id)
	_show_blast(at, ContentDB.get_ability(&"homing_rocket") as HomingRocketAbility)


func _show_blast(at: Vector2, ability: HomingRocketAbility) -> void:
	if ability == null:
		return
	var wave := ShockwaveAbility.new()
	wave.radius = ability.radius
	var ring: AnimatedSprite2D = AbilityFx.make_burst(wave, 1).node
	ring.position = at
	ring.modulate = Color(1.0, 0.6, 0.25)
	add_child(ring)
