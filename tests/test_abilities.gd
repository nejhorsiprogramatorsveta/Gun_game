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
	var protected := _player(&"mlha", 4, Vector2(-80, 0))
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


func test_dash_moves_sideways_fast_without_gravity_then_runs() -> void:
	var jiskra := _player(&"jiskra", 1, Vector2.ZERO)
	var dash := jiskra.character.ability as DashAbility
	jiskra.motor_state.facing = -1
	jiskra.tick_ability(_press(true), 0.0)
	check_eq([jiskra.motor_state.dash_direction, jiskra.motor_state.dash_time_left], [-1, dash.duration],
			"standing still dashes to the facing side")
	var velocity := PlayerMotor.compute_velocity(Vector2(0, 300), false, _press(true), jiskra.motor_state, jiskra.character, 1.0 / 60.0)
	check_eq(velocity, Vector2(-dash.speed, 0), "fast and straight, gravity ignored")
	for i in 20:
		velocity = PlayerMotor.compute_velocity(velocity, false, _press(false), jiskra.motor_state, jiskra.character, 1.0 / 60.0)
	check(absf(velocity.x) <= jiskra.character.move_speed + 0.01, "after the dash only running speed is left")
	jiskra.free()
