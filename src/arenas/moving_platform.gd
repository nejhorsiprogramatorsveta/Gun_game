@tool
class_name MovingPlatform
extends Platform
## A platform that glides back and forth along `travel` (Hobitín, user 2026-11-13). Its
## position is a pure function of the host's match tick, so the host and the own client's
## prediction (which knows the host tick of every input, MatchClient.tick_for) place it
## exactly the same. Players standing on it are carried by Arena.prepare inside
## Player.simulate, not by the physics engine, so a replay carries them identically.
## In the editor it stays at its start; `travel` is the offset of the far end.

## A body whose feet are this close to the top counts as standing on it.
const SUPPORT_TOLERANCE := 6.0

## Offset (px) of the far end of the path from the start position.
@export var travel := Vector2(240, 0)
## Seconds for one way there and back (eased: slow at both ends, fastest in the middle,
## top speed = PI * |travel| / period).
@export var period := 8.0
## Where in the cycle it is at tick 0 (0 = start, 0.5 = far end), so neighbours can move
## out of step.
@export_range(0.0, 1.0) var phase := 0.0

## Start position (top-left corner) from the scene.
var base_position := Vector2.ZERO
var _placed_tick := -1


func _ready() -> void:
	base_position = position


func offset_at(tick: int) -> Vector2:
	var ticks_per_cycle := maxf(period * Engine.physics_ticks_per_second, 1.0)
	var t := fposmod(tick / ticks_per_cycle + phase, 1.0)
	return travel * (0.5 - 0.5 * cos(TAU * t))


## Moves the platform to where it is at `tick`; physics queries see it at once.
func place(tick: int) -> void:
	if tick == _placed_tick or Engine.is_editor_hint():
		return
	_placed_tick = tick
	position = base_position + offset_at(tick)
	if is_inside_tree():
		force_update_transform()


## True when a body with its feet (bottom centre) at `feet` and `half_width` stood on top of
## the platform at `tick`.
func supports(feet: Vector2, half_width: float, tick: int) -> bool:
	var top_left := base_position + offset_at(tick)
	return absf(feet.y - top_left.y) <= SUPPORT_TOLERANCE \
			and feet.x + half_width > top_left.x and feet.x - half_width < top_left.x + size.x
