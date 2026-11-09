extends TestCase
## Practice target brain (PracticeDummy): walks and pauses, turns before edges, never
## steers in the air. Physics probes are replaced by a stub; a scene smoke test covers them.

const DT := 1.0 / 60.0


func _dummy_player() -> Player:
	var player := Player.new()
	player.character = ContentDB.default_character()
	player.motor_state.on_floor = true
	return player


func _run(dummy: PracticeDummy, ticks: int) -> Array[InputFrame]:
	var inputs: Array[InputFrame] = []
	for i in ticks:
		inputs.append(dummy.next_input(DT))
	return inputs


func test_walks_and_pauses_but_never_towards_a_blocked_side() -> void:
	var player := _dummy_player()
	var dummy := PracticeDummy.new(player, 7)
	dummy.can_walk = func(direction: int) -> bool: return direction == 1  # edge on the left
	var moves := {}
	for input in _run(dummy, 60 * 30):
		moves[input.move_x] = true
		check(input.move_x != -1, "never walks towards the edge")
		check(input.buttons & ~InputFrame.JUMP == 0, "never shoots, reloads or uses the ability")
	check(moves.has(1) and moves.has(0), "walks right and stands still in between")
	player.free()


func test_stands_when_both_sides_are_blocked() -> void:
	var player := _dummy_player()
	var dummy := PracticeDummy.new(player, 3)
	dummy.can_walk = func(_direction: int) -> bool: return false
	for input in _run(dummy, 60 * 20):
		check_eq(input.move_x, 0, "no room: stays on the spot")
	player.free()


func test_no_steering_in_the_air_and_jumps_only_standing_still() -> void:
	var player := _dummy_player()
	var dummy := PracticeDummy.new(player, 11)
	dummy.can_walk = func(_direction: int) -> bool: return true
	player.motor_state.on_floor = false
	for input in _run(dummy, 60 * 5):
		check_eq([input.move_x, input.buttons], [0, 0], "in the air (e.g. knocked back): no input")
	player.motor_state.on_floor = true
	var jumps := 0
	for i in 60 * 60:
		player.velocity.x = 0.0
		var input := dummy.next_input(DT)
		if input.buttons & InputFrame.JUMP:
			jumps += 1
			check_eq(input.move_x, 0, "jumps on the spot")
	check(jumps > 0, "jumps now and then (%d)" % jumps)
	player.free()
