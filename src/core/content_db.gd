class_name ContentDB
## Read-only lookup of gameplay data (.tres files in res://data/) by id.
## Adding a character = dropping a new .tres into data/characters/, no code change.

const CHARACTERS_DIR := "res://data/characters/"
const WEAPONS_DIR := "res://data/weapons/"
const ABILITIES_DIR := "res://data/abilities/"
const MATCH_RULES_PATH := "res://data/match_rules.tres"
const DEFAULT_CHARACTER_ID := &"jiskra"

static var _characters: Dictionary[StringName, CharacterData] = {}
static var _weapons: Dictionary[StringName, WeaponData] = {}
static var _abilities: Dictionary[StringName, AbilityData] = {}
static var _match_rules: MatchRules


static func _static_init() -> void:
	for data in _load_all(WEAPONS_DIR):
		if data is WeaponData:
			_weapons[data.id] = data
	for data in _load_all(ABILITIES_DIR):
		if data is AbilityData:
			_abilities[data.id] = data
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
	# StringName.sort() orders by internal address, which differs between computers.
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


static func get_weapon(id: StringName) -> WeaponData:
	return _weapons.get(id)


static func get_ability(id: StringName) -> AbilityData:
	return _abilities.get(id)


## The chosen character (lobby or practice menu), or the default one for unknown ids.
static func practice_character(id: String) -> CharacterData:
	return _characters.get(StringName(id), default_character())


static func default_character() -> CharacterData:
	return _characters.get(DEFAULT_CHARACTER_ID)


static func match_rules() -> MatchRules:
	return _match_rules
