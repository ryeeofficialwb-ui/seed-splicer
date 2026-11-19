class_name CropArt
extends RefCounted
## Paints a seed's crop at each growth stage, 32x32, from the Aseprite template
## (assets/crop_template.png, made by art/make_crops.lua).
##
## A crop grows through 5 stages: SEED (the seed's own art, see SeedArt), PLANTED (just a tiny
## leaf poking out of the ground: the seed item is far too big to look right in the ground),
## SPROUT, SAPLING, CROP.
## The template has one row per crop type and one 32x32 column per stage after the seed. It is
## role-coded like the seed template: every pixel says which of the seed's colors it takes
## (main = Color 1, accent = Color 2, leaf = Sprout, wood = bark mixed with Color 2) and which
## shade (outline / deep / dark / mid / light / shine). So every crop uses its seed's own colors.
## There are 5 crop types; every seed is one of them (its "crop" field).

## PLANTED is last in the enum so the sprite sheet's older columns (seed, sprout, sapling, crop)
## keep their places: the new column is added at the far right.
enum Stage { SEED, SPROUT, SAPLING, CROP, PLANTED }
const STAGE_NAMES: Array[String] = ["Seed", "Sprout", "Sapling", "Crop", "Planted"]
## The order a crop grows in (the sheet's column order is STAGE_NAMES').
const GROWTH_ORDER: Array[int] = [Stage.SEED, Stage.PLANTED, Stage.SPROUT, Stage.SAPLING, Stage.CROP]

## The planted stage: a tiny leaf, per crop type. One pixel per word: "." is empty, otherwise a
## letter for the material (L leaf = the seed's sprout color, A accent = Color 2, M main = Color 1,
## W wood) and a digit for the shade (0 outline, 1 deep, 2 dark, 3 mid, 4 light, 5 shine): the
## same codes as the crop template. Drawn centered, standing on the ground line at the bottom.
const PLANTED_ART := {
	"round_tree": [
		". L0 . L0 .",
		"L0 L4 L0 L3 L0",
		". L0 L2 L0 .",
		". . W0 . .",
		". . W0 . .",
	],
	"pine": [
		". L0 .",
		"L0 L4 L0",
		"L0 L3 L0",
		". W0 .",
		". W0 .",
	],
	"twisted_tree": [
		". . L0 L0 .",
		". L0 L4 L3 L0",
		"L0 L3 L2 L0 .",
		". L0 W0 . .",
		". . W0 . .",
	],
	"flower": [
		". A0 .",
		"A0 A4 A0",
		". L0 .",
		"L0 L3 L0",
		". L0 .",
	],
	"mushroom": [
		". M0 M0 M0 .",
		"M0 M4 M3 M3 M0",
		"M0 M3 M2 M2 M0",
		". M0 M0 M0 .",
		". . L3 . .",
	],
}
const PLANTED_BASE_Y := 30  ## the last row of the leaf sits on this pixel row

enum Mat { NONE, MAIN, LEAF, ACCENT, WOOD }
enum Tone { OUT, DEEP, DARK, MID, LIGHT, SHINE }
## template color -> [material, tone]. Each material uses one channel (main = gray, leaf = green,
## accent = red, wood = blue) with the same 6 steps: outline, deep, dark, mid, light, shine.
const ROLE_COLORS := {
	0x000000: [Mat.MAIN, Tone.OUT], 0x202020: [Mat.MAIN, Tone.DEEP], 0x404040: [Mat.MAIN, Tone.DARK],
	0x808080: [Mat.MAIN, Tone.MID], 0xC0C0C0: [Mat.MAIN, Tone.LIGHT], 0xFFFFFF: [Mat.MAIN, Tone.SHINE],
	0x004000: [Mat.LEAF, Tone.OUT], 0x006000: [Mat.LEAF, Tone.DEEP], 0x008000: [Mat.LEAF, Tone.DARK],
	0x00C000: [Mat.LEAF, Tone.MID], 0x80FF80: [Mat.LEAF, Tone.LIGHT], 0xC0FFC0: [Mat.LEAF, Tone.SHINE],
	0x400000: [Mat.ACCENT, Tone.OUT], 0x600000: [Mat.ACCENT, Tone.DEEP], 0x800000: [Mat.ACCENT, Tone.DARK],
	0xC00000: [Mat.ACCENT, Tone.MID], 0xFF8080: [Mat.ACCENT, Tone.LIGHT], 0xFFC0C0: [Mat.ACCENT, Tone.SHINE],
	0x000040: [Mat.WOOD, Tone.OUT], 0x000060: [Mat.WOOD, Tone.DEEP], 0x000080: [Mat.WOOD, Tone.DARK],
	0x0000C0: [Mat.WOOD, Tone.MID], 0x8080FF: [Mat.WOOD, Tone.LIGHT], 0xC0C0FF: [Mat.WOOD, Tone.SHINE],
}
const SIZE := 32
const TEMPLATE_PATH := "res://assets/crop_template.png"
const META_PATH := "res://assets/crop_template.json"
const BARK := Color("#7a5538")  ## trunks: this brown, mixed a little toward the seed's Color 2
## Used only if assets/crop_template.json can't be read.
const FALLBACK_TYPES := [
	{ "id": "round_tree", "name": "Round Tree" }, { "id": "pine", "name": "Pine" },
	{ "id": "twisted_tree", "name": "Twisted Tree" }, { "id": "flower", "name": "Big Flower" },
	{ "id": "mushroom", "name": "Giant Mushroom" },
]

