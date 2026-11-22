class_name SplicesWindow
extends FloatingPanel
## Every splice you've made as "A + B = C" rows, in a floating window.
## Click a row to drop its result into the void, or drag the row out into the void.

signal spawn_requested(id: String)

var _box: VBoxContainer


class SpliceRow extends PanelContainer:
	signal clicked(id: String)
	var result_id := ""
	var _pressed := false

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressed = true
			else:
				if _pressed and not get_viewport().gui_is_dragging():
					clicked.emit(result_id)
				_pressed = false

	func _get_drag_data(_at: Vector2) -> Variant:
		_pressed = false
		var pv := TextureRect.new()
		pv.texture = SeedArt.texture_for(Game.get_seed(result_id))
		pv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pv.size = Vector2(96, 96)
		pv.position = -pv.size / 2.0
		pv.modulate.a = 0.85
		var holder := Control.new()
		holder.add_child(pv)
		set_drag_preview(holder)
		return { "seed_id": result_id }


func _init() -> void:
	super("Splices", "splices", Vector2(500, 440), Vector2(18, 110))


func _build(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 4)
	scroll.add_child(_box)
	Game.recipes_changed.connect(refresh)
	Game.seeds_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _box == null:
		return
	for c in _box.get_children():
		c.queue_free()
	set_title("Splices (%d)" % Game.recipes.size())
	if Game.recipe_order.is_empty():
		var empty := Label.new()
		empty.text = "No splices yet.\nDrag one seed onto another in the void."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty.add_theme_color_override("font_color", Color(0.82, 0.79, 0.91))
		_box.add_child(empty)
		return
	var keys := Game.recipe_order.duplicate()
	keys.reverse()
	for key in keys:
		var pair: PackedStringArray = key.split("|")
		_box.add_child(_splice_row(pair[0], pair[1], Game.recipes[key]))


func _splice_row(a: String, b: String, result: String) -> Control:
	var row := SpliceRow.new()
	row.result_id = result
	row.add_theme_stylebox_override("panel", _row_box())
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var s := Game.get_seed(result)
	row.tooltip_text = "Click or drag to put %s in the void" % s.name
	row.clicked.connect(func(id): spawn_requested.emit(id))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	h.add_child(_icon(a))
	h.add_child(_sym("+"))
	h.add_child(_icon(b))
	h.add_child(_sym("="))
	h.add_child(_icon(result))
	var l := Label.new()
	l.text = "%s\nR%d" % [s.name, int(s.rarity)]
	l.add_theme_font_size_override("font_size", UiKit.SMALL)
	l.add_theme_color_override("font_color", (SeedArt.rarity_tier(int(s.rarity))[1] as Color).lerp(Color.WHITE, 0.3))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	return row


func _icon(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = SeedArt.texture_for(Game.get_seed(id))
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.custom_minimum_size = Vector2(40, 40)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _sym(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.78, 0.75, 0.88))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _row_box() -> StyleBox:
	return UiKit.box("inset", 3, [6, 4, 6, 4])
