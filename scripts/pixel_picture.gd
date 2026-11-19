class_name PixelPicture
extends Control
## Shows pixel art so every art pixel is the SAME whole number of screen pixels (1, 2, 3...).
## A TextureRect stretches to its box: a 32 px picture in a 51 px box, or the window being 1.125x
## the game's base size, makes some pixels 1 screen pixel wide and others 2 (lumpy, uneven art).
## This works out how many real screen pixels the box has (window scale and UI scale included),
## picks the largest whole zoom that fits, and lines the picture up with the screen's pixels.

@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


## Screen pixels per art pixel the picture is drawn at right now (0 = nothing to draw).
func zoom() -> int:
	if texture == null or not is_inside_tree():
		return 0
	var s := _screen_scale()
	var t := texture.get_size()
	return maxi(1, floori(minf(size.x * s / t.x, size.y * s / t.y) + 0.001))


func _screen_scale() -> float:
	return (get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().x


func _draw() -> void:
	if texture == null:
		return
	var xf := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var s := xf.get_scale().x
	var n := zoom()
	var on_screen := texture.get_size() * n  # in screen pixels
	var corner := (xf * Vector2.ZERO + (size * s - on_screen) / 2.0).round()  # whole screen pixel
	var local := xf.affine_inverse() * corner
	draw_texture_rect(texture, Rect2(local, on_screen / s), false)
