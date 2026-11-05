class_name MatchRanking
## When a network match is decided and the ranking sent to the results screen.
## Free-for-all: the last player with lives wins, the others by reverse elimination order.
## 2 v 2: the last team with lives wins (all its players share place 1), the other team 2.


## alive = players with lives left (Player or anything with `team`).
static func is_decided(alive: Array, team_mode: bool) -> bool:
	if not team_mode:
		return alive.size() <= 1
	for player in alive:
		if player.team != alive[0].team:
			return false
	return true


## alive first, then eliminated players from the last one out to the first one out.
## Rows: {"name", "place", "lives", "kills", "deaths", "team"} (see LobbyValidator.results).
static func results(alive: Array, eliminated_first_to_last: Array, team_mode: bool) -> Array:
	var ranking: Array = alive.duplicate()
	for i in range(eliminated_first_to_last.size() - 1, -1, -1):
		ranking.append(eliminated_first_to_last[i])
	var winner_team: int = ranking[0].team if team_mode and not ranking.is_empty() else Teams.NONE
	var rows: Array = []
	for i in ranking.size():
		var player: Variant = ranking[i]
		var place := i + 1
		if team_mode:
			place = 1 if player.team == winner_team else 2
		rows.append({"name": player.display_name, "place": place, "lives": player.lives,
				"kills": player.kills, "deaths": player.deaths, "team": player.team if team_mode else Teams.NONE})
	# The whole winning team first, also a teammate who ran out of lives earlier.
	return rows.filter(func(row: Dictionary) -> bool: return row.place == 1) \
			+ rows.filter(func(row: Dictionary) -> bool: return row.place != 1)
