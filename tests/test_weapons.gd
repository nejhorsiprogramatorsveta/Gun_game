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


func test_heavy_machine_gun_is_accurate_only_standing_still() -> void:
	var hmg := ContentDB.get_weapon(&"heavy_machine_gun")
	check_eq(hmg.magazine_size, 75, "75 rounds (user 2026-11-13)")
	check(hmg.reload_time >= 2.0, "long reload (%.1f s)" % hmg.reload_time)
	check(hmg.knockback >= 700.0, "good knockback (%.0f)" % hmg.knockback)
	var still := CombatRules.spread_degrees(hmg, false, false)
	check(still <= 1.0, "accurate standing still on the ground")
	check(CombatRules.spread_degrees(hmg, true) >= 25.0 * still, "extreme spread in the air")
	check(CombatRules.spread_degrees(hmg, false, true) >= 25.0 * still, "extreme spread while a movement key is held")
	var widest := CombatRules.spread_direction(Vector2.RIGHT, hmg, 1.0, true)
	check(is_equal_approx(rad_to_deg(widest.angle()), hmg.air_spread_degrees), "air spread used while airborne")
	widest = CombatRules.spread_direction(Vector2.RIGHT, hmg, 1.0, false, true)
	check(is_equal_approx(rad_to_deg(widest.angle()), hmg.move_spread_degrees), "movement spread used while walking")
	var smg := ContentDB.get_weapon(&"smg")
	check_eq(CombatRules.spread_degrees(smg, true, true), smg.spread_degrees, "other guns spread the same in the air and moving")


func test_every_movement_key_counts_as_moving() -> void:
	check(not InputFrame.create(0, InputFrame.FIRE | InputFrame.RELOAD | InputFrame.ABILITY).is_moving(), "fire, reload, ability: standing still")
	for frame: InputFrame in [InputFrame.create(-1, 0), InputFrame.create(1, 0), InputFrame.create(0, InputFrame.JUMP),
			InputFrame.create(0, InputFrame.DOWN)]:
		check(frame.is_moving(), "A, D, W and S are movement (move %d, buttons %d)" % [frame.move_x, frame.buttons])


func test_sniper_knocks_back_hard_but_less_than_0217() -> void:
	var sniper := ContentDB.get_weapon(&"sniper")
	check_eq(sniper.knockback, 1900.0, "2600 (0.2.16) and 2200 (0.2.17) were too much (user 2026-11-13/14); 1300 before 0.2.16")
	check(CombatRules.knockback_per_shot(sniper) <= CombatRules.MAX_KNOCKBACK_PER_SHOT, "within the raised per-shot limit")


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
	var walking := 0.0
	for seq in range(1, 41):
		var step := InputFrame.create(1, InputFrame.FIRE, 0, seq)
		walking = maxf(walking, absf(rad_to_deg(WeaponSystem._shot_direction(shooter, step, Vector2.RIGHT, hmg, 0).angle())))
	check(walking > 5.0 * hmg.spread_degrees, "walking on the ground spreads much more (%.1f°)" % walking)
	shooter.free()


func test_double_barrel_between_0216_and_0217() -> void:
	var shotgun := ContentDB.get_weapon(&"double_barrel")
	# 0.2.16: 8 x 170, 500 px; buffed in 0.2.17 to 8 x 220, 650 px; nerfed again in 0.2.18 (user 2026-11-14).
	check_eq([shotgun.knockback, shotgun.max_range], [195.0, 580.0], "between the 0.2.16 and 0.2.17 values")
	check(CombatRules.knockback_per_shot(shotgun) > 1360.0 and CombatRules.knockback_per_shot(shotgun) < 1760.0,
			"a full blast still pushes hard (%.0f)" % CombatRules.knockback_per_shot(shotgun))
	check(shotgun.damage * shotgun.pellets >= 15.0, "damage of a full blast unchanged (15 %)")
