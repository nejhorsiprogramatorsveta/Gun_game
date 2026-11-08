class_name SessionAuth
extends Node
## Join handshake of the Session autoload ("/root/Session/SessionAuth" on every peer):
## version and room code via SceneMultiplayer authentication, messages built and checked in
## Handshake. Until it completes, a peer cannot send or receive any RPC (PLAN.md section S).
##   Host: checks ONE hello per connection (code, version, lobby open, free place), then
##         accepts it or sends the reason and drops the peer shortly after.
##   Client: sends the hello and remembers why the host refused it.

## Host drops peers that do not finish the handshake in time.
const AUTH_TIMEOUT := 5.0
## Gives a rejection message time to arrive before the host drops the peer.
const REJECT_DISCONNECT_DELAY := 0.5

## Client: why the host refused us (translated; shown when the connection closes).
var rejection_message := ""

var _join_code := ""
var _local_name := ""
## Host: names of peers that passed the handshake but are not connected yet.
var _pending_names: Dictionary[int, String] = {}
## Host: rejected peers waiting to be dropped (they may also leave on their own).
var _rejected_peers: Dictionary[int, bool] = {}


func _init() -> void:
	name = "SessionAuth"


func _ready() -> void:
	var api := multiplayer as SceneMultiplayer
	api.auth_callback = _on_auth_message
	api.auth_timeout = AUTH_TIMEOUT
	api.peer_authenticating.connect(_on_peer_authenticating)
	api.peer_authentication_failed.connect(_forget_peer)
	multiplayer.peer_disconnected.connect(_forget_pending)


## Client, before connecting: what the hello will carry.
func prepare_join(code: String, player_name: String) -> void:
	_join_code = code
	_local_name = player_name
	rejection_message = ""


## Host: the name a newly connected peer asked for in its hello ("" if unknown).
func take_requested_name(id: int) -> String:
	var requested_name: String = _pending_names.get(id, "")
	_pending_names.erase(id)
	return requested_name


## The session closed: forget every waiting peer.
func reset() -> void:
	_pending_names.clear()
	_rejected_peers.clear()


func _on_peer_authenticating(id: int) -> void:
	if not multiplayer.is_server():
		(multiplayer as SceneMultiplayer).send_auth(id, Handshake.make_hello(_join_code, _local_name))


func _on_auth_message(id: int, data: PackedByteArray) -> void:
	if multiplayer.is_server() and (_rejected_peers.has(id) or _pending_names.has(id)):
		return  # one hello per connection: no guessing room codes while waiting to be dropped
	var message := Handshake.decode(data)
	if message.is_empty():
		return
	if multiplayer.is_server():
		_handle_hello(id, message)
	else:
		_handle_auth_reply(message)


func _handle_hello(id: int, hello: Dictionary) -> void:
	var api := multiplayer as SceneMultiplayer
	var reason := Handshake.check_hello(hello, Session.room_code)
	if reason.is_empty() and Session.phase != Session.Phase.LOBBY:
		reason = "ERROR_MATCH_IN_PROGRESS"
	elif reason.is_empty() and Session.players.size() + _pending_names.size() >= Session.MAX_PLAYERS:
		reason = "ERROR_LOBBY_FULL"
	if not reason.is_empty():
		DiagLog.event("conn", "peer %d rejected: %s" % [id, reason])
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
		rejection_message = Handshake.rejection_text(reply)


func _drop_peer(id: int) -> void:
	if Session.is_host() and _rejected_peers.has(id):
		_rejected_peers.erase(id)
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _forget_pending(id: int) -> void:
	if multiplayer.is_server():
		_pending_names.erase(id)


func _forget_peer(id: int) -> void:
	if multiplayer.is_server():
		_rejected_peers.erase(id)
		_pending_names.erase(id)
