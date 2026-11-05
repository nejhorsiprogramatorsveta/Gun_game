class_name LobbyValidator
## Checks lobby/match-flow data before Session uses it (PLAN.md section S, defense in depth).
## Clients only accept these messages from the host, but a buggy or modified host must still
## not be able to break the UI with huge or malformed data. Invalid input -> empty result.

const MAX_PLAYERS := 4
const MAX_NAME_LENGTH := 16
const MAX_SCORE := 65535


## Trims a requested player name; empty names become the translated default.
static func clean_name(raw_name: String, number: int) -> String:
	var cleaned := raw_name.strip_edges().left(MAX_NAME_LENGTH)
	if cleaned.is_empty():
		cleaned = TranslationServer.translate("LOBBY_DEFAULT_NAME").format({"number": number})
	return cleaned


## peer_id -> {"name": String, "character": String, "team": int, "ready": bool}; must contain
## the host (peer 1), every character must exist and be used at most once, team 0 or 1
## (missing = 0), "ready" = character confirmed (missing = false).
static func players(raw: Dictionary) -> Dictionary[int, Dictionary]:
	var result: Dictionary[int, Dictionary] = {}
	if raw.size() < 1 or raw.size() > MAX_PLAYERS or not raw.has(1):
		return result
	var used_characters: Dictionary[String, bool] = {}
	for peer_id: Variant in raw:
		var entry: Variant = raw[peer_id]
		if typeof(peer_id) != TYPE_INT or peer_id <= 0 or typeof(entry) != TYPE_DICTIONARY:
			return {}
		var character: Variant = entry.get("character")
		if typeof(character) != TYPE_STRING or character.length() > 32 or used_characters.has(character) \
				or ContentDB.get_character(StringName(character)) == null:
			return {}
		used_characters[character] = true
		var player_name: Variant = entry.get("name")
		if typeof(player_name) != TYPE_STRING or player_name.strip_edges().is_empty() \
				or player_name.length() > MAX_NAME_LENGTH:
			return {}
		var team: Variant = entry.get("team", 0)
		if typeof(team) != TYPE_INT or not Teams.is_valid(team):
			return {}
		var ready: Variant = entry.get("ready", false)
		if typeof(ready) != TYPE_BOOL:
			return {}
		result[peer_id] = {"name": player_name, "character": character, "team": team, "ready": ready}
	return result


## peer_id -> slot; every peer must be a lobby player, slots 0..3 unique, at least 2 players.
static func slots(raw: Dictionary, lobby_players: Dictionary) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	if raw.size() < 2 or raw.size() > MAX_PLAYERS:
		return result
	var used: Dictionary[int, bool] = {}
	for peer_id: Variant in raw:
		var slot: Variant = raw[peer_id]
		if typeof(peer_id) != TYPE_INT or not lobby_players.has(peer_id) or typeof(slot) != TYPE_INT \
				or slot < 0 or slot >= MAX_PLAYERS or used.has(slot):
			return {}
		used[slot] = true
		result[peer_id] = slot
	return result


## Ranking for the results screen: at most 4 rows with only the known, range-limited fields.
static func results(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw.size() > MAX_PLAYERS:
		return result
	for entry: Variant in raw:
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("name")) != TYPE_STRING:
			return []
		result.append({
			"name": str(entry.name).left(MAX_NAME_LENGTH),
			"place": clampi(_int(entry, "place"), 1, MAX_PLAYERS),
			"lives": clampi(_int(entry, "lives"), 0, MAX_SCORE),
			"kills": clampi(_int(entry, "kills"), 0, MAX_SCORE),
			"deaths": clampi(_int(entry, "deaths"), 0, MAX_SCORE),
			"team": clampi(_int(entry, "team", Teams.NONE), Teams.NONE, Teams.COUNT - 1),
		})
	return result


static func _int(entry: Dictionary, key: String, default: int = 0) -> int:
	var value: Variant = entry.get(key, default)
	return value if typeof(value) == TYPE_INT else default
