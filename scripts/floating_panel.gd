class_name FloatingPanel
extends PanelContainer
## A small window that floats over the game.
##   drag the title bar to move it    - collapse button (or double-click the title) shrinks it to
##   just its title bar               - X hides it (the toolbar button brings it back)
## Position, collapsed and hidden state are remembered between sessions.
## Subclasses override _build(parent) to fill the body.

signal shown_changed(shown: bool)
signal state_changed

const TITLE_H := 32

var settings_key := ""
var collapsed := false
var title_text := ""
var body: MarginContainer

var _body_size: Vector2
var _start_pos: Vector2
var _title: Label
var _collapse_btn: Button
var _dragging := false
var _grab := Vector2.ZERO


func _init(p_title: String, p_key: String, body_size: Vector2, start_pos: Vector2) -> void:
	title_text = p_title
	settings_key = p_key
	_body_size = body_size
	_start_pos = start_pos


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(_body_size.x, 0)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#15111e")
	frame.border_color = Color("#4a3d66")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(0)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 8
	add_theme_stylebox_override("panel", frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, TITLE_H)
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	var bar_box := StyleBoxFlat.new()
	bar_box.bg_color = Color("#241c35")
	bar_box.set_content_margin_all(0)
	bar_box.content_margin_left = 10
	bar_box.content_margin_right = 4
	bar.add_theme_stylebox_override("panel", bar_box)
	bar.gui_input.connect(_on_bar_input)
	root.add_child(bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	bar.add_child(hb)
	_title = Label.new()
	_title.text = title_text
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color("#a6ff6e"))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_title)
	_collapse_btn = _bar_button("–", "Collapse", toggle_collapsed)
	hb.add_child(_collapse_btn)
	hb.add_child(_bar_button("×", "Hide", func(): show_panel(false)))

	body = MarginContainer.new()
	body.custom_minimum_size = _body_size
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 8)
	root.add_child(body)
	_build(body)

	position = _start_pos
	var saved_pos: Variant = UserSettings.get_value("panels", settings_key + "_pos", null)
	if saved_pos is Vector2:
		position = saved_pos
	collapsed = bool(UserSettings.get_value("panels", settings_key + "_collapsed", false))
	_apply_collapsed()
	visible = bool(UserSettings.get_value("panels", settings_key + "_visible", true))
	var parent := get_parent_control()
	if parent:
		parent.resized.connect(_clamp_deferred)
	_clamp_deferred()


## Override: add your content to `parent`.
func _build(_parent: Control) -> void:
	pass


func set_title(text: String) -> void:
	title_text = text
	if _title:
		_title.text = text


func show_panel(on: bool) -> void:
	visible = on
	UserSettings.set_value("panels", settings_key + "_visible", on)
	shown_changed.emit(on)
	if on:
		_clamp_deferred()


func toggle_collapsed() -> void:
	collapsed = not collapsed
	UserSettings.set_value("panels", settings_key + "_collapsed", collapsed)
	_apply_collapsed()
	_clamp_deferred()
	state_changed.emit()


func _apply_collapsed() -> void:
	body.visible = not collapsed
	_collapse_btn.text = "+" if collapsed else "–"
	_collapse_btn.tooltip_text = "Expand" if collapsed else "Collapse"
	reset_size()  # shrink/grow to the new minimum size


## Keep the whole window on screen, even after the game window gets smaller.
func _clamp_deferred() -> void:
	_clamp.call_deferred()


func _clamp() -> void:
	var parent := get_parent_control()
	if parent == null:
		return
	reset_size()
	var max_pos := (parent.size - size).max(Vector2.ZERO)
	position = position.clamp(Vector2.ZERO, max_pos).round()


func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.double_click:
				_dragging = false
				toggle_collapsed()
			else:
				_dragging = true
				_grab = get_parent_control().get_local_mouse_position() - position
		elif _dragging:
			_dragging = false
			UserSettings.set_value("panels", settings_key + "_pos", position)
	elif event is InputEventMouseMotion and _dragging:
		position = get_parent_control().get_local_mouse_position() - _grab
		_clamp()


func _bar_button(text: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(28, 24)
	b.pressed.connect(action)
	return b
