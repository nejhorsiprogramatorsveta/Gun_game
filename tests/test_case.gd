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
