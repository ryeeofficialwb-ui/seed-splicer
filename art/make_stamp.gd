extends SceneTree
## Makes the approval stamp from art/../assets/stamp/approval_logo.png (the logo, never changed):
## the black background becomes see-through, the picture is cropped to the flower and saved
## square at 64 / 24 px.   godot --headless --path . --script art/make_stamp.gd

func _init() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://assets/stamp/approval_logo.png"))
	src.convert(Image.FORMAT_RGBA8)
	var w := src.get_width()
	var h := src.get_height()
	var lo := Vector2i(w, h)
	var hi := Vector2i(-1, -1)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			var v := maxf(c.r, maxf(c.g, c.b))
			# near black -> clear; a short ramp keeps the glow soft
			var a := clampf((v - 0.10) / 0.18, 0.0, 1.0)
			c.a = a
			src.set_pixel(x, y, c)
			if a > 0.3:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var side := maxi(hi.x - lo.x, hi.y - lo.y) + 1
	var mid := (lo + hi) / 2
	var sq := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	sq.blit_rect(src, Rect2i(mid.x - side / 2, mid.y - side / 2, side, side), Vector2i.ZERO)
	for s in [64, 24]:
		var out := sq.duplicate()
		out.resize(s, s, Image.INTERPOLATE_LANCZOS)
		out.save_png(ProjectSettings.globalize_path("res://assets/stamp/approval_stamp_%d.png" % s))
	print("stamp ", lo, " ", hi, " side ", side)
	quit()
