class_name Arena
extends Node2D
## Base script of every arena scene. An arena provides platforms (Platform nodes),
## spawn points (Marker2D children of "SpawnPoints"), the area outside which players die
## and a Camera2D "Camera" that frames it (its zoom sets how big everything looks;
## 0.6 = everything at 60 % of the original size).

## Leaving this rectangle (e.g. falling below it) costs a life.
@export var kill_rect := Rect2(-700, -800, 2680, 1900)


func spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for marker: Node2D in $SpawnPoints.get_children():
		points.append(marker.position)
	return points


func is_out_of_bounds(world_position: Vector2) -> bool:
	return not kill_rect.has_point(world_position)
