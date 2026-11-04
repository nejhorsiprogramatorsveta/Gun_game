class_name SlowCloud
extends Node2D
## Krügermann's arcade slowing cloud: a bubbly green puff that slows other players inside
## it and fades away after `lifetime` seconds.

var owner_peer_id := 0
var radius := 110.0
var speed_scale := 0.5
var jump_scale := 0.8
var lifetime := 3.0
var _age := 0.0


func contains(point: Vector2) -> bool:
	return point.distance_to(global_position) <= radius


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := clampf((lifetime - _age) / 0.5, 0.0, 1.0)
	var grow := minf(_age / 0.15, 1.0)
	var pulse := 1.0 + 0.06 * sin(_age * 9.0)
	draw_circle(Vector2.ZERO, radius * grow * pulse, Color(0.45, 0.95, 0.35, 0.22 * fade))
	for i in 7:
		var angle := TAU * i / 7.0 + _age * 0.8
		var bubble := Vector2.from_angle(angle) * radius * 0.55 * grow
		draw_circle(bubble, radius * 0.35 * grow * pulse, Color(0.55, 1.0, 0.45, 0.25 * fade))
	draw_arc(Vector2.ZERO, radius * grow * pulse, 0.0, TAU, 40, Color(0.7, 1.0, 0.5, 0.6 * fade), 3.0)
