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
	_add_winner()
	var table := ResultsTable.new()
	_ranking.add_child(table)
	table.show_rows(Session.match_results, Session.match_slots.get(multiplayer.get_unique_id(), -1))
	_update_status()
	if Session.phase == Session.Phase.LOBBY:  # the host ended the results while we were loading
		get_tree().change_scene_to_file.call_deferred(LOBBY_PATH)
	elif Session.is_host():
		_count_down()


## "Red team wins!" (team modes) or "Bob wins!" above the table (the winners have place 1).
func _add_winner() -> void:
	var results := Session.match_results
	if results.is_empty() or results[0].get("place", 0) != 1:
		return
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	var team: int = results[0].get("team", Teams.NONE)
	if Teams.is_valid(team):
		label.text = tr("RESULTS_TEAM_WINNER").format({"team": tr(Teams.NAME_KEYS[team])})
		label.add_theme_color_override("font_color", Teams.color(team))
	else:
		label.text = tr("RESULTS_PLAYER_WINNER").format({"name": str(results[0].get("name", "?"))})
		label.add_theme_color_override("font_color", ResultsTable.PLACE_COLORS[0])
	_ranking.add_child(label)


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
