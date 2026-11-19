class_name SideGrip
extends Control
## The thin strip between the void and the Seeds panel. Drag it left or right to resize the panel.

signal width_changed(width: float)
signal released

var panel: Control
var _drag := false
var _start_x := 0.0
var _start_w := 0.0
var _hover := false


func _ready() -> void:
	custom_minimum_size = Vector2(8, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	tooltip_text = "Drag to resize the Seeds panel"
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_drag = mb.pressed
		if mb.pressed:
			_start_x = get_global_mouse_position().x
			_start_w = panel.size.x
		else:
			released.emit()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		# the panel sits on the right, so dragging left makes it wider
		width_changed.emit(_start_w + (_start_x - get_global_mouse_position().x))
		accept_event()


func _draw() -> void:
	var c := Color("#a6ff6e") if (_drag or _hover) else Color("#3b3150")
	draw_rect(Rect2(size.x / 2.0 - 1.0, 0, 2, size.y), c)
	if _drag or _hover:  # little grab marks in the middle
		for i in 3:
			draw_rect(Rect2(size.x / 2.0 - 2.0, size.y / 2.0 - 12.0 + i * 10.0, 4, 4), c)
