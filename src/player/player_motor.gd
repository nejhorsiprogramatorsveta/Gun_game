class_name PlayerMotor
## Platformer movement shared by the host simulation and (from M4) client prediction.
## compute_velocity() has no engine side effects, so it can be unit-tested and replayed;
## step() applies it to a CharacterBody2D.

## Physics layer number of one-way platforms (see project.godot layer names).
## Players also collide with the "players" layer, so they can touch but never overlap.
const ONE_WAY_LAYER := 2


## Per-player movement memory that is not part of the body itself.
class State:
	var prev_buttons: int = 0
	## Jumps left before landing again: 1 ground jump + air jumps. Walking off a ledge
	## or being knocked off keeps all of them, so recovery never depends on timing.
	var jumps_left: int = 0
	var jump_buffer_timer: float = 0.0
	var drop_timer: float = 0.0
	## 1 = right, -1 = left: the side the player aims at.
	var facing: int = 1


static func step(body: CharacterBody2D, input: InputFrame, state: State, stats: CharacterData, delta: float) -> void:
	body.velocity = compute_velocity(body.velocity, body.is_on_floor(), input, state, stats, delta)
	body.set_collision_mask_value(ONE_WAY_LAYER, state.drop_timer <= 0.0)
	body.move_and_slide()


static func compute_velocity(velocity: Vector2, on_floor: bool, input: InputFrame, state: State, stats: CharacterData, delta: float) -> Vector2:
	var just_pressed := input.buttons & ~state.prev_buttons
	state.prev_buttons = input.buttons
	_update_timers(on_floor, just_pressed, state, stats, delta)

	velocity.x = _horizontal(velocity.x, on_floor, input.move_x, stats, delta)
	# The character looks where the player aims (mouse cursor), not where it runs.
	var aim_x := InputFrame.aim_to_vector(input.aim).x
	if absf(aim_x) > 0.01:
		state.facing = 1 if aim_x > 0.0 else -1

	if not on_floor:
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	# On the ground a recent (buffered) press is enough, so a press just before landing
	# still jumps. In the air only a fresh press jumps, so holding the key does nothing.
	var wants_jump := state.jump_buffer_timer > 0.0 if on_floor else bool(just_pressed & InputFrame.JUMP)
	if wants_jump and state.jumps_left > 0:
		velocity.y = -stats.jump_velocity
		state.jumps_left -= 1
		state.jump_buffer_timer = 0.0

	if on_floor and just_pressed & InputFrame.DOWN:
		state.drop_timer = stats.drop_through_time
	return velocity


static func _update_timers(on_floor: bool, just_pressed: int, state: State, stats: CharacterData, delta: float) -> void:
	if on_floor:
		state.jumps_left = 1 + stats.air_jumps
	if just_pressed & InputFrame.JUMP:
		state.jump_buffer_timer = stats.jump_buffer_time
	else:
		state.jump_buffer_timer = maxf(state.jump_buffer_timer - delta, 0.0)
	state.drop_timer = maxf(state.drop_timer - delta, 0.0)


static func _horizontal(vx: float, on_floor: bool, move_x: int, stats: CharacterData, delta: float) -> float:
	var target := move_x * stats.move_speed
	var steering_allowed := move_x != 0 and (absf(vx) <= stats.move_speed or signf(vx) != move_x)
	if steering_allowed:
		var accel := stats.ground_acceleration if on_floor else stats.air_acceleration
		return move_toward(vx, target, accel * delta)
	# No input, or faster than running speed (knockback): only friction slows us down,
	# so holding a direction cannot cancel knockback instantly.
	var friction := stats.ground_friction if on_floor else stats.air_friction
	if absf(vx) > stats.move_speed:
		friction = minf(friction, stats.knockback_friction)
	return move_toward(vx, target if move_x != 0 else 0.0, friction * delta)
