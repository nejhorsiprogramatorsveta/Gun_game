extends Node
## AUTOLOAD "Settings": user preferences saved in user://settings.cfg
## (a per-user folder that Godot resolves correctly on Windows, macOS and Linux).

const FILE_PATH := "user://settings.cfg"

var player_name := ""
## Character for practice (id from ContentDB); empty = default.
var practice_character := ""
## Arena for practice and the host's first lobby arena; empty = default.
var practice_arena := ""


func _ready() -> void:
	KeyBindings.capture_defaults()
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return
	player_name = str(config.get_value("player", "name", ""))
	practice_character = str(config.get_value("practice", "character", ""))
	practice_arena = str(config.get_value("practice", "arena", ""))
	# Rebound controls (settings screen); unknown or broken values keep the defaults.
	var controls := {}
	if config.has_section("controls"):
		for action in config.get_section_keys("controls"):
			controls[action] = config.get_value("controls", action, PackedStringArray())
	KeyBindings.apply(controls)


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("practice", "character", practice_character)
	config.set_value("practice", "arena", practice_arena)
	var controls := KeyBindings.serialize()
	for action: String in controls:
		config.set_value("controls", action, controls[action])
	config.save(FILE_PATH)
