class_name KeyBindings
## Rebindable controls (settings screen, PLAN.md T). Every action has two slots; the
## defaults come from project.godot [input]. Keys are stored by PHYSICAL position, so a
## binding stays on the same key on QWERTY and Czech QWERTZ keyboards; the label shows
## the key of the player's layout. Saved by Settings in user://settings.cfg as short codes
## ("key:65", "mouse:1"); broken or unknown codes fall back to the defaults.

const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump", &"down", &"fire", &"ability", &"reload"]
const NAME_KEYS := {
	&"move_left": "ACTION_MOVE_LEFT", &"move_right": "ACTION_MOVE_RIGHT", &"jump": "ACTION_JUMP",
	&"down": "ACTION_DOWN", &"fire": "ACTION_FIRE", &"ability": "ACTION_ABILITY", &"reload": "ACTION_RELOAD",
}
const SLOTS := 2
## Version of saved controls (Settings stores it with them). 2 (0.2.12): WASD only.
const VERSION := 2
## Space and the arrow keys were default inputs before VERSION 2; older saves drop them
## (Settings saved every binding, so a default cannot be told apart from a choice).
const REMOVED_IN_V2: Array[Key] = [KEY_SPACE, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]
## Reserved: Esc leaves the match / cancels, F3 toggles the FPS overlay.
const RESERVED_KEYS: Array[Key] = [KEY_ESCAPE, KEY_F3]
const MOUSE_BUTTON_KEYS := {
	MOUSE_BUTTON_LEFT: "KEY_MOUSE_LEFT", MOUSE_BUTTON_RIGHT: "KEY_MOUSE_RIGHT", MOUSE_BUTTON_MIDDLE: "KEY_MOUSE_MIDDLE",
	MOUSE_BUTTON_XBUTTON1: "KEY_MOUSE_4", MOUSE_BUTTON_XBUTTON2: "KEY_MOUSE_5",
}
## Keys whose layout label is unclear or missing in the pixel font.
const KEY_NAME_KEYS := {
	KEY_SPACE: "KEY_SPACE", KEY_LEFT: "KEY_ARROW_LEFT", KEY_RIGHT: "KEY_ARROW_RIGHT", KEY_UP: "KEY_ARROW_UP",
	KEY_DOWN: "KEY_ARROW_DOWN", KEY_SHIFT: "KEY_SHIFT", KEY_CTRL: "KEY_CTRL", KEY_ALT: "KEY_ALT",
	KEY_ENTER: "KEY_ENTER", KEY_TAB: "KEY_TAB", KEY_BACKSPACE: "KEY_BACKSPACE",
}

## action -> Array of InputEvents from project.godot (captured before anything is changed).
static var _defaults: Dictionary = {}


static func capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for action in ACTIONS:
		_defaults[action] = InputMap.action_get_events(action).duplicate()


static func reset_to_defaults() -> void:
	capture_defaults()
	for action in ACTIONS:
		_set_events(action, _defaults[action])


## saved: action (String) -> PackedStringArray of codes, as written by serialize();
## saved_version: VERSION it was written with (older saves are migrated).
static func apply(saved: Dictionary, saved_version: int = VERSION) -> void:
	capture_defaults()
	var kept_defaults: Array[StringName] = []
	var used_codes := {}
	for action in ACTIONS:
		var codes: Variant = saved.get(String(action))
		var events: Array[InputEvent] = []
		if typeof(codes) == TYPE_PACKED_STRING_ARRAY or typeof(codes) == TYPE_ARRAY:
			for code: Variant in codes:
				var event := decode(str(code))
				if event and events.size() < SLOTS and not (saved_version < 2 and _removed_in_v2(event)):
					events.append(event)
		if events.is_empty():  # never leave an action without any input: keep the defaults
			kept_defaults.append(action)
			continue
		_set_events(action, events)
		for event in events:
			used_codes[encode(event)] = true
	# Defaults (e.g. of an action added after the save) must not take a key that the
	# player already uses for something else.
	for action in kept_defaults:
		var free: Array[InputEvent] = []
		for event: InputEvent in _defaults[action]:
			if not encode(event).is_empty() and not used_codes.has(encode(event)):
				free.append(event)
		_set_events(action, free)


