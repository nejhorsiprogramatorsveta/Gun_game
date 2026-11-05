class_name DiagFileLogger
extends Logger
## The game's only log file (docs/PLAYTEST.md): user://logs/last_game.log holds the LAST
## online game (from hosting/joining until the next one), so logs never pile up on disk.
## Godot's own godot.log is switched off in project.godot. Receives every print, warning
## and engine/script error (Godot Logger API, may be called from any thread).
## Before a game starts, lines are kept in memory (startup info, errors) and written at the
## top of the new file. The file is capped at MAX_BYTES.

const PATH := "user://logs/last_game.log"
const MAX_BYTES := 4 * 1024 * 1024
const MEMORY_LINES := 300
## Unimportant lines (e.g. an error flood) are flushed at most this often; timestamped
## diagnostic lines (DiagLog) are flushed right away so a crash loses nothing important.
const FLUSH_MS := 500
const ERROR_KINDS: Array[String] = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]

var path := PATH
var _mutex := Mutex.new()
var _file: FileAccess
var _memory: PackedStringArray = []
var _bytes := 0
var _full := false
var _last_flush_ms := 0


func _log_message(message: String, _error: bool) -> void:
	var text := message.strip_edges(false, true)
	if not text.is_empty():
		_write(text if is_stamped(text) else stamp(text), is_stamped(text))


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var text := "%s: %s (%s:%d %s)" % [ERROR_KINDS[clampi(error_type, 0, ERROR_KINDS.size() - 1)],
			rationale if not rationale.is_empty() else code, file, line, function]
	for backtrace in script_backtraces:
		if not backtrace.is_empty():
			text += "\n" + backtrace.format(2, 4).strip_edges(false, true)
	_write(stamp(text), true)


## Starts a new log file (deleting the previous game's), with `header` and the lines
## remembered since start-up.
func begin_game(header: String) -> void:
	_mutex.lock()
	if _file:
		_file.close()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	_bytes = 0
	_full = false
	if _file:
		_store(header)
		for remembered in _memory:
			_store(remembered)
		_memory.clear()
		_file.flush()
		_last_flush_ms = Time.get_ticks_msec()
	_mutex.unlock()


func flush() -> void:
	_mutex.lock()
	if _file:
		_file.flush()
	_mutex.unlock()


func close() -> void:
	_mutex.lock()
	if _file:
		_file.close()
		_file = null
	_mutex.unlock()


static func stamp(text: String) -> String:
	var now := Time.get_time_dict_from_system()
	return "[%02d:%02d:%02d.%03d] %s" % [now.hour, now.minute, now.second, Time.get_ticks_msec() % 1000, text]


## True for lines that already start with "[hh:mm:ss.mmm]" (DiagLog lines).
static func is_stamped(text: String) -> bool:
	return text.length() > 14 and text[0] == "[" and text[3] == ":" and text[6] == ":" and text[13] == "]"


func _write(text: String, flush_now: bool) -> void:
	_mutex.lock()
	if _file == null:
		_memory.append(text)
		if _memory.size() > MEMORY_LINES:
			_memory.remove_at(0)
	elif not _full:
		_store(text)
		var now := Time.get_ticks_msec()
		if _bytes >= MAX_BYTES:
			_file.store_line(stamp("[log] size limit reached, nothing more is written until the next game"))
			_full = true
			_file.flush()
		elif flush_now or now - _last_flush_ms >= FLUSH_MS:
			_file.flush()
			_last_flush_ms = now
	_mutex.unlock()


func _store(text: String) -> void:
	_file.store_line(text)
	_bytes += text.to_utf8_buffer().size() + 1
