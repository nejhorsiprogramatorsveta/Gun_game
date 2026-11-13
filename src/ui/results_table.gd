class_name ResultsTable
extends VBoxContainer
## The table on the results screen (user 2026-11-13: "a nicer table sorted by kills with
## places 1., 2., ..."): place, character portrait, name in the team or slot colour, kills,
## deaths and a "winner" tag for the last one (or the team) standing. Striped rows; the own
## row is highlighted. Rows come from LobbyValidator.results.

const PLACE_COLORS: Array[Color] = [Color(1, 0.84, 0.3), Color(0.82, 0.84, 0.9), Color(0.85, 0.58, 0.35)]
const HEADER_COLOR := Color(1, 0.85, 0.5)
const FONT_SIZE := 24
const HEADER_FONT_SIZE := 16
## Column widths: place, portrait, name, kills, deaths, winner tag.
const WIDTHS: Array[float] = [56.0, 40.0, 250.0, 96.0, 96.0, 84.0]
const ROW_COLORS: Array[Color] = [Color(0.12, 0.1, 0.17, 0.85), Color(0.17, 0.14, 0.23, 0.85)]
const OWN_ROW_COLOR := Color(0.36, 0.28, 0.12, 0.9)
const HEAD_REGION := Rect2(8, 4, 16, 16)


## Most kills first; fewer deaths, then who lasted longer, break ties.
static func sorted_by_kills(rows: Array) -> Array:
	var sorted := rows.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.get("kills", 0) != b.get("kills", 0):
			return a.get("kills", 0) > b.get("kills", 0)
		if a.get("deaths", 0) != b.get("deaths", 0):
			return a.get("deaths", 0) < b.get("deaths", 0)
		return a.get("place", 99) < b.get("place", 99))
	return sorted


## own_slot: the local player's slot (-1 = none).
func show_rows(rows: Array, own_slot: int) -> void:
	add_theme_constant_override("separation", 3)
	add_child(_row(["RESULTS_COLUMN_PLACE", "", "HUD_PLAYER", "HUD_KILLS", "HUD_DEATHS", ""], null, Color.TRANSPARENT, true))
	var sorted := sorted_by_kills(rows)
	for i in sorted.size():
		var entry: Dictionary = sorted[i]
		var cells: Array[String] = ["%d." % (i + 1), "", str(entry.get("name", "?")), str(entry.get("kills", 0)),
				str(entry.get("deaths", 0)), tr("RESULTS_WINNER_TAG") if entry.get("place", 0) == 1 else ""]
		var background := OWN_ROW_COLOR if own_slot >= 0 and entry.get("slot", -1) == own_slot else ROW_COLORS[i % 2]
		var row := _row(cells, ContentDB.get_character(StringName(str(entry.get("character", "")))), background, false,
				int(entry.get("skins", 0)))
		var labels := row.get_child(0).get_children()
		(labels[0] as Label).add_theme_color_override("font_color", PLACE_COLORS[i] if i < PLACE_COLORS.size() else Color.WHITE)
		(labels[2] as Label).add_theme_color_override("font_color", _name_color(entry))
		(labels[5] as Label).add_theme_color_override("font_color", PLACE_COLORS[0])
		add_child(row)


func _row(cells: Array, character: CharacterData, background: Color, header: bool, skins: int = 0) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	panel.add_child(line)
	for column in cells.size():
		if column == 1:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(WIDTHS[1], 32)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if character and character.sprite_sheet:
				var head := AtlasTexture.new()
				head.atlas = character.sheet_for(skins)
				head.region = HEAD_REGION
				icon.texture = head
			line.add_child(icon)
			continue
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = tr(cells[column]) if header else cells[column]
		label.custom_minimum_size.x = WIDTHS[column]
		label.add_theme_font_size_override("font_size", HEADER_FONT_SIZE if header else FONT_SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if column == 2 else HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = column == 2
		if header:
			label.add_theme_color_override("font_color", HEADER_COLOR)
		line.add_child(label)
	return panel


static func _name_color(entry: Dictionary) -> Color:
	var team: int = entry.get("team", Teams.NONE)
	if Teams.is_valid(team):
		return Teams.color(team)
	var slot: int = entry.get("slot", -1)
	return Player.SLOT_COLORS[slot].lightened(0.3) if slot >= 0 and slot < Player.SLOT_COLORS.size() else Color.WHITE
