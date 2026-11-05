class_name ArenaData
extends Resource
## One arena (map), PLAN.md T.2 / M6. To add an arena: build a scene from src/arenas/arena.gd
## (Platform nodes, SpawnPoints with 4 Marker2D, Camera), copy a file in data/arenas/,
## change id + scene and add the name to localization/translations.csv.

@export var id: StringName
@export var name_key: String
@export var scene: PackedScene
