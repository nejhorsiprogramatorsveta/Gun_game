extends TestCase


func _player(character_id: StringName, peer_id: int, position: Vector2) -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(character_id)
	player.peer_id = peer_id
	player.position = position
	return player


func _press(held: bool) -> InputFrame:
	return InputFrame.create(0, InputFrame.ABILITY if held else 0)


func test_activates_on_press_and_respects_cooldown() -> void:
	var balvan := _player(&"balvan", 1, Vector2.ZERO)
	var ability := balvan.character.ability
	balvan.tick_ability(_press(true), 0.1); balvan.motor_state.prev_buttons = InputFrame.ABILITY
	check(balvan.ability_active(), "press activates the shield")
	check(is_equal_approx(balvan.ability_cooldown, ability.cooldown), "cooldown starts")
	balvan.ability_cooldown = 0.0
	balvan.tick_ability(_press(true), 0.1); balvan.motor_state.prev_buttons = InputFrame.ABILITY
	check(is_equal_approx(balvan.ability_cooldown, 0.0), "holding the button does not activate again")
	balvan.tick_ability(_press(false), 0.1); balvan.motor_state.prev_buttons = 0
	balvan.ability_cooldown = 5.0
	balvan.tick_ability(_press(true), 0.1); balvan.motor_state.prev_buttons = InputFrame.ABILITY
	check(is_equal_approx(balvan.ability_cooldown, 4.9), "no activation during cooldown")
	balvan.free()


func test_shield_reduces_knockback_and_allows_firing() -> void:
	var balvan := _player(&"balvan", 1, Vector2.ZERO)
	check(balvan.can_fire() and is_equal_approx(balvan.knockback_scale(), 1.0), "normal without the shield")
	balvan.ability_time_left = 1.0
	check(balvan.can_fire(), "Balvan keeps shooting behind the shield")
	check(is_equal_approx(balvan.knockback_scale(), 0.2), "knockback x0.2 while shielded")
	var jiskra := _player(&"jiskra", 2, Vector2.ZERO)
	jiskra.ability_time_left = 1.0
	check(jiskra.can_fire() and is_equal_approx(jiskra.knockback_scale(), 1.0), "no ability = no effect")
	balvan.free()
	jiskra.free()


func test_shockwave_pushes_only_nearby_opponents() -> void:
	var system := AbilitySystem.new()
	var vichr := _player(&"vichr", 1, Vector2.ZERO)
	var near := _player(&"jiskra", 2, Vector2(100, 0))
	var far := _player(&"balvan", 3, Vector2(400, 0))
	var protected := _player(&"krugermann", 4, Vector2(-80, 0))
	protected.invulnerable = true
	var hits: Array[int] = []
	system.player_hit.connect(func(attacker: int, target: Player) -> void: hits.append(attacker * 10 + target.peer_id))
	var everyone := [vichr, near, far, protected]
	vichr.tick_ability(_press(true), 0.0)
	system.tick(vichr, everyone)
	check(near.velocity.x > 0.0 and near.velocity.y < 0.0, "near opponent pushed away and slightly up")
	var limit := CombatRules.MAX_KNOCKBACK_PER_SHOT / near.character.weight
	check(near.velocity.length() <= limit + 0.01, "push within the knockback limit")
	check(far.velocity.is_zero_approx() and protected.velocity.is_zero_approx() and vichr.velocity.is_zero_approx(),
			"far, protected and the user are not pushed")
	check_eq(hits, [12], "the push counts as a hit for the score")
	for player in everyone:
		player.free()


