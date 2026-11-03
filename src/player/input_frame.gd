class_name InputFrame
extends RefCounted
## Player intent for one physics tick. Only held state is stored; press edges are derived
## by PlayerMotor, so the host and (from M4) client prediction interpret inputs identically.
## From M2 this is what clients send to the host.

const JUMP := 1
const FIRE := 2
const ABILITY := 4
const DOWN := 8

## -1 = left, 0 = none, 1 = right.
var move_x: int = 0
## Bitmask of the button constants above.
var buttons: int = 0


static func create(move: int, held_buttons: int) -> InputFrame:
	var frame := InputFrame.new()
	frame.move_x = clampi(move, -1, 1)
	frame.buttons = held_buttons
	return frame


static func sample_local() -> InputFrame:
	var held := 0
	if Input.is_action_pressed("jump"):
		held |= JUMP
	if Input.is_action_pressed("fire"):
		held |= FIRE
	if Input.is_action_pressed("ability"):
		held |= ABILITY
	if Input.is_action_pressed("down"):
		held |= DOWN
	return create(int(signf(Input.get_axis("move_left", "move_right"))), held)


func is_held(button: int) -> bool:
	return buttons & button != 0