## Block fruit: a fully grown crop carries 1-4 little copies of its seed's block (its drop),
## shrunk by BlockArt.fruit() and drawn on the crop's own pixel grid. Where they hang, per crop
## type and per count (top-left corner of each fruit in the 32x32 cell). Seeds without block art
## grow no fruit.
const FRUIT_SPOTS := {
	"round_tree": [[[11, 6]], [[5, 7], [17, 6]], [[11, 1], [4, 9], [18, 9]], [[6, 1], [17, 1], [4, 10], [18, 10]]],
	"pine": [[[11, 10]], [[6, 16], [17, 16]], [[11, 4], [5, 17], [18, 17]], [[11, 1], [6, 10], [16, 10], [11, 19]]],
	"twisted_tree": [[[8, 3]], [[4, 4], [20, 7]], [[2, 4], [11, 0], [21, 7]], [[1, 3], [10, 0], [14, 9], [23, 8]]],
	"flower": [[[11, 4]], [[5, 6], [18, 6]], [[11, 0], [4, 8], [19, 8]], [[7, 0], [16, 0], [4, 9], [19, 9]]],
	"mushroom": [[[11, 4]], [[5, 5], [18, 5]], [[11, 2], [2, 7], [20, 7]], [[1, 6], [8, 2], [16, 2], [23, 6]]],
}
const MAX_FRUIT := 4

static var _types: Array = []
static var _template: Image
static var _cache := {}


## Every crop type, in template order: [{ id, name }]
static func types() -> Array:
	_ensure_template()
	return _types


static func type_ids() -> Array:
	return types().map(func(t): return t.id)


static func type_name(id: String) -> String:
	for t in types():
		if t.id == id:
			return t.name
	return String(types()[0].name)


static func is_type(id: Variant) -> bool:
	return typeof(id) == TYPE_STRING and type_ids().has(id)


## A random-looking type that is always the same for the same key (a seed's id or name).
static func random_type(key: String) -> String:
	var ids := type_ids()
	return ids[posmod(hash("crop-type:" + key), ids.size())]


## `id` if it is a crop type, else a random one picked by `key`.
static func valid_type(id: Variant, key: String) -> String:
	return id if is_type(id) else random_type(key)


## Texture of a seed at one growth stage. Cached.
static func texture_for(seed: Dictionary, stage: int) -> Texture2D:
	if stage == Stage.SEED:
		return SeedArt.texture_for(seed)
	var key := "%s|%d|%s" % [seed.get("crop", ""), stage, SeedArt._key(seed)]
	if stage == Stage.CROP:
		key += "|%s|%d|%d" % [seed.get("id", ""), BlockArt.version, int(seed.get("fruit_count", 0))]
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(render(seed, stage))
	_cache[key] = tex
	return tex


## 32x32 image of a seed at one growth stage (SEED = the seed art itself).
static func render(seed: Dictionary, stage: int) -> Image:
	if stage == Stage.SEED:
		return SeedArt.render(seed)
	_ensure_template()
	var ids := type_ids()
	if stage == Stage.PLANTED:
		return _render_planted(seed, ids[maxi(0, ids.find(valid_type(seed.get("crop", ""), String(seed.get("id", seed.get("name", ""))))))])
	var row := maxi(0, ids.find(valid_type(seed.get("crop", ""), String(seed.get("id", seed.get("name", ""))))))
	var col := stage - 1
	var base := _materials(seed)

	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var px := _template.get_pixel(col * SIZE + x, row * SIZE + y)
			if px.a < 0.5:
				continue
			var role: Array = ROLE_COLORS.get((px.r8 << 16) | (px.g8 << 8) | px.b8, _nearest_role(px))
			img.set_pixel(x, y, _tone_color(base[role[0]], role[1]))
	if stage == Stage.CROP:
		_add_fruit(img, seed, ids[row])
	return img


