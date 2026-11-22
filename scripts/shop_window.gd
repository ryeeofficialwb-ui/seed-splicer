class_name ShopWindow
extends Modal
## The Shop (the gold button in the top bar): buy booster packs of seed cards.
##   1, 3 or 5 packs at once, Bank.PACK_PRICE Mycoras each. A pack holds 5 cards; the last one is
##   always Rare or better. A NEW seed starts making Mycoras; a duplicate pays 5 minutes of them.
## Opening: the pack shakes and tears open, five cards land face down: click each to flip it
## (or Reveal all). Several packs open one after another, then a summary shows every card.
## Everything is decided when you pay (Bank.open_packs): the show only reveals it.

const CARD := Vector2(192, 264)      ## a revealed card (the card art at 3x)
const SMALL_CARD := Vector2(128, 176)  ## a card in the summary (2x)
const STAGE := Vector2(1080, 440)

var _shop_view: VBoxContainer
var _open_view: VBoxContainer
var _sum_view: VBoxContainer
var _balance: Label
var _buy_btns: Array[Button] = []
var _odds: Label
var _rate: Label
var _stage: Control
var _pack_pic: Control
var _cards_row: Control
var _status: Label
var _reveal_btn: Button
var _next_btn: Button
var _sum_title: Label
var _sum_grid: GridContainer

var _result := {}
var _pack_i := 0
var _cards: Array[Control] = []
var _flipped := 0
var _busy := false


func _ready() -> void:
	_init_modal("Shop", Vector2(STAGE.x + 40, 0))
	set_title("Shop  ·  Booster Packs")

	# --- buying
	_shop_view = VBoxContainer.new()
	_shop_view.add_theme_constant_override("separation", 10)
	body.add_child(_shop_view)
	var bal_row := HBoxContainer.new()
	bal_row.add_theme_constant_override("separation", 6)
	_shop_view.add_child(bal_row)
	var micon := TextureRect.new()
	micon.texture = MycoraHud.ICON
	micon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	bal_row.add_child(micon)
	_balance = Label.new()
	_balance.add_theme_font_size_override("font_size", UiKit.BIG)
	_balance.add_theme_color_override("font_color", Mycora.COLOR)
	bal_row.add_child(_balance)
	_shop_view.add_child(note("Each pack holds %d seed cards from your game (rarer seeds turn up less often). The last card is always Rare or better. A new seed starts making Mycoras; a seed you already have pays 5 minutes of its Mycoras." % Bank.CARDS_PER_PACK))

	var offers := HBoxContainer.new()
	offers.add_theme_constant_override("separation", 12)
	offers.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_view.add_child(offers)
	for n in Bank.PACK_COUNTS:
		offers.add_child(_offer(n))
	_rate = note()
	_shop_view.add_child(_rate)
	_odds = note("", Color(0.8, 0.77, 0.9))
	_shop_view.add_child(_odds)

	# --- opening
	_open_view = VBoxContainer.new()
	_open_view.add_theme_constant_override("separation", 8)
	_open_view.visible = false
	body.add_child(_open_view)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.theme_type_variation = &"HeadingLabel"
	_open_view.add_child(_status)
	_stage = Control.new()
	_stage.custom_minimum_size = STAGE
	_stage.clip_contents = true
	_open_view.add_child(_stage)
	_cards_row = Control.new()
	_cards_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_cards_row)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 8)
	_open_view.add_child(btns)
	_reveal_btn = Button.new()
	_reveal_btn.text = "Reveal all"
	_reveal_btn.custom_minimum_size = Vector2(220, 0)
	_reveal_btn.pressed.connect(_reveal_all)
	btns.add_child(_reveal_btn)
	_next_btn = Button.new()
	_next_btn.theme_type_variation = &"ShopButton"
	_next_btn.custom_minimum_size = Vector2(260, 0)
	_next_btn.pressed.connect(_next)
	btns.add_child(_next_btn)

	# --- summary after several packs
	_sum_view = VBoxContainer.new()
	_sum_view.add_theme_constant_override("separation", 10)
	_sum_view.visible = false
	body.add_child(_sum_view)
	_sum_title = Label.new()
	_sum_title.theme_type_variation = &"HeadingLabel"
	_sum_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sum_view.add_child(_sum_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(STAGE.x, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sum_view.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_sum_grid = GridContainer.new()
	_sum_grid.columns = 7
	_sum_grid.add_theme_constant_override("h_separation", 8)
	_sum_grid.add_theme_constant_override("v_separation", 8)
	center.add_child(_sum_grid)
	var done := Button.new()
	done.text = "Back to the Shop"
	done.theme_type_variation = &"ShopButton"
	done.pressed.connect(_show_shop)
	_sum_view.add_child(done)

	Bank.changed.connect(_update)


func open() -> void:
	_show_shop()
	super()


func close_dialog() -> void:
	if _busy:
		return  # let the pack finish tearing open
	super()


## One offer: the packs fanned out, "3 Packs", and the price button.
func _offer(n: int) -> Control:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"CardBase"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	tile.add_child(col)
	var fan := Control.new()
	fan.custom_minimum_size = Vector2(300, 132)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fan)
	var tex := UiKit.tex("pack")
	var spread := 24.0
	for i in n:
		var p := TextureRect.new()
		p.texture = tex
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.size = tex.get_size()
		var off := (i - (n - 1) / 2.0) * spread
		p.position = Vector2(roundf(150 - tex.get_size().x / 2.0 + off), 132 - tex.get_size().y - absf(off) * 0.1)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fan.add_child(p)
	var name_l := Label.new()
	name_l.text = "%d Pack%s  ·  %d cards" % [n, "" if n == 1 else "s", n * Bank.CARDS_PER_PACK]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_l)
	var b := Button.new()
	b.theme_type_variation = &"ShopButton"
	b.icon = MycoraHud.ICON
	b.text = Bank.fmt(Bank.packs_price(n))
	b.tooltip_text = "Open %d pack%s for %s Mycoras" % [n, "" if n == 1 else "s", Bank.fmt(Bank.packs_price(n))]
	b.set_meta(&"packs", n)
	b.pressed.connect(_buy.bind(n))
	col.add_child(b)
	_buy_btns.append(b)
	return tile


