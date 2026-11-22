class_name Tutorial
extends Control
## The first-time tutorial: a spotlight on one part of the screen, a speech bubble and a bouncing
## arrow, one step at a time. Some steps wait for you to do the thing (splice two seeds, name the
## new one); the others have a Next button. Skip ends it any time.
## Starts by itself after signing in on a fresh game (should_start), and again from the ? button
## or Settings > Game > Replay tutorial. Finishing or skipping marks it done (UserSettings).

const DONE_KEY := "done"

var main: Node  ## main.gd (the screen this tutorial points at)

var _steps: Array = []
var _i := -1
var _hole := Rect2()
var _bubble: PanelContainer
var _text: Label
var _count: Label
var _next: Button
var _wait: Label
var _pointer: TextureRect
var _t := 0.0
var _waiting_for := ""


static func should_start() -> bool:
	return not bool(UserSettings.get_value("tutorial", DONE_KEY, false)) and int(Game.stats.sessions) <= 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the game stays playable under the spotlight
	_steps = [
		{ "text": "Welcome to Seed Splicer!\nSplice seeds together to discover new ones, collect them all and make Mycoras. Here's how it works.", "target": "" },
		{ "text": "Drag one seed onto another to splice them.\nTry it with two of the seeds in the void.", "target": "void", "wait": "splice" },
		{ "text": "A brand-new seed! Pick its look, give it a name, then press Add to Dictionary.", "target": "popup", "wait": "named" },
		{ "text": "Every seed you find lands in the Seeds panel.\nClick one (or drag it) to drop it into the void and splice it again.", "target": "panel" },
		{ "text": "These are Mycoras. Your seeds make them every 3 seconds, even for an hour after you close the game.\nWeather boosts them: Rain x2, Thunderstorm x100, Shooting Star x100.", "target": "hud" },
		{ "text": "Spend Mycoras in the Shop: booster packs of 5 seed cards. Every new seed you pull starts making Mycoras too.", "target": "shop" },
		{ "text": "Splices lists every recipe you know, the Recipe Tree shows how any seed is made, and the Dictionary shows every seed's art and tags.", "target": "collection" },
		{ "text": "That's everything! Press ? any time to see this again. Happy splicing!", "target": "help", "last": true },
	]

	_pointer = TextureRect.new()
	_pointer.texture = UiKit.tex("pointer")
	_pointer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pointer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pointer.size = _pointer.texture.get_size() * 2.0
	_pointer.pivot_offset = _pointer.size / 2.0
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pointer)

	_bubble = PanelContainer.new()
	_bubble.theme_type_variation = &"BubblePanel"
	_bubble.custom_minimum_size = Vector2(580, 0)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bubble)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_bubble.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "How to play"
	title.theme_type_variation = &"HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_count = Label.new()
	_count.theme_type_variation = &"DimLabel"
	head.add_child(_count)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(548, 0)
	col.add_child(_text)
	_wait = Label.new()
	_wait.theme_type_variation = &"NoteLabel"
	_wait.text = "Waiting for you..."
	col.add_child(_wait)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var skip := Button.new()
	skip.text = "Skip tutorial"
	skip.pressed.connect(finish)
	row.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_next = Button.new()
	_next.theme_type_variation = &"ShopButton"
	_next.custom_minimum_size = Vector2(150, 0)
	_next.pressed.connect(advance)
	row.add_child(_next)

	main.field.splice_new.connect(_on_splice_new)
	main.field.spliced.connect(_on_spliced)
	main.popup.created.connect(_on_named.unbind(1))
	main.popup.linked.connect(_on_named.unbind(1))
	main.popup.cancelled.connect(_on_popup_cancelled)
	get_viewport().size_changed.connect(_place)
	advance()


func advance() -> void:
	_i += 1
	if _i >= _steps.size():
		finish()
		return
	var st: Dictionary = _steps[_i]
	_text.text = st.text
	_count.text = "%d / %d" % [_i + 1, _steps.size()]
	_waiting_for = String(st.get("wait", ""))
	_next.visible = _waiting_for == ""
	_wait.visible = _waiting_for != ""
	_next.text = "Let's go!" if st.get("last", false) else "Next"
	Audio.play(&"open")
	_place.call_deferred()


func finish() -> void:
	UserSettings.set_value("tutorial", DONE_KEY, true)
	queue_free()


# --- waiting for the player -------------------------------------------------------------------------

func _on_splice_new(_a, _b) -> void:
	if _waiting_for == "splice":
		advance()  # the popup opened: step 3 (name it)


func _on_spliced(_id: String, _is_new: bool) -> void:
	if _waiting_for == "splice":
		advance()  # a splice everyone knows already: no popup, so skip the naming step
		advance()
	elif _waiting_for == "named":
		pass


func _on_named() -> void:
	if _waiting_for == "named":
		advance()


func _on_popup_cancelled() -> void:
	if _waiting_for == "named":  # back to "drag one seed onto another"
		_i -= 2
		advance()


# --- where things are --------------------------------------------------------------------------------

