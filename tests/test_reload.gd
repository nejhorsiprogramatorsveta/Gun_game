extends TestCase
## Magazines and the 1-second reload (PlayerWeapon.use_round / tick_reload / refill on respawn).


func _player(character_id: StringName) -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(character_id)
	player.gun.refill()
	return player


func test_every_weapon_has_a_magazine_and_one_second_reload() -> void:
	for id in ContentDB.character_ids():
		var weapon := ContentDB.get_character(id).weapon
		check(weapon.magazine_size >= 2, "%s: a magazine" % weapon.id)
		# Balvan's heavy machine gun reloads longer (user 2026-11-13).
		var expected := 2.0 if weapon.id == &"heavy_machine_gun" else 1.0
		check(is_equal_approx(weapon.reload_time, expected), "%s: %.0f s reload" % [weapon.id, expected])
	var sniper := ContentDB.get_weapon(&"sniper")
	var smg := ContentDB.get_weapon(&"smg")
	check(sniper.magazine_size < smg.magazine_size, "the sniper rifle runs dry sooner than the SMG")
	check(sniper.projectile_speed >= 3000.0, "Stín's bullets are fast to balance the slow fire rate")


func test_last_round_starts_reload_and_reload_refills() -> void:
	var stin := _player(&"stin")
	var size := stin.current_weapon().magazine_size
	check_eq([stin.gun.ammo, stin.gun.is_reloading()], [size, false], "starts full")
	for i in size:
		stin.gun.use_round()
	check_eq([stin.gun.ammo, stin.gun.is_reloading()], [0, true], "empty magazine reloads")
	check(stin.gun.tick_reload(0.5), "half a second later still reloading")
	check(not stin.gun.tick_reload(0.5), "after one second the gun can fire again")
	check_eq([stin.gun.ammo, stin.gun.is_reloading()], [size, false], "magazine full again")
	stin.free()


func test_respawn_resets_the_magazine() -> void:
	var jiskra := _player(&"jiskra")
	for i in 5:
		jiskra.gun.use_round()
	jiskra.reset_to(Vector2.ZERO)
	check_eq(jiskra.gun.ammo, jiskra.current_weapon().magazine_size, "half-empty magazine is full after a respawn")
	for i in jiskra.current_weapon().magazine_size:
		jiskra.gun.use_round()
	jiskra.reset_to(Vector2.ZERO)
	check_eq([jiskra.gun.ammo, jiskra.gun.is_reloading()], [jiskra.current_weapon().magazine_size, false], "a respawn also ends a reload")
	jiskra.free()


func test_reload_state_reaches_clients() -> void:
	var host := _player(&"vichr")
	for i in host.current_weapon().magazine_size:
		host.gun.use_round()
	var state := host.snapshot_state()
	check_eq([state.ammo, state.reloading], [0, true], "snapshot carries ammo and reload")
	var client := _player(&"vichr")
	client._apply_state(state)
	check(client.gun.is_reloading() and client.gun.ammo == 0, "client shows the reload")
	check(client.gun.reload_progress() >= 0.0, "client animates it")
	state.reloading = false
	state.ammo = 10
	client._apply_state(state)
	check_eq([client.gun.is_reloading(), client.gun.ammo, client.gun.reload_progress()], [false, 10, -1.0], "and stops it")
	host.free()
	client.free()


func test_manual_reload_only_with_rounds_missing() -> void:
	var krugermann := _player(&"krugermann")
	var size := krugermann.current_weapon().magazine_size
	var reload := InputFrame.create(0, InputFrame.RELOAD)
	check(not krugermann.tick_weapon(reload, 1.0 / 60.0) and not krugermann.gun.is_reloading(), "full magazine: Q does nothing")
	krugermann.gun.use_round()
	krugermann.gun.use_round()
	check(not krugermann.tick_weapon(reload, 1.0 / 60.0), "Q never fires")
	check(krugermann.gun.is_reloading(), "rounds missing: Q starts the reload")
	check_eq(krugermann.gun.ammo, size - 2, "rounds stay until the reload ends")
	var left := krugermann.gun.reload_time_left
	krugermann.tick_weapon(reload, 0.5)
	check(krugermann.gun.reload_time_left < left, "holding Q does not restart the reload")
	var fire := InputFrame.create(0, InputFrame.FIRE)
	check(not krugermann.tick_weapon(fire, 0.25), "no shot while reloading")
	krugermann.tick_weapon(InputFrame.new(), 0.25)
	check_eq([krugermann.gun.ammo, krugermann.gun.is_reloading()], [size, false], "after 1 s the magazine is full")
	krugermann.free()
