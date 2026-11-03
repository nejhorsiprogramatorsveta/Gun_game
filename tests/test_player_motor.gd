extends TestCase

const DT := 1.0 / 60.0

var stats := CharacterData.new()


func _step(state: PlayerMotor.State, velocity: Vector2, on_floor: bool, move_x: int = 0, buttons: int = 0) -> Vector2:
	return PlayerMotor.compute_velocity(velocity, on_floor, InputFrame.create(move_x, buttons), state, stats, DT)


func test_jump_from_floor() -> void:
	var state := PlayerMotor.State.new()
	var v := _step(state, Vector2.ZERO, true, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "ground jump sets jump velocity")


func test_holding_jump_does_not_rejump() -> void:
	var state := PlayerMotor.State.new()
	_step(state, Vector2.ZERO, true, 0, InputFrame.JUMP)
	var v := _step(state, Vector2.ZERO, true, 0, InputFrame.JUMP)
	check_eq(v.y, 0.0, "held jump is not a new press")


func test_walking_off_ledge_keeps_both_jumps() -> void:
	# Regression (bug reported 2026-11-03): walk off a ledge, wait, then jump twice.
	var state := PlayerMotor.State.new()
	_step(state, Vector2.ZERO, true)
	for i in 20:  # fall for a third of a second without jumping
		_step(state, Vector2(0, 300), false)
	var v := _step(state, Vector2(0, 300), false, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "first jump after walking off works")
	_step(state, v, false)
	v = _step(state, v, false, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "second jump after walking off works too")


func test_double_jump_then_no_more() -> void:
	var state := PlayerMotor.State.new()
	var v := _step(state, Vector2.ZERO, true, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "ground jump")
	_step(state, v, false)
	v = _step(state, v, false, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "air jump")
	_step(state, v, false)
	v = _step(state, Vector2(0, 100), false, 0, InputFrame.JUMP)
	check(v.y > 0.0, "no third jump before landing")


func test_jump_buffer_on_landing() -> void:
	var state := PlayerMotor.State.new()
	state.jumps_left = 0
	_step(state, Vector2(0, 300), false, 0, InputFrame.JUMP)
	var v := _step(state, Vector2.ZERO, true, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "jump pressed just before landing triggers on landing")


func test_run_accelerates_up_to_max_speed() -> void:
	var state := PlayerMotor.State.new()
	var v := Vector2.ZERO
	for i in 60:
		v = _step(state, v, true, 1)
	check_eq(v.x, stats.move_speed, "running reaches but does not exceed max speed")
	check_eq(state.facing, 1, "aiming right (default) faces right")


func test_facing_follows_aim_not_movement() -> void:
	var state := PlayerMotor.State.new()
	var aim_left := InputFrame.aim_from_vector(Vector2.LEFT)
	PlayerMotor.compute_velocity(Vector2.ZERO, true, InputFrame.create(1, 0, aim_left), state, stats, DT)
	check_eq(state.facing, -1, "running right while aiming left faces left")


func test_knockback_is_not_cancelled_instantly() -> void:
	var state := PlayerMotor.State.new()
	var v := _step(state, Vector2(1200, 0), false, 1)
	check(v.x > 1100.0, "holding a direction does not snap knockback speed down")


func test_drop_through_starts_timer() -> void:
	var state := PlayerMotor.State.new()
	_step(state, Vector2.ZERO, true, 0, InputFrame.DOWN)
	check(state.drop_timer > 0.0, "pressing down on the floor starts drop-through")
