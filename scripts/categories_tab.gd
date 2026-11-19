class_name CategoriesTab
extends VBoxContainer
## The Categories tab: every seed's drop sorted by MATERIAL or by HARDNESS (see category_logic.gd).
## Each row: the seed, its material, its hardness, and an OK box.
##   tick OK            you agree with the guess (it is kept from now on)
##   pick from a list   you change it (also kept from now on)
##   untick OK          back to the guess

const GROUP_MATERIAL := 0
const GROUP_HARDNESS := 1
const SHOW_ALL := 0
const SHOW_GUESSES := 1
const SHOW_AGREED := 2
const SHOW_CHANGED := 3

var _search: LineEdit
var _group: OptionButton
var _show: OptionButton
var _tree: Tree
var _summary: Label
var _collapsed := {}  # group key -> true
var _focus_id := ""   # seed to scroll back to after a change
var _shown_ids: Array = []
var _rebuilding := false


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	_search = LineEdit.new()
	_search.placeholder_text = "Search seeds..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t): refresh())
	add_child(_search)

	var row := HBoxContainer.new()
	add_child(row)
	_group = OptionButton.new()
	_group.add_item("Group by material")
	_group.add_item("Group by hardness")
	_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_group.fit_to_longest_item = false
	_group.clip_text = true
	_group.item_selected.connect(func(_i): refresh())
	row.add_child(_group)
	_show = OptionButton.new()
	for s in ["Show: all", "Show: still guesses", "Show: agreed", "Show: changed by me"]:
		_show.add_item(s)
	_show.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_show.fit_to_longest_item = false
	_show.clip_text = true
	_show.item_selected.connect(func(_i): refresh())
	row.add_child(_show)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.columns = 4
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tree.set_column_title(0, "Seed")
	_tree.set_column_title(1, "Material")
	_tree.set_column_title(2, "Hardness")
	_tree.set_column_title(3, "OK")
	_tree.set_column_expand(0, true)
	for c in [[1, 118], [2, 98], [3, 38]]:
		_tree.set_column_expand(c[0], false)
		_tree.set_column_custom_minimum_width(c[0], c[1])
	_tree.item_edited.connect(_on_edited)
	_tree.item_collapsed.connect(func(item: TreeItem):
		var key: Variant = item.get_metadata(0)
		if typeof(key) == TYPE_STRING and String(key).begins_with("group:"):
			_collapsed[key] = item.collapsed)
	add_child(_tree)

	var buttons := HBoxContainer.new()
	add_child(buttons)
	var agree_all := Button.new()
	agree_all.text = "Agree to all shown"
	agree_all.tooltip_text = "Tick OK on every seed in the list (the guesses become final)"
	agree_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	agree_all.pressed.connect(func(): Game.agree_categories(_shown_ids, true))
	buttons.add_child(agree_all)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 12)
	_summary.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	var tip := Label.new()
	tip.text = "Tick OK to agree  ·  pick another material or hardness to change it  ·  untick to go back to the guess"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(0.65, 0.62, 0.78))
	add_child(tip)

	Game.seeds_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _tree == null:
		return
	_rebuilding = true
	_tree.clear()
	var root := _tree.create_item()
	var q := _search.text.strip_edges().to_lower()
	var ids: Array = Game.order.filter(func(id):
		var s: Dictionary = Game.seeds[id]
		if q != "" and not String(s.name).to_lower().contains(q):
			return false
		var st: String = s.get("category", {}).get("status", "auto")
		match _show.selected:
			SHOW_GUESSES: return st == "auto"
			SHOW_AGREED: return st == "agreed"
			SHOW_CHANGED: return st == "changed"
		return true)
	_shown_ids = ids
	var by_material := _group.selected == GROUP_MATERIAL
	var groups: Array = CategoryLogic.MATERIALS.duplicate() if by_material else [5, 4, 3, 2, 1]
	var focus_item: TreeItem = null
	for g in groups:
		var members: Array = ids.filter(func(id):
			var c: Dictionary = Game.seeds[id].category
			return c.material == g if by_material else int(c.hardness) == g)
		if members.is_empty():
			continue
		# inside a material: hardest first; inside a hardness: by material; then by name
		members.sort_custom(func(a, b):
			var ca: Dictionary = Game.seeds[a].category
			var cb: Dictionary = Game.seeds[b].category
			if by_material and ca.hardness != cb.hardness:
				return int(ca.hardness) > int(cb.hardness)
			if not by_material and ca.material != cb.material:
				return CategoryLogic.MATERIALS.find(ca.material) < CategoryLogic.MATERIALS.find(cb.material)
			return String(Game.seeds[a].name).naturalnocasecmp_to(Game.seeds[b].name) < 0)
		var head := _tree.create_item(root)
		var key := "group:%s" % str(g)
		head.set_metadata(0, key)
		head.set_text(0, "%s   (%d)" % [CategoryLogic.material_name(g) if by_material else CategoryLogic.hardness_name(g), members.size()])
		head.set_custom_color(0, CategoryLogic.MATERIAL_COLORS.get(g, Color("#ffc94a")) if by_material else Color("#ffc94a"))
		head.set_expand_right(0, true)
		for c in 4:
			head.set_selectable(c, false)
		head.collapsed = _collapsed.get(key, false)
		for id in members:
			var it := _row(head, id)
			if id == _focus_id:
				focus_item = it
	var sm := Game.category_summary()
	_summary.text = "%d seeds  ·  %d still guesses  ·  %d agreed  ·  %d changed by you%s" % [
		Game.seeds.size(), sm.auto, sm.agreed, sm.changed, "  ·  %d shown" % ids.size() if ids.size() != Game.seeds.size() else ""]
	_rebuilding = false
	if focus_item:
		if focus_item.get_parent():
			focus_item.get_parent().collapsed = false
		_tree.scroll_to_item(focus_item, true)
		focus_item.select(0)
	_focus_id = ""


