class_name TeleportAbility
extends AbilityData
## Stín: jumps up to `distance` px towards the mouse cursor, stopping in front of walls
## and players, and loses its momentum (also knockback). Runs in prediction too.

@export var distance: float = 250.0


func start(user: Player, input: InputFrame) -> void:
	var offset := InputFrame.aim_to_vector(input.aim) * distance
	var collision := user.move_and_collide(offset, true)
	user.position += collision.get_travel() if collision else offset
	user.velocity = Vector2.ZERO
