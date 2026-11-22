class_name SettingsHub
extends Control
## The Settings window (the gear in the top right corner). Tabs, so nothing is one long list:
##   Account     who you're signed in as (your account name signs every seed you make),
##               Upload my seeds, Log out
##   Game        Display and Sound, Replay tutorial, Reset Progress
##   Statistics  time played and what you've found so far
##   Developer   (developer build only) Submissions, Export List, the sprite sheet
## Buttons that start a job close this window first (the signals are wired up in main.gd).

signal export_list_requested
signal import_sheet_requested
signal export_sheet_requested
signal reset_requested
signal upload_requested
signal submissions_requested
signal logout_requested
signal tutorial_requested

const TAB_ACCOUNT := 0
const TAB_GAME := 1
const TAB_STATS := 2
const TAB_DEV := 3

var display_page: SettingsDialog
var sound_page: SoundDialog
var _tabs: TabBar
var _pages: Array[Control] = []
var _who: Label
var _who_note: Label
var _out_btn: Button
var _stats_page: VBoxContainer
var _scroll: ScrollContainer
var _pages_box: VBoxContainer
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
	panel.theme_type_variation = &"WindowPanel"
	panel.custom_minimum_size = Vector2(920, 0)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	head.add_child(UiKit.icon("icon_gear"))
	var title := Label.new()
	title.text = "Settings"
	title.theme_type_variation = &"TitleLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.icon = UiKit.tex("icon_close")
	close.tooltip_text = "Close (Esc)"
	close.pressed.connect(close_dialog)
	head.add_child(close)

	_tabs = TabBar.new()
	_tabs.add_tab("Account")
	_tabs.add_tab("Game")
	_tabs.add_tab("Statistics")
	if DevMode.on():
		_tabs.add_tab("Developer")
	_tabs.tab_changed.connect(_show_tab)
	root.add_child(_tabs)
	# the pages scroll when the window is too short to show a whole tab
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_pages_box = VBoxContainer.new()
	_pages_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pages_box)

	# --- Account
	var account := _page(_pages_box)
	var who_row := HBoxContainer.new()
	who_row.add_theme_constant_override("separation", 8)
	account.add_child(who_row)
	who_row.add_child(UiKit.icon("icon_user"))
	_who = Label.new()
	_who.theme_type_variation = &"HeadingLabel"
	who_row.add_child(_who)
	_who_note = _note(account, "")
	_note(account, "Your account name is on every seed you make. Upload seeds you're proud of: approved ones reach every player in the next update, with your name and the approval stamp.")
	var acc_row := _row(account)
	_button(acc_row, "Upload my seeds", "Send seeds of yours to the developer for review", upload_requested, "icon_upload")
	_out_btn = _button(acc_row, "Log out", "Sign out of this PC (you'll need to sign in again to play)", logout_requested)
	_out_btn.size_flags_horizontal = Control.SIZE_SHRINK_END

	# --- Game
	var game := _page(_pages_box)
	_heading(game, "Display")
	display_page = SettingsDialog.new()
	game.add_child(display_page)
	game.add_child(HSeparator.new())
	_heading(game, "Sound")
	sound_page = SoundDialog.new()
	game.add_child(sound_page)
	game.add_child(HSeparator.new())
	var game_row := _row(game)
	_button(game_row, "Replay tutorial", "Walk through the basics again", tutorial_requested, "icon_help")
	var reset := _button(game_row, "Reset Progress", "Forget everything and start over", reset_requested)
	reset.theme_type_variation = &"DangerButton"

	# --- Statistics
	_stats_page = _page(_pages_box)
	_heading(_stats_page, "Time played")
	_time_label = Label.new()
	_time_label.theme_type_variation = &"TitleLabel"
	_stats_page.add_child(_time_label)
	_stats_text = RichTextLabel.new()
	_stats_text.bbcode_enabled = true
	_stats_text.fit_content = true
	_stats_text.scroll_active = false
	_stats_text.custom_minimum_size = Vector2(880, 0)
	_stats_page.add_child(_stats_text)

	# --- Developer
	if DevMode.on():
		var dev := _page(_pages_box)
		_note(dev, "Only in your own game (the editor or the Developer build).")
		_heading(dev, "Players' seeds")
		_button(_row(dev), "Submissions", "Review the seeds players uploaded", submissions_requested)
		_heading(dev, "Files")
		var files := _row(dev)
		_button(files, "Export List", "Save your splicing list (and its sprite sheet) to a file (backups, Mush Mantle)", export_list_requested)
		_button(files, "Export Sprite Sheet", "Save only the sprite sheet (PNG): 4 block-art boxes, then seed, sprout, sapling, crop and planted for every seed", export_sheet_requested)
		_button(_row(dev), "Import Sprite Sheet", "Bring in the block art you drew on an exported sprite sheet (the 4 boxes at the left of each seed's row)", import_sheet_requested)

	Online.session_changed.connect(_refresh_account)
	_show_tab(TAB_ACCOUNT)


