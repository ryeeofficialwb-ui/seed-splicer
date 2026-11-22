class_name SettingsDialog
extends VBoxContainer
## Display settings (a page in Settings > Game): window mode, resolution (windowed), UI size.
## Changes apply instantly.

var _mode: OptionButton
var _res: OptionButton
var _ui: OptionButton
var _note: Label
var _res_values: Array[Vector2i] = []
var _busy := false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var root := self
	get_window().size_changed.connect(func():
		if is_visible_in_tree():
			refresh.call_deferred())

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
	for n in DisplayManager.UI_SIZE_NAMES:
		_ui.add_item(n)
	_ui.item_selected.connect(_on_ui)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.theme_type_variation = &"NoteLabel"
	root.add_child(_note)

	var hint := Label.new()
	hint.text = "F11 switches between windowed and fullscreen. The game is always drawn at a whole zoom (1x, 2x, 3x) so the pixel art stays sharp."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.theme_type_variation = &"DimLabel"
	root.add_child(hint)


func open() -> void:
	refresh()


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

	_ui.select(DisplayManager.UI_SIZES.find(DisplayManager.ui_size()))
	_note.text += "  Drawn at %sx now." % ("%d" % int(win.content_scale_factor) if is_equal_approx(win.content_scale_factor, roundf(win.content_scale_factor)) else "%.2f" % win.content_scale_factor)
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
	DisplayManager.set_ui_size(get_window(), DisplayManager.UI_SIZES[i])
	refresh()


func _row(grid: GridContainer, caption: String) -> OptionButton:
	var l := Label.new()
	l.text = caption
	grid.add_child(l)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.custom_minimum_size = Vector2(0, 46)
	grid.add_child(o)
	return o
