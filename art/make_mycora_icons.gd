extends SceneTree
## Cuts the designer's 7 Mycora orbs (assets/mycora/mycora_orbs_source.png, never changed) into
## small pixel icons: each orb is sampled back onto its pixel grid (about 13 px per art pixel in
## the source) as 14x14, centered in 16x16, saved at 1x and 2x.
##   godot --headless --path . --script art/make_mycora_icons.gd

const NAMES := ["gray", "green", "blue", "purple", "orange", "red", "yellow"]
const GRID := 14

func _init() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://assets/mycora/mycora_orbs_source.png"))
	src.convert(Image.FORMAT_RGBA8)
	var spans := []
	var start := -1
	for x in src.get_width():
		var any := false
		for y in range(350, 680):
			if src.get_pixel(x, y).a > 0.5:
				any = true
				break
		if any and start < 0:
			start = x
		elif not any and start >= 0:
			spans.append([start, x - 1])
			start = -1
	var sheet := Image.create_empty(16 * 7 * 4, 16 * 4, false, Image.FORMAT_RGBA8)
	for i in spans.size():
		var x0: int = spans[i][0]
		var x1: int = spans[i][1]
		var top := 9999
		var bot := -1
		for y in src.get_height():
			for x in range(x0, x1 + 1, 3):
				if src.get_pixel(x, y).a > 0.5:
					top = mini(top, y)
					bot = maxi(bot, y)
		var side := maxi(x1 - x0, bot - top) + 1
		var cx := (x0 + x1) / 2.0
		var cy := (top + bot) / 2.0
		var cell := side / float(GRID)
		var icon := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		for gy in GRID:
			for gx in GRID:
				# the most common opaque color in the middle of the cell
				var counts := {}
				var best := Color(0, 0, 0, 0)
				var best_n := 0
				var clear := 0
				for sy in range(3):
					for sx in range(3):
						var px := int(cx - side / 2.0 + (gx + 0.3 + sx * 0.2) * cell)
						var py := int(cy - side / 2.0 + (gy + 0.3 + sy * 0.2) * cell)
						var c := src.get_pixel(clampi(px, 0, src.get_width() - 1), clampi(py, 0, src.get_height() - 1))
						if c.a < 0.5:
							clear += 1
							continue
						var k := c.to_html(false).left(5)  # group near colors
						counts[k] = int(counts.get(k, 0)) + 1
						if counts[k] > best_n:
							best_n = counts[k]
							best = Color(c.r, c.g, c.b, 1.0)
				if clear < 5:
					icon.set_pixel(gx + 1, gy + 1, best)
		icon.save_png(ProjectSettings.globalize_path("res://assets/mycora/mycora_%s.png" % NAMES[i]))
		var big := icon.duplicate()
		big.resize(32, 32, Image.INTERPOLATE_NEAREST)
		big.save_png(ProjectSettings.globalize_path("res://assets/mycora/mycora_%s_2x.png" % NAMES[i]))
		var prev := icon.duplicate()
		prev.resize(64, 64, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(prev, Rect2i(0, 0, 64, 64), Vector2i(i * 64, 0))
	sheet.save_png(OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://mycora_preview.png")
	print("orbs: ", spans.size())
	quit()
