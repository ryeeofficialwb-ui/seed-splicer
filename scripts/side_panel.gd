class_name SidePanel
extends PanelContainer
## The dictionary: every seed you have. Click or drag a seed into the void, double-click (or
## right-click) to edit it. The splice list lives in its own floating window (SplicesWindow).

signal spawn_requested(id: String)
## discard_spawn is true for a double-click: its first click already dropped a copy into the void.
signal edit_requested(id: String, discard_spawn: bool)
signal clear_void_requested
signal add_seed_requested
signal shown_changed(shown: bool)

const MIN_WIDTH := 320.0  ## narrower than this and the footer buttons don't fit
const MAX_WIDTH := 640.0
const DEFAULT_WIDTH := 380.0

var _list: SeedList
var _search: LineEdit
var _sort: OptionButton
var _filter: OptionButton
var _drop_filter: OptionButton
var _count: Label
var categories: CategoriesTab
var _tabs: TabContainer


class SeedList extends ItemList:
	signal spawn(id: String)
	signal edit(id: String, discard_spawn: bool)
	var _pressed := -1
	var stamped := {}  ## item index -> [name, "  ·  R36"]: drawn with the approval stamp after the rarity
	const STAMP := 22.0

	func _ready() -> void:
		resized.connect(fit_stamped)

	## A stamped row keeps its rarity and stamp in view: a long name is shortened instead.
	func fit_stamped() -> void:
		if stamped.is_empty() or item_count == 0:
			return
		var font := get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var avail := get_item_rect(0).size.x - (fixed_icon_size.x + get_theme_constant("icon_margin") + 2.0) - STAMP - 14.0
		for idx in stamped:
			if idx >= item_count:
				continue
			var seed_name: String = stamped[idx][0]
			var tail: String = stamped[idx][1]
			var text := seed_name + tail
			var cut := seed_name.length()
			while cut > 3 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
				cut -= 1
				text = seed_name.left(cut).strip_edges() + "…" + tail
			if get_item_text(idx) != text:
				set_item_text(idx, text)
		queue_redraw()

	## The approval stamp right after "Name  ·  R36" (ItemList has one icon per row, so it is
	## drawn on top of the list).
	func _draw() -> void:
		if stamped.is_empty():
			return
		var font := get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var scroll := get_v_scroll_bar().value if get_v_scroll_bar().visible else 0.0
		for idx in stamped:
			if idx >= item_count:
				continue
			var r := get_item_rect(idx)
			r.position.y -= scroll
			if r.end.y < 0.0 or r.position.y > size.y:
				continue
			var text_x := r.position.x + fixed_icon_size.x + get_theme_constant("icon_margin") + 2.0
			var x := minf(text_x + font.get_string_size(get_item_text(idx), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 5.0, r.end.x - STAMP - 2.0)
			draw_texture_rect(Approvals.STAMP_SMALL, Rect2(Vector2(x, r.get_center().y - STAMP / 2.0).round(), Vector2(STAMP, STAMP)), false)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null:
			return
		var idx := get_item_at_position(mb.position, true)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click and idx >= 0:
					_pressed = -1
					edit.emit(get_item_metadata(idx), true)
					accept_event()
					return
				_pressed = idx
			else:
				if idx >= 0 and idx == _pressed and not get_viewport().gui_is_dragging():
					spawn.emit(get_item_metadata(idx))
				_pressed = -1
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and idx >= 0:
			edit.emit(get_item_metadata(idx), false)

	func _get_drag_data(at: Vector2) -> Variant:
		var idx := get_item_at_position(at, true)
		_pressed = -1
		if idx < 0:
			return null
		var id: String = get_item_metadata(idx)
		var pv := TextureRect.new()
		pv.texture = get_item_icon(idx)
		pv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.size = Vector2(96, 96)
		pv.position = -pv.size / 2.0
		pv.modulate.a = 0.85
		var holder := Control.new()
		holder.add_child(pv)
		set_drag_preview(holder)
		return { "seed_id": id }


## Width in pixels (the panel is dragged wider/narrower with the SideGrip). Saved on save_width().
func set_width(w: float) -> void:
	custom_minimum_size = Vector2(clampf(w, MIN_WIDTH, MAX_WIDTH), 0)


func save_width() -> void:
	UserSettings.set_value("panels", "side_width", custom_minimum_size.x)


func show_panel(on: bool) -> void:
	visible = on
	UserSettings.set_value("panels", "side_visible", on)
	shown_changed.emit(on)


func _ready() -> void:
	set_width(float(UserSettings.get_value("panels", "side_width", DEFAULT_WIDTH)))
	visible = bool(UserSettings.get_value("panels", "side_visible", true))
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_tabs = TabContainer.new()
	var tabs := _tabs
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	var seeds_tab := VBoxContainer.new()
	seeds_tab.name = "Seeds"
	seeds_tab.add_theme_constant_override("separation", 6)
	tabs.add_child(seeds_tab)

	var row := HBoxContainer.new()
	seeds_tab.add_child(row)
	_search = LineEdit.new()
	_search.placeholder_text = "Search seeds..."
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): refresh_seeds())
	row.add_child(_search)
	_sort = SeedSort.make_sort_button(SeedSort.NEWEST)
	_sort.item_selected.connect(func(_i): refresh_seeds())
	row.add_child(_sort)

	var filters := HBoxContainer.new()
	seeds_tab.add_child(filters)
	_filter = SeedSort.make_filter_button()
	_drop_filter = SeedSort.make_drop_filter_button()
	for f in [_filter, _drop_filter]:
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f.fit_to_longest_item = false  # share the row; the full text shows in the dropdown
		f.clip_text = true
		f.item_selected.connect(func(_i): refresh_seeds())
		filters.add_child(f)

	_list = SeedList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.fixed_icon_size = Vector2i(48, 48)
	_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_list.icon_mode = ItemList.ICON_MODE_LEFT
	_list.max_text_lines = 2  # a long name wraps onto a second line
	_list.select_mode = ItemList.SELECT_SINGLE
	_list.add_theme_constant_override("v_separation", 6)
	_list.spawn.connect(func(id): spawn_requested.emit(id))
	_list.edit.connect(func(id, discard): edit_requested.emit(id, discard))
	seeds_tab.add_child(_list)

	var tip := Label.new()
	tip.text = "Click or drag into the void  ·  Double-click to edit"
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	seeds_tab.add_child(tip)

	categories = CategoriesTab.new()
	categories.name = "Categories"  # the tab's title
	tabs.add_child(categories)

	_count = Label.new()
	_count.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	root.add_child(_count)
	var add := Button.new()
	add.text = "+ Add Seed"
	add.tooltip_text = "Make your own Tier 1 seed"
	add.add_theme_color_override("font_color", Color("#a6ff6e"))
	add.pressed.connect(func(): add_seed_requested.emit())
	root.add_child(add)
	# (importing / exporting lists and sprite sheets, the sprites folder and Reset Progress are in Settings)
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	_footer_button(buttons, "Clear Void", "Remove every seed floating in the void", clear_void_requested)

	Game.seeds_changed.connect(refresh_seeds)
	Game.recipes_changed.connect(_update_count)
	refresh_seeds()


