class_name WeatherLayer
extends Control
## Over the void: rain falling while it rains, shooting stars streaking by during a Shooting Star.

const DROPS := 140

var _drops: Array = []
var _stars: Array = []   # [x, y, age]
var _star_t := 0.0
var _w := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in DROPS:
		_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.0)))


func _process(delta: float) -> void:
	_w = Weather.current()
	if not (_w.rain or _w.star):
		if not _stars.is_empty() or visible:
			_stars.clear()
			queue_redraw()
		return
	if _w.rain:
		for i in _drops.size():
			var d: Vector3 = _drops[i]
			d.y += delta * 0.9 * d.z
			d.x += delta * 0.12 * d.z
			if d.y > 1.0:
				d = Vector3(randf(), 0.0, randf_range(0.6, 1.0))
			_drops[i] = d
	if _w.star:
		_star_t -= delta
		if _star_t <= 0.0:
			_star_t = randf_range(0.35, 1.1)
			_stars.append([randf_range(0.1, 1.0), randf_range(0.0, 0.45), 0.0])
		for s in _stars:
			s[2] += delta
		_stars = _stars.filter(func(s): return s[2] < 0.9)
	queue_redraw()


func _draw() -> void:
	if _w.is_empty() or not (_w.rain or _w.star):
		return
	if _w.rain:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.18, 0.18))
		for d in _drops:
			var p := Vector2(d.x * size.x, d.y * size.y)
			draw_line(p, p + Vector2(-3, -14) * d.z, Color(0.7, 0.85, 1.0, 0.35 * d.z), 1.5)
	if _w.star:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.25, 0.05, 0.10))
		for s in _stars:
			var head: Vector2 = Vector2(float(s[0]) * size.x, float(s[1]) * size.y) + Vector2(-260, 150) * float(s[2])
			var fade: float = 1.0 - float(s[2]) / 0.9
			for k in 10:
				var t := k / 10.0
				draw_line(head + Vector2(26, -15) * t * 4.0, head + Vector2(26, -15) * (t + 0.1) * 4.0,
					Color(1.0, 0.95, 0.6, fade * (1.0 - t)), 3.0 * (1.0 - t) + 1.0)
			draw_circle(head, 3.0, Color(1, 1, 0.85, fade))
