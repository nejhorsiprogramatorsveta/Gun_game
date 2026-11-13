extends TestCase

const DATA_PATH := "res://data/changelog.tres"


func _set_build(version: String, build: int, commit: String = "test123") -> Dictionary:
	var saved := {"version": BuildInfo.version, "build": BuildInfo.build,
			"commit": BuildInfo.commit, "channel": BuildInfo.channel}
	BuildInfo.version = version
	BuildInfo.build = build
	BuildInfo.commit = commit
	return saved


func _restore_build(saved: Dictionary) -> void:
	BuildInfo.version = saved.version
	BuildInfo.build = saved.build
	BuildInfo.commit = saved.commit
	BuildInfo.channel = saved.channel


func _builds(history: Array[Dictionary]) -> Array[int]:
	var builds: Array[int] = []
	for entry in history:
		builds.append(entry.build)
	return builds


func _archived_builds() -> Array[int]:
	var data: ChangelogData = load(DATA_PATH)
	var builds: Array[int] = []
	for entry in data.entries:
		if entry.build > 0:
			builds.append(entry.build)
	return builds


func _current_build() -> int:
	var newest := 0
	for build in _archived_builds():
		newest = maxi(newest, build)
	return newest + 10


func test_current_entry_uses_installed_version_and_build() -> void:
	var current_build := _current_build()
	var saved := _set_build("9.8.7", current_build)
	var history := Changelog.history()
	var expected: Array[int] = [current_build]
	expected.append_array(_archived_builds())
	check_eq(_builds(history), expected, "current installed build precedes archived builds")
	if not history.is_empty():
		check(history[0].heading.contains(BuildInfo.display_string()), "current heading uses the same Czech version and build as the menu")
		check(history[0].heading.contains("sestavení %d" % current_build), "build header is translated into Czech")
	check_eq(history.size(), expected.size(), "different installed version does not hide archived history")
	_restore_build(saved)


func test_editor_entry_uses_development_identity() -> void:
	var saved := _set_build("0.9.0", 0, "localabc")
	var history := Changelog.history()
	var expected: Array[int] = [0]
	expected.append_array(_archived_builds())
	check_eq(_builds(history), expected, "editor shows current entry and all archived history")
	if not history.is_empty():
		check(history[0].heading.contains(BuildInfo.display_string()), "editor heading uses the menu's development identity")
		check(history[0].heading.contains("localabc"), "editor heading preserves the local commit identity")
	_restore_build(saved)


func test_older_builds_hide_future_and_current_entries() -> void:
	var saved := _set_build("0.0.0", 0)
	var archives := _archived_builds()
	for installed_build in archives:
		BuildInfo.build = installed_build
		var history := Changelog.history()
		var expected: Array[int] = []
		for archived_build in archives:
			if archived_build <= installed_build:
				expected.append(archived_build)
		check_eq(_builds(history), expected, "installed archived build hides the current placeholder and future archives")
		if not history.is_empty():
			check(history[0].heading.contains(str(installed_build)), "archived heading identifies its build")
	_restore_build(saved)


func test_release_changes_match_the_recent_menu_entries() -> void:
	var saved := _set_build("9.8.7", _current_build())
	var builds: Array[int] = [_current_build(), 0]
	builds.append_array(_archived_builds())
	for build in builds:
		BuildInfo.build = build
		var history := Changelog.history()
		check(not history.is_empty(), "installed build has a latest changelog entry")
		if not history.is_empty():
			var expected: PackedStringArray = []
			for entry in history.slice(0, Changelog.RECENT_COUNT):
				expected.append_array(entry.changes)
			check_eq(Changelog.release_changes(), expected, "release notes use exactly the recent menu changes")
			for change: String in Changelog.release_changes():
				check(not change.strip_edges().is_empty(), "release changes contain readable text")
	_restore_build(saved)


func test_menu_shows_the_three_newest_versions() -> void:
	var saved := _set_build("9.8.7", _current_build())
	check_eq(Changelog.RECENT_COUNT, 3, "the last 3 updates (user 2026-11-14)")
	var recent := Changelog.recent()
	check_eq(recent, Changelog.history().slice(0, 3), "the menu shows the three newest history entries")
	check_eq(recent[0].build, _current_build(), "newest entry belongs to the installed build")
	var text := Changelog.format_recent()
	for entry in recent:
		check(text.contains(entry.heading), "each recent version has its heading: " + entry.heading)
	check(not text.contains(Changelog.history()[3].heading), "the fourth newest version is not shown")
	BuildInfo.build = 1
	check(Changelog.latest().is_empty() and Changelog.format_recent().is_empty(), "build before any recorded history has no entry")
	_restore_build(saved)


func test_build_before_recorded_history_has_no_release_changes() -> void:
	var oldest := _current_build()
	for build in _archived_builds():
		oldest = mini(oldest, build)
	if oldest <= 1:
		return  # Build 0 identifies an editor run, not an earlier published build.
	var saved := _set_build("0.0.0", oldest - 1)
	check(Changelog.history().is_empty(), "unrecorded old builds do not inherit future history")
	check_eq(Changelog.release_changes(), PackedStringArray(), "empty history produces no release changes")
	_restore_build(saved)


