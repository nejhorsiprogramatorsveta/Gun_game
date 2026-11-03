class_name ContentDB
## Read-only lookup of gameplay data (.tres files in res://data/) by id.
## Adding a character = dropping a new .tres into data/characters/, no code change.

const CHARACTERS_DIR := "res://data/characters/"
const MATCH_RULES_PATH := "res://data/match_rules.tres"
const DEFAULT_CHARACTER_ID := &"jiskra"

static var _characters: Dictionary[StringName, CharacterData] = {}
static var _match_rules: MatchRules


static func _static_init() -> void:
	# list_directory() also sees resources renamed/remapped by export, unlike DirAccess.
	for file_name in ResourceLoader.list_directory(CHARACTERS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var data := load(CHARACTERS_DIR + file_name) as CharacterData
		if data == null or data.id.is_empty():
			push_error("Invalid character data: %s" % file_name)
			continue
		_characters[data.id] = data
	_match_rules = load(MATCH_RULES_PATH) as MatchRules


static func get_character(id: StringName) -> CharacterData:
	return _characters.get(id)


static func character_ids() -> Array[StringName]:
	var ids: Array[StringName] = _characters.keys()
	ids.sort()
	return ids


static func default_character() -> CharacterData:
	return _characters.get(DEFAULT_CHARACTER_ID)


static func match_rules() -> MatchRules:
	return _match_rules
