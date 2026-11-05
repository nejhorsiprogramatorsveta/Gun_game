class_name AreaEffects
extends Node2D
## Temporary objects created by abilities (PLAN.md G.0a): slowing clouds, platforms.
## They are created the same way on the host, in the owner's client prediction (inside
## AbilityData.start) and, through a reliable event from the host, on the other clients.
## The key (ability, owner peer, input seq) stops duplicates when prediction replays the
## activation tick; when the host's event arrives, its position wins. The host may apply a
## press a few inputs later than predicted (InputBuffer catch-up), so a predicted effect is
## matched within SEQ_MATCH_WINDOW; one the host never confirms disappears after
## UNCONFIRMED_LIFETIME_MS (e.g. the owner had already been knocked out on the host).

const SEQ_MATCH_WINDOW := 8
const UNCONFIRMED_LIFETIME_MS := 1000

## MatchNet of a network match; null offline.
var _net: Node
var _is_authority := true
## "ability/owner/seq" -> effect node
var _effects: Dictionary[String, Node2D] = {}
## Client: key -> creation time (msec) of effects predicted locally and not yet confirmed.
var _unconfirmed: Dictionary[String, int] = {}
## 2 v 2: peer_id -> team (set by MatchController); teammates' clouds do not slow.
var teams: Dictionary[int, int] = {}


func setup(net: Node, is_authority: bool) -> void:
	_net = net
	_is_authority = is_authority
	if _net and not _is_authority:
		_net.effect_spawned.connect(_on_remote_spawned)


## Shared host/prediction entry point (AbilityData.start). The host also tells the clients.
func spawn(ability: AbilityData, owner_peer_id: int, seq: int, at: Vector2) -> void:
	if not _add(ability, owner_peer_id, seq, at):
		return
	if _is_authority and _net:
		_net.send_effect_spawned(ability.id, owner_peer_id, seq, at)
	elif not _is_authority:
		_unconfirmed[_key(ability.id, owner_peer_id, seq)] = Time.get_ticks_msec()


## Movement multipliers for a player standing in other players' clouds: Vector2(run, jump).
func slow_for(player: Player) -> Vector2:
	var scale := Vector2.ONE
	for effect in _effects.values():
		var cloud := effect as SlowCloud
		if cloud and cloud.owner_peer_id != player.peer_id and cloud.contains(player.global_position) \
				and not Teams.allies(teams.get(cloud.owner_peer_id, Teams.NONE), player.team):
			scale = Vector2(minf(scale.x, cloud.speed_scale), minf(scale.y, cloud.jump_scale))
	return scale


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for key in _unconfirmed.keys():
		if now - _unconfirmed[key] > UNCONFIRMED_LIFETIME_MS:
			_unconfirmed.erase(key)
			if _effects.has(key):
				_effects[key].queue_free()


func _on_remote_spawned(ability_id: StringName, owner_peer_id: int, seq: int, at: Vector2) -> void:
	var key := _key(ability_id, owner_peer_id, seq)
	if not _effects.has(key):
		key = _matching_prediction(ability_id, owner_peer_id, seq)
	if _effects.has(key):
		_effects[key].position = at  # our prediction made it already; the host decides where
		_unconfirmed.erase(key)
		return
	_add(ContentDB.get_ability(ability_id), owner_peer_id, seq, at)


## Our own unconfirmed prediction of the same ability, a few inputs off (or "" if none).
func _matching_prediction(ability_id: StringName, owner_peer_id: int, seq: int) -> String:
	for key in _unconfirmed:
		var parts := key.split("/")
		var distance := absi(((parts[2].to_int() - seq + 0x8000) & 0xFFFF) - 0x8000)
		if parts[0] == String(ability_id) and parts[1].to_int() == owner_peer_id and distance <= SEQ_MATCH_WINDOW:
			return key
	return ""


func _add(ability: AbilityData, owner_peer_id: int, seq: int, at: Vector2) -> bool:
	var key := _key(ability.id, owner_peer_id, seq)
	if _effects.has(key):
		return false
	var effect := ability.create_effect(owner_peer_id)
	if effect == null:
		return false
	effect.position = at
	effect.tree_exited.connect(func() -> void:
		_effects.erase(key)
		_unconfirmed.erase(key))
	_effects[key] = effect
	add_child(effect)
	return true


static func _key(ability_id: StringName, owner_peer_id: int, seq: int) -> String:
	return "%s/%d/%d" % [ability_id, owner_peer_id, seq]
