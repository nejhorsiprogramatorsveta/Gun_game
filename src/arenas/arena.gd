class_name Arena
extends Node2D
## Base script of every arena scene. An arena provides platforms (Platform nodes),
## spawn points (Marker2D children of "SpawnPoints"), the area outside which players die
## and a Camera2D "Camera" that frames it (its zoom sets how big everything looks;
## 0.6 = everything at 60 % of the original size).

## Falling below this rectangle or leaving it sideways costs a life (after
## MatchRules.out_of_bounds_grace). The top is open, so knockback or a future flying
## ability can send players high up without killing them.
@export var kill_rect := Rect2(-700, -800, 2680, 1900)


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for marker: Node2D in $SpawnPoints.get_children():
		points.append(marker.position)
	return points


func is_out_of_bounds(world_position: Vector2) -> bool:
	return world_position.y > kill_rect.end.y or world_position.x < kill_rect.position.x \
			or world_position.x > kill_rect.end.x


## The arena's rising lava (Peklo), or null.
func lava() -> Lava:
	return get_node_or_null("Lava") as Lava


## The spawn point farthest from everyone in `occupied`, so nobody respawns onto a player.
## Only points whose feet are above `max_feet_y` count (rising lava, Lava.safe_feet_y); if
## none is, the highest point.
func free_spawn_point(occupied: Array[Vector2], max_feet_y: float = INF) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := -1.0
	var highest := Vector2(0.0, INF)
	for point in spawn_points():
		if point.y < highest.y:
			highest = point
		if point.y + Player.BODY_SIZE.y / 2.0 > max_feet_y:
			continue
		var nearest := INF
		for position in occupied:
			nearest = minf(nearest, point.distance_to(position))
		if nearest > best_distance:
			best_distance = nearest
			best = point
	return best if best_distance >= 0.0 else highest
