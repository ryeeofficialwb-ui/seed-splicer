extends Node
## Autoload "Online": accounts and seed submissions on Supabase (see supabase/setup.sql).
##
## Players log in with a USERNAME and a PASSWORD. Supabase Auth wants an email, so the game turns
## the username into one that is never mailed (<username>@<email_domain>, see data/supabase.json);
## "Confirm email" must be off in the Supabase dashboard. The password goes straight to Supabase
## (HTTPS) and is never written anywhere by the game. Only the session's refresh token is kept, in
## user://online_session.json, so you stay logged in.
##
## Everything is async:  var r := await Online.log_in("Bob", "secret")   # r = { ok, error, ... }
##
## data/supabase.json holds the project URL and its PUBLISHABLE (anon) key. That key is meant to be
## public: what anyone can do with it is decided by the row level security in setup.sql.

signal session_changed

const CONFIG := "res://data/supabase.json"
const SESSION_FILE := "user://online_session.json"
const TIMEOUT := 15.0

var url := ""
var key := ""
var email_domain := "players.seedsplicer.invalid"
var username := ""
var user_id := ""
var is_admin := false
var _access := ""
var _refresh := ""
var _expires := 0  # unix time


func _ready() -> void:
	if FileAccess.file_exists(CONFIG):
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		if c is Dictionary:
			url = String(c.get("url", "")).strip_edges().trim_suffix("/")
			key = String(c.get("key", "")).strip_edges()
			email_domain = String(c.get("email_domain", email_domain))
	if configured() and not "--selftest" in OS.get_cmdline_user_args():
		_resume.call_deferred()


func configured() -> bool:
	return url.begins_with("https://") and key != ""


func logged_in() -> bool:
	return _access != ""


## Usernames: 3-20 letters, digits or _ (the database checks the same).
static func username_problem(u: String) -> String:
	if not RegEx.create_from_string("^[A-Za-z0-9_]{3,20}$").search(u):
		return "3 to 20 letters, numbers or _ (no spaces)."
	if DevMode.is_reserved(u) and not DevMode.on():
		return "That username is taken."
	return ""


func _email(u: String) -> String:
	return "%s@%s" % [u.to_lower(), email_domain]


# --- accounts ------------------------------------------------------------------------------------

## 'ok', 'invalid', 'taken' or 'offline'.
func username_status(u: String) -> String:
	var r := await _call("POST", "/rest/v1/rpc/username_status", { "u": u }, false)
	return String(r.data) if r.ok and typeof(r.data) == TYPE_STRING else "offline"


func sign_up(u: String, password: String) -> Dictionary:
	u = u.strip_edges()
	var problem := username_problem(u)
	if problem != "":
		return { "ok": false, "error": problem }
	if password.length() < 8:
		return { "ok": false, "error": "Use a password of at least 8 characters." }
	var st := await username_status(u)
	if st == "taken":
		return { "ok": false, "error": "That username is taken." }
	if st == "invalid":
		return { "ok": false, "error": "3 to 20 letters, numbers or _ (no spaces)." }
	if st == "offline":
		return { "ok": false, "error": "Can't reach the server. Check your internet connection." }
	var r := await _call("POST", "/auth/v1/signup", { "email": _email(u), "password": password, "data": { "username": u } }, false)
	if not r.ok:
		return { "ok": false, "error": _auth_error(r) }
	if not (r.data is Dictionary and r.data.has("access_token")):
		return { "ok": false, "error": "The server wants an email confirmation: turn off \"Confirm email\" in Supabase." }
	await _take_session(r.data)
	return { "ok": true, "error": "" }


func log_in(u: String, password: String) -> Dictionary:
	u = u.strip_edges()
	var r := await _call("POST", "/auth/v1/token?grant_type=password", { "email": _email(u), "password": password }, false)
	if not r.ok:
		return { "ok": false, "error": _auth_error(r) }
	await _take_session(r.data)
	return { "ok": true, "error": "" }


func log_out() -> void:
	if logged_in():
		await _call("POST", "/auth/v1/logout", {}, true)
	_access = ""
	_refresh = ""
	username = ""
	user_id = ""
	is_admin = false
	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(SESSION_FILE)
	session_changed.emit()


func _auth_error(r: Dictionary) -> String:
	if r.code == 0:
		return "Can't reach the server. Check your internet connection."
	var msg := ""
	if r.data is Dictionary:
		msg = String(r.data.get("msg", r.data.get("error_description", r.data.get("message", ""))))
	if msg.to_lower().contains("invalid login"):
		return "Wrong username or password."
	if msg.to_lower().contains("already registered"):
		return "That username is taken."
	if msg.to_lower().contains("database error"):
		return "That username can't be used."
	return msg if msg != "" else "The server said no (%d)." % r.code


func _take_session(d: Dictionary) -> void:
	_access = String(d.get("access_token", ""))
	_refresh = String(d.get("refresh_token", ""))
	_expires = int(Time.get_unix_time_from_system()) + int(d.get("expires_in", 3600))
	var user: Dictionary = d.get("user", {})
	user_id = String(user.get("id", ""))
	username = String(user.get("user_metadata", {}).get("username", ""))
	var f := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({ "refresh_token": _refresh }))
		f.close()
	var adm := await _call("POST", "/rest/v1/rpc/is_admin", {}, true)
	is_admin = adm.ok and adm.data == true
	if username != "":
		Game.set_player_name(username)  # your seeds are signed with your account name
	session_changed.emit()