## The seed's 4 colors by material: main = Color 1, leaf = sprout, accent = Color 2, wood = bark.
static func _materials(seed: Dictionary) -> Dictionary:
	var colors: Array = seed.get("colors", ["#888888", "#555555"])
	var c2 := Color(colors[1])
	return { Mat.MAIN: Color(colors[0]), Mat.LEAF: Color(seed.get("sprout", "#6fcf4a")), Mat.ACCENT: c2,
		Mat.WOOD: BARK.lerp(c2, 0.3) }


static func _tone_color(c: Color, tone: int) -> Color:
	var out: Color
	match tone:
		Tone.OUT: out = SeedArt.INK.lerp(c, 0.22)
		Tone.DEEP: out = SeedArt.shade(c, -1.9)
		Tone.DARK: out = SeedArt.shade(c, -1.0)
		Tone.MID: out = c
		Tone.LIGHT: out = SeedArt.shade(c, 1.0)
		_: out = SeedArt.shade(c, 2.2)
	out.a = 1.0
	return out


## The tiny leaf of the PLANTED stage (see PLANTED_ART), in the seed's own colors.
@warning_ignore("integer_division")
static func _render_planted(seed: Dictionary, crop_id: String) -> Image:
	var base := _materials(seed)
	var letters := { "M": Mat.MAIN, "L": Mat.LEAF, "A": Mat.ACCENT, "W": Mat.WOOD }
	var rows: Array = PLANTED_ART.get(crop_id, PLANTED_ART.round_tree)
	var width := 0
	for r: String in rows:
		width = maxi(width, r.split(" ").size())
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var ox := (SIZE - width) / 2
	var oy := PLANTED_BASE_Y + 1 - rows.size()
	for y in rows.size():
		var words: PackedStringArray = (rows[y] as String).split(" ")
		for x in words.size():
			var w := words[x]
			if w.length() == 2:
				img.set_pixel(ox + x, oy + y, _tone_color(base[letters[w[0]]], int(w[1])))
	return img


## How many block fruits this seed's grown crop carries: 1-4, picked once per seed (by its id).
static func fruit_count(seed: Dictionary) -> int:
	var forced := int(seed.get("fruit_count", 0))  # previews can ask for a count
	if forced >= 1 and forced <= MAX_FRUIT:
		return forced
	return 1 + posmod(hash("fruit-count:" + String(seed.get("id", seed.get("name", "")))), MAX_FRUIT)


static func _add_fruit(img: Image, seed: Dictionary, crop_id: String) -> void:
	var id := String(seed.get("id", ""))
	if id == "":
		return
	var fruit := BlockArt.fruit(id)
	if fruit == null:
		return
	var spots: Array = FRUIT_SPOTS.get(crop_id, FRUIT_SPOTS.round_tree)[fruit_count(seed) - 1].duplicate()
	spots.sort_custom(func(a, b): return a[1] < b[1])  # lower fruit hang in front
	for p in spots:
		img.blend_rect(fruit, Rect2i(Vector2i.ZERO, fruit.get_size()), Vector2i(p[0], p[1]))


static func _ensure_template() -> void:
	if _template != null:
		return
	_types = FALLBACK_TYPES.duplicate(true)
	var meta: Variant = load(META_PATH) if ResourceLoader.exists(META_PATH) else null
	if meta is JSON and meta.data is Dictionary and meta.data.get("types") is Array and not meta.data.types.is_empty():
		_types = meta.data.types.map(func(t): return { "id": String(t.id), "name": String(t.name) })
	var tex := load(TEMPLATE_PATH) as Texture2D
	_template = tex.get_image()
	if _template.is_compressed():
		_template.decompress()
	_template.convert(Image.FORMAT_RGBA8)


static func _nearest_role(c: Color) -> Array:
	var best: Array = [Mat.MAIN, Tone.MID]
	var best_d := INF
	for rgb in ROLE_COLORS:
		var rc := Color8((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255)
		var d := Vector3(rc.r - c.r, rc.g - c.g, rc.b - c.b).length_squared()
		if d < best_d:
			best_d = d
			best = ROLE_COLORS[rgb]
	return best
