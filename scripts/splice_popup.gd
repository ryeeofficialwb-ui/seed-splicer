class_name SplicePopup
extends Control
## Pops up when you make a splice nobody has made yet (or right-click a seed in the
## dictionary to restyle it). Name it, pick a pattern, color the seed and its sprout, pick
## which crop it grows into (painted in the seed's colors), then add it to the dictionary.

signal created(look: Dictionary)          ## new seed from a + b
signal linked(existing_id: String)        ## new splice that makes a seed you already have
signal edited(id: String, look: Dictionary)
signal added_custom(look: Dictionary)     ## your own tier-1 seed (Add Seed button)
signal cancelled

enum Mode { NEW, EDIT, ADD }

const PRESETS := [
	"#f4f1ff", "#c4c0d4", "#7d7a8f", "#3b3646", "#1c1824",
	"#ff6a1c", "#ffb347", "#ffe066", "#e6c440", "#a6ff6e",
	"#5fd35a", "#2f8f4e", "#27b3c4", "#6ef7ff", "#4a7dff",
	"#2b3a8f", "#c58bff", "#8a3fd1", "#ff7fc8", "#e0334f",
	"#8b5a34", "#5c3a22", "#d8b48a", "#9a9cab", "#686a7c",
]

var mode := Mode.NEW
var parent_a := ""
var parent_b := ""
var edit_id := ""
var look := {}
var _names: Array[String] = []
var _name_idx := 0
var _link_id := ""

