class_name Changelog
## The menu and release notes share the same bundled history and translated changes.

const DATA: ChangelogData = preload("res://data/changelog.tres")


static func history() -> Array[Dictionary]:
	var newest_archived_build := 0
	for entry in DATA.entries:
		newest_archived_build = maxi(newest_archived_build, entry.build)
	var result: Array[Dictionary] = []
	for entry in DATA.entries:
		var entry_build: int = entry.build
		if BuildInfo.build > 0:
			if entry_build > BuildInfo.build or (entry_build == 0 and BuildInfo.build <= newest_archived_build):
				continue
		var heading := BuildInfo.display_string()
		if entry_build > 0 and entry_build != BuildInfo.build:
			heading = TranslationServer.translate("BUILD_DISPLAY").format({"version": entry.version, "build": entry_build})
		var changes: PackedStringArray = []
		for key: String in entry.change_keys:
			changes.append(TranslationServer.translate(key))
		result.append({"heading": heading, "changes": changes, "build": BuildInfo.build if entry_build == 0 else entry_build})
	return result


## The menu shows only the newest version (user decision 2026-11-04); empty if none applies.
static func latest() -> Dictionary:
	var entries := history()
	return entries[0] if not entries.is_empty() else {}


static func format_entry(entry: Dictionary) -> String:
	var lines: PackedStringArray = [entry.heading]
	for change: String in entry.changes:
		lines.append("• " + change)
	return "\n".join(lines)


static func release_changes() -> PackedStringArray:
	var entry := latest()
	return entry.changes if not entry.is_empty() else PackedStringArray()


static func release_notes(game_name: String, repository_url: String) -> String:
	var lines: PackedStringArray = [TranslationServer.translate("RELEASE_VERSION").format({"version": BuildInfo.display_string()}),
			"", "### " + TranslationServer.translate("CHANGELOG_TITLE")]
	for change in release_changes():
		lines.append("- " + change)
	lines.append_array(["", "### " + TranslationServer.translate("RELEASE_DOWNLOADS"),
			TranslationServer.translate("RELEASE_WINDOWS").format({"file": game_name + "-windows.exe"}),
			TranslationServer.translate("RELEASE_MACOS").format({"file": game_name + "-macos.zip"}),
			TranslationServer.translate("RELEASE_LINUX").format({"file": game_name + "-linux.zip"}),
			"", TranslationServer.translate("RELEASE_SOURCE_NOTICE"),
			TranslationServer.translate("RELEASE_SOURCE_COMMIT").format({"url": repository_url + "/tree/" + BuildInfo.commit}), "",
			TranslationServer.translate("RELEASE_GUIDE").format({"url": repository_url + "#readme"})])
	return "\n".join(lines) + "\n"
