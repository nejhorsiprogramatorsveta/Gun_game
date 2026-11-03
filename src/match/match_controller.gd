extends Node2D
## Runs a match. In M1 this is local practice: one keyboard player who respawns after
## falling out. Host-side rules (multiple players, lives, network) are added in M2/M3.

const ARENA_SCENE := preload("res://src/arenas/arena_rooftops.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"

var _arena: Arena
var _players: Array[Player] = []
var _rules: MatchRules = ContentDB.match_rules()


func _ready() -> void:
	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup(ContentDB.default_character(), true)
	add_child(player)
	player.reset_to(_arena.spawn_points()[0])
	_players.append(player)


func _physics_process(_delta: float) -> void:
	for player in _players:
		if player.visible and _arena.is_out_of_bounds(player.position):
			_respawn_later(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _respawn_later(player: Player) -> void:
	player.set_active(false)
	await get_tree().create_timer(_rules.respawn_delay).timeout
	if not is_instance_valid(player):
		return
	player.reset_to(_arena.spawn_points().pick_random())
	player.set_active(true)