func test_jetpack_lifts_up_and_can_be_steered() -> void:
	var jiskra := _player(&"jiskra", 1, Vector2.ZERO)
	var jet := jiskra.character.ability as JetpackAbility
	check(jet != null, "Jiskra has the jetpack")
	jiskra.tick_ability(_press(true), 0.0)
	check(is_equal_approx(jiskra.motor_state.boost_time_left, jet.duration), "thrust starts")
	var velocity := Vector2(0, 300)  # falling when it starts
	var height := 0.0
	var steps := int(ceil(jet.duration * 60.0))
	for i in steps:
		velocity = PlayerMotor.compute_velocity(velocity, false, InputFrame.create(1, InputFrame.ABILITY), jiskra.motor_state, jiskra.character, 1.0 / 60.0)
		height -= velocity.y / 60.0
	check(velocity.y < -jet.lift_speed * 0.9, "flying up at about the lift speed")
	check(height > 250.0, "carries her up a good bit (%.0f px)" % height)
	check(velocity.x > 0.0, "steerable sideways")
	check(is_equal_approx(jiskra.motor_state.boost_time_left, 0.0), "thrust ends after the duration")
	velocity = PlayerMotor.compute_velocity(velocity, false, InputFrame.create(0, 0), jiskra.motor_state, jiskra.character, 1.0 / 60.0)
	check(velocity.y > -jet.lift_speed, "gravity again afterwards")
	jiskra.free()


## Keeps calling blow() like Player.simulate does once per tick; returns how many ticks it
## took until the player was blown (-1 = never within `limit`).
func _ticks_until_blown(effects: AreaEffects, player: Player, limit: int = 120) -> int:
	for tick in range(1, limit + 1):
		if effects.blow(player):
			return tick
	return -1


func test_gas_blows_opponents_after_0_7_seconds() -> void:
	var effects := AreaEffects.new()
	var gas := ContentDB.get_ability(&"gas_blast") as GasBlastAbility
	effects._add(gas, 7, 100, Vector2(500, 300), 1)
	var delay := roundi(gas.blow_delay * Engine.physics_ticks_per_second)
	check_eq(delay, 42, "0.7 s = 42 physics ticks (user 2026-11-14)")
	check(gas.lifetime >= 5.0, "the gas stays longer (%.1f s)" % gas.lifetime)
	var blown: Array = []
	effects.player_blown.connect(func(owner_peer_id: int, victim: Player) -> void: blown.append([owner_peer_id, victim]))
	var owner := _player(&"krugermann", 7, Vector2(500, 300))
	check_eq(_ticks_until_blown(effects, owner), -1, "the owner is never blown by his own gas")
	var victim := _player(&"balvan", 8, Vector2(660, 330))
	for tick in delay - 1:
		check(not effects.blow(victim) and victim.velocity.is_zero_approx(), "tick %d inside: not yet" % (tick + 1))
	check(blown.is_empty(), "no credit before the blow")
	check(effects.blow(victim), "after 0.7 s inside: blown")
	var weight := victim.character.weight
	check(is_equal_approx(victim.velocity.x, gas.blow_speed / weight), "away from Krügermann (%.0f px/s)" % victim.velocity.x)
	check(victim.velocity.y <= -gas.blow_lift / weight + 0.01, "and upwards")
	var speed := victim.velocity.x
	check(effects.blow(victim) and is_equal_approx(victim.velocity.x, speed), "staying inside does not stack up")
	check(not blown.is_empty() and blown.all(func(entry: Array) -> bool: return entry == [7, victim]), "the authority credits Krügermann")
	var visitor := _player(&"jiskra", 9, Vector2(660, 330))
	for tick in delay - 1:
		effects.blow(visitor)
	visitor.position = Vector2(660, 600)
	check(not effects.blow(visitor) and visitor.gas_ticks == 0, "stepping out resets the count")
	visitor.position = Vector2(660, 330)
	check_eq(_ticks_until_blown(effects, visitor), delay, "back inside: the full second again")
	var edge := _player(&"jiskra", 10, Vector2(500 - gas.length / 2.0 - Player.BODY_SIZE.x / 2.0 + 2.0, 300))
	check(_ticks_until_blown(effects, edge) == delay and edge.velocity.x > 0.0, "touching the end of the strip counts")
	var outside := _player(&"stin", 11, Vector2(560, 300 + gas.height / 2.0 + Player.BODY_SIZE.y / 2.0 + 5.0))
	check_eq(_ticks_until_blown(effects, outside), -1, "below the strip nothing happens")
	for node in [effects, owner, victim, visitor, edge, outside]:
		node.free()


