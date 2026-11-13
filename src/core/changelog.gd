class_name Changelog
## The menu and release notes share the same bundled history and translated changes.

const DATA: ChangelogData = preload("res://data/changelog.tres")
## Sections of one version, in display order: [title key, data fields] (user 2026-11-14:
## "balance changes, new and other"). Older entries use "change_keys" / "mechanics_keys"
## (shown as new) and "fix_keys" (shown under other).
const SECTIONS := [
	["CHANGELOG_SECTION_BALANCE", ["balance_keys"]],
	["CHANGELOG_SECTION_NEW", ["change_keys", "new_keys", "mechanics_keys"]],
	["CHANGELOG_SECTION_OTHER", ["fix_keys", "other_keys"]],
]
## "Co je nového" and the release notes show this many newest updates (user 2026-11-14;
## before: only the newest).
const RECENT_COUNT := 3


## All change keys of a data entry, in display order.
static func entry_keys(entry: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = []
	for section in SECTIONS:
		for field: String in section[1]:
			keys.append_array(entry.get(field, PackedStringArray()))
	return keys


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
		var sections: Array[Dictionary] = []
		for section in SECTIONS:
			var texts: PackedStringArray = []
			for field: String in section[1]:
				for key: String in entry.get(field, PackedStringArray()):
					texts.append(TranslationServer.translate(key))
			if not texts.is_empty():
				sections.append({"title": TranslationServer.translate(section[0]), "changes": texts})
				changes.append_array(texts)
		result.append({"heading": heading, "changes": changes, "sections": sections,
				"build": BuildInfo.build if entry_build == 0 else entry_build})
	return result


## The newest version for the installed build; empty if none applies.
static func latest() -> Dictionary:
	var entries := history()
	return entries[0] if not entries.is_empty() else {}


## The RECENT_COUNT newest versions for the installed build (menu and release notes).
static func recent() -> Array[Dictionary]:
	return history().slice(0, RECENT_COUNT)


## The menu text: the recent versions one after another (empty if none applies).
static func format_recent() -> String:
	var parts: PackedStringArray = []
	for entry in recent():
		parts.append(format_entry(entry))
	return "\n\n\n".join(parts)


## Heading, then each non-empty section (title and bullets); entries without sections
## list their changes directly.
static func format_entry(entry: Dictionary) -> String:
	var lines: PackedStringArray = [entry.heading]
	var sections: Array = entry.get("sections", [])
	if sections.is_empty():
		sections = [{"title": "", "changes": entry.changes}]
	for section: Dictionary in sections:
		if not str(section.title).is_empty():
			lines.append_array(["", str(section.title)])
		for change: String in section.changes:
			lines.append("• " + change)
	return "\n".join(lines)


## Every bullet of the recent versions, newest first (what the release notes list).
static func release_changes() -> PackedStringArray:
	var changes: PackedStringArray = []
	for entry in recent():
		changes.append_array(entry.changes)
	return changes


static func release_notes(game_name: String, repository_url: String) -> String:
	var lines: PackedStringArray = [TranslationServer.translate("RELEASE_VERSION").format({"version": BuildInfo.display_string()}),
			"", "### " + TranslationServer.translate("CHANGELOG_TITLE")]
	for entry in recent():
		lines.append_array(["", "#### " + str(entry.heading)])
		for section: Dictionary in entry.get("sections", []):
			lines.append_array(["", "**" + str(section.title) + "**"])
			for change: String in section.changes:
				lines.append("- " + change)
	lines.append_array(["", "### " + TranslationServer.translate("RELEASE_DOWNLOADS"),
			TranslationServer.translate("RELEASE_WINDOWS").format({"file": game_name + "-windows.exe"}),
			TranslationServer.translate("RELEASE_MACOS").format({"file": game_name + "-macos.zip"}),
			TranslationServer.translate("RELEASE_LINUX").format({"file": game_name + "-linux.zip"}),
			"", TranslationServer.translate("RELEASE_SOURCE_NOTICE"),
			TranslationServer.translate("RELEASE_SOURCE_COMMIT").format({"url": repository_url + "/tree/" + BuildInfo.commit}), "",
			TranslationServer.translate("RELEASE_GUIDE").format({"url": repository_url + "#readme"})])
	return "\n".join(lines) + "\n"
