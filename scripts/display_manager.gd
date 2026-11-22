class_name DisplayManager
extends RefCounted
## Window mode, resolution and UI size. Everything is remembered in UserSettings.
##
## Modes:
##   WINDOWED    a normal window you can also drag-resize or maximize
##   BORDERLESS  "fullscreen windowed": covers the screen with no borders, instant alt-tab
##   FULLSCREEN  exclusive fullscreen
## Both fullscreen modes use your screen's own resolution; the resolution list is for windowed mode.
## PIXEL-PERFECT SCALE: the UI is pixel art, so the game is only ever drawn at WHOLE zooms
## (1x, 2x, 3x): every art pixel is the same number of screen pixels. The window shows the game at
## that zoom and the extra room is just more room (no stretching).
##   UI size Auto    the biggest zoom that still leaves at least 1280x720 of room
##   UI size 1x-3x   that zoom, as long as it leaves at least 960x540 of room (else smaller)
## A window smaller than that is drawn at 1x if it still has 1024x600 of room, else at 0.5x: still
## sharp, because the 26 px text becomes the font's crisp 13 px and an art pixel one screen pixel
## (a fraction like 0.8x would mangle the pixel font, e.g. in the Godot editor's embedded Game view).

enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }

const MODE_NAMES: Array[String] = ["Windowed", "Fullscreen Windowed (borderless)", "Fullscreen (exclusive)"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1280, 800),
	Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1680, 1050),
	Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1440), Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]
const UI_SIZES: Array[int] = [0, 1, 2, 3]  ## 0 = Auto
const UI_SIZE_NAMES: Array[String] = ["Auto", "1x", "2x", "3x"]
const BASE := Vector2(1280, 720)  ## the room the layout wants
const MIN_ROOM := Vector2(1280, 720)  ## the least room a chosen UI size may leave
const SMALL_ROOM := Vector2(1024, 600)  ## a smaller window still at 1x down to this (then 0.5x)
const MIN_WINDOW := Vector2i(1024, 600)
const DEFAULT_RES := Vector2i(1280, 720)


## Call once at startup.
static func load_and_apply(window: Window) -> void:
	window.min_size = MIN_WINDOW
	if not window.size_changed.is_connected(apply_scale.bind(window)):
		window.size_changed.connect(apply_scale.bind(window))
	apply_scale(window)
	var mode := int(UserSettings.get_value("display", "mode", Mode.WINDOWED))
	if mode == Mode.WINDOWED:
		set_resolution(window, saved_resolution())
	else:
		_apply_mode(window, mode)


static func saved_resolution() -> Vector2i:
	var v: Variant = UserSettings.get_value("display", "res", DEFAULT_RES)
	return v if v is Vector2i else DEFAULT_RES


## The chosen UI size: 0 = Auto, else 1-3.
static func ui_size() -> int:
	return clampi(int(UserSettings.get_value("display", "ui_size", 0)), 0, UI_SIZES[-1])


## The zoom the game is drawn at in a window this big.
static func zoom_for(window_size: Vector2, chosen: int) -> float:
	var fit := minf(window_size.x / BASE.x, window_size.y / BASE.y)
	if fit < 1.0:
		return 1.0 if window_size.x >= SMALL_ROOM.x and window_size.y >= SMALL_ROOM.y else 0.5
	var auto := floorf(fit)
	if chosen <= 0:
		return auto
	var k := float(chosen)
	while k > 1.0 and (window_size.x / k < MIN_ROOM.x or window_size.y / k < MIN_ROOM.y):
		k -= 1.0
	return k


static func apply_scale(window: Window) -> void:
	window.content_scale_factor = zoom_for(Vector2(window.size), ui_size())


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


static func set_ui_size(window: Window, chosen: int) -> void:
	UserSettings.set_value("display", "ui_size", chosen)
	apply_scale(window)


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
