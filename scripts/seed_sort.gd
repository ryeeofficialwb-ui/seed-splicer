class_name SeedSort
extends RefCounted
## The sort + filter menus used by both the Seeds panel and the Recipe Tree list:
## sort by date / rarity / name / tag / collision, filter by tag and by what the seed drops.

const NEWEST := 0
const OLDEST := 1
const RARITY := 2
const NAME := 3
const BOUNTIFUL_FIRST := 4
const FARMABLE_FIRST := 5
const NOT_FARMABLE_FIRST := 6
const COLLISION_FIRST := 7
const NO_COLLISION_FIRST := 8
const DAMAGE_FIRST := 9

const SORT_NAMES: Array[String] = ["Newest", "Oldest", "Rarity", "Name", "Bountiful first", "Farmable first",
	"Not Farmable first", "Collision first", "No collision first", "Collision damage first"]
const TAG_FIRST := { 4: "bountiful", 5: "farmable", 6: "not_farmable" }
const TAG_PREFERENCE: Array[String] = ["bountiful", "farmable", "not_farmable"]  # best to worst

## "Drops:" filter entries
const DROP_ALL := 0
const DROP_BLOCKS := 1
const DROP_DECORATIONS := 2
const DROP_COLLISION := 3
const DROP_NO_COLLISION := 4
const DROP_DAMAGE := 5
const DROP_BACKGROUNDS := 6
const DROP_LIGHT := 7
const DROP_FILTER_NAMES: Array[String] = ["Drops: anything", "Drops: blocks", "Drops: decorations",
	"Drops: collision", "Drops: no collision", "Drops: collision damage", "Drops: backgrounds", "Drops: emits light"]


## A dropdown that shrinks with its panel (the chosen item is cut short) instead of being as wide as
## its longest item: with 26 px text that would make the Seeds panel too wide to resize.
static func _option() -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.clip_text = true
	o.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return o


static func make_sort_button(default_mode: int) -> OptionButton:
	var o := _option()
	for s in SORT_NAMES:
		o.add_item(s)
	o.select(default_mode)
	o.tooltip_text = "How to order the list"
	return o


static func make_filter_button() -> OptionButton:
	var o := _option()
	o.add_item("Show: all tags")
	for tag in Game.TAGS:
		o.add_item("Show only: " + Game.tag_name(tag))
	o.tooltip_text = "Only list seeds with one tag"
	return o


static func make_drop_filter_button() -> OptionButton:
	var o := _option()
	for s in DROP_FILTER_NAMES:
		o.add_item(s)
	o.tooltip_text = "Only list seeds by what they drop: block or decoration, with or without collision"
	return o


## `filter_index` is the selected item of make_filter_button() (0 = all tags).
static func filter_ids(ids: Array, filter_index: int) -> Array:
	if filter_index <= 0:
		return ids
	var only: String = Game.TAGS[filter_index - 1]
	return ids.filter(func(id): return Game.seeds[id].get("tag", "farmable") == only)


## `filter_index` is the selected item of make_drop_filter_button() (0 = anything).
static func filter_drops(ids: Array, filter_index: int) -> Array:
	if filter_index <= DROP_ALL:
		return ids
	return ids.filter(func(id):
		var d: Dictionary = Game.seeds[id].get("drop", {})
		match filter_index:
			DROP_BLOCKS: return d.get("kind", "block") == "block"
			DROP_DECORATIONS: return d.get("kind", "block") == "decoration"
			DROP_COLLISION: return d.get("collision", true) and d.get("kind", "block") != "background"
			DROP_NO_COLLISION: return not d.get("collision", true)
			DROP_DAMAGE: return d.get("damage", false)
			DROP_BACKGROUNDS: return d.get("kind", "block") == "background"
			DROP_LIGHT: return d.get("light", false)
		return true)


## Returns `ids` ordered by `mode` (a SeedSort constant / the sort menu's selected index).
static func sort_ids(ids: Array, mode: int) -> Array:
	var out := ids.duplicate()
	match mode:
		NEWEST:
			out.reverse()  # Game.order is oldest first
		OLDEST:
			pass
		RARITY:
			out.sort_custom(func(a, b): return int(Game.seeds[a].rarity) > int(Game.seeds[b].rarity))
		NAME:
			out.sort_custom(func(a, b): return _by_name(a, b))
		BOUNTIFUL_FIRST, FARMABLE_FIRST, NOT_FARMABLE_FIRST:
			# the chosen tag first, then the others best to worst; inside each group the
			# rarest seeds first, then by name
			var rank := { TAG_FIRST[mode]: 0 }
			for t in TAG_PREFERENCE:
				if not rank.has(t):
					rank[t] = rank.size()
			out.sort_custom(func(a, b):
				var ra: int = rank.get(Game.seeds[a].get("tag", "farmable"), 9)
				var rb: int = rank.get(Game.seeds[b].get("tag", "farmable"), 9)
				if ra != rb:
					return ra < rb
				return _rarest_then_name(a, b))
		COLLISION_FIRST, NO_COLLISION_FIRST:
			# groups: with/without collision (the chosen one first); inside each group the
			# rarest seeds first, then by name
			var want_collision := mode == COLLISION_FIRST
			out.sort_custom(func(a, b):
				var ca: bool = Game.seeds[a].get("drop", {}).get("collision", true)
				var cb: bool = Game.seeds[b].get("drop", {}).get("collision", true)
				if ca != cb:
					return ca == want_collision
				return _rarest_then_name(a, b))
		DAMAGE_FIRST:
			# collision damage first, then the other seeds that have collision, then those without
			out.sort_custom(func(a, b):
				var da: Dictionary = Game.seeds[a].get("drop", {})
				var db: Dictionary = Game.seeds[b].get("drop", {})
				var ra: int = 0 if da.get("damage", false) else (1 if da.get("collision", true) else 2)
				var rb: int = 0 if db.get("damage", false) else (1 if db.get("collision", true) else 2)
				if ra != rb:
					return ra < rb
				return _rarest_then_name(a, b))
	return out


static func _rarest_then_name(a: String, b: String) -> bool:
	var xa := int(Game.seeds[a].rarity)
	var xb := int(Game.seeds[b].rarity)
	if xa != xb:
		return xa > xb
	return _by_name(a, b)


static func _by_name(a: String, b: String) -> bool:
	return String(Game.seeds[a].name).naturalnocasecmp_to(Game.seeds[b].name) < 0
