class_name WeatherLayer
extends Control
## Over the void, in pixel art (everything snapped to 2-pixel "art pixels", like the UI):
##   Rain            falling drops
##   Thunderstorm    a dark sky, heavy slanted rain, and lightning bolts with a white flash
##                   (each strike emits `lightning`: the Mycora counter lights up)
##   Shooting Star   streaks with a glowing head

signal lightning

const PX := 2.0  ## one art pixel
const DROPS := 140
const STORM_DROPS := 260

var _drops: Array = []
var _stars: Array = []   # [x, y, age]
var _star_t := 0.0
var _bolt: Array = []    # points of the current bolt (local pixels)
var _bolt_age := 9.0
var _flash := 0.0
var _next_strike := 1.5
var _w := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in STORM_DROPS:
		_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.0)))


func _snap(v: Vector2) -> Vector2:
	return (v / PX).floor() * PX


func _process(delta: float) -> void:
	_w = Weather.current()
	var storm: bool = _w.get("thunder", false)
	if not (_w.rain or _w.star or storm):
		if not _stars.is_empty() or _flash > 0.0 or not _bolt.is_empty():
			_stars.clear()
			_bolt.clear()
			_flash = 0.0
		queue_redraw()
		return
	if _w.rain or storm:
		var speed := 1.5 if storm else 0.9
		var drift := 0.3 if storm else 0.12
		for i in _drops.size():
			var d: Vector3 = _drops[i]
			d.y += delta * speed * d.z
			d.x += delta * drift * d.z
			if d.y > 1.0:
				d = Vector3(randf(), 0.0, randf_range(0.6, 1.0))
			if d.x > 1.0:
				d.x -= 1.0
			_drops[i] = d
	if storm:
		_next_strike -= delta
		if _next_strike <= 0.0:
			_strike()
			_next_strike = randf_range(2.5, 7.0)
	_bolt_age += delta
	_flash = maxf(0.0, _flash - delta * 2.5)
	if _w.star:
		_star_t -= delta
		if _star_t <= 0.0:
			_star_t = randf_range(0.35, 1.1)
			_stars.append([randf_range(0.1, 1.0), randf_range(0.0, 0.45), 0.0])
		for s in _stars:
			s[2] += delta
		_stars = _stars.filter(func(s): return s[2] < 0.9)
	queue_redraw()


## One lightning bolt: a jagged path from the top, built on the art-pixel grid.
func _strike() -> void:
	_bolt.clear()
	var x := randf_range(size.x * 0.1, size.x * 0.9)
	var y := 0.0
	var bottom := randf_range(size.y * 0.45, size.y * 0.8)
	while y < bottom:
		_bolt.append(_snap(Vector2(x, y)))
		y += randf_range(18.0, 34.0)
		x += randf_range(-22.0, 22.0)
	_bolt.append(_snap(Vector2(x, y)))
	_bolt_age = 0.0
	_flash = 1.0
	lightning.emit()


func _draw() -> void:
	if _w.is_empty():
		return
	var storm: bool = _w.get("thunder", false)
	if not (_w.rain or _w.star or storm):
		return
	if storm:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.02, 0.08, 0.42))
	elif _w.rain:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.18, 0.18))
	if _w.rain or storm:
		var n := STORM_DROPS if storm else DROPS
		var len_px := 6.0 if storm else 4.0  # art pixels long
		for i in n:
			var d: Vector3 = _drops[i]
			var p := _snap(Vector2(d.x * size.x, d.y * size.y))
			var c := Color(0.7, 0.85, 1.0, (0.45 if storm else 0.35) * d.z)
			var lean := 1 if storm else 0
			for k in int(len_px):
				draw_rect(Rect2(p + Vector2(-k / 2 * PX * lean, -k * PX), Vector2(PX, PX)), c)
	if storm and not _bolt.is_empty() and _bolt_age < 0.35:
		var fade := 1.0 - _bolt_age / 0.35
		for i in _bolt.size() - 1:
			_pixel_line(_bolt[i], _bolt[i + 1], Color(0.75, 0.65, 1.0, 0.45 * fade), 3)
		for i in _bolt.size() - 1:
			_pixel_line(_bolt[i], _bolt[i + 1], Color(1, 1, 0.92, fade), 1)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.9, 1.0, 0.35 * _flash * _flash))
	if _w.star:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.25, 0.05, 0.10))
		for s in _stars:
			var head: Vector2 = _snap(Vector2(float(s[0]) * size.x, float(s[1]) * size.y) + Vector2(-260, 150) * float(s[2]))
			var fade: float = 1.0 - float(s[2]) / 0.9
			for k in 14:  # the tail: art pixels up and to the right, fading
				var t := k / 14.0
				var p := head + Vector2(k * 2, -k) * PX
				draw_rect(Rect2(_snap(p), Vector2(PX, PX) * (2.0 if k < 3 else 1.0)), Color(1.0, 0.95, 0.6, fade * (1.0 - t)))
			draw_rect(Rect2(head - Vector2(PX, PX), Vector2(PX, PX) * 3.0), Color(1, 1, 0.85, fade))


## A line of whole art pixels (thickness in art pixels).
func _pixel_line(a: Vector2, b: Vector2, c: Color, thick: int) -> void:
	var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y)) / PX))
	var half := float(thick - 1) / 2.0 * PX
	for i in steps + 1:
		var p := _snap(a.lerp(b, float(i) / steps))
		draw_rect(Rect2(p - Vector2(half, half), Vector2(PX * thick, PX * thick)), c)
