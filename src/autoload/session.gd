extends Node
## AUTOLOAD "Session": the network session, alive across scene changes.
## Owns hosting/joining, the version handshake and the lobby player list.
## Host-authoritative: only the host (peer 1) changes `players` and broadcasts them.
##
## The handshake uses SceneMultiplayer authentication (raw bytes), not RPCs: RPC methods
## are matched by index, so a peer on a different build might not even decode an RPC
## hello. Until authentication completes, a peer cannot send or receive any RPC.

signal phase_changed(phase: Phase)
signal players_changed
## The session is over: failed to start, rejected, connection lost or left on purpose
## (message is then empty). The message is already translated for the UI.
signal ended(message: String)

enum Phase { OFFLINE, CONNECTING, LOBBY }

const MAX_PLAYERS := 4
const MAX_NAME_LENGTH := 16
const CONNECT_TIMEOUT := 10.0
## Host drops peers that do not finish the handshake in time.
const AUTH_TIMEOUT := 5.0
## Gives a rejection message time to arrive before the host drops the peer.
const REJECT_DISCONNECT_DELAY := 0.5
const REJECT_REASONS: PackedStringArray = ["ERROR_VERSION_MISMATCH", "ERROR_LOBBY_FULL", "ERROR_MATCH_IN_PROGRESS"]

var phase := Phase.OFFLINE
## peer_id -> {"name": String}. Identical on all peers (host broadcasts it).
var players: Dictionary[int, Dictionary] = {}

var _connector: Connector = EnetDirectConnector.new()
var _local_name := ""
var _join_address := ""
## Host: names of peers that passed the handshake but are not connected yet.
var _pending_names: Dictionary[int, String] = {}
## Host: rejected peers waiting to be dropped (they may also leave on their own).
var _rejected_peers: Dictionary[int, bool] = {}
## Client: why the host refused us (shown when the connection closes).
var _rejection_message := ""


func _ready() -> void:
	var api := multiplayer as SceneMultiplayer
	api.auth_callback = _on_auth_message
	api.auth_timeout = AUTH_TIMEOUT
	api.peer_authenticating.connect(_on_peer_authenticating)
	api.peer_authentication_failed.connect(_on_peer_authentication_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_lost)
	multiplayer.server_disconnected.connect(_on_connection_lost)


func is_host() -> bool:
	return phase != Phase.OFFLINE and multiplayer.is_server()


func host_game(player_name: String, port: int = EnetDirectConnector.DEFAULT_PORT) -> void:
	leave()
	var peer := _connector.host(port)
	if peer == null:
		ended.emit(tr("ERROR_HOST_FAILED").format({"port": port}))
		return
	multiplayer.multiplayer_peer = peer
	players = {1: {"name": _clean_name(player_name)}}
	_set_phase(Phase.LOBBY)
	players_changed.emit()


func join_game(address: String, player_name: String) -> void:
	leave()
	var peer := _connector.join(address)
	if peer == null:
		ended.emit(tr("ERROR_INVALID_ADDRESS"))
		return
	_local_name = player_name
	_join_address = address.strip_edges()
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
	players.clear()
	_pending_names.clear()
	_rejected_peers.clear()
	players_changed.emit()
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
		var hello := {"protocol": BuildInfo.PROTOCOL_VERSION, "build": BuildInfo.build_id(), "name": _local_name}
		(multiplayer as SceneMultiplayer).send_auth(id, var_to_bytes(hello))


func _on_auth_message(id: int, data: PackedByteArray) -> void:
	# bytes_to_var() never decodes objects, so untrusted data cannot create code.
	var message: Variant = bytes_to_var(data)
	if not message is Dictionary:
		return
	if multiplayer.is_server():
		_handle_hello(id, message)
	else:
		_handle_auth_reply(message)


func _handle_hello(id: int, hello: Dictionary) -> void:
	var api := multiplayer as SceneMultiplayer
	var reason := ""
	if not (_value_is(hello, "protocol", BuildInfo.PROTOCOL_VERSION) and _value_is(hello, "build", BuildInfo.build_id())):
		reason = "ERROR_VERSION_MISMATCH"
	elif phase != Phase.LOBBY:
		reason = "ERROR_MATCH_IN_PROGRESS"
	elif players.size() + _pending_names.size() >= MAX_PLAYERS:
		reason = "ERROR_LOBBY_FULL"
	if not reason.is_empty():
		api.send_auth(id, var_to_bytes({"ok": false, "reason": reason, "build": BuildInfo.build_id()}))
		_rejected_peers[id] = true
		get_tree().create_timer(REJECT_DISCONNECT_DELAY).timeout.connect(_drop_peer.bind(id))
		return
	_pending_names[id] = str(hello.get("name", ""))
	api.send_auth(id, var_to_bytes({"ok": true}))
	api.complete_auth(id)


func _handle_auth_reply(reply: Dictionary) -> void:
	if _value_is(reply, "ok", true):
		(multiplayer as SceneMultiplayer).complete_auth(1)
		return
	var reason := str(reply.get("reason", ""))
	if reason not in REJECT_REASONS:
		reason = "ERROR_VERSION_MISMATCH"
	_rejection_message = tr(reason).format({"mine": BuildInfo.build_id(), "host": str(reply.get("build", "?"))})


## Type-safe equality for values received from the network.
static func _value_is(data: Dictionary, key: String, expected: Variant) -> bool:
	var value: Variant = data.get(key)
	return typeof(value) == typeof(expected) and value == expected


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
