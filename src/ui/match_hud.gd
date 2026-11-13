class_name MatchHud
extends Control
## In-match overlay: scoreboard panel(s) (ScoreTable; team modes = one per team: red on the
## left, blue on the right, green at the top centre),
## the start countdown and short blinking alerts (e.g. rising lava). Kill announcements
## float above the killer (KillPopup).
## Bottom left: FPS and (on clients) ping; F3 hides/shows it.

@onready var _score_panel: PanelContainer = %ScorePanel
@onready var _countdown_label: Label = %CountdownLabel

## One table (free-for-all) or one per team (index = team).
var _tables: Array[ScoreTable] = []
var _team_count := Teams.FREE_FOR_ALL
## Keys of the ability (bindings cannot change during a match).
var _ability_keys := ""
var _net_label := Label.new()
var _weapon_label := Label.new()
var _alert_label := Label.new()
var _alert_until_ms := 0


## Inner padding of the scoreboard panels (the theme's panel has 16 x 12).
const SCORE_PANEL_MARGIN := Vector2(8, 5)


func _ready() -> void:
	_team_count = Session.team_count if Session.phase == Session.Phase.IN_MATCH else Teams.FREE_FOR_ALL
	_ability_keys = KeyBindings.action_text(&"ability")
	var panel_style := _score_panel.get_theme_stylebox("panel").duplicate() as StyleBox
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		panel_style.set_content_margin(side, SCORE_PANEL_MARGIN.x)
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		panel_style.set_content_margin(side, SCORE_PANEL_MARGIN.y)
	_score_panel.add_theme_stylebox_override("panel", panel_style)
	if _team_count > 0:
		var panels: Array[PanelContainer] = [_team_panel(0.0, -_score_panel.offset_right, Control.GROW_DIRECTION_END),
				_score_panel, _team_panel(0.5, 0.0, Control.GROW_DIRECTION_BOTH)]
		for team in _team_count:
			var table := ScoreTable.new()
			panels[team].add_child(table)
			table.setup(tr(Teams.NAME_KEYS[team]), Teams.color(team), Teams.max_per_team(_team_count))
			_tables.append(table)
		if _team_count < 3:
			panels[2].queue_free()
	else:
		var table := ScoreTable.new()
		_score_panel.add_child(table)
		table.setup("", Color.WHITE, Session.MAX_PLAYERS)
		_tables.append(table)
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
	_alert_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_alert_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 140)
	_alert_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 44)
	_alert_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
	_alert_label.add_theme_color_override("font_outline_color", Color(0.15, 0.02, 0.0))
	_alert_label.add_theme_constant_override("outline_size", 8)
	_alert_label.visible = false
	add_child(_alert_label)


## Another team's scoreboard panel like the right one, anchored at `anchor` (0 = left edge,
## 0.5 = centre) with the same top margin.
func _team_panel(anchor: float, offset: float, grow: Control.GrowDirection) -> PanelContainer:
	var panel := _score_panel.duplicate() as PanelContainer
	add_child(panel)
	panel.anchor_left = anchor
	panel.anchor_right = anchor
	panel.offset_left = offset
	panel.offset_right = offset
	panel.grow_horizontal = grow
	return panel


## A big blinking message for a few seconds (e.g. "Lava is rising!").
func show_alert(text: String, seconds: float = 3.0) -> void:
	_alert_label.text = text
	_alert_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		_net_label.visible = not _net_label.visible
		get_viewport().set_input_as_handled()


func show_state(players: Array, countdown: int, show_lives: bool) -> void:
	_countdown_label.visible = countdown > 0
	_countdown_label.text = str(countdown)
	var now := Time.get_ticks_msec()
	_alert_label.visible = now < _alert_until_ms and (now / 250) % 2 == 0
	_show_local_weapon(players)
	var sorted := players.duplicate()
	sorted.sort_custom(func(a: Player, b: Player) -> bool: return a.slot < b.slot)
	if _team_count <= 0:
		_tables[0].show_players(sorted, show_lives)
		return
	for team in _tables.size():
		_tables[team].show_players(sorted.filter(func(player: Player) -> bool: return player.team == team), show_lives)


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
				var ammo := tr("HUD_RELOADING") if player.gun.is_reloading() \
						else tr("HUD_AMMO").format({"ammo": player.gun.ammo, "max": weapon.magazine_size})
				_weapon_label.text = tr("HUD_WEAPON").format({"weapon": tr(weapon.name_key), "ammo": ammo}) + _ability_text(player)
			return
	_weapon_label.visible = false


func _ability_text(player: Player) -> String:
	var ability := player.character.ability if player.character else null
	if ability == null:
		return ""
	var ability_name := tr(ability.name_key)
	if player.ability_cooldown <= 0.0:
		return "\n" + tr("HUD_ABILITY_READY").format({"ability": ability_name, "keys": _ability_keys})
	return "\n" + tr("HUD_ABILITY_COOLDOWN").format({"ability": ability_name, "seconds": ("%.1f" % player.ability_cooldown).replace(".", ",")})
