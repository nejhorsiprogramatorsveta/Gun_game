extends TestCase
## Team modes (2 teams up to 3 v 3, 3 teams of 2): lobby rules, validation, start slots,
## friendly fire and the match result.


func _player(character_id: StringName, peer_id: int, position: Vector2, team: int) -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(character_id)
	player.peer_id = peer_id
	player.position = position
	player.team = team
	return player


func _lobby(teams: Array) -> Dictionary:
	var lobby := {}
	for i in teams.size():
		lobby[i + 1] = {"team": teams[i]}
	return lobby


func test_team_rules() -> void:
	check(Teams.allies(0, 0) and not Teams.allies(0, 1) and Teams.allies(2, 2), "same team = allies")
	check(not Teams.allies(Teams.NONE, Teams.NONE), "free-for-all has no allies")
	check_eq([Teams.max_per_team(2), Teams.max_per_team(3)], [3, 2], "up to 3 v 3, or 3 teams of 2 (user 2026-11-13)")
	check(Teams.is_mode(0) and Teams.is_mode(2) and Teams.is_mode(3), "the three modes")
	for bad: Variant in [1, 4, -1, "2", 2.0, null]:
		check(not Teams.is_mode(bad), "not a mode: %s" % str(bad))
	var lobby := _lobby([0, 0, 1])
	check_eq([Teams.count(lobby, 0), Teams.count(lobby, 1), Teams.count(lobby, 0, 2)], [2, 1, 1], "team sizes")
	check_eq(Teams.smaller_team(lobby, 2), 1, "a new player joins the smaller team")
	check_eq(Teams.smaller_team(_lobby([0, 1]), 2), 0, "red on a tie")
	check_eq(Teams.smaller_team(_lobby([0, 1]), 3), 2, "3 teams: the empty green team")
	check_eq(Teams.smaller_team(_lobby([0, 1]), 0), 0, "free-for-all keeps a 2-team split")
	check(Teams.ready_to_start(lobby, 2), "both teams have players")
	check(not Teams.ready_to_start(_lobby([0, 0]), 2), "one empty team cannot start")
	check(Teams.ready_to_start(_lobby([0, 0, 0, 1, 1, 1]), 2), "3 v 3 starts")
	check(Teams.ready_to_start(_lobby([0, 0, 0, 1]), 2), "3 v 1 starts (at most 3 per team)")
	check(not Teams.ready_to_start(_lobby([0, 0, 0, 0, 1, 1]), 2), "4 v 2 cannot start")
	check(Teams.ready_to_start(_lobby([0, 0, 1, 1, 2, 2]), 3), "2 + 2 + 2 starts")
	check(Teams.ready_to_start(_lobby([0, 1, 2]), 3), "1 + 1 + 1 starts")
	check(not Teams.ready_to_start(_lobby([0, 0, 0, 1, 2]), 3), "3 teams: at most 2 per team")
	check(not Teams.ready_to_start(_lobby([0, 0, 1, 1]), 3), "3 teams: the green team must not be empty")
	check(not Teams.ready_to_start(_lobby([0, 1, 2]), 2), "2 teams: nobody may stay in green")
	check(Teams.ready_to_start(_lobby([0, 0, 0, 0]), 0), "free-for-all ignores teams")


func test_teams_start_together() -> void:
	var slots := Teams.start_slots(_lobby([1, 0, 1, 0, 0, 1]), 2)
	check_eq([slots[2], slots[4], slots[5]], [0, 2, 4], "red on the left spawns (0, 2) and centre-left (4)")
	check_eq([slots[1], slots[3], slots[6]], [1, 3, 5], "blue on the right spawns (1, 3) and centre-right (5)")
	slots = Teams.start_slots(_lobby([2, 0, 1, 2, 1, 0]), 3)
	check_eq([slots[2], slots[6], slots[3], slots[5], slots[1], slots[4]], [0, 2, 1, 3, 4, 5], "3 teams: left, right, centre")
	check_eq(Teams.start_slots(_lobby([1, 1, 0]), 0), {1: 0, 2: 1, 3: 2}, "free-for-all: slots by peer id")
	var lobby := {}
	for peer_id in [1, 5, 9, 12, 20, 33]:
		lobby[peer_id] = {"team": 0}
	var ffa := Teams.start_slots(lobby, 0)
	check_eq(LobbyValidator.slots(ffa, lobby).size(), 6, "6 players get 6 valid slots")


func test_validator_checks_team_values() -> void:
	var valid := LobbyValidator.players({1: {"name": "A", "character": "stin", "team": 1},
			2: {"name": "B", "character": "vichr", "team": 0}})
	check_eq([valid[1].team, valid[2].team], [1, 0], "teams kept")
	check_eq(LobbyValidator.players({1: {"name": "A", "character": "stin", "team": 2}})[1].team, 2, "green team kept")
	var cases := [
		{1: {"name": "A", "character": "stin", "team": 3}},
		{1: {"name": "A", "character": "stin", "team": -1}},
		{1: {"name": "A", "character": "stin", "team": "0"}},
	]
	for raw: Dictionary in cases:
		check(LobbyValidator.players(raw).is_empty(), "rejected: %s" % str(raw).left(70))
	var results := LobbyValidator.results([{"name": "A", "team": 7}, {"name": "B", "team": "x"}])
	check_eq([results[0].team, results[1].team], [2, -1], "result teams clamped")


