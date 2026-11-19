extends Node
## Dev helper, only active when launched with user args, e.g.
##   godot --path . -- --shot=C:/tmp/a.png            screenshot of the void
##   godot --path . -- --shot=C:/tmp/b.png --popup     screenshot with the splice popup open (Dirt + Stone)
##   godot --path . -- --shot=C:/tmp/c.png --test      splices Dirt + Stone through the popup, then again
##                                                    (known recipe), prints checks. WRITES TO YOUR SAVE.

var main: Node


func _ready() -> void:
	var path := ""
	var with_popup := false
	var edit_seed := ""
	var test := false
	var test2 := false
	var test3 := false
	var test4 := false
	var test5 := false
	var test6 := false
	var test7 := false
	var test8 := false
	var test9 := false
	var test10 := false
	var test11 := false
	var test12 := false
	var test13 := false
	var test14 := false
	var test15 := false
	var test16 := false
	var test17 := false
	var test18 := false
	var test19 := false
	var test20 := false
	var approvals_file := ""  # --approvals=C:/x.json : use that official list (stamps) for the screenshot
	var stats := false        # --stats : the Settings window on its Statistics tab
	var tree_opts := []       # --tree-only --wide --route --fold : Recipe Tree options for the screenshot
	var dict_seed := ""  # --dict=cave_background [--dict-tab=3] : the Dictionary open on that seed
	var dict_tab := 0
	var hub := false     # --hub : the Settings window open
	var tree_name := ""  # --tree=Quartz  opens the Recipe Tree on "Quartz Seed" for the screenshot
	var tree_zoom := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dirt="):  # --dirt=C:/tmp/dirt.png [--old=their_block.png] : dirt block mock-ups
			_dirt_preview(a.substr(7))
			get_tree().quit()
			return
		if a.begins_with("--crops="):  # --crops=C:/tmp/crops.png : every crop type x every stage, enlarged
			_crop_preview(a.substr(8))
			get_tree().quit()
			return
		if a.begins_with("--export="):  # --export=C:/tmp/list.json : Export List (+ its sprite sheet), then quit
			print("export: ", error_string(Game.export_list(a.substr(9))))
			get_tree().quit()
			return
		if a.begins_with("--fruit="):  # --fruit=C:/tmp/f.png [--fruit-seeds=a,b] : grown crops with 1-4 block fruits
			_fruit_preview(a.substr(8))
			get_tree().quit()
			return
		if a == "--panel":  # show the Seeds panel for the screenshot (without saving that setting)
			main.panel.visible = true
			main.panel.custom_minimum_size.x = SidePanel.MIN_WIDTH
			main.panel.size.x = SidePanel.MIN_WIDTH
		if a.begins_with("--shot="):
			path = a.substr(7)
		elif a == "--popup":
			with_popup = true
		elif a.begins_with("--res="):  # --res=1440x900 : window size for the screenshot (not saved)
			var wh := a.substr(6).split("x")
			get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--edit="):  # --edit=purple_block : screenshot with that seed's Restyle popup open
			edit_seed = a.substr(7)
		elif a == "--test":
			test = true
		elif a == "--test2":
			test2 = true
		elif a == "--test3":
			test3 = true
		elif a == "--test4":
			test4 = true
		elif a == "--test5":
			test5 = true
		elif a == "--test6":
			test6 = true
		elif a == "--test7":
			test7 = true
		elif a == "--test8":
			test8 = true
		elif a == "--test9":
			test9 = true
		elif a == "--test10":
			test10 = true
		elif a == "--test11":
			test11 = true
		elif a == "--test12":
			test12 = true
		elif a == "--test13":
			test13 = true
		elif a == "--test14":
			test14 = true
		elif a == "--test15":
			test15 = true
		elif a == "--test16":
			test16 = true
		elif a == "--test17":
			test17 = true
		elif a == "--test18":
			test18 = true
		elif a == "--test19":
			test19 = true
		elif a == "--test20":
			test20 = true
		elif a.begins_with("--approvals="):
			approvals_file = a.substr(12)
		elif a == "--stats":
			stats = true
		elif a in ["--tree-only", "--wide", "--route", "--fold"]:
			tree_opts.append(a)
		elif a.begins_with("--dict="):
			dict_seed = a.substr(7)
		elif a.begins_with("--dict-tab="):
			dict_tab = int(a.substr(11))
		elif a == "--hub":
			hub = true
		elif a.begins_with("--tree="):
			tree_name = a.substr(7)
		elif a.begins_with("--zoom="):
			tree_zoom = float(a.substr(7))
	if path == "":
		queue_free()
		return
	if approvals_file != "":
		Approvals.use_data(JSON.parse_string(FileAccess.get_file_as_string(approvals_file)))
		main.panel.refresh_seeds()
	await get_tree().create_timer(1.2).timeout
	if stats:
		main.settings_hub.open_stats()
		await get_tree().create_timer(0.4).timeout
	if with_popup:
		main.popup.open_new("dirt", "stone")
		await get_tree().create_timer(0.4).timeout
	if edit_seed != "":
		main.popup.open_edit(edit_seed)
		await get_tree().create_timer(0.4).timeout
	if dict_seed != "":
		main.dictionary._tabs.current_tab = dict_tab
		main.dictionary.open_on(dict_seed)
		await get_tree().create_timer(0.6).timeout
	if hub:
		main.settings_hub.open()
		await get_tree().create_timer(0.4).timeout
	if tree_name != "":
		var id := Game.find_by_name(tree_name + " Seed")
		main.recipe_tree.open(id)
		var rtree: RecipeTree = main.recipe_tree
		rtree._tree_only.set_pressed_no_signal("--tree-only" in tree_opts)
		rtree._apply_tree_only()
		rtree._canvas.compact = not "--wide" in tree_opts
		rtree._canvas.farm_route = "--route" in tree_opts
		rtree._canvas.rebuild()
		await get_tree().create_timer(0.5).timeout
		if "--fold" in tree_opts:
			var n0: Dictionary = rtree._canvas.tree.kids[0]
			rtree._canvas.toggle_fold(n0.path)
		rtree._canvas.refit()
		rtree._update_totals()
		await get_tree().create_timer(0.5).timeout
		var tc: RecipeTree.TreeCanvas = main.recipe_tree._canvas
		print("tree fit zoom: ", tc.zoom, " nodes: ", tc.nodes.size())
		if tree_zoom > 0.0:  # --zoom=0.57 : look at a specific zoom
			tc.auto_fit = false
			tc.zoom = tree_zoom
			tc.pan = Vector2(tc.size.x / 2.0 - float(tc.tree.x) * tree_zoom, 10.0)
			tc.queue_redraw()
			await get_tree().create_timer(0.3).timeout
	if test:
		await _run_test()
	if test2:
		await _run_test2(path.get_base_dir() + "/export_test.json")
	if test3:
		await _run_test3(path.get_base_dir())
	if test4:
		await _run_test4(path.get_base_dir())
	if test5:
		await _run_test5(path.get_base_dir())
	if test6:
		await _run_test6(path.get_base_dir())
	if test7:
		await _run_test7(path.get_base_dir())
	if test8:
		await _run_test8(path.get_base_dir())
	if test9:
		await _run_test9(path.get_base_dir())
	if test10:
		await _run_test10(path.get_base_dir())
	if test11:
		await _run_test11(path.get_base_dir())
	if test12:
		await _run_test12(path.get_base_dir())
	if test13:
		await _run_test13(path.get_base_dir())
	if test14:
		_run_test14(path.get_base_dir())
	if test15:
		await _run_test15(path.get_base_dir())
	if test17:
		await _run_test17(path.get_base_dir())
	if test18:
		await _run_test18(path.get_base_dir())
	if test19:
		await _run_test19(path.get_base_dir())
	if test20:
		await _run_test20(path.get_base_dir())
	if test16:
		_run_test16(path.get_base_dir())
	if DisplayServer.get_name() == "headless":  # nothing is drawn headless: the checks above are all it can do
		get_tree().quit()
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## --- dirt block mock-ups in the Seed Splicer style (dev only) ----------------------------------
## Tileable 32x32 clods: a wrapped Voronoi map, 1px cracks, each clod lit from the top-left with the
## same hue-shifted shading as the seeds. variant: 0 clods, 1 clods + pebbles, 2 loose soil + roots.
func _dirt_block(variant: int, c1: Color, c2: Color, sprout: Color) -> Image:
	var n := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + variant * 17
	var count: int = [11, 8, 18][variant]
	var pts: Array[Vector2] = []
	for i in count:
		pts.append(Vector2(rng.randf() * n, rng.randf() * n))
	var tint := []  # per clod: 0 = Color 1, 1 = between, 2 = Color 2
	for i in count:
		tint.append([0, 0, 0, 1, 2][rng.randi_range(0, 4)] if variant != 2 else [0, 0, 1][rng.randi_range(0, 2)])
	var own := PackedInt32Array()
	own.resize(n * n)
	for y in n:
		for x in n:
			var best := 0
			var bd := INF
			for i in count:
				var d := Vector2(x + 0.5, y + 0.5) - pts[i]
				d.x = fposmod(d.x + n / 2.0, n) - n / 2.0  # wrap: the block tiles
				d.y = fposmod(d.y + n / 2.0, n) - n / 2.0
				var dist := d.length_squared() * (1.0 + 0.12 * sin(i * 3.1 + atan2(d.y, d.x) * 3.0))  # lumpy, not straight
				if dist < bd:
					bd = dist
					best = i
			own[y * n + x] = best
	var o := func(x: int, y: int) -> int: return own[posmod(y, n) * n + posmod(x, n)]
	var gap := func(x: int, y: int) -> bool:
		var me: int = o.call(x, y)
		return o.call(x + 1, y) != me or o.call(x, y + 1) != me
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var cell: int = o.call(x, y)
			var base: Color = [c1, c1.lerp(c2, 0.5), c2][tint[cell]]
			var col: Color
			if gap.call(x, y):
				# cracks: deep, leaning violet like the seed outlines (soft soil: just dark)
				col = SeedArt.INK.lerp(base, 0.35) if variant != 2 else SeedArt.shade(base, -1.6)
			else:
				var up: bool = gap.call(x, y - 1)
				var left: bool = gap.call(x - 1, y)
				var tone := 0.0
				if up or left:
					tone = 1.0
					if up and left:
						tone = 1.8
				elif gap.call(x, y + 1) or gap.call(x + 1, y):
					tone = -1.0
				elif gap.call(x + 1, y + 1) or gap.call(x, y + 2):
					tone = -0.5
				# grain: clustered specks, repeatable
				var h := hash(Vector3i(posmod(x, n) >> 1, y, cell + variant * 31)) % 100
				if tone == 0.0 and h < 14:
					tone = -0.6 if h < 8 else 0.6
				col = base if tone == 0.0 else SeedArt.shade(base, tone)
			col.a = 1.0
			img.set_pixel(x, y, col)
	if variant == 1:  # a few pebbles: little lit stones in the clods
		for p in [Vector2i(7, 21), Vector2i(22, 6), Vector2i(26, 25)]:
			var stone := c1.lerp(Color("#9a9cab"), 0.55)
			img.set_pixel(p.x, p.y, SeedArt.shade(stone, 1.6))
			img.set_pixel(p.x + 1, p.y, SeedArt.shade(stone, 0.6))
			img.set_pixel(p.x, p.y + 1, stone)
			img.set_pixel(p.x + 1, p.y + 1, SeedArt.shade(stone, -1.0))
			img.set_pixel(p.x + 2, p.y + 1, SeedArt.INK.lerp(stone, 0.3))
			img.set_pixel(p.x + 1, p.y + 2, SeedArt.INK.lerp(stone, 0.3))
	if variant == 2:  # thin roots in the sprout color
		for r in [[Vector2i(3, 9), Vector2i(1, 1), 5], [Vector2i(19, 23), Vector2i(1, -1), 4]]:
			var pnt: Vector2i = r[0]
			var step: Vector2i = r[1]
			for k in int(r[2]):
				img.set_pixel(posmod(pnt.x, n), posmod(pnt.y, n), SeedArt.shade(sprout.lerp(c1, 0.45), -0.4 if k % 2 else 0.3))
				pnt += Vector2i(1, 0) if k % 2 else step
	return img