func _update() -> void:
	if not is_inside_tree():
		return
	_balance.text = Bank.fmt(Bank.mycoras)
	var empty := Bank.pack_pool().is_empty()
	for b in _buy_btns:
		var n: int = b.get_meta(&"packs")
		b.disabled = _busy or empty or Bank.mycoras < Bank.packs_price(n)
	var pool := Bank.pack_pool()
	var have := pool.filter(func(p): return Bank.unlocked.has(p.id)).size()
	_rate.text = "Unlocked %d of %d seeds  ·  making %s Mycoras every 3 seconds (%s a minute, before weather)" % [
		have, pool.size(), Bank.fmt(Bank.rate_per_tick()), Bank.fmt(Bank.rate_per_tick() * 20.0)]
	if empty:
		_odds.text = "Splice a seed first: packs only hold seeds in your game."
		return
	var tiers := {}
	for p in pool:
		var t: String = SeedArt.rarity_tier(int(Game.seeds[p.id].rarity))[0]
		tiers[t] = float(tiers.get(t, 0.0)) + Bank.chance_of(p.id)
	var parts := PackedStringArray()
	for t in ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic"]:
		if tiers.has(t):
			parts.append("%s %s%%" % [t, _pct(tiers[t])])
	_odds.text = "Cards 1-4:  " + "  ·  ".join(parts) + "\nCard 5:  always Rare or better" + ("" if not Bank.pack_pool(true).is_empty() else " (once your game has a Rare seed)")


static func _pct(p: float) -> String:
	var v := p * 100.0
	return "%.1f" % v if v >= 1.0 else "%.2f" % v


func _show_shop() -> void:
	_busy = false
	_shop_view.visible = true
	_open_view.visible = false
	_sum_view.visible = false
	_update()


# --- opening -------------------------------------------------------------------------------------

func _buy(n: int) -> void:
	if _busy:
		return
	var r := Bank.open_packs(n)
	if not r.ok:
		Audio.play(&"error")
		_odds.text = r.error
		return
	Audio.play(&"open")
	_result = r
	_pack_i = 0
	_shop_view.visible = false
	_open_view.visible = true
	_open_pack()