func test_shockwave_and_cloud_spare_teammates() -> void:
	var vichr := _player(&"vichr", 1, Vector2.ZERO, 0)
	var mate := _player(&"jiskra", 2, Vector2(100, 0), 0)
	var enemy := _player(&"balvan", 3, Vector2(-100, 0), 1)
	var pushed := (vichr.character.ability as ShockwaveAbility).activate(vichr, [vichr, mate, enemy])
	check_eq(pushed, [enemy] as Array[Player], "only the enemy is pushed")
	check(mate.velocity.is_zero_approx(), "the teammate stays")
	var effects := AreaEffects.new()
	effects.teams = {7: 1, 8: 1, 9: 0}
	var gas := ContentDB.get_ability(&"gas_blast")
	effects._add(gas, 7, 1, Vector2(500, 300), 1)
	var teammate := _player(&"stin", 8, Vector2(600, 300), 1)
	var opponent := _player(&"architekt", 9, Vector2(600, 300), 0)
	var blown_after := -1
	for tick in range(1, 61):
		check(not effects.blow(teammate), "the teammate's gas does not blow")
		if blown_after < 0 and effects.blow(opponent):
			blown_after = tick
	check(teammate.velocity.is_zero_approx() and teammate.gas_ticks == 0, "the teammate stays put")
	check(blown_after > 0 and opponent.velocity.x > 0.0, "the opponent is blown away (after %d ticks)" % blown_after)
	for node in [vichr, mate, enemy, effects, teammate, opponent]:
		node.free()


func test_team_match_ends_when_one_team_is_left() -> void:
	var red_a := _player(&"stin", 1, Vector2.ZERO, 0)
	var red_b := _player(&"vichr", 2, Vector2.ZERO, 0)
	var blue_a := _player(&"balvan", 3, Vector2.ZERO, 1)
	var blue_b := _player(&"jiskra", 4, Vector2.ZERO, 1)
	check(not MatchRanking.is_decided([red_a, blue_b], true), "one of each team left: go on")
	check(MatchRanking.is_decided([red_a, red_b], true), "only red left: decided")
	check(not MatchRanking.is_decided([red_a, red_b], false), "free-for-all needs one player")
	red_a.display_name = "A"
	red_a.lives = 2
	var rows := MatchRanking.results([red_a], [red_b, blue_a, blue_b], true)
	var places := rows.map(func(row: Dictionary) -> Array: return [row.name, row.place, row.team])
	check_eq(places, [["A", 1, 0], ["", 1, 0], ["", 2, 1], ["", 2, 1]], "the whole red team wins")
	var ffa := MatchRanking.results([blue_a], [red_a, red_b], false)
	check_eq(ffa.map(func(row: Dictionary) -> int: return row.place), [1, 2, 3], "free-for-all places")
	check_eq(ffa[0].team, Teams.NONE, "no team in free-for-all")
	for node in [red_a, red_b, blue_a, blue_b]:
		node.free()


func test_three_team_match_places_teams_by_how_long_they_lasted() -> void:
	var players: Array[Player] = []
	for i in 6:
		var player := _player(ContentDB.character_ids()[i], i + 1, Vector2.ZERO, i % 3)
		player.display_name = "P%d" % (i + 1)
		players.append(player)
	# teams: 0 = P1, P4; 1 = P2, P5; 2 = P3, P6
	check(not MatchRanking.is_decided([players[0], players[1]], true), "red and blue left: go on")
	check(MatchRanking.is_decided([players[2], players[5]], true), "only green left: decided")
	# Out in this order: P1 (red), P2 (blue), P4 (red - red is out), P6 (green), P5 (blue - blue is out).
	var rows := MatchRanking.results([players[2]], [players[0], players[1], players[3], players[5], players[4]], true)
	var places := rows.map(func(row: Dictionary) -> Array: return [row.name, row.place, row.team])
	check_eq(places, [["P3", 1, 2], ["P6", 1, 2], ["P5", 2, 1], ["P2", 2, 1], ["P4", 3, 0], ["P1", 3, 0]],
			"green wins, blue lasted longer than red")
	check_eq(LobbyValidator.results(rows).size(), 6, "6 result rows pass validation")
	for player in players:
		player.free()


func test_results_table_sorts_by_kills() -> void:
	var rows := [{"name": "Winner", "place": 1, "kills": 2, "deaths": 1}, {"name": "Killer", "place": 3, "kills": 5, "deaths": 4},
			{"name": "Careful", "place": 2, "kills": 2, "deaths": 0}, {"name": "Tied", "place": 4, "kills": 2, "deaths": 0}]
	var names := ResultsTable.sorted_by_kills(rows).map(func(row: Dictionary) -> String: return row.name)
	check_eq(names, ["Killer", "Careful", "Tied", "Winner"], "kills, then fewer deaths, then who lasted longer")
	var players: Array[Player] = []
	for i in 3:
		var player := _player(ContentDB.character_ids()[i], i + 1, Vector2.ZERO, Teams.NONE)
		player.slot = i
		player.display_name = "P%d" % i
		players.append(player)
	var result_rows := MatchRanking.results([players[0]], [players[1], players[2]], false)
	check_eq([result_rows[0].character, result_rows[0].slot], [String(ContentDB.character_ids()[0]), 0], "rows carry portrait and slot")
	for player in players:
		player.free()