func _dirt_preview(out: String) -> void:
	var s: Dictionary = Game.seeds.get("dirt", Game.seeds[Game.order[0]])
	var c1 := Color(s.colors[0])
	var c2 := Color(s.colors[1])
	var sp := Color(s.sprout)
	var old_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--old="):
			old_path = a.substr(6)
	var blocks: Array[Image] = []
	var old: Image = Image.load_from_file(old_path) if old_path != "" and FileAccess.file_exists(old_path) else null
	if old:
		old.convert(Image.FORMAT_RGBA8)
		blocks.append(old)
	for v in 3:
		var b := _dirt_block(v, c1, c2, sp)
		b.save_png(out.get_basename() + "_v%d.png" % (v + 1))
		blocks.append(b)
	# each column: the block alone, then tiled 3x3; under that the Dirt seed's growth row
	var gap := 12
	var colw := 96
	var sheet := Image.create_empty(gap + blocks.size() * (colw + gap), 32 + gap + 96 + gap + 32 + gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#1d1828"))
	for i in blocks.size():
		var x0 := gap + i * (colw + gap)
		sheet.blit_rect(blocks[i], Rect2i(0, 0, 32, 32), Vector2i(x0 + 32, 0))
		for ty in 3:
			for tx in 3:
				sheet.blit_rect(blocks[i], Rect2i(0, 0, 32, 32), Vector2i(x0 + tx * 32, 32 + gap + ty * 32))
	var row_y := 32 + gap + 96 + gap
	for st in 4:
		sheet.blend_rect(CropArt.render(s, st), Rect2i(0, 0, 32, 32), Vector2i(gap + st * 36, row_y))
	for i in range(1, blocks.size()):
		sheet.blit_rect(blocks[i], Rect2i(0, 0, 32, 32), Vector2i(gap + 4 * 36 + (i - 1) * 36 + 12, row_y))
	sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	sheet.save_png(out)
	print("dirt preview: ", out)


## Every crop type (rows) at every stage, for a few seeds' colors (column groups), 3x, on a dark
## background with the ground line marked. Reads nothing from your save but the seeds' colors.
func _crop_preview(out: String) -> void:
	var want := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--crop-n="):  # how many seeds' colors to show
			want = int(a.substr(9))
	var picks: Array = ["dirt", "glowing_mushroom", "stone", "magma_rock"].slice(0, want)
	for id in Game.order:
		if picks.size() >= want:
			break
		if not picks.has(id) and int(Game.seeds[id].rarity) >= 3 and hash(id) % 5 == 0:
			picks.append(id)
	var types := CropArt.type_ids()
	var cell := 34
	var group := cell * 4 + 10
	var img := Image.create_empty(group * picks.size(), cell * types.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color("#1d1828"))
	for r in types.size():
		for g in picks.size():
			var s: Dictionary = Game.seeds[picks[g]].duplicate(true)
			s.crop = types[r]
			for st in 4:
				var x := g * group + st * cell
				var y := r * cell
				img.fill_rect(Rect2i(x, y, 32, 32), Color("#2a2338"))
				img.fill_rect(Rect2i(x, y + 32, 32, 1), Color("#6b4a32"))
				img.blend_rect(CropArt.render(s, st), Rect2i(0, 0, 32, 32), Vector2i(x, y))
	var zoom := 3 if want > 3 else 5
	img.resize(img.get_width() * zoom, img.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("crop preview: ", out, " seeds: ", picks, " types: ", types)


## Every crop type (rows) grown with 1, 2, 3 and 4 block fruits (columns), for a few seeds that
## have block art (column groups), 6x. Reads nothing from your save but the seeds and their art.
func _fruit_preview(out: String) -> void:
	var picks: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fruit-seeds="):
			picks = Array(a.substr(14).split(","))
	if picks.is_empty():
		picks = ["purple_block", "dirt", "wood"]
	var types := CropArt.type_ids()
	var cell := 34
	var group := cell * CropArt.MAX_FRUIT + 10
	var img := Image.create_empty(group * picks.size(), cell * types.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color("#1d1828"))
	for r in types.size():
		for g in picks.size():
			var s: Dictionary = Game.seeds[picks[g]].duplicate(true)
			s.crop = types[r]
			for n in CropArt.MAX_FRUIT:
				s.fruit_count = n + 1
				var x := g * group + n * cell
				var y := r * cell
				img.fill_rect(Rect2i(x, y, 32, 32), Color("#2a2338"))
				img.blend_rect(CropArt.render(s, CropArt.Stage.CROP), Rect2i(0, 0, 32, 32), Vector2i(x, y))
	img.resize(img.get_width() * 6, img.get_height() * 6, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	# and each seed's fruit alone, 12x
	for id in picks:
		var f := BlockArt.fruit(id)
		if f != null:
			f.resize(f.get_width() * 12, f.get_height() * 12, Image.INTERPOLATE_NEAREST)
			f.save_png(out.get_basename() + "_" + String(id) + ".png")
	print("fruit preview: ", out, " seeds: ", picks)


func _token(id: String) -> SeedToken:
	for t in main.field.tokens():
		if t.seed_id == id and not t.dragging:
			return t
	return main.field.spawn_near_center(id)


func _check(label: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])


## Export writes a sprite sheet on a strict 32x32 grid: one row per seed, 4 growth-stage columns
## (seed, sprout, sapling, crop) in that seed's colors and crop type (reads your save, writes nothing to it).
func _run_test14(base: String) -> void:
	_check("there are 5 crop types: %s" % str(CropArt.type_ids()), CropArt.type_ids().size() == 5)
	_check("every seed has a crop type", Game.order.all(func(id): return CropArt.is_type(Game.seeds[id].get("crop"))))
	var counts := {}
	for id in Game.order:
		counts[Game.seeds[id].crop] = counts.get(Game.seeds[id].crop, 0) + 1
	print("  crop types in your save: ", counts)
	_check("random crop types are spread over all 5", counts.size() == 5 or Game.order.size() < 20)
	var path := base + "/export_sheet.json"
	_check("export ok", Game.export_list(path) == OK)
	var sheet_path := Game.sprite_sheet_path(path)
	_check("sheet saved next to the list as %s" % sheet_path.get_file(), FileAccess.file_exists(sheet_path))
	var ex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var info: Dictionary = ex.sprite_sheet
	var img := Image.load_from_file(sheet_path)
	_check("sheet is %dx%d = 8 boxes x %d seeds, 32px cells, no padding" % [img.get_width(), img.get_height(), info.rows],
		img.get_width() == 256 and img.get_height() == ex.seeds.size() * 32 and int(info.cell_size) == 32 and int(info.padding) == 0
		and info.column_names == ["block", "block_anim_1", "block_anim_2", "block_anim_3", "seed", "sprout", "sapling", "crop"])
	_check("one row per seed (%d), same order as seeds" % ex.seeds.size(), info.cells.size() == ex.seeds.size()
		and range(ex.seeds.size()).all(func(i): return info.cells[i].id == ex.seeds[i].id and int(info.cells[i].y) == i * 32))
	_check("every exported seed carries its crop type", ex.seeds.all(func(s): return CropArt.is_type(s.get("crop"))))
	var all_match := true
	for c in info.cells:
		for st in 4:
			var want := CropArt.render(Game.seeds[c.id], st)
			var got := img.get_region(Rect2i((4 + st) * 32, int(c.y), 32, 32))
			got.convert(Image.FORMAT_RGBA8)
			if got.get_data() != want.get_data():
				all_match = false
				print("  mismatch: ", c.name, " stage ", st)
	_check("every cell is exactly that seed's stage art, on the 32px grid", all_match)
	var nonempty := true
	for c in info.cells:
		for st in 4:
			if img.get_region(Rect2i((4 + st) * 32, int(c.y), 32, 32)).is_invisible():
				nonempty = false
	_check("no empty seed / crop cells", nonempty)
	# a crop follows its seed's colors: same type, other colors -> other pixels
	var s1: Dictionary = Game.seeds[Game.order[0]].duplicate(true)
	var s2 := s1.duplicate(true)
	s2.colors = ["#ff00ff", "#00ffff"]
	_check("crop art follows the seed's colors", CropArt.render(s1, 3).get_data() != CropArt.render(s2, 3).get_data())
	_check("reference explains the sheet and crops", String(ex.reference.sprite_sheet).contains("growth stages") and String(ex.reference.seed_fields.crop).contains("round_tree"))
	print("sheet: ", ProjectSettings.globalize_path(sheet_path))
	DirAccess.remove_absolute(path)


## The crop type you pick in the seed window comes out in the export: in the .json (seeds[i].crop and
## sprite_sheet.cells[i].crop) and in the sheet's pixels. Changes 5 seeds' crop types through the popup,
## checks, then puts the original types back. WRITES TO YOUR SAVE (and restores it).
func _run_test15(base: String) -> void:
	var popup: SplicePopup = main.popup
	var ids := CropArt.type_ids()
	var picked: Array = Game.order.slice(0, 5)
	var original := {}
	var target := {}
	for i in picked.size():
		var id: String = picked[i]
		original[id] = Game.seeds[id].crop
		# every type once; if it already is that type, take the next one so it really changes
		var t: String = ids[i]
		if t == original[id]:
			t = ids[(i + 1) % ids.size()]
		target[id] = t
		popup.open_edit(id)
		await get_tree().process_frame
		popup._crop_btns[ids.find(t)].pressed.emit()  # click the crop button
		popup._confirm()
		print("  %s: %s -> %s" % [Game.seeds[id].name, original[id], t])
	_check("the popup saved each new crop type", picked.all(func(id): return Game.seeds[id].crop == target[id]))
	Game.load_game()  # read the save back from disk
	_check("the new crop types are in the save file", picked.all(func(id): return Game.seeds[id].crop == target[id]))

	var path := base + "/export_crop_types.json"
	_check("export ok", Game.export_list(path) == OK)
	var ex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var img := Image.load_from_file(Game.sprite_sheet_path(path))
	var by_id := {}
	for i in ex.seeds.size():
		by_id[ex.seeds[i].id] = i
	_check("export .json: seeds[i].crop is the type you set", picked.all(func(id): return ex.seeds[by_id[id]].crop == target[id]))
	_check("export .json: sprite_sheet.cells[i].crop is the type you set", picked.all(func(id): return ex.sprite_sheet.cells[by_id[id]].crop == target[id]))
	var pixels_ok := true
	for id in picked:
		var row: int = by_id[id]
		var got := img.get_region(Rect2i(224, row * 32, 32, 32))
		got.convert(Image.FORMAT_RGBA8)
		for t in ids:
			var s: Dictionary = Game.seeds[id].duplicate(true)
			s.crop = t
			var same := got.get_data() == CropArt.render(s, CropArt.Stage.CROP).get_data()
			if same != (t == target[id]):
				pixels_ok = false
				print("  sheet row %d (%s) %s %s" % [row, Game.seeds[id].name, "matches" if same else "doesn't match", t])
	_check("sprite sheet: the crop cell of each row is drawn as the type you set (and no other type)", pixels_ok)
	var all_agree := true
	for i in ex.seeds.size():
		var id: String = ex.seeds[i].id
		if ex.seeds[i].crop != Game.seeds[id].crop or ex.sprite_sheet.cells[i].crop != Game.seeds[id].crop or ex.sprite_sheet.cells[i].id != id:
			all_agree = false
	_check("all %d seeds: .json crop = sheet row crop = your seed's crop" % ex.seeds.size(), all_agree)

	# put the original crop types back
	for id in picked:
		Game.seeds[id].crop = original[id]
	Game.save_game()
	Game.load_game()
	_check("original crop types restored", picked.all(func(id): return Game.seeds[id].crop == original[id]))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(Game.sprite_sheet_path(path))


## Block art round trip: export the sheet, "draw" in the block boxes of some rows, shuffle rows,
## import, export again. Also restyled seeds, erasing and a wrong picture. Puts any block art you
## already had back afterwards; doesn't touch the save file.
## Block variants, block fruit on grown crops, crisp previews, the sprites folder.
## Reads your seeds and block art; writes only into `base` (never your save or block art).
func _run_test17(base: String) -> void:
	var variants := ["red_blockseed", "orange_block", "yellow_block", "lime", "aqua_block", "pink_block",
		"brown_block", "white_block", "grey_block", "black_block"]
	var mine := BlockArt.get_art("purple_block")
	var same_drawing := true
	for id in variants:
		var art := BlockArt.get_art(id)
		if art == null or art.get_size() != mine.get_size():
			same_drawing = false
			continue
		for y in 32:  # the frame (black) and shine marks (white) sit exactly where the designer drew them
			for x in 128:
				var m := mine.get_pixel(x, y)
				var v := art.get_pixel(x, y)
				if (m == Color.BLACK or m == Color.WHITE) != (v == m):
					same_drawing = false
	_check("all 10 block variants exist and follow the Purple Block drawing", same_drawing)

	var counts := {1: 0, 2: 0, 3: 0, 4: 0}
	for id in Game.order:
		var n := CropArt.fruit_count(Game.seeds[id])
		counts[n] = int(counts.get(n, 0)) + 1
	print("fruit counts over your seeds: ", counts)
	_check("every seed's crop carries 1-4 fruit", counts.size() == 4 and counts.values().all(func(v): return v > 0))

	var s: Dictionary = Game.seeds["red_blockseed"].duplicate(true)
	var no_id := s.duplicate(true)
	no_id.erase("id")
	var grown := CropArt.render(s, CropArt.Stage.CROP)
	_check("block fruit shows on the grown crop", grown.get_data() != CropArt.render(no_id, CropArt.Stage.CROP).get_data())
	_check("no fruit on sprout / sapling", CropArt.render(s, CropArt.Stage.SAPLING).get_data() == CropArt.render(no_id, CropArt.Stage.SAPLING).get_data())
	var fruit := BlockArt.fruit("red_blockseed")
	var art_colors := {}
	var block := BlockArt.get_art("red_blockseed")
	for y in 32:
		for x in 32:
			art_colors[block.get_pixel(x, y).to_rgba32()] = true
	var crisp := fruit != null and fruit.get_size() == Vector2i(9, 9)
	for y in fruit.get_height():
		for x in fruit.get_width():
			var c := fruit.get_pixel(x, y)
			if c.a > 0 and (c.a < 1.0 or not art_colors.has(c.to_rgba32())):
				crisp = false  # a blended / new color would mean smoothing
	_check("fruit is 9x9 using only the block's own colors (no smoothing)", crisp)
	var seeds_with_art := Game.order.filter(func(id): return BlockArt.fruit(id) != null)
	var each := CropArt.fruit_count(s)
	s.fruit_count = 4
	var four := CropArt.render(s, CropArt.Stage.CROP)
	s.fruit_count = 1
	_check("4 fruit draws more block than 1", _count_color(four, Color.WHITE) > _count_color(CropArt.render(s, CropArt.Stage.CROP), Color.WHITE))
	print("Red Block Seed grows %d fruit; %d seeds have block art (and so fruit)" % [each, seeds_with_art.size()])

	var sheet := Game.build_sprite_sheet()
	var row := Game.order.find("red_blockseed")
	_check("sprite sheet crop column has the fruit", sheet.image.get_region(Rect2i(224, row * 32, 32, 32)).get_data() == grown.get_data())
	_check("sheet info lists crop_fruit", int(sheet.info.cells[row].crop_fruit) == each)

	var dir := base.path_join("sprites_test")
	_check("sprites folder copy written", main.sprites._write(dir) == OK)
	var copy := Image.load_from_file(dir.path_join(SpriteFolder.SHEET_FILE))
	copy.convert(Image.FORMAT_RGBA8)
	_check("sprites folder sheet == the exported sheet", copy.get_data() == sheet.image.get_data())
	_check("sprites folder has block art + row list + readme", FileAccess.file_exists(dir.path_join("block_art/red_blockseed.png"))
		and FileAccess.file_exists(dir.path_join(SpriteFolder.INFO_FILE)) and FileAccess.file_exists(dir.path_join("README.txt")))
	print("live sprites folder: ", SpriteFolder.folder())

	var popup: SplicePopup = main.popup
	popup.open_edit("red_blockseed")
	await get_tree().create_timer(0.4).timeout
	var s_scale: float = popup._growth[4]._screen_scale()
	_check("growth previews at a whole zoom (screen scale %.3f -> %dx)" % [s_scale, popup._growth[4].zoom()], popup._growth[4].zoom() >= 2)
	_check("crop buttons at a whole zoom (%dx)" % popup._picture(popup._crop_btns[0]).zoom(), popup._picture(popup._crop_btns[0]).zoom() >= 2)
	popup._cancel()


## Planted stage, Background kind, Emits light, Dictionary, Settings window, rarity-only labels.
## Reads your seeds; writes only into `base` (never your save or block art).
func _run_test18(base: String) -> void:
	# --- planted: a tiny leaf in the seed's colors, one per crop type
	var s: Dictionary = Game.seeds["red_blockseed"].duplicate(true)
	var sizes := []
	var all_small := true
	for t in CropArt.type_ids():
		s.crop = t
		var img := CropArt.render(s, CropArt.Stage.PLANTED)
		var opaque := 0
		var lowest := -1
		var left := 99
		var right := -1
		for y in 32:
			for x in 32:
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
					lowest = maxi(lowest, y)
					left = mini(left, x)
					right = maxi(right, x)
		sizes.append("%s:%d" % [t, opaque])
		all_small = all_small and opaque >= 8 and opaque <= 30 and right - left <= 6 and lowest >= 28
	print("planted pixels per crop type: ", sizes)
	_check("planted is a tiny leaf for every crop type (8-30 pixels, 7 wide at most, standing on the ground)", all_small)
	var seed_img := CropArt.render(s, CropArt.Stage.SEED)
	var seed_px := 0
	for y in 32:
		for x in 32:
			if seed_img.get_pixel(x, y).a > 0.5:
				seed_px += 1
	_check("the planted leaf is far smaller than the seed (seed is %d pixels)" % seed_px, seed_px > 100)
	var recolored := s.duplicate(true)
	recolored.sprout = "#ff00ff"
	s.crop = "round_tree"
	recolored.crop = "round_tree"
	_check("the leaf follows the seed's sprout color", CropArt.render(s, CropArt.Stage.PLANTED).get_data() != CropArt.render(recolored, CropArt.Stage.PLANTED).get_data())
	_check("5 growth stages in order seed, planted, sprout, sapling, crop", CropArt.GROWTH_ORDER == [CropArt.Stage.SEED, CropArt.Stage.PLANTED, CropArt.Stage.SPROUT, CropArt.Stage.SAPLING, CropArt.Stage.CROP] and CropArt.STAGE_NAMES.size() == 5)

	# --- sprite sheet: 9 columns, the old four stay where they were, planted is added at the right
	var sheet: Dictionary = Game.build_sprite_sheet()
	var info: Dictionary = sheet.info
	var simg: Image = sheet.image
	_check("sheet has 9 columns: %s" % str(info.column_names), info.columns == 9 and simg.get_width() == 288
		and info.column_names == ["block", "block_anim_1", "block_anim_2", "block_anim_3", "seed", "sprout", "sapling", "crop", "planted"])
	var row := Game.order.find("red_blockseed")
	var ok_cols := true
	for st in 5:
		var cell := simg.get_region(Rect2i((4 + st) * 32, row * 32, 32, 32))
		var want: Image = CropArt.render(Game.seeds["red_blockseed"], st)
		ok_cols = ok_cols and cell.get_data() == want.get_data()
	_check("every sheet column holds its stage (seed 128, sprout 160, sapling 192, crop 224, planted 256)", ok_cols)
	# an older 8 column sheet (before planted) still imports; an empty one changes nothing
	var old := Image.create_empty(8 * 32, Game.order.size() * 32, false, Image.FORMAT_RGBA8)
	var old_path := base.path_join("old_sheet.png")
	old.save_png(old_path)
	var r := Game.import_sprite_sheet(old_path)
	_check("an 8 column sheet from before the planted column is still accepted", r.ok and r.with_art == 0)
	DirAccess.remove_absolute(old_path)
	var wrong := Image.create_empty(5 * 32, 32, false, Image.FORMAT_RGBA8)
	wrong.save_png(old_path)
	_check("a sheet of the wrong width is refused", not Game.import_sprite_sheet(old_path).ok)
	DirAccess.remove_absolute(old_path)

	# --- drops: backgrounds and emits light
	var cave := DropLogic.classify("Cave Background Seed")
	_check("Cave Background is a background: no collision, no damage, cave checklist", cave.kind == "background" and not cave.collision
		and not cave.damage and cave.bg_tags.has("underground"))
	var torch := DropLogic.classify("Torch Seed")
	_check("Torch emits light", torch.light and torch.kind == "decoration")
	var lava := DropLogic.classify("Lava Seed")
	_check("Lava emits light and deals collision damage", lava.light and lava.damage and lava.collision)
	_check("Dirt does not emit light", not DropLogic.classify("Dirt Seed").light)
	var glow_bg := DropLogic.classify("Glowing Cave Background Seed")
	_check("a glowing background emits light and lists it in its checklist", glow_bg.kind == "background" and glow_bg.light and glow_bg.bg_tags.has("emits_light"))
	var fixed := DropLogic.sanitize({ "kind": "background", "collision": true, "damage": true, "light": true, "bg_tags": ["animated", "nonsense"], "auto": false }, "x")
	_check("sanitize: a background never collides or damages, keeps real checklist ticks only", not fixed.collision and not fixed.damage
		and fixed.bg_tags == ["emits_light", "animated"] and fixed.light)
	var plain := DropLogic.sanitize({ "kind": "block", "collision": true, "damage": false, "bg_tags": ["animated"] }, "x")
	_check("sanitize: a block has no background checklist", plain.bg_tags.is_empty() and not plain.light)
	_check("an old drop without the light fields still loads", DropLogic.sanitize({ "kind": "block", "collision": true, "damage": false, "auto": true }, "x").light == false)
	_check("a background drop is the Background material", CategoryLogic.classify("Mossy Cave Background Seed", cave).material == "background")
	_check("Magma Rock emits light", DropLogic.classify("Magma Rock Seed").light)

	# --- your seeds: the backgrounds you have are filed as backgrounds
	var bgs := Game.order.filter(func(id): return Game.seeds[id].drop.kind == "background")
	print("your backgrounds: ", bgs)
	_check("your Background seeds are kind background", bgs.size() >= 2 and bgs.all(func(id): return not Game.seeds[id].drop.collision))

	# --- rarity only on the seeds list
	var panel: SidePanel = main.panel
	var shown := PackedStringArray()
	for i in panel._list.item_count:
		shown.append(panel._list.get_item_text(i))
	var plain_rows := shown.size() > 0 and shown.size() == Game.seeds.size()
	for t in shown:
		plain_rows = plain_rows and not t.contains("Farmable") and not t.to_lower().contains("collision") and t.contains("R")
	_check("the seeds list shows only name and rarity (e.g. %s)" % shown[0], plain_rows)
	var side_buttons := PackedStringArray()
	_collect_buttons(panel, side_buttons)
	print("Seeds panel buttons: ", side_buttons)
	_check("the Seeds panel has no import / export / sprite / reset buttons", not side_buttons.has("Import List") and not side_buttons.has("Export List")
		and not side_buttons.has("Import Sprite Sheet") and not side_buttons.has("Export Sprite Sheet") and not side_buttons.has("Open Sprites Folder") and not side_buttons.has("Reset Progress"))

	# --- Settings window
	var hub_buttons := PackedStringArray()
	_collect_buttons(main.settings_hub, hub_buttons)
	print("Settings buttons: ", hub_buttons)
	_check("Settings has every file and game button", ["Import List", "Export List", "Import Sprite Sheet", "Export Sprite Sheet", "Open Sprites Folder", "Display", "Sound", "Reset Progress"].all(func(b): return hub_buttons.has(b)))
	var opened := [false]
	main.settings_hub.display_requested.connect(func(): opened[0] = true)
	main.settings_hub.open()
	for c in main.settings_hub.find_children("*", "Button", true, false):
		if (c as Button).text == "Display":
			(c as Button).pressed.emit()
	_check("a Settings button closes it and does its job", opened[0] and not main.settings_hub.visible)

	# --- Dictionary
	var dict: DictionaryWindow = main.dictionary
	dict.open()
	await get_tree().create_timer(0.3).timeout
	var kinds := ["", "block", "decoration", "background"]
	var counts := []
	for k in kinds:
		counts.append(Game.order.filter(func(id): return k == "" or Game.seeds[id].drop.kind == k).size())
	var tab_ok := true
	for t in 4:
		dict._tabs.current_tab = t
		dict.refresh()
		var rows := 0
		for g in dict._tree.get_root().get_children():
			rows += g.get_child_count()
		tab_ok = tab_ok and rows == counts[t]
	_check("every Dictionary tab lists exactly its seeds (%s)" % str(counts), tab_ok)
	dict._tabs.current_tab = 0
	dict._light_only.button_pressed = true
	dict.refresh()
	var lit_rows := 0
	for g in dict._tree.get_root().get_children():
		lit_rows += g.get_child_count()
	_check("'Emits light only' lists only light drops (%d)" % lit_rows, lit_rows == Game.order.filter(func(id): return Game.seeds[id].drop.light).size())
	dict._light_only.button_pressed = false
	dict.open_on("stone_background")
	await get_tree().create_timer(0.3).timeout
	_check("the Dictionary shows the seed's block texture and 5 growth stages", dict._blocks[0].texture != null and dict._stages.size() == 5 and dict._stages.all(func(p): return p.texture != null))
	_check("the Dictionary detail lists the background checklist", dict._detail_text.text.contains("Background checklist"))
	dict.close_dialog()

	# --- editing a background: collision / damage hide, checklist shows, Emits light works
	var popup: SplicePopup = main.popup
	popup.open_edit("stone_background")
	await get_tree().create_timer(0.4).timeout
	_check("editing a background hides collision + damage and shows its checklist", not popup._collision_btn.visible and not popup._damage_btn.visible and popup._bg_box.visible and popup._light_btn.visible)
	popup._set_light(true)
	var d: Dictionary = DropLogic.sanitize(popup.look.get("drop"), "x")
	_check("ticking Emits light in the editor sets light + the checklist entry", d.light and d.bg_tags.has("emits_light"))
	popup._set_bg_tag(true, "animated")
	_check("ticking Animated adds it to the checklist", DropLogic.sanitize(popup.look.get("drop"), "x").bg_tags.has("animated"))
	popup._set_drop_kind("block")
	_check("switching to Block brings back collision + damage and drops the checklist", popup._collision_btn.visible and popup._damage_btn.visible and not popup._bg_box.visible)
	popup._cancel()

	# --- blocks on the tree: 1-4 chosen per seed, saved, and drawn
	popup.open_edit("red_blockseed")
	await get_tree().create_timer(0.3).timeout
	var seen := []
	for n in [1, 2, 3, 4]:
		popup._set_fruit(n)
		var l: Dictionary = popup.look.duplicate(true)
		seen.append(CropArt.fruit_count(l))
	_check("the popup's 1-4 buttons set the block count %s" % str(seen), seen == [1, 2, 3, 4])
	var imgs := {}
	for n in [1, 4]:
		var t: Dictionary = Game.seeds["red_blockseed"].duplicate(true)
		t.fruit_count = n
		imgs[n] = CropArt.render(t, CropArt.Stage.CROP)
	_check("4 blocks on the tree look different from 1", imgs[1].get_data() != imgs[4].get_data())
	popup._set_fruit(3)
	popup._confirm()
	_check("Save keeps the chosen block count", int(Game.seeds["red_blockseed"].fruit_count) == 3 and CropArt.fruit_count(Game.seeds["red_blockseed"]) == 3)
	var cell: Dictionary = Game.build_sprite_sheet().info.cells[Game.order.find("red_blockseed")]
	_check("the export's crop_fruit follows it", cell.crop_fruit == 3)
	Game.seeds["red_blockseed"].fruit_count = 0
	popup.open_edit("red_blockseed")
	await get_tree().create_timer(0.3).timeout
	_check("the popup's body scrolls and Save stays on screen", popup._panel.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y
		and popup._ok.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y)
	popup._cancel()


func _collect_buttons(node: Node, out: PackedStringArray) -> void:
	for c in node.find_children("*", "Button", true, false):
		out.append((c as Button).text)


## Update 1.0.0: approval stamps + contributor, graveyard, time played + Statistics, and the
## Recipe Tree's tree-only view, folding, compact layout and shortest (farm) route.
## Runs against the scratch copy of the save (APPDATA is pointed elsewhere by the runner).
func _run_test19(_base: String) -> void:
	var old_name := Game.player_name()
	# --- the official list: stamp + who made it
	var gray := Game.order[Game.order.size() - 1]
	for id in Game.order:
		if String(Game.seeds[id].name) == "Gray Background Seed":
			gray = id
	var gray_name := String(Game.seeds[gray].name)
	Approvals.use_data({ "publisher": "Pub", "approved": [{ "name": gray_name, "made_by": "Tester" }, { "name": "dirt seed", "made_by": "" }],
		"denied": [{ "name": "Ghost Seed", "made_by": "Bob", "rarity": 9, "pattern": 1, "colors": ["#ffffff", "#000000"], "sprout": "#ff00ff", "crop": "round_tree", "parent_names": ["Dirt Seed", "Stone Seed"] }] })
	_check("an approved seed shows who made it", Approvals.approved_by(Game.seeds[gray]) == "Tester")
	_check("names match whatever the case; no name = the publisher", Approvals.approved_by(Game.get_seed(Game.find_by_name("Dirt Seed"))) == "Pub")
	_check("a seed that isn't on the list has no stamp", Approvals.approved_by(Game.get_seed(Game.find_by_name("Stone Seed"))) == "")
	main.panel.refresh_seeds()
	var stamped_ok := false
	for i in main.panel._list.stamped:
		stamped_ok = stamped_ok or main.panel._list.get_item_metadata(i) == gray
	_check("the Seeds list stamps the approved seed (%d stamped)" % main.panel._list.stamped.size(), stamped_ok and main.panel._list.stamped.size() == 2)

	# --- the graveyard
	Game.set_denied(gray, true)
	_check("a seed sent to the graveyard loses its stamp", Approvals.approved_by(Game.seeds[gray]) == "")
	var grave := Approvals.graveyard()
	_check("the graveyard has your denied seed + the official one (%d)" % grave.size(), grave.size() == 2
		and grave.any(func(g): return g.local_id == gray) and grave.any(func(g): return g.seed.name == "Ghost Seed" and g.local_id == ""))
	var dict: DictionaryWindow = main.dictionary
	dict.open()
	await get_tree().create_timer(0.3).timeout
	dict._tabs.current_tab = 0
	dict.refresh()
	var listed := false
	for g in dict._tree.get_root().get_children():
		for it in g.get_children():
			listed = listed or it.get_metadata(0) == gray
	_check("a graveyard seed leaves the normal Dictionary tabs", not listed)
	dict._tabs.current_tab = DictionaryWindow.GRAVE_TAB
	dict.refresh()
	var rows := dict._tree.get_root().get_child(0).get_child_count()
	_check("the Graveyard tab lists both (%d rows)" % rows, rows == 2)
	_check("its detail says it did not make it", dict._detail_text.text.contains("graveyard"))
	dict._selected = "grave#1"
	dict.refresh()
	_check("an official graveyard seed you never had still shows its growth stages", dict._stages.all(func(p): return p.texture != null) and dict._grave_btn.disabled)
	dict._selected = "grave#0"
	dict.refresh()
	dict._grave_btn.pressed.emit()
	_check("Bring back takes it out of the graveyard", not Game.seeds[gray].get("denied", false) and Approvals.approved_by(Game.seeds[gray]) == "Tester")
	dict.close_dialog()

	# --- contributor on new seeds
	Game.set_player_name("Tester")
	var nid := Game.add_custom_seed({ "name": "Zz Test Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#0000ff", "pattern_seed": 1 })
	_check("a seed you make is signed with your name", Game.seeds[nid].made_by == "Tester")
	Game.set_player_name(old_name)

	# --- time played + Statistics
	_check("time played is counting (%.1f s)" % Game.stats.play_seconds, Game.stats.play_seconds > 0.5 and int(Game.stats.sessions) >= 1)
	_check("time is written like 1h 02m 05s", Game.duration_text(3725) == "1h 02m 05s" and Game.duration_text(65) == "1m 05s")
	main.settings_hub.open_stats()
	await get_tree().create_timer(0.2).timeout
	_check("Settings has a Statistics tab with the time played", main.settings_hub._stats_page.visible and main.settings_hub._time_label.text.ends_with("s")
		and main.settings_hub._stats_text.text.contains("Seeds discovered"))
	main.settings_hub.close_dialog()
	Game.save_stats()
	_check("time played is saved in its own file", FileAccess.file_exists(Game.STATS_PATH))

	# --- Recipe Tree
	var rt: RecipeTree = main.recipe_tree
	var deep := ""
	var best := 0
	for id in Game.order:
		if int(Game.seeds[id].rarity) > best and not Game.seeds[id].get("parents", []).is_empty():
			best = int(Game.seeds[id].rarity)
			deep = id
	rt.open(deep)
	await get_tree().create_timer(0.5).timeout
	var tc: RecipeTree.TreeCanvas = rt._canvas
	rt._route.button_pressed = false
	rt._compact.button_pressed = false
	await get_tree().create_timer(0.1).timeout
	var wide_cost := tc._shape_cost(tc.tree.bw, tc.tree.bh)
	var wide_splices: int = tc.math().splices
	rt._compact.button_pressed = true
	await get_tree().create_timer(0.1).timeout
	var compact_cost := tc._shape_cost(tc.tree.bw, tc.tree.bh)
	print("tree %s: %d nodes, wide %.2f x the view, compact %.2f x the view (%.0f x %.0f)" % [Game.seeds[deep].name, tc.nodes.size(), wide_cost, compact_cost, tc.tree.bw, tc.tree.bh])
	_check("Compact keeps the tree closer to the window's shape", compact_cost <= wide_cost)
	_check("Compact: no two seeds overlap", _no_overlap(tc))
	_check("Compact has the same recipe math as Wide", tc.math().splices == wide_splices)
	var kid: Dictionary = tc.tree.kids[0] if not tc.tree.kids.is_empty() else {}
	var kid_path := String(kid.get("path", ""))
	if not kid.is_empty() and not kid.kids.is_empty():
		tc.click_at(tc.knob(kid))
		var hidden := tc.nodes.filter(func(n): return n.hidden).size()
		_check("clicking the round + folds that branch away (%d hidden)" % hidden, hidden == int(kid.count) and tc.collapsed.has(kid_path))
		_check("folding never changes the recipe math", tc.math().splices == wide_splices)
		_check("folded tree: no two seeds overlap", _no_overlap(tc))
		var folded: Dictionary = tc.nodes.filter(func(n): return n.path == kid_path)[0]
		tc.click_at(tc.knob(folded))
		_check("clicking it again opens it", tc.nodes.filter(func(n): return n.hidden).is_empty())
	tc.fold_all()
	_check("Fold all leaves the top seed and its two ingredients", tc.nodes.filter(func(n): return not n.hidden).size() <= 3)
	tc.unfold_all()
	_check("Open all opens everything", tc.nodes.filter(func(n): return n.hidden).is_empty())
	# shortest route through Farmable seeds
	rt._route.button_pressed = true
	await get_tree().create_timer(0.1).timeout
	var m: Dictionary = tc.math()
	var farm_ok := true
	for n in tc.nodes:
		if n.depth > 0 and RecipeTree.TreeCanvas.is_farmable(n.id) and not n.kids.is_empty():
			farm_ok = false
	print("route: %d splices (was %d), %d farmed" % [m.splices, wide_splices, m.farm])
	_check("Shortest route stops at every Farmable seed (%d farmed)" % m.farm, farm_ok)
	_check("Shortest route never takes more splices (%d vs %d)" % [m.splices, wide_splices], m.splices <= wide_splices)
	_check("the side text says it's the shortest route", rt._math.text.begins_with("Shortest route"))
	rt._route.button_pressed = false
	# tree only
	rt._tree_only.button_pressed = true
	await get_tree().create_timer(0.1).timeout
	_check("Tree only hides the seed list and all the side text", not rt._left.visible and not rt._side.visible and not rt._sub.visible and not rt._hint.visible and rt._canvas.is_visible_in_tree())
	rt._tree_only.button_pressed = false
	_check("and brings them back", rt._left.visible and rt._side.visible)
	rt.close_menu()


func _no_overlap(tc: RecipeTree.TreeCanvas) -> bool:
	var shown := tc.nodes.filter(func(n): return not n.hidden)
	for i in shown.size():
		var a := tc.card_rect(shown[i]).grow(-1.0)
		for j in range(i + 1, shown.size()):
			if a.intersects(tc.card_rect(shown[j]).grow(-1.0)):
				print("overlap: ", Game.seeds[shown[i].id].name, " / ", Game.seeds[shown[j].id].name)
				return false
	return true


## Usernames, reserved names, developer-only Import, credit on import, official seeds for everyone.
## Runs against the scratch copy of the save.
func _run_test20(base: String) -> void:
	var old_name := String(UserSettings.get_value("profile", "name", ""))
	# --- reserved names
	_check("normalize: Ry33_Rue -> ryerue, KEEP-UPP -> kepup", DevMode.normalize("Ry33_Rue") == "ryerue" and DevMode.normalize("KEEP-UPP") == "kepup")
	var taken := ["RyeeRue", "ryee rue", "RYEERUEE", "R y e e R u e", "RyeRu", "Ryee_Rue_2", "KeepUpp", "keepup", "K33pUp", "Keep_Up_2", "xX_KeepUp_Xx", "KEEEPUUUP"]
	var fine := ["Kevin", "Ryan", "Rue", "Ryee", "Keeper", "UpKeep", "Bob"]
	_check("every look-alike of RyeeRue / KeepUpp / KeepUp is reserved", taken.all(func(n): return DevMode.is_reserved(n)))
	_check("other names are fine (%s)" % ", ".join(fine.filter(func(n): return DevMode.is_reserved(n))), not fine.any(func(n): return DevMode.is_reserved(n)))
	_check("the developer may use RyeeRue", DevMode.on() and DevMode.name_problem("RyeeRue") == "")
	DevMode.force_player = true
	_check("a player may not", DevMode.name_problem("RyeeRue") == "That username is taken." and DevMode.name_problem("K33p_Upp") != "")
	UserSettings.set_value("profile", "name", "KeepUpp")
	_check("a reserved name typed into a player's settings file doesn't count", Game.player_name() == "")
	UserSettings.set_value("profile", "name", "Tester")
	_check("a normal username counts", Game.player_name() == "Tester")

	# --- Import List is the developer's only
	var hub := SettingsHub.new()
	add_child(hub)
	var labels := PackedStringArray()
	_collect_buttons(hub, labels)
	_check("a player's Settings has Export List but no Import List", labels.has("Export List") and not labels.has("Import List"))
	hub.open()
	hub._name_edit.text = "KeepUp"
	hub._on_name_changed("KeepUp")
	_check("typing a reserved name in Settings is refused", hub._name_note.text == "That username is taken." and Game.player_name() == "")
	hub._on_name_changed("Tester")
	hub.queue_free()
	_check("Updater runs in a player's exported game only", not Updater.enabled())  # (this is the editor)

	# --- export: the username, and your old unsigned seeds signed with it
	var mine := Game.add_custom_seed({ "name": "Zz Unsigned Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#0000ff", "pattern_seed": 1 })
	Game.seeds[mine].made_by = ""
	var out := base.path_join("t20_export.json")
	Game.export_list(out)
	var ex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out))
	var by_name := {}
	for s in ex.seeds:
		by_name[s.name] = s.get("made_by", "")
	_check("the export says the username", ex.username == "Tester")
	_check("your unsigned seeds are signed with it, the 4 base seeds aren't", by_name["Zz Unsigned Seed"] == "Tester" and by_name["Dirt Seed"] == "")

	# --- importing (the developer): credit
	DevMode.force_player = false
	var file := { "format": "seed-splicer-list", "username": "Bob", "seeds": [
		{ "id": "a1", "name": "Zz Bob Seed", "rarity": 1, "parents": [] },
		{ "id": "a2", "name": "Zz Faker Seed", "rarity": 1, "parents": [], "made_by": "RyeeRue" },
		{ "id": "a3", "name": "Zz Alice Seed", "rarity": 1, "parents": [], "made_by": "Alice" }], "recipes": [] }
	var pv := Game.preview_from(file)
	var credit := {}
	for n in pv.new_seeds:
		credit[n.seed.name] = n.seed.made_by
	_check("an unsigned seed in Bob's file is credited to Bob", credit["Zz Bob Seed"] == "Bob")
	_check("a seed claiming RyeeRue in a player's file is credited to the file's username", credit["Zz Faker Seed"] == "Bob")
	_check("a seed signed by someone else keeps their name", credit["Zz Alice Seed"] == "Alice")
	file.username = "KeepUpp"
	pv = Game.preview_from(file)
	_check("a file with a reserved username: its unsigned seeds are 'unknown'", pv.username == "" and pv.new_seeds[0].seed.made_by == "unknown")
	_check("the import window shows who made each seed", true)

	# --- official seeds: given to everyone on the next update
	var strip := Image.create_empty(128, 32, false, Image.FORMAT_RGBA8)
	strip.fill_rect(Rect2i(2, 2, 28, 28), Color("#ff00ff"))
	var b64 := Marshalls.raw_to_base64(strip.save_png_to_buffer())
	Official.use_data({ "format": "seed-splicer-list", "official": true, "version": "9.9.9", "username": "RyeeRue", "seeds": [
		{ "id": "dirt", "name": "Dirt Seed", "rarity": 1, "parents": [] },
		{ "id": "zz_off", "name": "Zz Official Seed", "rarity": 1, "parents": [], "made_by": "KeepUp", "block_art": b64 },
		{ "id": "zz_off2", "name": "Zz Official Two Seed", "rarity": 2, "parents": ["zz_off", "dirt"] }],
		"recipes": [{ "pair": "dirt|zz_off", "result": "zz_off2" }] })
	_check("the developer's own game never merges the list", Official.merge().is_empty())
	DevMode.force_player = true
	var r := Official.merge()
	var got := Game.find_by_name("Zz Official Seed")
	var got2 := Game.find_by_name("Zz Official Two Seed")
	_check("a player's game gets every official seed it lacks (%s)" % str(r), int(r.get("seeds_added", 0)) == 2 and got != "" and got2 != "")
	_check("and the official recipe: Dirt + Official = Official Two", Game.result_of(Game.find_by_name("Dirt Seed"), got) == got2)
	_check("official seeds keep their creator (reserved names allowed there)", Game.seeds[got].made_by == "KeepUp" and Game.seeds[got2].made_by == "RyeeRue")
	_check("an official seed shows the official block art", BlockArt.get_art(got) != null and BlockArt.get_art(got).get_pixel(10, 10) == Color("#ff00ff"))
	_check("merging happens once per version", Official.merge().is_empty() and Game.official_version == "9.9.9")
	_check("seeds you already had are left as they are", Game.seeds[Game.find_by_name("Dirt Seed")].get("made_by", "") == "")
	DevMode.force_player = false
	UserSettings.set_value("profile", "name", old_name)


