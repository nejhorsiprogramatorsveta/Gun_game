class_name ArenaData
extends Resource
## One arena (map), PLAN.md T.2 / M6. To add an arena: build a scene from src/arenas/arena.gd
## (Platform / MovingPlatform nodes, SpawnPoints with 6+ Marker2D, Camera), copy a file in data/arenas/,
## change id + scene and add the name to localization/translations.csv.

@export var id: StringName
@export var name_key: String
@export var scene: PackedScene
## Player count the map suits (tooltip in the map pickers); max 0 = "and more".
@export var recommended_min_players := 2
@export var recommended_max_players := 3


## Tooltip: "Good for 2-3 players" / "Good for 4 and more players".
func players_hint() -> String:
	if recommended_max_players <= 0:
		return TranslationServer.translate("ARENA_PLAYERS_MANY").format({"min": recommended_min_players})
	return TranslationServer.translate("ARENA_PLAYERS_RANGE").format({"min": recommended_min_players, "max": recommended_max_players})
