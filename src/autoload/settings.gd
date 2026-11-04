extends Node
## AUTOLOAD "Settings": user preferences saved in user://settings.cfg
## (a per-user folder that Godot resolves correctly on Windows, macOS and Linux).

const FILE_PATH := "user://settings.cfg"

var player_name := ""


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return
	player_name = str(config.get_value("player", "name", ""))


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.save(FILE_PATH)
