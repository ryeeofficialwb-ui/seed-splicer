class_name MycoraHud
extends PanelContainer
## Top bar: your Mycoras and how fast they come in (a pixel chip), plus the weather chip
## (main.gd puts it under the top-right buttons): its icon, name, boost and the time it has left.

const ICON := preload("res://assets/mycora/mycora_green_2x.png")

var _amount: Label
var _rate: Label
var _weather: Label
var _weather_icon: TextureRect
var _t := 0.0
var _flash := 0.0
## The weather chip lives elsewhere (main.gd puts it under the top-right buttons).
var weather_chip: PanelContainer


func _ready() -> void:
	theme_type_variation = &"ChipPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = ICON
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	_amount = Label.new()
	_amount.add_theme_font_size_override("font_size", UiKit.BIG)
	_amount.add_theme_color_override("font_color", Mycora.COLOR)
	row.add_child(_amount)
	_rate = Label.new()
	_rate.theme_type_variation = &"NoteLabel"
	_rate.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_rate)
	tooltip_text = "Mycoras: every 3 seconds each producing seed makes its drop.\nThe 4 base seeds always produce; unlock the others from packs in the Shop.\nWeather (every 5 minutes): Rain 1 in 10 x2  ·  Thunderstorm 1 in 50 x100  ·  Shooting Star 1 in 250 x100\nWhile the game is closed, seeds keep producing for 1 hour."

	weather_chip = PanelContainer.new()
	weather_chip.theme_type_variation = &"ChipPanel"
	weather_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 6)
	wrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weather_chip.add_child(wrow)
	_weather_icon = TextureRect.new()
	_weather_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_weather_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_weather_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrow.add_child(_weather_icon)
	_weather = Label.new()
	wrow.add_child(_weather)
	weather_chip.tooltip_text = tooltip_text
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		_amount.modulate = Color(1, 1, 1).lerp(Color(2.2, 2.2, 1.4), _flash)
	if _t >= 0.25:
		_t = 0.0
		_refresh()


## A lightning strike lights the counter up (weather_layer.gd calls this).
func flash() -> void:
	_flash = 1.0


func _refresh() -> void:
	var w := Weather.current()
	_amount.text = Bank.fmt(Bank.mycoras)
	var per_s := Bank.rate_per_second() * float(w.mult)
	_rate.text = "+%s / s" % Bank.fmt(per_s) if per_s >= 10.0 else "+%.1f / s" % per_s
	var weather_name := Weather.name_of(w)
	weather_chip.visible = weather_name != ""
	if weather_name == "":
		return
	var left := int(w.end) - Weather.now()
	_weather.text = "%s  %d:%02d" % [weather_name, left / 60, left % 60]
	_weather_icon.texture = UiKit.tex(Weather.icon_of(w))
	var c := Color("#8fd0ff")
	if w.star:
		c = Color("#ffe066")
	elif w.get("thunder", false):
		c = Color("#c9b8ff")
	_weather.add_theme_color_override("font_color", c)
