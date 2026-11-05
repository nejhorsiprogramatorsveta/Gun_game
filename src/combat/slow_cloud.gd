class_name SlowCloud
extends Node2D
## Krügermann's arcade slowing gas: a long horizontal strip of bubbly green gas that slows
## other players inside it and fades away after `lifetime` seconds.

const PUFFS: Texture2D = preload("res://assets/sprites/effects/gas_puffs.png")
const PUFF_SIZE := Vector2(32, 24)
const PUFF_FRAMES := 4
const PUFF_SCALE := 2.0

var owner_peer_id := 0
## Half of the strip's width and height (px).
var half_size := Vector2(180, 45)
var speed_scale := 0.5
var jump_scale := 0.8
var lifetime := 3.0
var _age := 0.0


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func contains(point: Vector2) -> bool:
	var offset := (point - global_position).abs()
	return offset.x <= half_size.x and offset.y <= half_size.y


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
