extends Node
## AUTOLOAD "Session": the network session, alive across scene changes.
## Owns hosting/joining, the version handshake and the lobby player list.
## Host-authoritative: only the host (peer 1) changes `players` and broadcasts them.
##
## The join handshake (version + room code) uses SceneMultiplayer authentication; messages
## are built/checked in Handshake. Until it completes, a peer cannot send or receive any RPC.

signal phase_changed(phase: Phase)
signal players_changed
## The session is over: failed to start, rejected, connection lost or left on purpose
## (message is then empty). The message is already translated for the UI.
signal ended(message: String)

enum Phase { OFFLINE, CONNECTING, LOBBY, IN_MATCH, RESULTS }

const MAX_PLAYERS := 4
const MIN_PLAYERS_TO_START := 2
const MAX_NAME_LENGTH := 16
const CONNECT_TIMEOUT := 10.0
## Host drops peers that do not finish the handshake in time.
const AUTH_TIMEOUT := 5.0
## Gives a rejection message time to arrive before the host drops the peer.
const REJECT_DISCONNECT_DELAY := 0.5

var phase := Phase.OFFLINE
## peer_id -> {"name": String}. Identical on all peers (host broadcasts it).
var players: Dictionary[int, Dictionary] = {}
## Why the last session ended (translated), so the main menu can show it after a
## scene change. The menu clears it once shown.
var last_end_message := ""
var host_port := EnetDirectConnector.DEFAULT_PORT
## peer_id -> slot (0..3) of the running match; identical on all peers.
var match_slots: Dictionary[int, int] = {}
## Ranking of the last match: [{"name": String, "place": int, "lives": int}], best first.
var match_results: Array = []
## Host: secret that friends need to join (sent along with the address as "ip:port#CODE").
var room_code := ""

var _connector: Connector = EnetDirectConnector.new()
var _local_name := ""
var _join_address := ""
var _join_code := ""
## Host: names of peers that passed the handshake but are not connected yet.
var _pending_names: Dictionary[int, String] = {}
## Host: rejected peers waiting to be dropped (they may also leave on their own).
var _rejected_peers: Dictionary[int, bool] = {}
## Client: why the host refused us (shown when the connection closes).
var _rejection_message := ""


func _ready() -> void:
	var api := multiplayer as SceneMultiplayer
	# Clients may only talk to the host, never relay RPCs to each other (PLAN.md S).
	api.server_relay = false
	api.auth_callback = _on_auth_message
	api.auth_timeout = AUTH_TIMEOUT
	api.peer_authenticating.connect(_on_peer_authenticating)
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
	return is_host() and phase == Phase.LOBBY and players.size() >= MIN_PLAYERS_TO_START


## Host: starts the match for everyone in the lobby (slots by peer id, host = slot 0).
func start_match() -> void:
	if not can_start_match():
		return
	var ids := players.keys()
	ids.sort()
	var slots := {}
	for i in ids.size():
		slots[ids[i]] = i
	_begin_match.rpc(slots)


@rpc("authority", "call_local", "reliable")
func _begin_match(slots: Dictionary) -> void:
	match_slots.assign(slots)
	_set_phase(Phase.IN_MATCH)


## Host: the match is decided; everyone sees the results (PLAN.md T.1).
func end_match(results: Array) -> void:
	if is_host() and phase == Phase.IN_MATCH:
		_end_match.rpc(results)


@rpc("authority", "call_local", "reliable")
func _end_match(results: Array) -> void:
	match_results = results
	_set_phase(Phase.RESULTS)


## Host: everyone goes back to the same lobby; the session (and room code) stays open.
func return_to_lobby() -> void:
	if is_host() and phase in [Phase.IN_MATCH, Phase.RESULTS]:
		_return_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _return_to_lobby() -> void:
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
	var peer := _connector.host(port)
	if peer == null:
		_emit_ended(tr("ERROR_HOST_FAILED").format({"port": port}))
		return
	multiplayer.multiplayer_peer = peer
	host_port = port
	room_code = Handshake.generate_room_code()
	players = {1: {"name": _clean_name(player_name)}}
	_set_phase(Phase.LOBBY)
	players_changed.emit()


