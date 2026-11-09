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
	KeyBindings.bind(&"jump", 0, _key(KEY_E))
	check_eq(KeyBindings.encode(KeyBindings.events(&"jump")[0]), "key:%d" % KEY_E, "jump is now E")
	for event in KeyBindings.events(&"ability"):
		check(KeyBindings.encode(event) != "key:%d" % KEY_E, "E no longer uses the ability")
	check_eq(KeyBindings.serialize()["ability"], PackedStringArray(["mouse:%d" % MOUSE_BUTTON_RIGHT]), "ability keeps its mouse button")
	KeyBindings.reset_to_defaults()


func test_defaults_are_wasd_only_with_q_reload() -> void:
	KeyBindings.reset_to_defaults()
	var saved := KeyBindings.serialize()
	check_eq(saved["move_left"], PackedStringArray(["key:%d" % KEY_A]), "left: A only")
	check_eq(saved["move_right"], PackedStringArray(["key:%d" % KEY_D]), "right: D only")
	check_eq(saved["jump"], PackedStringArray(["key:%d" % KEY_W]), "jump: W only (no Space)")
	check_eq(saved["down"], PackedStringArray(["key:%d" % KEY_S]), "down: S only")
	check_eq(saved["reload"], PackedStringArray(["key:%d" % KEY_Q]), "reload: Q")


func test_old_saves_drop_space_and_arrows() -> void:
	KeyBindings.reset_to_defaults()
	var old_save := {"move_left": PackedStringArray(["key:%d" % KEY_A, "key:%d" % KEY_LEFT]),
			"move_right": PackedStringArray(["key:%d" % KEY_RIGHT]), "jump": PackedStringArray(["key:%d" % KEY_W, "key:%d" % KEY_SPACE]),
			"down": PackedStringArray(["key:%d" % KEY_S, "key:%d" % KEY_DOWN]), "fire": PackedStringArray(["mouse:1"]),
			"ability": PackedStringArray(["mouse:2", "key:%d" % KEY_E])}
	KeyBindings.apply(old_save, 1)
	var saved := KeyBindings.serialize()
	check_eq(saved["move_left"], PackedStringArray(["key:%d" % KEY_A]), "left arrow removed")
	check_eq(saved["move_right"], PackedStringArray(["key:%d" % KEY_D]), "only an arrow saved: back to the default D")
	check_eq(saved["jump"], PackedStringArray(["key:%d" % KEY_W]), "Space removed")
	check_eq(saved["down"], PackedStringArray(["key:%d" % KEY_S]), "down arrow removed")
	check_eq(saved["reload"], PackedStringArray(["key:%d" % KEY_Q]), "reload (not in the old save) gets Q")
	KeyBindings.apply({"jump": PackedStringArray(["key:%d" % KEY_SPACE])})
	check_eq(KeyBindings.serialize()["jump"], PackedStringArray(["key:%d" % KEY_SPACE]), "a current save may bind Space on purpose")
	KeyBindings.reset_to_defaults()


func test_new_action_default_does_not_steal_a_used_key() -> void:
	KeyBindings.reset_to_defaults()
	KeyBindings.apply({"ability": PackedStringArray(["key:%d" % KEY_Q])}, 1)
	check_eq(KeyBindings.serialize()["ability"], PackedStringArray(["key:%d" % KEY_Q]), "the player's Q stays on the ability")
	check(KeyBindings.events(&"reload").is_empty(), "reload stays unbound instead of sharing Q")
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