func _open_pack() -> void:
	_busy = true
	_update()
	for c in _cards_row.get_children():
		c.queue_free()
	_cards.clear()
	_flipped = 0
	var total: int = _result.packs.size()
	_status.text = "Pack %d of %d" % [_pack_i + 1, total] if total > 1 else "Your pack"
	_reveal_btn.disabled = true
	_next_btn.disabled = true
	_next_btn.text = "Next pack" if _pack_i < total - 1 else ("See all cards" if total > 1 else "Done")

	# the pack: shake, then tear the top off
	var tex := UiKit.tex("pack")
	var zoom := 3.0
	var psize := tex.get_size() * zoom
	_pack_pic = Control.new()
	_pack_pic.size = psize
	_pack_pic.position = ((STAGE - psize) / 2.0).round()
	_pack_pic.pivot_offset = psize / 2.0
	_stage.add_child(_pack_pic)
	var tear_y := 18.0  # texture pixels: the crimp above the dotted tear line
	var top := _atlas_rect(tex, Rect2(0, 0, tex.get_size().x, tear_y), zoom)
	var rest := _atlas_rect(tex, Rect2(0, tear_y, tex.get_size().x, tex.get_size().y - tear_y), zoom)
	rest.position.y = tear_y * zoom
	_pack_pic.add_child(rest)
	_pack_pic.add_child(top)
	_pack_pic.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_pack_pic, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in 6:
		tw.tween_property(_pack_pic, "rotation", deg_to_rad(4.0 if k % 2 == 0 else -4.0), 0.06)
	tw.tween_property(_pack_pic, "rotation", 0.0, 0.05)
	await tw.finished
	if not is_inside_tree():
		return
	Audio.play(&"splice")
	var tear := create_tween().set_parallel()
	tear.tween_property(top, "position", top.position + Vector2(90, -140), 0.35).set_ease(Tween.EASE_IN)
	tear.tween_property(top, "rotation", deg_to_rad(35), 0.35)
	tear.tween_property(rest, "position:y", rest.position.y + 260, 0.45).set_delay(0.15).set_ease(Tween.EASE_IN)
	tear.tween_property(_pack_pic, "modulate:a", 0.0, 0.3).set_delay(0.3)
	await tear.finished
	if not is_inside_tree():
		return
	_pack_pic.queue_free()

	# five cards fly out, face down
	var cards: Array = _result.packs[_pack_i]
	var gap := 12.0
	var row_w := cards.size() * CARD.x + (cards.size() - 1) * gap
	var x0 := roundf((STAGE.x - row_w) / 2.0)
	var y := roundf((STAGE.y - CARD.y) / 2.0)
	var deal := create_tween().set_parallel()
	for i in cards.size():
		var c := _card_back(cards[i])
		c.position = Vector2((STAGE.x - CARD.x) / 2.0, STAGE.y)
		_cards_row.add_child(c)
		_cards.append(c)
		deal.tween_property(c, "position", Vector2(x0 + i * (CARD.x + gap), y), 0.3).set_delay(i * 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await deal.finished
	_busy = false
	_reveal_btn.disabled = false


func _atlas_rect(tex: Texture2D, region: Rect2, zoom: float) -> TextureRect:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = region
	var r := TextureRect.new()
	r.texture = a
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = region.size * zoom
	r.pivot_offset = r.size / 2.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A face-down card: click it to flip.
func _card_back(card: Dictionary) -> Control:
	var root := Control.new()
	root.size = CARD
	root.pivot_offset = CARD / 2.0
	root.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	root.set_meta(&"card", card)
	var back := TextureRect.new()
	back.name = "Back"
	back.texture = UiKit.tex("card_back")
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.size = CARD
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	if card.rare_slot:  # the guaranteed card shimmers gold before you flip it
		var hint := Label.new()
		hint.text = "RARE+"
		hint.add_theme_color_override("font_color", UiKit.GOLD)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size = Vector2(CARD.x, 32)
		hint.position = Vector2(0, CARD.y + 4)
		root.add_child(hint)
	root.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_flip(root))
	return root


func _flip(root: Control) -> void:
	if root.has_meta(&"flipped"):
		return
	root.set_meta(&"flipped", true)
	root.mouse_default_cursor_shape = Control.CURSOR_ARROW
	var card: Dictionary = root.get_meta(&"card")
	var tw := create_tween()
	tw.tween_property(root, "scale:x", 0.0, 0.12)
	await tw.finished
	for c in root.get_children():
		c.queue_free()
	var face := card_face(card, CARD)
	root.add_child(face)
	var s: Dictionary = Game.seeds.get(card.id, {})
	var rarity := int(s.get("rarity", 1))
	if rarity >= Bank.RARE_AT:
		_glow(root, SeedArt.rarity_tier(rarity)[1])
		Audio.play(&"discover")
	else:
		Audio.play(&"success" if card.new else &"pickup")
	var tw2 := create_tween()
	tw2.tween_property(root, "scale:x", 1.0, 0.12)
	_flipped += 1
	if _flipped >= _cards.size():
		_reveal_btn.disabled = true
		_next_btn.disabled = false


## A pulsing glow behind a Rare-or-better card.
func _glow(root: Control, color: Color) -> void:
	var g := ColorRect.new()
	g.color = Color(color, 0.0)
	g.position = Vector2(-6, -6)
	g.size = root.size + Vector2(12, 12)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.show_behind_parent = true
	root.add_child(g)
	var tw := g.create_tween().set_loops()
	tw.tween_property(g, "color:a", 0.55, 0.5)
	tw.tween_property(g, "color:a", 0.15, 0.5)