func _row(parent: TreeItem, id: String) -> TreeItem:
	var s: Dictionary = Game.seeds[id]
	var c: Dictionary = s.category
	var it := _tree.create_item(parent)
	it.set_metadata(0, id)
	it.set_text(0, s.name)
	it.set_icon(0, SeedArt.texture_for(s))
	it.set_icon_max_width(0, 26)
	it.set_tooltip_text(0, "%s  ·  drops %s (%s)" % [s.name, DropLogic.drop_name(s.name), DropLogic.describe(s.get("drop", {}))])

	it.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
	it.set_text(1, ",".join(PackedStringArray(CategoryLogic.MATERIALS.map(func(m): return CategoryLogic.material_name(m)))))
	it.set_range(1, CategoryLogic.MATERIALS.find(c.material))
	it.set_editable(1, true)
	it.set_cell_mode(2, TreeItem.CELL_MODE_RANGE)
	it.set_text(2, ",".join(PackedStringArray([1, 2, 3, 4, 5].map(func(h): return CategoryLogic.hardness_name(h)))))
	it.set_range(2, int(c.hardness) - 1)
	it.set_editable(2, true)
	it.set_cell_mode(3, TreeItem.CELL_MODE_CHECK)
	it.set_checked(3, c.status != "auto")
	it.set_editable(3, true)

	var tip := ""
	match c.status:
		"auto":
			tip = "A guess from the name. Tick OK if you agree, or pick something else."
			for col in [1, 2]:
				it.set_custom_color(col, Color(0.72, 0.69, 0.82))
		"agreed":
			tip = "You agreed with this. Untick OK to go back to the guess."
		"changed":
			tip = "You set this yourself. Untick OK to go back to the guess."
			for col in [1, 2]:
				it.set_custom_color(col, Color("#a6ff6e"))
	for col in [1, 2, 3]:
		it.set_tooltip_text(col, tip)
	it.set_custom_color(1, CategoryLogic.MATERIAL_COLORS.get(c.material, Color.WHITE).lerp(it.get_custom_color(1) if c.status != "agreed" else Color.WHITE, 0.35))
	return it


func _on_edited() -> void:
	if _rebuilding:
		return
	var it := _tree.get_edited()
	var col := _tree.get_edited_column()
	if it == null or typeof(it.get_metadata(0)) != TYPE_STRING or String(it.get_metadata(0)).begins_with("group:"):
		return
	var id: String = it.get_metadata(0)
	var c: Dictionary = Game.seeds[id].category
	_focus_id = id
	# change the data after the Tree has finished its own edit (the list is rebuilt from it)
	match col:
		1: Game.set_category.call_deferred(id, CategoryLogic.MATERIALS[int(it.get_range(1))], int(c.hardness))
		2: Game.set_category.call_deferred(id, c.material, int(it.get_range(2)) + 1)
		3: Game.agree_category.call_deferred(id, it.is_checked(3))
