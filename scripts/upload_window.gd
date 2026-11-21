class_name UploadWindow
extends Modal
## Settings > Upload my seeds: pick seeds of yours that aren't official yet and send them for
## review. Below: everything you sent and what happened to it (waiting / approved / denied).
## Each seed can carry your block art: "Add art..." takes a PNG of 4 boxes of 32x32 (128x32, like
## the 4 block boxes of the sprite sheet / an Aseprite strip) or one 32x32 box. If the developer
## approves the seed WITH your art, it makes x25 Mycoras instead of x10.

var _list: VBoxContainer
var _checks := {}  # seed id -> CheckBox
var _send: Button
var _status: Label
var _history: VBoxContainer
var _busy := false
var _art_dialog: FileDialog
var _art_for := ""


func _ready() -> void:
	_init_modal("Upload my seeds", Vector2(560, 0))
	body.add_child(note("Tick the seeds you want the developer to review. Approved seeds reach every player in the next update, signed with your username."))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_send = Button.new()
	_send.custom_minimum_size = Vector2(0, 36)
	_send.pressed.connect(_on_send)
	body.add_child(_send)
	_status = note()
	body.add_child(_status)
	var h := Label.new()
	h.text = "Sent before"
	h.add_theme_color_override("font_color", Color("#ffc94a"))
	body.add_child(h)
	var hs := ScrollContainer.new()
	hs.custom_minimum_size = Vector2(0, 140)
	hs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(hs)
	_art_dialog = FileDialog.new()
	_art_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_art_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_art_dialog.use_native_dialog = true
	_art_dialog.title = "Block art: a PNG of 4 boxes of 32x32 (128x32) or one 32x32"
	_art_dialog.filters = PackedStringArray(["*.png ; PNG image"])
	_art_dialog.file_selected.connect(_on_art_file)
	add_child(_art_dialog)
	_history = VBoxContainer.new()
	_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.add_child(_history)


func open() -> void:
	_status.text = ""
	_fill()
	super()
	_load_history()


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	_checks.clear()
	if not Online.logged_in():
		_list.add_child(note("Log in first: Settings > Account."))
		_send.disabled = true
		_send.text = "Upload"
		return
	var ids := Game.my_unofficial_seeds()
	if ids.is_empty():
		_list.add_child(note("No seeds of yours to upload: splice something new!"))
	for id in ids:
		var s: Dictionary = Game.seeds[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var cb := CheckBox.new()
		cb.toggled.connect(func(_on): _update_send())
		row.add_child(cb)
		var icon := TextureRect.new()
		icon.texture = SeedArt.texture_for(s)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(36, 36)
		row.add_child(icon)
		var l := Label.new()
		var parents: Array = s.get("parents", [])
		l.text = "%s  ·  R%d%s" % [s.name, int(s.rarity), "  ·  %s + %s" % [Game.get_seed(parents[0]).get("name", "?"), Game.get_seed(parents[1]).get("name", "?")] if parents.size() == 2 else "  ·  your own Tier 1"]
		l.add_theme_color_override("font_color", (SeedArt.rarity_tier(int(s.rarity))[1] as Color).lerp(Color.WHITE, 0.35))
		l.clip_text = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var art := TextureRect.new()
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.custom_minimum_size = Vector2(32, 32)
		var img := BlockArt.get_art(id)
		if img != null:
			art.texture = ImageTexture.create_from_image(img.get_region(Rect2i(0, 0, 32, 32)))
		art.tooltip_text = "Your block art (sent with the seed)" if img != null else "No block art yet"
		row.add_child(art)
		var add := Button.new()
		add.text = "Change art..." if img != null else "Add art..."
		add.tooltip_text = "A PNG of 4 boxes of 32x32 (128x32) or one 32x32 box.\nApproved with your art = x25 Mycoras instead of x10."
		add.pressed.connect(func():
			_art_for = id
			_art_dialog.popup_centered_ratio())
		row.add_child(add)
		_list.add_child(row)
		_checks[id] = cb
	_update_send()


## The picked PNG becomes this seed's block art (you see it in your game right away too).
func _on_art_file(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or _art_for == "" or not Game.seeds.has(_art_for):
		_say("Couldn't read that image.", false)
		return
	img.convert(Image.FORMAT_RGBA8)
	var strip: Image
	if img.get_size() == Vector2i(BlockArt.FRAMES * BlockArt.SIZE, BlockArt.SIZE):
		strip = img
	elif img.get_size() == Vector2i(BlockArt.SIZE, BlockArt.SIZE):
		strip = Image.create_empty(BlockArt.FRAMES * BlockArt.SIZE, BlockArt.SIZE, false, Image.FORMAT_RGBA8)
		for f in BlockArt.FRAMES:
			strip.blit_rect(img, Rect2i(0, 0, BlockArt.SIZE, BlockArt.SIZE), Vector2i(f * BlockArt.SIZE, 0))
	else:
		_say("The art must be 128x32 (4 boxes of 32x32) or 32x32: this one is %dx%d." % [img.get_width(), img.get_height()], false)
		return
	BlockArt.set_art(_art_for, strip)
	_say("Block art added to %s." % Game.seeds[_art_for].name, true)
	var keep := _chosen()
	_fill()
	for id in keep:
		if _checks.has(id):
			_checks[id].button_pressed = true


func _say(text: String, ok: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color("#a6ff6e") if ok else Color("#ff8a8a"))


func _chosen() -> Array:
	return _checks.keys().filter(func(id): return _checks[id].button_pressed)


func _update_send() -> void:
	var n := _chosen().size()
	_send.text = "Upload %d seed%s for review" % [n, "" if n == 1 else "s"]
	_send.disabled = n == 0 or _busy or not Online.logged_in()


func _on_send() -> void:
	_busy = true
	_update_send()
	_status.text = "Uploading..."
	var r: Dictionary = await Online.upload(_chosen())
	_busy = false
	_status.text = "Sent %d seed%s: the developer will review them." % [r.sent, "" if r.sent == 1 else "s"] if r.ok else r.error
	_status.add_theme_color_override("font_color", Color("#a6ff6e") if r.ok else Color("#ff8a8a"))
	Audio.play(&"success" if r.ok else &"error")
	for id in _checks:
		_checks[id].button_pressed = false
	_update_send()
	_load_history()


func _load_history() -> void:
	for c in _history.get_children():
		c.queue_free()
	if not Online.logged_in():
		return
	var rows: Array = await Online.my_submissions()
	for c in _history.get_children():
		c.queue_free()
	if rows.is_empty():
		_history.add_child(note("Nothing yet."))
	for r in rows:
		var st := String(r.get("status", "pending"))
		var l := Label.new()
		l.text = "%s  ·  %s%s" % [r.get("seed_name", "?"), { "pending": "waiting for review", "approved": "APPROVED", "denied": "denied" }.get(st, st),
			"  ·  \"%s\"" % r.note if r.get("note") != null and String(r.note) != "" else ""]
		l.add_theme_color_override("font_color", { "pending": Color(0.8, 0.78, 0.9), "approved": Color("#a6ff6e"), "denied": Color("#ff8a8a") }.get(st, Color.WHITE))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_history.add_child(l)
