extends Control
## Results after a network match. Everyone then returns to the SAME lobby (PLAN.md T.1):
## the host clicks the button or waits AUTO_RETURN_SECONDS; nobody has to host again.

const LOBBY_PATH := "res://src/ui/lobby.tscn"
const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"
const AUTO_RETURN_SECONDS := 8

@onready var _ranking: VBoxContainer = %Ranking
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _leave_button: Button = %LeaveButton

var _seconds_left := AUTO_RETURN_SECONDS


func _ready() -> void:
	Session.phase_changed.connect(_on_phase_changed)
	Session.ended.connect(func(_message: String) -> void: get_tree().change_scene_to_file.call_deferred(MAIN_MENU_PATH))
	_leave_button.pressed.connect(Session.leave)
	_back_button.visible = Session.is_host()
	_back_button.pressed.connect(Session.return_to_lobby)
	for entry: Dictionary in Session.match_results:
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var key := "RESULTS_WINNER" if entry.get("place", 0) == 1 else "RESULTS_PLACE"
		label.text = tr(key).format({"place": entry.get("place", 0), "name": str(entry.get("name", "?"))})
		label.add_theme_font_size_override("font_size", 34 if entry.get("place", 0) == 1 else 24)
		_ranking.add_child(label)
	_update_status()
	if Session.is_host():
		_count_down()


func _count_down() -> void:
	while _seconds_left > 0 and is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		_seconds_left -= 1
		_update_status()
	if is_inside_tree():
		Session.return_to_lobby()


func _update_status() -> void:
	if Session.is_host():
		_status_label.text = tr("RESULTS_AUTO_RETURN").format({"seconds": _seconds_left})
	else:
		_status_label.text = tr("RESULTS_WAITING")


func _on_phase_changed(phase: Session.Phase) -> void:
	if phase == Session.Phase.LOBBY:
		get_tree().change_scene_to_file.call_deferred(LOBBY_PATH)
