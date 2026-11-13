extends Control
## Lobby (fits 1280 x 720 with 6 players, user 2026-11-13): map (left) and game mode (right;
## host: free-for-all, 2 teams or 3 teams) with the team buttons below, then the box
## "Players in the lobby (x/6)" next to the character choice (small cards with pixel-art
## previews; a click selects, "Confirm" takes the character; each character once, PLAN.md
## T.2) and, for the host, which address to send to friends.
## The host starts the match; every peer then switches to the match scene.

const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"
const MATCH_PATH := "res://src/match/match.tscn"
## Mode picker texts by Session.team_count (Teams.MODES).
const MODE_KEYS := {0: "LOBBY_MODE_FFA", 2: "LOBBY_MODE_TWO_TEAMS", 3: "LOBBY_MODE_THREE_TEAMS"}
## Character cards: size and the upper body of the first idle frame shown at 2x.
const CARD_SIZE := Vector2(0, 72)
const CARD_FONT_SIZE := 14
const CARD_PREVIEW_REGION := Rect2(0, 0, 32, 30)
const PLAYER_FONT_SIZE := 16
const ADDRESS_KIND_KEYS := {
	&"tailscale": "LOBBY_ADDRESS_TAILSCALE",
	&"lan": "LOBBY_ADDRESS_LAN",
}

@onready var _players_title: Label = %PlayersTitle
@onready var _player_list: VBoxContainer = %PlayerList
@onready var _share_section: VBoxContainer = %ShareSection
@onready var _address_list: GridContainer = %AddressList
@onready var _room_code_label: Label = %RoomCodeLabel
@onready var _internet_hint: Label = %InternetHint
@onready var _leave_button: Button = %LeaveButton
@onready var _start_button: Button = %StartButton
@onready var _status_label: Label = %StatusLabel
@onready var _arena_preview: ArenaPreview = %ArenaPreview
@onready var _character_grid: GridContainer = %CharacterGrid
@onready var _confirm_button: Button = %ConfirmButton
@onready var _arena_row: HBoxContainer = %ArenaRow
@onready var _mode_row: HBoxContainer = %ModeRow
@onready var _team_row: HBoxContainer = %TeamRow

## character id -> its card button
var _character_buttons: Dictionary[String, Button] = {}
## Card selected locally but maybe not confirmed yet.
var _selected_character := ""
## Last character the host stored as confirmed for us (the selection follows it once).
var _confirmed_character := ""
## Host: arena picker; clients: read-only arena name.
var _arena_option := OptionButton.new()
var _arena_label := Label.new()
## Host: game mode picker; clients: read-only mode name. Team buttons only in team modes.
var _mode_option := OptionButton.new()
var _mode_label := Label.new()
var _team_buttons: Array[Button] = []
## Skin switches for the selected character (sent to the host, CharacterChoice.set_skins).
var _skins := SkinToggles.new()


func _ready() -> void:
	Session.players_changed.connect(_refresh_players)
	Session.ended.connect(func(_message: String) -> void: get_tree().change_scene_to_file.call_deferred(MAIN_MENU_PATH))
	Session.phase_changed.connect(_on_phase_changed)
	_leave_button.pressed.connect(Session.leave)
	_start_button.pressed.connect(Session.start_match)
	_start_button.visible = Session.is_host()
	_share_section.visible = Session.is_host()
	if Session.is_host():
		_build_address_list()
	_build_character_cards()
	_build_arena_choice()
	_build_mode_choice()
	_refresh_players()
	if Session.phase == Session.Phase.IN_MATCH:  # the next match started while we were loading
		get_tree().change_scene_to_file.call_deferred(MATCH_PATH)
		return
	_arena_preview.show_arena(Session.arena_id)


func _refresh_players() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	_players_title.text = tr("LOBBY_PLAYERS").format({"count": Session.players.size(), "max": Session.MAX_PLAYERS})
	var ids := Session.players.keys()
	ids.sort()  # host (peer 1) first, then by join order-independent id
	for id: int in ids:
		var text: String = Session.players[id].name
		var character := ContentDB.get_character(StringName(str(Session.players[id].get("character", ""))))
		if not Session.players[id].get("ready", false):
			text += " – " + tr("LOBBY_PICKING_CHARACTER")
		elif character:
			text += " – " + tr(character.name_key)
		var team := int(Session.players[id].get("team", Teams.NONE))
		if id == 1:
			text += " " + tr("LOBBY_HOST_TAG")
		if id == multiplayer.get_unique_id():
			text += " " + tr("LOBBY_YOU_TAG")
		var label := _make_label(text)
		label.add_theme_font_size_override("font_size", PLAYER_FONT_SIZE)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = text
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		if Session.team_count > 0 and Teams.is_valid(team):  # the team shows as the name's colour
			label.add_theme_color_override("font_color", Teams.color(team))
		var row := HBoxContainer.new()
		row.add_child(label)
		row.add_child(_stats_label(Session.players[id]))
		_player_list.add_child(row)
	_refresh_character_cards()
	_refresh_teams()
	_start_button.disabled = not Session.can_start_match()
	if Session.is_host():
		_status_label.text = ""
		if Session.players.size() < Session.MIN_PLAYERS_TO_START:
			_status_label.text = tr("LOBBY_NEED_PLAYERS").format({"min": Session.MIN_PLAYERS_TO_START})
		elif not CharacterChoice.all_confirmed(Session.players):
			_status_label.text = tr("LOBBY_NEED_CONFIRM")
		elif not Session.can_start_match():
			_status_label.text = tr("LOBBY_NEED_TEAMS").format({"max": Teams.max_per_team(Session.team_count)})
	else:
		_status_label.text = tr("LOBBY_WAITING_FOR_HOST")


