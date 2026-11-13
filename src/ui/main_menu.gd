extends Control
## Main menu: practice, host or join. Network errors from the last session
## (Session.last_end_message) are shown here after returning from the lobby.

const PRACTICE_SCENE_PATH := "res://src/match/match.tscn"
const LOBBY_SCENE_PATH := "res://src/ui/lobby.tscn"
const SETTINGS_PATH := "res://src/ui/settings_screen.tscn"
const ERROR_COLOR := Color(1.0, 0.45, 0.4)
const INFO_COLOR := Color(0.75, 0.78, 0.85)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _practice_button: Button = %PracticeButton
@onready var _character_option: OptionButton = %CharacterOption
@onready var _arena_option: OptionButton = %ArenaOption
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _changelog_button: Button = %ChangelogButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _changelog_dialog: AcceptDialog = %ChangelogDialog
@onready var _changelog_text: RichTextLabel = %ChangelogText
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel
@onready var _update_panel: PanelContainer = %UpdatePanel
@onready var _update_label: Label = %UpdateLabel
@onready var _update_progress: ProgressBar = %UpdateProgress
@onready var _update_button: Button = %UpdateButton
@onready var _update_later_button: Button = %UpdateLaterButton

var _updater := Updater.new()
## After a failed update the button opens the download page instead.
var _manual_download := false


func _ready() -> void:
	get_window().title = tr("GAME_TITLE")  # the project/user-data name stays "gun_game"
	_version_label.text = tr("MENU_VERSION").format({"version": BuildInfo.display_string()})
	_name_edit.max_length = Session.MAX_NAME_LENGTH
	_name_edit.text = Settings.player_name
	# The address always contains a new room code, so it is never prefilled; the example
	# placeholder disappears as soon as the field is clicked.
	_address_edit.focus_entered.connect(func() -> void: _address_edit.placeholder_text = "")
	_address_edit.focus_exited.connect(func() -> void: _address_edit.placeholder_text = tr("MENU_ADDRESS_PLACEHOLDER"))
	_fill_character_option()
	_fill_arena_option()
	_practice_button.pressed.connect(_on_practice_pressed)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_address_edit.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	_changelog_button.pressed.connect(_on_changelog_pressed)
	_settings_button.pressed.connect(func() -> void:
		_remember_inputs()
		get_tree().change_scene_to_file(SETTINGS_PATH))
	_changelog_dialog.visibility_changed.connect(_on_changelog_visibility_changed)
	_quit_button.pressed.connect(get_tree().quit)
	Session.phase_changed.connect(_on_session_phase_changed)
	Session.ended.connect(_show_status.bind(ERROR_COLOR))
	_show_status(Session.last_end_message, ERROR_COLOR)
	Session.last_end_message = ""
	_practice_button.grab_focus()
	_setup_updater()


func _on_changelog_pressed() -> void:
	var entry := Changelog.latest()
	_changelog_dialog.title = tr("CHANGELOG_TITLE")
	_changelog_text.text = Changelog.format_entry(entry) if not entry.is_empty() else tr("CHANGELOG_EMPTY")
	_show_text_dialog()


## The text dialog (changelog).
func _show_text_dialog() -> void:
	_changelog_text.scroll_to_line(0)
	# Scrolling text does not contribute a useful minimum size to AcceptDialog.
	var available_size := Vector2i(Vector2(get_window().size) * 0.9)
	_changelog_dialog.min_size = Vector2i(clampi(available_size.x, 280, 840), clampi(available_size.y, 180, 560))
	_changelog_dialog.popup_centered_clamped(_changelog_dialog.min_size, 0.9)
	_changelog_text.grab_focus()


func _on_changelog_visibility_changed() -> void:
	if not _changelog_dialog.visible:
		_changelog_button.grab_focus.call_deferred()


