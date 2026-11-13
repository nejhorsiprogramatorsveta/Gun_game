extends Node
## AUTOLOAD "Session": the network session, alive across scene changes.
## Owns hosting/joining, the version handshake and the lobby player list.
## Host-authoritative: only the host (peer 1) changes `players` and broadcasts them.
##
## The join handshake (version + room code) lives in the child SessionAuth: until it
## completes, a peer cannot send or receive any RPC.

signal phase_changed(phase: Phase)
signal players_changed
## The session is over: failed to start, rejected, connection lost or left on purpose
## (message is then empty). The message is already translated for the UI.
signal ended(message: String)

enum Phase { OFFLINE, CONNECTING, LOBBY, IN_MATCH, RESULTS }

const MAX_PLAYERS := LobbyValidator.MAX_PLAYERS
const MIN_PLAYERS_TO_START := 2
const MAX_NAME_LENGTH := LobbyValidator.MAX_NAME_LENGTH
const CONNECT_TIMEOUT := 10.0

var phase := Phase.OFFLINE
## peer_id -> {"name": String, "character": String, "team": int, "ready": bool (character
## confirmed)}. Identical on all peers (host broadcasts it).
var players: Dictionary[int, Dictionary] = {}
## Why the last session ended (translated), so the main menu can show it after a
## scene change. The menu clears it once shown.
var last_end_message := ""
var host_port := EnetDirectConnector.DEFAULT_PORT
## peer_id -> slot (0..5) of the running match; identical on all peers.
var match_slots: Dictionary[int, int] = {}
## Ranking of the last match: [{"name": String, "place": int, "lives": int}], best first.
var match_results: Array = []
## Host: secret that friends need to join (sent along with the address as "ip:port#CODE").
var room_code := ""
## Arena of the lobby / running match (ArenaChoice in the lobby, fixed by _begin_match).
var arena_id := ""
## Game mode: 0 = free-for-all, 2 or 3 teams (Teams.MODES; TeamChoice in the lobby, fixed
## by _begin_match).
var team_count := Teams.FREE_FOR_ALL

var _connector: Connector = EnetDirectConnector.new()
var _join_address := ""
## Join handshake (room code, version, pending names), see session_auth.gd.
var _auth := SessionAuth.new()


func _ready() -> void:
	var api := multiplayer as SceneMultiplayer
	# Clients may only talk to the host, never relay RPCs to each other (PLAN.md S).
	api.server_relay = false
	add_child(CharacterChoice.new())  # character choice RPCs, see character_choice.gd
	add_child(ArenaChoice.new())  # arena choice RPCs, see arena_choice.gd
	add_child(TeamChoice.new())  # game mode and team RPCs, see team_choice.gd
	add_child(ConnectionLog.new())  # diagnostics in the game log, see connection_log.gd
	add_child(_auth)  # join handshake, see session_auth.gd
	api.peer_authentication_failed.connect(_on_peer_authentication_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_lost)
	multiplayer.server_disconnected.connect(_on_connection_lost)


func _notification(what: int) -> void:
	# Closing the window tells the other peers right away instead of after a timeout.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		leave()


func is_host() -> bool:
	return phase != Phase.OFFLINE and multiplayer.is_server()


func can_start_match() -> bool:
	return is_host() and phase == Phase.LOBBY and players.size() >= MIN_PLAYERS_TO_START \
			and CharacterChoice.all_confirmed(players) and Teams.ready_to_start(players, team_count)


## Host: starts the match for everyone in the lobby (free-for-all: slots by peer id, host =
## slot 0; teams start together, see Teams.START_SLOTS).
func start_match() -> void:
	if not can_start_match():
		return
	_begin_match.rpc(Teams.start_slots(players, team_count), arena_id, team_count)


@rpc("authority", "call_local", "reliable")
func _begin_match(slots: Dictionary, arena: String, teams: Variant) -> void:
	var valid_slots := LobbyValidator.slots(slots, players)
	if phase != Phase.LOBBY or valid_slots.is_empty() or arena.length() > ArenaChoice.MAX_ID_LENGTH \
			or not Teams.is_mode(teams):
		return
	match_slots = valid_slots
	team_count = teams
	arena_id = String(ContentDB.arena_or_default(arena).id)
	_set_phase(Phase.IN_MATCH)


## Host: the match is decided; everyone sees the results (PLAN.md T.1).
func end_match(results: Array) -> void:
	if is_host() and phase == Phase.IN_MATCH:
		_end_match.rpc(results)


