class_name PlayerMotor
## Platformer movement shared by the host simulation and (from M4) client prediction.
## compute_velocity() has no engine side effects, so it can be unit-tested and replayed;
## step() applies it to a CharacterBody2D.

## Physics layer number of one-way platforms (see project.godot layer names).
const ONE_WAY_LAYER := 2


## Per-player movement memory that is not part of the body itself.
class State:
	var prev_buttons: int = 0
	var air_jumps_left: int = 0
	var coyote_timer: float = 0.0
	var jump_buffer_timer: float = 0.0
	var drop_timer: float = 0.0
	## 1 = right, -1 = left. Also the shooting direction.
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
	if input.move_x != 0:
		state.facing = input.move_x

	if not on_floor:
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	if state.jump_buffer_timer > 0.0 and state.coyote_timer > 0.0:
		velocity.y = -stats.jump_velocity
		state.coyote_timer = 0.0
		state.jump_buffer_timer = 0.0
	elif just_pressed & InputFrame.JUMP and state.coyote_timer <= 0.0 and state.air_jumps_left > 0:
		# Air jumps need a fresh press; a buffered press only counts for ground jumps,
		# otherwise pressing jump just before landing would waste the double jump.
		velocity.y = -stats.jump_velocity
		state.air_jumps_left -= 1
		state.jump_buffer_timer = 0.0

	if on_floor and just_pressed & InputFrame.DOWN:
		state.drop_timer = stats.drop_through_time
	return velocity


static func _update_timers(on_floor: bool, just_pressed: int, state: State, stats: CharacterData, delta: float) -> void:
	if on_floor:
		state.coyote_timer = stats.coyote_time
		state.air_jumps_left = stats.air_jumps
	else:
		state.coyote_timer = maxf(state.coyote_timer - delta, 0.0)
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
	return move_toward(vx, target if move_x != 0 else 0.0, friction * delta)
