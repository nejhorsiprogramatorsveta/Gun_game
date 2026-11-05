class_name DiagLog
## Diagnostic lines in the game log (user://logs/godot.log) for analysing real play sessions
## (connection problems, lag). Every line starts with the wall-clock time, so the host's and
## the clients' logs can be put side by side. Developer text: not translated.
## Privacy (PLAN.md S): never log IP addresses or player names; mask() replaces addresses
## by their kind (lan / tailscale / public / ipv6).

static var _ipv4 := RegEx.create_from_string("\\b\\d{1,3}(\\.\\d{1,3}){3}\\b")
static var _ipv6 := RegEx.create_from_string("\\b[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{0,4}){2,7}\\b")


## "[12:34:56.789] [tag] text"
static func line(tag: String, text: String) -> String:
	var now := Time.get_datetime_dict_from_system()
	return "[%02d:%02d:%02d.%03d] [%s] %s" % [now.hour, now.minute, now.second, Time.get_ticks_msec() % 1000, tag, text]


static func event(tag: String, text: String) -> void:
	print(line(tag, mask(text)))


## Replaces every IP address in `text` by <kind>.
static func mask(text: String) -> String:
	var result := text
	for regex: RegEx in [_ipv4, _ipv6]:
		for found in regex.search_all(text):
			var ip := found.get_string()
			var kind := EnetDirectConnector.address_kind(ip)
			result = result.replace(ip, "<%s>" % (kind if not String(kind).is_empty() else "addr"))
	return result


## "lan port=24642", "tailscale port=...", "hostname port=..." or "invalid" - never the address.
static func describe_address(text: String) -> String:
	var parsed := EnetDirectConnector.parse_address(text)
	if parsed.is_empty():
		return "invalid address"
	var kind := String(EnetDirectConnector.address_kind(parsed.host))
	if kind.is_empty():
		kind = "hostname" if not parsed.host.is_valid_ip_address() else "local"
	return "%s port=%d" % [kind, parsed.port]


## One-time description of this computer and build (no personal data).
static func system_info() -> String:
	var screen := DisplayServer.window_get_current_screen()
	return "build=%s protocol=%d os=%s %s cpu_threads=%d gpu=%s driver=%s refresh=%.0fHz vsync=%d max_fps=%d physics=%dHz window=%s" % [
		BuildInfo.build_id(), BuildInfo.PROTOCOL_VERSION, OS.get_name(), OS.get_version(),
		OS.get_processor_count(), RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(),
		DisplayServer.screen_get_refresh_rate(screen), DisplayServer.window_get_vsync_mode(), Engine.max_fps,
		Engine.physics_ticks_per_second, DisplayServer.window_get_size()]
