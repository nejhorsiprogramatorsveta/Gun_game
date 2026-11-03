class_name Updater
extends Node
## In-game auto-update (PLAN.md I.8): checks version.json on GitHub, downloads the new
## build next to the running game, verifies its SHA-256, swaps it in and restarts.
## Security (PLAN.md section S): only files from this repository's GitHub releases over
## HTTPS are accepted, and nothing is replaced unless the checksum matches; on any
## failure the running version stays untouched.

signal update_available(info: Dictionary)
signal download_progress(fraction: float)
## Translated reason; the menu then offers the manual download page.
signal failed(message: String)

const REPO_URL := "https://github.com/nejhorsiprogramatorsveta/Gun_game"
const DEV_MANIFEST_URL := REPO_URL + "/releases/download/dev/version.json"
const STABLE_MANIFEST_URL := REPO_URL + "/releases/latest/download/version.json"
const ALLOWED_URL_PREFIX := REPO_URL + "/releases/download/"
const DOWNLOADS_PAGE_URL := REPO_URL + "/releases"
const OLD_SUFFIX := ".old"
const DOWNLOAD_NAME := "gun_game.update"
const MAX_MANIFEST_BYTES := 16 * 1024
## rwxr-xr-x (octal 755): the new game binary must stay executable on macOS/Linux.
const EXECUTABLE_PERMISSIONS := 493

var _http := HTTPRequest.new()
## Debug builds only: `-- --update-test=http://127.0.0.1:8000/version.json` checks a local
## manifest (any URL allowed) and installs without asking, for end-to-end testing.
var _test_url := ""
var _info := {}


func _ready() -> void:
	add_child(_http)
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--update-test="):
				_test_url = arg.get_slice("=", 1)


## Only exported builds made by CI can update themselves (not editor/dev runs).
func is_supported() -> bool:
	if not _test_url.is_empty():
		return true
	return not OS.has_feature("editor") and BuildInfo.build > 0


func check() -> void:
	if not is_supported():
		return
	var url := _test_url
	if url.is_empty():
		url = STABLE_MANIFEST_URL if BuildInfo.channel == "stable" else DEV_MANIFEST_URL
	_http.download_file = ""
	_http.body_size_limit = MAX_MANIFEST_BYTES
	_http.request_completed.connect(_on_manifest_received, CONNECT_ONE_SHOT)
	if _http.request(url) != OK:
		_http.request_completed.disconnect(_on_manifest_received)


func _on_manifest_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # offline or no manifest yet: just play the current version
	var info := parse_manifest(body.get_string_from_utf8(), platform_key(), _test_url.is_empty())
	if info.is_empty() or info.build <= BuildInfo.build:
		return
	_info = info
	if _test_url.is_empty():
		update_available.emit(info)
	else:
		download_and_install()


## Returns {version, build, url, sha256} for `platform`, or {} if the manifest is invalid
## or points anywhere else than this repository's releases.
static func parse_manifest(text: String, platform: String, strict_urls: bool = true) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or not data.get("files") is Dictionary:
		return {}
	var file: Variant = data.files.get(platform)
	if not file is Dictionary:
		return {}
	var url := str(file.get("url", ""))
	var sha := str(file.get("sha256", "")).to_lower()
	var build: Variant = data.get("build")
	if not (build is float or build is int) or sha.length() != 64 or not sha.is_valid_hex_number():
		return {}
	if strict_urls and not url.begins_with(ALLOWED_URL_PREFIX):
		return {}
	return {"version": str(data.get("version", "?")), "build": int(build), "url": url, "sha256": sha}


func download_and_install() -> void:
	var target_dir := install_directory()
	if not DirAccess.dir_exists_absolute(target_dir):
		failed.emit(tr("UPDATE_FAILED_INSTALL"))
		return
	var download_path := target_dir.path_join(DOWNLOAD_NAME)
	_http.download_file = download_path
	_http.body_size_limit = -1
	_http.request_completed.connect(_on_download_finished.bind(download_path), CONNECT_ONE_SHOT)
	if _http.request(_info.url) != OK:
		_http.request_completed.disconnect(_on_download_finished)
		failed.emit(tr("UPDATE_FAILED_DOWNLOAD"))
		return
	set_process(true)


func _process(_delta: float) -> void:
	var total := _http.get_body_size()
	if total > 0:
		download_progress.emit(float(_http.get_downloaded_bytes()) / total)


