class_name LiveSync
extends Node
## LIVE, no install: keeps the game in step with the database while it runs.
##   Everyone: every 5 minutes (and soon after the start) checks the official list the developer
##             pushed (Submissions > Push to players). A newer one comes in at once: new seeds,
##             stamps, ratings, art, the graveyard. Players see what arrived.
##   Developer (logged in as an admin): every minute counts the submissions waiting for review.
##             When new ones arrive: a message, a number on the Settings button, and the game's
##             taskbar button flashes.

const OFFICIAL_EVERY := 300.0
const PENDING_EVERY := 60.0

var settings_btn: Button
var toast: Callable  # (text, color)
var pending := 0
var _seen_pending := -1
var _t_official := OFFICIAL_EVERY - 4.0  # first check a few seconds after the start
var _t_pending := PENDING_EVERY - 6.0
var _busy := false


func _process(delta: float) -> void:
	if not Online.configured() or _busy:
		return
	_t_official += delta
	_t_pending += delta
	if _t_official >= OFFICIAL_EVERY:
		_t_official = 0.0
		check_official()
	elif _t_pending >= PENDING_EVERY and Online.logged_in() and Online.is_admin:
		_t_pending = 0.0
		check_pending()


func check_official() -> void:
	_busy = true
	var v: int = await Online.official_version()
	if v > Official.live_version:
		var d: Dictionary = await Online.fetch_official()
		if d.get("data") is Dictionary and int(d.get("version", 0)) > Official.live_version:
			var r: Dictionary = Official.apply_live(d.data, int(d.version))
			var added := int(r.get("seeds_added", 0))
			if added > 0 and toast.is_valid():
				toast.call("New from the developer: %d new seed%s and %d splice%s are in your game!" % [
					added, "" if added == 1 else "s", int(r.recipes_added), "" if int(r.recipes_added) == 1 else "s"], Color("#a6ff6e"))
	_busy = false


func check_pending() -> void:
	_busy = true
	var n: int = await Online.pending_count()
	_busy = false
	set_pending(n)


func set_pending(n: int) -> void:
	var new_ones := n - maxi(_seen_pending, 0)
	pending = n
	if settings_btn:
		settings_btn.text = "Settings  (%d)" % n if n > 0 else "Settings"
	if _seen_pending >= 0 and new_ones > 0 or _seen_pending < 0 and n > 0:
		if toast.is_valid():
			toast.call("%d new seed%s need%s to be approved  (Settings > Submissions)" % [n, "" if n == 1 else "s", "s" if n == 1 else ""], Color("#ffc94a"))
		Audio.play(&"discover")
		DisplayServer.window_request_attention()
	_seen_pending = n
