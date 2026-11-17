extends TestCase

class RocketNetStub extends Node:
	var packets: Array[PackedByteArray] = []
	var explosions: Array[int] = []

	func send_rocket_state(data: PackedByteArray) -> void:
		packets.append(data)

	func send_rocket_exploded(id: int, _at: Vector2) -> void:
		explosions.append(id)


func _world() -> Node2D:
	var world := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	return world


func _player(world: Node2D, peer_id: int, at: Vector2, team: int = Teams.NONE) -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(&"bibi")
	player.peer_id = peer_id
	player.team = team
	player.position = at
	player.collision_layer = 4
	player.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Player.BODY_SIZE
	collision.shape = shape
	player.add_child(collision)
	world.add_child(player)
	return player


func _rocket(world: Node2D, team: int = Teams.NONE) -> HomingRocket:
	var rocket := HomingRocket.new()
	rocket.setup(1, Vector2(100, 0), Vector2.RIGHT, ContentDB.get_ability(&"homing_rocket"), 1, team, true)
	world.add_child(rocket)
	return rocket


func _bullet(world: Node2D, shooter: Player) -> Projectile:
	var bullet := Projectile.new()
	bullet.setup(1, Vector2.ZERO, Vector2.RIGHT, ContentDB.get_weapon(&"smg"), shooter)
	world.add_child(bullet)
	bullet.set_physics_process(false)
	return bullet


func test_enemy_projectile_is_consumed_by_rocket_instead_of_hitting_player_behind_it() -> void:
	var world := _world()
	var shooter := _player(world, 2, Vector2.ZERO, 1)
	var behind := _player(world, 3, Vector2(180, 0), 0)
	var rocket := _rocket(world, 0)
	var bullet := _bullet(world, shooter)
	var hits: Array[int] = []
	bullet.hit_player.connect(func(_shot: Projectile, target: Player) -> void: hits.append(target.peer_id))
	await physics_step()
	bullet.advance(0.2)
	check(bullet.is_queued_for_deletion(), "enemy bullet ends at the rocket")
	check(rocket.speed < rocket.ability.speed, "the actual projectile ray slows the rocket")
	check(not rocket.detonated and not rocket.is_queued_for_deletion(), "the rocket is not destroyed")
	check(hits.is_empty() and behind.velocity.is_zero_approx() and behind.damage == 0.0, "the shielded player receives no bullet hit")
	world.free()


func test_owner_and_allied_bullets_pass_through_rocket() -> void:
	for shooter_id in [1, 2]:
		var world := _world()
		var shooter := _player(world, shooter_id, Vector2.ZERO, 0)
		var behind := _player(world, 3, Vector2(180, 0), 1)
		var rocket := _rocket(world, 0)
		var bullet := _bullet(world, shooter)
		var hits: Array[int] = []
		bullet.hit_player.connect(func(_shot: Projectile, target: Player) -> void: hits.append(target.peer_id))
		await physics_step()
		bullet.advance(0.2)
		check_eq(hits, [behind.peer_id], "owner/allied bullet passes through the rocket and reaches the opponent")
		check_eq(rocket.speed, rocket.ability.speed, "owner/allied fire does not slow the rocket")
		check(not rocket.detonated, "friendly fire cannot detonate the rocket")
		world.free()


func test_host_spawns_only_accepted_bibi_ability_presses() -> void:
	var world := _world()
	var bibi := _player(world, 1, Vector2.ZERO)
	var players: Dictionary[int, Player] = {1: bibi}
	var system := RocketSystem.new()
	world.add_child(system)
	system.setup(null, true, players)
	system.spawn_for(bibi)
	check_eq(system._rockets.size(), 0, "no rocket without an ability press")
	var press := InputFrame.create(0, InputFrame.ABILITY, InputFrame.aim_from_vector(Vector2.RIGHT))
	bibi.tick_ability(press, 1.0 / 60.0)
	system.spawn_for(bibi)
	check_eq(system._rockets.size(), 1, "an accepted Bibi press spawns one rocket")
	bibi.motor_state.prev_buttons = InputFrame.ABILITY
	bibi.tick_ability(press, 1.0 / 60.0)
	system.spawn_for(bibi)
	check_eq(system._rockets.size(), 1, "holding the button cannot repeatedly spawn")
	bibi.motor_state.prev_buttons = 0
	bibi.tick_ability(press, 1.0 / 60.0)
	system.spawn_for(bibi)
	check_eq(system._rockets.size(), 1, "cooldown rejects a new press")
	var client := RocketSystem.new()
	world.add_child(client)
	client.setup(null, false, players)
	bibi.ability_started = true
	client.spawn_for(bibi)
	check_eq(client._rockets.size(), 0, "a client cannot spawn gameplay rockets")
	bibi.character = ContentDB.get_character(&"vichr")
	system.spawn_for(bibi)
	check_eq(system._rockets.size(), 1, "other characters retain their own abilities")
	world.free()


