class_name GasCloud
extends Node2D
## Krügermann's gas: a long horizontal strip of bubbly green gas that blows other players
## away once they stay in it for `blow_delay` seconds (AreaEffects.blow) and fades after
## `lifetime` seconds.
## Arrows drifting through the gas show which way it blows.

const PUFFS: Texture2D = preload("res://assets/sprites/effects/gas_puffs.png")
const PUFF_SIZE := Vector2(32, 24)
const PUFF_FRAMES := 4
const PUFF_SCALE := 2.0
const ARROW: Texture2D = preload("res://assets/sprites/effects/gas_arrow.png")
## Arrows are drawn bigger than the puffs so the direction reads at a glance.
const ARROW_SCALE := 3.0
## Distance between the arrows and how fast they drift (px, px/s on screen).
const ARROW_SPACING := 110.0
const ARROW_SPEED := 260.0

var owner_peer_id := 0
## 1 = blows to the right, -1 = to the left (away from Krügermann).
var direction := 1
## Half of the strip's width and height (px).
var half_size := Vector2(270, 45)
var lifetime := 3.0
## Seconds in the gas (in a row) before it blows; blow speed (px/s) before the victim's
## weight: sideways and upwards.
var blow_delay := 0.2
var blow_speed := 1250.0
var blow_lift := 380.0
var _age := 0.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## True when a body of `body_half_size` centred at `point` overlaps the gas.
func touches(point: Vector2, body_half_size: Vector2 = Vector2.ZERO) -> bool:
	var offset := (point - global_position).abs()
	return offset.x <= half_size.x + body_half_size.x and offset.y <= half_size.y + body_half_size.y


## Physics ticks a player must spend in the gas before it blows (whole ticks, so the host
## and the victim's prediction count exactly the same).
func delay_ticks() -> int:
	return maxi(roundi(blow_delay * Engine.physics_ticks_per_second), 1)


## Velocity the gas gives a victim of weight 1.
func blow_velocity() -> Vector2:
	return Vector2(direction * blow_speed, -blow_lift)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	# Pixel-art gas: two rows of churning puffs (tools/art/generate_effects.py) that spread out
	# from the middle when the gas appears and fade away at the end.
	var fade := clampf((lifetime - _age) / 0.5, 0.0, 1.0)
	var grow := minf(_age / 0.2, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PUFF_SCALE)
	var area := half_size * 2.0 / PUFF_SCALE
	var width := area.x * grow
	var step := PUFF_SIZE.x * 0.7
	var columns := maxi(1, ceili(maxf(width - PUFF_SIZE.x, 0.0) / step) + 1)
	for row in 2:
		var y := -area.y / 2.0 if row == 0 else area.y / 2.0 - PUFF_SIZE.y
		for column in columns:
			var x := -width / 2.0 + minf(column * step, maxf(width - PUFF_SIZE.x, 0.0)) + (step / 2.0 if row == 1 else 0.0)
			x = minf(x, width / 2.0 - PUFF_SIZE.x)
			var frame := (int(_age * 6.0) + column + row * 2) % PUFF_FRAMES
			draw_texture_rect_region(PUFFS, Rect2(Vector2(x, y), PUFF_SIZE),
					Rect2(Vector2(frame * PUFF_SIZE.x, 0), PUFF_SIZE), Color(1, 1, 1, 0.85 * fade))
	_draw_arrows(width, fade)


## A row of arrows along the middle drifting the way the gas blows; mirrored for the left.
func _draw_arrows(width: float, fade: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ARROW_SCALE * direction, ARROW_SCALE))
	width *= PUFF_SCALE / ARROW_SCALE  # `width` came in puff units
	var arrow_size := ARROW.get_size()
	var spacing := ARROW_SPACING / ARROW_SCALE
	var x := -width / 2.0 + fmod(_age * ARROW_SPEED / ARROW_SCALE, spacing)
	while x < width / 2.0:
		# Arrows appear at the back of the strip and fade out at its front.
		var edge := minf(x + width / 2.0, width / 2.0 - x)
		var alpha := clampf(edge / (spacing * 0.5), 0.0, 1.0) * fade
		draw_texture(ARROW, Vector2(x - arrow_size.x / 2.0, -arrow_size.y / 2.0), Color(1, 1, 1, alpha))
		x += spacing
