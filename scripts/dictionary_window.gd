class_name DictionaryWindow
extends Control
## The Dictionary (the Dictionary button in the top right corner): every seed sorted into Blocks,
## Decorations and Backgrounds, with its block texture, rarity, material, hardness and every tag.
## Click a seed to see its 4 block boxes and its 5 growth stages big and crisp, and all of its
## tags written out. Double-click (or the Edit button) opens the seed editor.
## Approved seeds (on the official list, see approvals.gd) show the stamp and who made them.
## The Graveyard tab lists every seed that did not make it into the game.

signal edit_requested(id: String)

const THUMB := 64  ## block textures in the list are drawn at 2x (32 -> 64)
const GROUP_KIND := 0
const GROUP_MATERIAL := 1
const GRAVE_TAB := 4
const COLS := 8

var _search: LineEdit
var _tabs: TabBar
var _sort: OptionButton
var _light_only: CheckBox
var _tree: Tree
var _summary: Label
var _blocks: Array[PixelPicture] = []
var _stages: Array[PixelPicture] = []
var _detail_name: Label
var _detail_text: RichTextLabel
var _edit_btn: Button
var _grave_btn: Button
var _remove_btn: Button
var _rsr: OptionButton
var _art_ok: CheckBox
var _dev_row: HBoxContainer
var _grave: Array = []  # Approvals.graveyard() while the Graveyard tab is open
var _selected := ""
var _collapsed := {}  # group key -> true
var _thumbs := {}     # id -> [BlockArt.version, ImageTexture]
var _shown_ids: Array = []
var _placeholder: ImageTexture
var _rebuilding := false


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
	panel.custom_minimum_size = Vector2(1180, 640)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := Label.new()
	title.text = "Dictionary"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#a6ff6e"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_dialog)
	head.add_child(close)

	_tabs = TabBar.new()
	for t in ["All", "Blocks", "Decorations", "Backgrounds", "Graveyard"]:
		_tabs.add_tab(t)
	_tabs.tab_changed.connect(func(_i): refresh())
	root.add_child(_tabs)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	_search = LineEdit.new()
	_search.placeholder_text = "Search seeds..."
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): refresh())
	bar.add_child(_search)
	_sort = OptionButton.new()
	for n in ["Sort: name", "Sort: rarity (highest)", "Sort: newest", "Sort: Mycoras (most)"]:
		_sort.add_item(n)
	_sort.item_selected.connect(func(_i): refresh())
	bar.add_child(_sort)
	_light_only = CheckBox.new()
	_light_only.text = "Emits light only"
	_light_only.toggled.connect(func(_on): refresh())
	bar.add_child(_light_only)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	_tree = Tree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = COLS
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for c in COLS:
		_tree.set_column_title(c, ["Seed", "R", "Material", "Hardness", "Seed tag", "Drop", "Mycoras", "Approved"][c])
	_tree.set_column_expand(0, true)
	_tree.set_column_custom_minimum_width(0, 200)
	for c in [[1, 34], [2, 100], [3, 90], [4, 104], [5, 120], [6, 76], [7, 118]]:
		_tree.set_column_expand(c[0], false)
		_tree.set_column_custom_minimum_width(c[0], c[1])
	_tree.item_selected.connect(_on_selected)
	_tree.item_activated.connect(func():
		if Game.seeds.has(_selected):
			edit_requested.emit(_selected))
	_tree.item_collapsed.connect(func(item: TreeItem):
		var key: Variant = item.get_metadata(0)
		if typeof(key) == TYPE_STRING and String(key).begins_with("group:"):
			_collapsed[key] = item.collapsed)
	body.add_child(_tree)

	# right: the picked seed in detail
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(340, 0)
	detail.add_theme_constant_override("separation", 6)
	body.add_child(detail)
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 20)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_detail_name)
	detail.add_child(_caption("Block  (4 boxes; 1 is the block, the others are spare for animation)"))
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 4)
	detail.add_child(brow)
	for i in BlockArt.FRAMES:
		_blocks.append(_picture(brow))
	detail.add_child(_caption("Grows:  seed › planted › sprout › sapling › crop"))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 4)
	detail.add_child(srow)
	for stage in CropArt.GROWTH_ORDER:
		var p := _picture(srow, 64)
		p.tooltip_text = CropArt.STAGE_NAMES[stage]
		_stages.append(p)
	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = false
	_detail_text.scroll_active = true
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(_detail_text)
	_edit_btn = Button.new()
	_edit_btn.text = "Edit this seed"
	_edit_btn.pressed.connect(func():
		if Game.seeds.has(_local_id(_selected)):
			edit_requested.emit(_local_id(_selected)))
	_grave_btn = Button.new()
	_grave_btn.tooltip_text = "Seeds in the graveyard did not make it into the game: no approval stamp.\nWhen an update is published, your graveyard ships with it."
	_grave_btn.pressed.connect(func():
		var id := _local_id(_selected)
		if id != "":
			Game.set_denied(id, not Game.seeds[id].get("denied", false)))
	_remove_btn = Button.new()
	_remove_btn.text = "Remove from graveyard"
	_remove_btn.tooltip_text = "Take it out of the graveyard for good: it isn't listed, and your next push / update leaves it out.\n(A seed of yours stays in your game.)"
	_remove_btn.pressed.connect(func():
		if not _selected.begins_with("grave#"):
			return
		var i := int(_selected.substr(6))
		if i < _grave.size():
			Game.remove_from_graveyard(String(_grave[i].seed.name))
			_selected = ""
			refresh())
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	for b in [_edit_btn, _grave_btn, _remove_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(b)
	detail.add_child(btns)
	# the developer's verdict: RSR (6-10) and whether the block art is approved
	_dev_row = HBoxContainer.new()
	_dev_row.add_theme_constant_override("separation", 6)
	_dev_row.visible = DevMode.on()
	detail.add_child(_dev_row)
	_rsr = OptionButton.new()
	_rsr.add_item("RSR: not rated", 0)
	for r in range(6, 11):
		_rsr.add_item("RSR %d  (x%s)" % [r, str(Bank.RSR_MULT[r])], r)
	_rsr.tooltip_text = "RyeScale Rating: how much you like this seed. Ships with your next update:\nan approved seed makes x1 (6) to x4 (10) more Mycoras."
	_rsr.item_selected.connect(func(i):
		var id := _local_id(_selected)
		if id != "":
			Game.set_rating(id, _rsr.get_item_id(i)))
	_rsr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dev_row.add_child(_rsr)
	_art_ok = CheckBox.new()
	_art_ok.text = "Art approved"
	_art_ok.tooltip_text = "Approved with its art: x25 Mycoras instead of x10 (ships with your next update)"
	_art_ok.toggled.connect(func(on):
		var id := _local_id(_selected)
		if id != "" and on != Game.art_approved(id):
			Game.set_art_ok(id, on))
	_dev_row.add_child(_art_ok)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	root.add_child(_summary)

	Game.seeds_changed.connect(func():
		if visible:
			refresh())


func open() -> void:
	visible = true
	refresh()
	Audio.play(&"open")


func close_dialog() -> void:
	visible = false


func open_on(id: String) -> void:
	_selected = id
	open()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	return l


func _picture(parent: Control, px := 64) -> PixelPicture:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0e0b16")
	sb.border_color = Color("#3b3150")
	sb.set_border_width_all(1)
	sb.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	parent.add_child(frame)
	var p := PixelPicture.new()
	p.custom_minimum_size = Vector2(px, px)
	frame.add_child(p)
	return p


## The block texture drawn 2x for the list (a gray placeholder if the seed has no block art yet).
func _thumb(id: String) -> Texture2D:
	var cached: Variant = _thumbs.get(id)
	if cached != null and cached[0] == BlockArt.version:
		return cached[1]
	var art := BlockArt.get_art(id)
	var tex: ImageTexture
	if art != null and not art.get_region(Rect2i(0, 0, BlockArt.SIZE, BlockArt.SIZE)).is_invisible():
		var img := art.get_region(Rect2i(0, 0, BlockArt.SIZE, BlockArt.SIZE))
		img.resize(THUMB, THUMB, Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(img)
	else:
		tex = _placeholder_texture()
	_thumbs[id] = [BlockArt.version, tex]
	return tex


func _placeholder_texture() -> ImageTexture:
	if _placeholder == null:
		var img := Image.create_empty(THUMB, THUMB, false, Image.FORMAT_RGBA8)
		for y in THUMB:
			for x in THUMB:
				var edge := x < 2 or y < 2 or x >= THUMB - 2 or y >= THUMB - 2
				var dark := ((x / 8) + (y / 8)) % 2 == 0
				img.set_pixel(x, y, Color("#4a3d66") if edge else (Color("#1c1628") if dark else Color("#231c32")))
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder


func refresh() -> void:
	if _tree == null:
		return
	_rebuilding = true
	_tree.clear()
	var root := _tree.create_item()
	var q := _search.text.strip_edges().to_lower()
	if _tabs.current_tab == GRAVE_TAB:
		_refresh_graveyard(root, q)
		return
	var kind_tab: String = ["", "block", "decoration", "background"][_tabs.current_tab]
	var ids: Array = Game.order.filter(func(id):
		var s: Dictionary = Game.seeds[id]
		var d: Dictionary = s.get("drop", {})
		if q != "" and not String(s.name).to_lower().contains(q):
			return false
		if s.get("denied", false):
			return false  # it's in the Graveyard tab
		if kind_tab != "" and d.get("kind", "block") != kind_tab:
			return false
		if _light_only.button_pressed and not d.get("light", false):
			return false
		return true)
	match _sort.selected:
		0: ids.sort_custom(func(a, b): return String(Game.seeds[a].name).naturalnocasecmp_to(Game.seeds[b].name) < 0)
		1: ids.sort_custom(func(a, b):
			var ra := int(Game.seeds[a].rarity)
			var rb := int(Game.seeds[b].rarity)
			return ra > rb if ra != rb else String(Game.seeds[a].name).naturalnocasecmp_to(Game.seeds[b].name) < 0)
		2: ids.reverse()
		3: ids.sort_custom(func(a, b):
			var ma := Mycora.average_per_break(Game.seeds[a])
			var mb := Mycora.average_per_break(Game.seeds[b])
			return ma > mb if ma != mb else String(Game.seeds[a].name).naturalnocasecmp_to(Game.seeds[b].name) < 0)
	_shown_ids = ids
	# the All tab is grouped by kind, the others by material
	var by_kind: bool = kind_tab == ""
	var groups: Array = DropLogic.KINDS.duplicate() if by_kind else CategoryLogic.MATERIALS.duplicate()
	var selected_item: TreeItem = null
	for g in groups:
		var members: Array = ids.filter(func(id):
			var s: Dictionary = Game.seeds[id]
			return s.get("drop", {}).get("kind", "block") == g if by_kind else s.get("category", {}).get("material", "other") == g)
		if members.is_empty():
			continue
		var head := _tree.create_item(root)
		var key := "group:%s:%s" % [kind_tab, g]
		head.set_metadata(0, key)
		head.set_text(0, "%s   (%d)" % [DropLogic.KIND_PLURALS[g] if by_kind else CategoryLogic.material_name(g), members.size()])
		head.set_custom_color(0, Color("#ffc94a") if by_kind else CategoryLogic.MATERIAL_COLORS.get(g, Color("#ffc94a")))
		head.set_expand_right(0, true)
		for c in COLS:
			head.set_selectable(c, false)
		head.collapsed = _collapsed.get(key, false)
		for id in members:
			var it := _row(head, id)
			if id == _selected:
				selected_item = it
	var lights := ids.filter(func(id): return Game.seeds[id].get("drop", {}).get("light", false)).size()
	_summary.text = "%d of %d seeds shown  ·  %d emit light  ·  %d with block art  ·  %d approved  ·  double-click a seed to edit it" % [
		ids.size(), Game.seeds.size(), lights, ids.filter(func(id): return BlockArt.has_art(id)).size(),
		ids.filter(func(id): return Approvals.is_approved(Game.seeds[id])).size()]
	_rebuilding = false
	if selected_item == null:
		_selected = ids[0] if not ids.is_empty() and not ids.has(_selected) else _selected
	if selected_item:
		selected_item.get_parent().collapsed = false
		selected_item.select(0)
		_tree.scroll_to_item(selected_item, true)
	_show_detail(_selected)


func _row(parent: TreeItem, id: String) -> TreeItem:
	var s: Dictionary = Game.seeds[id]
	var d: Dictionary = s.get("drop", {})
	var c: Dictionary = s.get("category", {})
	var tier: Array = SeedArt.rarity_tier(int(s.rarity))
	var it := _tree.create_item(parent)
	it.set_metadata(0, id)
	it.set_text(0, s.name)
	it.set_icon(0, _thumb(id))
	it.set_icon_max_width(0, THUMB)
	it.set_custom_color(0, (tier[1] as Color).lerp(Color.WHITE, 0.35))
	it.set_text(1, str(int(s.rarity)))
	it.set_custom_color(1, tier[1])
	it.set_text(2, CategoryLogic.material_name(c.get("material", "other")))
	it.set_custom_color(2, CategoryLogic.MATERIAL_COLORS.get(c.get("material", "other"), Color.WHITE))
	it.set_text(3, CategoryLogic.hardness_name(int(c.get("hardness", 3))))
	it.set_text(4, Game.tag_name(s.get("tag", "")))
	it.set_custom_color(4, Game.tag_color(s.get("tag", "")))
	var light: bool = d.get("light", false)
	var drop_text := DropLogic.short_text(d)
	if light:
		drop_text += "  ·  Light"
	it.set_text(5, drop_text)
	it.set_custom_color(5, DropLogic.LIGHT_COLOR if light else DropLogic.short_color(d))
	it.set_tooltip_text(0, "%s drops %s\n%s" % [s.name, DropLogic.drop_name(s.name), DropLogic.describe(d)])
	it.set_text(6, Mycora.range_text(s))
	it.set_custom_color(6, Mycora.COLOR)
	it.set_tooltip_text(6, "Mycoras when the block is broken: %s\nWhen the crop is harvested: %s" % [Mycora.break_text(s), Mycora.harvest_text(s)])
	_approved_cell(it, s)
	return it


func _approved_cell(it: TreeItem, s: Dictionary) -> void:
	var by := Approvals.approved_by(s)
	if by == "":
		return
	it.set_icon(7, Approvals.STAMP_SMALL)
	it.set_icon_max_width(7, 22)
	it.set_text(7, by)
	it.set_custom_color(7, Approvals.STAMP_COLOR)
	it.set_tooltip_text(7, "Approved: on the official seed list  ·  made by %s" % by)


## The Graveyard tab: seeds that did not make it into the game.
func _refresh_graveyard(root: TreeItem, q: String) -> void:
	_grave = Approvals.graveyard()
	var head := _tree.create_item(root)
	head.set_text(0, "Graveyard   (%d)" % _grave.size())
	head.set_custom_color(0, Color("#a19bb8"))
	head.set_expand_right(0, true)
	for c in COLS:
		head.set_selectable(c, false)
	var selected_item: TreeItem = null
	var first_item: TreeItem = null
	for i in _grave.size():
		var g: Dictionary = _grave[i]
		var s: Dictionary = g.seed
		if q != "" and not String(s.name).to_lower().contains(q):
			continue
		var key := "grave#%d" % i
		var it := _tree.create_item(head)
		it.set_metadata(0, key)
		it.set_text(0, s.name)
		it.set_icon(0, _seed_thumb(s))
		it.set_icon_max_width(0, THUMB)
		it.set_custom_color(0, Color("#a19bb8"))
		it.set_text(1, str(int(s.rarity)))
		it.set_custom_color(1, SeedArt.rarity_tier(int(s.rarity))[1])
		var c: Dictionary = s.get("category", {})
		if not c.is_empty():
			it.set_text(2, CategoryLogic.material_name(c.get("material", "other")))
		it.set_text(4, Game.tag_name(s.get("tag", "")))
		it.set_custom_color(4, Game.tag_color(s.get("tag", "")))
		it.set_text(7, "made by %s" % _maker(s))
		it.set_custom_color(7, Color("#8a85a0"))
		if first_item == null:
			first_item = it
		if key == _selected:
			selected_item = it
	_summary.text = "%d seeds in the graveyard: they did not make it into the game  ·  %s" % [_grave.size(),
		"select one of yours to bring it back" if not _grave.is_empty() else "send a seed here from its page in the other tabs"]
	_rebuilding = false
	if selected_item == null:
		selected_item = first_item
		_selected = String(first_item.get_metadata(0)) if first_item else ""
	if selected_item:
		selected_item.select(0)
		_tree.scroll_to_item(selected_item, true)
	_show_detail(_selected)


func _maker(s: Dictionary) -> String:
	var by := String(s.get("made_by", "")).strip_edges()
	if by == "":
		by = Approvals.publisher  # seeds from before names existed: the developer's
	return by if by != "" else "unknown"


## A seed picture drawn 2x for the graveyard list.
func _seed_thumb(s: Dictionary) -> Texture2D:
	var img := SeedArt.render(s)
	img.resize(THUMB, THUMB, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## The seed of yours behind a list key ("grave#3" or an id), or "".
func _local_id(key: String) -> String:
	if key.begins_with("grave#"):
		var i := int(key.substr(6))
		return String(_grave[i].local_id) if i < _grave.size() else ""
	return key if Game.seeds.has(key) else ""


func _on_selected() -> void:
	if _rebuilding:
		return
	var it := _tree.get_selected()
	if it == null or typeof(it.get_metadata(0)) != TYPE_STRING or String(it.get_metadata(0)).begins_with("group:") or String(it.get_metadata(0)) == "":
		return
	_selected = it.get_metadata(0)
	_show_detail(_selected)


func _show_detail(key: String) -> void:
	var id := _local_id(key)
	var s: Dictionary = Game.seeds.get(id, {})
	if s.is_empty() and key.begins_with("grave#") and int(key.substr(6)) < _grave.size():
		s = _grave[int(key.substr(6))].seed  # a graveyard seed you don't have: draw what we know
	_edit_btn.disabled = id == ""
	_grave_btn.disabled = id == ""
	_grave_btn.text = "Bring back from the graveyard" if id != "" and Game.seeds[id].get("denied", false) else "Send to graveyard"
	_dev_row.visible = DevMode.on() and id != ""
	_remove_btn.visible = DevMode.on() and key.begins_with("grave#")
	if id != "":
		_rsr.select(_rsr.get_item_index(int(Game.seeds[id].get("rsr", 0))))
		_art_ok.set_pressed_no_signal(Game.art_approved(id))
		_art_ok.disabled = not BlockArt.has_art(id)
	for p in _blocks + _stages:
		p.texture = null
	if s.is_empty():
		_detail_name.text = "Nothing here"
		_detail_text.text = ""
		return
	var tier: Array = SeedArt.rarity_tier(int(s.rarity))
	_detail_name.text = s.name
	_detail_name.add_theme_color_override("font_color", (tier[1] as Color).lerp(Color.WHITE, 0.3))
	var art := BlockArt.get_art(id) if id != "" else null
	for i in BlockArt.FRAMES:
		if art != null:
			var frame := art.get_region(Rect2i(i * BlockArt.SIZE, 0, BlockArt.SIZE, BlockArt.SIZE))
			_blocks[i].texture = null if frame.is_invisible() else ImageTexture.create_from_image(frame)
	for i in _stages.size():
		_stages[i].texture = CropArt.texture_for(s, CropArt.GROWTH_ORDER[i])
	var d: Dictionary = DropLogic.sanitize(s.get("drop"), String(s.name))
	var c: Dictionary = s.get("category", {})
	var lines := PackedStringArray()
	var by := Approvals.approved_by(s) if id != "" else ""
	if by != "":
		lines.append("[img=22x22]%s[/img] [color=#ffb347]Approved  ·  made by %s[/color]" % [Approvals.STAMP_SMALL.resource_path, by])
	elif s.get("denied", false) or key.begins_with("grave#"):
		lines.append("[color=#a19bb8]In the graveyard: this seed did not make it into the game[/color]")
	lines.append("[color=#ffc94a]Made by[/color]  %s" % _maker(s))
	lines.append("[color=#ffc94a]Rarity[/color]  %d  (%s)" % [int(s.rarity), tier[0]])
	if id != "":
		var inf := Approvals.info(s)
		var rsr := int(inf.get("rsr", 0))
		lines.append("[color=#ffc94a]Makes[/color]  [color=#7dffc0]%s Mycoras every 3 s[/color]  %s%s" % [Bank.fmt(Bank.seed_rate(s)) if Bank.seed_rate(s) >= 10 else "%.1f" % Bank.seed_rate(s),
			"(x%s: %s%s)" % [str(Bank.boost(s)), "approved with its art" if inf.get("art", false) else "approved", ", RSR %d" % rsr if rsr > 0 else ""] if not inf.is_empty() else "",
			"" if Bank.produces(id) else "  [color=#a19bb8]· locked: unlock it in the Seed Chest[/color]"])
	lines.append("[color=#ffc94a]Mycoras when broken[/color]  [color=#7dffc0]%s[/color]" % Mycora.break_text(s))
	lines.append("[color=#ffc94a]Mycoras when harvested[/color]  [color=#7dffc0]%s[/color]" % Mycora.harvest_text(s))
	lines.append("[color=#ffc94a]Seed tag[/color]  [color=#%s]%s[/color]" % [Game.tag_color(s.get("tag", "")).to_html(false), Game.tag_name(s.get("tag", ""))])
	lines.append("[color=#ffc94a]Drops[/color]  %s  (%s)" % [DropLogic.drop_name(s.name), DropLogic.KIND_NAMES[d.kind]])
	lines.append("[color=#ffc94a]Material[/color]  %s  ·  %s%s" % [CategoryLogic.material_name(c.get("material", "other")),
		CategoryLogic.hardness_name(int(c.get("hardness", 3))), "  (a guess)" if c.get("status", "auto") == "auto" else ""])
	if d.kind == "background":
		lines.append("[color=#ffc94a]Background checklist[/color]")
		for t in DropLogic.BG_TAGS:
			var on: bool = d.bg_tags.has(t)
			lines.append("   [color=#%s]%s %s[/color]" % ["a6ff6e" if on else "6f6a80", "(x)" if on else "( )", DropLogic.BG_TAG_NAMES[t]])
	else:
		lines.append("[color=#ffc94a]Collision[/color]  %s" % ("Solid" if d.collision else "Walk through"))
		lines.append("[color=#ffc94a]Collision damage[/color]  %s" % ("[color=#ff6b6b]Yes[/color]" if d.damage else "No"))
		lines.append("[color=#ffc94a]Emits light[/color]  %s" % ("[color=#ffe066]Yes[/color]" if d.light else "No"))
	lines.append("[color=#ffc94a]Block art[/color]  %s" % ("%d of %d boxes drawn" % [BlockArt.frame_count(id), BlockArt.FRAMES] if art != null else "not drawn yet"))
	lines.append("[color=#ffc94a]Crop[/color]  %s%s" % [CropArt.type_name(String(s.get("crop", ""))),
		"  ·  %d block fruit" % CropArt.fruit_count(s) if BlockArt.fruit(id) != null else ""])
	var parents: Array = s.get("parents", []) if id != "" else []
	if id == "":
		var pn: Array = s.get("parent_names", [])
		lines.append("[color=#ffc94a]Made[/color]  %s" % (" + ".join(pn) if pn.size() == 2 else "unknown"))
	elif parents.is_empty():
		lines.append("[color=#ffc94a]Made[/color]  %s tier 1 seed" % ("your own" if s.get("custom", false) else "base"))
	else:
		lines.append("[color=#ffc94a]Made[/color]  %s + %s" % [Game.get_seed(parents[0]).get("name", "?"), Game.get_seed(parents[1]).get("name", "?")])
	if id != "":
		lines.append("[color=#8a85a0]%s[/color]" % ("Drop set by you" if not d.auto else "Drop guessed from the name"))
	_detail_text.text = "\n".join(lines)
