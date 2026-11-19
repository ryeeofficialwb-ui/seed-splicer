class_name SettingsDialog
extends Control
## Display settings: window mode, resolution (windowed), UI size. Changes apply instantly.

var _mode: OptionButton
var _res: OptionButton
var _ui: OptionButton
var _note: Label
var _res_values: Array[Vector2i] = []
var _busy := false


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
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Display"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#a6ff6e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(grid)

	_mode = _row(grid, "Window mode")
	for n in DisplayManager.MODE_NAMES:
		_mode.add_item(n)
	_mode.item_selected.connect(_on_mode)

	_res = _row(grid, "Resolution")
	_res.item_selected.connect(_on_res)

	_ui = _row(grid, "UI size")
	for n in DisplayManager.UI_SCALE_NAMES:
		_ui.add_item(n)
	_ui.item_selected.connect(_on_ui)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	root.add_child(_note)

	var hint := Label.new()
	hint.text = "F11 switches between windowed and fullscreen. You can also drag the window edges to resize it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	root.add_child(hint)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 38)
	close.pressed.connect(close_dialog)
	root.add_child(close)


func open() -> void:
	refresh()
	visible = true
	Audio.play(&"open")


func close_dialog() -> void:
	visible = false


## Re-reads the real window state (also after F11 or a manual resize).
func refresh() -> void:
	var win := get_window()
	_busy = true
	var mode := DisplayManager.current_mode(win)
	_mode.select(mode)

	_res.clear()
	_res_values = DisplayManager.available_resolutions(win)
	var sel := -1
	for i in _res_values.size():
		var r := _res_values[i]
		var is_preset := DisplayManager.RESOLUTIONS.has(r)
		_res.add_item("%d × %d%s" % [r.x, r.y, "" if is_preset else "  (current)"])
		if mode == DisplayManager.Mode.WINDOWED and r == win.size:
			sel = i
	if sel >= 0:
		_res.select(sel)
	_res.disabled = mode != DisplayManager.Mode.WINDOWED
	if mode != DisplayManager.Mode.WINDOWED:
		_res.add_item("Screen resolution (%d × %d)" % [win.size.x, win.size.y])
		_res.select(_res.item_count - 1)
		_note.text = "Fullscreen uses your screen's own resolution. Switch to Windowed to pick a size."
	else:
		_note.text = "Windowed: pick a size, or drag the window edges."

	var scale := DisplayManager.ui_scale()
	var best := 1
	for i in DisplayManager.UI_SCALES.size():
		if is_equal_approx(DisplayManager.UI_SCALES[i], scale):
			best = i
	_ui.select(best)
	_busy = false


func _on_mode(i: int) -> void:
	if _busy:
		return
	DisplayManager.set_mode(get_window(), i)
	# the window needs a moment to change mode before we can read its new size
	await get_tree().create_timer(0.25).timeout
	refresh()


func _on_res(i: int) -> void:
	if _busy or i >= _res_values.size():
		return
	DisplayManager.set_resolution(get_window(), _res_values[i])
	await get_tree().create_timer(0.15).timeout
	refresh()


func _on_ui(i: int) -> void:
	if _busy:
		return
	DisplayManager.set_ui_scale(get_window(), DisplayManager.UI_SCALES[i])


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()


func _row(grid: GridContainer, caption: String) -> OptionButton:
	var l := Label.new()
	l.text = caption
	grid.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.custom_minimum_size = Vector2(0, 34)
	grid.add_child(o)
	return o
