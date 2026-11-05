extends TestCase
## Magazines and the 1-second reload (Player.use_round / tick_reload / refill on respawn).


func _player(character_id: StringName) -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(character_id)
	player.refill_magazine()
	return player


func test_every_weapon_has_a_magazine_and_one_second_reload() -> void:
	for id in ContentDB.character_ids():
		var weapon := ContentDB.get_character(id).weapon
		check(weapon.magazine_size >= 2, "%s: a magazine" % weapon.id)
		check(is_equal_approx(weapon.reload_time, 1.0), "%s: one second reload" % weapon.id)
	var sniper := ContentDB.get_weapon(&"sniper")
	var smg := ContentDB.get_weapon(&"smg")
	check(sniper.magazine_size < smg.magazine_size, "the sniper rifle runs dry sooner than the SMG")
	check(sniper.projectile_speed >= 3000.0, "Stín's bullets are fast to balance the slow fire rate")


func test_last_round_starts_reload_and_reload_refills() -> void:
	var stin := _player(&"stin")
	var size := stin.current_weapon().magazine_size
	check_eq([stin.ammo, stin.is_reloading()], [size, false], "starts full")
	for i in size:
		stin.use_round()
	check_eq([stin.ammo, stin.is_reloading()], [0, true], "empty magazine reloads")
	check(stin.tick_reload(0.5), "half a second later still reloading")
	check(not stin.tick_reload(0.5), "after one second the gun can fire again")
	check_eq([stin.ammo, stin.is_reloading()], [size, false], "magazine full again")
	stin.free()


func test_respawn_resets_the_magazine() -> void:
	var jiskra := _player(&"jiskra")
	for i in 5:
		jiskra.use_round()
	jiskra.reset_to(Vector2.ZERO)
	check_eq(jiskra.ammo, jiskra.current_weapon().magazine_size, "half-empty magazine is full after a respawn")
	for i in jiskra.current_weapon().magazine_size:
		jiskra.use_round()
	jiskra.reset_to(Vector2.ZERO)
	check_eq([jiskra.ammo, jiskra.is_reloading()], [jiskra.current_weapon().magazine_size, false], "a respawn also ends a reload")
	jiskra.free()


func test_reload_state_reaches_clients() -> void:
	var host := _player(&"vichr")
	for i in host.current_weapon().magazine_size:
		host.use_round()
	var state := host.snapshot_state()
	check_eq([state.ammo, state.reloading], [0, true], "snapshot carries ammo and reload")
	var client := _player(&"vichr")
	client._apply_state(state)
	check(client.is_reloading() and client.ammo == 0, "client shows the reload")
	check(client.reload_progress() >= 0.0, "client animates it")
	state.reloading = false
	state.ammo = 10
	client._apply_state(state)
	check_eq([client.is_reloading(), client.ammo, client.reload_progress()], [false, 10, -1.0], "and stops it")
	host.free()
	client.free()
