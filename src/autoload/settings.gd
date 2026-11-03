extends Node
## AUTOLOAD "Settings": user preferences saved in user://settings.cfg
## (a per-user folder that Godot resolves correctly on Windows, macOS and Linux).

const FILE_PATH := "user://settings.cfg"

var player_name := ""
var last_address := ""


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return
	player_name = str(config.get_value("player", "name", ""))
	last_address = str(config.get_value("network", "last_address", ""))


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("network", "last_address", last_address)
	config.save(FILE_PATH)