func test_data_has_ordered_unique_builds_and_complete_translations() -> void:
	var data: ChangelogData = load(DATA_PATH)
	check(data.entries.size() > 1, "current changes and archived history are recorded")
	var seen: Dictionary[int, bool] = {}
	var previous_build := _current_build()
	for index in data.entries.size():
		var entry := data.entries[index]
		var build: int = entry.build
		check(not seen.has(build), "each build has one changelog entry")
		seen[build] = true
		if index == 0:
			check_eq(build, 0, "current-build placeholder is first")
		else:
			check(build > 0 and build < previous_build, "archived builds are positive and newest first")
			check(not str(entry.version).is_empty(), "archived build has its version")
			previous_build = build
		var keys := Changelog.entry_keys(entry)
		check(not keys.is_empty(), "each entry describes at least one change")
		var seen_keys: Dictionary[String, bool] = {}
		for key in keys:
			check(not seen_keys.has(key), "an entry does not repeat the same change")
			seen_keys[key] = true
			var translated := TranslationServer.translate(key)
			check(not translated.strip_edges().is_empty() and translated != key, "changelog key has Czech text: " + key)
	check_eq(seen.size(), data.entries.size(), "all build identifiers are distinct")


func test_reading_and_editing_history_does_not_mutate_source_data() -> void:
	var saved := _set_build("9.8.7", _current_build())
	var data: ChangelogData = load(DATA_PATH)
	var original := data.entries.duplicate(true)
	var history := Changelog.history()
	if not history.is_empty():
		var original_heading: String = history[0].heading
		var original_changes: PackedStringArray = history[0].changes.duplicate()
		history[0].heading = "caller mutation"
		var changes: PackedStringArray = history[0].changes
		changes.append("caller mutation")
		history[0].changes = changes
		var fresh := Changelog.history()
		check_eq(fresh[0].heading, original_heading, "caller edits cannot change future headings")
		check_eq(fresh[0].changes, original_changes, "caller edits cannot change future bullets")
	BuildInfo.version = "1.2.3"
	BuildInfo.build += 1
	Changelog.history()
	Changelog.release_changes()
	check_eq(data.entries, original, "resolving current build and translating text leave the shared resource unchanged")
	_restore_build(saved)


func test_release_notes_use_current_metadata_and_only_recent_changes() -> void:
	var saved := _set_build("9.8.7", _current_build())
	var notes := Changelog.release_notes("gun_game", "https://example.test/repo")
	var history := Changelog.history()
	check(notes.contains(BuildInfo.display_string()), "release notes identify the actual installed version and build")
	var bullets: PackedStringArray = []
	for line in notes.split("\n"):
		if line.begins_with("- ") and not line.begins_with("- **"):
			bullets.append(line.trim_prefix("- "))
	check_eq(bullets, Changelog.release_changes(), "release notes contain exactly the latest menu's changelog bullets")
	if not history.is_empty():
		var recent_changes := Changelog.release_changes()
		for index in range(Changelog.RECENT_COUNT, history.size()):
			for change: String in history[index].changes:
				if not recent_changes.has(change):
					check(not notes.contains("- " + change + "\n"), "release notes omit older changelog bullets")
		for entry in Changelog.recent():
			check(notes.contains("#### " + entry.heading), "each recent version has its heading in the notes")
	for file_name in ["gun_game-windows.exe", "gun_game-macos.zip", "gun_game-linux.zip"]:
		check(notes.contains(file_name), "release notes preserve the download filename: " + file_name)
	check(notes.contains("https://example.test/repo#readme"), "release notes use the supplied repository guide link")
	check(notes.contains("https://example.test/repo/tree/test123"), "release notes link to this build's actual source commit instead of the fixed release tag")
	_restore_build(saved)


func test_sections_group_changes_in_display_order() -> void:
	var saved := _set_build("9.8.7", _current_build())
	var latest := Changelog.latest()
	var flat: PackedStringArray = []
	var titles: PackedStringArray = []
	for section: Dictionary in latest.sections:
		check(not section.changes.is_empty(), "empty sections are left out")
		titles.append(section.title)
		flat.append_array(section.changes)
	check_eq(flat, latest.changes, "sections contain exactly the entry's changes in order")
	var order := [tr("CHANGELOG_SECTION_BALANCE"), tr("CHANGELOG_SECTION_NEW"), tr("CHANGELOG_SECTION_OTHER")]
	var last := -1
	for title in titles:
		check(order.find(title) > last, "sections keep the order balance, new, other")
		last = order.find(title)
	var archived := Changelog.history()[1]
	check_eq(archived.sections.map(func(section: Dictionary) -> String: return section.title), order,
			"0.2.17 is split into balance, new and other (user 2026-11-14)")
	var text := Changelog.format_entry(latest)
	for title in titles:
		check(text.contains("\n" + title + "\n• "), "menu text has the section title above its bullets: " + title)
	_restore_build(saved)


func test_format_entry_keeps_heading_and_each_change_on_its_own_line() -> void:
	var entry := {"heading": "0.1.0 (sestavení 28)", "build": 28,
			"changes": PackedStringArray(["Silnější odhození.", "Skóre hráčů."])}
	check_eq(Changelog.format_entry(entry), "0.1.0 (sestavení 28)\n• Silnější odhození.\n• Skóre hráčů.", "plain changelog text preserves the localized heading and bullets")
