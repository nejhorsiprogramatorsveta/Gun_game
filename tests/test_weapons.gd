extends TestCase
## Balance guard (user 2026-11-04: knockback must not get too high) and character loadouts.


func test_every_weapon_stays_within_knockback_limits() -> void:
	for file_name in ResourceLoader.list_directory(ContentDB.WEAPONS_DIR):
		var weapon: WeaponData = load(ContentDB.WEAPONS_DIR + file_name)
		check(CombatRules.knockback_per_shot(weapon) <= CombatRules.MAX_KNOCKBACK_PER_SHOT,
				"%s: knockback per shot %.0f" % [weapon.id, CombatRules.knockback_per_shot(weapon)])
		check(CombatRules.knockback_per_second(weapon) <= CombatRules.MAX_KNOCKBACK_PER_SECOND,
				"%s: knockback per second %.0f" % [weapon.id, CombatRules.knockback_per_second(weapon)])
		check(weapon.pellets >= 1 and weapon.shots_per_second > 0.0, "%s: valid pellets and fire rate" % weapon.id)


func test_four_characters_with_two_own_weapons_each() -> void:
	var ids := ContentDB.character_ids()
	check_eq(ids, [&"balvan", &"jiskra", &"stin", &"vichr"] as Array[StringName], "the four characters (PLAN.md G.0)")
	var used: Dictionary[StringName, StringName] = {}
	for id in ids:
		var character := ContentDB.get_character(id)
		check_eq(character.weapons.size(), 2, "%s has exactly 2 weapons" % id)
		for weapon in character.weapons:
			check(not used.has(weapon.id), "%s: weapon %s is unique (also used by %s)" % [id, weapon.id, used.get(weapon.id, "")])
			used[weapon.id] = id
			check(ContentDB.get_weapon(weapon.id) == weapon, "%s is registered in ContentDB" % weapon.id)


func test_switching_weapons_blocks_firing_briefly() -> void:
	var player := Player.new()
	player.character = ContentDB.get_character(&"balvan")
	var system := WeaponSystem.new()
	check_eq(player.current_weapon().id, &"shotgun", "first weapon at spawn")
	system._switch_weapon(player, 1)
	check_eq(player.current_weapon().id, &"assault_rifle", "switched to the second weapon")
	check(is_equal_approx(player.fire_cooldown, CombatRules.WEAPON_SWITCH_SECONDS), "no shot right after switching")
	player.fire_cooldown = 0.0
	system._switch_weapon(player, 1)
	check_eq(player.fire_cooldown, 0.0, "no penalty without a change")
	system._switch_weapon(player, 5)
	check_eq(player.weapon_slot, 1, "invalid slot ignored")
	system.free()
	player.free()


func test_local_weapon_keys() -> void:
	var player := Player.new()
	var toggle := InputEventAction.new()
	toggle.action = &"weapon_switch"
	toggle.pressed = true
	check(player.handle_weapon_input(toggle), "Q / wheel handled")
	check_eq(player.wanted_weapon_slot, 1, "toggle to the second weapon")
	player.handle_weapon_input(toggle)
	check_eq(player.wanted_weapon_slot, 0, "toggle back")
	var second := InputEventAction.new()
	second.action = &"weapon_2"
	second.pressed = true
	player.handle_weapon_input(second)
	check_eq(player.wanted_weapon_slot, 1, "2 selects the second weapon")
	check(not player.handle_weapon_input(InputEventAction.new()), "other input not handled")
	player.free()
