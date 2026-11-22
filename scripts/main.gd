extends Control
## Builds the screen: the void on the left, the Seeds panel on the right, the top bar, every
## window, the sign-in screen (first launch) and the tutorial (a fresh save). Wires them together.
##
## TOP BAR, in three groups:   [Shop]  |  [Seeds] [Splices] [Recipe Tree] [Dictionary]  |  [gear] [?]
##   Shop        open booster packs: unlock seeds so they make Mycoras
##   the middle  browse your collection (a lit button = that window is open)
##   gear / ?    Settings (Account, Game, Statistics, Developer) and the tutorial

var field: VoidField
var panel: SidePanel
var splices: SplicesWindow
var recipe_tree: RecipeTree
var popup: SplicePopup
var settings_dialog: SettingsDialog
var sound_dialog: SoundDialog
var settings_hub: SettingsHub
var shop: ShopWindow
var live: LiveSync
var dictionary: DictionaryWindow
var hud: MycoraHud
var weather_layer: WeatherLayer
var toolbar: HBoxContainer
var login: LoginScreen
var tutorial: Tutorial
var account: AccountDialog
var shop_btn: Button
var tree_btn: Button
var dict_btn: Button
var settings_btn: Button
var help_btn: Button
var _splices_btn: Button
var _seeds_btn: Button
var _confirm_reset: ConfirmationDialog
var _export_dialog: FileDialog
var _sheet_export_dialog: FileDialog
var sprites: SpriteFolder
var _sheet_import_dialog: FileDialog
var _pending: Array = []  # [token_a, token_b] while the popup is open