func _target_rect(name: String) -> Rect2:
	match name:
		"void":
			var toks: Array = main.field.tokens_layer.get_children().filter(func(t): return t is SeedToken and t.visible)
			if toks.size() >= 2:
				var r: Rect2 = toks[0].get_global_rect()
				r = r.merge(toks[1].get_global_rect())
				return r.grow(18)
			return main.field.get_global_rect().grow(-60)
		"popup":
			var p: Control = main.popup
			for c in p.get_children():
				if c is CenterContainer and c.get_child_count() > 0:
					return (c.get_child(0) as Control).get_global_rect().grow(6)
			return p.get_global_rect()
		"panel":
			return main.panel.get_global_rect().grow(-4) if main.panel.visible else main._seeds_btn.get_global_rect().grow(6)
		"hud":
			var r: Rect2 = main.hud.get_global_rect()
			if main.hud.weather_chip.visible:
				r = r.merge(main.hud.weather_chip.get_global_rect())
			return r.grow(8)
		"shop":
			return main.shop_btn.get_global_rect().grow(8)
		"collection":
			return main._splices_btn.get_global_rect().merge(main.dict_btn.get_global_rect()).grow(8)
		"help":
			return main.help_btn.get_global_rect().grow(8)
	return Rect2()


func _place() -> void:
	if _i < 0 or _i >= _steps.size() or not is_inside_tree():
		return
	var st: Dictionary = _steps[_i]
	_hole = _target_rect(String(st.target))
	var view := size
	_set_bubble_width(580.0)
	var bs := _bubble.size
	var pos: Vector2
	if _hole.size == Vector2.ZERO:
		pos = (view - bs) / 2.0
		_pointer.visible = false
	else:
		_pointer.visible = true
		# below the target if there's room, else above; centered on it, kept on screen
		var below := _hole.end.y + 40.0
		if below + bs.y > view.y - 10.0:
			pos.y = _hole.position.y - bs.y - 40.0
		else:
			pos.y = below
		pos.x = _hole.get_center().x - bs.x / 2.0
		if pos.y < 10.0:  # no room above or below (a tall target): beside it, on the roomier side
			var left_room := _hole.position.x - 22.0
			var right_room := view.x - _hole.end.x - 22.0
			_set_bubble_width(clampf(maxf(left_room, right_room), 380.0, 580.0))
			bs = _bubble.size
			pos.y = clampf(_hole.get_center().y - bs.y / 2.0, 10.0, view.y - bs.y - 10.0)
			pos.x = _hole.position.x - bs.x - 12.0 if left_room > right_room else _hole.end.x + 12.0
			if maxf(left_room, right_room) < 380.0:  # no room beside it either: bottom-left corner
				_set_bubble_width(480.0)
				bs = _bubble.size
				pos = Vector2(10.0, view.y - bs.y - 10.0)
	pos.x = clampf(pos.x, 10.0, maxf(10.0, view.x - bs.x - 10.0))
	pos.y = clampf(pos.y, 10.0, maxf(10.0, view.y - bs.y - 10.0))
	_bubble.position = pos.round()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _i >= 0 and _i < _steps.size() and String(_steps[_i].target) in ["void", "popup", "panel"]:
		var r := _target_rect(String(_steps[_i].target))
		if not r.is_equal_approx(_hole):
			_place()
	if _pointer.visible and _hole.size != Vector2.ZERO:
		var bob := roundf(sin(_t * 6.0) * 3.0) * 2.0
		var above := _bubble.position.y > _hole.end.y  # bubble below the target: point up at it
		if above:
			_pointer.rotation = PI
			_pointer.position = Vector2(_hole.get_center().x - _pointer.size.x / 2.0, _hole.end.y + 4.0 + bob).round()
		else:
			_pointer.rotation = 0.0
			_pointer.position = Vector2(_hole.get_center().x - _pointer.size.x / 2.0, _hole.position.y - _pointer.size.y - 4.0 - bob).round()


func _set_bubble_width(w: float) -> void:
	_bubble.custom_minimum_size.x = w
	_text.custom_minimum_size.x = w - 32.0
	_bubble.reset_size()


## The dim around the spotlight (4 rectangles, so the target shows through untouched).
func _draw() -> void:
	var dim := Color(0.02, 0.01, 0.05, 0.62)
	if _hole.size == Vector2.ZERO:
		draw_rect(Rect2(Vector2.ZERO, size), dim)
		return
	var h := Rect2(_hole.position.round(), _hole.size.round()).intersection(Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(0, 0, size.x, h.position.y), dim)
	draw_rect(Rect2(0, h.end.y, size.x, size.y - h.end.y), dim)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), dim)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), dim)
	# a gold pixel frame around the spotlight
	var g := UiKit.GOLD
	draw_rect(Rect2(h.position - Vector2(2, 2), Vector2(h.size.x + 4, 2)), g)
	draw_rect(Rect2(h.position.x - 2, h.end.y, h.size.x + 4, 2), g)
	draw_rect(Rect2(h.position - Vector2(2, 2), Vector2(2, h.size.y + 4)), g)
	draw_rect(Rect2(h.end.x, h.position.y - 2, 2, h.size.y + 4), g)
