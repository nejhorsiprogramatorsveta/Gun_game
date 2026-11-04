extends SceneTree
## project.godot is the single source of the public version; Git supplies build identity.


func _initialize() -> void:
	var build := ""
	var commit := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--build="):
			build = argument.trim_prefix("--build=")
		elif argument.begins_with("--commit="):
			commit = argument.trim_prefix("--commit=")
		else:
			printerr("Unknown build-info argument: ", argument)
			quit(1)
			return
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var semver := RegEx.create_from_string(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")
	if semver.search(version) == null or not build.is_valid_int() or build.to_int() <= 0 or commit.length() < 7 or commit.length() > 40 or not commit.is_valid_hex_number():
		printerr("Expected project version X.Y.Z, positive --build and hexadecimal --commit (7–40 characters)")
		quit(1)
		return
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		printerr("Cannot read export presets")
		quit(1)
		return
	for section in presets.get_sections():
		if presets.get_value(section, "platform", "") == "macOS":
			presets.set_value(section + ".options", "application/short_version", version)
			presets.set_value(section + ".options", "application/version", version)
	if presets.save("res://export_presets.cfg") != OK:
		printerr("Cannot write export version")
		quit(1)
		return
	var file := FileAccess.open(BuildInfo.FILE_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write build info")
		quit(1)
		return
	file.store_string(JSON.stringify({"version": version, "build": build.to_int(), "commit": commit, "channel": "stable"}))
	file.close()
	quit()