var _title: Label
var _parents_row: HBoxContainer
var _icon_a: PixelPicture
var _icon_b: PixelPicture
var _label_a: Label
var _label_b: Label
var _preview: PixelPicture
var _rarity: Label
var _rarity_sum: Label
var _name_edit: LineEdit
var _idea_btn: Button
var _pattern_btns: Array[Button] = []
var _pattern_label: Label
var _shuffle_btn: Button
var _random_btn: Button
var _tag_btns := {}  # tag -> Button
var _tag_row: HBoxContainer
var _tag_caption: Label
var _tag_roll: Label   # "Rolled: Bountiful!" for a new splice
var _tag_odds: Label
var _drop_caption: Label
var _kind_btns := {}  # "block"/"decoration" -> Button
var _collision_btn: Button
var _damage_btn: Button
var _light_btn: Button
var _bg_box: VBoxContainer  ## the checklist for backgrounds
var _bg_checks := {}  # background tag -> CheckBox
var _drop_note: Label
var _crop_btns: Array[Button] = []
var _crop_label: Label
var _growth: Array[PixelPicture] = []  # in growth order: seed, planted, sprout, sapling, crop
var _c1: ColorPickerButton
var _c2: ColorPickerButton
var _cs: ColorPickerButton
var _notice: Label
var _scroll: ScrollContainer
var _panel: PanelContainer
var _fruit_btns := {}  # 0 (auto), 1..4 -> Button
var _fruit_label: Label
var _ok: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	_panel = panel
	panel.custom_minimum_size = Vector2(740, 0)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("#a6ff6e"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)

	# parents: [A] + [B]
	_parents_row = HBoxContainer.new()
	_parents_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_parents_row.add_theme_constant_override("separation", 8)
	root.add_child(_parents_row)
	_icon_a = _small_icon()
	_label_a = Label.new()
	_icon_b = _small_icon()
	_label_b = Label.new()
	var plus := Label.new()
	plus.text = "  +  "
	plus.add_theme_font_size_override("font_size", 20)
	for c in [_icon_a, _label_a, plus, _icon_b, _label_b]:
		_parents_row.add_child(c)

	# the editor can be taller than a small window: the middle scrolls, the title and the Save /
	# Cancel buttons always stay in view
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)

	# left: big preview + rarity
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	body.add_child(left)
	var frame := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("#0e0b16")
	fsb.border_color = Color("#3b3150")
	fsb.set_border_width_all(2)
	fsb.set_content_margin_all(8)
	frame.add_theme_stylebox_override("panel", fsb)
	left.add_child(frame)
	# every picture in this window is a PixelPicture: whole screen pixels per art pixel at any
	# window size, so the pixel art never gets lumpy
	_preview = PixelPicture.new()
	_preview.custom_minimum_size = Vector2(128, 128)
	frame.add_child(_preview)
	_rarity = Label.new()
	_rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity.add_theme_font_size_override("font_size", 18)
	left.add_child(_rarity)
	_rarity_sum = Label.new()
	_rarity_sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rarity_sum.add_theme_font_size_override("font_size", 13)
	_rarity_sum.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	left.add_child(_rarity_sum)

	# the 4 growth stages of this seed's crop, in its colors
	left.add_child(_caption("Grows:  seed › planted › sprout › sapling › crop"))
	var growth := HBoxContainer.new()
	growth.add_theme_constant_override("separation", 2)
	left.add_child(growth)
	for stage in CropArt.GROWTH_ORDER:
		var g := PixelPicture.new()
		g.custom_minimum_size = Vector2(64, 64)  # 2x: five stages side by side still fit a small window
		g.tooltip_text = CropArt.STAGE_NAMES[stage] + ("  (with its block fruit, if the seed has block art)" if stage == CropArt.Stage.CROP
			else "  (just a tiny leaf: the seed is too big to look right in the ground)" if stage == CropArt.Stage.PLANTED else "")
		growth.add_child(g)
		_growth.append(g)

	# drop: what this seed gives when harvested (see drop_logic.gd). Guessed from the name until
	# you change it; seeds themselves never deal damage, only their drop can.
	left.add_theme_constant_override("separation", 6)
	_drop_caption = _caption("Drops")
	left.add_child(_drop_caption)
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 4)
	left.add_child(kinds)
	var kind_group := ButtonGroup.new()
	for k in DropLogic.KINDS:
		var kb := Button.new()
		kb.text = DropLogic.KIND_NAMES[k]
		kb.toggle_mode = true
		kb.button_group = kind_group
		kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kb.pressed.connect(_set_drop_kind.bind(k))
		kinds.add_child(kb)
		_kind_btns[k] = kb
	_collision_btn = Button.new()
	_collision_btn.toggle_mode = true
	_collision_btn.tooltip_text = "Can you walk through what this seed drops?"
	_collision_btn.toggled.connect(_set_collision)
	left.add_child(_collision_btn)
	_damage_btn = Button.new()
	_damage_btn.toggle_mode = true
	_damage_btn.text = "Collision damage"
	_damage_btn.tooltip_text = "Touching the drop hurts (lava, spikes...). Turns collision on. The seed itself never deals damage."
	_damage_btn.add_theme_color_override("font_pressed_color", DropLogic.DAMAGE_COLOR)
	_damage_btn.add_theme_color_override("font_hover_pressed_color", DropLogic.DAMAGE_COLOR)
	_damage_btn.toggled.connect(_set_damage)
	left.add_child(_damage_btn)
	_light_btn = Button.new()
	_light_btn.toggle_mode = true
	_light_btn.text = "Emits light"
	_light_btn.tooltip_text = "The drop gives off light (a torch, lava, a glowing cave background...). Blocks, decorations and backgrounds can all have it."
	_light_btn.add_theme_color_override("font_pressed_color", DropLogic.LIGHT_COLOR)
	_light_btn.add_theme_color_override("font_hover_pressed_color", DropLogic.LIGHT_COLOR)
	_light_btn.toggled.connect(_set_light)
	left.add_child(_light_btn)
	_bg_box = VBoxContainer.new()
	_bg_box.add_theme_constant_override("separation", 0)
	left.add_child(_bg_box)
	_bg_box.add_child(_caption("Background checklist"))
	for t in DropLogic.BG_TAGS:
		if t == "emits_light":
			continue  # the Emits light button above is this tick (a background's list shows it too)
		var cb := CheckBox.new()
		cb.text = DropLogic.BG_TAG_NAMES[t]
		cb.toggled.connect(_set_bg_tag.bind(t))
		_bg_box.add_child(cb)
		_bg_checks[t] = cb
	_drop_note = Label.new()
	_drop_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drop_note.custom_minimum_size = Vector2(208, 0)
	_drop_note.add_theme_font_size_override("font_size", 11)
	_drop_note.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	left.add_child(_drop_note)

	# right: name, pattern, colors
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)

	right.add_child(_caption("Name"))
	var name_row := HBoxContainer.new()
	right.add_child(name_row)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.max_length = 40
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_t): _confirm())
	name_row.add_child(_name_edit)
	_idea_btn = Button.new()
	_idea_btn.text = "Another idea"
	_idea_btn.tooltip_text = "Cycle through suggested names"
	_idea_btn.pressed.connect(_next_name)
	name_row.add_child(_idea_btn)

	var pat_head := HBoxContainer.new()
	right.add_child(pat_head)
	var pc := _caption("Pattern")
	pat_head.add_child(pc)
	_pattern_label = Label.new()
	_pattern_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pattern_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
	pat_head.add_child(_pattern_label)
	_shuffle_btn = Button.new()
	_shuffle_btn.text = "Shuffle"
	_shuffle_btn.tooltip_text = "Same pattern type, new layout (stripe width, dot spacing...)"
	_shuffle_btn.pressed.connect(_shuffle)
	pat_head.add_child(_shuffle_btn)

	var pats := HBoxContainer.new()
	pats.add_theme_constant_override("separation", 4)
	right.add_child(pats)
	var group := ButtonGroup.new()
	for i in SeedArt.Pattern.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		_add_picture(b)
		b.tooltip_text = SeedArt.PATTERN_NAMES[i]
		b.pressed.connect(_set_pattern.bind(i))
		pats.add_child(b)
		_pattern_btns.append(b)

	right.add_child(_caption("Colors"))
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 8)
	right.add_child(colors)
	_c1 = _color_button("Color 1", colors, _set_color.bind(0))
	_c2 = _color_button("Color 2", colors, _set_color.bind(1))
	_cs = _color_button("Sprout", colors, _set_color.bind(2))

	var crop_head := HBoxContainer.new()
	right.add_child(crop_head)
	crop_head.add_child(_caption("Crop"))
	_crop_label = Label.new()
	_crop_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
	crop_head.add_child(_crop_label)
	var crops := HBoxContainer.new()
	crops.add_theme_constant_override("separation", 4)
	right.add_child(crops)
	var crop_group := ButtonGroup.new()
	for t in CropArt.types():
		var cb := Button.new()
		cb.toggle_mode = true
		cb.button_group = crop_group
		_add_picture(cb)
		cb.tooltip_text = t.name
		cb.pressed.connect(_set_crop.bind(t.id))
		crops.add_child(cb)
		_crop_btns.append(cb)

	var fruit_head := HBoxContainer.new()
	right.add_child(fruit_head)
	fruit_head.add_child(_caption("Blocks on the tree"))
	_fruit_label = Label.new()
	_fruit_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.95))
	fruit_head.add_child(_fruit_label)
	var fruits := HBoxContainer.new()
	fruits.add_theme_constant_override("separation", 4)
	right.add_child(fruits)
	var fruit_group := ButtonGroup.new()
	for n in [0, 1, 2, 3, 4]:
		var fb := Button.new()
		fb.text = "Auto" if n == 0 else str(n)
		fb.toggle_mode = true
		fb.button_group = fruit_group
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.tooltip_text = "How many of its block the fully grown tree carries (1 to 4). Auto picks one for the seed and keeps it."
		fb.pressed.connect(_set_fruit.bind(n))
		fruits.add_child(fb)
		_fruit_btns[n] = fb

	_tag_caption = _caption("Tag")
	right.add_child(_tag_caption)
	# a brand new splice doesn't get to choose: it shows the roll (and its odds) instead
	_tag_roll = Label.new()
	_tag_roll.add_theme_font_size_override("font_size", 20)
	right.add_child(_tag_roll)
	_tag_odds = Label.new()
	_tag_odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tag_odds.add_theme_font_size_override("font_size", 12)
	_tag_odds.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	right.add_child(_tag_odds)
	var tags := HBoxContainer.new()
	_tag_row = tags
	tags.add_theme_constant_override("separation", 6)
	right.add_child(tags)
	var tag_group := ButtonGroup.new()
	for tag in Game.TAGS:
		var tb := Button.new()
		tb.text = Game.tag_name(tag)
		tb.toggle_mode = true
		tb.button_group = tag_group
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_color_override("font_pressed_color", Game.tag_color(tag))
		tb.add_theme_color_override("font_hover_pressed_color", Game.tag_color(tag))
		tb.pressed.connect(_set_tag.bind(tag))
		tags.add_child(tb)
		_tag_btns[tag] = tb

	_random_btn = Button.new()
	_random_btn.text = "Randomize look"
	_random_btn.pressed.connect(_randomize)
	right.add_child(_random_btn)

	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_color", Color("#ffc94a"))
	root.add_child(_notice)

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
	_ok.custom_minimum_size = Vector2(190, 38)
	_ok.add_theme_color_override("font_color", Color("#a6ff6e"))
	_ok.pressed.connect(_confirm)
	buttons.add_child(_ok)


