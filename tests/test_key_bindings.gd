extends TestCase
## Rebindable controls (KeyBindings); every test restores the defaults.


func _key(physical: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = true
	return event


func test_codes_roundtrip_and_reject_garbage() -> void:
	check_eq(KeyBindings.encode(KeyBindings.decode("key:65")), "key:65", "key code")
	check_eq(KeyBindings.encode(KeyBindings.decode("mouse:2")), "mouse:2", "mouse button")
	for bad in ["", "key", "key:abc", "mouse:99", "pad:1", "key:%d" % KEY_ESCAPE, "key:-5"]:
		check(KeyBindings.decode(bad) == null, "rejected: " + bad)


func test_bind_moves_a_key_away_from_other_actions() -> void:
	KeyBindings.reset_to_defaults()
	KeyBindings.bind(&"jump", 0, _key(KEY_D))
	check_eq(KeyBindings.encode(KeyBindings.events(&"jump")[0]), "key:%d" % KEY_D, "jump is now D")
	for event in KeyBindings.events(&"move_right"):
		check(KeyBindings.encode(event) != "key:%d" % KEY_D, "D no longer moves right")
	check(not KeyBindings.events(&"move_right").is_empty(), "move right keeps its other key")
	KeyBindings.reset_to_defaults()


func test_saved_bindings_apply_and_broken_ones_keep_defaults() -> void:
	KeyBindings.reset_to_defaults()
	var defaults := KeyBindings.serialize()
	KeyBindings.apply({"fire": PackedStringArray(["key:%d" % KEY_K]), "jump": PackedStringArray(["garbage"]), "ability": 5})
	check_eq(KeyBindings.serialize()["fire"], PackedStringArray(["key:%d" % KEY_K]), "saved key applied")
	check_eq(KeyBindings.serialize()["jump"], defaults["jump"], "broken entry keeps the default")
	check_eq(KeyBindings.serialize()["ability"], defaults["ability"], "wrong type ignored")
	KeyBindings.reset_to_defaults()
	check_eq(KeyBindings.serialize(), defaults, "reset restores everything")


func test_reserved_keys_and_labels() -> void:
	check(not KeyBindings.is_bindable(_key(KEY_ESCAPE)), "Esc stays reserved")
	check(not KeyBindings.is_bindable(_key(KEY_F3)), "F3 stays reserved")
	check(KeyBindings.is_bindable(_key(KEY_Q)), "normal key")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	check(KeyBindings.is_bindable(click), "mouse button")
	check_eq(KeyBindings.display(click), tr("KEY_MOUSE_LEFT"), "mouse label translated")
	check_eq(KeyBindings.display(_key(KEY_SPACE)), tr("KEY_SPACE"), "space label translated")
	check(not KeyBindings.action_text(&"jump").is_empty(), "help text for an action")