func _build_character_cards() -> void:
	for id in ContentDB.character_ids():
		var character := ContentDB.get_character(id)
		var button := Button.new()
		button.toggle_mode = true
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = CARD_SIZE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if character.sprite_sheet:  # upper body of the first idle frame, 2x without blurring
			var preview := AtlasTexture.new()
			preview.atlas = character.sprite_sheet
			preview.region = CARD_PREVIEW_REGION
			button.icon = preview
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", int(CARD_PREVIEW_REGION.size.x * 2))
			button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.pressed.connect(_on_character_pressed.bind(String(id)))
		_character_grid.add_child(button)
		_character_buttons[String(id)] = button
	_confirm_button.pressed.connect(func() -> void: Session.get_node("CharacterChoice").choose(_selected_character))
	_confirm_button.get_parent().add_child(_skins)
	_confirm_button.get_parent().move_child(_skins, _confirm_button.get_index())
	_skins.changed.connect(func(skins: int) -> void:
		Session.get_node("CharacterChoice").set_skins(skins)
		_refresh_character_cards())


func _build_arena_choice() -> void:
	_arena_row.add_child(_make_label(tr("LOBBY_ARENA")))
	_arena_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_arena_row.add_child(_arena_label)
	_arena_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arena_row.add_child(_arena_option)
	for id in ContentDB.arena_ids():
		var arena := ContentDB.arena_or_default(String(id))
		_arena_option.add_item(tr(arena.name_key))
		_arena_option.set_item_metadata(_arena_option.item_count - 1, String(id))
		_arena_option.set_item_tooltip(_arena_option.item_count - 1, arena.players_hint())
	_arena_option.visible = Session.is_host()
	_arena_label.visible = not Session.is_host()
	_arena_option.item_selected.connect(func(index: int) -> void:
		Session.get_node("ArenaChoice").choose(str(_arena_option.get_item_metadata(index))))
	Session.get_node("ArenaChoice").changed.connect(_refresh_arena)
	_refresh_arena()


func _build_mode_choice() -> void:
	_mode_row.add_child(_make_label(tr("LOBBY_MODE")))
	_mode_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_mode_row.add_child(_mode_label)
	_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_row.add_child(_mode_option)
	for team_count in Teams.MODES:
		_mode_option.add_item(tr(MODE_KEYS[team_count]))
	_mode_option.visible = Session.is_host()
	_mode_label.visible = not Session.is_host()
	_mode_option.item_selected.connect(func(index: int) -> void:
		Session.get_node("TeamChoice").set_team_count(Teams.MODES[index]))
	for team in Teams.MAX_COUNT:
		var button := Button.new()
		button.toggle_mode = true
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(0, 36)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", Teams.color(team))
		button.add_theme_color_override("font_pressed_color", Teams.color(team).lightened(0.4))
		button.pressed.connect(_on_team_pressed.bind(team))
		_team_row.add_child(button)
		_team_buttons.append(button)
	Session.get_node("TeamChoice").mode_changed.connect(_refresh_players)


func _refresh_teams() -> void:
	_mode_option.select(maxi(Teams.MODES.find(Session.team_count), 0))
	_mode_label.text = tr(MODE_KEYS[Session.team_count])
	_team_row.visible = Session.team_count > 0
	var my_team := int(Session.players.get(multiplayer.get_unique_id(), {}).get("team", Teams.NONE))
	for team in _team_buttons.size():
		var members := Teams.count(Session.players, team)
		var button := _team_buttons[team]
		button.visible = team < Session.team_count
		button.text = tr("LOBBY_TEAM_BUTTON").format({"team": tr(Teams.NAME_KEYS[team]),
				"count": members, "max": Teams.max_per_team(Session.team_count)})
		button.set_pressed_no_signal(team == my_team)


func _on_team_pressed(team: int) -> void:
	Session.get_node("TeamChoice").choose(team)
	_refresh_teams()  # undo the toggle until the host confirms