func open_new(a: String, b: String) -> void:
	mode = Mode.NEW
	parent_a = a
	parent_b = b
	look = Game.suggest_look(a, b)
	_names = Game.suggest_names(a, b)
	_name_idx = 0
	look.name = _names[0]
	var sa := Game.get_seed(a)
	var sb := Game.get_seed(b)
	_icon_a.texture = SeedArt.texture_for(sa)
	_icon_b.texture = SeedArt.texture_for(sb)
	_label_a.text = "%s (R%d)" % [sa.name, int(sa.rarity)]
	_label_b.text = "%s (R%d)" % [sb.name, int(sb.rarity)]
	_parents_row.visible = true
	_idea_btn.visible = true
	_title.text = "New Splice!"
	_ok.text = "Add to Dictionary"
	_show()


func open_edit(id: String) -> void:
	mode = Mode.EDIT
	edit_id = id
	var s := Game.get_seed(id)
	look = {
		"id": id,  # so the previews show this seed's own block fruit
		"name": s.name, "pattern": int(s.pattern), "colors": [s.colors[0], s.colors[1]],
		"sprout": s.sprout, "pattern_seed": int(s.pattern_seed), "tag": s.get("tag", "farmable"),
		"crop": CropArt.valid_type(s.get("crop"), id),
		"drop": DropLogic.sanitize(s.get("drop"), s.name),
		"fruit_count": int(s.get("fruit_count", 0)),
	}
	_parents_row.visible = false
	_idea_btn.visible = false
	_title.text = "Restyle Seed"
	_ok.text = "Save"
	_show()


