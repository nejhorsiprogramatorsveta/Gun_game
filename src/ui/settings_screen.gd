extends Control
## Settings: rebinding of movement, shooting and the ability (KeyBindings, two inputs per
## action), reset to defaults, and the folder with the diagnostic log (docs/PLAYTEST.md).
## Built in code; Esc (when not waiting for a key) goes back to the main menu.

const MAIN_MENU_PATH := "res://src/ui/main_menu.tscn"
const BACKGROUND: Texture2D = preload("res://assets/backgrounds/temple_steps.png")

## action -> [slot buttons]
var _slot_buttons: Dictionary[StringName, Array] = {}
## [action, slot] while waiting for the new input, otherwise empty.
var _waiting: Array = []
var _hint := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ArenaBackground.new()
	background.scene = BACKGROUND
	background.dim = 0.45
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(640, 0)
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	column.add_child(_label(tr("SETTINGS_TITLE"), 34, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label(tr("SETTINGS_CONTROLS"), 22, HORIZONTAL_ALIGNMENT_LEFT))
	var grid := GridContainer.new()
	grid.columns = 1 + KeyBindings.SLOTS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for action in KeyBindings.ACTIONS:
		var name_label := _label(tr(KeyBindings.NAME_KEYS[action]), 20, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.custom_minimum_size.x = 200
		grid.add_child(name_label)
		var buttons: Array[Button] = []
		for slot in KeyBindings.SLOTS:
			var button := Button.new()
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.custom_minimum_size = Vector2(210, 38)
			button.pressed.connect(_start_waiting.bind(action, slot))
			grid.add_child(button)
			buttons.append(button)
		_slot_buttons[action] = buttons
	_hint.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color(0.75, 0.77, 0.83))
	column.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	row.add_child(_button("SETTINGS_RESET", _on_reset_pressed))
	row.add_child(_button("SETTINGS_OPEN_LOGS", DiagLog.open_folder))
	column.add_child(_label(tr("SETTINGS_LOGS_HINT"), 15, HORIZONTAL_ALIGNMENT_LEFT))
	var back := _button("SETTINGS_BACK", _go_back)
	column.add_child(back)
	back.grab_focus()
	_refresh()


func _input(event: InputEvent) -> void:
	if _waiting.is_empty():
		return
	var key := event as InputEventKey
	if key and key.pressed and key.physical_keycode == KEY_ESCAPE:
		_waiting = []
		_refresh()
		get_viewport().set_input_as_handled()
	elif KeyBindings.is_bindable(event):
		KeyBindings.bind(_waiting[0], _waiting[1], event)
		Settings.save()
		_waiting = []
		_refresh()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting.is_empty() and event.is_action_pressed("ui_cancel"):
		_go_back()


func _start_waiting(action: StringName, slot: int) -> void:
	_waiting = [action, slot]
	_refresh()


func _refresh() -> void:
	for action in _slot_buttons:
		var events := KeyBindings.events(action)
		var buttons: Array = _slot_buttons[action]
		for slot in buttons.size():
			var button: Button = buttons[slot]
			if _waiting == [action, slot]:
				button.text = tr("SETTINGS_PRESS_KEY")
			else:
				button.text = KeyBindings.display(events[slot]) if slot < events.size() else tr("SETTINGS_UNBOUND")
	_hint.text = tr("SETTINGS_WAITING_HINT") if not _waiting.is_empty() else tr("SETTINGS_HINT")


func _on_reset_pressed() -> void:
	KeyBindings.reset_to_defaults()
	Settings.save()
	_waiting = []
	_refresh()


func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _label(text: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text_key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_key
	button.custom_minimum_size = Vector2(0, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button