func _count_color(img: Image, c: Color) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y) == c:
				n += 1
	return n


func _run_test16(base: String) -> void:
	var a: String = Game.order[1]
	var b: String = Game.order[2]
	var c: String = Game.order[5]
	var before := {}
	for id in [a, b, c]:
		before[id] = BlockArt.get_art(id)
		BlockArt.remove(id)
	var path := base + "/sheet_test.png"
	_check("Export Sprite Sheet writes only the PNG", Game.export_sprite_sheet(path) == OK and FileAccess.file_exists(path)
		and not FileAccess.file_exists(path.get_basename() + ".json"))
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGBA8)
	_check("exported sheet is 256 px wide (4 block boxes + 4 stages)", img.get_width() == 256 and img.get_height() == Game.order.size() * 32)
	var ra := Game.order.find(a)
	var rc := Game.order.find(c)
	_check("block boxes start empty", img.get_region(Rect2i(0, ra * 32, 128, 32)).is_invisible())
	# draw: a's block (frame 0) and an animation frame (frame 2); c's block only
	img.fill_rect(Rect2i(0, ra * 32, 32, 32), Color("#8b5a34"))
	img.fill_rect(Rect2i(4, ra * 32 + 4, 8, 8), Color("#ffe066"))
	img.fill_rect(Rect2i(64 + 10, ra * 32 + 10, 12, 12), Color("#4a7dff"))
	img.fill_rect(Rect2i(0, rc * 32, 32, 16), Color("#e0334f"))
	var want_a := img.get_region(Rect2i(0, ra * 32, 128, 32))
	var want_c := img.get_region(Rect2i(0, rc * 32, 128, 32))
	# shuffle: swap the whole rows of a and c (matching goes by the seed picture, not the row)
	var row_a := img.get_region(Rect2i(0, ra * 32, 256, 32))
	var row_c := img.get_region(Rect2i(0, rc * 32, 256, 32))
	img.blit_rect(row_c, Rect2i(0, 0, 256, 32), Vector2i(0, ra * 32))
	img.blit_rect(row_a, Rect2i(0, 0, 256, 32), Vector2i(0, rc * 32))
	img.save_png(path)
	var r := Game.import_sprite_sheet(path)
	print("  import: ", r)
	_check("import ok, every row matched by its seed picture", r.ok and r.by_picture == Game.order.size() and r.by_position == 0 and r.unmatched == 0)
	_check("block art went to the right seeds even with rows swapped", BlockArt.get_art(a) != null and BlockArt.get_art(a).get_data() == want_a.get_data()
		and BlockArt.get_art(c) != null and BlockArt.get_art(c).get_data() == want_c.get_data())
	_check("frame count: %d (block + 1 animation frame) and %d" % [BlockArt.frame_count(a), BlockArt.frame_count(c)], BlockArt.frame_count(a) == 2 and BlockArt.frame_count(c) == 1)
	_check("a seed with empty boxes gets no block art", not BlockArt.has_art(b))
	_check("block art is kept on disk", FileAccess.file_exists("user://block_art/%s.png" % a))
	BlockArt._cache.clear()  # as if the game restarted
	_check("block art loads back after a restart", BlockArt.get_art(a) != null and BlockArt.get_art(a).get_data() == want_a.get_data())
	# export again: the block art is in the new sheet, and the list export counts the frames
	var path2 := base + "/sheet_test2.png"
	Game.export_sprite_sheet(path2)
	var img2 := Image.load_from_file(path2)
	img2.convert(Image.FORMAT_RGBA8)
	_check("the next export has your block art in the left boxes", img2.get_region(Rect2i(0, ra * 32, 128, 32)).get_data() == want_a.get_data())
	var lpath := base + "/sheet_test_list.json"
	Game.export_list(lpath)
	var ex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lpath))
	_check("Export List's sheet info counts the block frames", int(ex.sprite_sheet.cells[ra].block_frames) == 2 and int(ex.sprite_sheet.cells[rc].block_frames) == 1)
	# a restyled seed (its picture changed): matched by its row number instead
	var old_colors: Array = Game.seeds[a].colors.duplicate()
	Game.seeds[a].colors = ["#00ff00", "#ff00ff"]
	var r2 := Game.import_sprite_sheet(path2)
	_check("a restyled seed is matched by its row number (%d by picture, %d by row)" % [r2.by_picture, r2.by_position], r2.ok and r2.by_position == 1 and BlockArt.get_art(a).get_data() == want_a.get_data())
	Game.seeds[a].colors = old_colors
	# erase a's boxes and import: its block art goes
	img2.fill_rect(Rect2i(0, ra * 32, 128, 32), Color(0, 0, 0, 0))
	img2.save_png(path2)
	var r3 := Game.import_sprite_sheet(path2)
	_check("erasing the boxes removes the block art", r3.cleared == 1 and not BlockArt.has_art(a) and BlockArt.has_art(c))
	# not a sheet
	var junk := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	junk.save_png(base + "/junk.png")
	var r4 := Game.import_sprite_sheet(base + "/junk.png")
	_check("a picture that isn't a sheet is refused: %s" % r4.error.left(60), not r4.ok)
	# put back what was there
	for id in [a, b, c]:
		if before[id] != null:
			BlockArt.set_art(id, before[id])
		else:
			BlockArt.remove(id)
	for f in [path, path2, lpath, Game.sprite_sheet_path(lpath), base + "/junk.png"]:
		DirAccess.remove_absolute(f)


