class_name DashAbility
extends AbilityData
## Jiskra: a short, fast sideways dash (also in the air) in the movement direction, or the
## facing side when standing. The movement itself is in PlayerMotor, so client prediction
## replays it exactly.

## Dash speed (px/s) for `duration` seconds (0.15 s x 1400 = 210 px).
@export var speed: float = 1400.0


func start(user: Player, input: InputFrame) -> void:
	user.motor_state.dash_time_left = duration
	user.motor_state.dash_direction = input.move_x if input.move_x != 0 else user.motor_state.facing
