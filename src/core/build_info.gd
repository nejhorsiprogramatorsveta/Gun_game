class_name BuildInfo
## Identity of this build. Shown in the main menu and (from M2) compared during the
## network handshake, so players on different builds get a clear error instead of desyncs.
## CI writes res://build_info.json before export; editor runs fall back to "dev".

## Bump whenever network messages change in an incompatible way.
const PROTOCOL_VERSION: int = 1
const FILE_PATH := "res://build_info.json"

static var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
static var commit: String = "dev"
static var channel: String = "dev"


static func _static_init() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE_PATH))
	if data is Dictionary:
		version = str(data.get("version", version))
		commit = str(data.get("commit", commit))
		channel = str(data.get("channel", channel))


## Exact build identity; peers must match it to play together.
static func build_id() -> String:
	return "%s+%s" % [version, commit]


static func display_string() -> String:
	return "v%s (%s)" % [build_id(), channel]