func _on_download_finished(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, download_path: String) -> void:
	set_process(false)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(download_path)
		failed.emit(tr("UPDATE_FAILED_DOWNLOAD"))
		return
	if FileAccess.get_sha256(download_path) != _info.sha256:
		DirAccess.remove_absolute(download_path)
		failed.emit(tr("UPDATE_FAILED_VERIFY"))
		return
	# Remember the path first: after the swap the OS reports the moved-aside old copy
	# as the running executable.
	var target := install_target()
	var error := install(download_path, platform_key(), target)
	DirAccess.remove_absolute(download_path)
	if error != OK:
		failed.emit(tr("UPDATE_FAILED_INSTALL"))
		return
	_restart(target)


# --- Installing (static, so it can be tested on temporary folders) ----------------

static func platform_key() -> String:
	match OS.get_name():
		"Windows": return "windows"
		"macOS": return "macos"
		_: return "linux"


## The running game: the .exe/binary, or the .app bundle on macOS.
static func install_target() -> String:
	var executable := OS.get_executable_path()
	if platform_key() == "macos":
		return executable.get_base_dir().get_base_dir().get_base_dir()  # .../X.app
	return executable


static func install_directory() -> String:
	return install_target().get_base_dir()


static func install(download_path: String, platform: String, target: String = install_target()) -> Error:
	match platform:
		"windows":
			return replace_file(download_path, target)
		"linux":
			var binary := download_path + ".bin"
			var error := extract_single_file(download_path, target.get_file(), binary)
			if error == OK:
				error = replace_file(binary, target)
			DirAccess.remove_absolute(binary)
			return error
		_:
			return replace_macos_app(download_path, target)


## Swaps `new_file` into `target`. A running executable cannot be overwritten, but it can
## be renamed, so the old one is moved aside and deleted on the next start.
static func replace_file(new_file: String, target: String) -> Error:
	var old := target + OLD_SUFFIX
	DirAccess.remove_absolute(old)
	var error := DirAccess.rename_absolute(target, old)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(new_file, target)
	if error != OK:
		DirAccess.rename_absolute(old, target)  # put the working version back
		return error
	FileAccess.set_unix_permissions(target, EXECUTABLE_PERMISSIONS)
	return OK


static func extract_single_file(zip_path: String, file_name: String, destination: String) -> Error:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return ERR_FILE_CANT_OPEN
	var error := ERR_FILE_NOT_FOUND
	for entry in zip.get_files():
		if entry.get_file() == file_name:
			var out := FileAccess.open(destination, FileAccess.WRITE)
			if out:
				out.store_buffer(zip.read_file(entry))
				out.close()
				error = OK
			else:
				error = ERR_FILE_CANT_WRITE
	zip.close()
	return error


## Unpacks the new .app next to the running one, then swaps the bundles.
static func replace_macos_app(zip_path: String, app_path: String) -> Error:
	var staging := app_path.get_base_dir().path_join("gun_game.update.staging")
	remove_tree(staging)
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return ERR_FILE_CANT_OPEN
	var new_app := ""
	for entry in zip.get_files():
		# Never write outside the staging folder, whatever the archive contains.
		if entry.contains("..") or entry.begins_with("/"):
			continue
		var path := staging.path_join(entry)
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(path)
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var out := FileAccess.open(path, FileAccess.WRITE)
		if out == null:
			zip.close()
			remove_tree(staging)
			return ERR_FILE_CANT_WRITE
		out.store_buffer(zip.read_file(entry))
		out.close()
		if entry.contains(".app/Contents/MacOS/"):
			FileAccess.set_unix_permissions(path, EXECUTABLE_PERMISSIONS)
		if new_app.is_empty() and entry.contains(".app/"):
			new_app = staging.path_join(entry.substr(0, entry.find(".app/") + 4))
	zip.close()
	var error := ERR_FILE_NOT_FOUND
	if not new_app.is_empty():
		error = replace_file(new_app, app_path)
	remove_tree(staging)
	return error


## Removes leftovers of a previous update: the old version moved aside, and a partial
## download or staging folder if the game was closed during an update.
static func cleanup_old_files() -> void:
	var directory := install_directory()
	for leftover in [install_target() + OLD_SUFFIX, directory.path_join(DOWNLOAD_NAME),
			directory.path_join(DOWNLOAD_NAME + ".bin"), directory.path_join("gun_game.update.staging")]:
		remove_tree(leftover)


static func remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.remove_absolute(path)
		return
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for dir in DirAccess.get_directories_at(path):
		remove_tree(path.path_join(dir))
	DirAccess.remove_absolute(path)


func _restart(target: String) -> void:
	if platform_key() == "macos":
		OS.create_process("open", ["-n", target])
	else:
		OS.create_process(target, [])
	get_tree().quit()
