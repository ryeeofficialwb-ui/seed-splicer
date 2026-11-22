class_name VoidField
extends Control
## The empty void the seeds float in. Handles spawning, dropping from the dictionary,
## and detecting when one seed is dropped onto another.

signal splice_new(a: SeedToken, b: SeedToken)  ## a pair nobody has spliced yet: main opens the popup
signal edit_seed(id: String)                    ## a floating seed was double-clicked
signal void_changed
signal spliced(result_id: String, is_new: bool)  ## any splice finished (the tutorial waits for one)

const SPLICE_DISTANCE := 62.0
const SPARKLE := preload("res://assets/sparkle.png")
const SPARKLE_FRAMES := 5
const SPARKLE_FRAME_TIME := 0.07

var tokens_layer: Control
var fx_layer: FxLayer
var toast: Label
var _toast_box: PanelContainer
var _toast_tw: Tween
var _stars: Array = []
var _motes: Array = []
var _t := 0.0


class FxLayer extends Control:
	var effects: Array = []  # {pos, t}

	func add(pos: Vector2) -> void:
		effects.append({ "pos": pos, "t": 0.0 })

	func _process(delta: float) -> void:
		for e in effects:
			e.t += delta
		effects = effects.filter(func(e): return e.t < VoidField.SPARKLE_FRAMES * VoidField.SPARKLE_FRAME_TIME)
		queue_redraw()

	func _draw() -> void:
		for e in effects:
			var f := mini(int(e.t / VoidField.SPARKLE_FRAME_TIME), VoidField.SPARKLE_FRAMES - 1)
			var s := 32.0 * 5.0
			draw_texture_rect_region(VoidField.SPARKLE, Rect2(e.pos - Vector2(s, s) / 2.0, Vector2(s, s)),
				Rect2(f * 32, 0, 32, 32))


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	tokens_layer = Control.new()
	tokens_layer.name = "Tokens"
	tokens_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tokens_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tokens_layer)

	fx_layer = FxLayer.new()
	fx_layer.name = "Fx"
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fx_layer)

	var title := Label.new()
	title.text = "SEED SPLICER"
	title.add_theme_font_size_override("font_size", UiKit.BIG)
	title.add_theme_color_override("font_color", Color("#a6ff6e"))
	title.position = Vector2(18, 12)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var hint := Label.new()
	hint.text = "Drag one seed onto another to splice  ·  Double-click: edit  ·  Right-click: remove  ·  Ctrl+click: copy"
	hint.add_theme_font_size_override("font_size", UiKit.SMALL)
	hint.add_theme_color_override("font_color", Color(0.75, 0.72, 0.85, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # two lines when the void is narrow
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 18
	hint.offset_right = -18
	hint.offset_top = -72
	hint.offset_bottom = -10
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	# messages: a pixel panel centered near the top (fades out by itself)
	_toast_box = PanelContainer.new()
	_toast_box.theme_type_variation = &"ToastPanel"
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.modulate.a = 0.0
	add_child(_toast_box)
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_child(toast)
	resized.connect(_place_toast)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 170:
		_stars.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"s": [1, 1, 1, 2, 2, 3][rng.randi_range(0, 5)],
			"tw": rng.randf_range(0.6, 2.4), "ph": rng.randf() * TAU,
			"c": [Color("#e9e4ff"), Color("#bfe9ff"), Color("#ffe9c4"), Color("#c9ffd8")][rng.randi_range(0, 3)],
		})
	for i in 40:
		_motes.append({
			"p": Vector2(rng.randf(), rng.randf()), "v": rng.randf_range(0.006, 0.02),
			"sway": rng.randf_range(4.0, 14.0), "ph": rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var sz := size
	# deep-space gradient: violet-black top to a faint mossy glow at the bottom
	var top := Color("#0b0912")
	var bottom := Color("#141220")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	# soft nebula blobs made of stacked circles (stays "pixel" because alpha steps are coarse)
	var neb := [[Vector2(0.3, 0.35), Color(0.45, 0.25, 0.75)], [Vector2(0.72, 0.68), Color(0.15, 0.55, 0.5)]]
	for n in neb:
		var c: Vector2 = n[0] * sz
		for r in [260.0, 190.0, 120.0]:
			var col: Color = n[1]
			col.a = 0.035
			draw_circle(c + Vector2(sin(_t * 0.07) * 20.0, cos(_t * 0.05) * 14.0), r, col)
	for s in _stars:
		var a: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * s.tw + s.ph))
		var col: Color = s.c
		col.a = a
		var sp: Vector2 = s.p
		var p := (sp * sz).floor()
		draw_rect(Rect2(p, Vector2(s.s, s.s)), col)
		if s.s == 3 and a > 0.8:  # little cross glint on the big ones
			col.a = a * 0.5
			draw_rect(Rect2(p + Vector2(-2, 1), Vector2(7, 1)), col)
			draw_rect(Rect2(p + Vector2(1, -2), Vector2(1, 7)), col)
	for m in _motes:
		var mp: Vector2 = m.p
		var y: float = fposmod(mp.y - _t * m.v, 1.0)
		var p := Vector2(mp.x * sz.x + sin(_t * 0.8 + m.ph) * m.sway, y * sz.y).floor()
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.65, 1.0, 0.55, 0.22))


