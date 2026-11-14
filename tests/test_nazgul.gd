extends TestCase
## The Nazgûl (Hobitín, user 2026-11-13): from 4 kills (including 4) a wraith appears every
## 12-18 s next to the player and throws him to the side of the map he is on.


func _player(slot: int, x: float, kills: int) -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(ContentDB.character_ids()[slot])
	player.slot = slot
	player.peer_id = slot + 1
	player.position = Vector2(x, 800)
	player.kills = kills
	return player


func _nazgul(players: Array) -> Nazgul:
	var arena: Arena = ContentDB.arena_or_default("hobbiton").scene.instantiate()
	var nazgul := arena.nazgul()
	arena.remove_child(nazgul)
	arena.free()
	var by_peer: Dictionary[int, Player] = {}
	for player: Player in players:
		by_peer[player.peer_id] = player
	nazgul.setup(null, true, by_peer)
	return nazgul


func _fx_count(nazgul: Nazgul) -> int:
	return nazgul.get_children().filter(func(child: Node) -> bool: return child is NazgulFx).size()


func test_only_hobbiton_has_the_nazgul() -> void:
	for id in ContentDB.arena_ids():
		var arena: Arena = ContentDB.arena_or_default(String(id)).scene.instantiate()
		check_eq(arena.nazgul() != null, id == &"hobbiton", "%s: Nazgûl only on Hobitín" % id)
		arena.free()


func test_hunts_from_four_kills_and_throws_to_the_near_side() -> void:
	var left := _player(0, 300, 3)
	var right := _player(1, 2000, 4)
	var nazgul := _nazgul([left, right])
	check_eq(nazgul.min_kills, 4, "from 4 kills, including 4 (user)")
	var alerts: Array[String] = []
	nazgul.alert.connect(func(text: String) -> void: alerts.append(text))
	var tick := 0
	nazgul.tick(tick)
	check_eq(alerts.size(), 1, "4 kills: 'Nazgûl přichází!' once")
	check_eq(alerts[0], tr("NAZGUL_COMING"), "the banner text")
	var first := Nazgul._ticks(nazgul.first_delay)
	while tick < first - 1:
		tick += 1
		nazgul.tick(tick)
	check_eq(_fx_count(nazgul), 0, "nothing before the first delay")
	tick += 1
	nazgul.tick(tick)
	check_eq(_fx_count(nazgul), 1, "the wraith appears next to the hunted player")
	check(right.velocity.is_zero_approx(), "the slash comes only after the sword is raised")
	for i in Nazgul._ticks(NazgulFx.STRIKE_TIME):
		tick += 1
		nazgul.tick(tick)
	check(right.velocity.x > 0.0 and right.velocity.y < 0.0, "right half: thrown to the right and up (%s)" % right.velocity)
	check(right.damage > 0.0, "the slash adds damage percent")
	check(left.velocity.is_zero_approx() and _fx_count(nazgul) == 1, "3 kills: not hunted")
	left.kills = 4
	nazgul.tick(tick + 1)
	check_eq(alerts.size(), 2, "another player reaching 4 kills: the banner again")
	check_eq(nazgul.direction_for(300.0), -1, "left half: thrown to the left")
	for node in [left, right, nazgul]:
		node.free()


func test_comes_back_every_12_to_18_seconds_and_waits_for_a_respawn() -> void:
	var hunted := _player(2, 1800, 6)
	var nazgul := _nazgul([hunted])
	var appearances: Array[int] = []
	for tick in 60 * 70:
		var before := _fx_count(nazgul)
		nazgul.tick(tick)
		if _fx_count(nazgul) > before:
			appearances.append(tick)
		hunted.velocity = Vector2.ZERO
	check(appearances.size() >= 4, "%d visits in 70 s" % appearances.size())
	for i in range(1, appearances.size()):
		var gap := (appearances[i] - appearances[i - 1]) / 60.0
		check(gap >= 12.0 and gap <= 18.01, "visit %d after %.1f s" % [i, gap])
	hunted.invulnerable = true
	var count := _fx_count(nazgul)
	for tick in range(60 * 70, 60 * 95):
		nazgul.tick(tick)
	check_eq(_fx_count(nazgul), count, "no visit while the player is protected after a respawn")
	hunted.invulnerable = false
	for tick in range(60 * 95, 60 * 97):
		nazgul.tick(tick)
	check_eq(_fx_count(nazgul), count + 1, "comes back within a second once he is not")
	hunted.free()
	nazgul.free()


func test_the_wraith_animation_ends_by_itself() -> void:
	var victim := _player(0, 500, 4)
	var fx := NazgulFx.new()
	fx.setup(victim, -1)
	check(fx.total_time() > NazgulFx.STRIKE_TIME and fx.total_time() < 2.0, "appear, slash and vanish within 2 s")
	fx._process(0.1)
	check(fx.position.x > victim.position.x, "thrown left: the wraith stands on his right (%s)" % fx.position)
	fx._process(fx.total_time())
	check(fx.is_queued_for_deletion(), "gone after vanishing")
	victim.free()
	fx.free()


func test_events_have_a_log_line() -> void:
	check_eq(Nazgul.describe(Nazgul.Event.COMING, 2, 0), "nazgul coming slot2", "the banner (user 2026-11-14: log it)")
	check_eq(Nazgul.describe(Nazgul.Event.STRIKE, 0, -1), "nazgul strike slot0 to=left", "a slash to the left")
	check_eq(Nazgul.describe(Nazgul.Event.STRIKE, 5, 1), "nazgul strike slot5 to=right", "a slash to the right")
