class_name HomingRocket
extends Area2D
## Host-owned guided projectile. Bullets can slow it, never destroy it.
## RocketSystem advances it explicitly after the players have moved; clients only
## extrapolate the flight between host updates and never decide impacts.

signal player_hit(attacker_peer_id: int, target: Player)
signal exploded(rocket: HomingRocket)

const COLLISION_LAYER := 16
const TERRAIN_MASK := 1 | 2
const PLAYERS_MASK := 4
const HIT_RADIUS := 12.0
var id := 0
var owner_peer_id := 0
var owner_team := Teams.NONE
var authoritative := false
var ability: HomingRocketAbility
var direction := Vector2.RIGHT
var speed := 0.0
var age := 0.0
var detonated := false
var slow_time_left := 0.0


func _init() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	monitoring = false
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	collision.shape = circle
	add_child(collision)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3


func setup(rocket_id: int, at: Vector2, flight_direction: Vector2, data: HomingRocketAbility,
		owner_id: int, team: int, is_authority: bool) -> void:
	id = rocket_id
	position = at
	direction = flight_direction.normalized() if not flight_direction.is_zero_approx() else Vector2.RIGHT
	ability = data
	speed = ability.speed
	owner_peer_id = owner_id
	owner_team = team
	authoritative = is_authority
	# Client bullets are visual only; only the host's copy is a hittable area.
	collision_layer = COLLISION_LAYER if authoritative else 0


## Re-evaluated from the current rocket position every tick. Hidden/eliminated,
## respawning and allied players are never chosen as a homing target.
func nearest_target(players: Array) -> Player:
	var nearest: Player
	var nearest_distance := INF
	for candidate: Player in players:
		if not is_instance_valid(candidate) or candidate.peer_id == owner_peer_id or not candidate.visible \
				or candidate.invulnerable or Teams.allies(owner_team, candidate.team):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


## Accepted hits consume the bullet in Projectile, but never detonate the rocket.
func slow_by_shot(shooter_id: int, shooter_team: int) -> bool:
	if not authoritative or detonated or shooter_id == owner_peer_id or Teams.allies(owner_team, shooter_team):
		return false
	speed = maxf(ability.minimum_speed, speed * ability.hit_speed_scale)
	slow_time_left = ability.slow_duration
	queue_redraw()
	return true


func advance(delta: float, players: Array) -> void:
	if detonated or is_queued_for_deletion():
		return
	age += delta
	if authoritative:
		if age >= ability.lifetime:
			explode(players)
			return
		var target := nearest_target(players)
		if target:
			var offset := target.global_position - global_position
			if not offset.is_zero_approx():
				direction = Vector2.from_angle(rotate_toward(direction.angle(), offset.angle(), ability.turn_rate * delta))
		slow_time_left = maxf(slow_time_left - delta, 0.0)
		if slow_time_left <= 0.0:
			speed = move_toward(speed, ability.speed, ability.recovery_acceleration * delta)
	var step := direction * speed * delta
	if authoritative and _impact(step, players):
		return
	position += step
	queue_redraw()


func _impact(step: Vector2, players: Array) -> bool:
	var exclude: Array[RID] = []
	for candidate: Player in players:
		if not candidate.visible or candidate.invulnerable or candidate.peer_id == owner_peer_id \
				or Teams.allies(owner_team, candidate.team):
			exclude.append(candidate.get_rid())
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, TERRAIN_MASK | PLAYERS_MASK, exclude)
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	global_position = hit.position
	explode(players, hit.collider as Player)
	return true


## Everyone in the blast can be pushed, including Bibi and his teammates.
## The direct victim follows the incoming flight, the remaining victims the radius.
func explode(players: Array, direct_target: Player = null) -> void:
	if detonated:
		return
	detonated = true
	if authoritative:
		for target: Player in players:
			if not is_instance_valid(target) or not target.visible or target.invulnerable:
				continue
			var offset := target.global_position - global_position
			if target != direct_target and offset.length() > ability.radius:
				continue
			var push_direction := direction if target == direct_target or offset.is_zero_approx() else offset.normalized()
			push_direction = (push_direction + Vector2(0, -ability.lift)).normalized()
			target.take_hit(push_direction * ability.strength / maxf(target.character.weight, 0.1), ability.damage)
			player_hit.emit(owner_peer_id, target)
	exploded.emit(self)
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, direction.angle())
	# A compact pixel missile, with a pale-blue ring while enemy fire holds it back.
	if speed < ability.speed - 1.0:
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 12, Color(0.45, 0.85, 1.0, 0.85), 2.0)
	var flame := 12.0 + fmod(age * 80.0, 8.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -4), Vector2(-13 - flame, 0), Vector2(-13, 4)]), Color(1.0, 0.55, 0.12))
	draw_rect(Rect2(-13, -5, 23, 10), Color(0.18, 0.23, 0.3))
	draw_rect(Rect2(-9, -4, 17, 8), Color(0.83, 0.87, 0.91))
	draw_rect(Rect2(-5, -4, 3, 8), Color(0.45, 0.54, 0.63))
	draw_colored_polygon(PackedVector2Array([Vector2(8, -5), Vector2(17, 0), Vector2(8, 5)]), Color(0.87, 0.2, 0.16))
	draw_rect(Rect2(-12, -9, 5, 4), Color(0.5, 0.58, 0.68))
	draw_rect(Rect2(-12, 5, 5, 4), Color(0.5, 0.58, 0.68))