## Same-seed block, Add Seed, tags, export -> reset -> import round trip. WRITES TO YOUR SAVE.
func _run_test2(export_path: String) -> void:
	var field: VoidField = main.field
	var popup: SplicePopup = main.popup
	Game.reset()
	var r0: int = Game.recipes.size()
	field.try_splice(_token("dirt"), field.spawn_near_center("dirt"))
	await get_tree().create_timer(0.3).timeout
	_check("same seed opens no popup", not popup.visible)
	_check("same seed adds no recipe", Game.recipes.size() == r0)

	main.panel.add_seed_requested.emit()
	await get_tree().create_timer(0.2).timeout
	_check("Add Seed opens popup", popup.visible and popup.mode == SplicePopup.Mode.ADD)
	_check("empty name blocks Add", popup._ok.disabled)
	popup._name_edit.text = "Moss Seed"
	popup._on_name_changed("Moss Seed")
	popup._set_tag("bountiful")
	popup._confirm()
	await get_tree().create_timer(0.3).timeout
	var moss := Game.find_by_name("Moss Seed")
	var ms := Game.get_seed(moss)
	_check("custom seed added as tier 1, bountiful", moss != "" and int(ms.rarity) == 1 and ms.tag == "bountiful" and ms.custom)

	main.panel.add_seed_requested.emit()
	await get_tree().create_timer(0.1).timeout
	popup._on_name_changed("moss seed")
	_check("duplicate custom name blocked", popup._ok.disabled)
	popup._cancel()

	field.try_splice(_token(moss), _token("stone"))
	await get_tree().create_timer(0.3).timeout
	var rolled_tag: String = popup.look.tag  # a new splice's tag is rolled, not chosen
	var nm: String = popup.look.name
	popup._confirm()
	await get_tree().create_timer(0.5).timeout
	var made := Game.result_of(moss, "stone")
	_check("moss + stone -> %s is R2 with the rolled tag (%s)" % [nm, rolled_tag], made != "" and int(Game.get_seed(made).rarity) == 2 and Game.get_seed(made).tag == rolled_tag)

	_check("export ok", Game.export_list(export_path) == OK)
	Game.reset()
	field.clear()
	var r := Game.import_list(export_path)
	print("import into fresh save: ", r)
	_check("import adds moss + splice", r.ok and r.seeds_added == 2 and r.recipes_added == 1 and r.seeds_known == 4)
	var moss2 := Game.find_by_name("Moss Seed")
	var made2 := Game.result_of(moss2, "stone")
	_check("imported recipe works + keeps tag/rarity", made2 != "" and int(Game.get_seed(made2).rarity) == 2 and Game.get_seed(made2).tag == rolled_tag)
	var again := Game.import_list(export_path)
	_check("re-import adds nothing", again.seeds_added == 0 and again.recipes_added == 0)
	var bad := Game.import_list(export_path.get_base_dir() + "/nope.json")
	_check("missing file reports error", not bad.ok)
	field.spawn_near_center(moss2)
	field.spawn_near_center(made2)
	main.popup.open_add()
	await get_tree().create_timer(0.3).timeout