## Make your own tier-1 seed from scratch.
func open_add() -> void:
	mode = Mode.ADD
	look = { "name": "", "colors": ["#888888", "#555555"], "sprout": "#7ccf4e", "tag": "farmable",
		"drop": DropLogic.classify("") }
	_parents_row.visible = false
	_idea_btn.visible = false
	_title.text = "Add Tier 1 Seed"
	_randomize()  # fills pattern + colors and updates the color buttons
	_show()


func _show() -> void:
	_name_edit.text = look.name
	_c1.color = Color(look.colors[0])
	_c2.color = Color(look.colors[1])
	_cs.color = Color(look.sprout)
	visible = true
	Audio.play(&"open")
	_update()
	_fit_scroll.call_deferred()
	if not get_viewport().size_changed.is_connected(_fit_scroll):
		get_viewport().size_changed.connect(_fit_scroll)
	_name_edit.grab_focus.call_deferred()
	_name_edit.select_all.call_deferred()


## The middle part is as tall as it needs, but never taller than the window leaves room for.
func _fit_scroll() -> void:
	if _scroll == null or not visible:
		return
	_scroll.custom_minimum_size.y = 0.0
	_panel.reset_size()
	var fixed := _panel.get_combined_minimum_size().y  # title, parents, buttons, margins
	var content: float = _scroll.get_child(0).get_combined_minimum_size().y
	var room := get_viewport_rect().size.y - fixed - 16.0
	_scroll.custom_minimum_size.y = clampf(content, 120.0, maxf(120.0, room))
	_panel.reset_size()


