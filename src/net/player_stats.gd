class_name PlayerStats
extends Node
## Lifetime statistics in the lobby (user 2026-11-13: "players in the lobby have their
## statistics - kills and deaths over all games"). Every player keeps his own totals of
## online matches (Settings.total_*, counted at each match's results) and reports them when
## he is in the lobby; the host stores them in Session.players (kills_total, deaths_total,
## matches_total) and broadcasts. Self-reported numbers, only shown - they decide nothing.
## Child of the Session autoload ("/root/Session/PlayerStats" on every peer).

const MAX_REQUESTS_PER_SECOND := 4
const MAX_VALUE := 99999999

var _request_counts: Dictionary[int, int] = {}
var _rate_window_start_ms := 0


func _init() -> void:
	name = "PlayerStats"  # same node path on every peer, needed for RPCs


## The local player's totals, as stored in Session.players.
static func own() -> Dictionary:
	return {"kills_total": Settings.total_kills, "deaths_total": Settings.total_deaths,
			"matches_total": Settings.total_matches}


## Tell everyone the local totals (host: store and broadcast; client: ask the host).
func report() -> void:
	var totals := own()
	if Session.is_host():
		_apply(multiplayer.get_unique_id(), totals.kills_total, totals.deaths_total, totals.matches_total)
	elif Session.phase == Session.Phase.LOBBY:
		_request.rpc_id(1, totals.kills_total, totals.deaths_total, totals.matches_total)


@rpc("any_peer", "call_remote", "reliable")
func _request(kills: int, deaths: int, matches: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and not _rate_exceeded(sender):
		_apply(sender, kills, deaths, matches)


## Host: validated totals of one player; broadcasts when they changed.
func _apply(peer_id: int, kills: int, deaths: int, matches: int) -> bool:
	if not Session.players.has(peer_id):
		return false
	var entry: Dictionary = Session.players[peer_id]
	var totals := {"kills_total": clampi(kills, 0, MAX_VALUE), "deaths_total": clampi(deaths, 0, MAX_VALUE),
			"matches_total": clampi(matches, 0, MAX_VALUE)}
	if totals.kills_total == entry.get("kills_total", 0) and totals.deaths_total == entry.get("deaths_total", 0) \
			and totals.matches_total == entry.get("matches_total", 0):
		return false
	entry.merge(totals, true)
	Session.broadcast_players()
	return true


func _rate_exceeded(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - _rate_window_start_ms >= 1000:
		_rate_window_start_ms = now
		_request_counts.clear()
	_request_counts[peer_id] = _request_counts.get(peer_id, 0) + 1
	return _request_counts[peer_id] > MAX_REQUESTS_PER_SECOND
