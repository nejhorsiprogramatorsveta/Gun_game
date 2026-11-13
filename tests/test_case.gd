class_name TestCase
extends RefCounted
## Base class for tests run by tests/run_tests.gd. Each test_* method is one test.

var failures: PackedStringArray = []
var current_test := ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


## Bodies added to the scene take part in physics queries (test_move, rays) only after the
## next physics step: `await physics_step()` after building a test world.
func physics_step() -> void:
	await (Engine.get_main_loop() as SceneTree).physics_frame