func _set_fruit(n: int) -> void:
	look.fruit_count = n
	_update()


func _update() -> void:
	var name_text := String(look.name).strip_edges()
	var other := Game.find_by_name(name_text)
	_link_id = ""
	var ok := name_text != ""
	_notice.text = ""
	if mode == Mode.NEW and other != "":
		_link_id = other
		_notice.text = "You already have \"%s\" — this splice will become another recipe for it (it keeps its rarity and look)." % Game.get_seed(other).name
	elif mode == Mode.EDIT and other != "" and other != edit_id:
		ok = false
		_notice.text = "Another seed is already called \"%s\"." % name_text
	elif mode == Mode.ADD and other != "":
		ok = false
		_notice.text = "You already have a seed called \"%s\"." % name_text
	if name_text == "":
		_notice.text = "Give your seed a name."

	var shown: Dictionary = Game.get_seed(_link_id) if _link_id != "" else look
	_preview.texture = SeedArt.texture_for(shown)
	var rarity: int
	if mode == Mode.NEW:
		rarity = int(shown.rarity) if _link_id != "" else Game.splice_rarity(parent_a, parent_b)
		var ra := int(Game.get_seed(parent_a).rarity)
		var rb := int(Game.get_seed(parent_b).rarity)
		_rarity_sum.text = "%d + %d = %d" % [ra, rb, ra + rb] if _link_id == "" else "first recipe's rarity"
	elif mode == Mode.ADD:
		rarity = 1
		_rarity_sum.text = "your own tier 1 seed"
	else:
		rarity = int(Game.get_seed(edit_id).rarity)
		_rarity_sum.text = ""
	var tier: Array = SeedArt.rarity_tier(rarity)
	_rarity.text = "Rarity %d · %s" % [rarity, tier[0]]
	_rarity.add_theme_color_override("font_color", tier[1])

	var locked := _link_id != ""
	for i in _pattern_btns.size():
		var b := _pattern_btns[i]
		var l := look.duplicate(true)
		l.pattern = i
		_picture(b).texture = SeedArt.texture_for(l)
		b.set_pressed_no_signal(i == int(look.pattern))
		b.disabled = locked
	_pattern_label.text = SeedArt.PATTERN_NAMES[int(look.pattern)]
	# crop: one button per type, each drawn fully grown in this seed's colors
	var crop_id := CropArt.valid_type(shown.get("crop"), String(shown.get("name", "")))
	var ids := CropArt.type_ids()
	for i in _crop_btns.size():
		var l := look.duplicate(true)
		l.crop = ids[i]
		_picture(_crop_btns[i]).texture = CropArt.texture_for(l, CropArt.Stage.CROP)
		_crop_btns[i].set_pressed_no_signal(ids[i] == crop_id)
		_crop_btns[i].disabled = locked
	_crop_label.text = "  " + CropArt.type_name(crop_id) + ("  (the seed you already have)" if locked else "")
	var grown := shown.duplicate(true)
	grown.crop = crop_id
	for i in _growth.size():
		_growth[i].texture = CropArt.texture_for(grown, CropArt.GROWTH_ORDER[i])
	for c in [_c1, _c2, _cs, _shuffle_btn, _random_btn]:
		c.disabled = locked
	var fruit_n := int(shown.get("fruit_count", 0))
	for n in _fruit_btns:
		_fruit_btns[n].set_pressed_no_signal(n == fruit_n)
		_fruit_btns[n].disabled = locked
	var seed_id := String(shown.get("id", ""))
	_fruit_label.text = "  " + ("Auto (%d)" % CropArt.fruit_count(shown) if fruit_n == 0 else str(fruit_n)) 		+ ("" if seed_id == "" or BlockArt.has_art(seed_id) else "  (draw this seed's block first)")
	var tag: String = shown.get("tag", "farmable")
	for t in _tag_btns:
		_tag_btns[t].set_pressed_no_signal(t == tag)
		_tag_btns[t].disabled = locked
	# New splice: the tag is rolled by chance and can't be picked (you can still edit it later).
	var new_roll := mode == Mode.NEW and _link_id == ""
	_tag_row.visible = mode != Mode.NEW
	_tag_roll.visible = mode == Mode.NEW
	_tag_odds.visible = new_roll
	_tag_caption.text = "Tag  (rolled by chance)" if mode == Mode.NEW else "Tag"
	if mode == Mode.NEW:
		_tag_roll.text = ("Rolled:  %s" if new_roll else "%s  (the seed you already have)") % Game.tag_name(tag)
		_tag_roll.add_theme_color_override("font_color", Game.tag_color(tag))
		_tag_odds.text = "Odds at rarity %d:  %s" % [rarity, Game.tag_odds_text(rarity)]
	# drop
	var drop: Dictionary = DropLogic.sanitize(shown.get("drop"), String(shown.get("name", "")))
	for k in _kind_btns:
		_kind_btns[k].set_pressed_no_signal(k == drop.kind)
		_kind_btns[k].disabled = locked
	var is_bg: bool = drop.kind == "background"
	_collision_btn.visible = not is_bg  # a background is never walked into
	_damage_btn.visible = not is_bg
	_bg_box.visible = is_bg
	_collision_btn.set_pressed_no_signal(drop.collision)
	_collision_btn.text = "Has collision" if drop.collision else "No collision (walk through)"
	_collision_btn.disabled = locked
	_damage_btn.set_pressed_no_signal(drop.damage)
	_damage_btn.disabled = locked
	_light_btn.set_pressed_no_signal(drop.light)
	_light_btn.disabled = locked
	for t in _bg_checks:
		_bg_checks[t].set_pressed_no_signal(drop.bg_tags.has(t))
		_bg_checks[t].disabled = locked
	_drop_caption.text = "Drops: %s" % (DropLogic.drop_name(String(shown.get("name", ""))) if String(shown.get("name", "")).strip_edges() != "" else "…")
	if locked:
		_drop_note.text = "The seed you already have keeps its drop."
	elif drop.auto:
		_drop_note.text = "Guessed from the name (changes as you rename). Click to set it yourself."
	else:
		_drop_note.text = "Set by you. The seed itself never deals damage, only what it drops."

	_ok.disabled = not ok
	match mode:
		Mode.NEW: _ok.text = "Add Recipe" if locked else "Add to Dictionary"
		Mode.ADD: _ok.text = "Add Seed"
		_: _ok.text = "Save"


