extends TestCase


func test_players_accepts_valid_lobby() -> void:
	var players := LobbyValidator.players({1: {"name": "Host", "character": "balvan"},
			55: {"name": "Kamarád", "character": "stin", "extra": 1}})
	check_eq(players.size(), 2, "two players")
	check_eq(players[55], {"name": "Kamarád", "character": "stin"}, "unknown fields dropped")


func test_players_rejects_malformed_lobby() -> void:
	var too_many := {1: {"name": "A", "character": "balvan"}, 2: {"name": "B", "character": "jiskra"},
			3: {"name": "C", "character": "stin"}, 4: {"name": "D", "character": "vichr"}, 5: {"name": "E", "character": "architekt"}}
	var cases := [
		{}, too_many, {2: {"name": "No host", "character": "stin"}},
		{1: {"name": "A", "character": "stin"}, "x": {"name": "B", "character": "vichr"}},
		{1: {"name": "A", "character": "stin"}, -3: {"name": "B", "character": "vichr"}},
		{1: "not a dict"}, {1: {"name": 5, "character": "stin"}}, {1: {"name": "   ", "character": "stin"}},
		{1: {"name": "x".repeat(17), "character": "stin"}},
		{1: {"name": "A"}}, {1: {"name": "A", "character": "nobody"}}, {1: {"name": "A", "character": 3}},
		{1: {"name": "A", "character": "stin"}, 2: {"name": "B", "character": "stin"}},
	]
	for raw: Dictionary in cases:
		check(LobbyValidator.players(raw).is_empty(), "rejected: %s" % str(raw).left(60))


func test_slots_must_match_lobby_and_be_unique() -> void:
	var lobby := {1: {"name": "A", "character": "stin"}, 7: {"name": "B", "character": "vichr"}}
	check_eq(LobbyValidator.slots({1: 0, 7: 1}, lobby), {1: 0, 7: 1}, "valid slots")
	check(LobbyValidator.slots({1: 0}, lobby).is_empty(), "a match needs two players")
	check(LobbyValidator.slots({1: 0, 9: 1}, lobby).is_empty(), "unknown peer")
	check(LobbyValidator.slots({1: 0, 7: 0}, lobby).is_empty(), "duplicate slot")
	check(LobbyValidator.slots({1: 0, 7: 4}, lobby).is_empty(), "slot out of range")
	check(LobbyValidator.slots({1: 0, 7: "1"}, lobby).is_empty(), "slot of wrong type")


func test_results_are_limited_and_cleaned() -> void:
	var results := LobbyValidator.results([
		{"name": "x".repeat(40), "place": 9, "lives": -2, "kills": 70000, "deaths": "3", "evil": [1, 2]},
	])
	check_eq(results.size(), 1, "one row")
	check_eq(results[0], {"name": "x".repeat(16), "place": 4, "lives": 0, "kills": 65535, "deaths": 0},
			"only known fields, clamped")
	check(LobbyValidator.results([{}, {}, {}, {}, {}]).is_empty(), "more rows than players")
	check(LobbyValidator.results([{"name": "A"}, "row"]).is_empty(), "row of wrong type")


func test_clean_name_trims_and_defaults() -> void:
	check_eq(LobbyValidator.clean_name("  Ninja  ", 1), "Ninja", "trimmed")
	check_eq(LobbyValidator.clean_name("x".repeat(30), 1).length(), LobbyValidator.MAX_NAME_LENGTH, "shortened")
	check(not LobbyValidator.clean_name("   ", 3).is_empty(), "empty name gets a default")


func test_first_free_character_prefers_the_favourite() -> void:
	var lobby := {1: {"name": "A", "character": "architekt"}, 2: {"name": "B", "character": "stin"}}
	check_eq(CharacterChoice.first_free(lobby, "vichr"), "vichr", "the favourite when free")
	check_eq(CharacterChoice.first_free(lobby, "stin"), "balvan", "taken favourite -> first free in order")
	check_eq(CharacterChoice.first_free(lobby, "unknown"), "balvan", "unknown favourite ignored")
	check(CharacterChoice.is_taken(lobby, "stin", 1), "taken by another player")
	check(not CharacterChoice.is_taken(lobby, "stin", 2), "own character is not 'taken'")
