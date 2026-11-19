class_name RecipeTree
extends Control
## "Recipe Tree": pick a seed and see how to make it as a tree. The seed is at the top; under
## each seed are the two seeds that splice into it, all the way down to the Tier 1 seeds.
##   drag = pan     mouse wheel = zoom     click a seed = center the tree on it
##   click a "1/2" badge = switch to that seed's other recipe (seeds can have several)
##   click the round "+" under a seed (or right-click the seed) = fold that branch away / open it
## Layouts: Compact (default) stacks big branches downward so the tree stays near the window's
## shape; Wide is the classic tree where every branch sits side by side.
## Shortest route: a Farmable / Bountiful seed in the tree is farmed instead of spliced again
## (its branch stops there), and every seed with several recipes uses its cheapest one.

var root_id := ""

var _list: ItemList
var _search: LineEdit
var _sort: OptionButton
var _filter: OptionButton
var _drop_filter: OptionButton
var _drop_label: Label
var _math: Label
var _lens_toggle: CheckBox
var _lens_box: PanelContainer
var _canvas: TreeCanvas
var _header: Label
var _sub: Label
var _totals: Label
var _back_btn: Button
var _left: Control
var _side: Control
var _hint: Label
var _tree_only: CheckBox
var _compact: CheckBox
var _route: CheckBox
var _count: Label
var _history: Array[String] = []
var _list_ids: Array[String] = []


## The magnifier, docked at the bottom right of the Recipe Tree: it shows the part of the tree
## under your cursor up close. Shift + mouse wheel changes how much it magnifies.
class Lens extends Control:
	const LENS_SIZE := Vector2(320, 240)
	var canvas: TreeCanvas
	var world_center := Vector2.ZERO
	var lens_zoom := 1.0
	var has_target := false  ## true while the cursor is over the tree

	func _ready() -> void:
		custom_minimum_size = LENS_SIZE
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0b0912"))
		var f := get_theme_default_font()
		draw_string(f, Vector2(8, 16), "MAGNIFIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a6ff6e"))
		if not has_target or canvas == null or canvas.tree.is_empty():
			draw_string(f, Vector2(0, size.y / 2.0), "Point at the tree to see it up close", HORIZONTAL_ALIGNMENT_CENTER,
				size.x, 13, Color(0.7, 0.67, 0.8))
			return
		var lens_pan := size / 2.0 - world_center * lens_zoom
		canvas.draw_tree_into(self, lens_pan, lens_zoom, Rect2(world_center - size / 2.0 / lens_zoom, size / lens_zoom))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# crosshair where the cursor is, and a frame
		var c := (size / 2.0).round()
		draw_rect(Rect2(c - Vector2(7, 0), Vector2(5, 1)), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(c + Vector2(3, 0), Vector2(5, 1)), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(c - Vector2(0, 7), Vector2(1, 5)), Color(1, 1, 1, 0.5))
		draw_rect(Rect2(c + Vector2(0, 3), Vector2(1, 5)), Color(1, 1, 1, 0.5))
		draw_string(f, Vector2(8, 16), "MAGNIFIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#a6ff6e"))
		draw_string(f, Vector2(8, size.y - 8), "x%.1f  (Shift + wheel)" % (lens_zoom / maxf(canvas.zoom, 0.0001)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.67, 0.8, 0.8))