func open(tab := -1) -> void:
	_refresh_account()
	_refresh_stats()
	display_page.refresh()
	sound_page.open()
	if tab >= 0 and tab < _tabs.tab_count:
		_tabs.current_tab = tab
	visible = true
	_fit_scroll.call_deferred()
	Audio.play(&"open")


func open_stats() -> void:
	open(TAB_STATS)


func close_dialog() -> void:
	visible = false


func _show_tab(i: int) -> void:
	for k in _pages.size():
		_pages[k].visible = k == i
	if i == TAB_STATS:
		_refresh_stats()
	_fit_scroll.call_deferred()


## As tall as the page, but never taller than the window has room for (then it scrolls).
func _fit_scroll() -> void:
	if not is_inside_tree():
		return
	_scroll.scroll_vertical = 0
	var want := _pages_box.get_combined_minimum_size().y
	var room := get_viewport_rect().size.y - 190.0  # the window's title, tabs and margins
	_scroll.custom_minimum_size.y = clampf(want, 120.0, maxf(120.0, room))


func _refresh_account() -> void:
	if not is_instance_valid(_who):
		return
	if Online.logged_in():
		_who.text = "Signed in as %s%s" % [Online.username, "  (developer)" if Online.is_admin else ""]
		_who_note.text = ""
	elif Online.has_saved_session():
		_who.text = "Signed in as %s" % Online.saved_username()
		_who_note.text = "Offline right now: uploading waits until you're back online."
	else:
		_who.text = "Not signed in"
		_who_note.text = "Online features aren't set up in this version." if not Online.configured() else ""
	var signed := Online.logged_in() or Online.has_saved_session()
	_out_btn.text = "Log out" if signed else "Sign in"
	_out_btn.theme_type_variation = &"DangerButton" if signed else &"ShopButton"
	_out_btn.disabled = not Online.configured()


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
	row.call("Mycoras", "%s  (+%s every 3 s)" % [Bank.fmt(Bank.mycoras), Bank.fmt(Bank.rate_per_tick())])
	row.call("Mycoras made in total", Bank.fmt(Bank.earned_total))
	row.call("Packs opened", "%d  ·  %d seeds unlocked" % [Bank.packs, Bank.unlocked.size()])
	var w := Weather.current()
	row.call("Weather now", Weather.name_of(w) if Weather.name_of(w) != "" else "clear")
	row.call("Game version", "v%s" % GameVersion.VERSION)
	_stats_text.text = "\n".join(lines)


func _page(root: Control) -> VBoxContainer:
	var p := VBoxContainer.new()
	p.add_theme_constant_override("separation", 8)
	root.add_child(p)
	_pages.append(p)
	return p


func _heading(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"HeadingLabel"
	parent.add_child(l)


func _note(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"NoteLabel"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(880, 0)
	parent.add_child(l)
	return l


func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	parent.add_child(r)
	return r


func _button(parent: Control, text: String, tip: String, sig: Signal, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	if icon_name != "":
		b.icon = UiKit.tex(icon_name)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(func():
		close_dialog()
		sig.emit())
	parent.add_child(b)
	return b


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()
