class_name Projectile
extends Node2D
## A bullet flying in a straight line. Each tick it ray-casts from its old to its new
## position, so even fast bullets cannot pass through thin targets.
## Authoritative bullets (host/practice) hit walls and players; display-only bullets on
## clients only stop at walls – hits are decided by the host (PLAN.md D.5).
## Bullets pass through one-way platforms (they are not on the "world" layer).

signal hit_player(projectile: Projectile, player: Player)
signal finished(projectile: Projectile)

const WORLD_MASK := 1
const PLAYERS_MASK := 4

var id := 0
var direction := Vector2.RIGHT
var weapon: WeaponData
var authoritative := false

var _exclude: Array[RID] = []
var _travelled := 0.0


func setup(projectile_id: int, origin: Vector2, flight_direction: Vector2, weapon_data: WeaponData, shooter: Player) -> void:
	id = projectile_id
	position = origin
	direction = flight_direction.normalized()
	weapon = weapon_data
	authoritative = shooter != null
	if shooter:
		_exclude = [shooter.get_rid()]


func _physics_process(delta: float) -> void:
	var step := direction * weapon.projectile_speed * delta
	var mask := WORLD_MASK | (PLAYERS_MASK if authoritative else 0)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, mask, _exclude)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider is Player:
			hit_player.emit(self, hit.collider)
		finish()
		return
	position += step
	_travelled += step.length()
	if _travelled >= weapon.max_range:
		finish()


func finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit(self)
	queue_free()


func _draw() -> void:
	draw_line(-direction * 12.0, direction * 4.0, Color(1, 0.93, 0.55), 3.0)
