class_name BuildInfo
## Identity of this build. Shown in the main menu and (from M2) compared during the
## network handshake, so players on different builds get a clear error instead of desyncs.
## CI writes res://build_info.json before export; editor runs fall back to "dev".

## Bump whenever network messages change in an incompatible way.
const PROTOCOL_VERSION: int = 3
const FILE_PATH := "res://build_info.json"

static var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
## CI build number (number of commits on main, only ever grows); 0 = local editor run.
static var build: int = 0
static var commit: String = "dev"
static var channel: String = "dev"


static func _static_init() -> void:
	if FileAccess.file_exists(FILE_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE_PATH))
		if data is Dictionary:
			version = str(data.get("version", version))
			build = int(data.get("build", 0))
			commit = str(data.get("commit", commit))
			channel = str(data.get("channel", channel))
	# Debug/editor runs only: `-- --fake-commit=abc` simulates another build to test
	# the version-mismatch handshake with two local instances.
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--fake-commit="):
				commit = arg.get_slice("=", 1)


## Exact build identity; peers must match it to play together.
static func build_id() -> String:
	return "%s+%s" % [version, str(build) if build > 0 else commit]


## Human-friendly version for the menu and messages, e.g. "0.0.0 (sestavení 24)".
static func display_string() -> String:
	if build > 0:
		return TranslationServer.translate("BUILD_DISPLAY").format({"version": version, "build": build})
	return TranslationServer.translate("BUILD_DISPLAY_DEV").format({"version": version, "commit": commit})
