class_name ContentDB
## Read-only lookup of gameplay data (.tres files in res://data/) by id.
## Adding a character = dropping a new .tres into data/characters/, no code change.

const CHARACTERS_DIR := "res://data/characters/"
const WEAPONS_DIR := "res://data/weapons/"
const MATCH_RULES_PATH := "res://data/match_rules.tres"
const DEFAULT_CHARACTER_ID := &"jiskra"

static var _characters: Dictionary[StringName, CharacterData] = {}
static var _weapons: Dictionary[StringName, WeaponData] = {}
static var _match_rules: MatchRules


static func _static_init() -> void:
	for data in _load_all(WEAPONS_DIR):
		if data is WeaponData:
			_weapons[data.id] = data
	for data in _load_all(CHARACTERS_DIR):
		if data is CharacterData:
			_characters[data.id] = data
	_match_rules = load(MATCH_RULES_PATH) as MatchRules


static func _load_all(directory: String) -> Array[Resource]:
	var result: Array[Resource] = []
	# list_directory() also sees resources renamed/remapped by export, unlike DirAccess.
	for file_name in ResourceLoader.list_directory(directory):
		if not file_name.ends_with(".tres"):
			continue
		var data := load(directory + file_name)
		if data == null or str(data.get("id")).is_empty():
			push_error("Invalid data file: %s%s" % [directory, file_name])
			continue
		result.append(data)
	return result


static func get_character(id: StringName) -> CharacterData:
	return _characters.get(id)


static func character_ids() -> Array[StringName]:
	var ids: Array[StringName] = _characters.keys()
	ids.sort()
	return ids


static func get_weapon(id: StringName) -> WeaponData:
	return _weapons.get(id)


static func default_character() -> CharacterData:
	return _characters.get(DEFAULT_CHARACTER_ID)


static func match_rules() -> MatchRules:
	return _match_rules
