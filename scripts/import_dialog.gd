class_name ImportDialog
extends Control
## Opens after you pick a friend's file in Import List: every seed they have that you don't is
## listed with a checkbox, so you say yes or no to each one before anything is added.
## Seeds you already have are never offered (yours stay as they are).

signal confirmed(chosen: Array)  ## their ids of the seeds you said yes to
signal cancelled

var preview := {}
var _rows := {}  # their id -> { check: CheckBox, needs: Label }
var _names := {}  # their id -> name, for "needs ..." messages
var _title: Label
var _sub: Label
var _box: VBoxContainer
var _summary: Label
var _ok: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	_title = Label.new()
	_title.text = "Import Seeds"
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("#a6ff6e"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)
	_sub = Label.new()
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	root.add_child(_sub)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	root.add_child(tools)
	_tool(tools, "Yes to all", "Tick every seed", func(): _set_all(true))
	_tool(tools, "No to all", "Untick every seed", func(): _set_all(false))
	_tool(tools, "Also take what they need", "Tick the seeds your ticked seeds are spliced from", _take_needed)

	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#0e0b16")
	fsb.border_color = Color("#3b3150")
	fsb.set_border_width_all(2)
	fsb.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fsb)
	root.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_box)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_color_override("font_color", Color("#ffc94a"))
	root.add_child(_summary)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(110, 38)
	cancel.pressed.connect(_cancel)
	buttons.add_child(cancel)
	_ok = Button.new()
	_ok.custom_minimum_size = Vector2(200, 38)
	_ok.add_theme_color_override("font_color", Color("#a6ff6e"))
	_ok.pressed.connect(_confirm)
	buttons.add_child(_ok)


## Shows the new seeds in `p` (from Game.read_import). All ticked to start with.
func open(p: Dictionary, file_name: String) -> void:
	preview = p
	_rows.clear()
	_names.clear()
	for c in _box.get_children():
		c.queue_free()
	for n in preview.new_seeds:
		_names[n.their_id] = n.seed.name
	var list: Array = preview.new_seeds.duplicate()
	list.sort_custom(func(a, b): return int(a.seed.rarity) < int(b.seed.rarity) or (int(a.seed.rarity) == int(b.seed.rarity) and String(a.seed.name).naturalnocasecmp_to(b.seed.name) < 0))
	for n in list:
		_box.add_child(_row(n))
	var clashes: int = preview.new_seeds.filter(func(n): return String(n.get("clash", "")) != "").size()
	_sub.text = "From %s%s:  %d new seed%s.  %d you already have are skipped (yours stay as they are).%s\nSay yes or no to each one." % [
		file_name, "  by %s" % preview.username if String(preview.get("username", "")) != "" else "  (no username)", preview.new_seeds.size(), "" if preview.new_seeds.size() == 1 else "s", preview.known.size(),
		"\n%d use a recipe you already have under another name: they start unticked." % clashes if clashes > 0 else ""]
	visible = true
	Audio.play(&"open")
	_refresh()


func chosen() -> Array:
	var out: Array = []
	for id in _rows:
		if _rows[id].check.button_pressed:
			out.append(id)
	return out


func _row(n: Dictionary) -> Control:
	var s: Dictionary = n.seed
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1d1828")
	sb.border_color = Color("#2e2640")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)

	var check := CheckBox.new()
	# a seed whose recipe already makes one of YOUR seeds is the same splice under another
	# name: it starts as "no"
	check.button_pressed = String(n.get("clash", "")) == ""
	check.tooltip_text = "Ticked = yes, add it.  Unticked = no, leave it out."
	check.toggled.connect(func(_on): _refresh())
	h.add_child(check)
	var icon := TextureRect.new()
	icon.texture = SeedArt.texture_for(s)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(44, 44)
	h.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	h.add_child(text)
	var tier: Array = SeedArt.rarity_tier(int(s.rarity))
	var name_l := Label.new()
	name_l.text = s.name
	name_l.add_theme_color_override("font_color", (tier[1] as Color).lerp(Color.WHITE, 0.3))
	text.add_child(name_l)
	var detail := Label.new()
	var made := "Tier 1" if n.parents.is_empty() else "made from %s + %s" % [_name_of(n.parents[0]), _name_of(n.parents[1])] if n.parents.size() == 2 else ""
	detail.text = "R%d  ·  by %s  ·  %s  ·  %s  ·  %s" % [int(s.rarity), s.get("made_by", "unknown"), Game.tag_name(s.tag), DropLogic.describe(s.drop), made]
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.72, 0.69, 0.82))
	detail.clip_text = true
	text.add_child(detail)
	if String(n.get("clash", "")) != "":
		var clash := Label.new()
		clash.text = "Same splice as your %s: %s + %s already makes it. Your recipe wins, so this one would come in without a recipe." % [
			Game.get_seed(n.clash).get("name", "?"), _name_of(n.parents[0]), _name_of(n.parents[1])]
		clash.add_theme_font_size_override("font_size", 12)
		clash.add_theme_color_override("font_color", Color("#7fb2ff"))
		clash.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(clash)
	var needs := Label.new()
	needs.add_theme_font_size_override("font_size", 12)
	needs.add_theme_color_override("font_color", Color("#ffb347"))
	needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(needs)

	# clicking anywhere on the row flips the checkbox
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			check.button_pressed = not check.button_pressed)
	_rows[n.their_id] = { "check": check, "needs": needs, "panel": panel, "style": sb }
	return panel


func _name_of(their_id: String) -> String:
	if _names.has(their_id):
		return _names[their_id]
	if preview.known.has(their_id):
		return Game.get_seed(preview.known[their_id]).get("name", their_id)
	return their_id


func _refresh() -> void:
	var picked := chosen()
	for id in _rows:
		var row: Dictionary = _rows[id]
		var on: bool = row.check.button_pressed
		row.style.border_color = Color("#a6ff6e").darkened(0.45) if on else Color("#2e2640")
		row.panel.modulate.a = 1.0 if on else 0.55
		var missing := Game.import_missing(preview, picked, [id]) if on else []
		if missing.is_empty():
			row.needs.text = ""
			row.needs.visible = false
		else:
			row.needs.visible = true
			row.needs.text = "Needs %s (not ticked): it will come in without its recipe." % ", ".join(PackedStringArray(missing.map(func(m): return _name_of(m))))
	var splices := Game.import_recipe_count(preview, picked)
	_summary.text = "Adding %d of %d seeds and %d splice%s." % [picked.size(), _rows.size(), splices, "" if splices == 1 else "s"]
	_ok.text = "Import %d seed%s" % [picked.size(), "" if picked.size() == 1 else "s"]
	_ok.disabled = picked.is_empty() and splices == 0


func _set_all(on: bool) -> void:
	for id in _rows:
		_rows[id].check.set_pressed_no_signal(on)
	_refresh()


func _take_needed() -> void:
	for id in Game.import_with_needed(preview, chosen()):
		if _rows.has(id):
			_rows[id].check.set_pressed_no_signal(true)
	_refresh()


func _confirm() -> void:
	if _ok.disabled:
		return
	visible = false
	confirmed.emit(chosen())


func _cancel() -> void:
	visible = false
	cancelled.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


func _tool(parent: Control, text: String, tip: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)
