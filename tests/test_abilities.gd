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


func test_shield_reduces_knockback_and_blocks_firing() -> void:
	var balvan := _player(&"balvan", 1, Vector2.ZERO)
	check(balvan.can_fire() and is_equal_approx(balvan.knockback_scale(), 1.0), "normal without the shield")
	balvan.ability_time_left = 1.0
	check(not balvan.can_fire(), "no shooting behind the shield")
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


func test_cloud_slows_other_players_running_and_jumping() -> void:
	var stats := ContentDB.get_character(&"balvan")
	var state := PlayerMotor.State.new()
	state.speed_scale = 0.5
	state.jump_scale = 0.8
	state.jumps_left = 2
	var velocity := Vector2.ZERO
	for i in 60:
		velocity = PlayerMotor.compute_velocity(velocity, true, InputFrame.create(1, 0), state, stats, 1.0 / 60.0)
	check(is_equal_approx(velocity.x, stats.move_speed * 0.5), "runs at half speed")
	velocity = PlayerMotor.compute_velocity(velocity, true, InputFrame.create(1, InputFrame.JUMP), state, stats, 1.0 / 60.0)
	check(is_equal_approx(velocity.y, -stats.jump_velocity * 0.8), "jumps lower")


func test_area_effects_owner_immunity_dedupe_and_host_position() -> void:
	var effects := AreaEffects.new()
	var cloud_ability := ContentDB.get_ability(&"slow_cloud") as SlowCloudAbility
	effects._add(cloud_ability, 7, 100, Vector2(500, 300))
	check(not effects._add(cloud_ability, 7, 100, Vector2(520, 300)), "replaying the activation tick adds no second cloud")
	var owner := _player(&"krugermann", 7, Vector2(500, 300))
	var victim := _player(&"balvan", 8, Vector2(660, 330))
	var outside := _player(&"jiskra", 9, Vector2(560, 380))
	check_eq(effects.slow_for(owner), Vector2.ONE, "the owner is not slowed by his own cloud")
	check_eq(effects.slow_for(victim), Vector2(cloud_ability.speed_scale, cloud_ability.jump_scale), "an opponent inside is slowed")
	check_eq(effects.slow_for(outside), Vector2.ONE, "above/below the strip nothing happens")
	effects._on_remote_spawned(&"slow_cloud", 7, 100, Vector2(510, 300))
	check_eq(effects.get_child_count(), 1, "the host's event for a predicted cloud does not duplicate it")
	check_eq(effects.get_child(0).position, Vector2(510, 300), "the host's position wins")
	effects._on_remote_spawned(&"platform", 8, 5, Vector2(100, 100))
	check_eq(effects.get_child_count(), 2, "another player's platform from the host is created")
	for node in [effects, owner, victim, outside]:
		node.free()


func test_client_matches_a_late_host_effect_and_drops_unconfirmed_ones() -> void:
	var effects := AreaEffects.new()
	effects._is_authority = false
	var platform := ContentDB.get_ability(&"platform")
	effects.spawn(platform, 7, 100, Vector2(10, 10))
	effects._on_remote_spawned(&"platform", 7, 102, Vector2(14, 10))
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