class TreeCanvas extends Control:
	signal reroot(id: String)
	signal built

	const CARD_W := 116.0
	const CARD_H := 132.0
	const GAP_X := 18.0
	const LEVEL_H := 178.0
	const MIN_ZOOM := 0.01      ## zoom out as far as you like
	const MAX_ZOOM := 1.6
	const MAX_DEPTH := 80
	const SLOT_W := CARD_W + GAP_X
	const GAP_Y := LEVEL_H - CARD_H
	const INDENT := 96.0   ## how far a stacked branch is pushed right of its trunk
	const KNOB_R := 12.0   ## the round "+" under a seed (click: fold / unfold)

	var root_id := ""
	var choices := {}      # path -> which of the seed's recipes to show
	var collapsed := {}    # path -> true: that branch is folded away
	var compact := true    ## stack big branches downward (false: the classic wide tree)
	var farm_route := false  ## shortest route: farm Farmable seeds instead of splicing them
	var _cost_memo := {}
	var _fold_marks: Array = []  # [world position, hidden count] of folded branches (drawn as text)
	var nodes: Array = []  # every node in the tree, parents before children
	var tree := {}
	var pan := Vector2.ZERO
	var zoom := 1.0
	var auto_fit := true
	var lens: Lens
	var lens_enabled := true
	var _plus_marks: Array[Vector2] = []
	var _panning := false
	var _moved := false
	var _press_pos := Vector2.ZERO
	var _pan_start := Vector2.ZERO

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		resized.connect(_on_resized)
		mouse_exited.connect(func():
			if lens:
				lens.has_target = false
				lens.queue_redraw())

	## Points the docked magnifier at what's under the cursor.
	func update_lens(mouse: Vector2) -> void:
		if lens == null:
			return
		lens.has_target = lens_enabled and not tree.is_empty() and Rect2(Vector2.ZERO, size).has_point(mouse)
		if lens.has_target:
			lens.world_center = _to_world(mouse)
		lens.queue_redraw()

	func _on_resized() -> void:
		if auto_fit:
			fit()  # keeps the whole tree in view while the window settles or is resized
		queue_redraw()

	func set_root(id: String) -> void:
		root_id = id
		choices.clear()
		collapsed.clear()
		rebuild()
		refit()

	## Folds a branch away, or opens it again.
	func toggle_fold(path: String) -> void:
		if collapsed.has(path):
			collapsed.erase(path)
		else:
			collapsed[path] = true
		rebuild()
		if auto_fit:
			fit()

	## Folds every branch under the top seed's two ingredients.
	func fold_all() -> void:
		collapsed.clear()
		for n in nodes:
			if n.depth == 1 and not n.kids.is_empty():
				collapsed[n.path] = true
		rebuild()
		refit()

	func unfold_all() -> void:
		collapsed.clear()
		rebuild()
		refit()

	## Fit the tree to the view now, and keep doing so until you pan or zoom yourself.
	func refit() -> void:
		auto_fit = true
		fit()

	func rebuild() -> void:
		nodes.clear()
		tree = {}
		_cost_memo.clear()
		if not Game.get_seed(root_id).is_empty():
			tree = _build(root_id, "0", [], 0, false)
			_count_splices(tree)
			_measure(tree)
			_place(tree, 0.0, 0.0)
		queue_redraw()
		built.emit()

	## A seed you can farm (grow for more seeds) instead of splicing it again.
	static func is_farmable(id: String) -> bool:
		var s := Game.get_seed(id)
		return not s.get("parents", []).is_empty() and String(s.get("tag", "")) in ["farmable", "bountiful"]

	## Fewest splices to make `id` when Farmable seeds below the top are farmed, not spliced.
	func _route_cost(id: String, stack: Dictionary) -> int:
		if _cost_memo.has(id):
			return _cost_memo[id]
		var s := Game.get_seed(id)
		if s.get("parents", []).is_empty() or is_farmable(id):
			return 0
		if stack.has(id) or stack.size() >= MAX_DEPTH:
			return 1000000
		stack[id] = true
		var best := 1000000
		for pair in Game.recipes_for(id):
			best = mini(best, 1 + _route_cost(pair[0], stack) + _route_cost(pair[1], stack))
		stack.erase(id)
		_cost_memo[id] = best
		return best

	func _best_recipe(recs: Array, id: String) -> int:
		var best := 0
		var best_cost := 1 << 60
		for i in recs.size():
			var c := _route_cost(recs[i][0], { id: true }) + _route_cost(recs[i][1], { id: true })
			if c < best_cost:
				best_cost = c
				best = i
		return best

	func _build(id: String, path: String, ancestors: Array, depth: int, hidden: bool) -> Dictionary:
		var node := { "id": id, "path": path, "depth": depth, "kids": [], "recipes": 0, "idx": 0,
			"loop": false, "farm": false, "collapsed": false, "hidden": hidden, "count": 0,
			"x": 0.0, "y": 0.0, "bw": SLOT_W, "bh": CARD_H, "mode": 0, "box": Rect2() }
		nodes.append(node)
		if ancestors.has(id):
			node.loop = true  # a recipe that needs the seed it is making: stop here
			return node
		if Game.get_seed(id).get("parents", []).is_empty() or depth >= MAX_DEPTH:
			return node       # a Tier 1 seed
		if farm_route and depth > 0 and is_farmable(id):
			node.farm = true  # shortest route: farm this one instead of splicing it
			return node
		var recs := Game.recipes_for(id)
		if recs.is_empty():
			return node
		node.recipes = recs.size()
		if choices.has(path):
			node.idx = clampi(int(choices[path]), 0, recs.size() - 1)
		elif farm_route and recs.size() > 1:
			node.idx = _best_recipe(recs, id)
		node.collapsed = collapsed.has(path)
		var pair: Array = recs[node.idx]
		var anc := ancestors.duplicate()
		anc.append(id)
		for k in 2:
			var kid := _build(pair[k], path + "." + str(k), anc, depth + 1, hidden or node.collapsed)
			node.kids.append(kid)
			node.count += 1 + int(kid.count)
		return node

	## node.splices: every "+" below a seed, including its own (how many splices it takes to make).
	func _count_splices(node: Dictionary) -> int:
		node.splices = 0
		if not node.kids.is_empty():
			node.splices = 1
			for k in node.kids:
				node.splices += _count_splices(k)
		return node.splices

	## How big each branch is drawn. A seed's two ingredients go side by side (mode 1), or in the
	## Compact layout one under the other along a trunk (mode 2). A folded branch is just its seed
	## (mode 0). Compact tries every useful mix: each branch keeps a short list of the shapes it can
	## take (no shape on the list is both wider and taller than another), and the top seed picks the
	## shape that fits the window best.
	const MAX_SHAPES := 24

	func _measure(root: Dictionary) -> void:
		_shapes(root)
		var best := 0
		var opts: Array = root.opts
		for i in opts.size():
			if _shape_cost(opts[i][0], opts[i][1]) < _shape_cost(opts[best][0], opts[best][1]) - 0.0001:
				best = i
		_use_shape(root, best)

	## n.opts: [width, height, mode, shape of ingredient 1, shape of ingredient 2], narrowest first.
	func _shapes(n: Dictionary) -> void:
		if n.kids.is_empty() or n.collapsed:
			n.opts = [[SLOT_W, CARD_H, 0, -1, -1]]
			return
		var a: Dictionary = n.kids[0]
		var b: Dictionary = n.kids[1]
		_shapes(a)
		_shapes(b)
		var all: Array = []
		for ai in a.opts.size():
			var sa: Array = a.opts[ai]
			for bi in b.opts.size():
				var sb: Array = b.opts[bi]
				all.append([sa[0] + sb[0], LEVEL_H + maxf(sa[1], sb[1]), 1, ai, bi])
				if compact:
					all.append([maxf(SLOT_W, INDENT + maxf(sa[0], sb[0])), LEVEL_H + sa[1] + GAP_Y + sb[1], 2, ai, bi])
		all.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
		var front: Array = []
		for o in all:
			if front.is_empty() or o[1] < front[-1][1] - 0.5:
				front.append(o)
		if front.size() > MAX_SHAPES:  # keep the narrowest, the flattest and an even spread between
			var keep: Array = []
			for k in MAX_SHAPES:
				keep.append(front[roundi(float(k) * (front.size() - 1) / (MAX_SHAPES - 1))])
			front = keep
		n.opts = front

	func _use_shape(n: Dictionary, i: int) -> void:
		var o: Array = n.opts[i]
		n.bw = o[0]
		n.bh = o[1]
		n.mode = o[2]
		if o[2] != 0:
			_use_shape(n.kids[0], o[3])
			_use_shape(n.kids[1], o[4])

	## How far the view would have to zoom out to show a box this big (smaller is better).
	func _shape_cost(w: float, h: float) -> float:
		var view := size if size.x > 100.0 and size.y > 100.0 else Vector2(1200, 700)
		return maxf(w / view.x, h / view.y)

	func _place(n: Dictionary, ox: float, oy: float) -> void:
		n.y = oy
		n.box = Rect2(ox, oy, n.bw, n.bh)
		match int(n.mode):
			1:
				_place(n.kids[0], ox, oy + LEVEL_H)
				_place(n.kids[1], ox + float(n.kids[0].bw), oy + LEVEL_H)
				n.x = (float(n.kids[0].x) + float(n.kids[1].x)) / 2.0
			2:
				n.x = ox + SLOT_W / 2.0
				_place(n.kids[0], ox + INDENT, oy + LEVEL_H)
				_place(n.kids[1], ox + INDENT, oy + LEVEL_H + float(n.kids[0].bh) + GAP_Y)
			_:
				n.x = ox + SLOT_W / 2.0

	## The round knob under a seed: the "+" between it and its ingredients (click: fold / unfold).
	func knob(n: Dictionary) -> Vector2:
		return Vector2(n.x, n.y + CARD_H + GAP_Y / 2.0)

	func knob_at(world: Vector2) -> Dictionary:
		for n in nodes:
			if not n.hidden and (not n.kids.is_empty()) and world.distance_to(knob(n)) <= KNOB_R + 4.0:
				return n
		return {}

	## The math for the whole tree: { splices, different, longest, tier1 }
	##   splices   every "+" in the tree: how many splices you do to make the top seed from scratch
	##             (an ingredient needed twice is made twice)
	##   different how many different recipes that is (each one only has to be discovered once)
	##   longest   the most splices in a row, from a Tier 1 seed up to the top
	##   tier1     how many Tier 1 seeds go in
	func math() -> Dictionary:
		var out := { "splices": 0, "different": 0, "longest": 0, "tier1": 0, "farm": 0 }
		var seen := {}
		for n in nodes:
			if n.loop:
				continue
			if n.kids.is_empty():
				if n.depth > 0:
					if n.farm:
						out.farm += 1
					else:
						out.tier1 += 1
					out.longest = maxi(out.longest, int(n.depth))
			else:
				out.splices += 1
				seen[n.id] = true
		out.different = seen.size()
		return out

	func fit() -> void:
		if tree.is_empty() or size.x < 10.0:
			return
		var bw: float = tree.bw
		var bh: float = tree.bh
		var pad := 20.0
		zoom = clampf(minf((size.x - pad * 2.0) / bw, (size.y - pad * 2.0) / bh), MIN_ZOOM, 1.0)
		var px := (size.x - bw * zoom) / 2.0
		if bw * zoom > size.x:  # too wide to fit even at the smallest zoom: start on the top seed
			px = size.x / 2.0 - float(tree.x) * zoom
		pan = Vector2(px, maxf(pad, (size.y - bh * zoom) / 2.0))
		queue_redraw()

	func card_rect(n: Dictionary) -> Rect2:
		return Rect2(n.x - CARD_W / 2.0, n.y, CARD_W, CARD_H)

	func badge_rect(n: Dictionary) -> Rect2:
		var r := card_rect(n)
		return Rect2(r.end.x - 38.0, r.position.y + 4.0, 34.0, 18.0)

	func node_at(world: Vector2) -> Dictionary:
		for i in range(nodes.size() - 1, -1, -1):
			if not nodes[i].hidden and card_rect(nodes[i]).has_point(world):
				return nodes[i]
		return {}

	func _to_world(p: Vector2) -> Vector2:
		return (p - pan) / zoom

	# --- input -----------------------------------------------------------------

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_panning = true
					_moved = false
					_press_pos = mb.position
					_pan_start = pan
				else:
					if _panning and not _moved:
						click_at(_to_world(mb.position))
					_panning = false
					_moved = false
					update_lens(mb.position)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				var rn := node_at(_to_world(mb.position))  # right-click a seed: fold / unfold its branch
				if not rn.is_empty() and not rn.kids.is_empty():
					toggle_fold(rn.path)
				accept_event()
			elif mb.pressed and mb.shift_pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				# Shift + wheel: how much the magnifier magnifies
				var f := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				lens.lens_zoom = clampf(lens.lens_zoom * f, 0.3, 2.5)
				update_lens(mb.position)
				accept_event()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(mb.position, 1.12)
				update_lens(mb.position)
				accept_event()
			elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(mb.position, 1.0 / 1.12)
				update_lens(mb.position)
				accept_event()
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _panning:
				if mm.position.distance_to(_press_pos) > 4.0:
					_moved = true
				if _moved:
					auto_fit = false
					pan = _pan_start + (mm.position - _press_pos)
					queue_redraw()
			else:
				_update_tooltip(_to_world(mm.position))
			update_lens(mm.position)

	func click_at(world: Vector2) -> void:
		var kn := knob_at(world)
		if not kn.is_empty():
			toggle_fold(kn.path)
			return
		var n := node_at(world)
		if n.is_empty():
			return
		if n.recipes > 1 and badge_rect(n).has_point(world):
			choices[n.path] = (int(n.idx) + 1) % int(n.recipes)  # show the next recipe
			rebuild()
		elif n.depth > 0:
			reroot.emit(n.id)

	func _zoom_at(pos: Vector2, factor: float) -> void:
		auto_fit = false
		var old := zoom
		zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
		var world := (pos - pan) / old
		pan = pos - world * zoom
		queue_redraw()

	func _update_tooltip(world: Vector2) -> void:
		var kn := knob_at(world)
		if not kn.is_empty():
			tooltip_text = ("Click to open this branch again (%d seeds)" if kn.collapsed else "Click to fold this branch away (%d seeds)") % int(kn.count)
			return
		var n := node_at(world)
		if n.is_empty():
			tooltip_text = ""
			return
		var s := Game.get_seed(n.id)
		var line := "%s  ·  Rarity %d  ·  %s" % [s.name, int(s.rarity), Game.tag_name(s.get("tag", ""))]
		if n.loop:
			line += "\nThis recipe needs a seed that is already above it, so the tree stops here."
		elif n.farm:
			line += "\nFarmable: grow this one for more seeds instead of splicing it again"
		elif n.recipes > 1 and badge_rect(n).has_point(world):
			line += "\nClick to show another recipe (%d of %d now)" % [int(n.idx) + 1, int(n.recipes)]
		else:
			if int(n.get("splices", 0)) > 0:
				line += "\nTakes %d splice%s to make from Tier 1 seeds" % [n.splices, "" if n.splices == 1 else "s"]
			if n.depth > 0:
				line += "\nClick to center the tree on this seed"
			if not n.kids.is_empty():
				line += "\nRight-click to fold this branch %s" % ("open" if n.collapsed else "away")
		tooltip_text = line

	# --- drawing ---------------------------------------------------------------

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#0e0b16"))
		if tree.is_empty():
			var f := get_theme_default_font()
			draw_string(f, Vector2(24, 40), "Pick a seed on the left.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.67, 0.8))
			return
		draw_tree_into(self, pan, zoom, Rect2(_to_world(Vector2.ZERO), size / zoom))

	## Draws the tree onto `ci` (this canvas, or the magnifier) with its own pan and zoom.
	## Only cards inside `world_view` are drawn, so a huge tree stays fast.
	func draw_tree_into(ci: CanvasItem, p: Vector2, z: float, world_view: Rect2) -> void:
		var keep_pan := pan
		var keep_zoom := zoom
		pan = p
		zoom = z
		var view := world_view.grow(CARD_W)
		_plus_marks.clear()
		_fold_marks.clear()
		# Boxes and lines are scaled by the zoom...
		ci.draw_set_transform(pan, 0.0, Vector2(zoom, zoom))
		_draw_links(ci, tree, view)
		for n in nodes:
			if not n.hidden and card_rect(n).intersects(view):
				_draw_card(ci, n)
		# ...but text and seed pictures are drawn at their real on-screen size, so they stay
		# sharp however far you zoom out (scaling a drawn font just blurs it).
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for m in _plus_marks:
			_draw_plus(ci, m)
		for m in _fold_marks:
			_draw_fold_count(ci, m[0], m[1])
		for n in nodes:
			if not n.hidden and card_rect(n).intersects(view):
				_draw_card_content(ci, n)
		pan = keep_pan
		zoom = keep_zoom

	func _sp(p: Vector2) -> Vector2:  # world position -> whole-pixel screen position
		return (p * zoom + pan).round()

	func _fs(base: float) -> int:  # font size at the current zoom
		return roundi(base * zoom)

	func _lw(world_width: float) -> float:  # a line width that never gets thinner than 1 screen pixel
		return maxf(world_width, 1.0 / zoom)

	func _draw_plus(ci: CanvasItem, m: Vector2) -> void:
		var fs := _fs(18.0)
		if fs < 8:
			return
		var c := _sp(m)
		ci.draw_string(get_theme_default_font(), Vector2(c.x - 20.0, roundf(c.y + fs * 0.35)), "+",
			HORIZONTAL_ALIGNMENT_CENTER, 40.0, fs, Color("#e8e4f5"))

	func _draw_links(ci: CanvasItem, n: Dictionary, view: Rect2) -> void:
		if n.kids.is_empty() or n.hidden:
			return
		var col := Color("#5b4d7a")
		var bottom := card_rect(n).end.y
		var k0 := knob(n)
		if n.collapsed:
			# a folded branch: a short stem and a knob that says how many seeds are hidden
			if Rect2(k0 - Vector2(40, 40), Vector2(80, 80)).intersects(view):
				ci.draw_line(Vector2(n.x, bottom), k0 - Vector2(0, KNOB_R), Color("#a6ff6e"), _lw(2.0))
				if KNOB_R * zoom >= 3.0:
					ci.draw_circle(k0, KNOB_R, Color("#2a3a1f"))
					ci.draw_arc(k0, KNOB_R, 0.0, TAU, 20, Color("#a6ff6e"), _lw(2.0))
					_fold_marks.append([k0, int(n.count)])
			return
		if n.box.intersects(view):  # skip a whole branch that is off screen
			if int(n.mode) == 2:
				# stacked: a trunk down the left, a branch off to each ingredient
				var a: Dictionary = n.kids[0]
				var b: Dictionary = n.kids[1]
				ci.draw_line(Vector2(n.x, bottom), Vector2(n.x, float(b.y) + CARD_H / 2.0), col, _lw(3.0))
				for k in [a, b]:
					var y: float = float(k.y) + CARD_H / 2.0
					ci.draw_line(Vector2(n.x, y), Vector2(float(k.x) - CARD_W / 2.0, y), col, _lw(3.0))
			else:
				var kid_top: float = n.kids[0].y
				var mid := k0.y
				ci.draw_line(Vector2(n.x, bottom), Vector2(n.x, mid), col, _lw(3.0))
				ci.draw_line(Vector2(n.kids[0].x, mid), Vector2(n.kids[1].x, mid), col, _lw(3.0))
				for k in n.kids:
					ci.draw_line(Vector2(k.x, mid), Vector2(k.x, kid_top), col, _lw(3.0))
			if KNOB_R * zoom >= 3.0:
				ci.draw_circle(k0, KNOB_R, Color("#241c35"))
				ci.draw_arc(k0, KNOB_R, 0.0, TAU, 20, col, _lw(2.0))
				_plus_marks.append(k0)
		for k in n.kids:
			_draw_links(ci, k, view)

	func _draw_fold_count(ci: CanvasItem, m: Vector2, count: int) -> void:
		var fs := _fs(13.0)
		if fs < 7:
			return
		var c := _sp(m)
		ci.draw_string(get_theme_default_font(), Vector2(c.x - 30.0, roundf(c.y + fs * 0.35)), "+%d" % count,
			HORIZONTAL_ALIGNMENT_CENTER, 60.0, fs, Color("#a6ff6e"))

	## The card's box, border, tag square and badge (shapes: these scale with the zoom).
	func _draw_card(ci: CanvasItem, n: Dictionary) -> void:
		var s := Game.get_seed(n.id)
		var r := card_rect(n)
		var tier: Array = SeedArt.rarity_tier(int(s.rarity))
		var is_root: bool = n.depth == 0
		var tier1: bool = s.get("parents", []).is_empty()
		var alpha := 0.55 if n.loop else 1.0

		var bg := Color("#1d1828") if not tier1 else Color("#15222a")
		if n.farm:
			bg = Color("#17271a")
		bg.a = alpha
		ci.draw_rect(r, bg)
		var border: Color = Color("#a6ff6e") if is_root else (Color("#7be36f") if n.farm else (tier[1] as Color).darkened(0.25))
		border.a = alpha
		ci.draw_rect(r, border, false, _lw(3.0 if is_root else 2.0))
		if 8.0 * zoom < 2.0:
			return  # too small for the little markers

		# tag color square, top-left; next to it the drop: filled = collision, hollow = no collision,
		# red = collision damage
		ci.draw_rect(Rect2(r.position.x + 5.0, r.position.y + 5.0, 8.0, 8.0), Game.tag_color(s.get("tag", "")))
		var drop: Dictionary = s.get("drop", {})
		var dr := Rect2(r.position.x + 16.0, r.position.y + 5.0, 8.0, 8.0)
		var solid: bool = drop.get("collision", true)
		ci.draw_rect(dr, DropLogic.short_color(drop), solid, -1.0 if solid else _lw(1.5))
		if n.recipes > 1:
			var br := badge_rect(n)
			ci.draw_rect(br, Color("#3b3150"))
			ci.draw_rect(br, Color("#a6ff6e"), false, _lw(1.5))

	## The card's seed picture and text, at real screen size (see draw_tree_into).
	func _draw_card_content(ci: CanvasItem, n: Dictionary) -> void:
		var s := Game.get_seed(n.id)
		var r := card_rect(n)
		var f := get_theme_default_font()
		var tier: Array = SeedArt.rarity_tier(int(s.rarity))
		var tier1: bool = s.get("parents", []).is_empty()
		var alpha := 0.55 if n.loop else 1.0

		# The seed is 32x32 pixel art: draw it at a whole multiple (or exactly half) of its size
		# so every pixel stays square, centered in the space the card gives it. Zoomed out
		# further than that, the card just shows the seed's main color.
		var box := 64.0 * zoom
		var center := _sp(Vector2(r.position.x + CARD_W / 2.0, r.position.y + 6.0 + 32.0))
		if box >= 16.0:
			var ideal := 2.0 * zoom
			var k := floorf(ideal) if ideal >= 1.0 else 0.5
			var px := 32.0 * k
			var icon := Rect2((center - Vector2(px, px) / 2.0).round(), Vector2(px, px))
			ci.draw_texture_rect(SeedArt.texture_for(s), icon, false, Color(1, 1, 1, alpha))
		elif box >= 2.0:
			var dot := maxf(roundf(box * 0.7), 2.0)
			var c := Color(s.get("colors", ["#888888"])[0])
			c.a = alpha
			ci.draw_rect(Rect2((center - Vector2(dot, dot) / 2.0).round(), Vector2(dot, dot)), c)

		# Text never gets smaller than 9 px (smaller is unreadable), so names are laid out from
		# the picture downward in screen space, and drop out once the cards get too tight.
		var nm := String(s.name)
		if nm.ends_with(" Seed"):
			nm = nm.substr(0, nm.length() - 5)
		var fs := maxi(9 if zoom >= 0.5 else 8, _fs(12.0))
		var box_bottom := _sp(Vector2(r.position.x, r.position.y + 70.0)).y
		var cx := _sp(Vector2(r.position.x + CARD_W / 2.0, 0.0)).x
		var wrap := (CARD_W + GAP_X - 6.0) * zoom  # may use a little of the gap between cards
		if zoom >= 0.38:
			ci.draw_multiline_string(f, Vector2(roundf(cx - wrap / 2.0), box_bottom + fs), nm,
				HORIZONTAL_ALIGNMENT_CENTER, wrap, fs, 2, Color(0.95, 0.93, 1.0, alpha))
		if zoom >= 0.5:
			var bottom_text := "R%d" % int(s.rarity)
			var bottom_col: Color = tier[1]
			if n.loop:
				bottom_text = "loop"
				bottom_col = Color("#ffb347")
			elif n.farm:
				bottom_text += " · Farm"
				bottom_col = Color("#7be36f")
			elif tier1:
				bottom_text += " · Tier 1"
			var fs2 := maxi(8, _fs(11.0))
			ci.draw_string(f, Vector2(roundf(cx - wrap / 2.0), _sp(Vector2(0.0, r.end.y - 4.0)).y), bottom_text,
				HORIZONTAL_ALIGNMENT_CENTER, wrap, fs2, bottom_col)
		if n.recipes > 1 and zoom >= 0.5:
			var br := badge_rect(n)
			ci.draw_string(f, _sp(Vector2(br.position.x, br.end.y - 5.0)), "%d/%d" % [int(n.idx) + 1, int(n.recipes)],
				HORIZONTAL_ALIGNMENT_CENTER, br.size.x * zoom, maxi(8, _fs(12.0)), Color("#a6ff6e"))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	add_child(panel)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	panel.add_child(cols)

	# --- left: seed picker
	var left := VBoxContainer.new()
	_left = left
	left.custom_minimum_size = Vector2(370, 0)
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	var title := Label.new()
	title.text = "Recipe Tree"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#a6ff6e"))
	left.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = "Search seeds..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t): _refresh_list())
	left.add_child(_search)
	_sort = SeedSort.make_sort_button(SeedSort.NAME)
	_sort.item_selected.connect(func(_i): _refresh_list())
	left.add_child(_sort)
	var filters := HBoxContainer.new()
	left.add_child(filters)
	_filter = SeedSort.make_filter_button()
	_drop_filter = SeedSort.make_drop_filter_button()
	for f in [_filter, _drop_filter]:
		f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f.fit_to_longest_item = false
		f.clip_text = true
		f.item_selected.connect(func(_i): _refresh_list())
		filters.add_child(f)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.fixed_icon_size = Vector2i(40, 40)
	_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_list.icon_mode = ItemList.ICON_MODE_LEFT
	_list.max_text_lines = 2
	_list.item_selected.connect(_on_list_selected)
	left.add_child(_list)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 12)
	_count.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	left.add_child(_count)

	# --- right: the tree
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	right.add_child(top)
	_header = Label.new()
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_theme_font_size_override("font_size", 18)
	_header.clip_text = true
	top.add_child(_header)
	_back_btn = Button.new()
	_back_btn.text = "Back"
	_back_btn.pressed.connect(_go_back)
	top.add_child(_back_btn)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(close_menu)
	top.add_child(close)

	# tools for the tree itself
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	right.add_child(tools)
	var fit := Button.new()
	fit.text = "Fit"
	fit.tooltip_text = "Zoom to fit the whole tree"
	fit.pressed.connect(func(): _canvas.refit())
	tools.add_child(fit)
	var fold := Button.new()
	fold.text = "Fold all"
	fold.tooltip_text = "Fold every branch away under the top seed's two ingredients\n(click the round + under any seed to fold or open just that branch; right-click a seed works too)"
	fold.pressed.connect(func(): _canvas.fold_all())
	tools.add_child(fold)
	var unfold := Button.new()
	unfold.text = "Open all"
	unfold.tooltip_text = "Open every folded branch"
	unfold.pressed.connect(func(): _canvas.unfold_all())
	tools.add_child(unfold)
	tools.add_child(VSeparator.new())
	_compact = CheckBox.new()
	_compact.text = "Compact"
	_compact.tooltip_text = "On: big branches go downward so the tree keeps the window's shape\nOff: the classic wide tree, every branch side by side"
	_compact.button_pressed = bool(UserSettings.get_value("panels", "tree_compact", true))
	_compact.toggled.connect(func(on):
		UserSettings.set_value("panels", "tree_compact", on)
		_canvas.compact = on
		_canvas.rebuild()
		_canvas.refit())
	tools.add_child(_compact)
	_route = CheckBox.new()
	_route.text = "Shortest route (farm Farmable seeds)"
	_route.tooltip_text = "A Farmable or Bountiful seed in the tree is grown for more seeds instead of being spliced again:\nits branch stops there. Seeds with several recipes use the one with the fewest splices."
	_route.button_pressed = bool(UserSettings.get_value("panels", "tree_route", false))
	_route.toggled.connect(func(on):
		UserSettings.set_value("panels", "tree_route", on)
		_canvas.farm_route = on
		_canvas.choices.clear()
		_canvas.collapsed.clear()
		_canvas.rebuild()
		_canvas.refit())
	tools.add_child(_route)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	_tree_only = CheckBox.new()
	_tree_only.text = "Tree only"
	_tree_only.tooltip_text = "Hide the seed list and all the side text: just the tree"
	_tree_only.button_pressed = bool(UserSettings.get_value("panels", "tree_only", false))
	_tree_only.toggled.connect(func(on):
		UserSettings.set_value("panels", "tree_only", on)
		_apply_tree_only())
	tools.add_child(_tree_only)
	_lens_toggle = CheckBox.new()
	_lens_toggle.text = "Magnifier"
	_lens_toggle.tooltip_text = "Show the tree around your cursor up close, bottom right (Shift + wheel: stronger / weaker)"
	_lens_toggle.button_pressed = bool(UserSettings.get_value("panels", "tree_lens", true))
	_lens_toggle.toggled.connect(func(on):
		UserSettings.set_value("panels", "tree_lens", on)
		_apply_tree_only())
	tools.add_child(_lens_toggle)

	_sub = Label.new()
	_sub.add_theme_color_override("font_color", Color(0.8, 0.78, 0.9))
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_sub)

	# the tree on the left; on the right a column with the seed's facts and math on top and
	# the magnifier docked at the bottom
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 10)
	right.add_child(middle)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _box_style())
	middle.add_child(frame)
	_canvas = TreeCanvas.new()
	_canvas.reroot.connect(func(id): show_seed(id))
	_canvas.built.connect(_update_totals)
	frame.add_child(_canvas)
	_canvas.compact = _compact.button_pressed
	_canvas.farm_route = _route.button_pressed

	var side := VBoxContainer.new()
	_side = side
	side.custom_minimum_size = Vector2(Lens.LENS_SIZE.x + 4, 0)
	side.add_theme_constant_override("separation", 8)
	middle.add_child(side)
	var info := ScrollContainer.new()  # long totals scroll instead of pushing the magnifier away
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(info)
	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 10)
	info.add_child(info_box)
	_drop_label = Label.new()  # what the root seed drops, and its category
	_drop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_drop_label.add_theme_font_size_override("font_size", 14)
	info_box.add_child(_drop_label)
	_math = Label.new()  # how many splices it takes to make the seed
	_math.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_math.add_theme_font_size_override("font_size", 15)
	_math.add_theme_color_override("font_color", Color("#a6ff6e"))
	info_box.add_child(_math)
	_totals = Label.new()
	_totals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_totals.add_theme_color_override("font_color", Color("#ffc94a"))
	info_box.add_child(_totals)

	_lens_box = PanelContainer.new()  # the magnifier, docked bottom right
	_lens_box.add_theme_stylebox_override("panel", _box_style())
	side.add_child(_lens_box)
	var lens := Lens.new()
	lens.canvas = _canvas
	_lens_box.add_child(lens)
	_canvas.lens = lens

	var hint := Label.new()
	_hint = hint
	hint.text = "Drag to pan  ·  Wheel: zoom  ·  Shift + wheel: magnifier strength  ·  Click a seed to center on it  ·  Click a round + (or right-click a seed) to fold its branch  ·  1/2 badge: other recipe"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.67, 0.8))
	hint.clip_text = true
	right.add_child(hint)
	_apply_tree_only()

	Game.seeds_changed.connect(_on_data_changed)
	Game.recipes_changed.connect(_on_data_changed)


