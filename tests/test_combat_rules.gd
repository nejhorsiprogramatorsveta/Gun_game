extends TestCase

var pistol: WeaponData = load("res://data/weapons/pistol.tres")


func test_knockback_follows_bullet_and_weight() -> void:
	var push := CombatRules.knockback(Vector2.RIGHT, pistol, 1.0)
	check_eq(push, Vector2(pistol.knockback, 0), "full knockback along the flight direction")
	var heavy := CombatRules.knockback(Vector2.RIGHT, pistol, 2.0)
	check_eq(heavy.x, pistol.knockback / 2.0, "twice as heavy = half the push")


func test_recoil_opposite_to_aim() -> void:
	check_eq(CombatRules.recoil(Vector2.DOWN, pistol), Vector2(0, -pistol.recoil), "shooting down pushes up")


func test_fire_interval() -> void:
	check(absf(CombatRules.fire_interval(pistol) - 1.0 / pistol.shots_per_second) < 0.0001, "interval = 1 / shots per second")


func test_spread_stays_within_limits() -> void:
	var left := CombatRules.spread_direction(Vector2.RIGHT, pistol, 0.0)
	var right := CombatRules.spread_direction(Vector2.RIGHT, pistol, 1.0)
	check(absf(rad_to_deg(left.angle()) + pistol.spread_degrees) < 0.01, "minimum spread")
	check(absf(rad_to_deg(right.angle()) - pistol.spread_degrees) < 0.01, "maximum spread")


func test_pistol_is_loaded_for_default_character() -> void:
	check_eq(ContentDB.default_character().weapon.id, &"smg", "default character has her SMG")
	check(ContentDB.get_weapon(&"pistol") != null, "weapon lookup by id")


func test_authoritative_hit_reports_shooter_and_protection_blocks_it() -> void:
	var shooter := Player.new()
	shooter.peer_id = 10
	var target := Player.new()
	target.peer_id = 20
	target.character = CharacterData.new()
	var projectile := Projectile.new()
	projectile.setup(1, Vector2.ZERO, Vector2.RIGHT, pistol, shooter)
	var weapons := WeaponSystem.new()
	var hits: Array[int] = []
	weapons.player_hit.connect(func(attacker_id: int, _victim: Player) -> void: hits.append(attacker_id))
	weapons._on_hit(projectile, target)
	check_eq(hits, [10], "bullet reports its original shooter for kill attribution")
	check_eq(target.velocity.x, pistol.knockback, "hit applies the configured knockback")
	target.invulnerable = true
	weapons._on_hit(projectile, target)
	check_eq(hits.size(), 1, "protected hits do not change kill attribution")
	check_eq(target.velocity.x, pistol.knockback, "protected hits do not push")
	target.invulnerable = false
	projectile.authoritative = false
	weapons._on_hit(projectile, target)
	check_eq(hits.size(), 1, "client visuals cannot report hits or change score")
	weapons.free()
	projectile.free()
	shooter.free()
	target.free()
