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
		check(weapon.recoil >= CombatRules.MIN_RECOIL, "%s: recoil %.0f is noticeable" % [weapon.id, weapon.recoil])


func test_six_characters_with_one_own_weapon_each() -> void:
	var ids := ContentDB.character_ids()
	check_eq(ids, [&"architekt", &"balvan", &"jiskra", &"krugermann", &"stin", &"vichr"] as Array[StringName],
			"the six characters (PLAN.md G.0a)")
	var expected := {&"architekt": &"double_barrel", &"balvan": &"assault_rifle", &"jiskra": &"smg",
			&"krugermann": &"light_machine_gun", &"stin": &"sniper", &"vichr": &"battle_rifle"}
	for id in ids:
		var weapon := ContentDB.get_character(id).weapon
		check(weapon != null and weapon.id == expected[id], "%s has the weapon chosen by the user" % id)
		check(weapon != null and ContentDB.get_weapon(weapon.id) == weapon, "%s weapon is registered in ContentDB" % id)


func test_practice_character_falls_back_to_default() -> void:
	check_eq(ContentDB.practice_character("stin").id, &"stin", "chosen character")
	check_eq(ContentDB.practice_character("").id, ContentDB.DEFAULT_CHARACTER_ID, "nothing chosen yet")
	check_eq(ContentDB.practice_character("removed_character").id, ContentDB.DEFAULT_CHARACTER_ID, "unknown id from old settings")