func test_flight_passes_through_owner_and_allies_but_blast_hits_them() -> void:
	var world := _world()
	var owner := _player(world, 1, Vector2(140, 0), 0)
	var ally := _player(world, 2, Vector2(180, 0), 0)
	var enemy := _player(world, 3, Vector2(250, 0), 1)
	var rocket := _rocket(world, 0)
	await physics_step()
	rocket.advance(0.5, [owner, ally, enemy])
	check(rocket.detonated, "the enemy triggers the impact")
	check(rocket.position.x > 200.0, "owner and teammate did not block flight")
	check(owner.velocity.x < 0.0 and ally.velocity.x < 0.0 and enemy.velocity.x > 0.0,
			"the explosion pushes owner, ally and directly hit opponent")
	world.free()


func test_launch_points_at_nearest_enemy_even_when_aiming_away() -> void:
	var world := _world()
	var bibi := _player(world, 1, Vector2.ZERO)
	var enemy := _player(world, 2, Vector2(-200, 0))
	var players: Dictionary[int, Player] = {1: bibi, 2: enemy}
	var system := RocketSystem.new()
	world.add_child(system)
	system.setup(null, true, players)
	bibi.aim = InputFrame.aim_from_vector(Vector2.RIGHT)
	bibi.ability_started = true
	system.spawn_for(bibi)
	var rocket: HomingRocket = system._rockets.values()[0]
	check(rocket.direction.is_equal_approx(Vector2.LEFT), "auto-targeted launch points at the nearest enemy")
	check(rocket.position.x < 0.0, "the muzzle follows the rocket's target direction")
	world.free()


func test_remote_explosion_cannot_be_resurrected_by_delayed_state() -> void:
	var world := _world()
	var system := RocketSystem.new()
	world.add_child(system)
	var players: Dictionary[int, Player] = {}
	system.setup(null, false, players)
	var records: Array[Dictionary] = [{"id": 7, "owner_peer_id": 1, "position": Vector2(10, 20),
			"direction": Vector2.RIGHT, "speed": 200.0}]
	system._on_remote_state({"tick": 3, "rockets": records})
	check_eq(system._rockets.size(), 1, "a valid host state creates the visual rocket even after its owner departs")
	system._on_remote_exploded(7, Vector2(30, 20))
	check_eq(system._rockets.size(), 0, "reliable host explosion removes it")
	system._on_remote_state({"tick": 6, "rockets": records})
	check_eq(system._rockets.size(), 0, "a delayed flight update cannot revive it")
	system._on_remote_state({"tick": 2, "rockets": records})
	check_eq(system._last_tick, 6, "out-of-order state is ignored")
	world.free()


func test_network_sends_flight_states_only_when_needed() -> void:
	var world := _world()
	var net := RocketNetStub.new()
	world.add_child(net)
	var bibi := _player(world, 1, Vector2.ZERO)
	var players: Dictionary[int, Player] = {1: bibi}
	var system := RocketSystem.new()
	world.add_child(system)
	system.setup(net, true, players)
	system.tick(1.0 / 60.0, 3)
	check(net.packets.is_empty(), "no extra network traffic in matches without rockets")
	bibi.ability_started = true
	system.spawn_for(bibi)
	system.tick(1.0 / 60.0, 6)
	check_eq(net.packets.size(), 1, "a live rocket is replicated")
	check_eq(RocketCodec.decode(net.packets[0]).rockets.size(), 1, "one complete flight record")
	var rocket: HomingRocket = system._rockets.values()[0]
	rocket.explode([])
	system.tick(1.0 / 60.0, 9)
	check_eq(net.explosions, [rocket.id], "host sends a reliable explosion event")
	check_eq(net.packets.size(), 2, "one final empty state clears old client visuals")
	check_eq(RocketCodec.decode(net.packets[1]).rockets.size(), 0, "the final live set is empty")
	system.tick(1.0 / 60.0, 12)
	check_eq(net.packets.size(), 2, "idle matches stop sending rocket packets")
	world.free()