func _setup_updater() -> void:
	add_child(_updater)
	if not _updater.is_supported():
		return
	Updater.cleanup_old_files()
	_updater.update_available.connect(_on_update_available)
	_updater.download_progress.connect(func(fraction: float) -> void: _update_progress.value = fraction)
	_updater.failed.connect(_on_update_failed)
	_update_button.pressed.connect(_on_update_pressed)
	_update_later_button.pressed.connect(_update_panel.hide)
	_updater.check()


func _on_update_available(info: Dictionary) -> void:
	_update_label.text = tr("UPDATE_AVAILABLE").format({"version": "%s (%s)" % [info.version, tr("UPDATE_BUILD").format({"build": info.build})]})
	_update_panel.show()


func _on_update_pressed() -> void:
	if _manual_download:
		OS.shell_open(Updater.DOWNLOADS_PAGE_URL)
		return
	_update_button.disabled = true
	_update_later_button.disabled = true
	_update_progress.show()
	_update_label.text = tr("UPDATE_DOWNLOADING")
	_updater.download_and_install()


func _on_update_failed(message: String) -> void:
	_manual_download = true
	_update_progress.hide()
	_update_label.text = message
	_update_button.text = "UPDATE_MANUAL"
	_update_button.disabled = false
	_update_later_button.disabled = false
	_update_panel.show()


## Practice character choice (PLAN.md M5): every character from ContentDB, remembered.
func _fill_character_option() -> void:
	for id in ContentDB.character_ids():
		var character := ContentDB.get_character(id)
		_character_option.add_item(tr(character.name_key))
		var index := _character_option.item_count - 1
		_character_option.set_item_metadata(index, String(id))
		_character_option.set_item_tooltip(index, tr(character.description_key))
		if String(id) == Settings.practice_character or (Settings.practice_character.is_empty() and id == ContentDB.DEFAULT_CHARACTER_ID):
			_character_option.select(index)


## Practice arena (also the host's first lobby arena), remembered like the character.
func _fill_arena_option() -> void:
	var chosen := ContentDB.arena_or_default(Settings.practice_arena).id
	for id in ContentDB.arena_ids():
		var arena := ContentDB.arena_or_default(String(id))
		_arena_option.add_item(tr(arena.name_key))
		_arena_option.set_item_metadata(_arena_option.item_count - 1, String(id))
		_arena_option.set_item_tooltip(_arena_option.item_count - 1, arena.players_hint())
		if id == chosen:
			_arena_option.select(_arena_option.item_count - 1)
	_arena_option.item_selected.connect(_show_arena_hint)
	_show_arena_hint(_arena_option.selected)


## The closed map picker's tooltip: what it is for and how many players the map suits.
func _show_arena_hint(index: int) -> void:
	var hint := str(_arena_option.get_item_tooltip(index)) if index >= 0 else ""
	_arena_option.tooltip_text = tr("MENU_PRACTICE_ARENA") + ("\n" + hint if not hint.is_empty() else "")


func _on_practice_pressed() -> void:
	_remember_inputs()
	get_tree().change_scene_to_file(PRACTICE_SCENE_PATH)


func _on_host_pressed() -> void:
	_remember_inputs()
	Session.host_game(_name_edit.text)


func _on_join_pressed() -> void:
	_remember_inputs()
	Session.join_game(_address_edit.text, _name_edit.text)


func _remember_inputs() -> void:
	Settings.player_name = _name_edit.text.strip_edges()
	if _character_option.selected >= 0:
		Settings.practice_character = str(_character_option.get_item_metadata(_character_option.selected))
	if _arena_option.selected >= 0:
		Settings.practice_arena = str(_arena_option.get_item_metadata(_arena_option.selected))
	Settings.save()


func _on_session_phase_changed(phase: Session.Phase) -> void:
	var connecting := phase == Session.Phase.CONNECTING
	for button: Button in [_practice_button, _host_button, _join_button]:
		button.disabled = connecting
	if connecting:
		_show_status(tr("MENU_CONNECTING"), INFO_COLOR)
	elif phase == Session.Phase.LOBBY:
		get_tree().change_scene_to_file.call_deferred(LOBBY_SCENE_PATH)


func _show_status(message: String, color: Color) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)
