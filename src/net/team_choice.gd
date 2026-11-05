class_name TeamChoice
extends Node
## Lobby game mode (free-for-all or 2 v 2) and team choice.
## Child of the Session autoload ("/root/Session/TeamChoice" on every peer).
## Only the host switches the mode; it is repeated to everyone like the arena and sent
## again with the match start (Session._begin_match), so all peers agree on it.
## A client only ASKS for a team; the host checks phase, sender and team range, stores it in
## Session.players and broadcasts (section S). Teams may be over-full in the lobby so players
## can swap; the start needs Teams.ready_to_start.

signal mode_changed

const MAX_REQUESTS_PER_SECOND := 8

var _request_counts: Dictionary[int, int] = {}
var _rate_window_start_ms := 0


func _init() -> void:
	name = "TeamChoice"  # same node path on every peer, needed for RPCs


func _ready() -> void:
	Session.players_changed.connect(_share_mode)


## Host UI: switch between free-for-all (false) and 2 v 2 (true).
func set_team_mode(enabled: bool) -> void:
	if not Session.is_host() or Session.phase != Session.Phase.LOBBY or Session.team_mode == enabled:
		return
	Session.team_mode = enabled
	_share_mode()
	mode_changed.emit()


func _share_mode() -> void:
	if Session.is_host() and Session.phase == Session.Phase.LOBBY:
		_receive_mode.rpc(Session.team_mode)


@rpc("authority", "call_remote", "reliable")
func _receive_mode(enabled: bool) -> void:
	if Session.phase != Session.Phase.LOBBY or typeof(enabled) != TYPE_BOOL:
		return
	if Session.team_mode != enabled:
		Session.team_mode = enabled
		mode_changed.emit()


## UI: the local player wants to join `team`.
func choose(team: int) -> void:
	if Session.is_host():
		_apply(multiplayer.get_unique_id(), team)
	elif Session.phase == Session.Phase.LOBBY:
		_request.rpc_id(1, team)


@rpc("any_peer", "call_remote", "reliable")
func _request(team: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and typeof(team) == TYPE_INT and not _rate_exceeded(sender):
		_apply(sender, team)


## Host: validated team change of one player; returns whether it changed.
func _apply(peer_id: int, team: int) -> bool:
	if Session.phase != Session.Phase.LOBBY or not Session.players.has(peer_id) or not Teams.is_valid(team) \
			or int(Session.players[peer_id].get("team", Teams.NONE)) == team:
		return false
	Session.players[peer_id].team = team
	Session.broadcast_players()
	return true


func _rate_exceeded(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - _rate_window_start_ms >= 1000:
		_rate_window_start_ms = now
		_request_counts.clear()
	_request_counts[peer_id] = _request_counts.get(peer_id, 0) + 1
	return _request_counts[peer_id] > MAX_REQUESTS_PER_SECOND
