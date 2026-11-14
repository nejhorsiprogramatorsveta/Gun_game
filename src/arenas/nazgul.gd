class_name Nazgul
extends Node2D
## Hobitín (user 2026-11-13): a player with `min_kills` (4) or more kills is hunted. The first
## time someone reaches it everybody sees "Nazgûl přichází!"; then every `interval_min` to
## `interval_max` seconds a hooded wraith with a sword appears next to that player
## (NazgulFx), raises the sword and slashes him away towards the side of the map he is on
## (left of `center_x` -> to the left), then vanishes. Only on arenas that have this node.
## The authority (host, practice) decides everything; clients get the events through
## MatchNet.send_nazgul and the knockback in snapshots (like a hit). A fall afterwards
## counts like any other fall (the last shooter keeps the kill). Online games write every
## event to the diagnostic log (`[match] nazgul ...`, user 2026-11-14: it was not visible).

signal alert(text: String)

enum Event { COMING, STRIKE }

@export var min_kills := 4
## Seconds from reaching min_kills to the first appearance, then between appearances.
@export var first_delay := 3.0
@export var interval_min := 12.0
@export var interval_max := 18.0
## The slash: speed (px/s) before the victim's weight, sideways and upwards, and the damage
## percent it adds (more damage = more knockback, like a hit).
@export var strength := 1200.0
@export var lift := 400.0
@export var damage := 12.0
## x of the map's middle.
@export var center_x := 1200.0

var _net: Node
## Online game (host or client): events go to the diagnostic log.
var _logging := false
## The match's live peer_id -> Player dictionary.
var _players: Dictionary[int, Player] = {}
## Authority: peer_id -> tick of the next appearance (only hunted players) and peer_id ->
## {"tick", "direction"} of a slash under way.
var _next_tick: Dictionary[int, int] = {}
var _pending: Dictionary[int, Dictionary] = {}


func setup(net: Node, is_authority: bool, players: Dictionary[int, Player]) -> void:
	_net = net if is_authority else null
	_logging = net != null
	_players = players
	if net and not is_authority:
		net.nazgul_event.connect(_on_event)


## Authority, every tick while the match runs (not during the countdown).
func tick(tick: int) -> void:
	for peer_id: int in _players:
		var player := _players[peer_id]
		if not _next_tick.has(peer_id):
			if player.kills >= min_kills:
				_next_tick[peer_id] = tick + _ticks(first_delay)
				_emit(Event.COMING, player.slot, 0)
			continue
		if _pending.has(peer_id):
			if tick >= _pending[peer_id].tick:
				_strike(player, _pending[peer_id].direction)
				_pending.erase(peer_id)
			continue
		if tick < _next_tick[peer_id]:
			continue
		if not player.visible or player.invulnerable:
			_next_tick[peer_id] = tick + _ticks(1.0)  # comes back once the player is
			continue
		var direction := direction_for(player.position.x)
		_pending[peer_id] = {"tick": tick + _ticks(NazgulFx.STRIKE_TIME), "direction": direction}
		_next_tick[peer_id] = tick + _ticks(randf_range(interval_min, interval_max))
		_emit(Event.STRIKE, player.slot, direction)


## -1 = thrown to the left (the player is in the left half), 1 = to the right.
func direction_for(x: float) -> int:
	return -1 if x < center_x else 1


func _strike(player: Player, direction: int) -> void:
	if not player.visible or player.invulnerable:
		if _logging:
			DiagLog.event("match", "nazgul missed slot%d" % player.slot)
		return  # died or respawned meanwhile: the slash misses
	var weight := player.character.weight if player.character else 1.0
	player.take_hit(Vector2(direction * strength, -lift) / maxf(weight, 0.1), damage)


func _emit(event: Event, slot: int, direction: int) -> void:
	if _net:
		_net.send_nazgul(event, slot, direction)
	_on_event(event, slot, direction)


## Everyone: the banner, or the wraith next to the player in `slot`.
func _on_event(event: int, slot: int, direction: int) -> void:
	if _logging:
		DiagLog.event("match", describe(event, slot, direction))
	for player: Player in _players.values():
		if player.slot != slot:
			continue
		if event == Event.COMING:
			alert.emit(tr("NAZGUL_COMING"))
		elif event == Event.STRIKE and direction != 0:
			var fx := NazgulFx.new()
			fx.setup(player, direction)
			add_child(fx)
		return


## Text of the diagnostic log line, e.g. "nazgul coming slot2", "nazgul strike slot0 to=left".
static func describe(event: int, slot: int, direction: int) -> String:
	if event == Event.COMING:
		return "nazgul coming slot%d" % slot
	return "nazgul strike slot%d to=%s" % [slot, "left" if direction < 0 else "right"]


static func _ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)