## Tree only: hides the seed list, the side text, the magnifier and the hints.
func _apply_tree_only() -> void:
	var only := _tree_only.button_pressed
	for c in [_left, _sub, _hint]:
		c.visible = not only
	var lens_on := _lens_toggle.button_pressed and not only
	_lens_toggle.disabled = only
	_canvas.lens_enabled = lens_on
	_lens_box.visible = lens_on
	_side.visible = not only
	if _canvas.auto_fit:
		_canvas.call_deferred("fit")


func _box_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0e0b16")
	sb.border_color = Color("#3b3150")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(0)
	return sb


## Opens the menu on `id`, or on the last seed you looked at (else your newest spliced seed).
func open(id := "") -> void:
	_refresh_list()
	if id == "" or Game.get_seed(id).is_empty():
		id = root_id if not Game.get_seed(root_id).is_empty() else _default_seed()
	visible = true
	Audio.play(&"open")
	show_seed(id, false)  # (the canvas re-fits itself once the window has its real size)


func close_menu() -> void:
	visible = false


func show_seed(id: String, push := true) -> void:
	if Game.get_seed(id).is_empty():
		return
	if push and root_id != "" and root_id != id:
		_history.append(root_id)
	root_id = id
	_canvas.set_root(id)
	_select_in_list(id)
	var s := Game.get_seed(id)
	var tier: Array = SeedArt.rarity_tier(int(s.rarity))
	_header.text = "%s  ·  Rarity %d %s  ·  %s" % [s.name, int(s.rarity), tier[0], Game.tag_name(s.get("tag", ""))]
	_header.add_theme_color_override("font_color", (tier[1] as Color).lerp(Color.WHITE, 0.25))
	var drop: Dictionary = s.get("drop", {})
	_drop_label.text = "Drops %s:  %s%s   ·   %s" % [DropLogic.drop_name(s.name), DropLogic.describe(drop),
		"   (guessed from the name)" if drop.get("auto", false) else "   (set by you)",
		CategoryLogic.describe(s.get("category", {}))]
	_drop_label.add_theme_color_override("font_color", DropLogic.short_color(drop))
	_update_sub()
	_back_btn.disabled = _history.is_empty()


