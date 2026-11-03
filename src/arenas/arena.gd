class_name Arena
extends Node2D
## Base script of every arena scene. An arena provides platforms (Platform nodes),
## spawn points (Marker2D children of "SpawnPoints") and the area outside which players die.

## Leaving this rectangle (e.g. falling below it) costs a life.
@export var kill_rect := Rect2(-400, -600, 2080, 1500)


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for marker: Node2D in $SpawnPoints.get_children():
		points.append(marker.position)
	return points


func is_out_of_bounds(world_position: Vector2) -> bool:
	return not kill_rect.has_point(world_position)
