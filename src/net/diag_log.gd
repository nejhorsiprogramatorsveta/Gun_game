class_name DiagLog
## Diagnostic lines in the game's single log file (DiagFileLogger: user://logs/last_game.log,
## only the last online game) for analysing real play sessions (connection, Tailscale, lag).
## Every line starts with the wall-clock time, so the host's and the clients' logs can be
## put side by side. Developer text: not translated.
## Privacy (PLAN.md S): never log IP addresses or player names; mask() replaces addresses
## by their kind (lan / tailscale / public / ipv6).

const LOG_DIR := "user://logs"

static var _logger: DiagFileLogger


## Once at start-up: route all output into DiagFileLogger and delete old godot*.log files
## of earlier versions (Godot's own file logging is off in project.godot).
static func install() -> void:
	if _logger:
		return
	_logger = DiagFileLogger.new()
	OS.add_logger(_logger)
	if DirAccess.dir_exists_absolute(LOG_DIR):
		for file_name in DirAccess.get_files_at(LOG_DIR):
			if file_name.begins_with("godot") and file_name.ends_with(".log"):
				DirAccess.remove_absolute(LOG_DIR.path_join(file_name))


## A new online game (host or join): the previous game's log is replaced.
static func begin_game() -> void:
	if _logger == null:
		return
	var utc := Time.get_datetime_string_from_system(true)
	var local := Time.get_datetime_string_from_system(false)
	_logger.begin_game("=== Dojo Knockout diagnostic log | local %s | UTC %s ===" % [local, utc])
	event("sys", system_info())
	event("sys", network_summary())


static func flush() -> void:
	if _logger:
		_logger.flush()


static func close() -> void:
	if _logger:
		_logger.close()


## Settings button: opens the folder with last_game.log in Explorer / Finder.
static func open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	OS.shell_open(ProjectSettings.globalize_path(LOG_DIR))

static var _ipv4 := RegEx.create_from_string("\\b\\d{1,3}(\\.\\d{1,3}){3}\\b")
static var _ipv6 := RegEx.create_from_string("\\b[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{0,4}){2,7}\\b")


## "[12:34:56.789] [tag] text"
static func line(tag: String, text: String) -> String:
	return DiagFileLogger.stamp("[%s] %s" % [tag, text])


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
	return "%s port=%d" % [_target_kind(parsed.host), parsed.port]


## Kind of a join target. A typed 100.64/10 address (no interface to look at) is almost
## always a friend's Tailscale address.
static func _target_kind(host: String) -> String:
	var kind := String(EnetDirectConnector.address_kind(host))
	if kind.is_empty():
		return "hostname" if not host.is_valid_ip_address() else "local"
	var parts := host.split(".")
	if kind == "lan" and parts.size() == 4 and parts[0] == "100" and parts[1].to_int() >= 64 and parts[1].to_int() <= 127:
		return "tailscale"
	return kind


## Local network as seen by the game, without addresses: Tailscale up/off and the kinds of
## addresses per interface, e.g. "tailscale=up interfaces: en0[lan,ipv6] utun4[tailscale]".
static func network_summary() -> String:
	var tailscale := false
	var parts: PackedStringArray = []
	for interface: Dictionary in IP.get_local_interfaces():
		var label := "%s %s" % [interface.get("name", ""), interface.get("friendly", "")]
		var kinds: PackedStringArray = []
		for ip: String in interface.get("addresses", []):
			var kind := String(EnetDirectConnector.address_kind(ip, label))
			if not kind.is_empty() and not kinds.has(kind):
				kinds.append(kind)
			tailscale = tailscale or kind == "tailscale"
		if not kinds.is_empty():
			var shown_name := str(interface.get("friendly", "")) if not str(interface.get("friendly", "")).is_empty() else str(interface.get("name", ""))
			parts.append("%s[%s]" % [shown_name.left(24).replace(" ", "_"), ",".join(kinds)])
	return "network: tailscale=%s interfaces: %s" % ["up" if tailscale else "off", " ".join(parts) if not parts.is_empty() else "none"]


## Join target for the log: its kind and port, whether a LAN target is in one of our own
## subnets (/24), and a hint when the target needs Tailscale but this computer has none.
static func describe_join(text: String) -> String:
	var result := describe_address(text)
	var parsed := EnetDirectConnector.parse_address(text)
	if parsed.is_empty():
		return result
	var kind := _target_kind(parsed.host)
	var local_kinds := {}
	var same_subnet := false
	for interface: Dictionary in IP.get_local_interfaces():
		var label := "%s %s" % [interface.get("name", ""), interface.get("friendly", "")]
		for ip: String in interface.get("addresses", []):
			local_kinds[String(EnetDirectConnector.address_kind(ip, label))] = true
			if ip.count(".") == 3 and parsed.host.count(".") == 3 and ip.substr(0, ip.rfind(".")) == parsed.host.substr(0, parsed.host.rfind(".")):
				same_subnet = true
	if kind == "lan":
		result += " same_subnet=%s" % ("yes" if same_subnet else "no")
	if kind == "tailscale" and not local_kinds.has("tailscale"):
		result += " HINT: Tailscale address, but this computer has no Tailscale address (Tailscale off or logged out?)"
	return result


## One-time description of this computer and build (no personal data).
static func system_info() -> String:
	var screen := DisplayServer.window_get_current_screen()
	return "build=%s protocol=%d os=%s %s cpu_threads=%d gpu=%s driver=%s refresh=%.0fHz vsync=%d max_fps=%d physics=%dHz window=%s" % [
		BuildInfo.build_id(), BuildInfo.PROTOCOL_VERSION, OS.get_name(), OS.get_version(),
		OS.get_processor_count(), RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(),
		DisplayServer.screen_get_refresh_rate(screen), DisplayServer.window_get_vsync_mode(), Engine.max_fps,
		Engine.physics_ticks_per_second, DisplayServer.window_get_size()]