func _on_name_changed(t: String) -> void:
	look.name = t
	# a drop that is still a guess follows the name; one you set yourself stays
	var d: Dictionary = DropLogic.sanitize(look.get("drop"), t)
	if d.auto:
		look.drop = DropLogic.classify(t)
	_update()


func _set_drop_kind(kind: String) -> void:
	var d: Dictionary = DropLogic.sanitize(look.get("drop"), String(look.name))
	d.kind = kind
	d.auto = false
	look.drop = DropLogic.sanitize(d, String(look.name))  # a background loses collision and damage
	_update()


func _set_collision(on: bool) -> void:
	var d: Dictionary = DropLogic.sanitize(look.get("drop"), String(look.name))
	d.collision = on
	if not on:
		d.damage = false  # nothing to collide with, so nothing to hurt
	d.auto = false
	look.drop = d
	_update()


func _set_damage(on: bool) -> void:
	var d: Dictionary = DropLogic.sanitize(look.get("drop"), String(look.name))
	d.damage = on
	if on:
		d.collision = true  # damage is dealt on collision
	d.auto = false
	look.drop = d
	_update()


func _set_light(on: bool) -> void:
	var d: Dictionary = DropLogic.sanitize(look.get("drop"), String(look.name))
	d.light = on
	d.auto = false
	look.drop = DropLogic.sanitize(d, String(look.name))
	_update()


