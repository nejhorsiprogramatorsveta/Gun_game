extends Control
## Lobby: who is connected and, for the host, which address to send to friends.
## Starting a match is added in M2 step 4.

const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"
const INTERNET_STATUS_KEYS := {
	&"checking": "LOBBY_UPNP_CHECKING",
	&"open": "LOBBY_UPNP_OPEN",
	&"failed": "LOBBY_UPNP_FAILED",
	&"cgnat": "LOBBY_UPNP_CGNAT",
}
const ADDRESS_KIND_KEYS := {
	&"public": "LOBBY_ADDRESS_PUBLIC",
	&"tailscale": "LOBBY_ADDRESS_TAILSCALE",
	&"lan": "LOBBY_ADDRESS_LAN",
	&"ipv6": "LOBBY_ADDRESS_IPV6",
}

@onready var _players_title: Label = %PlayersTitle
@onready var _player_list: VBoxContainer = %PlayerList
@onready var _share_section: VBoxContainer = %ShareSection
@onready var _address_list: GridContainer = %AddressList
@onready var _room_code_label: Label = %RoomCodeLabel
@onready var _internet_hint: Label = %InternetHint
@onready var _leave_button: Button = %LeaveButton


func _ready() -> void:
	Session.players_changed.connect(_refresh_players)
	Session.ended.connect(func(_message: String) -> void: get_tree().change_scene_to_file.call_deferred(MAIN_MENU_PATH))
	_leave_button.pressed.connect(Session.leave)
	_share_section.visible = Session.is_host()
	if Session.is_host():
		Session.share_info_changed.connect(_build_address_list)
		_build_address_list()
	_refresh_players()


func _refresh_players() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	_players_title.text = tr("LOBBY_PLAYERS").format({"count": Session.players.size(), "max": Session.MAX_PLAYERS})
	var ids := Session.players.keys()
	ids.sort()  # host (peer 1) first, then by join order-independent id
	for id: int in ids:
		var text: String = Session.players[id].name
		if id == 1:
			text += " " + tr("LOBBY_HOST_TAG")
		if id == multiplayer.get_unique_id():
			text += " " + tr("LOBBY_YOU_TAG")
		_player_list.add_child(_make_label(text))


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
	var status := Session.internet_status()
	_internet_hint.text = tr(INTERNET_STATUS_KEYS[status]).format({"port": Session.host_port}) if INTERNET_STATUS_KEYS.has(status) else ""


func _copy(address: String, button: Button) -> void:
	DisplayServer.clipboard_set(address)
	button.text = "LOBBY_COPIED"


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	return label
