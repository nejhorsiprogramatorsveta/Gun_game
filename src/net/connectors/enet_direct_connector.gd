class_name EnetDirectConnector
extends Connector
## Direct UDP connection by IP address and port (ENet). Needs a reachable host:
## same LAN, port forwarding/UPnP, or a virtual network such as Tailscale.

const DEFAULT_PORT := 24642
## 3 clients + 1 spare slot, so a client over the player limit still gets the
## "lobby full" message from Session instead of a silent connection timeout.
const MAX_CLIENTS := 4
## ENet drops a silent peer after timeout_min..timeout_max ms (RTT-dependent).
const TIMEOUT_LIMIT := 32
const TIMEOUT_MIN_MS := 5000
const TIMEOUT_MAX_MS := 8000


func host(port: int) -> MultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_CLIENTS) != OK:
		return null
	peer.peer_connected.connect(func(id: int) -> void: _apply_timeout(peer, id))
	return peer


func join(join_info: String) -> MultiplayerPeer:
	var address := parse_address(join_info)
	if address.is_empty():
		return null
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address.host, address.port) != OK:
		return null
	_apply_timeout(peer, 1)
	return peer


## Accepts "1.2.3.4", "1.2.3.4:5000", "host.name:5000", "[::1]:5000" or a bare IPv6.
## Returns {host, port} or an empty dictionary when the text is not a valid address.
static func parse_address(text: String) -> Dictionary:
	var input := text.strip_edges()
	var host_part := input
	var port := DEFAULT_PORT
	if input.begins_with("["):
		var end := input.find("]")
		if end == -1:
			return {}
		host_part = input.substr(1, end - 1)
		var rest := input.substr(end + 1)
		if not rest.is_empty():
			if not rest.begins_with(":"):
				return {}
			port = _parse_port(rest.substr(1))
	elif input.count(":") == 1:
		host_part = input.get_slice(":", 0)
		port = _parse_port(input.get_slice(":", 1))
	if host_part.is_empty() or host_part.contains(" ") or port == -1:
		return {}
	return {"host": host_part, "port": port}


static func _parse_port(text: String) -> int:
	if not text.is_valid_int():
		return -1
	var port := text.to_int()
	return port if port >= 1 and port <= 65535 else -1


static func _apply_timeout(peer: ENetMultiplayerPeer, id: int) -> void:
	var packet_peer := peer.get_peer(id)
	if packet_peer:
		packet_peer.set_timeout(TIMEOUT_LIMIT, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)
