extends Control
## Main menu: practice, host or join. Network errors from the last session
## (Session.last_end_message) are shown here after returning from the lobby.

const PRACTICE_SCENE_PATH := "res://src/match/match.tscn"
const LOBBY_SCENE_PATH := "res://src/ui/lobby.tscn"
const ERROR_COLOR := Color(1.0, 0.45, 0.4)
const INFO_COLOR := Color(0.75, 0.78, 0.85)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _practice_button: Button = %PracticeButton
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	_version_label.text = tr("MENU_VERSION").format({"version": BuildInfo.display_string()})
	_name_edit.max_length = Session.MAX_NAME_LENGTH
	_name_edit.text = Settings.player_name
	_address_edit.text = Settings.last_address
	_practice_button.pressed.connect(get_tree().change_scene_to_file.bind(PRACTICE_SCENE_PATH))
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_address_edit.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	_quit_button.pressed.connect(get_tree().quit)
	Session.phase_changed.connect(_on_session_phase_changed)
	Session.ended.connect(_show_status.bind(ERROR_COLOR))
	_show_status(Session.last_end_message, ERROR_COLOR)
	Session.last_end_message = ""
	_practice_button.grab_focus()


func _on_host_pressed() -> void:
	_remember_inputs()
	Session.host_game(_name_edit.text)


func _on_join_pressed() -> void:
	_remember_inputs()
	Session.join_game(_address_edit.text, _name_edit.text)


func _remember_inputs() -> void:
	Settings.player_name = _name_edit.text.strip_edges()
	Settings.last_address = _address_edit.text.strip_edges()
	Settings.save()


func _on_session_phase_changed(phase: Session.Phase) -> void:
	var connecting := phase == Session.Phase.CONNECTING
	for button: Button in [_practice_button, _host_button, _join_button]:
		button.disabled = connecting
	if connecting:
		_show_status(tr("MENU_CONNECTING"), INFO_COLOR)
	elif phase == Session.Phase.LOBBY:
		get_tree().change_scene_to_file.call_deferred(LOBBY_SCENE_PATH)


func _show_status(message: String, color: Color) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)
