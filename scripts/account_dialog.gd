class_name AccountDialog
extends Modal
## Settings > Account: log in, create an account (username + password), or log out.

var _user: LineEdit
var _pass: LineEdit
var _pass2: LineEdit
var _msg: Label
var _login_btn: Button
var _signup_btn: Button
var _form: VBoxContainer
var _signed_in: VBoxContainer
var _who: Label
var _busy := false


func _ready() -> void:
	_init_modal("Account", Vector2(420, 0))
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 8)
	body.add_child(_form)
	_form.add_child(note("Log in to upload your seeds for review. If one is approved, it reaches every player in the next update, with your username and the approval stamp."))
	_user = LineEdit.new()
	_user.placeholder_text = "Username (3-20 letters, numbers or _)"
	_user.max_length = 20
	_form.add_child(_user)
	_pass = LineEdit.new()
	_pass.placeholder_text = "Password (8 characters or more)"
	_pass.secret = true
	_pass.text_submitted.connect(func(_t): _on_login())
	_form.add_child(_pass)
	_pass2 = LineEdit.new()
	_pass2.placeholder_text = "Password again (only to create an account)"
	_pass2.secret = true
	_form.add_child(_pass2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_form.add_child(row)
	_login_btn = Button.new()
	_login_btn.text = "Log in"
	_login_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_login_btn.pressed.connect(_on_login)
	row.add_child(_login_btn)
	_signup_btn = Button.new()
	_signup_btn.text = "Create account"
	_signup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_signup_btn.pressed.connect(_on_signup)
	row.add_child(_signup_btn)
	_form.add_child(note("Your password goes straight to the game's account server and is never saved on this PC. There's no email, so pick a password you'll remember: it can't be reset.", Color(0.6, 0.58, 0.7)))

	_signed_in = VBoxContainer.new()
	_signed_in.add_theme_constant_override("separation", 8)
	body.add_child(_signed_in)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 18)
	_signed_in.add_child(_who)
	var out := Button.new()
	out.text = "Log out"
	out.pressed.connect(func():
		await Online.log_out()
		_refresh())
	_signed_in.add_child(out)

	_msg = note()
	body.add_child(_msg)
	Online.session_changed.connect(_refresh)


func open() -> void:
	_msg.text = ""
	if not Online.configured():
		_msg.text = "Online features aren't set up in this version yet."
	_refresh()
	super()
	if not Online.logged_in():
		_user.grab_focus.call_deferred()


func _refresh() -> void:
	_form.visible = not Online.logged_in()
	_signed_in.visible = Online.logged_in()
	_who.text = "Logged in as %s%s" % [Online.username, "  (admin)" if Online.is_admin else ""]
	for b in [_login_btn, _signup_btn]:
		b.disabled = _busy or not Online.configured()


func _say(text: String, ok: bool) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", Color("#a6ff6e") if ok else Color("#ff8a8a"))


func _on_login() -> void:
	if _busy:
		return
	_busy = true
	_refresh()
	_say("Logging in...", true)
	var r: Dictionary = await Online.log_in(_user.text, _pass.text)
	_busy = false
	_pass.text = ""
	_pass2.text = ""
	_say("Welcome back, %s!" % Online.username if r.ok else r.error, r.ok)
	_refresh()


func _on_signup() -> void:
	if _busy:
		return
	if _pass.text != _pass2.text:
		_say("The two passwords are different.", false)
		return
	_busy = true
	_refresh()
	_say("Creating your account...", true)
	var r: Dictionary = await Online.sign_up(_user.text, _pass.text)
	_busy = false
	_pass.text = ""
	_pass2.text = ""
	_say("Account created. Welcome, %s!" % Online.username if r.ok else r.error, r.ok)
	_refresh()