## Start of the game: log back in with the saved refresh token (never a saved password).
func _resume() -> void:
	if not FileAccess.file_exists(SESSION_FILE):
		return
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION_FILE))
	if not saved is Dictionary or String(saved.get("refresh_token", "")) == "":
		return
	_refresh = saved.refresh_token
	await _renew()


func _renew() -> bool:
	if _refresh == "":
		return false
	var r := await _call("POST", "/auth/v1/token?grant_type=refresh_token", { "refresh_token": _refresh }, false)
	if not r.ok:
		if r.code >= 400 and r.code < 500:  # the session ended: log out
			_access = ""
			_refresh = ""
			if FileAccess.file_exists(SESSION_FILE):
				DirAccess.remove_absolute(SESSION_FILE)
			session_changed.emit()
		return false
	await _take_session(r.data)
	return true


# --- submissions -------------------------------------------------------------------------------------

## Uploads seeds of yours (ids). Each becomes one pending submission. Returns { ok, error, sent }.
func upload(ids: Array) -> Dictionary:
	if not logged_in():
		return { "ok": false, "error": "Log in first.", "sent": 0 }
	var rows: Array = []
	for id in ids:
		rows.append({ "seed_name": String(Game.seeds[id].name), "payload": Game.submission_payload(id) })
	var r := await _call("POST", "/rest/v1/submissions", rows, true, ["Prefer: return=minimal"])
	if not r.ok:
		var msg := String(r.data.get("message", "")) if r.data is Dictionary else ""
		if msg.contains("ALREADY_PENDING"):
			return { "ok": false, "error": "One of these is already waiting for review.", "sent": 0 }
		if msg.contains("TOO_MANY_PENDING"):
			return { "ok": false, "error": "You have 100 seeds waiting for review: wait for some to be reviewed.", "sent": 0 }
		return { "ok": false, "error": msg if msg != "" else "Upload failed (%d)." % r.code, "sent": 0 }
	return { "ok": true, "error": "", "sent": rows.size() }


## Your own submissions, newest first: [{ id, seed_name, status, note, created_at }]
func my_submissions() -> Array:
	var r := await _call("GET", "/rest/v1/submissions?select=id,seed_name,status,note,created_at&user_id=eq.%s&order=created_at.desc" % user_id, null, true)
	return r.data if r.ok and r.data is Array else []


## Developer: submissions waiting for review, oldest first, with the player's username.
func pending_submissions() -> Array:
	var r := await _call("GET", "/rest/v1/submissions?select=id,seed_name,payload,status,created_at,profiles(username)&status=eq.pending&order=created_at.asc", null, true)
	return r.data if r.ok and r.data is Array else []


## Developer: every denied submission (to keep your graveyard in step with the server).
func denied_submissions() -> Array:
	var r := await _call("GET", "/rest/v1/submissions?select=id,seed_name,payload,profiles(username)&status=eq.denied&order=reviewed_at.asc", null, true)
	return r.data if r.ok and r.data is Array else []


## The live official list's version on the server (-1 if it can't be read).
func official_version() -> int:
	var r := await _call("GET", "/rest/v1/official?select=version&id=eq.1", null, logged_in())
	return int(r.data[0].version) if r.ok and r.data is Array and not r.data.is_empty() else -1


## The live official list: { version, data } or {}.
func fetch_official() -> Dictionary:
	var r := await _call("GET", "/rest/v1/official?select=version,data&id=eq.1", null, logged_in())
	return r.data[0] if r.ok and r.data is Array and not r.data.is_empty() else {}


## Developer: push the official list to every player. Returns the new version (-1 = failed).
func push_official(payload: Dictionary) -> int:
	var v := await official_version()
	if v < 0:
		return -1
	var r := await _call("PATCH", "/rest/v1/official?id=eq.1",
		{ "version": v + 1, "data": payload, "published_at": Time.get_datetime_string_from_system(true), "published_by": user_id },
		true, ["Prefer: return=representation"])
	return v + 1 if r.ok and r.data is Array and not r.data.is_empty() else -1


## Developer: how many submissions wait for review (0 for players).
func pending_count() -> int:
	var r := await _call("POST", "/rest/v1/rpc/pending_count", {}, true)
	return int(r.data) if r.ok and r.data != null else 0


## Developer: approve or deny one submission.
func review(id: int, status: String, note := "") -> bool:
	var r := await _call("PATCH", "/rest/v1/submissions?id=eq.%d" % id,
		{ "status": status, "note": note.left(300), "reviewed_at": Time.get_datetime_string_from_system(true), "reviewed_by": user_id },
		true, ["Prefer: return=minimal"])
	return r.ok


# --- plumbing -----------------------------------------------------------------------------------------

## One request. Returns { ok, code, data } (data: the parsed JSON, or null).
func _call(method: String, path: String, body: Variant, auth: bool, extra_headers: Array = []) -> Dictionary:
	if not configured():
		return { "ok": false, "code": 0, "data": null }
	if auth and _access != "" and Time.get_unix_time_from_system() > _expires - 60 and not path.begins_with("/auth/"):
		await _renew()
	var headers := PackedStringArray(["apikey: " + key, "Content-Type: application/json"])
	if auth and _access != "":
		headers.append("Authorization: Bearer " + _access)
	for h in extra_headers:
		headers.append(h)
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var m: int = { "GET": HTTPClient.METHOD_GET, "POST": HTTPClient.METHOD_POST, "PATCH": HTTPClient.METHOD_PATCH, "DELETE": HTTPClient.METHOD_DELETE }[method]
	var err := http.request(url + path, headers, m, JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		return { "ok": false, "code": 0, "data": null }
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else null
	return { "ok": res[0] == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, "code": code if res[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": data }