func _set_bg_tag(on: bool, tag: String) -> void:
	var d: Dictionary = DropLogic.sanitize(look.get("drop"), String(look.name))
	var tags: Array = d.bg_tags.duplicate()
	if on and not tags.has(tag):
		tags.append(tag)
	elif not on:
		tags.erase(tag)
	d.bg_tags = tags
	d.auto = false
	look.drop = DropLogic.sanitize(d, String(look.name))
	_update()


func _shuffle() -> void:
	look.pattern_seed = randi_range(0, 99999)
	_update()


func _set_tag(tag: String) -> void:
	look.tag = tag
	_update()


func _set_crop(id: String) -> void:
	look.crop = id
	_update()


func _set_pattern(i: int) -> void:
	look.pattern = i
	_update()


## which: 0 = color 1, 1 = color 2, 2 = sprout
func _set_color(c: Color, which: int) -> void:
	var hex := "#" + c.to_html(false)
	if which == 2:
		look.sprout = hex
	else:
		look.colors[which] = hex
	_update()


func _next_name() -> void:
	if _names.is_empty():
		return
	_name_idx = (_name_idx + 1) % _names.size()
	look.name = _names[_name_idx]
	_name_edit.text = look.name
	_update()


func _randomize() -> void:
	var c1 := Color.from_hsv(randf(), randf_range(0.35, 0.9), randf_range(0.45, 0.95))
	var c2 := Color.from_hsv(fposmod(c1.h + randf_range(0.08, 0.5), 1.0), randf_range(0.3, 0.9), randf_range(0.3, 0.95))
	var cs := Color.from_hsv(randf_range(0.18, 0.42), randf_range(0.45, 0.8), randf_range(0.6, 0.95))
	look.colors = ["#" + c1.to_html(false), "#" + c2.to_html(false)]
	look.sprout = "#" + cs.to_html(false)
	look.pattern = randi_range(0, SeedArt.Pattern.size() - 1)
	look.pattern_seed = randi_range(0, 99999)
	look.crop = CropArt.type_ids().pick_random()
	_c1.color = c1
	_c2.color = c2
	_cs.color = cs
	_update()


func _confirm() -> void:
	if _ok.disabled or not visible:
		return
	visible = false
	if mode == Mode.EDIT:
		edited.emit(edit_id, look)
	elif mode == Mode.ADD:
		added_custom.emit(look)
	elif _link_id != "":
		linked.emit(_link_id)
	else:
		created.emit(look)


func _cancel() -> void:
	if not visible:
		return
	visible = false
	cancelled.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.65, 0.62, 0.78))
	return l


func _small_icon() -> PixelPicture:
	var t := PixelPicture.new()
	t.custom_minimum_size = Vector2(64, 64)
	return t


## A picture button: its art is a PixelPicture filling the button (2x at the normal window size).
func _add_picture(b: Button) -> void:
	b.custom_minimum_size = Vector2(72, 72)
	var pic := PixelPicture.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 4
	pic.offset_top = 4
	pic.offset_right = -4
	pic.offset_bottom = -4
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	b.set_meta(&"picture", pic)


func _picture(b: Button) -> PixelPicture:
	return b.get_meta(&"picture")


func _color_button(caption: String, parent: Control, on_change: Callable) -> ColorPickerButton:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var l := Label.new()
	l.text = caption
	l.add_theme_font_size_override("font_size", 12)
	box.add_child(l)
	var b := ColorPickerButton.new()
	b.edit_alpha = false
	b.custom_minimum_size = Vector2(0, 34)
	b.color_changed.connect(on_change)
	var picker := b.get_picker()
	for p in PRESETS:
		picker.add_preset(Color(p))
	box.add_child(b)
	return b
