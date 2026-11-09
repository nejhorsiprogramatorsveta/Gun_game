class_name InputFrame
extends RefCounted
## Player intent for one physics tick: what clients send to the host (PLAN.md D.3).
## Only held state is stored; press edges are derived by PlayerMotor, so the host and
## (from M4) client prediction interpret inputs identically.

const JUMP := 1
const FIRE := 2
const ABILITY := 4
const DOWN := 8
## Reload before the magazine is empty (key Q by default).
const RELOAD := 16
const ALL_BUTTONS := JUMP | FIRE | ABILITY | DOWN | RELOAD
## Aim angle is sent as u16: a full turn = 65536 steps (~0.005°).
const AIM_STEPS := 65536

## -1 = left, 0 = none, 1 = right.
var move_x: int = 0
## Bitmask of the button constants above.
var buttons: int = 0
## Direction from the player to the mouse cursor, 0..65535 (0 = right, clockwise).
var aim: int = 0
## Sequence number (u16, wraps) so the host can drop duplicates and old packets.
var seq: int = 0


static func create(move: int, held_buttons: int, aim_steps: int = 0, sequence: int = 0) -> InputFrame:
	var frame := InputFrame.new()
	frame.move_x = clampi(move, -1, 1)
	frame.buttons = held_buttons & ALL_BUTTONS
	frame.aim = aim_steps & 0xFFFF
	frame.seq = sequence & 0xFFFF
	return frame


## Reads this computer's keyboard and mouse; `origin` is the player being controlled.
static func sample_local(origin: Player) -> InputFrame:
	var held := 0
	if Input.is_action_pressed("jump"):
		held |= JUMP
	if Input.is_action_pressed("fire"):
		held |= FIRE
	if Input.is_action_pressed("ability"):
		held |= ABILITY
	if Input.is_action_pressed("down"):
		held |= DOWN
	if Input.is_action_pressed("reload"):
		held |= RELOAD
	var move := int(signf(Input.get_axis("move_left", "move_right")))
	return create(move, held, aim_from_vector(origin.get_global_mouse_position() - origin.global_position))


static func aim_from_vector(direction: Vector2) -> int:
	return roundi(fposmod(direction.angle(), TAU) / TAU * AIM_STEPS) & 0xFFFF


static func aim_to_vector(aim_steps: int) -> Vector2:
	return Vector2.from_angle(float(aim_steps) / AIM_STEPS * TAU)


func is_held(button: int) -> bool:
	return buttons & button != 0
