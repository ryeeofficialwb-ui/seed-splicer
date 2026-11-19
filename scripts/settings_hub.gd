class_name SettingsHub
extends Control
## The Settings window (the Settings button in the top right corner): everything you don't need
## while playing. Sharing your seeds, the sprite sheet, display and sound settings, and Reset.
## Each button closes this window and starts its job (the signals are wired up in main.gd).

signal import_list_requested
signal export_list_requested
signal import_sheet_requested
signal export_sheet_requested
signal sprites_folder_requested
signal display_requested
signal sound_requested
signal reset_requested


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

	_heading(root, "Seed lists")
	var lists := _row(root)
	_button(lists, "Import List", "Merge a friend's splicing list into yours", import_list_requested)
	_button(lists, "Export List", "Save your splicing list (and its sprite sheet) to a file to share", export_list_requested)

	_heading(root, "Sprites")
	var sheets := _row(root)
	_button(sheets, "Import Sprite Sheet", "Bring in the block art you drew on an exported sprite sheet\n(the 4 boxes at the left of each seed's row)", import_sheet_requested)
	_button(sheets, "Export Sprite Sheet", "Save only the sprite sheet (PNG): 4 block-art boxes, then seed, sprout, sapling, crop and planted for every seed", export_sheet_requested)
	var folder := _row(root)
	_button(folder, "Open Sprites Folder", "Open the folder that always has the latest copy of your sprite sheet\n(sprites/ next to the game; it updates by itself whenever your seeds change)", sprites_folder_requested)

	_heading(root, "Game")
	var game := _row(root)
	_button(game, "Display", "Window mode, resolution and UI size (F11: fullscreen)", display_requested)
	_button(game, "Sound", "Music, sound effects and volumes", sound_requested)
	var reset := _row(root)
	_button(reset, "Reset Progress", "Forget everything and start over", reset_requested)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 38)
	close.pressed.connect(close_dialog)
	root.add_child(close)


func open() -> void:
	visible = true
	Audio.play(&"open")


func close_dialog() -> void:
	visible = false


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
