extends TestCase
## The single diagnostic log file (DiagFileLogger): memory before a game, one file per game.

const TEST_PATH := "user://test_diag/last_game.log"


func _content() -> String:
	return FileAccess.get_file_as_string(TEST_PATH)


func test_lines_before_a_game_are_kept_and_each_game_replaces_the_file() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	var logger := DiagFileLogger.new()
	logger.path = TEST_PATH
	logger._log_message("startup line\n", false)
	logger._log_error("func", "file.gd", 7, "code", "something broke", false, 0, [] as Array[ScriptBacktrace])
	check(not FileAccess.file_exists(TEST_PATH), "nothing written to disk before a game")
	logger.begin_game("=== header 1 ===")
	logger._log_message(DiagLog.line("conn", "peer 5 connected"), false)
	var first := _content()
	check(first.begins_with("=== header 1 ==="), "header first")
	check(first.contains("startup line") and first.contains("ERROR: something broke (file.gd:7 func)"), "remembered lines and errors")
	check(first.contains("] [conn] peer 5 connected"), "live line written and flushed")
	logger.begin_game("=== header 2 ===")
	logger._log_message("second game", false)
	logger.flush()
	var second := _content()
	check(second.begins_with("=== header 2 ===") and not second.contains("peer 5"), "a new game replaces the old log")
	logger.close()
	DirAccess.remove_absolute(TEST_PATH)
	DirAccess.remove_absolute(TEST_PATH.get_base_dir())


func test_stamps() -> void:
	var stamped := DiagFileLogger.stamp("x")
	check(DiagFileLogger.is_stamped(stamped), "own stamp is recognised")
	check(not DiagFileLogger.is_stamped("[net] something"), "other brackets are not a stamp")
