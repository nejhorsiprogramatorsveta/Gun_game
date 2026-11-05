class_name Teams
## Team mode (2 v 2) rules shared by the lobby, the match and the HUD.
## Team 0 = red (scoreboard on the left), team 1 = blue (right); -1 = no team (free-for-all).

const COUNT := 2
const MAX_PER_TEAM := 2
const NONE := -1
const NAME_KEYS: Array[String] = ["TEAM_RED", "TEAM_BLUE"]
const COLORS: Array[Color] = [Color(1, 0.42, 0.38), Color(0.4, 0.68, 1)]


static func is_valid(team: int) -> bool:
	return team >= 0 and team < COUNT


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


## Where a newly joined player goes: the smaller team (red on a tie).
static func smaller_team(players: Dictionary) -> int:
	return 1 if count(players, 1) < count(players, 0) else 0


## Players may move freely between teams in the lobby (so four players can rearrange);
## a team match starts only with 1..MAX_PER_TEAM players in each team.
static func ready_to_start(players: Dictionary) -> bool:
	for team in COUNT:
		if count(players, team) == 0 or count(players, team) > MAX_PER_TEAM:
			return false
	return true


static func color(team: int) -> Color:
	return COLORS[team] if is_valid(team) else Color.WHITE
