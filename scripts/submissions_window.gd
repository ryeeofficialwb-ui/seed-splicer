class_name SubmissionsWindow
extends Modal
## Developer only (Settings > Submissions): every seed players uploaded that is waiting for review.
## A submission is reviewed ONE SEED AT A TIME, from the first seed of its recipe chain that isn't
## in your game yet (Game.submission_next_step): nothing gets in without being looked at.
##   Approve  that seed comes into your game with the stamp, credited to the player (+ their block
##            art if you tick it); the next unique seed of the chain shows up, until the top one.
##   Deny     that seed goes to your graveyard (it can still be spliced, it makes 1 Mycora) and the
##            submission is closed.
## Push to players (or publish an update) gives your stamps and graveyard to everyone.

var _list: VBoxContainer
var _status: Label
var _busy := false
var live: LiveSync
var _push: Button
var _push_note: Label
var _push_armed := false


func _ready() -> void:
	_init_modal("Submissions", Vector2(1060, 0))
	body.add_child(note("Seeds players uploaded. Each one is reviewed a seed at a time, starting with the first seed of its recipe that isn't in your game yet. Approve = in your game with the stamp. Deny = into the graveyard."))
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
	var who := String(r.get("profiles", {}).get("username", "?")) if r.get("profiles") is Dictionary else "?"
	var step := Game.submission_next_step(payload)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"CardBase"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	# header: what they submitted, by whom, and which step this is
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var title := Label.new()
	title.text = "%s  ·  by %s" % [r.get("seed_name", "?"), who]
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	var step_l := Label.new()
	step_l.theme_type_variation = &"NoteLabel"
	head.add_child(step_l)
	if not step.ok:
		col.add_child(note("Couldn't read this submission: %s" % step.error, UiKit.RED))
	if String(step.their_id) == "":
		step_l.text = "already in your game"
		col.add_child(note("Every seed of this submission is in your game already: approving just closes it."))
	else:
		step_l.text = "%d seed%s left to review" % [_unique_left(payload), "" if _unique_left(payload) == 1 else "s"]

	var seed: Dictionary = step.seed
	var art_tex: Texture2D = null
	if not seed.is_empty():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		col.add_child(h)
		h.add_child(_picture(SeedArt.texture_for(_drawable(seed)), "Their seed"))
		var b64 := String(seed.get("block_art", ""))
		if b64 != "":
			var img := Image.new()
			if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) == OK:
				art_tex = ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, 32, 32)))
		h.add_child(_picture(art_tex, "Their block art" if art_tex else "No block art"))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 6)
		h.add_child(info)
		var nm := Label.new()
		nm.text = "Now reviewing:  %s" % String(step.name)
		info.add_child(nm)
		var parents: Array = step.parents
		info.add_child(note("Made from:  %s" % (" + ".join(parents) if not parents.is_empty() else "nothing (their own Tier 1 seed)")))
		info.add_child(note("R%d  ·  %s  ·  %s" % [int(seed.get("rarity", 1)), Game.tag_name(String(seed.get("tag", ""))),
			"has block art" if art_tex else "no block art"]))

	# the verdict
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 10)
	controls.add_theme_constant_override("v_separation", 8)
	col.add_child(controls)
	var art_cb := CheckBox.new()
	art_cb.text = "Approve their block art (x25)"
	art_cb.button_pressed = art_tex != null
	art_cb.disabled = art_tex == null
	art_cb.tooltip_text = "Only BLOCK art counts (the seed's own picture doesn't).\nTicked: their block art comes in and the seed makes x25 Mycoras. Unticked: x10."
	controls.add_child(art_cb)
	var rsr := OptionButton.new()
	rsr.add_item("RSR: not rated", 0)
	for rr in range(6, 11):
		rsr.add_item("RSR %d  (x%s)" % [rr, str(Bank.RSR_MULT[rr])], rr)
	controls.add_child(rsr)
	var deny_note := LineEdit.new()
	deny_note.placeholder_text = "Note to the player (optional)"
	deny_note.max_length = 300
	deny_note.custom_minimum_size = Vector2(380, 0)
	controls.add_child(deny_note)
	var ok := Button.new()
	ok.text = "Approve this seed" if String(step.their_id) != "" else "Close it (approved)"
	ok.theme_type_variation = &"ShopButton"
	ok.pressed.connect(func(): _decide(r, payload, step, "approved", deny_note.text, panel, art_cb.button_pressed and not art_cb.disabled, rsr.get_selected_id()))
	controls.add_child(ok)
	var no := Button.new()
	no.text = "Deny (graveyard)"
	no.theme_type_variation = &"DangerButton"
	no.pressed.connect(func(): _decide(r, payload, step, "denied", deny_note.text, panel))
	controls.add_child(no)
	return panel


## How many seeds of the submission still aren't in your game.
func _unique_left(payload: Dictionary) -> int:
	var preview := Game.preview_from(payload)
	return preview.new_seeds.size() if preview.ok else 0


func _picture(tex: Texture2D, tip: String) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.box("inset", 3, [4, 4, 4, 4]))
	frame.tooltip_text = tip
	var p := PixelPicture.new()
	p.texture = tex
	p.custom_minimum_size = Vector2(96, 96)
	frame.add_child(p)
	return frame


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


func _decide(r: Dictionary, payload: Dictionary, step: Dictionary, status: String, text: String, panel: Control, with_art := false, rating := 0) -> void:
	if _busy:
		return
	var their_id := String(step.get("their_id", ""))
	var seed_name := String(step.get("name", r.get("seed_name", "?")))
	var msg := ""
	if their_id != "":
		var res: Dictionary = Game.import_submission_step(payload, their_id, with_art, status == "denied")
		if not res.ok:
			_status.text = "Couldn't bring that seed in: %s" % res.error
			return
		if status == "approved":
			Game.set_art_ok(res.id, with_art and BlockArt.has_art(res.id))
			Game.set_rating(res.id, rating)
			msg = "Approved %s%s%s: it's in your game with the stamp." % [seed_name, " with its block art" if with_art else "",
				"  ·  RSR %d" % rating if rating >= 6 else ""]
		else:
			msg = "Denied %s: it's in your Graveyard (still splices, makes 1 Mycora)." % seed_name
	if status == "approved" and their_id != "" and String(Game.submission_next_step(payload).their_id) != "":
		# more seeds of this chain to review: show the next one, the submission stays open
		_status.text = msg + "  The next seed of this submission is up."
		Audio.play(&"success")
		var i := panel.get_index()
		panel.queue_free()
		var next := _row(r)
		_list.add_child(next)
		_list.move_child(next, i)
		_update_push_note()
		return
	if rating >= 6 and text.strip_edges() == "":
		text = "RSR %d/10" % rating
	_busy = true
	var saved: bool = await Online.review(int(r.id), status, text)
	_busy = false
	if not saved:
		_status.text = msg + "  (couldn't save the decision online: try Refresh)"
		return
	_status.text = msg + ("  Submission done." if status == "approved" else "")
	Audio.play(&"success")
	panel.queue_free()
	if live:
		live.set_pending(maxi(0, live.pending - 1))
	_update_push_note()
