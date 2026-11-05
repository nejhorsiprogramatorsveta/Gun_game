class_name Projectile
extends Node2D
## A bullet flying in a straight line. Each tick it ray-casts from its old to its new
## position, so even fast bullets cannot pass through thin targets.
## Authoritative bullets (host/practice) hit walls and players; display-only bullets on
## clients only stop at walls – hits are decided by the host (PLAN.md D.5).
## Bullets pass through one-way platforms (they are not on the "world" layer) and, in 2 v 2,
## through the shooter's teammates.

signal hit_player(projectile: Projectile, player: Player)
signal finished(projectile: Projectile)

const WORLD_MASK := 1
const PLAYERS_MASK := 4
## Length of the visible streak behind the bullet (px).
const TRAIL_LENGTH := 40.0

var id := 0
var direction := Vector2.RIGHT
var weapon: WeaponData
var authoritative := false
var shooter_peer_id := 0
var shooter_team := Teams.NONE

var _exclude: Array[RID] = []
var _travelled := 0.0
## Client: shown right when the own player fires (before the host confirms the shot).
var predicted := false
var predicted_ms := 0


func setup(projectile_id: int, origin: Vector2, flight_direction: Vector2, weapon_data: WeaponData, shooter: Player) -> void:
	id = projectile_id
	position = origin
	direction = flight_direction.normalized()
	weapon = weapon_data
	authoritative = shooter != null
	if shooter:
		shooter_peer_id = shooter.peer_id
		shooter_team = shooter.team
		_exclude = [shooter.get_rid()]


func _physics_process(delta: float) -> void:
	advance(delta)


## Moves one physics step (ray-cast against walls and, if authoritative, players).
## Also used to fast-forward a shot that belongs to an earlier tick (InputBuffer catch-up).
func advance(delta: float) -> void:
	if is_queued_for_deletion():
		return
	var step := direction * weapon.projectile_speed * delta
	var mask := WORLD_MASK | (PLAYERS_MASK if authoritative else 0)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, mask, _exclude)
	# The muzzle can start inside a player standing right next to the shooter; still a hit.
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	while not hit.is_empty() and hit.collider is Player and Teams.allies(shooter_team, hit.collider.team):
		_exclude.append(hit.rid)  # fly through teammates (at most 3 of them)
		query.exclude = _exclude
		hit = get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider is Player:
			hit_player.emit(self, hit.collider)
		finish()
		return
	position += step
	_travelled += step.length()
	queue_redraw()
	if _travelled >= weapon.max_range:
		finish()


func finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit(self)
	queue_free()


func _draw() -> void:
	# The trail fades out behind the bullet and never sticks out behind the muzzle.
	var trail := minf(TRAIL_LENGTH, _travelled + 4.0)
	draw_line(-direction * trail, -direction * trail * 0.4, Color(1, 0.85, 0.4, 0.35), 2.0)
	draw_line(-direction * trail * 0.4, direction * 4.0, Color(1, 0.95, 0.65), 3.0)