func _go_back() -> void:
	if _history.is_empty():
		return
	show_seed(_history.pop_back(), false)


func _default_seed() -> String:
	for i in range(Game.order.size() - 1, -1, -1):
		if not Game.seeds[Game.order[i]].get("parents", []).is_empty():
			return Game.order[i]
	return Game.order[0] if not Game.order.is_empty() else ""


func _update_sub() -> void:
	var t: Dictionary = _canvas.tree
	if t.is_empty():
		_sub.text = ""
	elif t.kids.is_empty():
		_sub.text = "A Tier 1 seed: it can't be made by splicing, it's one of the seeds you start with." if Game.get_seed(root_id).get("parents", []).is_empty() else "No recipe was found for this seed."
	else:
		var a := String(Game.get_seed(t.kids[0].id).name)
		var b := String(Game.get_seed(t.kids[1].id).name)
		_sub.text = "%s  +  %s  =  %s%s" % [a, b, Game.get_seed(root_id).name,
			"      (%d recipes: click the badge on a seed to switch)" % int(t.recipes) if int(t.recipes) > 1 else ""]


## "Splice it from: 3x Dirt Seed, 2x Stone Seed" - the Tier 1 seeds at the bottom of the tree,
## and the splice math above it.
func _update_totals() -> void:
	_update_sub()
	var m := _canvas.math()
	var top_name := String(Game.get_seed(root_id).get("name", ""))
	if m.splices == 0:
		_math.text = "%s is a Tier 1 seed: no splicing needed." % top_name if top_name != "" else ""
	else:
		_math.text = "To make %s from scratch: %d splice%s  (%d different recipe%s to discover)  ·  longest chain: %d splice%s in a row  ·  %d Tier 1 seeds%s" % [
			top_name, m.splices, "" if m.splices == 1 else "s", m.different, "" if m.different == 1 else "s",
			m.longest, "" if m.longest == 1 else "s", m.tier1,
			"  ·  %d farmed seed%s" % [m.farm, "" if m.farm == 1 else "s"] if m.farm > 0 else ""]
		if _canvas.farm_route:
			_math.text = "Shortest route (farming Farmable seeds): " + _math.text
	var counts := {}
	var farmed := {}
	var loops := false
	var total := 0
	for n in _canvas.nodes:
		if n.loop:
			loops = true
		elif n.kids.is_empty() and n.depth > 0:
			counts[n.id] = int(counts.get(n.id, 0)) + 1
			total += 1
			if n.farm:
				farmed[n.id] = true
	if counts.is_empty():
		_totals.text = ""
		return
	var ids := counts.keys()
	ids.sort_custom(func(a, b): return counts[a] > counts[b] or (counts[a] == counts[b] and String(Game.get_seed(a).name) < String(Game.get_seed(b).name)))
	var parts: PackedStringArray = []
	for id in ids:
		parts.append("%d× %s%s" % [counts[id], Game.get_seed(id).name, " (farm it)" if farmed.has(id) else ""])
	_totals.text = "%s (%d): %s%s" % ["Seeds to start from" if not farmed.is_empty() else "Tier 1 seeds needed", total, ", ".join(parts),
		"   ·   a looping recipe was cut off" if loops else ""]


