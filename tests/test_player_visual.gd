extends TestCase


func test_animation_follows_movement_and_shooting() -> void:
	for id: StringName in [&"balvan", &"krugermann", &"architekt"]:
		var visual := PlayerVisual.new()
		visual.setup(ContentDB.get_character(id))
		var body: AnimatedSprite2D = visual._body
		visual.update_look(1, Vector2.RIGHT, true, Vector2.ZERO, false)
		check_eq(body.animation, &"idle", "%s: standing still" % id)
		visual.update_look(1, Vector2.RIGHT, true, Vector2(200, 0), false)
		check_eq(body.animation, &"walk", "%s: running" % id)
		visual.update_look(-1, Vector2.LEFT, false, Vector2(0, -500), false)
		check_eq(body.animation, &"jump", "%s: going up" % id)
		check(body.flip_h, "%s: faces left" % id)
		check(visual._weapon.flip_v, "%s: gun mirrored when aiming left" % id)
		visual.update_look(1, Vector2.RIGHT, false, Vector2(0, 300), false)
		check_eq(body.animation, &"fall", "%s: falling" % id)
		visual.update_look(1, Vector2.RIGHT, true, Vector2(200, 0), true)
		check_eq(body.animation, &"shoot", "%s: shooting wins over walking" % id)
		var expected_frames := {&"idle": 2, &"walk": 4, &"jump": 1, &"fall": 1, &"shoot": 2}
		for animation: StringName in expected_frames:
			check_eq(body.sprite_frames.get_frame_count(animation), expected_frames[animation],
					"%s: %s frame count" % [id, animation])
		visual.free()


func test_snapshot_state_drives_remote_look() -> void:
	var player := Player.new()
	player.character = ContentDB.get_character(&"stin")
	player._apply_state({"position": Vector2(10, 20), "velocity": Vector2(150, -300), "active": true, "facing": -1,
			"aim": 0, "lives": 3, "invulnerable": false, "on_floor": false, "firing": true})
	check_eq(player.velocity, Vector2(150, -300), "velocity for walk/jump choice")
	check(not player.motor_state.on_floor, "in the air")
	check(player.is_firing(), "shooting flag from the host")
	player.free()


func test_every_character_and_its_weapon_have_sprites() -> void:
	for id in ContentDB.character_ids():
		var character := ContentDB.get_character(id)
		check(character.sprite_sheet != null, "%s has a sprite sheet" % id)
		check(character.sprite_sheet.get_size() == Vector2(PlayerVisual.FRAME_SIZE.x * 10, PlayerVisual.FRAME_SIZE.y),
				"%s sheet has 10 frames of 32x40" % id)
		check(character.weapon.sprite != null, "%s weapon has a sprite" % id)


func test_every_ability_has_a_pixel_art_effect() -> void:
	check(AbilityFx.make_loop(ContentDB.get_ability(&"shield")) != null, "shield: bubble while active")
	check(AbilityFx.make_loop(ContentDB.get_ability(&"jetpack")) != null, "jetpack: flame while flying")
	for id: StringName in [&"shockwave", &"teleport"]:
		var burst := AbilityFx.make_burst(ContentDB.get_ability(id), 1)
		check(not burst.is_empty(), "%s: burst effect when it starts" % id)
		if not burst.is_empty():
			burst.node.free()
	var ring: AnimatedSprite2D = AbilityFx.make_burst(ContentDB.get_ability(&"shockwave"), 1).node
	check(is_equal_approx(ring.scale.x * AbilityFx.RING_RADIUS, (ContentDB.get_ability(&"shockwave") as ShockwaveAbility).radius),
			"the ring grows exactly to the shockwave reach")
	ring.free()
	check(GasCloud.PUFFS != null and GasCloud.ARROW != null and ContentDB.get_ability(&"platform") != null,
			"gas (with direction arrows) and platform draw themselves")


func test_every_character_and_weapon_in_use_has_a_skin() -> void:
	for id in ContentDB.character_ids():
		var character := ContentDB.get_character(id)
		check(character.skin_sheet != null and not character.skin_name_key.is_empty(), "%s: a character skin" % id)
		check(character.skin_sheet != null and character.skin_sheet.get_size() == character.sprite_sheet.get_size(), "%s: same sheet layout" % id)
		check(character.sheet_for(0) == character.sprite_sheet and character.sheet_for(CharacterData.SKIN_CHARACTER) == character.skin_sheet,
				"%s: the skin only with its bit" % id)
		var weapon := character.weapon
		check(weapon.skin_sprite != null and weapon.skin_sprite.get_size() == weapon.sprite.get_size(), "%s: a weapon skin" % weapon.id)
		check(weapon.sprite_for(CharacterData.SKIN_CHARACTER) == weapon.sprite and weapon.sprite_for(CharacterData.SKIN_ALL) == weapon.skin_sprite,
				"%s: weapon skin only with its bit" % weapon.id)
	check_eq(ContentDB.get_weapon(&"sniper").skin_name_key, "WEAPON_SKIN_SNIPER", "Stín's sniper: the dragon skin")


func test_player_draws_its_skins() -> void:
	var player := Player.new()
	player.setup(ContentDB.get_character(&"stin"), 0, 1, "A", CharacterData.SKIN_ALL)
	check_eq(player.skins, CharacterData.SKIN_ALL, "skins stored")
	var visual: PlayerVisual = player._visual
	var frame: AtlasTexture = visual._body.sprite_frames.get_frame_texture("idle", 0)
	check(frame.atlas == ContentDB.get_character(&"stin").skin_sheet, "the body uses the skin sheet")
	check((visual._weapon_frames[0] as AtlasTexture).atlas == ContentDB.get_weapon(&"sniper").skin_sprite, "the gun uses the dragon skin")
	player.free()