static func serialize() -> Dictionary:
	var result := {}
	for action in ACTIONS:
		var codes: PackedStringArray = []
		for event in events(action):
			codes.append(encode(event))
		result[String(action)] = codes
	return result


static func events(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if not encode(event).is_empty() and result.size() < SLOTS:
			result.append(event)
	return result


## Puts `event` into slot `slot` of `action` and removes the same input everywhere else,
## so one key never triggers two actions.
static func bind(action: StringName, slot: int, event: InputEvent) -> void:
	var code := encode(event)
	if code.is_empty() or not ACTIONS.has(action):
		return
	for other in ACTIONS:
		var kept: Array[InputEvent] = []
		for existing in events(other):
			if encode(existing) != code:
				kept.append(existing)
		if other != action:
			_set_events(other, kept)
		else:
			var own := events(action)
			if slot < own.size():
				own[slot] = decode(code)
			else:
				own.append(decode(code))
			var unique: Array[InputEvent] = []
			var seen := {}
			for existing in own:
				if not seen.has(encode(existing)):
					seen[encode(existing)] = true
					unique.append(existing)
			_set_events(action, unique)


## A pressed key (not reserved) or mouse button, usable as a binding.
static func is_bindable(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key:
		return key.pressed and not key.echo and key.physical_keycode != KEY_NONE and not RESERVED_KEYS.has(key.physical_keycode)
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and MOUSE_BUTTON_KEYS.has(mouse.button_index)


static func encode(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key and key.physical_keycode != KEY_NONE:
		return "key:%d" % key.physical_keycode
	var mouse := event as InputEventMouseButton
	if mouse and MOUSE_BUTTON_KEYS.has(mouse.button_index):
		return "mouse:%d" % mouse.button_index
	return ""


## "key:65" / "mouse:1" -> a fresh InputEvent, or null for anything else.
static func decode(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var value := parts[1].to_int()
	if parts[0] == "key" and value > 0 and value < 0x2000000 and not RESERVED_KEYS.has(value):
		var key := InputEventKey.new()
		key.physical_keycode = value as Key
		return key
	if parts[0] == "mouse" and MOUSE_BUTTON_KEYS.has(value):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = value as MouseButton
		return mouse
	return null


## Label of one input on the player's keyboard layout, e.g. "W", "Mezerník", "Levé tlačítko myši".
static func display(event: InputEvent) -> String:
	var mouse := event as InputEventMouseButton
	if mouse:
		return TranslationServer.translate(MOUSE_BUTTON_KEYS.get(mouse.button_index, "KEY_MOUSE_LEFT"))
	var key := event as InputEventKey
	if key == null:
		return ""
	if KEY_NAME_KEYS.has(key.physical_keycode):
		return TranslationServer.translate(KEY_NAME_KEYS[key.physical_keycode])
	var keycode := key.physical_keycode
	if DisplayServer.get_name() != "headless":  # the headless server (tests, CI) has no keyboard layout
		keycode = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
	var label := OS.get_keycode_string(keycode)
	return label if not label.is_empty() else OS.get_keycode_string(key.physical_keycode)


## All inputs of an action for help texts, e.g. "W / Mezerník".
static func action_text(action: StringName) -> String:
	var labels: PackedStringArray = []
	for event in events(action):
		labels.append(display(event))
	return " / ".join(labels) if not labels.is_empty() else "–"


static func _removed_in_v2(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and REMOVED_IN_V2.has(key.physical_keycode)


static func _set_events(action: StringName, new_events: Array) -> void:
	InputMap.action_erase_events(action)
	for event: InputEvent in new_events:
		InputMap.action_add_event(action, event)