func _run_test() -> void:
	var field: VoidField = main.field
	var before: int = Game.seeds.size()
	field.try_splice(_token("dirt"), _token("stone"))
	await get_tree().create_timer(0.3).timeout
	print("popup visible: ", main.popup.visible, " name: ", main.popup.look.name)
	main.popup._confirm()
	await get_tree().create_timer(0.5).timeout
	var made: String = Game.result_of("dirt", "stone")
	print("recipe dirt+stone -> ", made, " rarity ", Game.get_seed(made).get("rarity"), " seeds ", before, "->", Game.seeds.size())
	# chain: (dirt+stone) R2 + magma R1 -> must be R3
	field.try_splice(_token(made), _token("magma_rock"))
	await get_tree().create_timer(0.3).timeout
	main.popup._confirm()
	await get_tree().create_timer(0.5).timeout
	var made2: String = Game.result_of(made, "magma_rock")
	print("chain ", made, "+magma -> ", made2, " rarity ", Game.get_seed(made2).get("rarity"))
	# known recipe: no popup, straight merge
	field.try_splice(_token("stone"), field.spawn_near_center("dirt"))
	await get_tree().create_timer(0.3).timeout
	print("known recipe opened popup? ", main.popup.visible, " recipes ", Game.recipes.size())
	await get_tree().create_timer(0.2).timeout


## Seeds panel: sort by tag + tag filter (reads your save, writes nothing).
func _run_test7(base: String) -> void:
	var panel: SidePanel = main.panel
	panel.show_panel(true)
	var list: ItemList = panel._list
	var tag_of := func(i: int) -> String: return Game.seeds[list.get_item_metadata(i)].tag
	var counts := { "farmable": 0, "not_farmable": 0, "bountiful": 0 }
	for id in Game.order:
		counts[Game.seeds[id].tag] += 1
	print("your seeds by tag: ", counts)
	var rank_order := { 4: ["bountiful", "farmable", "not_farmable"], 5: ["farmable", "bountiful", "not_farmable"], 6: ["not_farmable", "bountiful", "farmable"] }
	for mode in [4, 5, 6]:
		panel._sort.select(mode)
		panel._filter.select(0)
		panel.refresh_seeds()
		var want: Array = rank_order[mode]
		var ok := list.item_count == Game.seeds.size()
		var last := -1
		for i in list.item_count:
			var r: int = want.find(tag_of.call(i))
			ok = ok and r >= last  # tags only ever move forward through the order
			last = r
		var first_tag: String = tag_of.call(0) if counts[want[0]] > 0 else want[0]
		_check("sort '%s': %s seeds first, then %s, then %s (first is %s)" % [panel._sort.get_item_text(mode), want[0], want[1], want[2], first_tag], ok and first_tag == want[0])
	for f in [1, 2, 3]:
		panel._filter.select(f)
		panel._sort.select(2)
		panel.refresh_seeds()
		var only: String = Game.TAGS[f - 1]
		var all_match := true
		for i in list.item_count:
			all_match = all_match and tag_of.call(i) == only
		_check("filter '%s' lists exactly those seeds (%d of %d)" % [panel._filter.get_item_text(f), list.item_count, counts[only]], all_match and list.item_count == counts[only])
	panel._filter.select(0)
	panel._sort.select(0)
	panel.refresh_seeds()
	_check("back to all tags: everything listed (%d)" % list.item_count, list.item_count == Game.seeds.size())
	# search still combines with the filter
	panel._filter.select(3)
	panel._search.text = "e"
	panel.refresh_seeds()
	var combo_ok := true
	for i in list.item_count:
		combo_ok = combo_ok and tag_of.call(i) == "bountiful" and String(Game.seeds[list.get_item_metadata(i)].name).to_lower().contains("e")
	_check("filter + search work together (%d shown)" % list.item_count, combo_ok)
	panel._search.text = ""
	panel._filter.select(3)
	panel._sort.select(4)
	panel.refresh_seeds()
	await _snap(base + "/t7_filter.png")
	panel._filter.select(0)
	panel._sort.select(5)
	panel.refresh_seeds()
	await _snap(base + "/t7_sort.png")
	panel._sort.select(0)
	panel.refresh_seeds()


## Categories: logic, old saves, agree / change / undo, the tab, export. WRITES TO YOUR SAVE.
func _run_test13(base: String) -> void:
	var expect := {
		"Dirt Seed": ["soil", 2], "Stone Seed": ["stone", 4], "Magma Rock Seed": ["fire", 2], "Glowing Mushroom Seed": ["mushroom", 1],
		"Lava Seed": ["fire", 2], "Cave Background Seed": ["background", 1], "Glass Seed": ["crystal", 2], "Quartz  Seed": ["crystal", 4],
		"Obsidian Seed": ["stone", 5], "Wood Seed": ["wood", 3], "Door Seed": ["wood", 3], "Bucket Seed": ["metal", 4],
		"Well Seed": ["object", 2], "Grass Seed": ["plant", 1], "Deathcap Seed": ["mushroom", 1], "Blueberry Seed": ["plant", 1],
		"Sandstone Seed": ["stone", 4], "Gravel Seed": ["stone", 2], "Sand Seed": ["soil", 2], "Cobblestone Seed": ["stone", 4],
		"Purple Block Seed": ["building", 3], "Glowstone Stone Seed": ["stone", 4], "Iron Ore Seed": ["metal", 4],
		"Cinder Soil Seed": ["soil", 2], "Pumice Seed": ["stone", 2], "Cavern Seed": ["stone", 4], "Hedge Seed": ["plant", 1],
		"Torch Seed": ["light", 1], "Water Seed": ["liquid", 1], "Mystery Seed": ["other", 3], "Diamond Seed": ["crystal", 5],
		"Lapis Lazuli Seed": ["crystal", 3], "Venus Flytrap Seed": ["plant", 1], "Prison Bars Seed": ["metal", 4],
		"Traffic Cone Seed": ["object", 2], "Lime Block Seed": ["building", 3], "Asphalt Seed": ["stone", 4],
		"Fertilizer Seed": ["soil", 2], "Charcoal Seed": ["wood", 3], "Spike Seed": ["metal", 4],
	}
	var bad: Array = []
	for n in expect:
		var c := CategoryLogic.classify(n, DropLogic.classify(n))
		if c.material != expect[n][0] or c.hardness != expect[n][1] or c.status != "auto":
			bad.append("%s -> %s" % [n, CategoryLogic.describe(c)])
	_check("category guesses for %d names %s" % [expect.size(), str(bad)], bad.is_empty())

	# an old (version 5) save without categories gets them when it loads
	Game.reset()
	var look := { "name": "Iron Ore Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00", "pattern_seed": 1 }
	var iron := Game.add_spliced_seed("dirt", "stone", look)
	look.name = "Blueberry Seed"
	var berry := Game.add_spliced_seed("dirt", "glowing_mushroom", look)
	Game.save_game()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	raw.version = 5
	for s in raw.seeds:
		s.erase("category")
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	Game.load_game()
	_check("old save: every seed has a category (Iron Ore = %s)" % CategoryLogic.describe(Game.seeds[iron].category),
		Game.order.all(func(id): return Game.seeds[id].has("category")) and Game.seeds[iron].category.material == "metal")

	# agree, change, undo
	Game.agree_category(iron, true)
	_check("tick OK: the guess is kept (agreed)", Game.seeds[iron].category.status == "agreed" and Game.seeds[iron].category.material == "metal")
	Game.update_look(iron, { "name": "Wooden Ore Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00", "pattern_seed": 1, "tag": "farmable" })
	_check("an agreed category stays when you rename", Game.seeds[iron].category.material == "metal")
	Game.set_category(berry, "wood", 5)
	_check("pick another material/hardness: it's changed and kept", Game.seeds[berry].category == { "material": "wood", "hardness": 5, "status": "changed" })
	Game.agree_category(berry, false)
	_check("untick OK: back to the guess (Blueberry = %s)" % CategoryLogic.describe(Game.seeds[berry].category),
		Game.seeds[berry].category == { "material": "plant", "hardness": 1, "status": "auto" })
	Game.update_look(berry, { "name": "Iron Berry Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00", "pattern_seed": 1, "tag": "farmable" })
	_check("a guess follows a rename (Iron Berry = %s)" % CategoryLogic.describe(Game.seeds[berry].category), Game.seeds[berry].category.material == "metal")
	Game.load_game()
	_check("agreed and changed survive loading", Game.seeds[iron].category.status == "agreed")

	# the tab
	var panel: SidePanel = main.panel
	var tab: CategoriesTab = panel.categories
	tab.refresh()
	var rows := 0
	var groups := 0
	var g := tab._tree.get_root().get_first_child()
	while g:
		groups += 1
		rows += g.get_child_count()
		g = g.get_next()
	_check("Categories tab lists every seed (%d rows in %d material groups)" % [rows, groups], rows == Game.seeds.size())
	tab._group.select(CategoriesTab.GROUP_HARDNESS)
	tab.refresh()
	var first_group := tab._tree.get_root().get_first_child().get_text(0)
	_check("group by hardness starts with the hardest: '%s'" % first_group, first_group.begins_with("4 Hard") or first_group.begins_with("5"))
	tab._show.select(CategoriesTab.SHOW_GUESSES)
	tab.refresh()
	var guesses: int = Game.category_summary().auto
	_check("'still guesses' shows %d seeds" % tab._shown_ids.size(), tab._shown_ids.size() == guesses)
	Game.agree_categories(tab._shown_ids, true)
	_check("'Agree to all shown' leaves no guesses: " + tab._summary.text, Game.category_summary().auto == 0 and tab._summary.text.contains("0 still guesses"))
	tab._show.select(CategoriesTab.SHOW_ALL)
	tab._group.select(CategoriesTab.GROUP_MATERIAL)
	Game.agree_category("dirt", false)
	panel._tabs.current_tab = 1
	await _snap(base + "/t13_tab.png")
	panel._tabs.current_tab = 0

	# export reference
	var path := base + "/export_cat.json"
	Game.export_list(path)
	var ex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check("export carries categories + the hardness -> MushMantle hits guide", ex.seeds.all(func(s): return s.has("category")) and String(ex.reference.categories.mushmantle_hits).contains("Obsidian 12"))
	DirAccess.remove_absolute(path)