# --- tokens -------------------------------------------------------------------

## pop = the little grow-in animation (and the "seed appears" sound unless quiet).
func spawn(id: String, center_pos: Vector2, pop := true, quiet := false) -> SeedToken:
	var tk := SeedToken.new()
	tk.name = "Seed_" + id
	tk.field = self
	tokens_layer.add_child(tk)
	tk.setup(id)
	tk.position = _clamp_pos(center_pos - tk.size / 2.0)
	tk.dropped.connect(_on_token_dropped)
	tk.remove_requested.connect(_on_remove)
	tk.duplicate_requested.connect(_on_duplicate)
	tk.edit_requested.connect(_on_edit_token)
	if pop:
		tk.pop_in()
		if not quiet:
			Audio.play(&"spawn")
	_changed()
	return tk


func spawn_near_center(id: String) -> SeedToken:
	var c := size / 2.0 + Vector2(randf_range(-180, 180), randf_range(-120, 120))
	return spawn(id, c)


func tokens() -> Array[SeedToken]:
	var out: Array[SeedToken] = []
	for c in tokens_layer.get_children():
		if c is SeedToken and not c.is_queued_for_deletion():
			out.append(c)
	return out


func clear() -> void:
	for t in tokens():
		t.queue_free()
	_changed.call_deferred()


func refresh_all() -> void:
	for t in tokens():
		if Game.get_seed(t.seed_id).is_empty():
			t.queue_free()
		else:
			t.refresh()


func restore(saved: Array) -> void:
	for e in saved:
		if not Game.get_seed(e.id).is_empty():
			spawn(e.id, Vector2(e.x, e.y), false)


func spawn_starters() -> void:
	var c := size / 2.0
	var offs := [Vector2(-170, -90), Vector2(150, -110), Vector2(-140, 120), Vector2(170, 100)]
	for i in Game.BASE_SEEDS.size():
		spawn(Game.BASE_SEEDS[i].id, c + offs[i % offs.size()])


func store() -> void:
	var list: Array = []
	for t in tokens():
		var c := t.center()
		list.append({ "id": t.seed_id, "x": roundf(c.x), "y": roundf(c.y) })
	Game.void_tokens = list


func _clamp_pos(p: Vector2) -> Vector2:
	var max_p := size - Vector2(SeedToken.ART, SeedToken.ART + SeedToken.BOTTOM_ROOM)
	return Vector2(clampf(p.x, 0, maxf(max_p.x, 0)),
		clampf(p.y, SeedToken.TOP_ROOM, maxf(max_p.y, SeedToken.TOP_ROOM)))


func _changed() -> void:
	store()
	void_changed.emit()


