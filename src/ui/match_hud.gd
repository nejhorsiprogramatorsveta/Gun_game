class_name MatchHud
extends Control
## In-match overlay: scoreboard panel (character icon, lives, kills, deaths) and the start
## countdown. Kill announcements float above the killer (KillPopup).
## Bottom left: FPS and (on clients) ping; F3 hides/shows it.

const SCORE_COLUMNS := 4  # name, lives, kills, deaths (plus the character icon column)
## Head of the character in its sprite sheet (first idle frame), shown in the scoreboard.
const HEAD_REGION := Rect2(8, 4, 16, 16)

@onready var _scoreboard: GridContainer = %Scoreboard
@onready var _countdown_label: Label = %CountdownLabel

var _score_cells: Array[Label] = []
var _score_icons: Array[TextureRect] = []
var _net_label := Label.new()
var _weapon_label := Label.new()


func _ready() -> void:
	_scoreboard.add_child(Control.new())  # no heading above the icons
	for key: String in ["HUD_PLAYER", "HUD_LIVES_HEADER", "HUD_KILLS", "HUD_DEATHS"]:
		var heading := Label.new()
		heading.text = tr(key)
		heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if key == "HUD_PLAYER" else HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size", 16)
		heading.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
		_scoreboard.add_child(heading)
	for row in Session.MAX_PLAYERS:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.visible = false
		_scoreboard.add_child(icon)
		_score_icons.append(icon)
		for column in SCORE_COLUMNS:
			var cell := Label.new()
			cell.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			cell.visible = false
			if column == 0:
				cell.custom_minimum_size.x = 200.0
				cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				cell.clip_text = true
			else:
				cell.custom_minimum_size.x = 64.0
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_scoreboard.add_child(cell)
			_score_cells.append(cell)
	_net_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_net_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_net_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_net_label.add_theme_font_size_override("font_size", 12)
	_net_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	_net_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_net_label.add_theme_constant_override("outline_size", 3)
	add_child(_net_label)
	_weapon_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_weapon_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	_weapon_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_weapon_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_label.add_theme_font_size_override("font_size", 20)
	_weapon_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_weapon_label.add_theme_constant_override("outline_size", 4)
	add_child(_weapon_label)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		_net_label.visible = not _net_label.visible
		get_viewport().set_input_as_handled()


func show_state(players: Array, countdown: int, show_lives: bool) -> void:
	_countdown_label.visible = countdown > 0
	_countdown_label.text = str(countdown)
	_show_local_weapon(players)
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: Player, b: Player) -> bool: return a.slot < b.slot)
	for row in Session.MAX_PLAYERS:
		for column in SCORE_COLUMNS:
			_score_cells[row * SCORE_COLUMNS + column].visible = row < sorted.size()
		_score_icons[row].visible = row < sorted.size()
		if row >= sorted.size():
			continue
		var player: Player = sorted[row]
		if _score_icons[row].texture == null and player.character and player.character.sprite_sheet:
			var head := AtlasTexture.new()
			head.atlas = player.character.sprite_sheet
			head.region = HEAD_REGION
			_score_icons[row].texture = head
		_score_icons[row].modulate.a = 1.0 if player.lives > 0 or not show_lives else 0.35
		var lives_text := tr("HUD_UNLIMITED")
		if show_lives:
			lives_text = str(player.lives) if player.lives > 0 else tr("HUD_ELIMINATED")
		var values: Array[String] = [player.display_name, lives_text, str(player.kills), str(player.deaths)]
		for column in SCORE_COLUMNS:
			_score_cells[row * SCORE_COLUMNS + column].text = values[column]
		_score_cells[row * SCORE_COLUMNS].modulate = Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]


## ping_ms < 0 = nothing to measure (host, practice) or not measured yet.
func show_ping(ping_ms: int) -> void:
	if not _net_label.visible:
		return
	var text := tr("HUD_FPS").format({"fps": roundi(Engine.get_frames_per_second())})
	if ping_ms >= 0:
		text += "   " + tr("HUD_PING").format({"ping": ping_ms})
	_net_label.text = text


func _show_local_weapon(players: Array) -> void:
	for player: Player in players:
		if player.peer_id == multiplayer.get_unique_id():
			var weapon := player.current_weapon()
			_weapon_label.visible = weapon != null and player.visible
			if weapon:
				_weapon_label.text = tr("HUD_WEAPON").format({"weapon": tr(weapon.name_key)}) + _ability_text(player)
			return
	_weapon_label.visible = false


func _ability_text(player: Player) -> String:
	var ability := player.character.ability if player.character else null
	if ability == null:
		return ""
	var ability_name := tr(ability.name_key)
	if player.ability_cooldown <= 0.0:
		return "\n" + tr("HUD_ABILITY_READY").format({"ability": ability_name})
	return "\n" + tr("HUD_ABILITY_COOLDOWN").format({"ability": ability_name, "seconds": ("%.1f" % player.ability_cooldown).replace(".", ",")})
