class_name BlockArt
extends RefCounted
## Block art you draw yourself, one per seed: what the seed's drop (its block) looks like in the game.
## FRAMES boxes of 32x32: frame 0 is the block, frames 1-3 are spare for animation.
##
## You draw it on the exported sprite sheet (the columns at the far left of each seed's row) and
## bring it in with Import Sprite Sheet. It is kept per seed as a FRAMES*32 x 32 PNG strip in
## user://block_art/<seed id>.png, and written back into every sprite sheet you export.

const FRAMES := 4
const SIZE := 32
const DIR := "user://block_art"

static var _cache := {}  # id -> Image (or null for "none")
static var _fruit_cache := {}  # id -> Image (or null)
## Goes up whenever any block art changes, so pictures made from it (the fruit on grown crops) redraw.
static var version := 0


## The seed's block art strip (FRAMES*32 x 32), or null if none was imported.
static func get_art(id: String) -> Image:
	if _cache.has(id):
		return _cache[id]
	var img: Image = null
	var path := _path(id)
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
		if img != null:
			img.convert(Image.FORMAT_RGBA8)
	if img == null and Engine.get_main_loop() != null:  # no art of your own: the official drawing, if any
		var s: Dictionary = Game.get_seed(id)
		if not s.is_empty():
			var off := Official.art_for(String(s.name))
			img = off.duplicate() if off != null else null
	_cache[id] = img
	return img


static func has_art(id: String) -> bool:
	return get_art(id) != null


## How many frames have something drawn in them (0 = none).
static func frame_count(id: String) -> int:
	var img := get_art(id)
	if img == null:
		return 0
	var n := 0
	for f in FRAMES:
		if not img.get_region(Rect2i(f * SIZE, 0, SIZE, SIZE)).is_invisible():
			n += 1
	return n


## Keep this strip as the seed's block art. An empty (fully transparent) strip removes it.
static func set_art(id: String, strip: Image) -> Error:
	if strip == null or strip.is_invisible():
		return remove(id)
	DirAccess.make_dir_recursive_absolute(DIR)
	var err := strip.save_png(_path(id))
	_cache[id] = strip if err == OK else null
	_changed(id)
	return err


static func remove(id: String) -> Error:
	_cache[id] = null
	_changed(id)
	if FileAccess.file_exists(_path(id)):
		return DirAccess.remove_absolute(_path(id))
	return OK


## Forgets every seed's block art (Reset Progress).
static func clear_all() -> void:
	_cache.clear()
	_fruit_cache.clear()
	version += 1
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.get_extension() == "png":
			d.remove(f)


## The official art changed (a live push): forget every cached picture so they are read again.
static func refresh_all() -> void:
	_cache.clear()
	_fruit_cache.clear()
	version += 1


static func _changed(id: String) -> void:
	_fruit_cache.erase(id)
	version += 1


## FRUIT_SIZE: a grown crop carries little copies of its block (see CropArt). They are drawn on
## the crop's own 32x32 pixel grid (no smaller pixels, no smoothing), so the block is shrunk by
## 4 with pixel art rules instead of resizing:
##   - a full block (opaque to its edges, like the designer's bevel blocks): its 2 px frame is
##     kept as a 1 px frame and the 28x28 inside becomes 7x7, each pixel the most common color
##     of its 4x4 square. The corners are cut, like the designer's rounded corners.
##   - anything else (a decoration with a see-through background): the 32x32 becomes 8x8 the same
##     way, then gets a 1 px dark outline.
const FRUIT_SIZE := 9


## The seed's block as a crop fruit (FRUIT_SIZE or 10 px square), or null if it has no block art.
static func fruit(id: String) -> Image:
	if _fruit_cache.has(id):
		return _fruit_cache[id]
	var art := get_art(id)
	var img: Image = null
	if art != null and not art.get_region(Rect2i(0, 0, SIZE, SIZE)).is_invisible():
		img = shrink(art.get_region(Rect2i(0, 0, SIZE, SIZE)))
	_fruit_cache[id] = img
	return img


## Shrinks one 32x32 block picture to a crop fruit (see FRUIT_SIZE).
static func shrink(src: Image) -> Image:
	var ring: Array[Color] = []
	for i in SIZE:
		for t in 2:
			ring.append_array([src.get_pixel(i, t), src.get_pixel(i, SIZE - 1 - t), src.get_pixel(t, i), src.get_pixel(SIZE - 1 - t, i)])
	var opaque := ring.filter(func(c: Color): return c.a >= 0.5)
	var counts := _counts(src, 0, 0, SIZE)
	if opaque.size() >= ring.size() * 0.9:
		var img := Image.create_empty(FRUIT_SIZE, FRUIT_SIZE, false, Image.FORMAT_RGBA8)
		var frame := _mode(opaque, counts)
		for i in range(1, FRUIT_SIZE - 1):
			for p in [Vector2i(i, 0), Vector2i(i, FRUIT_SIZE - 1), Vector2i(0, i), Vector2i(FRUIT_SIZE - 1, i)]:
				img.set_pixelv(p, frame)
		for y in 7:
			for x in 7:
				img.set_pixel(x + 1, y + 1, _mode(_square(src, 2 + x * 4, 2 + y * 4, 4), counts))
		return img
	# see-through art: 8x8 + a 1 px outline around it
	var out := Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var c := _mode(_square(src, x * 4, y * 4, 4), counts, true)
			if c.a >= 0.5:
				c.a = 1.0
				out.set_pixel(x + 1, y + 1, c)
	var ink := Color(0.08, 0.06, 0.1)
	var edge := []
	for y in 10:
		for x in 10:
			if out.get_pixel(x, y).a > 0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < 10 and q.y < 10 and out.get_pixelv(q).a > 0:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		out.set_pixelv(p, ink)
	return out


static func _square(src: Image, x0: int, y0: int, n: int) -> Array[Color]:
	var out: Array[Color] = []
	for y in n:
		for x in n:
			out.append(src.get_pixel(x0 + x, y0 + y))
	return out


static func _counts(src: Image, x0: int, y0: int, n: int) -> Dictionary:
	var out := {}
	for c in _square(src, x0, y0, n):
		out[c.to_rgba32()] = int(out.get(c.to_rgba32(), 0)) + 1
	return out


## The most common color; a tie goes to the color that is rarer in the whole picture (so small
## details like a shine mark survive). Fully see-through pixels count as one "color" only when
## `keep_clear` is true (decorations); otherwise they are ignored.
static func _mode(colors: Array, overall: Dictionary, keep_clear := false) -> Color:
	var n := {}
	for c: Color in colors:
		if c.a < 0.5 and not keep_clear:
			continue
		var k := 0 if c.a < 0.5 else c.to_rgba32()
		n[k] = int(n.get(k, 0)) + 1
	var best := -1
	var best_n := -1
	for k in n:
		if n[k] > best_n or (n[k] == best_n and int(overall.get(k, 0)) < int(overall.get(best, 0))):
			best = k
			best_n = n[k]
	if best <= 0:
		return Color(0, 0, 0, 0)
	return Color.hex(best)


static func _path(id: String) -> String:
	return "%s/%s.png" % [DIR, id.validate_filename()]
