class_name ScoreTable
extends VBoxContainer
## One scoreboard: optional title (team name), then a row per player with the character
## icon, name, lives, kills and deaths. MatchHud shows one table, or one per team in 2 v 2.

const COLUMNS := 4  # name, lives, kills, deaths (plus the character icon column)
## Head of the character in its sprite sheet (first idle frame).
const HEAD_REGION := Rect2(8, 4, 16, 16)
const HEADER_COLOR := Color(1, 0.85, 0.5)
## Sizes [normal, compact]: compact is used for the two team tables (2 v 2), so they do not
## cover much of the arena.
const FONT_SIZE: Array[int] = [22, 15]
const HEADER_FONT_SIZE: Array[int] = [16, 12]
const ICON_SIZE: Array[float] = [32.0, 20.0]
const NAME_WIDTH: Array[float] = [200.0, 110.0]
const VALUE_WIDTH: Array[float] = [64.0, 38.0]
const H_SEPARATION: Array[int] = [14, 6]

var _title := Label.new()
var _grid := GridContainer.new()
var _cells: Array[Label] = []
var _icons: Array[TextureRect] = []


## title_text empty = no title row (free-for-all).
func setup(title_text: String, title_color: Color, rows: int, compact := false) -> void:
	var variant := 1 if compact else 0
	add_theme_constant_override("separation", 0 if compact else 4)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.text = title_text
	_title.visible = not title_text.is_empty()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", title_color)
	_title.add_theme_font_size_override("font_size", FONT_SIZE[variant])
	add_child(_title)
	_grid.columns = COLUMNS + 1
	_grid.add_theme_constant_override("h_separation", H_SEPARATION[variant])
	_grid.add_theme_constant_override("v_separation", 0 if compact else 4)
	add_child(_grid)
	_grid.add_child(Control.new())  # no heading above the icons
	for key: String in ["HUD_PLAYER", "HUD_LIVES_HEADER", "HUD_KILLS", "HUD_DEATHS"]:
		var heading := _label()
		heading.text = tr(key)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if key == "HUD_PLAYER" else HORIZONTAL_ALIGNMENT_CENTER
		heading.add_theme_font_size_override("font_size", HEADER_FONT_SIZE[variant])
		heading.add_theme_color_override("font_color", HEADER_COLOR)
		_grid.add_child(heading)
	for row in rows:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2.ONE * ICON_SIZE[variant]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.visible = false
		_grid.add_child(icon)
		_icons.append(icon)
		for column in COLUMNS:
			var cell := _label()
			cell.visible = false
			cell.add_theme_font_size_override("font_size", FONT_SIZE[variant])
			if column == 0:
				cell.custom_minimum_size.x = NAME_WIDTH[variant]
				cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				cell.clip_text = true
			else:
				cell.custom_minimum_size.x = VALUE_WIDTH[variant]
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_grid.add_child(cell)
			_cells.append(cell)


## players sorted as they should appear; name colors by team (2 v 2) or slot.
func show_players(players: Array, show_lives: bool) -> void:
	for row in _icons.size():
		var shown := row < players.size()
		_icons[row].visible = shown
		for column in COLUMNS:
			_cells[row * COLUMNS + column].visible = shown
		if not shown:
			continue
		var player: Player = players[row]
		if _icons[row].texture == null and player.character and player.character.sprite_sheet:
			var head := AtlasTexture.new()
			head.atlas = player.character.sprite_sheet
			head.region = HEAD_REGION
			_icons[row].texture = head
		_icons[row].modulate.a = 1.0 if player.lives > 0 or not show_lives else 0.35
		var lives_text := tr("HUD_UNLIMITED")
		if show_lives:
			lives_text = str(player.lives) if player.lives > 0 else tr("HUD_ELIMINATED")
		var values: Array[String] = [player.display_name, lives_text, str(player.kills), str(player.deaths)]
		for column in COLUMNS:
			_cells[row * COLUMNS + column].text = values[column]
		_cells[row * COLUMNS].modulate = Teams.color(player.team) if Teams.is_valid(player.team) \
				else Player.SLOT_COLORS[player.slot % Player.SLOT_COLORS.size()]


func _label() -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return label
