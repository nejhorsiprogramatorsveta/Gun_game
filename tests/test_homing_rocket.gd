extends TestCase


func _world() -> Node2D:
	var world := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	return world


func _player(world: Node2D, peer_id: int, at: Vector2, character_id: StringName = &"vichr", team: int = Teams.NONE) -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(character_id)
	player.peer_id = peer_id
	player.position = at
	player.team = team
	world.add_child(player)
	return player


func _rocket(world: Node2D, authoritative: bool = true, team: int = Teams.NONE) -> HomingRocket:
	var rocket := HomingRocket.new()
	rocket.setup(7, Vector2.ZERO, Vector2.RIGHT, ContentDB.get_ability(&"homing_rocket"), 1, team, authoritative)
	world.add_child(rocket)
	return rocket


func test_targets_current_nearest_live_opponent_and_turns() -> void:
	var world := _world()
	var owner := _player(world, 1, Vector2(1, 0))
	var ally := _player(world, 2, Vector2(2, 0), &"vichr", 0)
	var near := _player(world, 3, Vector2(0, -100))
	var far := _player(world, 4, Vector2(400, 0))
	var hidden := _player(world, 5, Vector2(3, 0))
	hidden.visible = false
	var protected := _player(world, 6, Vector2(4, 0))
	protected.invulnerable = true
	var players := [owner, ally, near, far, hidden, protected]
	var rocket := _rocket(world, true, 0)
	check_eq(rocket.nearest_target(players), near, "ignores owner, allies, eliminated and respawning players")
	rocket.advance(0.1, players)
	check(rocket.direction.y < 0.0 and rocket.direction.x > 0.0, "steers towards the nearest enemy with a curved turn")
	far.position = rocket.position + Vector2(10, 0)
	check_eq(rocket.nearest_target(players), far, "a newly closer opponent replaces the previous target")
	far.visible = false
	near.visible = false
	check_eq(rocket.nearest_target(players), null, "no valid opponent is also safe")
	world.free()


func test_enemy_bullets_slow_temporarily_but_cannot_destroy() -> void:
	var world := _world()
	var rocket := _rocket(world, true, 0)
	var normal_speed := rocket.speed
	check(not rocket.slow_by_shot(1, Teams.NONE), "the owner cannot slow his own rocket")
	check(not rocket.slow_by_shot(2, 0), "allied bullets pass through")
	check_eq(rocket.speed, normal_speed, "friendly fire does not change its speed")
	for hit in 100:
		check(rocket.slow_by_shot(3, 1), "enemy bullet %d is accepted" % hit)
	check_eq(rocket.speed, rocket.ability.minimum_speed, "repeated shots stop at a nonzero speed")
	check(not rocket.detonated and not rocket.is_queued_for_deletion(), "firing cannot destroy the missile")
	rocket.advance(0.2, [])
	check_eq(rocket.speed, rocket.ability.minimum_speed, "the slowdown persists briefly")
	for tick in 120:
		rocket.advance(1.0 / 60.0, [])
	check(is_equal_approx(rocket.speed, normal_speed), "it accelerates back to normal after the slowdown")
	world.free()


func test_blast_hits_owner_allies_and_multiple_players_in_incoming_direction() -> void:
	var world := _world()
	var owner := _player(world, 1, Vector2(-100, 0))
	var direct := _player(world, 2, Vector2(-20, 20))
	var ally := _player(world, 3, Vector2(60, 0), &"vichr", 0)
	var above := _player(world, 4, Vector2(-60, -60))
	var far := _player(world, 5, Vector2(321, 0))
	var protected := _player(world, 6, Vector2(80, 0))
	protected.invulnerable = true
	var rocket := _rocket(world, true, 0)
	var hits: Array[int] = []
	rocket.player_hit.connect(func(attacker: int, target: Player) -> void:
		check_eq(attacker, 1, "Bibi gets the hit attribution")
		hits.append(target.peer_id))
	var shockwave := ContentDB.get_ability(&"shockwave") as ShockwaveAbility
	check_eq(rocket.ability.radius, shockwave.radius, "blast reach equals Vichr")
	check_eq(rocket.ability.strength, shockwave.strength, "blast strength equals Vichr")
	rocket.explode([owner, direct, ally, above, far, protected], direct)
	check_eq(hits, [1, 2, 3, 4], "all nearby players including Bibi and allies are hit")
	check(owner.velocity.x < 0.0 and ally.velocity.x > 0.0 and above.velocity.y < 0.0, "surrounding players fly away from the explosion")
	check(direct.velocity.x > 0.0, "the direct victim flies along the incoming rocket, even behind the centre")
	check(is_equal_approx(direct.velocity.length(), shockwave.strength / direct.character.weight), "same base impulse as Vichr")
	check_eq(direct.damage, 0.0, "Bibi's blast adds no damage percent")
	check(far.velocity.is_zero_approx() and protected.velocity.is_zero_approx(), "outside and respawn-protected players are safe")
	rocket.explode([owner, direct])
	check_eq(hits.size(), 4, "an explosion is applied only once")
	world.free()


func test_blast_keeps_shield_weight_and_existing_damage_scaling() -> void:
	var world := _world()
	var balvan := _player(world, 2, Vector2(100, 0), &"balvan")
	balvan.ability_time_left = 1.0
	balvan.damage = 50.0
	var rocket := _rocket(world)
	var expected := rocket.ability.strength / balvan.character.weight * 0.2 * CombatRules.damage_multiplier(50.0)
	rocket.explode([balvan])
	check(is_equal_approx(balvan.velocity.length(), expected), "weight, shield and existing percent use the normal combat formula")
	check_eq(balvan.damage, 50.0, "existing damage is retained without adding damage")
	world.free()


func test_remote_rocket_never_decides_hits_or_knockback() -> void:
	var world := _world()
	var victim := _player(world, 2, Vector2(100, 0))
	var rocket := _rocket(world, false)
	check_eq(rocket.collision_layer, 0, "display rocket is not a physical bullet target")
	check(not rocket.slow_by_shot(3, Teams.NONE), "client bullets cannot slow the host's rocket")
	rocket.advance(0.1, [victim])
	check(rocket.position.x > 0.0 and not rocket.detonated, "remote copies only display flight")
	rocket.explode([victim], victim)
	check(victim.velocity.is_zero_approx(), "remote explosion is visual only")
	world.free()


func test_collision_with_solid_and_one_way_platform_detonates() -> void:
	for one_way in [false, true]:
		var world := _world()
		var platform := Platform.new()
		platform.position = Vector2(100, -20)
		platform.size = Vector2(10, 40)
		platform.one_way = one_way
		world.add_child(platform)
		var rocket := _rocket(world)
		await physics_step()
		rocket.advance(0.3, [])
		check(rocket.detonated, "collision detonates against %s terrain" % ("one-way" if one_way else "solid"))
		check(absf(rocket.position.x - 100.0) < 0.01, "blast starts at the impact point")
		world.free()


func test_rocket_without_a_target_expires_with_a_blast() -> void:
	var world := _world()
	var rocket := _rocket(world)
	rocket.advance(rocket.ability.lifetime, [])
	check(rocket.detonated, "a targetless rocket cannot stay in the match forever")
	world.free()
