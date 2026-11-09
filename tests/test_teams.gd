extends TestCase
## 2 v 2 team mode: lobby rules, validation, friendly fire and the match result.


func _player(character_id: StringName, peer_id: int, position: Vector2, team: int) -> Player:
	var player := Player.new()
	player.character = ContentDB.get_character(character_id)
	player.peer_id = peer_id
	player.position = position
	player.team = team
	return player


func test_team_rules() -> void:
	check(Teams.allies(0, 0) and not Teams.allies(0, 1), "same team = allies")
	check(not Teams.allies(Teams.NONE, Teams.NONE), "free-for-all has no allies")
	var lobby := {1: {"team": 0}, 2: {"team": 0}, 3: {"team": 1}}
	check_eq([Teams.count(lobby, 0), Teams.count(lobby, 1), Teams.count(lobby, 0, 2)], [2, 1, 1], "team sizes")
	check_eq(Teams.smaller_team(lobby), 1, "a new player joins the smaller team")
	check_eq(Teams.smaller_team({1: {"team": 0}, 2: {"team": 1}}), 0, "red on a tie")
	check(Teams.ready_to_start(lobby), "both teams have players")
	check(not Teams.ready_to_start({1: {"team": 0}, 2: {"team": 0}}), "one empty team cannot start")
	check(not Teams.ready_to_start({1: {"team": 0}, 2: {"team": 0}, 3: {"team": 0}, 4: {"team": 1}}),
			"3 v 1 cannot start")


func test_validator_checks_team_values() -> void:
	var valid := LobbyValidator.players({1: {"name": "A", "character": "stin", "team": 1},
			2: {"name": "B", "character": "vichr", "team": 0}})
	check_eq([valid[1].team, valid[2].team], [1, 0], "teams kept")
	var cases := [
		{1: {"name": "A", "character": "stin", "team": 2}},
		{1: {"name": "A", "character": "stin", "team": -1}},
		{1: {"name": "A", "character": "stin", "team": "0"}},
	]
	for raw: Dictionary in cases:
		check(LobbyValidator.players(raw).is_empty(), "rejected: %s" % str(raw).left(70))
	var results := LobbyValidator.results([{"name": "A", "team": 7}, {"name": "B", "team": "x"}])
	check_eq([results[0].team, results[1].team], [1, -1], "result teams clamped")


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
	check(not effects.blow(teammate) and teammate.velocity.is_zero_approx(), "the teammate's gas does not blow")
	check(effects.blow(opponent) and opponent.velocity.x > 0.0, "the opponent is blown away")
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
