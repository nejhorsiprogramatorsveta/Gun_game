class_name WeaponSystem
extends Node2D
## Shooting: fire rate, projectiles, hits, knockback and recoil (PLAN.md D.5).
## Only the authority (host or offline practice) decides shots and hits. Clients receive
## spawn/remove events and fly the same bullets purely for display.

signal player_hit(attacker_peer_id: int, target: Player)

## MatchNet of a network match; null in offline practice.
var _net: Node
var _projectiles: Dictionary[int, Projectile] = {}
var _next_id := 1


func setup(net: Node) -> void:
	_net = net
	if _net:
		_net.projectile_spawned.connect(_on_remote_spawned)
		_net.projectile_removed.connect(_on_remote_removed)


## Authority: called every tick after Player.simulate(), which already decided the shot
## (cooldown, ammo, recoil - shared with the client's prediction); spawns its projectiles.
func spawn_shot(player: Player, input: InputFrame) -> void:
	var weapon := player.current_weapon()
	if not player.fired_this_tick or weapon == null:
		return
	var aim_direction := InputFrame.aim_to_vector(input.aim)
	var origin := player.global_position + aim_direction * Player.GUN_LENGTH
	for pellet in weapon.pellets:
		var direction := CombatRules.spread_direction(aim_direction, weapon, randf())
		var id := _next_id
		_next_id += 1
		_spawn(id, origin, direction, weapon, player)
		if _net:
			_net.send_projectile_spawned(id, origin, direction, weapon.id)


func _spawn(id: int, origin: Vector2, direction: Vector2, weapon: WeaponData, shooter: Player) -> void:
	var projectile := Projectile.new()
	projectile.setup(id, origin, direction, weapon, shooter)
	projectile.hit_player.connect(_on_hit)
	projectile.finished.connect(_on_finished)
	add_child(projectile)
	_projectiles[id] = projectile


func _on_hit(projectile: Projectile, target: Player) -> void:
	if not projectile.authoritative or not target.visible or target.invulnerable:
		return
	target.velocity += CombatRules.knockback(projectile.direction, projectile.weapon, target.character.weight) * target.knockback_scale()
	player_hit.emit(projectile.shooter_peer_id, target)


func _on_finished(projectile: Projectile) -> void:
	_projectiles.erase(projectile.id)
	if projectile.authoritative and _net:
		_net.send_projectile_removed(projectile.id)


func _on_remote_spawned(id: int, origin: Vector2, direction: Vector2, weapon_id: StringName) -> void:
	var weapon := ContentDB.get_weapon(weapon_id)
	if weapon == null or _projectiles.has(id) or not origin.is_finite() or not direction.is_finite() \
			or direction.is_zero_approx():
		return
	_spawn(id, origin, direction, weapon, null)


func _on_remote_removed(id: int) -> void:
	var projectile: Projectile = _projectiles.get(id)
	if projectile:
		projectile.finish()
