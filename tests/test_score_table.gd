extends TestCase
## In-match scoreboard size (user 2026-11-13: the free-for-all tables took too much of the
## screen). The 1280 x 720 viewport is the reference.


func test_free_for_all_table_stays_small() -> void:
	var table := ScoreTable.new()
	table.setup("", Color.WHITE, 4)
	var players: Array = []
	for slot in 4:
		var player := Player.new()
		player.slot = slot
		player.display_name = "Hrac_s_velmi_dlouhym_jmenem_%d" % slot
		players.append(player)
	table.show_players(players, true)
	var size := table.get_combined_minimum_size()
	check(size.x <= 340.0, "at most ~a quarter of the width, even with long names (%.0f px)" % size.x)
	check(size.y <= 130.0, "4 rows plus the heading under 130 px (%.0f px)" % size.y)
	for player: Player in players:
		player.free()
	table.free()
