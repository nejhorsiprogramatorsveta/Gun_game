class_name CharacterChoice
extends Node
## Lobby character choice (PLAN.md T.2, G.0a): every character at most once per match.
## Child of the Session autoload ("/root/Session/CharacterChoice" on every peer).
## Clicking a card only selects it locally; the player then CONFIRMS it (`choose`). Until
## then everyone holds a placeholder character ("ready" = false) that blocks nobody: a
## confirmation takes a character from an unconfirmed holder, who gets another free one.
## The match starts only when everyone confirmed (all_confirmed).
## A client only ASKS; the host checks phase, sender, that the character exists and is not
## confirmed by someone else, stores it in Session.players and broadcasts (section S).

## Requests above this rate are ignored (a legit click is a few per second at most).
const MAX_REQUESTS_PER_SECOND := 8
const MAX_ID_LENGTH := 32

var _request_counts: Dictionary[int, int] = {}
var _rate_window_start_ms := 0


func _init() -> void:
	name = "CharacterChoice"  # same node path on every peer, needed for RPCs


## First free character, preferring `preferred` (e.g. the one picked in the main menu).
static func first_free(players: Dictionary, preferred: String) -> String:
	if not preferred.is_empty() and ContentDB.get_character(StringName(preferred)) and not is_taken(players, preferred, 0):
		return preferred
	for id in ContentDB.character_ids():
		if not is_taken(players, String(id), 0):
			return String(id)
	return String(ContentDB.DEFAULT_CHARACTER_ID)


static func is_taken(players: Dictionary, character_id: String, except_peer_id: int) -> bool:
	return holder(players, character_id, except_peer_id) != 0


## Peer (other than except_peer_id) holding the character, or 0.
static func holder(players: Dictionary, character_id: String, except_peer_id: int) -> int:
	for peer_id: int in players:
		if peer_id != except_peer_id and str(players[peer_id].get("character", "")) == character_id:
			return peer_id
	return 0


## Peer (other than except_peer_id) who CONFIRMED the character, or 0.
static func confirmed_by(players: Dictionary, character_id: String, except_peer_id: int) -> int:
	var peer_id := holder(players, character_id, except_peer_id)
	return peer_id if peer_id != 0 and players[peer_id].get("ready", false) else 0


static func all_confirmed(players: Dictionary) -> bool:
	for peer_id: int in players:
		if not players[peer_id].get("ready", false):
			return false
	return true


## UI: the local player confirms `character_id`.
func choose(character_id: String) -> void:
	if Session.is_host():
		_apply(multiplayer.get_unique_id(), character_id)
	elif Session.phase == Session.Phase.LOBBY:
		_request.rpc_id(1, character_id)


@rpc("any_peer", "call_remote", "reliable")
func _request(character_id: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and not _rate_exceeded(sender):
		_apply(sender, character_id)


## Host: validated confirmation of one player's character; returns whether it changed.
func _apply(peer_id: int, character_id: String) -> bool:
	if Session.phase != Session.Phase.LOBBY or not Session.players.has(peer_id) \
			or character_id.length() > MAX_ID_LENGTH or ContentDB.get_character(StringName(character_id)) == null \
			or confirmed_by(Session.players, character_id, peer_id) != 0:
		return false
	var me: Dictionary = Session.players[peer_id]
	if me.get("character") == character_id and me.get("ready", false):
		return false
	var previous_holder := holder(Session.players, character_id, peer_id)
	if previous_holder != 0:
		Session.players[previous_holder].character = ""
	me.character = character_id
	me.ready = true
	if previous_holder != 0:  # an unconfirmed placeholder: give that player another free one
		Session.players[previous_holder].character = first_free(Session.players, "")
	Session.broadcast_players()
	return true


func _rate_exceeded(peer_id: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - _rate_window_start_ms >= 1000:
		_rate_window_start_ms = now
		_request_counts.clear()
	_request_counts[peer_id] = _request_counts.get(peer_id, 0) + 1
	return _request_counts[peer_id] > MAX_REQUESTS_PER_SECOND