func test_gas_blows_left_spares_respawned_and_shield_holds() -> void:
	var effects := AreaEffects.new()
	effects._is_authority = false
	var gas := ContentDB.get_ability(&"gas_blast") as GasBlastAbility
	effects._add(gas, 7, 1, Vector2(500, 300), -1)
	var jiskra := _player(&"jiskra", 8, Vector2(450, 300))
	check(_ticks_until_blown(effects, jiskra) > 0 and is_equal_approx(jiskra.velocity.x, -gas.blow_speed / jiskra.character.weight), "left gas blows left")
	var respawned := _player(&"stin", 9, Vector2(450, 300))
	respawned.invulnerable = true
	check_eq(_ticks_until_blown(effects, respawned), -1, "just respawned: not blown (like bullets)")
	check_eq(respawned.gas_ticks, 0, "and the time does not count")
	var balvan := _player(&"balvan", 10, Vector2(450, 300))
	balvan.ability_time_left = 1.0
	_ticks_until_blown(effects, balvan)
	check(is_equal_approx(balvan.velocity.x, -gas.blow_speed / balvan.character.weight * 0.2), "the shield cuts the blow to a fifth")
	for node in [effects, jiskra, respawned, balvan]:
		node.free()


func test_gas_time_travels_in_snapshots_and_resets_on_respawn() -> void:
	var host := _player(&"jiskra", 8, Vector2.ZERO)
	host.gas_ticks = 7
	var state: Dictionary = NetCodec.decode_snapshot(NetCodec.encode_snapshot(1, 0, [host.snapshot_state()] as Array[Dictionary])).states[0]
	check_eq(state.gas_ticks, 7, "gas time in the snapshot")
	var client := _player(&"jiskra", 8, Vector2.ZERO)
	client.restore_state(state)
	check_eq(client.gas_ticks, 7, "a replay starts from the host's count")
	host.reset_to(Vector2.ZERO)
	check_eq(host.gas_ticks, 0, "respawn clears it")
	host.free()
	client.free()


func test_area_effects_owner_immunity_dedupe_and_host_position() -> void:
	var effects := AreaEffects.new()
	var gas := ContentDB.get_ability(&"gas_blast")
	effects._add(gas, 7, 100, Vector2(500, 300), 1)
	check(not effects._add(gas, 7, 100, Vector2(520, 300), 1), "replaying the activation tick adds no second cloud")
	effects._on_remote_spawned(&"gas_blast", 7, 100, Vector2(510, 300), -1)
	check_eq(effects.get_child_count(), 1, "the host's event for a predicted cloud does not duplicate it")
	check_eq(effects.get_child(0).position, Vector2(510, 300), "the host's position wins")
	check_eq((effects.get_child(0) as GasCloud).direction, -1, "and the host's direction")
	effects._on_remote_spawned(&"platform", 8, 5, Vector2(100, 100), 1)
	check_eq(effects.get_child_count(), 2, "another player's platform from the host is created")
	effects.free()


func test_client_matches_a_late_host_effect_and_drops_unconfirmed_ones() -> void:
	var effects := AreaEffects.new()
	effects._is_authority = false
	var platform := ContentDB.get_ability(&"platform")
	effects.spawn(platform, 7, 100, Vector2(10, 10))
	effects._on_remote_spawned(&"platform", 7, 102, Vector2(14, 10), 1)
	check_eq(effects.get_child_count(), 1, "host applied the press 2 inputs later: same platform, not a second one")
	check_eq(effects.get_child(0).position, Vector2(14, 10), "host position wins")
	check(effects._unconfirmed.is_empty(), "confirmed")
	effects.spawn(platform, 7, 300, Vector2(50, 50))
	effects._unconfirmed[effects._unconfirmed.keys()[0]] -= AreaEffects.UNCONFIRMED_LIFETIME_MS + 1
	effects._process(0.0)
	check(effects.get_child(1).is_queued_for_deletion(), "a prediction the host never confirms is removed")
	effects.free()


func test_respawn_makes_the_ability_ready() -> void:
	var balvan := _player(&"balvan", 1, Vector2.ZERO)
	balvan.tick_ability(_press(true), 0.1)
	check(balvan.ability_cooldown > 0.0, "used: cooldown runs")
	balvan.reset_to(Vector2(100, 0))
	check_eq([balvan.ability_cooldown, balvan.ability_active()], [0.0, false], "after a death the ability is ready again")
	balvan.free()


