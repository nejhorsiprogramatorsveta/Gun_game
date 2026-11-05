class_name MagazineDrop
extends Node2D
## Reload effect: an empty pixel-art magazine falls out of the gun, spins and fades.
## Purely visual, drawn with rectangles (no texture), frees itself.

const LIFETIME := 0.7
const GRAVITY := 1800.0
## One art pixel in world pixels (same scale as the character sprites).
const PIXEL := 2.0

var _velocity := Vector2.ZERO
var _age := 0.0


func setup(facing: int) -> void:
	_velocity = Vector2(-90.0 * facing, -160.0)
	z_index = 1


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	rotation += 9.0 * delta * signf(-_velocity.x if _velocity.x != 0.0 else 1.0)
	modulate.a = 1.0 - _age / LIFETIME


func _draw() -> void:
	# 3 x 5 art pixels: dark body, lighter edge, brass top.
	draw_rect(Rect2(Vector2(-1.5, -2.5) * PIXEL, Vector2(3, 5) * PIXEL), Color(0.16, 0.16, 0.2))
	draw_rect(Rect2(Vector2(-1.5, -2.5) * PIXEL, Vector2(1, 5) * PIXEL), Color(0.36, 0.36, 0.42))
	draw_rect(Rect2(Vector2(-1.5, -2.5) * PIXEL, Vector2(3, 1) * PIXEL), Color(0.85, 0.66, 0.25))
