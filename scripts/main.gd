extends Control
## Builds the screen: the void on the left, the dictionary tabs on the right,
## and the splice popup on top. Wires them together.

var field: VoidField
var panel: SidePanel
var splices: SplicesWindow
var recipe_tree: RecipeTree
var popup: SplicePopup
var settings_dialog: SettingsDialog
var import_picker: ImportDialog
var sound_dialog: SoundDialog
var settings_hub: SettingsHub
var dictionary: DictionaryWindow
var _pending_import := {}  # the file being imported while you pick its seeds
var _splices_btn: Button
var _seeds_btn: Button
var _confirm_reset: ConfirmationDialog
var _export_dialog: FileDialog
var _import_dialog: FileDialog
var _sheet_export_dialog: FileDialog
var sprites: SpriteFolder
var _sheet_import_dialog: FileDialog
var _pending: Array = []  # [token_a, token_b] while the popup is open


func _ready() -> void:
	# every button in the game (also ones made later, inside windows) gets the click sound
	get_tree().node_added.connect(_on_node_added)
	theme = _make_theme()
	get_tree().auto_accept_quit = false
	if OS.get_cmdline_user_args().is_empty():  # (dev screenshot runs keep their own window)
		DisplayManager.load_and_apply(get_window())

	var bg := ColorRect.new()
	bg.color = Color("#0b0912")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	add_child(row)

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

	# top-right buttons over the void
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	field.add_child(bar)
	_seeds_btn = Button.new()
	_seeds_btn.text = "Seeds"
	_seeds_btn.toggle_mode = true
	_seeds_btn.tooltip_text = "Show or hide the Seeds panel (Ctrl+B)"
	_seeds_btn.set_pressed_no_signal(panel.visible)
	_seeds_btn.toggled.connect(panel.show_panel)
	panel.shown_changed.connect(_seeds_btn.set_pressed_no_signal)
	bar.add_child(_seeds_btn)
	_splices_btn = Button.new()
	_splices_btn.text = "Splices"
	_splices_btn.toggle_mode = true
	_splices_btn.tooltip_text = "Show or hide the splices window"
	bar.add_child(_splices_btn)
	var tree_btn := Button.new()
	tree_btn.text = "Recipe Tree"
	tree_btn.tooltip_text = "See how any seed is made, as a tree"
	bar.add_child(tree_btn)
	var dict_btn := Button.new()
	dict_btn.text = "Dictionary"
	dict_btn.tooltip_text = "Every seed's block texture, growth stages and tags, sorted into blocks, decorations and backgrounds"
	bar.add_child(dict_btn)
	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.tooltip_text = "Import / export lists and sprite sheets, the sprites folder, display, sound and reset"
	bar.add_child(settings_btn)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN

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

	settings_dialog = SettingsDialog.new()
	add_child(settings_dialog)

	sound_dialog = SoundDialog.new()
	add_child(sound_dialog)

	dictionary = DictionaryWindow.new()
	add_child(dictionary)
	dict_btn.pressed.connect(dictionary.open)
	dictionary.edit_requested.connect(func(id):
		dictionary.close_dialog()
		popup.open_edit(id))

	settings_hub = SettingsHub.new()
	add_child(settings_hub)
	settings_btn.pressed.connect(settings_hub.open)

	# version + over-the-air update check (exported game only, never in the editor)
	var version_label := Label.new()
	version_label.text = "v%s" % GameVersion.VERSION
	version_label.add_theme_font_size_override("font_size", 12)
	version_label.add_theme_color_override("font_color", Color(0.6, 0.57, 0.7))
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(version_label)
	if Updater.enabled():
		var updater := Updater.new()
		add_child(updater)
		updater.status_changed.connect(func(text: String):
			version_label.text = "v%s" % GameVersion.VERSION + ("   %s" % text if text != "" else ""))

	import_picker = ImportDialog.new()
	add_child(import_picker)
	import_picker.confirmed.connect(_on_import_chosen)
	import_picker.cancelled.connect(func():
		_pending_import = {}
		field.show_toast("Import cancelled: nothing was added.", Color("#c4c0d4")))

	_confirm_reset = ConfirmationDialog.new()
	_confirm_reset.title = "Reset Progress"
	_confirm_reset.dialog_text = "Forget every spliced seed, recipe and your own Tier 1 seeds,\nand start again with the 4 base seeds?\nThis can't be undone (export your list first if you want to keep it).\nYour block art goes too (export the sprite sheet first to keep it)."
	_confirm_reset.ok_button_text = "Reset"
	_confirm_reset.confirmed.connect(_do_reset)
	add_child(_confirm_reset)

	_export_dialog = _file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Export Splicing List")
	_export_dialog.current_file = "seed_splicer_list.json"
	_export_dialog.file_selected.connect(_on_export_path)
	_import_dialog = _file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Import a Splicing List")
	_import_dialog.file_selected.connect(_on_import_path)
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
	settings_hub.export_list_requested.connect(_export_dialog.popup_centered_ratio)
	settings_hub.import_list_requested.connect(_import_dialog.popup_centered_ratio)
	settings_hub.export_sheet_requested.connect(_sheet_export_dialog.popup_centered_ratio)
	settings_hub.import_sheet_requested.connect(_sheet_import_dialog.popup_centered_ratio)
	settings_hub.display_requested.connect(settings_dialog.open)
	settings_hub.sound_requested.connect(sound_dialog.open)
	settings_hub.reset_requested.connect(_confirm_reset.popup_centered)
	sprites = SpriteFolder.new()  # keeps a copy of the sprite sheet in a folder you can open
	add_child(sprites)
	settings_hub.sprites_folder_requested.connect(_open_sprites_folder)
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
		if settings_dialog.visible:
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


