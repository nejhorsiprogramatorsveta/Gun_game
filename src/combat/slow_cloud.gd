class_name SlowCloud
extends Node2D
## Krügermann's arcade slowing gas: a long horizontal strip of bubbly green gas that slows
## other players inside it and fades away after `lifetime` seconds.

var owner_peer_id := 0
## Half of the strip's width and height (px).
var half_size := Vector2(180, 45)
var speed_scale := 0.5
var jump_scale := 0.8
var lifetime := 3.0
var _age := 0.0


func contains(point: Vector2) -> bool:
	var offset := (point - global_position).abs()
	return offset.x <= half_size.x and offset.y <= half_size.y


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := clampf((lifetime - _age) / 0.5, 0.0, 1.0)
	var grow := minf(_age / 0.2, 1.0)
	var size := Vector2(half_size.x * grow, half_size.y)
	var rect := Rect2(-size, size * 2.0)
	draw_rect(rect, Color(0.45, 0.95, 0.35, 0.18 * fade))
	var puffs := 9
	for i in puffs:
		var x := lerpf(-size.x, size.x, (i + 0.5) / puffs)
		var wobble := sin(_age * 7.0 + i * 1.7) * size.y * 0.25
		draw_circle(Vector2(x, wobble), size.y * 0.8, Color(0.55, 1.0, 0.45, 0.22 * fade))
	draw_rect(rect, Color(0.7, 1.0, 0.5, 0.55 * fade), false, 3.0)