func _footer_button(parent: Control, text: String, tip: String, sig: Signal) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(sig.emit)
	parent.add_child(b)


func refresh_seeds() -> void:
	var ids: Array = Game.order.duplicate()
	var q := _search.text.strip_edges().to_lower()
	if q != "":
		ids = ids.filter(func(id): return String(Game.seeds[id].name).to_lower().contains(q))
	ids = SeedSort.sort_ids(SeedSort.filter_drops(SeedSort.filter_ids(ids, _filter.selected), _drop_filter.selected), _sort.selected)
	_list.clear()
	_list.stamped.clear()
	for id in ids:
		var s: Dictionary = Game.seeds[id]
		var r := int(s.rarity)
		var tier: Array = SeedArt.rarity_tier(r)
		# only the name and rarity: every other tag (farmable, collision...) is in the Dictionary
		var by := Approvals.approved_by(s)
		var i := _list.add_item("%s  ·  R%d" % [s.name, r], SeedArt.texture_for(s))
		_list.set_item_metadata(i, id)
		_list.set_item_custom_fg_color(i, tier[1].lerp(Color.WHITE, 0.35))
		if by != "":
			_list.stamped[i] = [String(s.name), "  ·  R%d" % r]
		_list.set_item_tooltip(i, ("Approved seed  ·  made by %s
" % by if by != "" else "") + _origin_text(s))
	_list.fit_stamped.call_deferred()
	_update_count()


func _origin_text(s: Dictionary) -> String:
	var parents: Array = s.get("parents", [])
	var tag := Game.tag_name(s.get("tag", ""))
	var cat: Dictionary = s.get("category", {})
	var drops := "Drops %s: %s\nCategory: %s%s" % [DropLogic.drop_name(s.name), DropLogic.describe(s.get("drop", {})),
		CategoryLogic.describe(cat), "  (a guess)" if cat.get("status", "auto") == "auto" else ""]
	if parents.is_empty():
		return "%s — %s tier 1 seed · %s\n%s" % [s.name, "your own" if s.get("custom", false) else "base", tag, drops]
	var a := Game.get_seed(parents[0])
	var b := Game.get_seed(parents[1])
	return "%s = %s + %s · %s\n%s" % [s.name, a.get("name", "?"), b.get("name", "?"), tag, drops]


func _update_count() -> void:
	if _count:
		var shown := " (%d shown)" % _list.item_count if _list.item_count != Game.seeds.size() else ""
		_count.text = "%d seeds discovered%s  ·  %d splices" % [Game.seeds.size(), shown, Game.recipes.size()]
