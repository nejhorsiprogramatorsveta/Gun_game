extends TestCase
## Moving platforms (Hobitín, user 2026-11-13): position from the host tick only, players
## carried by Arena.prepare, and the client's replay ends exactly where the host did.

const DELTA := 1.0 / 60.0


func _hobbiton() -> Arena:
	var arena: Arena = ContentDB.arena_or_default("hobbiton").scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(arena)
	return arena


func _player_on(arena: Arena, platform_name: String) -> Player:
	var platform: MovingPlatform = arena.get_node(platform_name)
	var player: Player = load("res://src/player/player.tscn").instantiate()
	player.character = ContentDB.get_character(&"balvan")
	player.arena = arena
	arena.add_child(player)
	arena.place_platforms(0)
	player.reset_to(platform.base_position + Vector2(platform.size.x / 2.0, -Player.BODY_SIZE.y / 2.0))
	player.motor_state.on_floor = true
	player.world_tick = 0
	return player


func _input(tick: int, move: int = 0) -> InputFrame:
	var input := InputFrame.create(move, 0, 0, tick & 0xFFFF)
	input.tick = tick
	return input


func test_hobbiton_moves_most_but_not_all_platforms() -> void:
	var arena: Arena = ContentDB.arena_or_default("hobbiton").scene.instantiate()
	var moving := 0
	var still := 0
	for child in arena.get_children():
		if child is MovingPlatform:
			moving += 1
		elif child is Platform:
			still += 1
	check(moving > still and still > 0, "most platforms move, some do not (%d moving, %d still)" % [moving, still])
	check(arena.spawn_points().size() >= 6, "spawns for 6 players")
	arena.free()


func test_position_depends_only_on_the_tick() -> void:
	var platform := MovingPlatform.new()
	platform.travel = Vector2(300, 0)
	platform.period = 9.0
	check(platform.offset_at(0).is_zero_approx(), "starts at its scene position")
	check(platform.offset_at(270).is_equal_approx(platform.travel), "the far end after half a period (4.5 s)")
	check(platform.offset_at(123).is_equal_approx(platform.offset_at(123 + 540)), "repeats every period")
	var fastest := 0.0
	for tick in 540:
		fastest = maxf(fastest, platform.offset_at(tick + 1).distance_to(platform.offset_at(tick)))
	check(fastest < 2.0, "slow enough to ride (%.2f px per tick)" % fastest)
	platform.phase = 0.5
	check(platform.offset_at(0).is_equal_approx(platform.travel), "phase 0.5 starts at the far end")
	platform.free()


func test_hobbiton_platforms_are_not_too_fast() -> void:
	var arena: Arena = ContentDB.arena_or_default("hobbiton").scene.instantiate()
	for child in arena.get_children():
		var platform := child as MovingPlatform
		if platform:
			var top_speed := PI * platform.travel.length() / platform.period
			check(top_speed <= 120.0, "%s: top speed %.0f px/s" % [platform.name, top_speed])
	arena.free()


func test_a_player_rides_along() -> void:
	var arena := _hobbiton()
	await physics_step()
	for platform_name in ["SwingLeft", "LiftLeft", "Ferry"]:
		var player := _player_on(arena, platform_name)
		var platform: MovingPlatform = arena.get_node(platform_name)
		var start_offset := player.position.x - platform.base_position.x
		for tick in range(1, 121):
			player.simulate(_input(tick), DELTA)
		var top := platform.base_position + platform.offset_at(120)
		check(player.motor_state.on_floor, "%s: still standing on it after 2 s" % platform_name)
		check(absf(player.position.y + Player.BODY_SIZE.y / 2.0 - top.y) < 2.0, "%s: feet on its top (%s vs %s)" % [platform_name, player.position, top])
		check(absf(player.position.x - top.x - start_offset) < 3.0, "%s: moved along with it" % platform_name)
		player.free()
	arena.free()


func test_client_replay_ends_where_the_host_did() -> void:
	var arena := _hobbiton()
	await physics_step()
	for platform_name in ["SwingLeft", "LiftRight", "HighLeft"]:
		var player := _player_on(arena, platform_name)
		var inputs: Array[InputFrame] = []
		var state_at_30: Dictionary
		for tick in range(1, 91):
			var input := _input(tick, 1 if tick > 40 and tick < 48 else 0)  # a short step mid-ride
			if tick == 70:
				input.buttons = InputFrame.JUMP
			inputs.append(input)
			player.simulate(input, DELTA)
			if tick == 30:
				state_at_30 = player.snapshot_state()
		var host_end := player.position
		# The client got the snapshot of tick 30 and replays its own inputs 31..90.
		player.restore_state(state_at_30)
		player.world_tick = 30
		for input in inputs.slice(30):
			player.simulate(input, DELTA)
		check(player.position.distance_to(host_end) < 0.01, "%s: replay = host (%s vs %s)" % [platform_name, player.position, host_end])
		player.free()
	arena.free()


func test_client_estimates_the_host_tick_of_its_inputs() -> void:
	var client := MatchClient.new({} as Dictionary[int, Player], 2, null, null, null)
	client._base_tick = 1000
	client._base_seq = 65530
	check_eq([client.tick_for(65530), client.tick_for(65535), client.tick_for(3), client.tick_for(65520)],
			[1000, 1005, 1009, 990], "one input per tick after the snapshot, also across the u16 wrap")
