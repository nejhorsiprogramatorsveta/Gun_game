class_name MatchHud
extends Control
## In-match overlay: player scores, the start countdown and kill announcements.

const SCORE_COLUMNS := 4
const KILL_NOTICE_SECONDS := 2.0

@onready var _scoreboard: GridContainer = %Scoreboard
@onready var _countdown_label: Label = %CountdownLabel
@onready var _kill_label: Label = %KillLabel

var _score_cells: Array[Label] = []
var _kill_seconds_left := 0.0


func _ready() -> void:
	for key: String in ["HUD_PLAYER", "HUD_LIVES_HEADER", "HUD_KILLS", "HUD_DEATHS"]:
		var heading := Label.new()
		heading.text = tr(key)
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if key == "HUD_PLAYER" else HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size", 18)
		heading.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
		_scoreboard.add_child(heading)
	for index in Session.MAX_PLAYERS * SCORE_COLUMNS:
		var cell := Label.new()
		cell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		cell.visible = false
		if index % SCORE_COLUMNS == 0:
			cell.custom_minimum_size.x = 220.0
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.clip_text = true
		else:
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_scoreboard.add_child(cell)
		_score_cells.append(cell)


func _process(delta: float) -> void:
	if _kill_seconds_left > 0.0:
		_kill_seconds_left = maxf(_kill_seconds_left - delta, 0.0)
		_kill_label.visible = _kill_seconds_left > 0.0


func show_state(players: Array, countdown: int, show_lives: bool) -> void:
	_countdown_label.visible = countdown > 0
	_countdown_label.text = str(countdown)
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: Player, b: Player) -> bool: return a.slot < b.slot)
	for row in Session.MAX_PLAYERS:
		for column in SCORE_COLUMNS:
			_score_cells[row * SCORE_COLUMNS + column].visible = row < sorted.size()
		if row >= sorted.size():
			continue
		var player: Player = sorted[row]
		var lives_text := tr("HUD_UNLIMITED")
		if show_lives:
			lives_text = str(player.lives) if player.lives > 0 else tr("HUD_ELIMINATED")
		var values: Array[String] = [player.display_name, lives_text, str(player.kills), str(player.deaths)]
		for column in SCORE_COLUMNS:
			_score_cells[row * SCORE_COLUMNS + column].text = values[column]
		_score_cells[row * SCORE_COLUMNS].modulate = Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]


func show_kill(player_name: String, streak: int) -> void:
	if streak <= 0:
		return
	var key := "HUD_KILL"
	if streak == 2:
		key = "HUD_DOUBLE_KILL"
	elif streak == 3:
		key = "HUD_TRIPLE_KILL"
	elif streak >= 4:
		key = "HUD_MULTI_KILL"
	_kill_label.text = tr(key).format({"name": player_name, "count": streak})
	_kill_seconds_left = KILL_NOTICE_SECONDS
	_kill_label.show()
