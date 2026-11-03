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

var _upnp: UpnpHelper
var _internet_status := &""
## "ip:port" reachable from the internet (router answered via UPnP), else empty.
var _public_address := ""


func host(port: int) -> MultiplayerPeer:
	close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_CLIENTS) != OK:
		return null
	peer.peer_connected.connect(func(id: int) -> void: _apply_timeout(peer, id))
	_internet_status = &"checking"
	_upnp = UpnpHelper.new()
	_upnp.finished.connect(_on_upnp_finished.bind(_upnp, port))
	_upnp.open_port(port)
	return peer


func close() -> void:
	if _upnp:
		_upnp.close_port()
		_upnp = null
	_internet_status = &""
	_public_address = ""


func internet_status() -> StringName:
	return _internet_status


func _on_upnp_finished(result: Dictionary, helper: UpnpHelper, port: int) -> void:
	if helper != _upnp:
		return  # hosting already ended
	var external_ip: String = result.external_ip
	if not result.mapped:
		_internet_status = &"failed"
	elif address_kind(external_ip) != &"public":
		# The router itself sits behind the provider's NAT (CGNAT): forwarding is useless.
		_internet_status = &"cgnat"
		helper.close_port()
	else:
		_internet_status = &"open"
		_public_address = "%s:%d" % [external_ip, port]
	share_info_changed.emit()


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
	var has_ipv6 := false
	for interface in IP.get_local_interfaces():
		for ip: String in interface.addresses:
			var kind := address_kind(ip, interface.name)
			if kind.is_empty() or (kind == &"ipv6" and has_ipv6):
				continue
			has_ipv6 = has_ipv6 or kind == &"ipv6"
			var host_text := "[%s]" % ip if ip.contains(":") else ip
			result.append({"kind": kind, "address": "%s:%d" % [host_text, port]})
	if not _public_address.is_empty():
		result.append({"kind": &"public", "address": _public_address})
	var order: Array[StringName] = [&"public", &"tailscale", &"lan", &"ipv6"]
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return order.find(a.kind) < order.find(b.kind))
	return result


## Classifies a local interface address; empty = useless for friends (loopback, link-local...).
static func address_kind(ip: String, interface_name: String = "") -> StringName:
	if ip.contains(":"):
		var first := ip.get_slice(":", 0).to_lower()
		# Global unicast IPv6 (2000::/3) is often reachable from the internet without NAT.
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
		# so only the interface name tells them apart (utunX on macOS, "Tailscale"/tailscale0 elsewhere).
		var iface := interface_name.to_lower()
		return &"tailscale" if iface.contains("tailscale") or iface.begins_with("utun") else &"lan"
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
