class_name Teams
## Game modes shared by the lobby, the match and the HUD (user 2026-11-13): free-for-all,
## 2 teams (up to 3 v 3) or 3 teams of 2. Session.team_count holds the mode (0 = free-for-all).
## Team 0 = red (scoreboard on the left), 1 = blue (right), 2 = green (top); -1 = no team.

const NONE := -1
const FREE_FOR_ALL := 0
## Allowed Session.team_count values, in the order of the lobby's mode picker.
const MODES: Array[int] = [FREE_FOR_ALL, 2, 3]
const MAX_COUNT := 3
const NAME_KEYS: Array[String] = ["TEAM_RED", "TEAM_BLUE", "TEAM_GREEN"]
const COLORS: Array[Color] = [Color(1, 0.42, 0.38), Color(0.4, 0.68, 1), Color(0.5, 0.9, 0.42)]
## Start slots of each team per mode. A slot is also the arena spawn point, and every arena
## lists its spawns as left, right, left, right, centre-left, centre-right, so a team starts
## together: 2 teams = left / right side, 3 teams = left / right / centre.
const START_SLOTS := {2: [[0, 2, 4], [1, 3, 5]], 3: [[0, 2], [1, 3], [4, 5]]}


static func is_valid(team: int) -> bool:
	return team >= 0 and team < MAX_COUNT


static func is_mode(team_count: Variant) -> bool:
	return typeof(team_count) == TYPE_INT and MODES.has(team_count)


## Most players one team may have when the match starts: 3 (2 teams) or 2 (3 teams).
static func max_per_team(team_count: int) -> int:
	return LobbyValidator.MAX_PLAYERS / team_count if team_count > 0 else LobbyValidator.MAX_PLAYERS


## Teammates never hurt, push or slow each other. Without teams nobody is an ally.
static func allies(team_a: int, team_b: int) -> bool:
	return is_valid(team_a) and team_a == team_b


## players: peer_id -> {"team": int, ...}
static func count(players: Dictionary, team: int, except_peer_id: int = 0) -> int:
	var total := 0
	for peer_id: int in players:
		if peer_id != except_peer_id and int(players[peer_id].get("team", NONE)) == team:
			total += 1
	return total


## Where a newly joined (or moved) player goes: the team with the fewest players among the
## mode's teams, the first one on a tie. Free-for-all keeps the 2-team split ready.
static func smaller_team(players: Dictionary, team_count: int, except_peer_id: int = 0) -> int:
	var best := 0
	for team in range(1, maxi(team_count, 2)):
		if count(players, team, except_peer_id) < count(players, best, except_peer_id):
			best = team
	return best


## Players may move freely between teams in the lobby (so they can rearrange); a team match
## starts only when every team has 1..max_per_team players and nobody is in a team the mode
## does not have.
static func ready_to_start(players: Dictionary, team_count: int) -> bool:
	if team_count <= 0:
		return true
	var placed := 0
	for team in team_count:
		var members := count(players, team)
		if members == 0 or members > max_per_team(team_count):
			return false
		placed += members
	return placed == players.size()


## peer_id -> slot for the match start (see START_SLOTS); free-for-all: by peer id.
static func start_slots(players: Dictionary, team_count: int) -> Dictionary:
	var ids := players.keys()
	ids.sort()
	var slots := {}
	var taken: Array[int] = [0, 0, 0]
	for i in ids.size():
		if team_count <= 0:
			slots[ids[i]] = i
			continue
		var team := int(players[ids[i]].get("team", 0))
		slots[ids[i]] = START_SLOTS[team_count][team][taken[team]]
		taken[team] += 1
	return slots


static func color(team: int) -> Color:
	return COLORS[team] if is_valid(team) else Color.WHITE