func _refresh_arena() -> void:
	var arena := ContentDB.arena_or_default(Session.arena_id)
	if _arena_preview:
		_arena_preview.show_arena(Session.arena_id)
	_arena_label.text = tr(arena.name_key)
	_arena_label.tooltip_text = arena.players_hint()
	_arena_label.mouse_filter = Control.MOUSE_FILTER_PASS  # labels ignore the mouse (no tooltip) by default
	_arena_option.tooltip_text = arena.players_hint()  # the closed picker shows the chosen map's hint
	for index in _arena_option.item_count:
		if _arena_option.get_item_metadata(index) == String(arena.id):
			_arena_option.select(index)


func _refresh_character_cards() -> void:
	var my_id := multiplayer.get_unique_id()
	var me: Dictionary = Session.players.get(my_id, {})
	var confirmed: bool = me.get("ready", false)
	# Start from the menu favourite; after a confirmation follow what the host stored.
	if _selected_character.is_empty() or (confirmed and not _character_buttons.has(_selected_character)):
		_selected_character = Settings.practice_character if _character_buttons.has(Settings.practice_character) \
				else str(me.get("character", ""))
	if confirmed and str(me.get("character", "")) != _confirmed_character:
		_confirmed_character = str(me.get("character", ""))
		_selected_character = _confirmed_character
	if CharacterChoice.confirmed_by(Session.players, _selected_character, my_id) != 0:
		_selected_character = str(me.get("character", ""))  # someone else confirmed it first
	for id in _character_buttons:
		var character := ContentDB.get_character(StringName(id))
		var owner_id := CharacterChoice.confirmed_by(Session.players, id, my_id)
		var button := _character_buttons[id]
		if button.icon is AtlasTexture:  # the selected card previews the own skin choice
			(button.icon as AtlasTexture).atlas = character.sheet_for(Settings.skins if id == _selected_character else 0)
		button.set_pressed_no_signal(id == _selected_character)
		button.disabled = owner_id != 0
		var lines: PackedStringArray = [tr(character.name_key), tr(character.weapon.name_key) if character.weapon else ""]
		lines.append(tr(character.ability.name_key) if character.ability else "")
		if owner_id != 0:
			lines[2] = tr("LOBBY_CHARACTER_TAKEN").format({"name": str(Session.players[owner_id].name)})
		elif confirmed and str(me.get("character", "")) == id:
			lines[2] = tr("LOBBY_CHARACTER_CONFIRMED")
		button.text = "\n".join(lines)
		button.tooltip_text = tr(character.description_key) + ("\n" + tr(character.ability.description_key) if character.ability else "")
	_skins.show_character(_selected_character)
	var already := confirmed and str(me.get("character", "")) == _selected_character
	_confirm_button.disabled = already or not _character_buttons.has(_selected_character)
	_confirm_button.text = tr("LOBBY_CHARACTER_CONFIRMED" if already else "LOBBY_CONFIRM_CHARACTER")


func _on_character_pressed(character_id: String) -> void:
	_selected_character = character_id
	Settings.practice_character = character_id
	Settings.save()
	_refresh_character_cards()


func _on_phase_changed(phase: Session.Phase) -> void:
	if phase == Session.Phase.IN_MATCH:
		get_tree().change_scene_to_file.call_deferred(MATCH_PATH)


func _build_address_list() -> void:
	for child in _address_list.get_children():
		child.queue_free()
	_room_code_label.text = tr("LOBBY_ROOM_CODE").format({"code": Session.room_code})
	var addresses := Session.share_addresses()
	for entry in addresses:
		_address_list.add_child(_make_label(tr(ADDRESS_KIND_KEYS[entry.kind])))
		_address_list.add_child(_make_label(entry.address))
		var copy_button := Button.new()
		copy_button.text = "LOBBY_COPY"
		copy_button.pressed.connect(_copy.bind(entry.address, copy_button))
		_address_list.add_child(copy_button)
	if addresses.is_empty():
		_address_list.add_child(_make_label(tr("LOBBY_NO_ADDRESS")))
	var has_tailscale := addresses.any(func(entry: Dictionary) -> bool: return entry.kind == &"tailscale")
	_internet_hint.text = tr("LOBBY_HINT_TAILSCALE_ON" if has_tailscale else "LOBBY_HINT_TAILSCALE_OFF")


func _copy(address: String, button: Button) -> void:
	DisplayServer.clipboard_set(address)
	button.text = "LOBBY_COPIED"


## Lifetime kills / deaths of a lobby player (PlayerStats); matches in the tooltip.
func _stats_label(entry: Dictionary) -> Label:
	var label := _make_label(tr("LOBBY_PLAYER_STATS").format({"kills": entry.get("kills_total", 0), "deaths": entry.get("deaths_total", 0)}))
	label.add_theme_font_size_override("font_size", PLAYER_FONT_SIZE - 2)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	label.tooltip_text = tr("LOBBY_PLAYER_STATS_TOOLTIP").format({"kills": entry.get("kills_total", 0),
			"deaths": entry.get("deaths_total", 0), "matches": entry.get("matches_total", 0)})
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	return label
