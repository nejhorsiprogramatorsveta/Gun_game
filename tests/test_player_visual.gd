extends TestCase


func test_animation_follows_movement_and_shooting() -> void:
	var visual := PlayerVisual.new()
	visual.setup(ContentDB.get_character(&"balvan"))
	var body: AnimatedSprite2D = visual._body
	visual.update_look(1, Vector2.RIGHT, true, Vector2.ZERO, false)
	check_eq(body.animation, &"idle", "standing still")
	visual.update_look(1, Vector2.RIGHT, true, Vector2(200, 0), false)
	check_eq(body.animation, &"walk", "running")
	visual.update_look(-1, Vector2.LEFT, false, Vector2(0, -500), false)
	check_eq(body.animation, &"jump", "going up")
	check(body.flip_h, "faces left")
	check(visual._weapon.flip_v, "gun mirrored when aiming left")
	visual.update_look(1, Vector2.RIGHT, false, Vector2(0, 300), false)
	check_eq(body.animation, &"fall", "falling")
	visual.update_look(1, Vector2.RIGHT, true, Vector2(200, 0), true)
	check_eq(body.animation, &"shoot", "shooting wins over walking")
	check_eq(body.sprite_frames.get_frame_count(&"walk"), 4, "four walk frames")
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
