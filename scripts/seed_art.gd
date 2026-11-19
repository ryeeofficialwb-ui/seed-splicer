class_name SeedArt
extends RefCounted
## Paints a 32x32 seed texture from the Aseprite template (assets/seed_template.png).
##
## The template is role-coded (see art/make_art.lua): every pixel says whether it is
## body outline / shadow / body / light / shine or sprout outline / dark / mid / light.
## The body pixels get their color from one of six patterns using the seed's two
## colors, the sprout pixels from the sprout color. Shading is hue-shifted
## (shadows lean blue-purple, highlights lean warm) so every seed looks lit, whatever
## colors you pick.

enum Pattern { HALF, STRIPES, ZIGZAG, DOTS, VLINES, HLINES }
const PATTERN_NAMES: Array[String] = [
	"Half Color", "Stripes", "Zigzag Stripes", "Shade + Polkadots", "Vertical Lines", "Horizontal Lines",
]

enum Role { NONE, OUTLINE, SHADOW, BODY, LIGHT, SHINE, S_OUTLINE, S_DARK, S_MID, S_LIGHT }
const ROLE_COLORS := {
	0x000000: Role.OUTLINE, 0x404040: Role.SHADOW, 0x808080: Role.BODY, 0xC0C0C0: Role.LIGHT,
	0xFFFFFF: Role.SHINE, 0x004000: Role.S_OUTLINE, 0x008000: Role.S_DARK, 0x00C000: Role.S_MID,
	0x80FF80: Role.S_LIGHT,
}
const SIZE := 32
const TEMPLATE_PATH := "res://assets/seed_template.png"
const INK := Color(0.07, 0.05, 0.11) # outline base: a deep violet-black

const META_PATH := "res://assets/seed_template.json"  ## written by art/make_art.lua

static var _roles := PackedByteArray()
static var _cache := {}
static var _angle := deg_to_rad(50.0)       ## tilt of the seed (degrees up from horizontal)
static var _center := Vector2(13.4, 18.7)   ## middle of the seed in the template


## Texture for a seed (Dictionary with pattern, colors, sprout, pattern_seed). Cached.
static func texture_for(seed: Dictionary) -> ImageTexture:
	var key := _key(seed)
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(render(seed))
	_cache[key] = tex
	return tex


static func render(seed: Dictionary) -> Image:
	_ensure_template()
	var pattern: int = int(seed.get("pattern", Pattern.HALF))
	var colors: Array = seed.get("colors", ["#888888", "#555555"])
	var c1 := Color(colors[0])
	var c2 := Color(colors[1])
	var sprout := Color(seed.get("sprout", "#6fcf4a"))
	var params := _pattern_params(pattern, int(seed.get("pattern_seed", 0)))

	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var role := _roles[y * SIZE + x]
			if role == Role.NONE:
				continue
			var out: Color
			match role:
				Role.OUTLINE:
					out = INK.lerp(c1 if pattern_pick(pattern, params, x, y) == 0 else c2, 0.22)
				Role.SHADOW, Role.BODY, Role.LIGHT, Role.SHINE:
					var base := c1 if pattern_pick(pattern, params, x, y) == 0 else c2
					match role:
						Role.SHADOW: out = shade(base, -1.0)
						Role.BODY: out = base
						Role.LIGHT: out = shade(base, 1.0)
						_: out = shade(base, 2.6)
				Role.S_OUTLINE:
					out = INK.lerp(sprout, 0.22)
				Role.S_DARK:
					out = shade(sprout, -1.0)
				Role.S_MID:
					out = sprout
				Role.S_LIGHT:
					out = shade(sprout, 1.2)
			out.a = 1.0
			img.set_pixel(x, y, out)
	return img


## Where a template pixel sits relative to the seed: x = along its length (+ toward the
## sprout tip), y = across it (+ toward the shadow side). The seed is tilted, so stripes
## use these instead of screen x/y to run neatly across the seed.
static func seed_uv(x: int, y: int) -> Vector2:
	var dx := x + 0.5 - _center.x
	var dy := y + 0.5 - _center.y
	return Vector2(dx * cos(_angle) - dy * sin(_angle), dx * sin(_angle) + dy * cos(_angle))


## 0 = first color, 1 = second color. x/y are template pixels.
static func pattern_pick(pattern: int, p: Dictionary, x: int, y: int) -> int:
	match pattern:
		Pattern.HALF:
			var uv := seed_uv(x, y)
			if p.lengthwise:  # split down the length of the seed
				return 0 if uv.y < p.off * 0.7 else 1
			return 0 if uv.x < p.off * 0.7 else 1  # split across the middle
		Pattern.STRIPES:
			return posmod(floori((seed_uv(x, y).x + p.off) / p.w), 2)
		Pattern.ZIGZAG:
			var uv := seed_uv(x, y)
			var t: float = fposmod(uv.y + p.phase, p.amp * 2.0)
			var tri: float = absf(t - p.amp)
			return posmod(floori((uv.x + tri + p.off) / p.w), 2)
		Pattern.DOTS:
			var sp: int = p.sp
			var row: int = floori(float(y + p.oy) / sp)
			var lx: int = posmod(x + p.ox + (row % 2) * (sp / 2), sp)
			var ly: int = posmod(y + p.oy, sp)
			var c: int = sp / 2
			if p.big:
				return 1 if (lx == c or lx == c - 1) and (ly == c or ly == c - 1) else 0
			return 1 if (lx == c and absi(ly - c) <= 1) or (ly == c and absi(lx - c) <= 1) else 0
		Pattern.VLINES:
			return 1 if posmod(x + p.off, p.sp) < p.thick else 0
		Pattern.HLINES:
			return 1 if posmod(y + p.off, p.sp) < p.thick else 0
	return 0


