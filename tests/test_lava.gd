extends TestCase
## Peklo: only jump-through platforms, rising lava (Lava) and respawns above it.

const DT := 1.0 / 60.0


func _hell() -> Arena:
	return ContentDB.arena_or_default("hell").scene.instantiate()


func _player(lives: int, deaths: int, position: Vector2) -> Player:
	var player := Player.new()
	player.lives = lives
	player.deaths = deaths
	player.position = position
	return player


func test_hell_has_only_jump_through_platforms_and_a_long_top_bridge() -> void:
	var arena := _hell()
	var platforms: Array[Platform] = []
	for child in arena.get_children():
		if child is Platform:
			platforms.append(child)
	check(platforms.size() >= 5, "a top bridge and smaller platforms under it")
	var top: Platform = arena.get_node("TopBridge")
	for platform in platforms:
		check(platform.one_way, "%s can be jumped through" % platform.name)
		if platform != top:
			check(platform.position.y > top.position.y, "%s is under the top bridge" % platform.name)
			check(platform.size.x * 3.0 < top.size.x, "%s is much shorter than the top bridge" % platform.name)
	var lava := arena.lava()
	check(lava != null, "Peklo has lava")
	var bridge_bottom := top.position.y + top.size.y
	check(lava.top_y > bridge_bottom and lava.top_y < bridge_bottom + 40.0, "lava stops just under the top bridge (%.0f)" % lava.top_y)
	for platform in platforms:
		check(lava.start_y > platform.position.y + 100.0, "lava starts well below %s" % platform.name)
	var rooftops: Arena = ContentDB.arena_or_default("rooftops").scene.instantiate()
	check(rooftops.lava() == null, "other arenas have no lava")
	rooftops.free()
	arena.free()


func test_lava_rises_when_someone_has_three_lives_and_stops_under_the_bridge() -> void:
	var arena := _hell()
	var lava := arena.lava()
	lava._ready()
	var rose := []
	lava.started_rising.connect(func() -> void: rose.append(true))
	var players: Array = [_player(5, 0, Vector2.ZERO), _player(4, 1, Vector2.ZERO)]
	lava.tick(players, 5, true, 1.0)
	check(not lava.rising and is_equal_approx(lava.level, lava.start_y), "4 lives: the lava waits")
	players[1].lives = 3
	lava.tick(players, 5, true, 1.0)
	check(lava.rising and rose.size() == 1, "3 lives: it starts rising (once)")
	check(is_equal_approx(lava.level, lava.start_y - lava.rise_speed), "rises at rise_speed")
	for i in 600:
		lava.tick(players, 5, true, 1.0)
	check_eq(lava.level, lava.top_y, "stops at top_y")
	check_eq(rose.size(), 1, "the alert fires only once")
	for player in players:
		player.free()
	arena.free()


func test_practice_counts_deaths_and_clients_follow_the_host() -> void:
	var lava := _hell().lava()
	lava._ready()
	var practice: Array = [_player(0, 1, Vector2.ZERO)]
	lava.tick(practice, 5, false, DT)
	check(not lava.rising, "practice: endless lives, 1 death is not enough")
	practice[0].deaths = 2
	lava.tick(practice, 5, false, DT)
	check(lava.rising, "practice: after 2 deaths (5 - 2 = 3 lives) the lava rises")
	var client := _hell().lava()
	client._ready()
	client.show_level(client.start_y)
	check(not client.rising, "client: the level at the start is not rising")
	client.show_level(client.start_y - 20.0)
	check(client.rising and is_equal_approx(client.level, client.start_y - 20.0), "client shows the host's level")
	practice[0].free()
	lava.get_parent().free()
	client.get_parent().free()


func test_touching_lava_and_safe_respawns() -> void:
	var arena := _hell()
	var lava := arena.lava()
	lava._ready()
	var above := _player(5, 0, Vector2(400, lava.level - Player.BODY_SIZE.y / 2.0 - 1.0))
	var feet_in := _player(5, 0, Vector2(400, lava.level - Player.BODY_SIZE.y / 2.0 + 1.0))
	check(not lava.touches(above) and lava.touches(feet_in), "feet touching the surface = in the lava")
	var occupied: Array[Vector2] = []
	var low_spawn_used := false
	for i in 20:
		var spawn := arena.free_spawn_point(occupied, lava.safe_feet_y())
		low_spawn_used = low_spawn_used or spawn.y > lava.top_y
		occupied.append(spawn)
	check(low_spawn_used, "before the lava rises the lower platforms are used too")
	lava.rising = true
	for i in 20:
		var spawn := arena.free_spawn_point([Vector2(randf_range(0, 1280), randf_range(0, 700))] as Array[Vector2], lava.safe_feet_y())
		check(spawn.y + Player.BODY_SIZE.y / 2.0 < lava.top_y, "rising lava: respawn above its final level (%s)" % spawn)
	check_eq(arena.free_spawn_point([], -1000.0), Vector2(330, 210), "no safe point at all: the highest one")
	for node in [above, feet_in, arena]:
		node.free()


func test_snapshot_carries_the_lava_level() -> void:
	var states: Array[Dictionary] = []
	check_eq(NetCodec.decode_snapshot(NetCodec.encode_snapshot(5, 0, states)).lava, -1, "no lava by default")
	check_eq(NetCodec.decode_snapshot(NetCodec.encode_snapshot(5, 0, states, 612)).lava, 612, "lava level travels")
	var client := MatchClient.new({} as Dictionary[int, Player], 2, null, null, NetLog.new())
	client._apply_snapshot({"tick": 1, "countdown": 0, "lava": 433, "states": []})
	check_eq(client.lava_y, 433, "the client takes the level from the newest snapshot")
