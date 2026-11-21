class_name ChestWindow
extends Modal
## The Seed Chest (top bar): pay Bank.CHEST_PRICE Mycoras, a CS2-style reel spins and stops on a
## seed. A new one starts making Mycoras; one you already had pays 5 minutes of its Mycoras.

const ITEM := 84.0
const REEL_W := 680.0
const ITEMS := 48
const WIN_AT := 40
const SPIN_TIME := 4.6

var _reel: Control
var _strip: Control
var _open_btn: Button
var _balance: Label
var _result: Label
var _odds: Label
var _rate: Label
var _spinning := false


func _ready() -> void:
	_init_modal("Seed Chest", Vector2(REEL_W + 40, 0))
	body.add_child(note("Every seed in your game except the 4 base seeds can come out (a rarer seed less often). A new seed starts making Mycoras; one you already have pays 5 minutes of its Mycoras."))
	_balance = Label.new()
	_balance.add_theme_font_size_override("font_size", 18)
	body.add_child(_balance)

	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0e0b16")
	sb.border_color = Color("#3b3150")
	sb.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", sb)
	body.add_child(frame)
	_reel = Control.new()
	_reel.custom_minimum_size = Vector2(REEL_W, ITEM + 24)
	_reel.clip_contents = true
	frame.add_child(_reel)
	_strip = Control.new()
	_reel.add_child(_strip)
	var marker := ColorRect.new()  # the line the reel stops on
	marker.color = Color("#a6ff6e")
	marker.size = Vector2(3, ITEM + 24)
	marker.position = Vector2(REEL_W / 2.0 - 1.5, 0)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reel.add_child(marker)

	_open_btn = Button.new()
	_open_btn.custom_minimum_size = Vector2(0, 40)
	_open_btn.add_theme_font_size_override("font_size", 18)
	_open_btn.pressed.connect(_spin)
	body.add_child(_open_btn)
	_result = Label.new()
	_result.add_theme_font_size_override("font_size", 16)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_result)
	_rate = note()
	body.add_child(_rate)
	_odds = note("", Color(0.65, 0.62, 0.75))
	body.add_child(_odds)
	Bank.changed.connect(_update)


func open() -> void:
	_result.text = ""
	_fill_idle()
	_update()
	super()


func _update() -> void:
	if not is_inside_tree():
		return
	_balance.text = "You have %s Mycoras" % Bank.fmt(Bank.mycoras)
	_open_btn.text = "Open a chest  ·  %s Mycoras" % Bank.fmt(Bank.CHEST_PRICE)
	_open_btn.disabled = _spinning or Bank.mycoras < Bank.CHEST_PRICE or Bank.chest_pool().is_empty()
	var pool := Bank.chest_pool()
	var have := pool.filter(func(p): return Bank.unlocked.has(p.id)).size()
	_rate.text = "Unlocked %d of %d seeds  ·  making %s Mycoras every 3 seconds (%s a minute, before weather)" % [
		have, pool.size(), Bank.fmt(Bank.rate_per_tick()), Bank.fmt(Bank.rate_per_tick() * 20.0)]
	# chances by rarity tier
	var tiers := {}
	for p in pool:
		var t: String = SeedArt.rarity_tier(int(Game.seeds[p.id].rarity))[0]
		tiers[t] = float(tiers.get(t, 0.0)) + Bank.chance_of(p.id)
	var parts := PackedStringArray()
	for t in ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic"]:
		if tiers.has(t):
			parts.append("%s %s%%" % [t, _pct(tiers[t])])
	_odds.text = "Chances:  " + "  ·  ".join(parts)


static func _pct(p: float) -> String:
	var v := p * 100.0
	return "%.1f" % v if v >= 1.0 else "%.2f" % v


## A card for the reel: the seed picture on its tier color.
func _card(id: String) -> Control:
	var s: Dictionary = Game.seeds[id]
	var tier: Array = SeedArt.rarity_tier(int(s.rarity))
	var c := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = (tier[1] as Color).darkened(0.72)
	sb.border_color = tier[1]
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(3)
	c.add_theme_stylebox_override("panel", sb)
	c.size = Vector2(ITEM - 6, ITEM + 12)
	var pic := TextureRect.new()
	pic.texture = SeedArt.texture_for(s)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.size = Vector2(64, 64)
	pic.position = Vector2((ITEM - 6 - 64) / 2.0, 4)
	c.add_child(pic)
	var l := Label.new()
	l.text = String(s.name).trim_suffix(" Seed")
	l.add_theme_font_size_override("font_size", 10)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(ITEM - 8, 14)
	l.position = Vector2(1, 70)
	c.add_child(l)
	return c


func _fill(ids: Array) -> void:
	for ch in _strip.get_children():
		ch.queue_free()
	for i in ids.size():
		var c := _card(ids[i])
		c.position = Vector2(i * ITEM + 3, 6)
		_strip.add_child(c)


func _fill_idle() -> void:
	if _spinning or Bank.chest_pool().is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ids: Array = []
	for i in 10:
		ids.append(Bank.pick(rng))
	_fill(ids)
	_strip.position = Vector2.ZERO


func _spin() -> void:
	if _spinning:
		return
	var res := Bank.open_chest()
	if not res.ok:
		_result.text = res.error
		Audio.play(&"error")
		return
	_spinning = true
	_update()
	_result.text = ""
	Audio.play(&"click")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ids: Array = []
	for i in ITEMS:
		ids.append(res.id if i == WIN_AT else Bank.pick(rng))
	_fill(ids)
	_strip.position = Vector2.ZERO
	# stop somewhere inside the winning card, not always dead center
	var land := WIN_AT * ITEM + ITEM / 2.0 - REEL_W / 2.0 + rng.randf_range(-ITEM * 0.35, ITEM * 0.35)
	var tw := create_tween()
	tw.tween_property(_strip, "position:x", -land, SPIN_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw.finished
	_spinning = false
	var s: Dictionary = Game.seeds[res.id]
	if res.new:
		_result.text = "UNLOCKED  %s  ·  R%d  ·  now makes %s Mycoras every 3 seconds" % [s.name, int(s.rarity), Bank.fmt(Bank.seed_rate(s))]
		_result.add_theme_color_override("font_color", (SeedArt.rarity_tier(int(s.rarity))[1] as Color).lerp(Color.WHITE, 0.3))
		Audio.play(&"discover")
	else:
		_result.text = "%s again  ·  duplicate: +%s Mycoras (5 minutes of it)" % [s.name, Bank.fmt(res.payout)]
		_result.add_theme_color_override("font_color", Color("#ffc94a"))
		Audio.play(&"success")
	_update()
