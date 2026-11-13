class_name NazgulFx
extends Node2D
## The Nazgûl's visit (Hobitín, see Nazgul): the hooded wraith rises out of dark smoke next
## to the victim and follows him, raises the sword, slashes (the authority's knockback lands
## at STRIKE_TIME) and dissolves upwards. Pure decoration, shown on every computer.
## Sprite: tools/art/generate_effects.py nazgul() - 4 frames 48x56, facing right.

const SHEET: Texture2D = preload("res://assets/sprites/effects/nazgul.png")
const FRAME_SIZE := Vector2(48, 56)
## x of the body's centre in a frame, and how far below the victim's feet the hem hangs.
const BODY_CENTER_X := 17.0
const HEM_BELOW_FEET := 6.0
## Bigger than the players (they are drawn at 2x).
const PIXEL_SCALE := 2.5
## Timeline (s): appear (rise out of the smoke) -> sword raised -> slash -> vanish.
const APPEAR_TIME := 0.55
const STRIKE_TIME := 0.8
const SLASH_TIME := 0.25
const VANISH_TIME := 0.5
## Gap (px) between the victim's body and the wraith's body centre.
const GAP := 52.0
const SMOKE_COLOR := Color(0.07, 0.05, 0.11)

var _target: Player
## 1 = the victim is thrown to the right (the wraith stands on his left), -1 = to the left.
var _direction := 1
var _age := 0.0
var _anchor := Vector2.ZERO


func setup(target: Player, direction: int) -> void:
	_target = target
	_direction = 1 if direction >= 0 else -1
	_anchor = target.position + target.visual_offset
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func total_time() -> float:
	return STRIKE_TIME + SLASH_TIME + VANISH_TIME


func _process(delta: float) -> void:
	_age += delta
	# Follows the victim until the slash, then stays where it struck.
	if _age < STRIKE_TIME and is_instance_valid(_target) and _target.visible:
		_anchor = _target.position + _target.visual_offset
	position = _anchor + Vector2(-_direction * (Player.BODY_SIZE.x / 2.0 + GAP), 0.0)
	if _age >= total_time():
		queue_free()
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0
	var rise := 0.0  # px, negative = up
	var frame := int(_age * 8.0) % 2  # hovering, the hem flutters
	var smoke := 0.0
	if _age < APPEAR_TIME:
		var t := _age / APPEAR_TIME
		alpha = t
		rise = (1.0 - t) * 30.0
		smoke = 1.0 - t * 0.5
	elif _age < STRIKE_TIME:
		frame = 2
		smoke = 0.5 * (1.0 - (_age - APPEAR_TIME) / (STRIKE_TIME - APPEAR_TIME))
	elif _age < STRIKE_TIME + SLASH_TIME:
		frame = 3
	else:
		var t := (_age - STRIKE_TIME - SLASH_TIME) / VANISH_TIME
		alpha = 1.0 - t
		rise = -t * 26.0
		smoke = t
	if smoke > 0.0:
		_draw_smoke(smoke)
	var feet := Player.BODY_SIZE.y / 2.0 + HEM_BELOW_FEET
	draw_set_transform(Vector2(0.0, rise), 0.0, Vector2(PIXEL_SCALE * _direction, PIXEL_SCALE))
	draw_texture_rect_region(SHEET, Rect2(Vector2(-BODY_CENTER_X, feet / PIXEL_SCALE - FRAME_SIZE.y), FRAME_SIZE),
			Rect2(Vector2(frame * FRAME_SIZE.x, 0.0), FRAME_SIZE), Color(1, 1, 1, clampf(alpha, 0.0, 1.0)))


## Dark puffs swirling around the hem while the wraith appears or dissolves.
func _draw_smoke(strength: float) -> void:
	var feet_y := Player.BODY_SIZE.y / 2.0
	for i in 9:
		var angle := i * TAU / 9.0 + _age * 3.0
		var spread := 20.0 + 14.0 * sin(_age * 5.0 + i)
		var at := Vector2(cos(angle) * spread * 1.6, feet_y - 10.0 + sin(angle) * spread * 0.5 - _age * 20.0)
		draw_circle(at, 9.0 + 4.0 * sin(i + _age * 7.0), Color(SMOKE_COLOR, 0.75 * strength))
