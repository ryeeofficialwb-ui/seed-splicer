class_name MycoraHud
extends HBoxContainer
## Top bar: your Mycoras, how fast they come in, and the weather (with the time it has left).

const ICON := preload("res://assets/mycora/mycora_green_2x.png")

var _amount: Label
var _rate: Label
var _weather: Label
var _t := 0.0
## The weather line lives elsewhere (main.gd puts it under the top-right buttons).
var weather_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = ICON
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.tooltip_text = "Mycoras"
	add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	add_child(col)
	_amount = Label.new()
	_amount.add_theme_font_size_override("font_size", 18)
	_amount.add_theme_color_override("font_color", Mycora.COLOR)
	col.add_child(_amount)
	_rate = Label.new()
	_rate.add_theme_font_size_override("font_size", 11)
	_rate.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	col.add_child(_rate)
	_weather = Label.new()
	_weather.add_theme_font_size_override("font_size", 16)
	_weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weather.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	_weather.add_theme_constant_override("outline_size", 4)
	weather_label = _weather
	tooltip_text = "Mycoras: every 3 seconds each producing seed makes its drop.\nThe 4 base seeds always produce; unlock the others in the Seed Chest.\nRain (1 in 10, every 5 minutes) x2  ·  Shooting Star (1 in 250) x100"
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		_refresh()


func _refresh() -> void:
	var w := Weather.current()
	_amount.text = Bank.fmt(Bank.mycoras)
	_rate.text = "+%s / s" % Bank.fmt(Bank.rate_per_second() * float(w.mult)) if Bank.rate_per_second() * float(w.mult) >= 10.0 else "+%.1f / s" % (Bank.rate_per_second() * float(w.mult))
	var name := Weather.name_of(w)
	if name == "":
		_weather.text = ""
		return
	var left := int(w.end) - Weather.now()
	_weather.text = "%s  %d:%02d" % [name, left / 60, left % 60]
	_weather.add_theme_color_override("font_color", Color("#ffe066") if w.star else Color("#8fd0ff"))
