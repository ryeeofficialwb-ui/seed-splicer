class_name SoundDialog
extends Control
## Sound menu: music and effects volumes, which song plays, and the credits.

var _music_slider: HSlider
var _sfx_slider: HSlider
var _track: OptionButton
var _now: Label
var _busy := false


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
	panel.custom_minimum_size = Vector2(540, 0)
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Sound"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#a6ff6e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)
	_music_slider = _slider(grid, "Music volume", func(v): Audio.set_music_volume(v))
	_sfx_slider = _slider(grid, "Effects volume", func(v): Audio.set_sfx_volume(v))
	var l := Label.new()
	l.text = "Music"
	grid.add_child(l)
	var music_row := HBoxContainer.new()
	music_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(music_row)
	_track = OptionButton.new()
	_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_track.add_item("Shuffle all songs")
	for m in Audio.MUSIC:
		_track.add_item("Only: " + String(m.title))
	_track.item_selected.connect(func(i):
		if not _busy:
			Audio.set_track_choice(i - 1))  # item 0 = shuffle (-1)
	music_row.add_child(_track)
	var next := Button.new()
	next.text = "Next song"
	next.pressed.connect(Audio.next_track)
	music_row.add_child(next)
	_now = Label.new()
	_now.add_theme_font_size_override("font_size", 13)
	_now.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85))
	root.add_child(_now)
	Audio.track_changed.connect(func(_t): _update_now())

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0, 36)
	close.pressed.connect(func(): visible = false)
	root.add_child(close)

	var credits := Label.new()
	credits.text = "Music: \"Abstraction\" Music Loop Bundle (public domain, CC0) - abstractionmusic.com\nSound effects: Cozy FX - Game Assets by Pizza Doggy"
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_size_override("font_size", 12)
	credits.add_theme_color_override("font_color", Color(0.6, 0.57, 0.72))
	root.add_child(credits)


func open() -> void:
	_busy = true
	_music_slider.value = Audio.music_volume
	_sfx_slider.value = Audio.sfx_volume
	_track.select(Audio.track_choice + 1)
	_busy = false
	_update_now()
	visible = true
	Audio.play(&"open")


func _update_now() -> void:
	if _now:
		var t := Audio.current_title()
		_now.text = ("Now playing: %s - %s" % [t, Audio.ARTIST]) if t != "" else "Music is off"


func _slider(grid: GridContainer, caption: String, on_change: Callable) -> HSlider:
	var l := Label.new()
	l.text = caption
	grid.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 24)
	s.value_changed.connect(func(v):
		if not _busy:
			on_change.call(v))
	grid.add_child(s)
	return s


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false
		get_viewport().set_input_as_handled()
