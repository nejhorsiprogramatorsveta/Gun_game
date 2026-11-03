extends SceneTree
## Fails (exit code 1) when a localization key used in the project has no Czech text:
##   tools/godot --headless --path . -s tools/check_localization.gd
## A key is any quoted UPPER_SNAKE_CASE string (e.g. "MENU_PLAY") in .gd/.tscn/.tres files.
## Unused keys in the CSV are only reported as warnings.

const CSV_PATH := "res://localization/translations.csv"
const SCAN_DIRS: PackedStringArray = ["res://src", "res://data"]
const SCAN_EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]
const LANGUAGE_COLUMN := "cs"


func _initialize() -> void:
	var texts := _load_texts()
	var key_regex := RegEx.create_from_string("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	var used := {}
	var missing: PackedStringArray = []
	for path in _collect_files():
		for found in key_regex.search_all(FileAccess.get_file_as_string(path)):
			var key := found.get_string(1)
			used[key] = true
			if texts.get(key, "").is_empty():
				missing.append("%s (in %s)" % [key, path])

	for key: String in texts:
		if not used.has(key):
			print("WARNING unused key: ", key)
	for entry in missing:
		printerr("MISSING ", entry)
	print("Localization: %d keys used, %d missing" % [used.size(), missing.size()])
	quit(1 if missing.size() > 0 else 0)


func _load_texts() -> Dictionary:
	var texts := {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	var header := file.get_csv_line()
	var column := header.find(LANGUAGE_COLUMN)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > column and not row[0].is_empty():
			texts[row[0]] = row[column].strip_edges()
	return texts


func _collect_files() -> PackedStringArray:
	var files: PackedStringArray = []
	var pending: PackedStringArray = SCAN_DIRS.duplicate()
	while not pending.is_empty():
		var dir := pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		for sub in DirAccess.get_directories_at(dir):
			pending.append(dir.path_join(sub))
		for file_name in DirAccess.get_files_at(dir):
			if file_name.get_extension() in SCAN_EXTENSIONS:
				files.append(dir.path_join(file_name))
	return files
