extends TestCase


func test_six_players_with_six_characters_are_accepted() -> void:
	var lobby := {}
	for i in 6:
		lobby[i + 1] = {"name": "P%d" % (i + 1), "character": String(ContentDB.character_ids()[i]), "team": i % 3}
	check_eq(LobbyValidator.players(lobby).size(), 6, "6 players, each with another character")


func test_players_accepts_valid_lobby() -> void:
	var players := LobbyValidator.players({1: {"name": "Host", "character": "balvan"},
			55: {"name": "Kamarád", "character": "stin", "extra": 1}})
	check_eq(players.size(), 2, "two players")
	check_eq(players[55], {"name": "Kamarád", "character": "stin", "team": 0, "ready": false},
			"unknown fields dropped, team 0 and not confirmed by default")


func test_players_rejects_malformed_lobby() -> void:
	var too_many := {}  # 7 players (the limit is 6)
	for peer_id in range(1, 8):
		too_many[peer_id] = {"name": "P%d" % peer_id, "character": String(ContentDB.character_ids()[peer_id % 6])}
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
	check_eq(LobbyValidator.slots({1: 0, 7: 5}, lobby), {1: 0, 7: 5}, "slots up to 5 (6 players)")
	check(LobbyValidator.slots({1: 0, 7: 6}, lobby).is_empty(), "slot out of range")
	check(LobbyValidator.slots({1: 0, 7: "1"}, lobby).is_empty(), "slot of wrong type")


func test_results_are_limited_and_cleaned() -> void:
	var results := LobbyValidator.results([
		{"name": "x".repeat(40), "place": 9, "lives": -2, "kills": 70000, "deaths": "3", "evil": [1, 2]},
	])
	check_eq(results.size(), 1, "one row")
	check_eq(results[0], {"name": "x".repeat(16), "place": 6, "lives": 0, "kills": 65535, "deaths": 0, "team": -1,
			"character": "", "slot": -1}, "only known fields, clamped")
	var with_portrait := LobbyValidator.results([{"name": "A", "character": "stin", "slot": 3}, {"name": "B", "character": "nobody", "slot": 99}])
	check_eq([with_portrait[0].character, with_portrait[0].slot, with_portrait[1].character, with_portrait[1].slot],
			["stin", 3, "", 5], "known character kept, unknown dropped, slot clamped")
	check(LobbyValidator.results([{}, {}, {}, {}, {}, {}, {}]).is_empty(), "more rows than players")
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


func test_network_accepts_every_player_plus_one_spare() -> void:
	check_eq(EnetDirectConnector.MAX_CLIENTS, LobbyValidator.MAX_PLAYERS,
			"5 clients + 1 spare connection that gets the 'lobby full' message")
	check_eq(NetCodec.MAX_SNAPSHOT_PLAYERS, LobbyValidator.MAX_PLAYERS, "snapshots carry all 6 players")