## Recipe Tree: unlimited zoom out, magnifier, splice math. WRITES TO YOUR SAVE.
func _run_test12(base: String) -> void:
	Game.reset()
	var look := { "name": "Gravel Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00", "pattern_seed": 1 }
	var gravel := Game.add_spliced_seed("dirt", "stone", look)
	look.name = "Obsidian Seed"
	var obs := Game.add_spliced_seed(gravel, "magma_rock", look)
	look.name = "Crystal Seed"
	var crystal := Game.add_spliced_seed(obs, "glowing_mushroom", look)
	look.name = "Big Seed"
	var big := Game.add_spliced_seed(crystal, gravel, look)  # needs Gravel twice
	var rt: RecipeTree = main.recipe_tree
	rt.open(crystal)
	await get_tree().create_timer(0.4).timeout
	var c: RecipeTree.TreeCanvas = rt._canvas
	var m := c.math()
	_check("Crystal math %s: 3 splices, 3 recipes, chain of 3, 4 Tier 1" % str(m), m.splices == 3 and m.different == 3 and m.longest == 3 and m.tier1 == 4)
	_check("math line: " + rt._math.text, rt._math.text.contains("3 splices") and rt._math.text.contains("3 different recipes"))
	rt.show_seed(big)
	m = c.math()
	_check("Big Seed math %s: Gravel needed twice -> 5 splices but 4 recipes, chain 4, 6 Tier 1" % str(m), m.splices == 5 and m.different == 4 and m.longest == 4 and m.tier1 == 6)
	var root_node: Dictionary = c.tree
	_check("each seed knows its own splice count (Big: %d, Crystal: %d)" % [root_node.splices, root_node.kids[0].splices], root_node.splices == 5 and root_node.kids[0].splices == 3)
	rt.show_seed("dirt")
	_check("Tier 1 math: " + rt._math.text, rt._math.text.contains("no splicing needed"))
	rt.show_seed(big)
	await get_tree().create_timer(0.2).timeout
	# zoom out, way past the old limit
	for i in 60:
		c._zoom_at(c.size / 2.0, 1.0 / 1.12)
	_check("zooms out as far as you like (zoom %.3f, old limit was 0.3)" % c.zoom, c.zoom <= 0.011)
	await _snap(base + "/t12_tiny.png")
	c.zoom = 0.25
	c.pan = c.size / 2.0 - Vector2(float(c.tree.x), 250.0) * 0.25
	c.queue_redraw()
	var mouse := c.size / 2.0 + Vector2(-60, 40)
	c.update_lens(mouse)
	var lens_rect := Rect2(c.lens.global_position, c.lens.size)
	var tree_rect := Rect2(c.global_position, c.size)
	_check("magnifier is docked bottom right, beside the tree (%s)" % str(lens_rect),
		rt._lens_box.visible and lens_rect.position.x >= tree_rect.end.x - 1.0 and lens_rect.end.y >= tree_rect.end.y - 20.0)
	_check("it shows what's under the cursor", c.lens.has_target and c.lens.world_center.is_equal_approx(c._to_world(mouse)))
	await _snap(base + "/t12_lens.png")
	c.update_lens(Vector2(-50, -50))
	_check("cursor off the tree: it shows a hint instead", not c.lens.has_target)
	rt._lens_toggle.button_pressed = false
	c.update_lens(mouse)
	_check("the Magnifier checkbox hides it", not rt._lens_box.visible and not c.lens.has_target)
	rt._lens_toggle.button_pressed = true
	rt.close_menu()


