extends Node
## AUTOLOAD "Settings": user preferences saved in user://settings.cfg
## (a per-user folder that Godot resolves correctly on Windows, macOS and Linux).

const FILE_PATH := "user://settings.cfg"

var player_name := ""
## Character for practice (id from ContentDB); empty = default.
var practice_character := ""
## Arena for practice and the host's first lobby arena; empty = default.
var practice_arena := ""
## Skins the player wants (CharacterData.SKIN_* bits), for any character.
var skins := 0
## Lifetime statistics of online matches (shown to everyone in the lobby, PlayerStats).
var total_kills := 0
var total_deaths := 0
var total_matches := 0


func _ready() -> void:
	KeyBindings.capture_defaults()
	var config := ConfigFile.new()
	if config.load(FILE_PATH) != OK:
		return
	player_name = str(config.get_value("player", "name", ""))
	practice_character = str(config.get_value("practice", "character", ""))
	practice_arena = str(config.get_value("practice", "arena", ""))
	skins = clampi(int(config.get_value("player", "skins", 0)), 0, CharacterData.SKIN_ALL)
	total_kills = maxi(int(config.get_value("stats", "kills", 0)), 0)
	total_deaths = maxi(int(config.get_value("stats", "deaths", 0)), 0)
	total_matches = maxi(int(config.get_value("stats", "matches", 0)), 0)
	# Rebound controls (settings screen); unknown or broken values keep the defaults.
	var controls := {}
	if config.has_section("controls"):
		for action in config.get_section_keys("controls"):
			controls[action] = config.get_value("controls", action, PackedStringArray())
	KeyBindings.apply(controls, int(config.get_value("meta", "controls_version", 1)))


## One finished online match of the local player (Session at the results).
func add_match(kills: int, deaths: int) -> void:
	total_kills += maxi(kills, 0)
	total_deaths += maxi(deaths, 0)
	total_matches += 1
	save()


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("player", "skins", skins)
	config.set_value("practice", "character", practice_character)
	config.set_value("practice", "arena", practice_arena)
	config.set_value("stats", "kills", total_kills)
	config.set_value("stats", "deaths", total_deaths)
	config.set_value("stats", "matches", total_matches)
	config.set_value("meta", "controls_version", KeyBindings.VERSION)
	var controls := KeyBindings.serialize()
	for action: String in controls:
		config.set_value("controls", action, controls[action])
	config.save(FILE_PATH)