## Open Sprites Folder: writes the latest copy of the sprite sheet, then opens its folder.
func _open_sprites_folder() -> void:
	var err := sprites.write_now()
	if err != OK:
		Audio.play(&"error")
		field.show_toast("Couldn't write the sprites folder (%s)" % error_string(err), Color("#ff8a8a"))
		return
	OS.shell_open(SpriteFolder.folder())
	field.show_toast("Sprite sheet copy: %s" % SpriteFolder.folder().path_join(SpriteFolder.SHEET_FILE), Color("#a6ff6e"), 5.0)


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


## Import List, step 1: read the file and let you say yes or no to each new seed.
func _on_import_path(path: String) -> void:
	var preview := Game.read_import(path)
	if not preview.ok:
		Audio.play(&"error")
		field.show_toast(preview.error, Color("#ff8a8a"))
		return
	if preview.new_seeds.is_empty():
		if Game.import_recipe_count(preview, []) == 0:
			field.show_toast("Nothing new in %s: you already have all %d of its seeds and splices." % [path.get_file(), preview.known.size()], Color("#c4c0d4"))
			return
		_finish_import(preview, [])  # no new seeds, only new splices between seeds you have
		return
	_pending_import = preview
	import_picker.open(preview, path.get_file())


## Step 2: add the seeds you said yes to.
func _on_import_chosen(chosen: Array) -> void:
	_finish_import(_pending_import, chosen)
	_pending_import = {}


func _finish_import(preview: Dictionary, chosen: Array) -> void:
	var r := Game.apply_import(preview, chosen)
	field.refresh_all()
	Audio.play(&"success")
	field.show_toast("Imported %d seed%s and %d splice%s  (%d left out, %d you already had%s)" % [
		r.seeds_added, "" if r.seeds_added == 1 else "s", r.recipes_added, "" if r.recipes_added == 1 else "s",
		r.seeds_declined, r.seeds_known, ", your recipe kept %d time%s" % [r.recipes_kept_yours, "" if r.recipes_kept_yours == 1 else "s"] if r.recipes_kept_yours > 0 else ""],
		Color("#a6ff6e"), 4.0)


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
	await get_tree().process_frame
	field.spawn_starters()


# --- look & feel: dark violet panels, square corners, sprout-green accents ----------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	var ink := Color("#0b0912")
	var panel_bg := Color("#15111e")
	var raised := Color("#211a2e")
	var hover := Color("#2c2340")
	var border := Color("#3b3150")
	var accent := Color("#a6ff6e")
	var text := Color("#ece8f7")

	t.set_stylebox("panel", "PanelContainer", _box(panel_bg, border, 2, 14))
	t.set_stylebox("panel", "Panel", _box(panel_bg, border, 2, 14))
	for cls in ["Button", "OptionButton", "ColorPickerButton"]:
		t.set_stylebox("normal", cls, _box(raised, border, 2, 8))
		t.set_stylebox("hover", cls, _box(hover, accent.darkened(0.35), 2, 8))
		t.set_stylebox("pressed", cls, _box(ink, accent, 2, 8))
		t.set_stylebox("hover_pressed", cls, _box(hover, accent, 2, 8))
		t.set_stylebox("disabled", cls, _box(panel_bg, Color("#2a2338"), 2, 8))
		t.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), accent.darkened(0.2), 2, 8))
		t.set_color("font_color", cls, text)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, accent)
		t.set_color("font_disabled_color", cls, Color("#6c6680"))
	t.set_stylebox("normal", "LineEdit", _box(ink, border, 2, 8))
	t.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), accent.darkened(0.2), 2, 8))
	t.set_color("font_color", "LineEdit", text)
	t.set_color("caret_color", "LineEdit", accent)
	t.set_color("selection_color", "LineEdit", Color(accent, 0.3))
	t.set_stylebox("panel", "ItemList", _box(ink, border, 2, 6))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("hovered", "ItemList", _box(raised, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("selected", "ItemList", _box(hover, accent.darkened(0.3), 2, 4))
	t.set_stylebox("selected_focus", "ItemList", _box(hover, accent.darkened(0.3), 2, 4))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", text)
	t.set_stylebox("panel", "TabContainer", _box(panel_bg, border, 2, 8))
	t.set_stylebox("tab_selected", "TabContainer", _box(panel_bg, accent, 2, 10))
	t.set_stylebox("tab_unselected", "TabContainer", _box(ink, border, 2, 10))
	t.set_stylebox("tab_hovered", "TabContainer", _box(raised, border, 2, 10))
	t.set_color("font_selected_color", "TabContainer", accent)
	t.set_color("font_unselected_color", "TabContainer", Color("#9a94b0"))
	t.set_color("font_hovered_color", "TabContainer", text)
	t.set_color("font_color", "Label", text)
	t.set_stylebox("panel", "TooltipPanel", _box(Color("#1d1828"), border, 2, 6))
	t.set_color("font_color", "TooltipLabel", text)
	t.set_stylebox("panel", "PopupPanel", _box(panel_bg, border, 2, 8))
	t.set_stylebox("panel", "AcceptDialog", _box(panel_bg, border, 2, 12))
	t.set_stylebox("embedded_border", "Window", _box(panel_bg, border, 2, 0))
	return t


func _box(bg: Color, border: Color, bw: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = false
	return sb
