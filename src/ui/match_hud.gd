class_name MatchHud
extends Control
## In-match overlay: scoreboard panel(s) (ScoreTable; 2 v 2 = one per team, left and right),
## the start countdown and short blinking alerts (e.g. rising lava). Kill announcements
## float above the killer (KillPopup).
## Bottom left: FPS and (on clients) ping; F3 hides/shows it.

@onready var _score_panel: PanelContainer = %ScorePanel
@onready var _countdown_label: Label = %CountdownLabel

## One table (free-for-all) or one per team (2 v 2: red on the left, blue on the right).
var _tables: Array[ScoreTable] = []
var _team_mode := false
## Keys of the ability (bindings cannot change during a match).
var _ability_keys := ""
var _net_label := Label.new()
var _weapon_label := Label.new()
var _alert_label := Label.new()
var _alert_until_ms := 0


func _ready() -> void:
	_team_mode = Session.phase == Session.Phase.IN_MATCH and Session.team_mode
	_ability_keys = KeyBindings.action_text(&"ability")
	if _team_mode:
		var left := _score_panel.duplicate() as PanelContainer
		add_child(left)
		left.anchor_left = 0.0
		left.anchor_right = 0.0
		left.offset_left = -_score_panel.offset_right  # same margin as the right panel
		left.offset_right = left.offset_left
		left.grow_horizontal = Control.GROW_DIRECTION_END
		for team in Teams.COUNT:
			var table := ScoreTable.new()
			(left if team == 0 else _score_panel).add_child(table)
			table.setup(tr(Teams.NAME_KEYS[team]), Teams.color(team), Teams.MAX_PER_TEAM, true)
			_tables.append(table)
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
	if not _team_mode:
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
