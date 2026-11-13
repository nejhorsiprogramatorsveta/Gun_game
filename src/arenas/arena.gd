class_name Arena
extends Node2D
## Base script of every arena scene. An arena provides platforms (Platform nodes),
## spawn points (Marker2D children of "SpawnPoints"; at least 6, the first six in the order
## left, right, left, right, centre-left, centre-right - match slot = spawn, so teams start
## together, see Teams.START_SLOTS; more may follow for respawns), the area outside which players die
## and a Camera2D "Camera" that frames it (its zoom sets how big everything looks;
## 0.6 = everything at 60 % of the original size).

## Falling below this rectangle or leaving it sideways costs a life (after
## MatchRules.out_of_bounds_grace). The top is open, so knockback or a future flying
## ability can send players high up without killing them.
@export var kill_rect := Rect2(-700, -800, 2680, 1900)

## A player is carried only if it was simulated at most this many ticks ago (not after a
## respawn or a long gap in its inputs).
const MAX_CARRY_TICKS := 30

var _moving: Array[MovingPlatform] = []


func _ready() -> void:
	for child in get_children():
		if child is MovingPlatform:
			_moving.append(child)
	place_platforms(0)


func has_moving_platforms() -> bool:
	return not _moving.is_empty()


## Moves every MovingPlatform to where it is at host tick `tick`.
func place_platforms(tick: int) -> void:
	for platform in _moving:
		platform.place(tick)


## Shared by the host and the own client's prediction at the start of Player.simulate:
## platforms to `tick`, and a player who stood on a moving platform when last simulated
## (Player.world_tick) moves along with it: sideways by the platform's motion, and the
## feet are put right on its top. (Adding the vertical motion instead would leave the feet
## a pixel inside a rising jump-through platform whenever the client's estimate of the host
## tick is one off, and the player would fall through it.)
func prepare(player: Player, tick: int) -> void:
	place_platforms(tick)
	var last := player.world_tick
	player.world_tick = tick
	if _moving.is_empty() or last < 0 or last >= tick or tick - last > MAX_CARRY_TICKS \
			or not player.motor_state.on_floor or player.motor_state.drop_timer > 0.0:
		return
	var feet := player.position + Vector2(0.0, Player.BODY_SIZE.y / 2.0)
	for platform in _moving:
		if platform.supports(feet, Player.BODY_SIZE.x / 2.0, last):
			var top := platform.base_position + platform.offset_at(tick)
			player.position.x += platform.offset_at(tick).x - platform.offset_at(last).x
			player.position.y = top.y - Player.BODY_SIZE.y / 2.0 - player.safe_margin
			return


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
