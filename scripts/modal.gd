class_name Modal
extends Control
## A centered window over a dimmed game (Escape closes it). Subclasses build into `body`.

var body: VBoxContainer
var _title: Label


func _init_modal(title: String, min_size: Vector2) -> void:
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
	panel.theme_type_variation = &"WindowPanel"
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	_title = Label.new()
	_title.text = title
	_title.theme_type_variation = &"TitleLabel"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Button.new()
	close.icon = UiKit.tex("icon_close")
	close.tooltip_text = "Close (Esc)"
	close.pressed.connect(close_dialog)
	head.add_child(close)


func set_title(t: String) -> void:
	_title.text = t


func open() -> void:
	visible = true
	Audio.play(&"open")


func close_dialog() -> void:
	visible = false


func note(text := "", color := Color(0.85, 0.82, 0.93)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", UiKit.SMALL)
	l.add_theme_color_override("font_color", color)
	return l


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()
