class_name SubmissionsWindow
extends Modal
## Developer only (Settings > Submissions): every seed players uploaded that is waiting for review.
## Approve: the seed (and the seeds it's made from, with the player's block art) comes into your
## game, credited to the player; publish an update to give it to everyone. Deny: it stays out.

var _list: VBoxContainer
var _status: Label
var _busy := false
var live: LiveSync
var _push: Button
var _push_note: Label
var _push_armed := false


func _ready() -> void:
	_init_modal("Submissions", Vector2(1060, 0))
	body.add_child(note("Seeds players uploaded for review. Approve brings one into your game (credited to the player); your next published update gives it to everyone. Deny keeps it out."))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	body.add_child(top)
	var refresh := Button.new()
	refresh.text = "Refresh"
	refresh.pressed.connect(_load)
	top.add_child(refresh)
	_push = Button.new()
	_push.text = "Push to players"
	_push.tooltip_text = "When you're done approving: send your seeds, stamps, ratings, art and graveyard\nto every player right now (their games pick it up within 5 minutes, no install)."
	_push.pressed.connect(_on_push)
	top.add_child(_push)
	_push_note = Label.new()
	_push_note.add_theme_font_size_override("font_size", UiKit.SMALL)
	_push_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_push_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_push_note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_status = note()
	body.add_child(_status)


func open() -> void:
	super()
	_load()


func _load() -> void:
	for c in _list.get_children():
		c.queue_free()
	if not (Online.logged_in() and Online.is_admin):
		_list.add_child(note("Log in with your admin account (Settings > Account) to review submissions.", Color("#ffc94a")))
		return
	_list.add_child(note("Loading..."))
	# seeds denied before (even from another PC) go to your graveyard too
	var buried := 0
	for d in await Online.denied_submissions():
		var who := String(d.get("profiles", {}).get("username", "")) if d.get("profiles") is Dictionary else ""
		if d.get("payload") is Dictionary and Game.bury_submission(d.payload, who, int(d.id)):
			buried += 1
	if buried > 0:
		_status.text = "%d denied seed%s added to your Graveyard." % [buried, "" if buried == 1 else "s"]
	var rows: Array = await Online.pending_submissions()
	for c in _list.get_children():
		c.queue_free()
	set_title("Submissions (%d waiting)" % rows.size())
	if live:
		live.set_pending(rows.size())
	_update_push_note()
	if rows.is_empty():
		_list.add_child(note("Nothing waiting for review."))
	for r in rows:
		_list.add_child(_row(r))


func _row(r: Dictionary) -> Control:
	var payload: Dictionary = r.get("payload", {}) if r.get("payload") is Dictionary else {}
	var top: Dictionary = {}
	for s in payload.get("seeds", []):
		if String(s.get("id", "")) == String(payload.get("top", "")):
			top = s
	var who := String(r.get("profiles", {}).get("username", "?")) if r.get("profiles") is Dictionary else "?"
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(48, 48)
	if not top.is_empty():
		icon.texture = SeedArt.texture_for(_drawable(top))
	h.add_child(icon)
	var art := TextureRect.new()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.custom_minimum_size = Vector2(48, 48)
	var b64 := String(top.get("block_art", ""))
	if b64 != "":
		var img := Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) == OK:
			art.texture = ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, 32, 32)))
	art.tooltip_text = "Their block art" if art.texture else "No block art"
	h.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var name_l := Label.new()
	name_l.text = "%s  ·  by %s" % [r.get("seed_name", "?"), who]
	name_l.add_theme_font_size_override("font_size", UiKit.SMALL)
	info.add_child(name_l)
	var known := Game.find_by_name(String(r.get("seed_name", ""))) != ""
	info.add_child(note("R%d  ·  %s  ·  %d seed%s in the recipe chain%s" % [int(top.get("rarity", 1)), Game.tag_name(String(top.get("tag", ""))),
		payload.get("seeds", []).size(), "" if payload.get("seeds", []).size() == 1 else "s", "  ·  you already have a seed with this name" if known else ""],
		Color("#ffc94a") if known else Color(0.85, 0.82, 0.93)))
	var deny_note := LineEdit.new()
	deny_note.placeholder_text = "Note to the player (optional)"
	deny_note.max_length = 300
	info.add_child(deny_note)
	var verdict := HBoxContainer.new()
	verdict.add_theme_constant_override("separation", 6)
	info.add_child(verdict)
	var art_cb := CheckBox.new()
	art_cb.text = "Approve their art (x25)"
	art_cb.button_pressed = b64 != ""
	art_cb.disabled = b64 == ""
	art_cb.tooltip_text = "Ticked: their block art comes in and the seed makes x25 Mycoras.\nUnticked: the seed comes in without it (x10)."
	verdict.add_child(art_cb)
	var rsr := OptionButton.new()
	rsr.add_item("RSR: not rated", 0)
	for rr in range(6, 11):
		rsr.add_item("RSR %d  (x%s)" % [rr, str(Bank.RSR_MULT[rr])], rr)
	verdict.add_child(rsr)
	var btns := VBoxContainer.new()
	h.add_child(btns)
	var ok := Button.new()
	ok.text = "Approve"
	ok.pressed.connect(func(): _decide(r, payload, "approved", deny_note.text, panel, art_cb.button_pressed and not art_cb.disabled, rsr.get_selected_id()))
	btns.add_child(ok)
	var no := Button.new()
	no.text = "Deny"
	no.pressed.connect(func(): _decide(r, payload, "denied", deny_note.text, panel))
	btns.add_child(no)
	return panel