func _on_data_changed() -> void:
	if not visible:
		return
	_refresh_list()
	if Game.get_seed(root_id).is_empty():
		show_seed(_default_seed(), false)
	else:
		_canvas.rebuild()


func _refresh_list() -> void:
	var q := _search.text.strip_edges().to_lower()
	var ids: Array = Game.order.duplicate()
	if q != "":
		ids = ids.filter(func(id): return String(Game.seeds[id].name).to_lower().contains(q))
	ids = SeedSort.sort_ids(SeedSort.filter_drops(SeedSort.filter_ids(ids, _filter.selected), _drop_filter.selected), _sort.selected)
	_list.clear()
	_list_ids.clear()
	for id in ids:
		var s: Dictionary = Game.seeds[id]
		var drop: Dictionary = s.get("drop", {})
		var i := _list.add_item("%s  ·  R%d" % [s.name, int(s.rarity)], SeedArt.texture_for(s))
		_list.set_item_custom_fg_color(i, (SeedArt.rarity_tier(int(s.rarity))[1] as Color).lerp(Color.WHITE, 0.35))
		_list.set_item_tooltip(i, "%s drops %s: %s" % [s.name, DropLogic.drop_name(s.name), DropLogic.describe(drop)])
		_list_ids.append(id)
	var total := Game.seeds.size()
	_count.text = "%d seeds" % _list_ids.size() if _list_ids.size() == total else "%d of %d seeds" % [_list_ids.size(), total]
	_select_in_list(root_id)


func _select_in_list(id: String) -> void:
	var i := _list_ids.find(id)
	if i >= 0:
		_list.select(i)
		_list.ensure_current_is_visible()
	else:
		_list.deselect_all()


func _on_list_selected(i: int) -> void:
	if i >= 0 and i < _list_ids.size():
		show_seed(_list_ids[i])


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
