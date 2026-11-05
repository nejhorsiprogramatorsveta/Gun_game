class_name EnetDirectConnector
extends Connector
## Direct UDP connection by IP address and port (ENet). Friends reach the host either on
## the same LAN or over the internet through Tailscale (a private virtual network).
## Security (PLAN.md section S): the game never opens router ports and never shows the
## host's real public IP; only LAN and Tailscale addresses are offered for sharing.

const DEFAULT_PORT := 24642
## 3 clients + 1 spare slot, so a client over the player limit still gets the
## "lobby full" message from Session instead of a silent connection timeout.
const MAX_CLIENTS := 4
## ENet drops a silent peer after timeout_min..timeout_max ms (RTT-dependent).
const TIMEOUT_LIMIT := 32
const TIMEOUT_MIN_MS := 5000
const TIMEOUT_MAX_MS := 8000
## Kinds offered for sharing, best first. Public IPv4/IPv6 are deliberately left out.
const SHAREABLE_KINDS: Array[StringName] = [&"tailscale", &"lan"]


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


func share_addresses(port: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for interface in IP.get_local_interfaces():
		# Windows reports a GUID as "name" and "Tailscale" as the friendly name.
		var interface_label := "%s %s" % [interface.get("name", ""), interface.get("friendly", "")]
		for ip: String in interface.addresses:
			var kind := address_kind(ip, interface_label)
			if kind in SHAREABLE_KINDS:
				result.append({"kind": kind, "address": "%s:%d" % [ip, port]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return SHAREABLE_KINDS.find(a.kind) < SHAREABLE_KINDS.find(b.kind))
	return result


## Diagnostics (NetLog): ENet's view of the link to one peer, or {} if unavailable.
## rtt / rtt_var in ms, loss in percent, throttle 1..32 (32 = ENet sends at full rate).
static func peer_stats(multiplayer_peer: MultiplayerPeer, peer_id: int) -> Dictionary:
	var enet := multiplayer_peer as ENetMultiplayerPeer
	if enet == null or enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return {}
	var packet_peer := enet.get_peer(peer_id)
	if packet_peer == null:
		return {}
	return {
		"rtt": int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)),
		"rtt_var": int(packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE)),
		"loss": packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) * 100.0 / ENetPacketPeer.PACKET_LOSS_SCALE,
		"throttle": int(packet_peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)),
	}


## Classifies a local interface address: &"tailscale", &"lan", &"public", &"ipv6",
## or empty when useless for friends (loopback, link-local...).
static func address_kind(ip: String, interface_label: String = "") -> StringName:
	if ip.contains(":"):
		var first := ip.get_slice(":", 0).to_lower()
		return &"ipv6" if first.length() == 4 and (first.begins_with("2") or first.begins_with("3")) else &""
	var parts := ip.split(".")
	if parts.size() != 4:
		return &""
	var a := parts[0].to_int()
	var b := parts[1].to_int()
	if a == 127 or (a == 169 and b == 254) or a == 0:
		return &""
	if a == 100 and b >= 64 and b <= 127:
		# 100.64.0.0/10 is used by Tailscale but also by some ISPs/public Wi-Fi as a LAN range,
		# so only the interface tells them apart (utunX on macOS, "Tailscale"/tailscale0 elsewhere).
		var label := interface_label.to_lower()
		return &"tailscale" if label.contains("tailscale") or label.begins_with("utun") else &"lan"
	if a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168):
		return &"lan"
	return &"public"


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