## A teleport world: solid floor (top y = 400), a solid wall at x 700-740, a jump-through
## platform above Stín and another player right next to him.
func _teleport_world() -> Node2D:
	var world := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)
	for block: Array in [[Vector2(0, 400), Vector2(1400, 60), false], [Vector2(700, 100), Vector2(40, 300), false],
			[Vector2(250, 250), Vector2(300, 16), true]]:
		var platform := Platform.new()
		platform.position = block[0]
		platform.size = block[1]
		platform.one_way = block[2]
		world.add_child(platform)
	var other: Player = load("res://src/player/player.tscn").instantiate()
	other.position = Vector2(450, 372)
	world.add_child(other)
	return world


func _teleported(world: Node2D, from: Vector2, aim_degrees: float) -> Vector2:
	var stin: Player = load("res://src/player/player.tscn").instantiate()
	stin.character = ContentDB.get_character(&"stin")
	stin.position = from
	world.add_child(stin)
	var aim := InputFrame.aim_from_vector(Vector2.from_angle(deg_to_rad(aim_degrees)))
	stin.velocity = Vector2(300, -200)
	stin.character.ability.start(stin, InputFrame.create(0, InputFrame.ABILITY, aim))
	var at := stin.position
	check(stin.velocity.is_zero_approx(), "the teleport stops all momentum")
	stin.free()
	return at


func test_teleport_always_goes_as_far_as_the_world_allows() -> void:
	var world := _teleport_world()
	await physics_step()
	var distance := (ContentDB.get_character(&"stin").ability as TeleportAbility).distance
	var standing := Vector2(300, 372)  # feet on the floor (body 56 px high)
	var level := _teleported(world, standing, 0.0)
	check(level.distance_to(standing + Vector2(distance, 0)) < 1.0, "level aim: the full %.0f px (%s)" % [distance, level])
	for degrees in [3.0, 10.0, 30.0]:
		var into_floor := _teleported(world, standing, degrees)
		check(into_floor.x - standing.x > distance * cos(deg_to_rad(degrees)) - 2.0 and absf(into_floor.y - standing.y) < 1.0,
				"aiming %.0f° into the floor slides along it (%s)" % [degrees, into_floor])
	var up := _teleported(world, standing, -90.0)
	check(up.distance_to(standing + Vector2(0, -distance)) < 1.0, "up through the jump-through platform (%s)" % up)
	var wall := _teleported(world, Vector2(600, 372), 0.0)
	check(wall.x > 675.0 and wall.x <= 700.0 - Player.BODY_SIZE.x / 2.0 + 0.01, "a solid wall stops it right in front (%s)" % wall)
	var diagonal := _teleported(world, Vector2(600, 372), -30.0)
	check(diagonal.x <= 682.01 and diagonal.y < 372.0 - 100.0, "into the wall diagonally: slides up along it (%s)" % diagonal)
	var down := _teleported(world, standing, 90.0)
	check(down.distance_to(standing) < 1.0, "straight into the floor: nowhere to go")
	world.free()


func test_ability_cooldown_ends_on_the_same_tick_after_a_snapshot() -> void:
	var delta := 1.0 / 60.0
	var host := _player(&"balvan", 2, Vector2.ZERO)
	host.tick_ability(_press(true), delta)
	host.motor_state.prev_buttons = InputFrame.ABILITY
	var client := _player(&"balvan", 2, Vector2.ZERO)
	client.ability_cooldown = host.ability_cooldown
	for tick in 500:
		if tick % 7 == 3:  # a snapshot now and then: the client restarts from the host's value
			var states: Array[Dictionary] = [host.snapshot_state()]
			client.ability_cooldown = NetCodec.decode_snapshot(NetCodec.encode_snapshot(0, 0, states)).states[0].ability_cooldown
		host.tick_ability(_press(false), delta)
		client.tick_ability(_press(false), delta)
		check_eq(client.ability_cooldown <= 0.0, host.ability_cooldown <= 0.0, "tick %d: both ready or both waiting" % tick)
	check(host.ability_cooldown <= 0.0, "ready after the cooldown")
	host.free()
	client.free()
