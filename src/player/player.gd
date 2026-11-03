class_name Player
extends CharacterBody2D
## A character in the arena. Movement rules live in PlayerMotor; this node wires input,
## character data and placeholder visuals together.

const BODY_SIZE := Vector2(36, 56)

var character: CharacterData
var motor_state := PlayerMotor.State.new()
## True for the player controlled by this computer's keyboard.
var is_local := false

var _drawn_facing := 0


func setup(data: CharacterData, local: bool) -> void:
	character = data
	is_local = local
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_local:
		return
	PlayerMotor.step(self, InputFrame.sample_local(), motor_state, character, delta)
	if motor_state.facing != _drawn_facing:
		queue_redraw()


func reset_to(spawn_position: Vector2) -> void:
	position = spawn_position
	velocity = Vector2.ZERO
	motor_state = PlayerMotor.State.new()


## Inactive players are hidden and removed from physics (e.g. while waiting to respawn).
func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _draw() -> void:
	_drawn_facing = motor_state.facing
	draw_rect(Rect2(-BODY_SIZE / 2.0, BODY_SIZE), character.color if character else Color.WHITE)
	var eye := Vector2(8.0 * _drawn_facing, -BODY_SIZE.y / 4.0)
	draw_rect(Rect2(eye - Vector2(4, 4), Vector2(8, 8)), Color(0.1, 0.1, 0.12))