func _ready() -> void:
	# every button in the game (also ones made later, inside windows) gets the click sound
	get_tree().node_added.connect(_on_node_added)
	theme = UiKit.make_theme()
	get_tree().auto_accept_quit = false
	if OS.get_cmdline_user_args().is_empty():  # (dev screenshot runs keep their own window)
		DisplayManager.load_and_apply(get_window())

	var bg := ColorRect.new()
	bg.color = Color("#0b0912")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# the top bar (full width): Mycoras + weather on the left, the buttons on the right
	var screen := VBoxContainer.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_theme_constant_override("separation", 0)
	add_child(screen)
	var top := PanelContainer.new()
	top.theme_type_variation = &"TopBar"
	screen.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top.add_child(top_row)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	screen.add_child(row)

	field = VoidField.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(field)

	var grip := SideGrip.new()
	row.add_child(grip)

	panel = SidePanel.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(panel)
	grip.panel = panel
	grip.visible = panel.visible
	grip.width_changed.connect(panel.set_width)
	grip.released.connect(panel.save_width)
	panel.shown_changed.connect(func(on): grip.visible = on)

	weather_layer = WeatherLayer.new()  # rain, thunderstorms and shooting stars over the void
	field.add_child(weather_layer)

	hud = MycoraHud.new()
	top_row.add_child(hud)
	weather_layer.lightning.connect(hud.flash)
	top_row.add_child(hud.weather_chip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	top_row.add_child(toolbar)

	shop_btn = _tool_button("Shop", "icon_shop", "The Shop: open booster packs to unlock seeds, so they make Mycoras", &"ShopButton")
	_divider()
	_seeds_btn = _tool_button("Seeds", "icon_seeds", "Show or hide the Seeds panel (Ctrl+B)")
	_seeds_btn.toggle_mode = true
	_seeds_btn.set_pressed_no_signal(panel.visible)
	_seeds_btn.toggled.connect(panel.show_panel)
	panel.shown_changed.connect(_seeds_btn.set_pressed_no_signal)
	_splices_btn = _tool_button("Splices", "icon_splices", "Show or hide the splices window")
	_splices_btn.toggle_mode = true
	tree_btn = _tool_button("Recipe Tree", "icon_tree", "See how any seed is made, as a tree")
	dict_btn = _tool_button("Dictionary", "icon_book", "Every seed's block texture, growth stages and tags")
	_divider()
	settings_btn = _tool_button("", "icon_gear", "Settings: account, display, sound, statistics")
	help_btn = _tool_button("", "icon_help", "How to play: the tutorial")

	splices = SplicesWindow.new()
	add_child(splices)
	_splices_btn.set_pressed_no_signal(splices.visible)
	_splices_btn.toggled.connect(splices.show_panel)
	splices.shown_changed.connect(_splices_btn.set_pressed_no_signal)
	splices.spawn_requested.connect(func(id): field.spawn_near_center(id))

	recipe_tree = RecipeTree.new()
	add_child(recipe_tree)
	tree_btn.pressed.connect(recipe_tree.open)

	popup = SplicePopup.new()
	add_child(popup)

	dictionary = DictionaryWindow.new()
	add_child(dictionary)
	dict_btn.pressed.connect(dictionary.open)
	dictionary.edit_requested.connect(func(id):
		dictionary.close_dialog()
		popup.open_edit(id))

	live = LiveSync.new()
	live.settings_btn = settings_btn
	live.toast = func(text: String, color: Color): field.show_toast(text, color, 8.0)
	add_child(live)

	shop = ShopWindow.new()
	add_child(shop)
	shop_btn.pressed.connect(shop.open)

	settings_hub = SettingsHub.new()
	add_child(settings_hub)
	settings_dialog = settings_hub.display_page
	sound_dialog = settings_hub.sound_page
	settings_btn.pressed.connect(func(): settings_hub.open())

	# version + over-the-air update check (exported game only, never in the editor)
	var version_label := Label.new()
	version_label.text = "v%s" % GameVersion.VERSION
	version_label.add_theme_font_size_override("font_size", UiKit.SMALL)
	version_label.add_theme_color_override("font_color", Color(0.6, 0.57, 0.7))
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.theme_type_variation = &"DimLabel"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	field.add_child(version_label)  # in the void, so every window covers it
	print("Seed Splicer v%s - %s version" % [GameVersion.VERSION, "DEVELOPER" if DevMode.on() else "player"])
	if DevMode.on():
		version_label.text += "  ·  Developer"
	if Updater.enabled() and not "--selftest" in OS.get_cmdline_user_args():
		var updater := Updater.new()
		add_child(updater)
		updater.status_changed.connect(func(text: String):
			version_label.text = "v%s" % GameVersion.VERSION + ("   %s" % text if text != "" else ""))

	_confirm_reset = ConfirmationDialog.new()
	_confirm_reset.title = "Reset Progress"
	_confirm_reset.dialog_text = "Forget every spliced seed, recipe and your own Tier 1 seeds,\nand start again with the 4 base seeds?\nThis can't be undone. Your Mycoras and unlocked seeds go too."
	_confirm_reset.ok_button_text = "Reset"
	_confirm_reset.confirmed.connect(_do_reset)
	add_child(_confirm_reset)

	if DevMode.on():  # the developer's file tools (Settings > Developer)
		_export_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export Splicing List")
		_export_dialog.current_file = "seed_splicer_list.json"
		_export_dialog.file_selected.connect(_on_export_path)
		_sheet_export_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export Sprite Sheet")
		_sheet_export_dialog.filters = PackedStringArray(["*.png ; Sprite sheet"])
		_sheet_export_dialog.current_file = "seed_splicer_sprites.png"
		_sheet_export_dialog.file_selected.connect(_on_sheet_export_path)
		_sheet_import_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Import Sprite Sheet (block art)")
		_sheet_import_dialog.filters = PackedStringArray(["*.png ; Sprite sheet"])
		_sheet_import_dialog.file_selected.connect(_on_sheet_import_path)

	field.splice_new.connect(_on_splice_new)
	field.void_changed.connect(Game.save_game)
	panel.spawn_requested.connect(func(id): field.spawn_near_center(id))
	panel.edit_requested.connect(_on_edit_request)
	field.edit_seed.connect(func(id): popup.open_edit(id))
	panel.clear_void_requested.connect(field.clear)
	panel.add_seed_requested.connect(popup.open_add)
	account = AccountDialog.new()
	add_child(account)
	var upload := UploadWindow.new()
	add_child(upload)
	settings_hub.upload_requested.connect(func():
		if Online.logged_in():
			upload.open()
		else:
			account.open())
	settings_hub.logout_requested.connect(_log_out)
	settings_hub.reset_requested.connect(_confirm_reset.popup_centered)
	settings_hub.tutorial_requested.connect(_start_tutorial)
	help_btn.pressed.connect(_start_tutorial)
	if DevMode.on():
		var submissions := SubmissionsWindow.new()
		submissions.live = live
		add_child(submissions)
		settings_hub.submissions_requested.connect(submissions.open)
		settings_hub.export_list_requested.connect(_request_export)
		settings_hub.export_sheet_requested.connect(_sheet_export_dialog.popup_centered_ratio)
		settings_hub.import_sheet_requested.connect(_sheet_import_dialog.popup_centered_ratio)
		sprites = SpriteFolder.new()  # keeps a copy of the sprite sheet in a folder (developer only)
		add_child(sprites)
	Online.session_changed.connect(_on_session_changed)
	popup.added_custom.connect(_on_added_custom)
	popup.created.connect(_on_created)
	popup.linked.connect(_on_linked)
	popup.edited.connect(_on_edited)
	popup.cancelled.connect(_on_cancelled)

	# dev-only screenshots/tests (scripts/dev_shot.gd is left out of exported builds)
	if not OS.get_cmdline_user_args().is_empty() and ResourceLoader.exists("res://scripts/dev_shot.gd"):
		var shot: Node = load("res://scripts/dev_shot.gd").new()
		shot.main = self
		add_child(shot)

	# wait one frame so the void has its real size before placing seeds
	await get_tree().process_frame
	if Game.void_tokens.is_empty():
		field.spawn_starters()
	else:
		field.restore(Game.void_tokens.duplicate())
	if "--selftest" in OS.get_cmdline_user_args():
		# the updater's check of a freshly installed pack: the whole screen got built, report success
		get_tree().quit.call_deferred(Updater.SELFTEST_CODE)
		return
	if needs_sign_in():
		show_login()
	else:
		_maybe_start_tutorial()
	if not Game.reroll_report.is_empty():  # the one-time reroll of existing seeds just happened
		var c: Dictionary = Game.reroll_report.counts
		field.show_toast("Rerolled %d seeds:   %d Bountiful  ·  %d Farmable  ·  %d Not Farmable" % [
			Game.reroll_report.total, c.bountiful, c.farmable, c.not_farmable], Color("#ffc94a"), 8.0)
		Game.reroll_report = {}
		if not Game.drop_report.is_empty():
			await get_tree().create_timer(8.6).timeout
	if not Game.drop_report.is_empty():  # seeds from before drops were just sorted by collision
		var d: Dictionary = Game.drop_report
		field.show_toast("Sorted %d seeds' drops:   %d collision  ·  %d no collision  ·  %d collision damage" % [
			d.total, d.collision, d.no_collision, d.damage], Color("#7fb2ff"), 8.0)
		Game.drop_report = {}
	if not Game.crop_report.is_empty():  # seeds from before crop types just got a random one each
		field.show_toast("Gave %d seeds a random crop type. Double-click a seed to pick another." % Game.crop_report.total, Color("#a6ff6e"), 8.0)
		Game.crop_report = {}
	if not Bank.away_report.is_empty():  # Mycoras made while the game was closed (up to 1 hour)
		var away: int = Bank.away_report.seconds
		field.show_toast("While you were away (%s): +%s Mycoras%s" % [Game.duration_text(away), Bank.fmt(Bank.away_report.earned),
			"  (only your last hour away counts)" if away > Bank.MAX_AWAY else ""], Mycora.COLOR, 8.0)
		Bank.away_report = {}
	if int(Game.official_report.get("seeds_added", 0)) > 0:  # this update brought new official seeds
		field.show_toast("Update v%s: %d new official seeds and %d splices were added to your game!" % [
			Game.official_report.version, Game.official_report.seeds_added, Game.official_report.recipes_added], Color("#a6ff6e"), 8.0)
		Game.official_report = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if field:
			field.store()
		Game.save_game()
		if sprites:
			sprites.flush()
		get_tree().quit()


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta(&"no_click_sound"):
		(node as BaseButton).pressed.connect(Audio.play.bind(&"click"))


func _on_edit_request(id: String, discard_spawn: bool) -> void:
	if discard_spawn:
		field.discard_recent_spawn(id)
	popup.open_edit(id)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.ctrl_pressed and k.keycode == KEY_B:
		panel.show_panel(not panel.visible)
		get_viewport().set_input_as_handled()
		return
	if k and k.pressed and not k.echo and k.keycode == KEY_F11:
		DisplayManager.toggle_fullscreen(get_window())
		if settings_dialog.is_visible_in_tree():
			await get_tree().create_timer(0.25).timeout
			settings_dialog.refresh()
		get_viewport().set_input_as_handled()


func _file_dialog(file_mode: FileDialog.FileMode, dialog_title: String) -> FileDialog:
	var d := FileDialog.new()
	d.file_mode = file_mode
	d.access = FileDialog.ACCESS_FILESYSTEM
	d.use_native_dialog = true
	d.title = dialog_title
	d.filters = PackedStringArray(["*.json ; Seed Splicer list"])
	d.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	add_child(d)
	return d


## Export List (developer) needs a name on it: your account name.
func _request_export() -> void:
	if Game.player_name() == "":
		Audio.play(&"error")
		field.show_toast("Sign in first: your account name goes on the export and every seed you made.", Color("#ffc94a"), 6.0)
		return
	_export_dialog.popup_centered_ratio()


func _on_export_path(path: String) -> void:
	if not path.get_extension().to_lower() == "json":
		path += ".json"
	if field:
		field.store()
	var err := Game.export_list(path)
	if err == OK:
		Audio.play(&"success")
		field.show_toast("Exported %d seeds and %d splices to %s\n+ sprite sheet %s (32x32 grid)" % [Game.seeds.size(), Game.recipes.size(), path.get_file(), Game.sprite_sheet_path(path).get_file()], Color("#a6ff6e"))
	else:
		Audio.play(&"error")
		field.show_toast("Couldn't save the file (%s)" % error_string(err), Color("#ff8a8a"))


## Export Sprite Sheet: the PNG only.
func _on_sheet_export_path(path: String) -> void:
	if path.get_extension().to_lower() != "png":
		path += ".png"
	var err := Game.export_sprite_sheet(path)
	if err == OK:
		Audio.play(&"success")
		field.show_toast("Saved the sprite sheet: %d seeds, 9 boxes each (4 block art, seed, sprout, sapling, crop, planted)\n%s" % [Game.order.size(), path.get_file()], Color("#a6ff6e"), 5.0)
	else:
		Audio.play(&"error")
		field.show_toast("Couldn't save the sprite sheet (%s)" % error_string(err), Color("#ff8a8a"))


## Import Sprite Sheet: takes the block art you drew in the 4 left boxes of each row.
func _on_sheet_import_path(path: String) -> void:
	var r := Game.import_sprite_sheet(path)
	if not r.ok:
		Audio.play(&"error")
		field.show_toast(r.error, Color("#ff8a8a"), 8.0)
		return
	Audio.play(&"success")
	var msg := "Block art for %d seeds" % r.with_art
	if r.cleared > 0:
		msg += ", removed from %d (their boxes were empty)" % r.cleared
	if r.by_position > 0:
		msg += "\n%d rows matched by row number (their seed picture changed since the export)" % r.by_position
	if r.unmatched > 0:
		msg += "\n%d rows skipped: no seed of yours matches them" % r.unmatched
	field.show_toast(msg, Color("#a6ff6e") if r.unmatched == 0 else Color("#ffc94a"), 8.0)


func _on_added_custom(look: Dictionary) -> void:
	var id := Game.add_custom_seed(look)
	field.spawn_near_center(id)
	field.show_toast("Added %s  ·  Rarity 1" % Game.get_seed(id).name, Color("#c4c0d4"))


func _on_splice_new(a: SeedToken, b: SeedToken) -> void:
	_pending = [a, b]
	popup.open_new(a.seed_id, b.seed_id)


func _on_created(look: Dictionary) -> void:
	var a: SeedToken = _pending[0]
	var b: SeedToken = _pending[1]
	var id := Game.add_spliced_seed(a.seed_id, b.seed_id, look)
	_pending = []
	field.complete_splice(a, b, id, true)


func _on_linked(existing: String) -> void:
	var a: SeedToken = _pending[0]
	var b: SeedToken = _pending[1]
	Game.link_recipe(a.seed_id, b.seed_id, existing)
	_pending = []
	field.complete_splice(a, b, existing, false)


func _on_cancelled() -> void:
	if _pending.size() == 2:
		field.cancel_splice(_pending[0], _pending[1])
	_pending = []


func _on_edited(id: String, look: Dictionary) -> void:
	Game.update_look(id, look)
	field.refresh_all()


func _do_reset() -> void:
	field.clear()
	Game.reset()
	Bank.reset()
	await get_tree().process_frame
	field.spawn_starters()


# --- top bar -----------------------------------------------------------------------------------

func _tool_button(text: String, icon_name: String, tip: String, variation := &"ToolbarButton") -> Button:
	var b := Button.new()
	b.text = text
	b.icon = UiKit.tex(icon_name)
	b.tooltip_text = tip
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	toolbar.add_child(b)
	return b


func _divider() -> void:
	var d := UiKit.icon("divider")
	d.custom_minimum_size = Vector2(8, 0)
	toolbar.add_child(d)


# --- signing in -------------------------------------------------------------------------------------

## The sign-in screen shows until you've signed in once on this PC (the session is remembered,
## so after that the game opens even offline). Never during tests or the updater's self-test.
func needs_sign_in() -> bool:
	if not Online.configured() or Online.logged_in() or Online.has_saved_session():
		return false
	var args := OS.get_cmdline_user_args()
	if "--selftest" in args or "--no-login" in args:
		return false
	return args.is_empty() or not ResourceLoader.exists("res://scripts/dev_shot.gd")


func show_login() -> void:
	if is_instance_valid(login):
		return
	for w in [settings_hub, shop, account]:
		if w and w.visible:
			w.close_dialog()
	login = LoginScreen.new()
	add_child(login)
	login.signed_in.connect(func():
		login.queue_free()
		login = null
		field.show_toast("Signed in as %s" % Online.username, Color("#a6ff6e"), 4.0)
		_maybe_start_tutorial())


func _log_out() -> void:
	await Online.log_out()
	show_login()


func _on_session_changed() -> void:
	# the server ended the session (password changed, account removed...): sign in again
	if not Online.logged_in() and not Online.has_saved_session() and needs_sign_in():
		show_login()


# --- tutorial -------------------------------------------------------------------------------------

func _maybe_start_tutorial() -> void:
	if Tutorial.should_start() and OS.get_cmdline_user_args().is_empty():
		_start_tutorial()


func _start_tutorial() -> void:
	if is_instance_valid(tutorial):
		tutorial.queue_free()
	tutorial = Tutorial.new()
	tutorial.main = self
	add_child(tutorial)
