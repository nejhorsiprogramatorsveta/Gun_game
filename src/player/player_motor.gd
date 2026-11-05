class_name PlayerMotor
## Platformer movement shared by the host simulation and client prediction.
## compute_velocity() has no engine side effects, so it can be unit-tested and replayed;
## step() applies it to a CharacterBody2D.

## Physics layer number of one-way platforms (see project.godot layer names).
## Players also collide with the "players" layer, so they can touch but never overlap.
const ONE_WAY_LAYER := 2
## Sideways speed (px/s) of a player sliding off another player's head.
const HEAD_SLIDE_SPEED := 300.0


## Per-player movement memory that is not part of the body itself.
class State:
	var prev_buttons: int = 0
	## Jumps left before landing again: 1 ground jump + air jumps. Walking off a ledge
	## or being knocked off keeps all of them, so recovery never depends on timing.
	var jumps_left: int = 0
	var jump_buffer_timer: float = 0.0
	var drop_timer: float = 0.0
	## Last step's contact, explicitly restored when client prediction rewinds the body.
	var on_floor: bool = false
	## 1 = right, -1 = left: the side the player aims at.
	var facing: int = 1
	## Movement ability running (JetpackAbility.start): seconds of thrust left.
	var boost_time_left: float = 0.0
	## Slowing cloud (AreaEffects.slow_for), set before each step: running and jump multipliers.
	var speed_scale: float = 1.0
	var jump_scale: float = 1.0


static func step(body: CharacterBody2D, input: InputFrame, state: State, stats: CharacterData, delta: float) -> void:
	body.velocity = compute_velocity(body.velocity, state.on_floor, input, state, stats, delta)
	body.set_collision_mask_value(ONE_WAY_LAYER, state.drop_timer <= 0.0)
	body.move_and_slide()
	state.on_floor = body.is_on_floor()
	_slide_off_heads(body, delta)


## Players may touch but never stand on each other: whoever lands on (or respawns onto)
## another player's head slides off sideways, so nobody gets stuck under someone.
static func _slide_off_heads(body: CharacterBody2D, delta: float) -> void:
	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		var other := collision.get_collider() as CharacterBody2D
		if other == null or collision.get_normal().y > -0.7:
			continue
		var side := signf(body.global_position.x - other.global_position.x)
		if side == 0.0:
			side = 1.0 if body.get_instance_id() > other.get_instance_id() else -1.0
		body.move_and_collide(Vector2(side * HEAD_SLIDE_SPEED * delta, 0.0))
		return


static func compute_velocity(velocity: Vector2, on_floor: bool, input: InputFrame, state: State, stats: CharacterData, delta: float) -> Vector2:
	var just_pressed := input.buttons & ~state.prev_buttons
	state.prev_buttons = input.buttons
	_update_timers(on_floor, just_pressed, state, stats, delta)
	if state.boost_time_left > 0.0 and stats.ability is JetpackAbility:
		return _jetpack(velocity, input, state, stats, delta)

	velocity.x = _horizontal(velocity.x, on_floor, input.move_x, stats.move_speed * state.speed_scale, stats, delta)
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
		velocity.y = -stats.jump_velocity * state.jump_scale
		state.jumps_left -= 1
		state.jump_buffer_timer = 0.0

	if on_floor and just_pressed & InputFrame.DOWN:
		state.drop_timer = stats.drop_through_time
	return velocity


## Jetpack: thrust towards the ability's lift speed instead of gravity; running/steering
## works as in the air, so the player can fly sideways onto a platform.
static func _jetpack(velocity: Vector2, input: InputFrame, state: State, stats: CharacterData, delta: float) -> Vector2:
	var jet := stats.ability as JetpackAbility
	state.boost_time_left = maxf(state.boost_time_left - delta, 0.0)
	velocity.x = _horizontal(velocity.x, false, input.move_x, stats.move_speed * state.speed_scale, stats, delta)
	velocity.y = move_toward(velocity.y, -jet.lift_speed, jet.thrust * delta)
	var aim_x := InputFrame.aim_to_vector(input.aim).x
	if absf(aim_x) > 0.01:
		state.facing = 1 if aim_x > 0.0 else -1
	return velocity


static func _update_timers(on_floor: bool, just_pressed: int, state: State, stats: CharacterData, delta: float) -> void:
	if on_floor:
		state.jumps_left = 1 + stats.air_jumps
	if just_pressed & InputFrame.JUMP:
		state.jump_buffer_timer = stats.jump_buffer_time
	else:
		state.jump_buffer_timer = maxf(state.jump_buffer_timer - delta, 0.0)
	state.drop_timer = maxf(state.drop_timer - delta, 0.0)


static func _horizontal(vx: float, on_floor: bool, move_x: int, move_speed: float, stats: CharacterData, delta: float) -> float:
	var target := move_x * move_speed
	var steering_allowed := move_x != 0 and (absf(vx) <= move_speed or signf(vx) != move_x)
	if steering_allowed:
		var accel := stats.ground_acceleration if on_floor else stats.air_acceleration
		return move_toward(vx, target, accel * delta)
	# No input, or faster than running speed (knockback): only friction slows us down,
	# so holding a direction cannot cancel knockback instantly.
	var friction := stats.ground_friction if on_floor else stats.air_friction
	if absf(vx) > move_speed:
		friction = minf(friction, stats.knockback_friction)
	return move_toward(vx, target if move_x != 0 else 0.0, friction * delta)
