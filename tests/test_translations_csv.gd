extends TestCase
## An unquoted comma silently cuts a Czech text short, so every row must have exactly
## two columns (key, cs).


func test_every_row_has_key_and_one_translation() -> void:
	var file := FileAccess.open("res://localization/translations.csv", FileAccess.READ)
	check(file != null, "translations.csv is readable")
	if file == null:
		return
	var line_number := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		line_number += 1
		if row.size() == 1 and row[0].is_empty():
			continue  # trailing empty line
		check_eq(row.size(), 2, "line %d has key + text (quote texts containing commas)" % line_number)