func _reveal_all() -> void:
	for i in _cards.size():
		if not _cards[i].has_meta(&"flipped"):
			_flip(_cards[i])
			await get_tree().create_timer(0.12).timeout


func _next() -> void:
	_pack_i += 1
	if _pack_i < _result.packs.size():
		_open_pack()
	elif _result.packs.size() > 1:
		_show_summary()
	else:
		_show_shop()


func _show_summary() -> void:
	_open_view.visible = false
	_sum_view.visible = true
	for c in _sum_grid.get_children():
		c.queue_free()
	var all: Array = []
	for p in _result.packs:
		all.append_array(p)
	all.sort_custom(func(a, b):
		if a.new != b.new:
			return a.new
		return int(Game.seeds[a.id].rarity) > int(Game.seeds[b.id].rarity))
	for card in all:
		_sum_grid.add_child(card_face(card, SMALL_CARD))
	var dupes: int = all.size() - int(_result.new_count)
	_sum_title.text = "%d packs  ·  %d new seed%s  ·  %d duplicate%s (+%s Mycoras)" % [_result.packs.size(),
		_result.new_count, "" if _result.new_count == 1 else "s", dupes, "" if dupes == 1 else "s", Bank.fmt(_result.payout)]


## A revealed card: dark body, a border in the seed's rarity color, the seed, its name and what
## you got (NEW or the Mycoras a duplicate paid). Used by the reveal and the summary.
static func card_face(card: Dictionary, card_size: Vector2) -> Control:
	var s: Dictionary = Game.seeds.get(card.id, {})
	var rarity := int(s.get("rarity", 1))
	var tier: Array = SeedArt.rarity_tier(rarity)
	var small := card_size.x < 150.0
	var root := Control.new()
	root.custom_minimum_size = card_size
	root.size = card_size
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.tooltip_text = "%s  ·  R%d %s\n%s" % [s.get("name", "?"), rarity, tier[0],
		"NEW: it makes Mycoras now" if card.new else "Duplicate: +%s Mycoras" % Bank.fmt(card.payout)]
	var base := Panel.new()
	base.theme_type_variation = &"CardBase"
	base.add_theme_stylebox_override("panel", UiKit.box("card_base", 5, [0, 0, 0, 0]))
	base.size = card_size
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)
	var border := UiKit.box("card_border", 5, [0, 0, 0, 0])
	border.modulate_color = tier[1]
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", border)
	frame.size = card_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	var pic := PixelPicture.new()
	pic.texture = SeedArt.texture_for(s) if not s.is_empty() else null
	var pic_size := 64.0 if small else 96.0
	pic.size = Vector2(pic_size, pic_size)
	pic.position = Vector2(roundf((card_size.x - pic_size) / 2.0), 12.0 if small else 18.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pic)
	if small:
		var badge := Label.new()
		badge.text = "NEW" if card.new else "+%s" % Bank.fmt(card.payout)
		badge.add_theme_color_override("font_color", UiKit.ACCENT if card.new else UiKit.GOLD)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.size = Vector2(card_size.x, 32)
		badge.position = Vector2(0, card_size.y - 92)
		badge.clip_text = true
		root.add_child(badge)
		var r := Label.new()
		r.text = "R%d" % rarity
		r.add_theme_color_override("font_color", tier[1])
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.size = Vector2(card_size.x, 32)
		r.position = Vector2(0, card_size.y - 54)
		root.add_child(r)
		return root
	var name_l := Label.new()
	name_l.text = String(s.get("name", "?")).trim_suffix(" Seed")
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.max_lines_visible = 2
	name_l.size = Vector2(card_size.x - 20, 70)  # two lines of 26 px text, room for the stroke
	name_l.position = Vector2(10, 122)
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(name_l)
	var tier_l := Label.new()
	tier_l.text = "%s  R%d" % [tier[0], rarity]
	tier_l.add_theme_color_override("font_color", tier[1])
	tier_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_l.size = Vector2(card_size.x, 32)
	tier_l.position = Vector2(0, 206)
	root.add_child(tier_l)
	var badge2 := Label.new()
	badge2.text = "NEW!" if card.new else "+%s" % Bank.fmt(card.payout)
	badge2.add_theme_color_override("font_color", UiKit.ACCENT if card.new else UiKit.GOLD)
	badge2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge2.size = Vector2(card_size.x, 32)
	badge2.position = Vector2(0, card_size.y + 4)
	root.add_child(badge2)
	return root
