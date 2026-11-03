extends Control
## Main menu. Host/Join are placeholders until the network milestone (M2).

const PRACTICE_SCENE_PATH := "res://src/match/match.tscn"

@onready var _practice_button: Button = %PracticeButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_version_label.text = tr("MENU_VERSION").format({"version": BuildInfo.display_string()})
	_practice_button.pressed.connect(get_tree().change_scene_to_file.bind(PRACTICE_SCENE_PATH))
	_quit_button.pressed.connect(get_tree().quit)
	_practice_button.grab_focus()
