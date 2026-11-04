extends SceneTree
## CI runs this after writing build_info.json, sharing the game's translated changelog.


func _initialize() -> void:
	TranslationServer.set_locale("cs")
	var output_path := "res://notes.md"
	var repository_url := Updater.REPO_URL
	var game_name: String = ProjectSettings.get_setting("application/config/name")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--repository-url="):
			repository_url = argument.trim_prefix("--repository-url=")
		elif argument.begins_with("--game-name="):
			game_name = argument.trim_prefix("--game-name=")
		else:
			printerr("Unknown release-notes argument: ", argument)
			quit(1)
			return
	if Changelog.release_changes().is_empty():
		printerr("No changelog entry for this build")
		quit(1)
		return
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write release notes: ", output_path)
		quit(1)
		return
	file.store_string(Changelog.release_notes(game_name, repository_url))
	file.close()
	quit()