## Per-seed variation inside a pattern type (stripe width, dot spacing...).
static func _pattern_params(pattern: int, pattern_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pattern_seed * 7919 + pattern)
	match pattern:
		Pattern.HALF:
			return { "lengthwise": rng.randf() < 0.6, "off": rng.randi_range(-2, 2) }
		Pattern.STRIPES:
			return { "w": rng.randi_range(2, 4), "off": rng.randi_range(0, 7) }
		Pattern.ZIGZAG:
			return { "w": rng.randi_range(3, 4), "amp": rng.randi_range(2, 3), "phase": rng.randi_range(0, 5), "off": rng.randi_range(0, 7) }
		Pattern.DOTS:
			return { "sp": rng.randi_range(5, 6), "ox": rng.randi_range(0, 5), "oy": rng.randi_range(0, 5), "big": rng.randf() < 0.4 }
		Pattern.VLINES, Pattern.HLINES:
			return { "sp": rng.randi_range(3, 5), "thick": 1 if rng.randf() < 0.7 else 2, "off": rng.randi_range(0, 4) }
	return {}


## amount < 0 darkens toward blue-purple, > 0 lightens toward warm yellow.
static func shade(c: Color, amount: float) -> Color:
	var h := c.h
	var s := c.s
	var v := c.v
	if amount < 0.0:
		var a := -amount
		h = _hue_toward(h, 0.72, 0.06 * a) if s > 0.05 else 0.72
		s = clampf(s + 0.10 * a + (0.12 if s <= 0.05 else 0.0), 0.0, 1.0)
		v = clampf(v * pow(0.70, a), 0.0, 1.0)
	else:
		h = _hue_toward(h, 0.13, 0.05 * amount) if s > 0.05 else 0.13
		s = clampf(s - 0.12 * amount + (0.06 if s <= 0.05 else 0.0), 0.0, 1.0)
		v = clampf(v + (1.0 - v) * 0.30 * amount + 0.05 * amount, 0.0, 1.0)
	return Color.from_hsv(h, s, v)


static func _hue_toward(h: float, target: float, amount: float) -> float:
	var d := fposmod(target - h + 0.5, 1.0) - 0.5
	return fposmod(h + clampf(d, -amount, amount), 1.0)


static func _key(seed: Dictionary) -> String:
	var colors: Array = seed.get("colors", [])
	return "%d|%s|%s|%s|%d" % [int(seed.get("pattern", 0)), colors[0], colors[1], seed.get("sprout", ""), int(seed.get("pattern_seed", 0))]


static func _ensure_template() -> void:
	if not _roles.is_empty():
		return
	_roles.resize(SIZE * SIZE)
	var meta: Variant = load(META_PATH) if ResourceLoader.exists(META_PATH) else null
	if meta is JSON and meta.data is Dictionary:
		_angle = deg_to_rad(float(meta.data.get("angle", 50.0)))
		_center = Vector2(float(meta.data.get("cx", 13.4)), float(meta.data.get("cy", 18.7)))
	var tex := load(TEMPLATE_PATH) as Texture2D
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	for y in SIZE:
		for x in SIZE:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				_roles[y * SIZE + x] = Role.NONE
				continue
			var rgb := (c.r8 << 16) | (c.g8 << 8) | c.b8
			_roles[y * SIZE + x] = ROLE_COLORS.get(rgb, _nearest_role(c))


static func _nearest_role(c: Color) -> int:
	var best := Role.BODY
	var best_d := INF
	for rgb in ROLE_COLORS:
		var rc := Color8((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255)
		var d := Vector3(rc.r - c.r, rc.g - c.g, rc.b - c.b).length_squared()
		if d < best_d:
			best_d = d
			best = ROLE_COLORS[rgb]
	return best


## Rarity tiers: name + display color.
static func rarity_tier(rarity: int) -> Array:
	if rarity >= 64: return ["Cosmic", Color("#6ef7ff")]
	if rarity >= 32: return ["Mythic", Color("#ff6b7d")]
	if rarity >= 16: return ["Legendary", Color("#ffc94a")]
	if rarity >= 8: return ["Epic", Color("#c58bff")]
	if rarity >= 4: return ["Rare", Color("#5aa8ff")]
	if rarity >= 2: return ["Uncommon", Color("#7be36f")]
	return ["Common", Color("#c4c0d4")]