## join_text is what the host shared: "address#CODE".
func join_game(join_text: String, player_name: String) -> void:
	leave()
	var parts := Handshake.split_join_text(join_text)
	var address := parts[0]
	_join_code = parts[1]
	if _join_code.is_empty():
		_emit_ended(tr("ERROR_MISSING_CODE"))
		return
	var peer := _connector.join(address)
	if peer == null:
		_emit_ended(tr("ERROR_INVALID_ADDRESS"))
		return
	_local_name = player_name
	_join_address = address
	_rejection_message = ""
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
	players.clear()
	match_slots.clear()
	_pending_names.clear()
	_rejected_peers.clear()
	players_changed.emit()
	_emit_ended(message)


func _emit_ended(message: String) -> void:
	last_end_message = message
	ended.emit(message)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_changed.emit(phase)


func _clean_name(raw_name: String) -> String:
	var cleaned := raw_name.strip_edges().left(MAX_NAME_LENGTH)
	if cleaned.is_empty():
		cleaned = tr("LOBBY_DEFAULT_NAME").format({"number": players.size() + 1})
	return cleaned


# --- Handshake -------------------------------------------------------------

func _on_peer_authenticating(id: int) -> void:
	if not multiplayer.is_server():
		(multiplayer as SceneMultiplayer).send_auth(id, Handshake.make_hello(_join_code, _local_name))


func _on_auth_message(id: int, data: PackedByteArray) -> void:
	var message := Handshake.decode(data)
	if message.is_empty():
		return
	if multiplayer.is_server():
		_handle_hello(id, message)
	else:
		_handle_auth_reply(message)


func _handle_hello(id: int, hello: Dictionary) -> void:
	var api := multiplayer as SceneMultiplayer
	var reason := Handshake.check_hello(hello, room_code)
	if reason.is_empty() and phase != Phase.LOBBY:
		reason = "ERROR_MATCH_IN_PROGRESS"
	elif reason.is_empty() and players.size() + _pending_names.size() >= MAX_PLAYERS:
		reason = "ERROR_LOBBY_FULL"
	if not reason.is_empty():
		api.send_auth(id, Handshake.make_reject(reason))
		_rejected_peers[id] = true
		get_tree().create_timer(REJECT_DISCONNECT_DELAY).timeout.connect(_drop_peer.bind(id))
		return
	_pending_names[id] = Handshake.requested_name(hello)
	api.send_auth(id, Handshake.make_accept())
	api.complete_auth(id)


func _handle_auth_reply(reply: Dictionary) -> void:
	if Handshake.is_accept(reply):
		(multiplayer as SceneMultiplayer).complete_auth(1)
	else:
		_rejection_message = Handshake.rejection_text(reply)


func _drop_peer(id: int) -> void:
	if is_host() and _rejected_peers.has(id):
		_rejected_peers.erase(id)
		multiplayer.multiplayer_peer.disconnect_peer(id)


# --- Connection events -----------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		var requested_name: String = _pending_names.get(id, "")
		_pending_names.erase(id)
		players[id] = {"name": _clean_name(requested_name)}
		_broadcast_players()
	elif id == 1:
		_set_phase(Phase.LOBBY)


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	_pending_names.erase(id)
	if players.erase(id):
		_broadcast_players()


func _on_peer_authentication_failed(id: int) -> void:
	if multiplayer.is_server():
		_rejected_peers.erase(id)
		_pending_names.erase(id)
	elif id == 1:
		_on_connection_lost()


func _on_connection_lost() -> void:
	if not _rejection_message.is_empty():
		_close(_rejection_message)
	elif phase == Phase.CONNECTING:
		_close(tr("ERROR_CONNECTION_FAILED").format({"address": _join_address}))
	else:
		_close(tr("ERROR_HOST_LEFT"))


func _on_connect_timeout(peer: MultiplayerPeer) -> void:
	if phase == Phase.CONNECTING and multiplayer.multiplayer_peer == peer:
		_on_connection_lost()


# --- Lobby state -----------------------------------------------------------

func _broadcast_players() -> void:
	_receive_players.rpc(players)
	players_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_players(new_players: Dictionary) -> void:
	players.assign(new_players)
	players_changed.emit()