## A fingerprint of what players would get, to tell whether there's anything new to push.
static func _fingerprint(payload: Dictionary) -> String:
	var p := payload.duplicate(true)
	for part in ["official", "approvals"]:
		p[part].erase("published")
		p[part].erase("version")
	return JSON.stringify(p).sha256_text()


func _update_push_note() -> void:
	_push_armed = false
	_push.text = "Push to players"
	if not (Online.logged_in() and Online.is_admin):
		_push.disabled = true
		_push_note.text = ""
		return
	_push.disabled = false
	var fp := _fingerprint(Game.build_official_payload(""))
	var same := fp == String(UserSettings.get_value("live", "pushed", ""))
	_push_note.text = "Players have everything (live v%d)." % Official.live_version if same else "You have changes players don't have yet: push when you're done approving."
	_push_note.add_theme_color_override("font_color", Color(0.82, 0.79, 0.91) if same else Color("#ffc94a"))


func _on_push() -> void:
	if _busy:
		return
	if not _push_armed:  # a second click confirms
		_push_armed = true
		_push.text = "Click again to push to every player"
		return
	_busy = true
	_push.disabled = true
	_push_note.text = "Pushing..."
	var v: int = await Online.official_version()
	var payload := Game.build_official_payload("live-%d" % (v + 1))
	var nv: int = await Online.push_official(payload) if v >= 0 else -1
	_busy = false
	if nv < 0:
		_push_note.text = "The push failed: check your internet connection and that you're logged in as the admin."
		_push_note.add_theme_color_override("font_color", Color("#ff8a8a"))
		_push.disabled = false
		_push_armed = false
		_push.text = "Push to players"
		return
	Official.apply_live(payload, nv)
	UserSettings.set_value("live", "pushed", _fingerprint(payload))
	Audio.play(&"success")
	_update_push_note()
	_status.text = "Pushed live v%d to every player: %d seeds, %d in the graveyard." % [nv, payload.official.seeds.size(), payload.approvals.denied.size()]


## Enough of a seed to draw it (a submitted seed may lack fields).
func _drawable(s: Dictionary) -> Dictionary:
	var d := s.duplicate()
	d.pattern = int(d.get("pattern", 0))
	d.pattern_seed = int(d.get("pattern_seed", 0))
	if typeof(d.get("colors")) != TYPE_ARRAY or d.colors.size() < 2:
		d.colors = ["#888888", "#555555"]
	d.sprout = String(d.get("sprout", "#7ccf4e"))
	return d


func _decide(r: Dictionary, payload: Dictionary, status: String, text: String, panel: Control, with_art := false, rating := 0) -> void:
	if _busy:
		return
	_busy = true
	var msg := ""
	if status == "approved":
		var res: Dictionary = Game.import_submission(payload, with_art)
		if not res.get("ok", false):
			_busy = false
			_status.text = "Couldn't read that submission: %s" % res.get("error", "?")
			return
		var top_id := Game.find_by_name(String(r.get("seed_name", "")))
		if top_id != "":
			Game.set_art_ok(top_id, with_art and BlockArt.has_art(top_id))
			Game.set_rating(top_id, rating)
		if rating >= 6 and text.strip_edges() == "":
			text = "RSR %d/10" % rating
		msg = "Approved %s%s%s: %d new seed%s in your game." % [r.get("seed_name", "?"), " with its art" if with_art else "", "  ·  RSR %d" % rating if rating >= 6 else "",
			res.seeds_added, "" if res.seeds_added == 1 else "s"]
	else:
		var who := String(r.get("profiles", {}).get("username", "")) if r.get("profiles") is Dictionary else ""
		Game.bury_submission(payload, who, int(r.id), true)
		msg = "Denied %s: it's in your Graveyard (and ships in it with your next update)." % r.get("seed_name", "?")
	var saved: bool = await Online.review(int(r.id), status, text)
	_busy = false
	if not saved:
		_status.text = msg + "  (couldn't save the decision online: try Refresh)"
		return
	_status.text = msg
	Audio.play(&"success")
	panel.queue_free()
	if live:
		live.set_pending(maxi(0, live.pending - 1))
	_update_push_note()
