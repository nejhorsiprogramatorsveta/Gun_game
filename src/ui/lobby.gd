extends Control
## Lobby: who is connected, the character choice (each character once, PLAN.md T.2) and,
## for the host, which address to send to friends.
## The host starts the match; every peer then switches to the match scene.

const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"
const MATCH_PATH := "res://src/match/match.tscn"
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

## character id -> its card button
var _character_buttons: Dictionary[String, Button] = {}


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
	_refresh_players()
	# Ask for the character picked in the main menu (the host got it when hosting).
	if not Session.is_host() and not Settings.practice_character.is_empty():
		Session.get_node("CharacterChoice").choose(Settings.practice_character)


func _refresh_players() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	_players_title.text = tr("LOBBY_PLAYERS").format({"count": Session.players.size(), "max": Session.MAX_PLAYERS})
	var ids := Session.players.keys()
	ids.sort()  # host (peer 1) first, then by join order-independent id
	for id: int in ids:
		var text: String = Session.players[id].name
		var character := ContentDB.get_character(StringName(str(Session.players[id].get("character", ""))))
		if character:
			text += " – " + tr(character.name_key)
		if id == 1:
			text += " " + tr("LOBBY_HOST_TAG")
		if id == multiplayer.get_unique_id():
			text += " " + tr("LOBBY_YOU_TAG")
		_player_list.add_child(_make_label(text))
	_refresh_character_cards()
	_start_button.disabled = not Session.can_start_match()
	if Session.is_host():
		_status_label.text = "" if Session.can_start_match() else tr("LOBBY_NEED_PLAYERS").format({"min": Session.MIN_PLAYERS_TO_START})
	else:
		_status_label.text = tr("LOBBY_WAITING_FOR_HOST")


func _build_character_cards() -> void:
	var title := _make_label(tr("LOBBY_CHOOSE_CHARACTER"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var column := _player_list.get_parent()
	column.add_child(title)
	column.add_child(grid)
	column.move_child(title, _player_list.get_index() + 1)
	column.move_child(grid, title.get_index() + 1)
	for id in ContentDB.character_ids():
		var button := Button.new()
		button.toggle_mode = true
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(230, 88)
		button.pressed.connect(_on_character_pressed.bind(String(id)))
		grid.add_child(button)
		_character_buttons[String(id)] = button


func _refresh_character_cards() -> void:
	var my_id := multiplayer.get_unique_id()
	for id in _character_buttons:
		var character := ContentDB.get_character(StringName(id))
		var owner_name := ""
		for peer_id: int in Session.players:
			if str(Session.players[peer_id].get("character", "")) == id:
				owner_name = "" if peer_id == my_id else str(Session.players[peer_id].name)
		var button := _character_buttons[id]
		var mine := str(Session.players.get(my_id, {}).get("character", "")) == id
		button.set_pressed_no_signal(mine)
		button.disabled = not owner_name.is_empty()
		var lines: PackedStringArray = [tr(character.name_key), tr(character.weapon.name_key) if character.weapon else ""]
		lines.append(tr(character.ability.name_key) if character.ability else "")
		if not owner_name.is_empty():
			lines[2] = tr("LOBBY_CHARACTER_TAKEN").format({"name": owner_name})
		button.text = "\n".join(lines)
		button.tooltip_text = tr(character.description_key) + ("\n" + tr(character.ability.description_key) if character.ability else "")


func _on_character_pressed(character_id: String) -> void:
	Settings.practice_character = character_id
	Settings.save()
	Session.get_node("CharacterChoice").choose(character_id)
	_refresh_character_cards()  # undo the toggle until the host confirms


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


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	return label
