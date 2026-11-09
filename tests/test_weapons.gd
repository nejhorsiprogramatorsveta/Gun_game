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
	var expected := {&"architekt": &"double_barrel", &"balvan": &"heavy_machine_gun", &"jiskra": &"smg",
			&"krugermann": &"light_machine_gun", &"stin": &"sniper", &"vichr": &"battle_rifle"}
	for id in ids:
		var weapon := ContentDB.get_character(id).weapon
		check(weapon != null and weapon.id == expected[id], "%s has the weapon chosen by the user" % id)
		check(weapon != null and ContentDB.get_weapon(weapon.id) == weapon, "%s weapon is registered in ContentDB" % id)


func test_practice_character_falls_back_to_default() -> void:
	check_eq(ContentDB.practice_character("stin").id, &"stin", "chosen character")
	check_eq(ContentDB.practice_character("").id, ContentDB.DEFAULT_CHARACTER_ID, "nothing chosen yet")
	check_eq(ContentDB.practice_character("removed_character").id, ContentDB.DEFAULT_CHARACTER_ID, "unknown id from old settings")


func test_heavy_machine_gun_is_accurate_only_on_the_ground() -> void:
	var hmg := ContentDB.get_weapon(&"heavy_machine_gun")
	check_eq(hmg.magazine_size, 100, "100 rounds")
	check(hmg.knockback >= 700.0, "good knockback (%.0f)" % hmg.knockback)
	check(CombatRules.spread_degrees(hmg, false) <= 1.0, "accurate standing on the ground")
	check(CombatRules.spread_degrees(hmg, true) >= 10.0 * CombatRules.spread_degrees(hmg, false), "much wider spread in the air")
	var widest := CombatRules.spread_direction(Vector2.RIGHT, hmg, 1.0, true)
	check(is_equal_approx(rad_to_deg(widest.angle()), hmg.air_spread_degrees), "air spread used while airborne")
	var smg := ContentDB.get_weapon(&"smg")
	check_eq(CombatRules.spread_degrees(smg, true), smg.spread_degrees, "other guns spread the same in the air")


func test_client_shot_spread_matches_the_host() -> void:
	var hmg := ContentDB.get_weapon(&"heavy_machine_gun")
	var shooter := Player.new()
	shooter.slot = 2
	var input := InputFrame.create(0, InputFrame.FIRE, 0, 1234)
	var first := WeaponSystem._shot_direction(shooter, input, Vector2.RIGHT, hmg, 0)
	check(first.is_equal_approx(WeaponSystem._shot_direction(shooter, input, Vector2.RIGHT, hmg, 0)), "same input = same direction (host and prediction)")
	var angles := {}
	for seq in range(1, 41):
		angles[snappedf(WeaponSystem._shot_direction(shooter, InputFrame.create(0, InputFrame.FIRE, 0, seq), Vector2.RIGHT, hmg, 0).angle(), 0.0001)] = true
	check(angles.size() > 30, "different shots still spread (%d different directions)" % angles.size())
	shooter.motor_state.on_floor = true
	var ground := absf(rad_to_deg(WeaponSystem._shot_direction(shooter, input, Vector2.RIGHT, hmg, 0).angle()))
	check(ground <= hmg.spread_degrees + 0.001, "on the ground within %.1f° (%.2f°)" % [hmg.spread_degrees, ground])
	shooter.free()
