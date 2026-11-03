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


func test_coyote_jump_after_leaving_ledge() -> void:
	var state := PlayerMotor.State.new()
	_step(state, Vector2.ZERO, true)
	var v := _step(state, Vector2.ZERO, false, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "jump right after leaving ground uses coyote time")
	check_eq(state.air_jumps_left, stats.air_jumps, "coyote jump does not consume an air jump")


func test_double_jump_then_no_more() -> void:
	var state := PlayerMotor.State.new()
	_step(state, Vector2.ZERO, true)
	for i in 10:  # fall long enough for coyote time to expire
		_step(state, Vector2.ZERO, false)
	var v := _step(state, Vector2.ZERO, false, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "first air jump works")
	_step(state, Vector2.ZERO, false)
	v = _step(state, Vector2(0, 100), false, 0, InputFrame.JUMP)
	check(v.y > 0.0, "no jump when air jumps are used up")


func test_jump_buffer_on_landing() -> void:
	var state := PlayerMotor.State.new()
	state.air_jumps_left = 0
	_step(state, Vector2(0, 300), false, 0, InputFrame.JUMP)
	var v := _step(state, Vector2.ZERO, true, 0, InputFrame.JUMP)
	check_eq(v.y, -stats.jump_velocity, "jump pressed just before landing triggers on landing")


func test_run_accelerates_up_to_max_speed() -> void:
	var state := PlayerMotor.State.new()
	var v := Vector2.ZERO
	for i in 60:
		v = _step(state, v, true, 1)
	check_eq(v.x, stats.move_speed, "running reaches but does not exceed max speed")
	check_eq(state.facing, 1, "facing follows input")


func test_knockback_is_not_cancelled_instantly() -> void:
	var state := PlayerMotor.State.new()
	var v := _step(state, Vector2(1200, 0), false, 1)
	check(v.x > 1100.0, "holding a direction does not snap knockback speed down")


func test_drop_through_starts_timer() -> void:
	var state := PlayerMotor.State.new()
	_step(state, Vector2.ZERO, true, 0, InputFrame.DOWN)
	check(state.drop_timer > 0.0, "pressing down on the floor starts drop-through")
