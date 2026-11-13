class_name MatchRanking
## When a network match is decided and the ranking sent to the results screen.
## Free-for-all: the last player with lives wins, the others by reverse elimination order.
## Team modes (2 or 3 teams): the last team with lives wins (all its players share place 1);
## the other teams follow by how long they lasted (the team whose last player fell later
## is placed higher).


## alive = players with lives left (Player or anything with `team`).
static func is_decided(alive: Array, team_mode: bool) -> bool:
	if not team_mode:
		return alive.size() <= 1
	for player in alive:
		if player.team != alive[0].team:
			return false
	return true


## alive first, then eliminated players from the last one out to the first one out.
## Rows: {"name", "place", "lives", "kills", "deaths", "team", "character", "slot"} (see
## LobbyValidator.results), best place first; the results screen sorts them by kills.
static func results(alive: Array, eliminated_first_to_last: Array, team_mode: bool) -> Array:
	var ranking: Array = alive.duplicate()
	for i in range(eliminated_first_to_last.size() - 1, -1, -1):
		ranking.append(eliminated_first_to_last[i])
	# Team places in the order the teams first appear: the winners, then who lasted longer.
	var team_places := {}
	for player: Variant in ranking:
		if team_mode and not team_places.has(player.team):
			team_places[player.team] = team_places.size() + 1
	var rows: Array = []
	for i in ranking.size():
		var player: Variant = ranking[i]
		var place: int = team_places[player.team] if team_mode else i + 1
		rows.append({"name": player.display_name, "place": place, "lives": player.lives,
				"kills": player.kills, "deaths": player.deaths, "team": player.team if team_mode else Teams.NONE,
				"character": String(player.character.id) if player.character else "", "slot": player.slot,
				"skins": player.skins})
	# Whole teams together, best first (also a teammate who ran out of lives earlier).
	var sorted: Array = []
	for place in range(1, ranking.size() + 1):
		sorted.append_array(rows.filter(func(row: Dictionary) -> bool: return row.place == place))
	return sorted