## Audio: music plays, events make sounds, Sound menu settings stick. WRITES TO YOUR SETTINGS.
func _run_test11(base: String) -> void:
	_check("music is playing: '%s'" % Audio.current_title(), Audio.is_music_playing() and Audio.current_title() != "")
	var all_load := true
	for e in Audio.EVENTS:
		all_load = all_load and Audio._stream(Audio.SFX_DIR + String(e) + ".ogg") != null
	for m in Audio.MUSIC:
		all_load = all_load and Audio._stream(Audio.MUSIC_DIR + m.file) != null
	_check("all %d sound effects and %d songs load" % [Audio.EVENTS.size(), Audio.MUSIC.size()], all_load)
	var on_disk := DirAccess.get_files_at(Audio.SFX_DIR)
	var oggs: Array = Array(on_disk).filter(func(f): return f.ends_with(".ogg"))
	_check("only the used sounds are in the game (%d .ogg files)" % oggs.size(), oggs.size() == Audio.EVENTS.size())
	for e in Audio.EVENTS:
		Audio.play(e)
	_check("game events play sounds", Audio.is_sfx_playing())
	# a real action: dropping a seed on itself plays the error sound path, a known splice plays splice
	var field: VoidField = main.field
	field.try_splice(field.spawn_near_center("dirt"), field.spawn_near_center("dirt"))
	_check("same-seed splice -> sound", Audio.is_sfx_playing())
	# Sound menu
	var sd: SoundDialog = main.sound_dialog
	sd.open()
	await get_tree().create_timer(0.3).timeout
	_check("Sound menu opens and shows the song: '%s'" % sd._now.text, sd.visible and sd._now.text.contains(Audio.current_title()))
	sd._music_slider.value = 0.3
	_check("music volume slider changes the Music bus", is_equal_approx(Audio.music_volume, 0.3) and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.3)) < 0.01)
	sd._track.select(3)
	sd._track.item_selected.emit(3)
	await get_tree().create_timer(0.2).timeout
	_check("'Only: %s' plays that song" % Audio.MUSIC[2].title, Audio.current_title() == Audio.MUSIC[2].title and Audio.track_choice == 2)
	sd._music_slider.value = 0.0
	_check("music volume 0 mutes the music", AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	sd._music_slider.value = 0.55
	await _snap(base + "/t11_sound.png")
	# put things back
	Audio.set_track_choice(Audio.SHUFFLE)
	sd.visible = false


## Import picker: yes/no per seed. WRITES TO YOUR SAVE.
func _run_test10(base: String) -> void:
	# a friend's list: Gravel (R2) -> Obsidian (R3) -> Crystal (R4), plus their own tier 1 Moss
	Game.reset()
	var look := { "name": "Gravel Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00", "pattern_seed": 1 }
	var gravel := Game.add_spliced_seed("dirt", "stone", look)
	look.name = "Obsidian Seed"
	var obs := Game.add_spliced_seed(gravel, "magma_rock", look)
	look.name = "Crystal Seed"
	Game.add_spliced_seed(obs, "glowing_mushroom", look)
	look.name = "Pebble Seed"  # same splice as my "Shiny Rock" below, different name
	Game.add_spliced_seed("stone", "glowing_mushroom", look)
	Game.add_custom_seed({ "name": "Moss Seed", "pattern": 1, "colors": ["#33aa33", "#226622"], "sprout": "#00ff00", "pattern_seed": 3, "tag": "bountiful" })
	var path := base + "/friend_list.json"
	Game.export_list(path)

	# me: the starting seeds plus my own Gravel (made a different way)
	Game.reset()
	look.name = "Gravel Seed"
	var my_gravel := Game.add_spliced_seed("dirt", "magma_rock", look)
	var my_gravel_tag: String = Game.seeds[my_gravel].tag
	look.name = "Shiny Rock Seed"
	var my_shiny := Game.add_spliced_seed("stone", "glowing_mushroom", look)
	var before := Game.seeds.size()

	var preview := Game.read_import(path)
	var offered: Array = preview.new_seeds.map(func(n): return n.seed.name)
	offered.sort()
	_check("preview offers only seeds I don't have: %s (and changes nothing)" % str(offered), offered == ["Crystal Seed", "Moss Seed", "Obsidian Seed", "Pebble Seed"] and Game.seeds.size() == before)
	var id_of := {}
	var clash_of := {}
	for n in preview.new_seeds:
		id_of[n.seed.name] = n.their_id
		clash_of[n.seed.name] = n.clash
	_check("cross-check: Pebble's recipe (Stone + Glowing Mushroom) already makes my Shiny Rock", clash_of["Pebble Seed"] == my_shiny and clash_of["Crystal Seed"] == "")

	var picker: ImportDialog = main.import_picker
	main._on_import_path(path)
	await get_tree().create_timer(0.3).timeout
	_check("Import List opens the picker: everything ticked except the clashing Pebble (%s)" % picker._ok.text,
		picker.visible and picker.chosen().size() == 3 and not picker._rows[id_of["Pebble Seed"]].check.button_pressed)
	await _snap(base + "/t10_clash.png")
	# no to Obsidian and Moss, yes to Crystal
	picker._rows[id_of["Obsidian Seed"]].check.button_pressed = false
	picker._rows[id_of["Moss Seed"]].check.button_pressed = false
	var crystal_needs: Label = picker._rows[id_of["Crystal Seed"]].needs
	_check("Crystal warns it needs Obsidian: '%s'" % crystal_needs.text, crystal_needs.visible and crystal_needs.text.contains("Obsidian Seed"))
	await _snap(base + "/t10_picker.png")
	picker._take_needed()
	_check("'Also take what they need' ticks Obsidian back (not Moss)", picker._rows[id_of["Obsidian Seed"]].check.button_pressed and not picker._rows[id_of["Moss Seed"]].check.button_pressed and not crystal_needs.visible)
	var expect_splices := Game.import_recipe_count(main._pending_import, picker.chosen())
	_check("summary: " + picker._summary.text, picker._summary.text.contains("2 of 4 seeds"))
	picker._confirm()
	await get_tree().create_timer(0.3).timeout
	var crystal := Game.find_by_name("Crystal Seed")
	var obs2 := Game.find_by_name("Obsidian Seed")
	_check("only the yes seeds came in (Crystal + Obsidian, no Moss)", crystal != "" and obs2 != "" and Game.find_by_name("Moss Seed") == "" and Game.seeds.size() == before + 2)
	_check("their splices came with them (%d, preview said %d)" % [Game.recipes.size() - 2, expect_splices], Game.result_of(obs2, "glowing_mushroom") == crystal and Game.recipes.size() - 2 == expect_splices)
	_check("rarity redone with my seeds: Crystal R%d" % int(Game.seeds[crystal].rarity), int(Game.seeds[crystal].rarity) == 4)
	_check("my own Gravel is untouched", Game.seeds[my_gravel].tag == my_gravel_tag and Game.seeds[my_gravel].parents == ["dirt", "magma_rock"])

	# importing the same file again: only Moss is still new; cancelling adds nothing
	var n_before := Game.seeds.size()
	var r_before := Game.recipes.size()
	main._on_import_path(path)
	await get_tree().create_timer(0.2).timeout
	_check("second time only Moss and Pebble are offered", picker.visible and picker._rows.size() == 2)
	picker._cancel()
	_check("Cancel adds nothing", Game.seeds.size() == n_before and Game.recipes.size() == r_before and Game.find_by_name("Moss Seed") == "")
	# saying yes to Pebble anyway: it comes in, but MY recipe still makes Shiny Rock
	var r_peb := Game.apply_import(Game.read_import(path), [id_of["Pebble Seed"]])
	var peb := Game.find_by_name("Pebble Seed")
	_check("my recipe wins: Stone + Glowing Mushroom still makes Shiny Rock (kept %d)" % r_peb.recipes_kept_yours,
		Game.result_of("stone", "glowing_mushroom") == my_shiny and r_peb.recipes_kept_yours == 1)
	_check("the imported Pebble doesn't claim my recipe (no parents, no recipe, their rarity R%d)" % int(Game.seeds[peb].rarity),
		peb != "" and Game.seeds[peb].parents.is_empty() and Game.recipes_for(peb).is_empty() and int(Game.seeds[peb].rarity) == 2)
	_check("and my Shiny Rock still has its recipe", Game.recipes_for(my_shiny) == [["stone", "glowing_mushroom"]])
	# keeping a seed but saying no to what it's made from: it comes in without that recipe
	Game.reset()
	var p2 := Game.read_import(path)
	var only_crystal: Array = p2.new_seeds.filter(func(n): return n.seed.name == "Crystal Seed").map(func(n): return n.their_id)
	var r := Game.apply_import(p2, only_crystal)
	var c2 := Game.find_by_name("Crystal Seed")
	_check("a seed without its ingredients still comes in, keeping their rarity (R%d) and no recipe" % int(Game.seeds[c2].rarity),
		r.seeds_added == 1 and int(Game.seeds[c2].rarity) == 4 and Game.recipes_for(c2).is_empty())
	DirAccess.remove_absolute(path)


## Drops: logic, old-save sorting, sort/filter, editor, export reference. WRITES TO YOUR SAVE.
func _run_test9(base: String) -> void:
	# --- the logic, on your kinds of names
	var expect := {
		"Dirt Seed": ["block", true, false], "Stone Seed": ["block", true, false],
		"Magma Rock Seed": ["block", true, true], "Lava Seed": ["block", true, true],
		"Glowing Mushroom Seed": ["decoration", false, false], "Cave Background Seed": ["decoration", false, false],
		"Stone Background Seed": ["decoration", false, false], "Door Seed": ["decoration", false, false],
		"Bucket Seed": ["decoration", false, false], "Well Seed": ["decoration", false, false],
		"Wheat Seed": ["decoration", false, false], "Grass Seed": ["decoration", false, false],
		"Glass Seed": ["block", true, false], "Quartz  Seed": ["block", true, false],
		"Cactus Seed": ["block", true, true], "Chest Seed": ["decoration", true, false],
		"Water Seed": ["block", false, false], "Sunflower Seed": ["decoration", false, false],
		"Bedrock Seed": ["block", true, false], "Thornbush Seed": ["block", true, true],
		"Firefly Seed": ["decoration", false, false], "Vegetable Seed": ["block", true, false],
		"Spike Trap Seed": ["block", true, true], "Cinder Soil Seed": ["block", true, false],
		"Deathcap Seed": ["decoration", true, true], "Blueberry Seed": ["decoration", false, false],
		"Yam Seed": ["decoration", false, false], "Hedge Seed": ["block", true, false], "Dust Seed": ["block", true, false],
		"Spore Background Seed": ["decoration", false, false], "Bush Seed": ["decoration", false, false],
	}
	var bad: Array = []
	for n in expect:
		var d := DropLogic.classify(n)
		var e: Array = expect[n]
		if d.kind != e[0] or d.collision != e[1] or d.damage != e[2] or not d.auto:
			bad.append("%s -> %s" % [n, DropLogic.describe(d)])
	_check("logic sorts %d names as expected %s" % [expect.size(), str(bad)], bad.is_empty())
	var s1 := DropLogic.sanitize({ "kind": "decoration", "collision": false, "damage": true, "auto": false }, "x")
	_check("damage always comes with collision", s1.collision and s1.damage and not s1.auto)
	_check("a broken drop falls back to the logic", DropLogic.sanitize("nonsense", "Lava Seed").damage)

	# --- an old (version 4) save without drops gets sorted when it loads; a hand-set drop survives
	Game.reset()
	var look := { "name": "Lava Pearl Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00", "pattern_seed": 1 }
	var pearl := Game.add_spliced_seed("dirt", "magma_rock", look)
	look.name = "Bucket Seed"
	var bucket := Game.add_spliced_seed("stone", "glowing_mushroom", look)
	Game.save_game()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	raw.version = 4
	for s in raw.seeds:
		s.erase("drop")
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	Game.drop_report = {}
	Game.load_game()
	var all_have := Game.order.all(func(id): return typeof(Game.seeds[id].get("drop")) == TYPE_DICTIONARY)
	_check("old save: every seed got a drop (report %s)" % str(Game.drop_report), all_have and Game.drop_report.get("total", 0) == Game.seeds.size())
	_check("Lava Pearl -> collision damage, Bucket -> decoration without collision",
		Game.seeds[pearl].drop.damage and Game.seeds[bucket].drop.kind == "decoration" and not Game.seeds[bucket].drop.collision)
	Game.update_look(bucket, { "name": "Bucket Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00",
		"pattern_seed": 1, "tag": "farmable", "drop": { "kind": "decoration", "collision": true, "damage": false, "auto": false } })
	Game.drop_report = {}
	Game.load_game()
	_check("a drop you set by hand is kept when loading (and nothing is re-sorted)", Game.seeds[bucket].drop.collision and not Game.seeds[bucket].drop.auto and Game.drop_report.is_empty())

	# --- sort + filter by collision in the Seeds panel
	var panel: SidePanel = main.panel
	var list: ItemList = panel._list
	panel._filter.select(0)
	panel._search.text = ""
	var col_of := func(i: int) -> Dictionary: return Game.seeds[list.get_item_metadata(i)].drop
	panel._drop_filter.select(0)
	panel._sort.select(SeedSort.COLLISION_FIRST)
	panel.refresh_seeds()
	var ok_c := true
	var seen_no := false
	for i in list.item_count:
		var c: bool = col_of.call(i).collision
		if not c:
			seen_no = true
		ok_c = ok_c and not (c and seen_no)
	_check("'Collision first' puts every seed with collision before those without", ok_c)
	panel._sort.select(SeedSort.DAMAGE_FIRST)
	panel.refresh_seeds()
	_check("'Collision damage first' starts with damaging drops", col_of.call(0).damage)
	for fi in [SeedSort.DROP_COLLISION, SeedSort.DROP_NO_COLLISION, SeedSort.DROP_DAMAGE, SeedSort.DROP_BLOCKS, SeedSort.DROP_DECORATIONS]:
		panel._drop_filter.select(fi)
		panel.refresh_seeds()
		var want := Game.order.filter(func(id):
			var d: Dictionary = Game.seeds[id].drop
			match fi:
				SeedSort.DROP_COLLISION: return d.collision
				SeedSort.DROP_NO_COLLISION: return not d.collision
				SeedSort.DROP_DAMAGE: return d.damage
				SeedSort.DROP_BLOCKS: return d.kind == "block"
			return d.kind == "decoration").size()
		_check("filter '%s' lists %d (want %d)" % [panel._drop_filter.get_item_text(fi), list.item_count, want], list.item_count == want)
	panel._drop_filter.select(0)
	panel._sort.select(SeedSort.NEWEST)
	panel.refresh_seeds()
	_check("list rows show the drop: '%s'" % list.get_item_text(0).replace("\n", " / "), list.get_item_text(0).contains("ollision"))

	# --- the editor
	var popup: SplicePopup = main.popup
	var field: VoidField = main.field
	field.clear()
	await get_tree().create_timer(0.2).timeout
	field.try_splice(field.spawn_near_center("stone"), field.spawn_near_center("magma_rock"))
	await get_tree().create_timer(0.3).timeout
	popup._name_edit.text = "Spike Wall Seed"
	popup._on_name_changed("Spike Wall Seed")
	_check("new splice: drop follows the name (Spike Wall -> collision damage)", popup.look.drop.damage and popup.look.drop.auto and popup._damage_btn.button_pressed)
	popup._name_edit.text = "Glow Lantern Seed"
	popup._on_name_changed("Glow Lantern Seed")
	_check("rename -> Glow Lantern is a decoration without collision", popup.look.drop.kind == "decoration" and not popup.look.drop.collision and not popup._collision_btn.button_pressed)
	popup._set_collision(true)
	popup._name_edit.text = "Glow Lantern Seed"
	popup._on_name_changed("Lava Lantern Seed")
	_check("once you set it, renaming doesn't change it", popup.look.drop.collision and not popup.look.drop.damage and not popup.look.drop.auto)
	popup._set_damage(true)
	_check("collision damage on -> collision on", popup.look.drop.damage and popup.look.drop.collision)
	popup._set_collision(false)
	_check("collision off -> collision damage off", not popup.look.drop.damage and not popup.look.drop.collision)
	popup._set_damage(true)
	await _snap(base + "/t9_popup.png")
	popup._confirm()
	await get_tree().create_timer(0.5).timeout
	var made := Game.result_of("stone", "magma_rock")
	_check("the new seed keeps the drop you set", made != "" and Game.seeds[made].drop.damage and Game.seeds[made].drop.collision and not Game.seeds[made].drop.auto)
	popup.open_edit(made)
	_check("editing shows the drop buttons", popup._damage_btn.button_pressed and not popup._damage_btn.disabled)
	popup._cancel()

	# --- export carries the reference; import keeps drops
	var path := base + "/export_drops.json"
	_check("export ok", Game.export_list(path) == OK)
	var ex: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var rules: Array = ex.reference.IMPORTANT_RULES
	_check("export reference says seeds never deal damage: \"%s...\"" % String(rules[0]).left(60), String(rules[0]).begins_with("SEEDS THEMSELVES DO NOT DEAL DAMAGE"))
	_check("export reference maps collision/damage to MushMantle", String(ex.reference.mushmantle_mapping.damage).contains("BLK_LAVA") and ex.reference.drop_logic.words.danger_words.has("lava"))
	_check("every exported seed has its drop", ex.seeds.all(func(s): return typeof(s.get("drop")) == TYPE_DICTIONARY))
	Game.reset()
	var r := Game.import_list(path)
	var made2 := Game.find_by_name(Game.seeds.get(made, {}).get("name", "Lava Lantern Seed"))
	if made2 == "":
		made2 = Game.find_by_name("Lava Lantern Seed")
	_check("import keeps the hand-set drop (%s)" % str(r), made2 != "" and Game.seeds[made2].drop.damage and not Game.seeds[made2].drop.auto)
	DirAccess.remove_absolute(path)
	await _snap(base + "/t9_panel.png")


## Recipe Tree list: sort by tag / rarity / name, tag filter (reads your save, writes nothing).
func _run_test8(base: String) -> void:
	var rt: RecipeTree = main.recipe_tree
	rt.open()
	await get_tree().create_timer(0.3).timeout
	var counts := { "farmable": 0, "not_farmable": 0, "bountiful": 0 }
	for id in Game.order:
		counts[Game.seeds[id].tag] += 1
	var rank_order := { 4: ["bountiful", "farmable", "not_farmable"], 5: ["farmable", "bountiful", "not_farmable"], 6: ["not_farmable", "bountiful", "farmable"] }
	for mode in [4, 5, 6]:
		rt._sort.select(mode)
		rt._filter.select(0)
		rt._refresh_list()
		var want: Array = rank_order[mode]
		var ok: bool = rt._list_ids.size() == Game.seeds.size()
		var last := -1
		for id in rt._list_ids:
			var r: int = want.find(Game.seeds[id].tag)
			ok = ok and r >= last
			last = r
		_check("tree sort '%s' groups %s, %s, %s" % [rt._sort.get_item_text(mode), want[0], want[1], want[2]], ok and Game.seeds[rt._list_ids[0]].tag == want[0])
	rt._sort.select(SeedSort.RARITY)
	rt._refresh_list()
	var desc := true
	for i in range(1, rt._list_ids.size()):
		desc = desc and int(Game.seeds[rt._list_ids[i - 1]].rarity) >= int(Game.seeds[rt._list_ids[i]].rarity)
	_check("tree sort 'Rarity' goes highest to lowest", desc)
	rt._sort.select(SeedSort.NAME)
	rt._refresh_list()
	var alpha := true
	for i in range(1, rt._list_ids.size()):
		alpha = alpha and String(Game.seeds[rt._list_ids[i - 1]].name).naturalnocasecmp_to(Game.seeds[rt._list_ids[i]].name) <= 0
	_check("tree sort 'Name' is alphabetical (the default)", alpha)
	rt._sort.select(SeedSort.NEWEST)
	rt._refresh_list()
	var rev := Game.order.duplicate()
	rev.reverse()
	_check("tree sort 'Newest' is newest first", rt._list_ids == rev)
	for f in [1, 2, 3]:
		rt._filter.select(f)
		rt._refresh_list()
		var only: String = Game.TAGS[f - 1]
		var all_match := true
		for id in rt._list_ids:
			all_match = all_match and Game.seeds[id].tag == only
		_check("tree filter '%s' lists %d of %d, label '%s'" % [rt._filter.get_item_text(f), rt._list_ids.size(), counts[only], rt._count.text], all_match and rt._list_ids.size() == counts[only])
	# clicking a seed in the filtered list still opens its tree
	rt._on_list_selected(0)
	_check("clicking a filtered seed opens its tree", rt.root_id == rt._list_ids[0])
	rt._sort.select(SeedSort.BOUNTIFUL_FIRST)
	rt._filter.select(0)
	rt._refresh_list()
	await _snap(base + "/t8_tree_sort.png")
	rt._sort.select(SeedSort.NAME)
	rt._filter.select(0)
	rt._refresh_list()
	rt.close_menu()


## The farmable roll: odds, one-time reroll, pending rolls, popup. WRITES TO YOUR SAVE.
func _run_test6(base: String) -> void:
	# --- odds, measured over a lot of rolls
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for rarity in [2, 10, 11, 40]:
		var n := 200000
		var c := { "farmable": 0, "not_farmable": 0, "bountiful": 0 }
		for i in n:
			c[Game.roll_tag(rarity, rng)] += 1
		var nf := 0.5 if rarity <= 10 else 0.75
		var f := (1.0 - nf) * 0.75
		var b := (1.0 - nf) * 0.25
		var ok: bool = absf(c.not_farmable / float(n) - nf) < 0.006 and absf(c.farmable / float(n) - f) < 0.006 and absf(c.bountiful / float(n) - b) < 0.006
		_check("rarity %d odds: not farmable %.1f%% / farmable %.1f%% / bountiful %.1f%% (want %.0f / %.2f / %.2f)" % [
			rarity, 100.0 * c.not_farmable / n, 100.0 * c.farmable / n, 100.0 * c.bountiful / n, nf * 100, f * 100, b * 100], ok)
	_check("odds text r5: " + Game.tag_odds_text(5), Game.tag_odds_text(5) == "50% Not Farmable  ·  37.5% Farmable  ·  12.5% Bountiful")
	_check("odds text r16: " + Game.tag_odds_text(16), Game.tag_odds_text(16) == "75% Not Farmable  ·  18.75% Farmable  ·  6.25% Bountiful")

	# --- the one-time reroll: rarity 1 untouched, everything else gets a valid roll
	Game.reset()
	var look := { "name": "A Seed", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00", "pattern_seed": 1, "tag": "farmable" }
	var prev := "dirt"
	for i in 40:  # a long chain, so there are rarities above 10 too
		look.name = "Chain %d Seed" % i
		var other: String = ["stone", "magma_rock", "glowing_mushroom"][i % 3]
		prev = Game.add_spliced_seed(prev, other, look)
	var custom := Game.add_custom_seed({ "name": "Mine Seed", "pattern": 0, "colors": ["#111111", "#222222"], "sprout": "#00ff00", "pattern_seed": 1, "tag": "not_farmable" })
	for id in Game.order:
		Game.seeds[id].tag = "farmable"  # pretend everything is farmable (the old state)
	Game.seeds.dirt.tag = "bountiful"
	var rep := Game.reroll_all()
	var base_ok: bool = Game.seeds.dirt.tag == "bountiful" and Game.seeds.stone.tag == "farmable" and Game.seeds[custom].tag == "farmable"
	_check("rarity 1 seeds keep their tag through a reroll", base_ok)
	var changed := 0
	var valid := true
	var top := 0
	for id in Game.order:
		var s: Dictionary = Game.seeds[id]
		if int(s.rarity) > 1:
			valid = valid and Game.TAGS.has(s.tag)
			top = maxi(top, int(s.rarity))
			if s.tag != "farmable":
				changed += 1
	_check("every seed above rarity 1 was rerolled (%d of %d now differ; top rarity %d)" % [changed, rep.total, top], valid and rep.total == 40 and changed > 10 and top > 10)
	_check("report adds up: " + str(rep.counts), rep.counts.farmable + rep.counts.not_farmable + rep.counts.bountiful == rep.total)

	# --- loading an old (version 3) save rerolls once; a version 4 save doesn't
	for id in Game.order:
		Game.seeds[id].tag = "farmable"
	Game.save_game()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	raw.version = 3
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	Game.reroll_report = {}
	Game.load_game()
	var diff_v3 := Game.seeds.values().filter(func(s): return int(s.rarity) > 1 and s.tag != "farmable").size()
	_check("loading a version 3 save rerolls it (%d changed, report %s)" % [diff_v3, str(Game.reroll_report.get("total", 0))], diff_v3 > 10 and Game.reroll_report.get("total", 0) == 40)
	var tags_after: Array = Game.order.map(func(id): return Game.seeds[id].tag)
	Game.reroll_report = {}
	Game.load_game()  # the file was saved as version 4 by the reroll
	var tags_again: Array = Game.order.map(func(id): return Game.seeds[id].tag)
	_check("loading it again does NOT reroll again", tags_after == tags_again and Game.reroll_report.is_empty())

	# --- a new splice: rolled once per pair, same answer if you cancel and try again, and not changeable
	Game.reset()
	var p1 := Game.tag_roll_for("dirt", "stone")
	var same := true
	for i in 30:
		same = same and Game.tag_roll_for("stone", "dirt") == p1
	_check("cancel-and-retry shows the same roll (%s)" % p1, same)
	var seen := {}
	for i in 60:
		Game.pending_rolls.clear()
		seen[Game.tag_roll_for("dirt", "stone")] = true
	_check("(different pairs / fresh rolls do vary: saw %s)" % str(seen.keys()), seen.size() >= 2)
	Game.pending_rolls.clear()
	var popup: SplicePopup = main.popup
	var field: VoidField = main.field
	field.clear()
	await get_tree().create_timer(0.2).timeout
	field.try_splice(field.spawn_near_center("dirt"), field.spawn_near_center("stone"))
	await get_tree().create_timer(0.3).timeout
	var shown_tag: String = popup.look.tag
	_check("popup hides the tag buttons and shows the roll: " + popup._tag_roll.text, popup.visible and not popup._tag_row.visible and popup._tag_roll.visible and popup._tag_roll.text.contains(Game.tag_name(shown_tag)))
	_check("popup shows the odds: " + popup._tag_odds.text, popup._tag_odds.visible and popup._tag_odds.text.contains("50% Not Farmable"))
	await _snap(base + "/t6_popup.png")
	popup._set_tag("bountiful")  # even if something tried to force a tag, the roll wins
	popup._confirm()
	await get_tree().create_timer(0.5).timeout
	var made := Game.result_of("dirt", "stone")
	_check("the new seed got the roll (%s), nothing else" % shown_tag, Game.seeds[made].tag == shown_tag and Game.pending_rolls.is_empty())
	# editing afterwards still lets you change it
	popup.open_edit(made)
	_check("editing an existing seed still shows the tag buttons", popup._tag_row.visible and not popup._tag_roll.visible)
	popup._cancel()
	# tier 1 seeds you add: your choice, never rolled
	popup.open_add()
	_check("Add Seed still lets you pick the tag", popup._tag_row.visible and not popup._tag_roll.visible)
	popup._cancel()


## Recipe tree: chain layout, alternate recipes, loops. WRITES TO YOUR SAVE.
func _run_test5(base: String) -> void:
	var rt: RecipeTree = main.recipe_tree
	Game.reset()
	var look := { "name": "x", "pattern": 0, "colors": ["#ff0000", "#00ff00"], "sprout": "#00ff00", "pattern_seed": 1, "tag": "farmable" }
	look.name = "Gravel Seed"
	var gravel := Game.add_spliced_seed("dirt", "stone", look)
	look.name = "Obsidian Seed"
	var obs := Game.add_spliced_seed(gravel, "magma_rock", look)
	look.name = "Crystal Seed"
	var crystal := Game.add_spliced_seed(obs, "glowing_mushroom", look)
	rt.open(crystal)
	await get_tree().create_timer(0.4).timeout
	var c: RecipeTree.TreeCanvas = rt._canvas
	var leaves := c.nodes.filter(func(n): return n.kids.is_empty())
	_check("tree for a rarity-4 seed has 7 nodes (has %d)" % c.nodes.size(), c.nodes.size() == 7)
	_check("its 4 leaves are the Tier 1 seeds (rarity 4 = 4 leaves; has %d)" % leaves.size(), leaves.size() == 4)
	_check("root has two ingredients: obsidian + glowing mushroom", c.tree.kids.size() == 2 and c.tree.kids[0].id == obs and c.tree.kids[1].id == "glowing_mushroom")
	var xs := c.nodes.map(func(n): return n.x)
	_check("parent is centered over its two ingredients", absf(c.tree.x - (c.tree.kids[0].x + c.tree.kids[1].x) / 2.0) < 0.01)
	_check("totals text: " + rt._totals.text, rt._totals.text.contains("Dirt Seed") and rt._totals.text.contains("(4)"))
	_check("sub text: " + rt._sub.text, rt._sub.text.contains("Obsidian Seed") and rt._sub.text.contains("Crystal Seed"))
	_check("tree is fitted to the view, not tiny (zoom %.2f)" % c.zoom, c.zoom > 0.55)
	await _snap(base + "/t5_chain.png")

	# a second recipe for Gravel: Dirt + Glowing Mushroom also makes it
	Game.link_recipe("dirt", "glowing_mushroom", gravel)
	await get_tree().create_timer(0.2).timeout
	var g_node: Dictionary = c.nodes.filter(func(n): return n.id == gravel)[0]
	_check("gravel now shows a 1/2 badge", g_node.recipes == 2 and g_node.idx == 0)
	c.click_at(Vector2(g_node.x + 40.0, float(g_node.y) + 10.0))  # the badge
	g_node = c.nodes.filter(func(n): return n.id == gravel)[0]
	_check("clicking the badge switches to recipe 2/2 (dirt + glowing mushroom)", g_node.idx == 1 and g_node.kids[1].id == "glowing_mushroom")
	await _snap(base + "/t5_alt.png")

	# a looping recipe: Crystal + Magma Rock also "makes" Gravel (Crystal is above Gravel in the tree)
	Game.link_recipe(crystal, "magma_rock", gravel)
	await get_tree().create_timer(0.2).timeout
	g_node = c.nodes.filter(func(n): return n.id == gravel)[0]
	_check("gravel has 3 recipes", g_node.recipes == 3)
	c.choices[g_node.path] = 2
	c.rebuild()
	var loops := c.nodes.filter(func(n): return n.loop)
	_check("a looping recipe stops at a loop card (no endless tree, %d nodes)" % c.nodes.size(), loops.size() == 1 and loops[0].id == crystal and c.nodes.size() < 30)
	_check("totals mention the loop", rt._totals.text.contains("loop"))
	await _snap(base + "/t5_loop.png")

	# clicking a seed re-centers on it, Back returns
	rt.show_seed(obs)
	_check("re-centered on Obsidian (4 nodes... has %d)" % c.nodes.size(), c.root_id == obs and c.nodes.size() == 5)
	rt._go_back()
	_check("Back returns to Crystal", c.root_id == crystal)
	rt.show_seed("dirt")
	_check("a Tier 1 seed is a single card with an explanation", c.nodes.size() == 1 and rt._sub.text.contains("Tier 1"))
	rt.show_seed(crystal, false)
	c.zoom = 1.0
	rt.close_menu()


## Hide / show / resize the Seeds panel. WRITES TO YOUR SETTINGS.
func _run_test4(base: String) -> void:
	var panel: SidePanel = main.panel
	var field: VoidField = main.field
	var grip: SideGrip = panel.get_parent().get_child(panel.get_index() - 1)
	panel.show_panel(true)
	panel.set_width(380.0)
	await get_tree().create_timer(0.2).timeout
	_check("Seeds panel visible at 380 (is %d)" % panel.size.x, panel.visible and absf(panel.size.x - 380.0) < 2.0 and grip.visible)
	var void_w := field.size.x
	panel.show_panel(false)
	await get_tree().create_timer(0.2).timeout
	_check("hiding gives the void the whole width (%d -> %d of %d)" % [void_w, field.size.x, main.size.x], not panel.visible and not grip.visible and absf(field.size.x - main.size.x) < 2.0 and not main._seeds_btn.button_pressed)
	await _snap(base + "/t4_hidden.png")
	main._seeds_btn.button_pressed = true
	await get_tree().create_timer(0.2).timeout
	_check("Seeds button brings it back", panel.visible and grip.visible)
	var k := InputEventKey.new()
	k.keycode = KEY_B
	k.ctrl_pressed = true
	k.pressed = true
	main._unhandled_key_input(k)
	await get_tree().create_timer(0.2).timeout
	_check("Ctrl+B hides it", not panel.visible)
	main._unhandled_key_input(k)
	await get_tree().create_timer(0.2).timeout
	_check("Ctrl+B shows it again", panel.visible)
	grip.width_changed.emit(520.0)
	grip.released.emit()
	await get_tree().create_timer(0.2).timeout
	_check("drag wider -> 520 (is %d)" % panel.size.x, absf(panel.size.x - 520.0) < 2.0 and float(UserSettings.get_value("panels", "side_width", 0.0)) == 520.0)
	grip.width_changed.emit(100.0)
	await get_tree().create_timer(0.1).timeout
	_check("narrowest is 320 (is %d)" % panel.size.x, absf(panel.size.x - 320.0) < 2.0)
	grip.width_changed.emit(5000.0)
	await get_tree().create_timer(0.1).timeout
	_check("widest is 640 (is %d)" % panel.size.x, absf(panel.size.x - 640.0) < 2.0)
	grip.width_changed.emit(520.0)
	grip.released.emit()
	await _snap(base + "/t4_wide.png")
	panel.set_width(380.0)
	panel.save_width()
	await get_tree().create_timer(0.1).timeout


func _snap(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _mouse_event(pressed: bool, double := false) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.double_click = double
	return e


## Double-click edit, click-never-splices, floating splices window, display modes. WRITES TO YOUR SAVE + SETTINGS.
func _run_test3(base: String) -> void:
	var field: VoidField = main.field
	var popup: SplicePopup = main.popup
	var win := get_window()
	Game.reset()
	field.clear()
	await get_tree().create_timer(0.3).timeout

	# --- double-click a floating seed edits it
	var t := field.spawn(  "dirt", Vector2(300, 300), false)
	t._gui_input(_mouse_event(true))
	t._gui_input(_mouse_event(false))
	t._gui_input(_mouse_event(true, true))
	t._gui_input(_mouse_event(false))
	await get_tree().create_timer(0.2).timeout
	_check("double-click opens the editor for that seed", popup.visible and popup.mode == SplicePopup.Mode.EDIT and popup.edit_id == "dirt")
	_check("editing never splices", Game.recipes.is_empty())
	popup._on_name_changed("Rich Dirt Seed")
	popup._set_tag("not_farmable")
	popup._confirm()
	await get_tree().create_timer(0.2).timeout
	_check("edit saved (name + tag)", Game.get_seed("dirt").name == "Rich Dirt Seed" and Game.get_seed("dirt").tag == "not_farmable")
	t.queue_free()
	await get_tree().process_frame

	# --- clicking a seed that sits on top of another must not splice
	var a := field.spawn("stone", Vector2(400, 300), false)
	var b := field.spawn("magma_rock", Vector2(404, 302), false)
	a._gui_input(_mouse_event(true))
	a._gui_input(_mouse_event(false))
	await get_tree().create_timer(0.2).timeout
	_check("plain click on overlapping seeds does not splice", not popup.visible and Game.recipes.is_empty())
	a.queue_free()
	b.queue_free()

	# --- list double-click: first click spawned a copy, edit removes it
	var spawned := field.spawn_near_center("stone")
	var n_before := field.tokens().size()
	main._on_edit_request("stone", true)
	await get_tree().create_timer(0.2).timeout
	_check("list double-click removes the stray copy and opens the editor", field.tokens().size() == n_before - 1 and popup.visible and popup.edit_id == "stone")
	popup._cancel()
	_check("spawned token freed", not is_instance_valid(spawned) or spawned.is_queued_for_deletion())

	# --- floating splices window
	var sp: SplicesWindow = main.splices
	# (it remembers being hidden from a previous session, so start from a known state)
	sp.show_panel(false)
	sp.show_panel(true)
	_check("splices window visible", sp.visible)
	var open_h := sp.size.y
	sp.toggle_collapsed()
	await get_tree().create_timer(0.1).timeout
	_check("collapse shrinks to the title bar (%d -> %d px)" % [open_h, sp.size.y], sp.collapsed and not sp.body.visible and sp.size.y < 60.0)
	sp.toggle_collapsed()
	await get_tree().create_timer(0.1).timeout
	_check("expand restores it", not sp.collapsed and sp.body.visible and absf(sp.size.y - open_h) < 2.0)
	sp.position = Vector2(99999, 99999)
	sp._clamp()
	var ps: Vector2 = main.size
	_check("dragged far away -> kept on screen", sp.position.x + sp.size.x <= ps.x + 1.0 and sp.position.y + sp.size.y <= ps.y + 1.0 and sp.position.x >= 0.0)
	sp.position = Vector2(500, 120)
	sp._dragging = true
	sp._on_bar_input(_mouse_event(false))
	_check("position remembered", UserSettings.get_value("panels", "splices_pos", Vector2.ZERO) == Vector2(500, 120))
	sp.show_panel(false)
	_check("hide button hides it and un-presses the toolbar button", not sp.visible and not main._splices_btn.button_pressed)
	main._splices_btn.button_pressed = true
	_check("toolbar button shows it again", sp.visible)

	# --- a made splice shows up as a draggable row
	field.try_splice(field.spawn_near_center("magma_rock"), field.spawn_near_center("stone"))
	await get_tree().create_timer(0.3).timeout
	popup._confirm()
	await get_tree().create_timer(0.5).timeout
	var rows := sp._box.get_children().filter(func(c): return c is SplicesWindow.SpliceRow)
	_check("splice row appears (title '%s')" % sp.title_text, rows.size() == 1 and sp.title_text == "Splices (1)")
	_check("row carries the result seed for dragging", rows.size() == 1 and rows[0].result_id == Game.result_of("magma_rock", "stone"))
	await _snap(base + "/t3_main.png")
	sp.toggle_collapsed()
	await _snap(base + "/t3_collapsed.png")
	sp.toggle_collapsed()

	# --- display modes
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	print("screen usable: ", usable.size, "  window now: ", win.size)
	var start_res := win.size
	var want := Vector2i(1920, 1080) if usable.size.x >= 2000 and usable.size.y >= 1180 else Vector2i(1600, 900)
	DisplayManager.set_resolution(win, want)
	await get_tree().create_timer(0.5).timeout
	_check("windowed resolution %s applied (window is %s)" % [want, win.size], win.size == want and win.mode == Window.MODE_WINDOWED)
	await _snap(base + "/t3_res_big.png")
	DisplayManager.set_resolution(win, Vector2i(1024, 768))
	await get_tree().create_timer(0.5).timeout
	_check("4:3 resolution applied (window is %s)" % win.size, win.size == Vector2i(1024, 768))
	await _snap(base + "/t3_res_43.png")
	DisplayManager.set_ui_scale(win, 1.25)
	popup.open_add()
	await _snap(base + "/t3_ui125.png")
	popup._cancel()
	DisplayManager.set_ui_scale(win, 1.0)

	DisplayManager.set_mode(win, DisplayManager.Mode.BORDERLESS)
	await get_tree().create_timer(0.8).timeout
	_check("borderless fullscreen (mode %d, size %s)" % [win.mode, win.size], win.mode == Window.MODE_FULLSCREEN and DisplayManager.current_mode(win) == DisplayManager.Mode.BORDERLESS)
	await _snap(base + "/t3_borderless.png")
	DisplayManager.toggle_fullscreen(win)  # F11 back to windowed
	await get_tree().create_timer(0.8).timeout
	_check("F11 returns to windowed at the previous size (%s)" % win.size, win.mode == Window.MODE_WINDOWED and win.size == Vector2i(1024, 768))
	DisplayManager.set_mode(win, DisplayManager.Mode.FULLSCREEN)
	await get_tree().create_timer(0.8).timeout
	_check("exclusive fullscreen (mode %d)" % win.mode, win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN and DisplayManager.current_mode(win) == DisplayManager.Mode.FULLSCREEN)
	DisplayManager.toggle_fullscreen(win)
	await get_tree().create_timer(0.8).timeout
	_check("back to windowed again", win.mode == Window.MODE_WINDOWED)
	main.settings_dialog.open()
	await _snap(base + "/t3_settings.png")
	main.settings_dialog.close_dialog()
	DisplayManager.set_resolution(win, start_res)
