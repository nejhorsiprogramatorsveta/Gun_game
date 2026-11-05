class_name JetpackAbility
extends AbilityData
## Jiskra: a jetpack burst that carries her up for `duration` seconds (steerable sideways,
## gravity replaced by thrust). The movement itself is in PlayerMotor, so client prediction
## replays it exactly.

## Upward speed (px/s) the thrust accelerates towards, and how fast (px/s²).
@export var lift_speed: float = 650.0
@export var thrust: float = 5000.0


func start(user: Player, _input: InputFrame) -> void:
	user.motor_state.boost_time_left = duration
