class_name Updater
extends Node
## OVER-THE-AIR UPDATES from GitHub Releases. The main menu starts one of these.
##
## The game is exported as SeedSplicer.exe (the Godot engine) + SeedSplicer.pck (everything we make:
## scripts, scenes, art, data). An update is a new .pck published as a GitHub Release on
## GameVersion.RELEASES_REPO, tagged v<version>, with two files: SeedSplicer-<version>.pck and
## SeedSplicer-<version>.pck.sha256 (tools/publish_update.py makes both).
##
## 1. A pack downloaded earlier that is newer than this one? Restart into it right away.
## 2. Otherwise ask GitHub for the latest release. If it's newer, download the .pck and its .sha256
##    into user://updates/, check the hash, then restart into it with --main-pack: the whole game,
##    autoloads included, then runs from the new pack.
## Offline, GitHub down, no release yet, a bad hash: the game just starts as it is.
## Never runs in the editor (or the editor binary running tests), or with --no-update.

signal status_changed(text: String)

const UPDATES_DIR := "user://updates"
const PACK_PREFIX := "SeedSplicer-"
const TIMEOUT := 8.0

var _http: HTTPRequest


## Should this run check for updates? Only exported games, and not with --no-update.
static func enabled() -> bool:
	return not OS.has_feature("editor") and not "--no-update" in OS.get_cmdline_user_args() \
		and not "--no-update" in OS.get_cmdline_args()


func _ready() -> void:
	var waiting := newest_downloaded()
	if waiting != "":
		_restart_into(waiting)
		return
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_release)
	status_changed.emit("Checking for updates...")
	var url := "https://api.github.com/repos/%s/releases/latest" % GameVersion.RELEASES_REPO
	if _http.request(url, ["User-Agent: SeedSplicer", "Accept: application/vnd.github+json"]) != OK:
		_done("")


## The newest pack in user://updates that is newer than the running game and still matches its
## saved hash, or "".
static func newest_downloaded() -> String:
	var best := ""
	var best_version := GameVersion.VERSION
	DirAccess.make_dir_recursive_absolute(UPDATES_DIR)
	for file in DirAccess.get_files_at(UPDATES_DIR):
		if not (file.begins_with(PACK_PREFIX) and file.ends_with(".pck")):
			continue
		var version := file.trim_prefix(PACK_PREFIX).trim_suffix(".pck")
		var path := UPDATES_DIR.path_join(file)
		if GameVersion.is_newer(version, best_version) and _hash_ok(path, _read_text(path + ".sha256")):
			best = path
			best_version = version
	return best


func _on_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_done("")  # offline, no releases yet, or the repo can't be read: play this version
		return
	var release: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not release is Dictionary:
		_done("")
		return
	var version := str(release.get("tag_name", "")).trim_prefix("v")
	if not GameVersion.is_newer(version, GameVersion.VERSION):
		_done("Up to date (v%s)" % GameVersion.VERSION)
		return
	var pack_url := ""
	var hash_url := ""
	for asset in release.get("assets", []):
		var name := str(asset.get("name", ""))
		if name == PACK_PREFIX + version + ".pck":
			pack_url = str(asset.get("browser_download_url", ""))
		elif name == PACK_PREFIX + version + ".pck.sha256":
			hash_url = str(asset.get("browser_download_url", ""))
	if pack_url == "" or hash_url == "":
		_done("")  # a release without its pack or hash: never install it
		return
	DirAccess.make_dir_recursive_absolute(UPDATES_DIR)
	var pack := UPDATES_DIR.path_join(PACK_PREFIX + version + ".pck")
	status_changed.emit("Downloading update v%s..." % version)
	var hash_text := await _download_text(hash_url)
	if hash_text == "" or not await _download_file(pack_url, pack):
		_done("Update download failed - playing v%s" % GameVersion.VERSION)
		return
	if not _hash_ok(pack, hash_text):
		DirAccess.remove_absolute(pack)
		_done("Update failed its safety check - playing v%s" % GameVersion.VERSION)
		return
	var f := FileAccess.open(pack + ".sha256", FileAccess.WRITE)
	f.store_string(hash_text)
	f.close()
	_restart_into(pack)


func _download_text(url: String) -> String:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	if http.request(url, ["User-Agent: SeedSplicer"]) != OK:
		http.queue_free()
		return ""
	var r: Array = await http.request_completed
	http.queue_free()
	return (r[3] as PackedByteArray).get_string_from_utf8() if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200 else ""


func _download_file(url: String, path: String) -> bool:
	var http := HTTPRequest.new()
	http.download_file = path
	add_child(http)
	if http.request(url, ["User-Agent: SeedSplicer"]) != OK:
		http.queue_free()
		return false
	var r: Array = await http.request_completed
	http.queue_free()
	return r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200


## The file's SHA-256 matches the first word of `hash_text` (the .sha256 file's format).
static func _hash_ok(path: String, hash_text: String) -> bool:
	var want := hash_text.strip_edges().split(" ", false)
	return not want.is_empty() and FileAccess.file_exists(path) \
		and FileAccess.get_sha256(path).to_lower() == want[0].to_lower()


static func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _restart_into(pack: String) -> void:
	status_changed.emit("Starting the new version...")
	OS.create_process(OS.get_executable_path(), ["--main-pack", ProjectSettings.globalize_path(pack)])
	get_tree().quit()


func _done(text: String) -> void:
	status_changed.emit(text)
	queue_free()
