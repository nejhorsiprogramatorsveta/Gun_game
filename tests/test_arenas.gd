extends TestCase


func test_three_arenas_and_fallback() -> void:
	check_eq(ContentDB.arena_ids(), [&"hanging_bridges", &"rooftops", &"temple_steps"] as Array[StringName], "arenas (add new ones here)")
	check_eq(ContentDB.arena_or_default("").id, ContentDB.DEFAULT_ARENA_ID, "nothing chosen -> default")
	check_eq(ContentDB.arena_or_default("deleted_map").id, ContentDB.DEFAULT_ARENA_ID, "unknown id -> default")


func test_every_arena_has_safe_spawn_points() -> void:
	for id in ContentDB.arena_ids():
		var arena: Arena = ContentDB.arena_or_default(String(id)).scene.instantiate()
		var spawns := arena.spawn_points()
		check(spawns.size() >= 4, "%s: a spawn point for each of 4 players" % id)
		for spawn in spawns:
			check(not arena.is_out_of_bounds(spawn), "%s: spawn %s inside the arena" % [id, spawn])
			check(_ground_below(arena, spawn) < 120.0, "%s: platform right under spawn %s" % [id, spawn])
		arena.free()


## Distance from `point` down to the top of the nearest platform below it (INF = none).
func _ground_below(arena: Arena, point: Vector2) -> float:
	var best := INF
	for child in arena.get_children():
		var platform := child as Platform
		if platform == null:
			continue
		var left := platform.position.x
		if point.x >= left and point.x <= left + platform.size.x and platform.position.y >= point.y:
			best = minf(best, platform.position.y - point.y)
	return best
