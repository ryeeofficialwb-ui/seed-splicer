class_name SettingsHub
extends Control
## The Settings window (the Settings button in the top right corner): everything you don't need
## while playing. Two tabs:
##   Settings    your name (the contributor on seeds you make), sharing your seeds, the sprite
##               sheet, display and sound settings, and Reset. Each button closes this window and
##               starts its job (the signals are wired up in main.gd).
##   Statistics  time played and what you've found so far.

signal import_list_requested
signal export_list_requested
signal import_sheet_requested
signal export_sheet_requested
signal sprites_folder_requested
signal display_requested
signal sound_requested
signal reset_requested

var _tabs: TabBar
var _settings_page: VBoxContainer
var _stats_page: VBoxContainer
var _name_edit: LineEdit
var _time_label: Label
var _stats_text: RichTextLabel


func _ready() -> void:
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
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#a6ff6e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_tabs = TabBar.new()
	_tabs.add_tab("Settings")
	_tabs.add_tab("Statistics")
	_tabs.tab_changed.connect(_show_tab)
	root.add_child(_tabs)

	# --- Settings page
	_settings_page = VBoxContainer.new()
	_settings_page.add_theme_constant_override("separation", 8)
	root.add_child(_settings_page)

	_heading(_settings_page, "You")
	var you := _row(_settings_page)
	var nl := Label.new()
	nl.text = "Your name"
	you.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Shown next to the approval stamp on seeds you make"
	_name_edit.max_length = 32
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.tooltip_text = "Every seed you make from now on is signed with this name (the contributor).\nIt shows next to the approval stamp once the seed is on the official list."
	_name_edit.text_changed.connect(func(t): Game.set_player_name(t))
	you.add_child(_name_edit)

	_heading(_settings_page, "Seed lists")
	var lists := _row(_settings_page)
	_button(lists, "Import List", "Merge a friend's splicing list into yours", import_list_requested)
	_button(lists, "Export List", "Save your splicing list (and its sprite sheet) to a file to share", export_list_requested)

	_heading(_settings_page, "Sprites")
	var sheets := _row(_settings_page)
	_button(sheets, "Import Sprite Sheet", "Bring in the block art you drew on an exported sprite sheet\n(the 4 boxes at the left of each seed's row)", import_sheet_requested)
	_button(sheets, "Export Sprite Sheet", "Save only the sprite sheet (PNG): 4 block-art boxes, then seed, sprout, sapling, crop and planted for every seed", export_sheet_requested)
	var folder := _row(_settings_page)
	_button(folder, "Open Sprites Folder", "Open the folder that always has the latest copy of your sprite sheet\n(sprites/ next to the game; it updates by itself whenever your seeds change)", sprites_folder_requested)

	_heading(_settings_page, "Game")
	var game := _row(_settings_page)
	_button(game, "Display", "Window mode, resolution and UI size (F11: fullscreen)", display_requested)
	_button(game, "Sound", "Music, sound effects and volumes", sound_requested)
	var reset := _row(_settings_page)
	_button(reset, "Reset Progress", "Forget everything and start over", reset_requested)

	# --- Statistics page
	_stats_page = VBoxContainer.new()
	_stats_page.add_theme_constant_override("separation", 8)
	_stats_page.visible = false
	root.add_child(_stats_page)
	_heading(_stats_page, "Time played")
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 30)
	_time_label.add_theme_color_override("font_color", Color("#a6ff6e"))
	_stats_page.add_child(_time_label)
	_stats_text = RichTextLabel.new()
	_stats_text.bbcode_enabled = true
	_stats_text.fit_content = true
	_stats_text.scroll_active = false
	_stats_text.custom_minimum_size = Vector2(480, 0)
	_stats_page.add_child(_stats_text)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 38)
	close.pressed.connect(close_dialog)
	root.add_child(close)


func open() -> void:
	_name_edit.text = Game.player_name()
	_refresh_stats()
	visible = true
	Audio.play(&"open")


func open_stats() -> void:
	open()
	_tabs.current_tab = 1


func close_dialog() -> void:
	visible = false


func _show_tab(i: int) -> void:
	_settings_page.visible = i == 0
	_stats_page.visible = i == 1
	_refresh_stats()


func _process(_delta: float) -> void:
	if visible and _stats_page.visible:
		_time_label.text = Game.duration_text(Game.stats.play_seconds)


func _refresh_stats() -> void:
	_time_label.text = Game.duration_text(Game.stats.play_seconds)
	var tier1 := 0
	var top := ""
	var top_r := 0
	var approved := 0
	var approved_names := {}
	var mine := 0
	var me := Game.player_name().to_lower()
	var art := 0
	var farm := 0
	for id in Game.order:
		var s: Dictionary = Game.seeds[id]
		if s.get("parents", []).is_empty():
			tier1 += 1
		if int(s.rarity) > top_r:
			top_r = int(s.rarity)
			top = s.name
		if Approvals.is_approved(s) and not approved_names.has(String(s.name).to_lower()):
			approved_names[String(s.name).to_lower()] = true
			approved += 1
		if me != "" and String(s.get("made_by", "")).to_lower() == me:
			mine += 1
		if BlockArt.has_art(id):
			art += 1
		if s.get("tag", "") != "not_farmable":
			farm += 1
	var lines := PackedStringArray()
	var row := func(k: String, v: String) -> void:
		lines.append("[color=#ffc94a]%s[/color]   %s" % [k, v])
	row.call("Sessions", str(int(Game.stats.sessions)))
	row.call("Playing since", Time.get_date_string_from_unix_time(int(Game.stats.first_played)))
	row.call("Seeds discovered", "%d   (%d Tier 1, %d spliced)" % [Game.seeds.size(), tier1, Game.seeds.size() - tier1])
	row.call("Splices discovered", str(Game.recipes.size()))
	row.call("Farmable or Bountiful", str(farm))
	if top != "":
		row.call("Rarest seed", "%s  (R%d %s)" % [top, top_r, SeedArt.rarity_tier(top_r)[0]])
	row.call("Approved seeds you have", "%d of %d on the official list" % [approved, Approvals.official_count()])
	if me != "":
		row.call("Seeds made by you", str(mine))
	row.call("Seeds with block art", str(art))
	row.call("Graveyard", "%d seeds" % Approvals.graveyard().size())
	row.call("Game version", "v%s" % GameVersion.VERSION)
	_stats_text.text = "\n".join(lines)


func _heading(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("#ffc94a"))
	parent.add_child(l)


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	parent.add_child(r)
	return r


func _button(parent: Control, text: String, tip: String, sig: Signal) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 34)
	b.pressed.connect(func():
		close_dialog()
		sig.emit())
	parent.add_child(b)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()
