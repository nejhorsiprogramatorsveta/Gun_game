extends TestCase

var arena: Arena = load("res://src/arenas/arena_rooftops.tscn").instantiate()


func test_top_is_open_but_bottom_and_sides_kill() -> void:
	var rect := arena.kill_rect
	check(not arena.is_out_of_bounds(Vector2(rect.get_center().x, rect.position.y - 5000)), "far above the arena is allowed")
	check(arena.is_out_of_bounds(Vector2(rect.get_center().x, rect.end.y + 1)), "below the arena is out")
	check(arena.is_out_of_bounds(Vector2(rect.position.x - 1, 0)), "left side is out")
	check(arena.is_out_of_bounds(Vector2(rect.end.x + 1, 0)), "right side is out")


func test_free_spawn_point_avoids_players() -> void:
	var points := arena.spawn_points()
	var occupied: Array[Vector2] = [points[0]]
	check(arena.free_spawn_point(occupied) != points[0], "never the occupied spawn point")
	check(arena.free_spawn_point([] as Array[Vector2]) in points, "always one of the arena's spawn points")
