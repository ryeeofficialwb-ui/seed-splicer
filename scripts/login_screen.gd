class_name LoginScreen
extends Control
## The sign-in screen: covers the whole game until you log in or create an account (main.gd shows
## it on the first launch on a PC, and after Log out). Once you've signed in, the session is
## remembered and the game opens straight away, even offline.
## Accounts are a username + password (Online: the password goes straight to the account server).

signal signed_in

var _user: LineEdit
var _pass: LineEdit
var _pass2: LineEdit
var _msg: Label
var _go: Button
var _tabs: TabBar
var _busy := false
var _t := 0.0
var _motes: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in 60:
		_motes.append(Vector3(randf(), randf(), randf_range(0.3, 1.0)))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var logo_row := HBoxContainer.new()
	logo_row.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_row.add_theme_constant_override("separation", 12)
	col.add_child(logo_row)
	var seed_pic := TextureRect.new()
	seed_pic.texture = UiKit.tex("icon_seeds")
	seed_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seed_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seed_pic.custom_minimum_size = Vector2(72, 72)
	logo_row.add_child(seed_pic)
	var logo := Label.new()
	logo.text = "SEED SPLICER"
	logo.add_theme_font_size_override("font_size", UiKit.BIG * 2)
	logo.add_theme_color_override("font_color", UiKit.ACCENT)
	logo.add_theme_color_override("font_outline_color", Color("#07050c"))
	logo.add_theme_constant_override("outline_size", 8)
	logo_row.add_child(logo)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	panel.custom_minimum_size = Vector2(660, 0)
	col.add_child(panel)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	panel.add_child(form)

	_tabs = TabBar.new()
	_tabs.add_tab("Log in")
	_tabs.add_tab("Create account")
	_tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	_tabs.tab_changed.connect(func(_i): _refresh())
	form.add_child(_tabs)
	_user = LineEdit.new()
	_user.placeholder_text = "Username (3-20 letters, numbers or _)"
	_user.max_length = 20
	_user.text_submitted.connect(func(_t): _pass.grab_focus())
	form.add_child(_user)
	_pass = LineEdit.new()
	_pass.placeholder_text = "Password (8 characters or more)"
	_pass.secret = true
	_pass.text_submitted.connect(func(_t): _submit())
	form.add_child(_pass)
	_pass2 = LineEdit.new()
	_pass2.placeholder_text = "Password again"
	_pass2.secret = true
	_pass2.text_submitted.connect(func(_t): _submit())
	form.add_child(_pass2)
	_go = Button.new()
	_go.theme_type_variation = &"ShopButton"
	_go.custom_minimum_size = Vector2(0, 52)
	_go.pressed.connect(_submit)
	form.add_child(_go)
	_msg = Label.new()
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.custom_minimum_size = Vector2(620, 0)
	form.add_child(_msg)
	var fine := Label.new()
	fine.text = "Your account name signs every seed you make. The password goes straight to the game's account server and is never saved on this PC. There's no email, so pick one you'll remember."
	fine.theme_type_variation = &"DimLabel"
	fine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fine.custom_minimum_size = Vector2(620, 0)
	form.add_child(fine)

	var ver := Label.new()
	ver.text = "v%s" % GameVersion.VERSION
	ver.theme_type_variation = &"DimLabel"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ver)
	_refresh()
	_user.grab_focus.call_deferred()
	Audio.play(&"open")


func _process(delta: float) -> void:
	_t += delta
	for i in _motes.size():
		var m: Vector3 = _motes[i]
		m.y -= delta * 0.02 * m.z
		if m.y < 0.0:
			m = Vector3(randf(), 1.0, randf_range(0.3, 1.0))
		_motes[i] = m
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0912"))
	for m in _motes:  # drifting spores, on the 2-pixel grid like everything else
		var p := (Vector2(m.x * size.x, m.y * size.y) / 2.0).floor() * 2.0
		var a := 0.25 + 0.35 * (0.5 + 0.5 * sin(_t * 2.0 + m.x * 20.0))
		draw_rect(Rect2(p, Vector2(2, 2) * (2.0 if m.z > 0.8 else 1.0)), Color(0.65, 1.0, 0.43, a * m.z))


func _creating() -> bool:
	return _tabs.current_tab == 1


func _refresh() -> void:
	_pass2.visible = _creating()
	_go.text = "Create account" if _creating() else "Log in"
	_go.disabled = _busy or not Online.configured()
	_user.editable = not _busy
	_pass.editable = not _busy
	_pass2.editable = not _busy
	if not Online.configured():
		_say("Online features aren't set up in this version.", false)


func _say(text: String, ok: bool) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", UiKit.ACCENT if ok else UiKit.RED)


func _submit() -> void:
	if _busy:
		return
	if _creating() and _pass.text != _pass2.text:
		_say("The two passwords are different.", false)
		Audio.play(&"error")
		return
	_busy = true
	_refresh()
	_say("Creating your account..." if _creating() else "Logging in...", true)
	var r: Dictionary
	if _creating():
		r = await Online.sign_up(_user.text, _pass.text)
	else:
		r = await Online.log_in(_user.text, _pass.text)
	_busy = false
	_pass.text = ""
	_pass2.text = ""
	_refresh()
	if not r.ok:
		_say(r.error, false)
		Audio.play(&"error")
		return
	Audio.play(&"success")
	signed_in.emit()


func _unhandled_input(_event: InputEvent) -> void:
	get_viewport().set_input_as_handled()  # no shortcuts reach the game behind the sign-in screen
