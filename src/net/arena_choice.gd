class_name ArenaChoice
extends Node
## Arena (map) choice in the lobby, PLAN.md T.2: only the host chooses, everyone sees it.
## Child of the Session autoload ("/root/Session/ArenaChoice" on every peer). The match
## itself uses the arena sent along with the start (Session._begin_match), so a late or
## lost update here can never start different maps on different computers.

signal changed

const MAX_ID_LENGTH := 32


func _init() -> void:
	name = "ArenaChoice"  # same node path on every peer, needed for RPCs


func _ready() -> void:
	# Whenever the lobby changes (e.g. someone joined), the host repeats the current arena.
	Session.players_changed.connect(_share)


## Host UI: pick an arena (unknown ids fall back to the default arena).
func choose(arena_id: String) -> void:
	if not Session.is_host() or Session.phase != Session.Phase.LOBBY:
		return
	Session.arena_id = String(ContentDB.arena_or_default(arena_id).id)
	_share()
	changed.emit()


func _share() -> void:
	if Session.is_host() and Session.phase == Session.Phase.LOBBY:
		_receive.rpc(Session.arena_id)


@rpc("authority", "call_remote", "reliable")
func _receive(arena_id: String) -> void:
	if Session.phase != Session.Phase.LOBBY or arena_id.length() > MAX_ID_LENGTH:
		return
	Session.arena_id = String(ContentDB.arena_or_default(arena_id).id)
	changed.emit()
