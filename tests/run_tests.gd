extends SceneTree
## Minimal headless test runner (no addon needed):
##   tools/godot --headless --path . -s tests/run_tests.gd
## Runs every test_* method of every tests/test_*.gd (subclasses of TestCase).
## A test may `await` (e.g. TestCase.physics_step() so new bodies are in the physics
## world); the runner waits for it. Exit code 1 if anything fails, so CI stops.

const TESTS_DIR := "res://tests/"


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	var test_count := 0
	var failures: PackedStringArray = []
	for file_name in DirAccess.get_files_at(TESTS_DIR):
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")) or file_name == "test_case.gd":
			continue
		var suite: TestCase = load(TESTS_DIR + file_name).new()
		for method in suite.get_method_list():
			var method_name: String = method.name
			if not method_name.begins_with("test_"):
				continue
			suite.current_test = "%s::%s" % [file_name, method_name]
			var result: Variant = suite.call(method_name)
			if result is Object and (result as Object).has_signal("completed"):  # the test awaited
				await (result as Object).completed
			test_count += 1
		failures.append_array(suite.failures)

	for failure in failures:
		printerr("FAIL ", failure)
	print("%d tests, %d failures" % [test_count, failures.size()])
	quit(1 if failures.size() > 0 or test_count == 0 else 0)
