class_name DisplayManager
extends RefCounted
## Window mode, resolution and UI size. Everything is remembered in UserSettings.
##
## Modes:
##   WINDOWED    a normal window you can also drag-resize or maximize
##   BORDERLESS  "fullscreen windowed": covers the screen with no borders, instant alt-tab
##   FULLSCREEN  exclusive fullscreen
## Both fullscreen modes use your screen's own resolution; the resolution list is for windowed mode.
## The game always lays itself out as if the window were at least 1280x720, then scales up
## (UI size multiplies that), so every resolution shows the same screen, just sharper.

enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }

const MODE_NAMES: Array[String] = ["Windowed", "Fullscreen Windowed (borderless)", "Fullscreen (exclusive)"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1280, 800),
	Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1680, 1050),
	Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1440), Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]
const UI_SCALES: Array[float] = [0.75, 1.0, 1.25]
const UI_SCALE_NAMES: Array[String] = ["Small (75%)", "Normal (100%)", "Large (125%)"]
const MIN_WINDOW := Vector2i(960, 540)
const DEFAULT_RES := Vector2i(1280, 720)


## Call once at startup.
static func load_and_apply(window: Window) -> void:
	window.min_size = MIN_WINDOW
	window.content_scale_factor = ui_scale()
	var mode := int(UserSettings.get_value("display", "mode", Mode.WINDOWED))
	if mode == Mode.WINDOWED:
		set_resolution(window, saved_resolution())
	else:
		_apply_mode(window, mode)


static func saved_resolution() -> Vector2i:
	var v: Variant = UserSettings.get_value("display", "res", DEFAULT_RES)
	return v if v is Vector2i else DEFAULT_RES


static func ui_scale() -> float:
	return clampf(float(UserSettings.get_value("display", "ui_scale", 1.0)), UI_SCALES[0], UI_SCALES[-1])


static func current_mode(window: Window) -> int:
	match window.mode:
		Window.MODE_FULLSCREEN: return Mode.BORDERLESS
		Window.MODE_EXCLUSIVE_FULLSCREEN: return Mode.FULLSCREEN
	return Mode.WINDOWED


static func set_mode(window: Window, mode: int) -> void:
	var was := current_mode(window)
	if was == mode:
		return
	if was == Mode.WINDOWED and window.mode == Window.MODE_WINDOWED:
		UserSettings.set_value("display", "res", window.size)  # so we can come back to it
	if mode == Mode.WINDOWED:
		UserSettings.set_value("display", "mode", mode)
		set_resolution(window, saved_resolution())
	else:
		UserSettings.set_value("display", "mode", mode)
		UserSettings.set_value("display", "fullscreen_mode", mode)
		_apply_mode(window, mode)


## Windowed mode at an exact size (switches to windowed first), centered on the screen.
## Clamped so the window, title bar included, always fits on the screen.
static func set_resolution(window: Window, res: Vector2i) -> void:
	_apply_mode(window, Mode.WINDOWED)
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.size = res
	var deco := window.get_size_with_decorations() - window.size
	var fit := Vector2i(mini(res.x, usable.size.x - deco.x), mini(res.y, usable.size.y - deco.y))
	fit = Vector2i(maxi(fit.x, MIN_WINDOW.x), maxi(fit.y, MIN_WINDOW.y))
	window.size = fit
	var outer := fit + deco
	window.position = usable.position + (usable.size - outer) / 2 + Vector2i(deco.x / 2, deco.y - deco.x / 2)
	UserSettings.set_value("display", "res", fit)


static func set_ui_scale(window: Window, scale: float) -> void:
	window.content_scale_factor = scale
	UserSettings.set_value("display", "ui_scale", scale)


## F11: windowed <-> your last fullscreen mode (borderless by default).
static func toggle_fullscreen(window: Window) -> void:
	if current_mode(window) == Mode.WINDOWED:
		set_mode(window, int(UserSettings.get_value("display", "fullscreen_mode", Mode.BORDERLESS)))
	else:
		set_mode(window, Mode.WINDOWED)


## Resolutions that fit on this screen, plus the current size if it isn't one of them.
static func available_resolutions(window: Window) -> Array[Vector2i]:
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var deco := window.get_size_with_decorations() - window.size
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= usable.size.x - deco.x and r.y <= usable.size.y - deco.y:
			out.append(r)
	if window.mode == Window.MODE_WINDOWED and not out.has(window.size):
		out.append(window.size)
		out.sort_custom(func(a: Vector2i, b: Vector2i): return a.x * a.y < b.x * b.y)
	return out


static func _apply_mode(window: Window, mode: int) -> void:
	match mode:
		Mode.WINDOWED:
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
		Mode.BORDERLESS:
			window.mode = Window.MODE_FULLSCREEN
		Mode.FULLSCREEN:
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
