class_name TeleportAbility
extends AbilityData
## Stín: always jumps as far as possible towards the mouse cursor, up to `distance` px
## (user 2026-11-13: "it sometimes did not teleport"). Only solid blocks stop it; jump-through
## platforms and players do not. Along a solid surface it slides on like move_and_slide, so
## aiming slightly into the floor he stands on still carries him sideways (before, the floor
## stopped the whole jump at 0 px). Loses its momentum (also knockback). Runs in the own
## client's prediction too, so it tests only the static world, never other players.

## Solid surfaces the jump may slide along (a corner = 2).
const MAX_SLIDES := 4

@export var distance: float = 250.0


func start(user: Player, input: InputFrame) -> void:
	user.position = destination(user, InputFrame.aim_to_vector(input.aim) * distance)
	user.velocity = Vector2.ZERO


## Where a jump by `motion` ends; the body is not moved.
static func destination(user: Player, motion: Vector2) -> Vector2:
	var saved_mask := user.collision_mask
	user.collision_mask = Platform.WORLD_LAYER_BIT
	var at := user.global_transform
	for slide in MAX_SLIDES:
		var collision := KinematicCollision2D.new()
		if not user.test_move(at, motion, collision):
			at.origin += motion
			break
		at.origin += collision.get_travel()
		motion = collision.get_remainder().slide(collision.get_normal())
		if motion.length_squared() < 1.0:
			break
	user.collision_mask = saved_mask
	return user.position + (at.origin - user.global_position)
