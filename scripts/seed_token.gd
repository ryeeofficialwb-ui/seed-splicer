class_name SeedToken
extends Control
## A seed floating in the void. Drag it onto another seed to splice them.
## Double-click edits it, right-click removes it, Ctrl+click makes a copy.

signal dropped(token: SeedToken)
signal remove_requested(token: SeedToken)
signal duplicate_requested(token: SeedToken)
signal edit_requested(token: SeedToken)
signal moved

const SCALE := 3
const ART := 32 * SCALE
const DRIFT_SPEED := 7.0
const DRAG_THRESHOLD := 6.0  ## pixels you must drag before a drop counts as a splice
const TOP_ROOM := 44.0     ## keep clear of the title
const BOTTOM_ROOM := 70.0  ## room for the name label + the hint line

var seed_id := ""
var field: Control  ## the VoidField this token lives in
var dragging := false
var hovered := false
var velocity := Vector2.ZERO
var _grab := Vector2.ZERO
var _t := 0.0
var _phase := 0.0
var _drag_dist := 0.0
var spawned_at := 0  ## Time.get_ticks_msec() when it appeared
var _tex: Texture2D


func setup(id: String) -> void:
	seed_id = id
	spawned_at = Time.get_ticks_msec()
	refresh()


func refresh() -> void:
	var s := Game.get_seed(seed_id)
	if s.is_empty():
		return
	_tex = SeedArt.texture_for(s)
	tooltip_text = ""
	queue_redraw()


func _ready() -> void:
	size = Vector2(ART, ART)
	pivot_offset = size / 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_phase = randf() * TAU
	velocity = Vector2.from_angle(randf() * TAU) * DRIFT_SPEED * randf_range(0.5, 1.0)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(on: bool) -> void:
	hovered = on
	queue_redraw()


func center() -> Vector2:
	return position + size / 2


func pop_in() -> void:
	scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	if not dragging:
		var parent := get_parent_control()
		if parent:
			position += velocity * delta
			var max_pos := parent.size - size
			if position.x < 0.0 or position.x > max_pos.x:
				velocity.x = -velocity.x
				position.x = clampf(position.x, 0.0, maxf(max_pos.x, 0.0))
			if position.y < TOP_ROOM or position.y > max_pos.y - BOTTOM_ROOM:
				velocity.y = -velocity.y
				position.y = clampf(position.y, TOP_ROOM, maxf(max_pos.y - BOTTOM_ROOM, TOP_ROOM))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				edit_requested.emit(self)           # double-click: edit this seed
			elif mb.pressed and mb.ctrl_pressed:
				duplicate_requested.emit(self)      # Ctrl+click: make a copy
			elif mb.pressed:
				dragging = true
				_drag_dist = 0.0
				Audio.play(&"pickup")
				_grab = get_parent_control().get_local_mouse_position() - position
				get_parent().move_child(self, -1)
			elif dragging:
				dragging = false
				# a plain click (no real drag) must never splice with a seed it happens to overlap
				if _drag_dist >= DRAG_THRESHOLD:
					dropped.emit(self)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			remove_requested.emit(self)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		var target := get_parent_control().get_local_mouse_position() - _grab
		_drag_dist += position.distance_to(target)
		position = target
		moved.emit()
		accept_event()


# Dropping a seed from the dictionary onto a floating seed splices them.
func _can_drop_data(at: Vector2, data: Variant) -> bool:
	return field != null and field._can_drop_data(at + position, data)


func _drop_data(at: Vector2, data: Variant) -> void:
	field._drop_data(at + position, data)


func _draw() -> void:
	if _tex == null:
		return
	var bob := roundf(sin(_t * 1.7 + _phase) * 3.0) if not dragging else -6.0
	# soft shadow on the "floor" of the void
	var shadow_w := 54.0 + (0.0 if not dragging else -10.0)
	draw_set_transform(Vector2(ART / 2.0, ART - 6.0), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, shadow_w / 2.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO)
	if hovered or dragging:
		draw_circle(Vector2(ART / 2.0, ART / 2.0 + bob), ART * 0.42, Color(1, 1, 1, 0.06))
	draw_texture_rect(_tex, Rect2(Vector2(0, bob), Vector2(ART, ART)), false)
	# name + rarity under the seed
	var s := Game.get_seed(seed_id)
	var font := get_theme_default_font()
	var label := String(s.get("name", "?"))
	var fs := 15
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((ART - w) / 2.0, ART + 14.0)
	draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.05, 0.04, 0.08, 0.9))
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.93, 1.0))
	# second line: only the rarity, in its tier color (every other tag lives in the Dictionary)
	var tier: Array = SeedArt.rarity_tier(int(s.get("rarity", 1)))
	var rl := "R%d" % int(s.get("rarity", 1))
	var rw := font.get_string_size(rl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var rpos := Vector2((ART - rw) / 2.0, ART + 29.0)
	draw_string_outline(font, rpos, rl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0.05, 0.04, 0.08, 0.9))
	draw_string(font, rpos, rl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tier[1])