func _on_remove(tk: SeedToken) -> void:
	Audio.play(&"remove")
	tk.queue_free()
	_changed.call_deferred()


func _on_edit_token(tk: SeedToken) -> void:
	edit_seed.emit(tk.seed_id)


## A double-click in the Seeds list first spawns the seed (its first click). Take that seed
## back out so editing doesn't leave a stray copy behind.
func discard_recent_spawn(id: String, within_ms := 900) -> void:
	var now := Time.get_ticks_msec()
	var newest: SeedToken = null
	for t in tokens():
		if t.seed_id == id and now - t.spawned_at <= within_ms and (newest == null or t.spawned_at > newest.spawned_at):
			newest = t
	if newest:
		newest.queue_free()
		_changed.call_deferred()


func _on_duplicate(tk: SeedToken) -> void:
	spawn(tk.seed_id, tk.center() + Vector2(40, 30))


func _on_token_dropped(tk: SeedToken) -> void:
	var other := _overlapping(tk)
	if other == null:
		Audio.play(&"drop")
		_changed()
		return
	try_splice(tk, other)


func _overlapping(tk: SeedToken) -> SeedToken:
	var best: SeedToken = null
	var best_d := SPLICE_DISTANCE
	for t in tokens():
		if t == tk:
			continue
		var d := t.center().distance_to(tk.center())
		if d < best_d:
			best_d = d
			best = t
	return best


func try_splice(a: SeedToken, b: SeedToken) -> void:
	if not Game.can_splice(a.seed_id, b.seed_id):
		cancel_splice(a, b)
		Audio.play(&"error")
		show_toast("A seed can't be spliced with itself", Color("#ff8a8a"))
		return
	var result := Game.result_of(a.seed_id, b.seed_id)
	if result != "":
		complete_splice(a, b, result, false)
	else:
		a.dragging = true  # freeze both while the popup is open
		b.dragging = true
		splice_new.emit(a, b)


## Merge a + b into `result` with a little sparkle.
func complete_splice(a: SeedToken, b: SeedToken, result: String, is_new: bool) -> void:
	var mid := (a.center() + b.center()) / 2.0
	for t: SeedToken in [a, b]:
		t.dragging = true
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := t.create_tween()
		tw.tween_property(t, "position", mid - t.size / 2.0, 0.12)
		tw.parallel().tween_property(t, "scale", Vector2(0.5, 0.5), 0.12)
		tw.tween_callback(t.queue_free)
	await get_tree().create_timer(0.12).timeout
	spawn(result, mid, true, true)
	fx_layer.add(mid)
	Audio.play(&"discover" if is_new else &"splice")
	var s := Game.get_seed(result)
	var tier: Array = SeedArt.rarity_tier(int(s.rarity))
	show_toast("%s%s  ·  Rarity %d %s" % ["NEW!  " if is_new else "", s.name, int(s.rarity), tier[0]], tier[1])
	spliced.emit(result, is_new)


func cancel_splice(a: SeedToken, b: SeedToken) -> void:
	for t in [a, b]:
		if is_instance_valid(t):
			t.dragging = false
	if is_instance_valid(a) and is_instance_valid(b):
		var away := (b.center() - a.center()).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		b.position = _clamp_pos(b.position + away * 80.0)
	_changed()


func show_toast(text: String, color := Color.WHITE, seconds := 2.0) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", color)
	_place_toast()
	_toast_box.modulate.a = 1.0
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = _toast_box.create_tween()
	_toast_tw.tween_interval(seconds)
	_toast_tw.tween_property(_toast_box, "modulate:a", 0.0, 0.6)


func _place_toast() -> void:
	_toast_box.reset_size()
	_toast_box.position = (Vector2((size.x - _toast_box.size.x) / 2.0, 96.0)).round()


# --- drag from the dictionary -------------------------------------------------

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("seed_id")


func _drop_data(at: Vector2, data: Variant) -> void:
	var tk := spawn(data.seed_id, at)
	var other := _overlapping(tk)
	if other:
		try_splice(tk, other)