@rpc("authority", "call_local", "reliable")
func _end_match(results: Array) -> void:
	if phase != Phase.IN_MATCH:
		return
	match_results = LobbyValidator.results(results)
	_set_phase(Phase.RESULTS)


## Host: everyone goes back to the same lobby; the session (and room code) stays open.
func return_to_lobby() -> void:
	if is_host() and phase in [Phase.IN_MATCH, Phase.RESULTS]:
		_return_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _return_to_lobby() -> void:
	if phase != Phase.IN_MATCH and phase != Phase.RESULTS:
		return
	match_slots.clear()
	_set_phase(Phase.LOBBY)


## Addresses the host can share with friends, each including the room code
## ("ip:port#CODE"), see Connector.share_addresses.
func share_addresses() -> Array[Dictionary]:
	if not is_host():
		return []
	var entries := _connector.share_addresses(host_port)
	for entry in entries:
		entry.address += "#" + room_code
	return entries


func host_game(player_name: String, port: int = EnetDirectConnector.DEFAULT_PORT) -> void:
	leave()
	DiagLog.begin_game()
	var peer := _connector.host(port)
	if peer == null:
		_emit_ended(tr("ERROR_HOST_FAILED").format({"port": port}))
		return
	multiplayer.multiplayer_peer = peer
	host_port = port
	room_code = Handshake.generate_room_code()
	arena_id = String(ContentDB.arena_or_default(Settings.practice_arena).id)
	team_count = Teams.FREE_FOR_ALL
	players = {1: {"name": LobbyValidator.clean_name(player_name, 1),
			"character": CharacterChoice.first_free({}, Settings.practice_character), "team": 0, "ready": false}}
	_set_phase(Phase.LOBBY)
	players_changed.emit()


## join_text is what the host shared: "address#CODE".
func join_game(join_text: String, player_name: String) -> void:
	leave()
	var parts := Handshake.split_join_text(join_text)
	var address := parts[0]
	if parts[1].is_empty():
		_emit_ended(tr("ERROR_MISSING_CODE"))
		return
	DiagLog.begin_game()
	DiagLog.event("conn", "joining %s" % DiagLog.describe_join(address))
	var peer := _connector.join(address)
	if peer == null:
		_emit_ended(tr("ERROR_INVALID_ADDRESS"))
		return
	_auth.prepare_join(parts[1], player_name)
	_join_address = address
	multiplayer.multiplayer_peer = peer
	_set_phase(Phase.CONNECTING)
	get_tree().create_timer(CONNECT_TIMEOUT).timeout.connect(_on_connect_timeout.bind(peer))


func leave() -> void:
	_close("")


func _close(message: String) -> void:
	if phase == Phase.OFFLINE:
		return
	_set_phase(Phase.OFFLINE)
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_connector.close()
	room_code = ""
	team_count = Teams.FREE_FOR_ALL
	players.clear()
	match_slots.clear()
	_auth.reset()
	players_changed.emit()
	_emit_ended(message)


func _emit_ended(message: String) -> void:
	last_end_message = message
	ended.emit(message)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_changed.emit(phase)


# --- Connection events -----------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		var requested_name := _auth.take_requested_name(id)
		players[id] = {"name": LobbyValidator.clean_name(requested_name, players.size() + 1),
				"character": CharacterChoice.first_free(players, ""), "team": Teams.smaller_team(players, team_count), "ready": false}
		broadcast_players()
	elif id == 1:
		_set_phase(Phase.LOBBY)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.erase(id):
		broadcast_players()


## Client: the host did not finish the handshake (SessionAuth handles the host side).
func _on_peer_authentication_failed(id: int) -> void:
	if not multiplayer.is_server() and id == 1:
		_on_connection_lost()


func _on_connection_lost() -> void:
	if not _auth.rejection_message.is_empty():
		_close(_auth.rejection_message)
	elif phase == Phase.CONNECTING:
		_close(tr("ERROR_CONNECTION_FAILED").format({"address": _join_address}))
	else:
		_close(tr("ERROR_HOST_LEFT"))


func _on_connect_timeout(peer: MultiplayerPeer) -> void:
	if phase == Phase.CONNECTING and multiplayer.multiplayer_peer == peer:
		_on_connection_lost()


# --- Lobby state -----------------------------------------------------------

func broadcast_players() -> void:
	_receive_players.rpc(players)
	players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_players(new_players: Dictionary) -> void:
	var valid_players := LobbyValidator.players(new_players)
	if valid_players.is_empty():
		return
	players = valid_players
	players_changed.emit()
