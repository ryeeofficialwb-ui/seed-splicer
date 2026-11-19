class_name DropLogic
extends RefCounted
## What a seed gives when it is harvested: a BLOCK, a DECORATION or a BACKGROUND, whether that
## drop has COLLISION (you can't walk through it), whether touching it deals COLLISION DAMAGE, and
## whether it EMITS LIGHT (any kind can: a lava block, a torch, a glowing cave background).
##
## The drop is named after the seed ("Glass Seed" drops "Glass").
##
## IMPORTANT (for the game): the SEEDS THEMSELVES never deal damage. Not the seed item, not the
## planted sprout, not the grown crop. Only a seed's DROP can have the collision damage tag.
##
## A drop is a Dictionary:
##   kind      "block", "decoration" or "background" (a picture behind everything: never collides)
##   collision true = solid (blocks movement), false = you walk through it
##   damage    true = collision damage: touching it hurts. Always together with collision = true.
##   light     true = the drop EMITS LIGHT (blocks, decorations and backgrounds can all have it)
##   bg_tags   a background's checklist (BG_TAGS), only ever filled for kind = "background"
##   auto      true = guessed from the name by classify() below; false = set by hand (never overwritten)
##
## classify() is plain keyword logic, so it is easy to read and to change (the word lists
## below). It's only a first draft: you can change any drop yourself in the seed editor.

const KINDS: Array[String] = ["block", "decoration", "background"]
const KIND_NAMES := { "block": "Block", "decoration": "Decoration", "background": "Background" }
const KIND_PLURALS := { "block": "Blocks", "decoration": "Decorations", "background": "Backgrounds" }
## The checklist for backgrounds (tick any). "emits_light" is the same as drop.light: it is on this
## list too so a background's whole checklist is in one place.
const BG_TAGS: Array[String] = ["emits_light", "underground", "outdoors", "animated"]
const BG_TAG_NAMES := { "emits_light": "Emits light", "underground": "Cave / underground", "outdoors": "Sky / outdoors", "animated": "Animated" }
const LIGHT_COLOR := Color("#ffe066")
const DAMAGE_COLOR := Color("#ff6b6b")
const COLLISION_COLOR := Color("#7fb2ff")
const NO_COLLISION_COLOR := Color("#a19bb8")

## Plants, lights, furniture and backgrounds: drops that are decoration. By default they have no
## collision (you walk through them); the SOLID_DECORATION_WORDS below do collide.
const DECORATION_WORDS: Array[String] = [
	"grass", "flower", "rose", "daffodil", "tulip", "lily", "orchid", "fern", "vine", "moss", "bush", "shrub",
	"sapling", "sprout", "leaf", "leaves", "wheat", "herb", "weed", "reed", "petal", "stem",
	"berry", "yam", "potato", "carrot", "beet", "turnip", "onion", "fruit",
	"mushroom", "shroom", "fungus", "spore", "cap", "truffle", "firefly", "glimmercap", "flarecap",
	"torch", "lantern", "lamp", "candle", "chandelier",
	"door", "bucket", "well", "sign", "banner", "flag", "painting", "picture", "poster", "rug", "carpet",
	"curtain", "chair", "stool", "bed", "pot", "vase", "ladder", "rope", "chain", "clock", "mirror",
	"cobweb", "web", "mailbox",
	"shelf", "bookshelf", "table", "statue", "chest", "barrel", "crate", "box", "pillar", "column", "fence",
	"anvil", "furnace", "bench", "workbench", "loom", "sifter",
]
## A background is a picture behind the blocks.
const BACKGROUND_WORDS: Array[String] = ["background", "backdrop", "backwall", "wallpaper"]
## Drops that give off light.
const LIGHT_WORDS: Array[String] = [
	"torch", "lantern", "lamp", "candle", "chandelier", "lightbulb", "beacon", "glow", "glowing", "glowstone",
	"lava", "magma", "fire", "flame", "inferno", "molten", "ember", "blaze", "firefly", "glimmercap", "flarecap",
	"neon", "lumin", "luminous", "radiant", "sparkling", "shining",
]
## Background words that hint at the rest of the checklist.
const BG_UNDERGROUND_WORDS: Array[String] = ["cave", "cavern", "mine", "underground", "dungeon", "tunnel"]
const BG_OUTDOOR_WORDS: Array[String] = ["sky", "cloud", "forest", "meadow", "mountain", "sunset", "sunrise", "night", "stars"]
## Decoration you can't walk through.
const SOLID_DECORATION_WORDS: Array[String] = [
	"shelf", "bookshelf", "table", "statue", "chest", "barrel", "crate", "box", "pillar", "column", "fence",
	"anvil", "furnace", "bench", "workbench", "loom", "sifter",
]
## Blocks you can pass through (liquids, gases) - every other block collides.
const NONSOLID_BLOCK_WORDS: Array[String] = ["water", "steam", "smoke", "fog", "cloud", "gas", "vapor", "mist", "air"]
## Things that look dangerous: they get the collision damage tag (and so collision too).
const DANGER_WORDS: Array[String] = [
	"lava", "magma", "fire", "flame", "inferno", "molten", "blaze", "brimstone", "sulfur", "sulphur",
	"spike", "thorn", "cactus", "nettle", "thistle", "barbed", "blade", "razor", "saw",
	"acid", "poison", "toxic", "venom", "death", "deadly",
]
## Word endings that mean a plant or mushroom (decoration): Deathcap, Blueberry, Bluebloom...
const DECORATION_ENDINGS: Array[String] = ["cap", "berry", "shroom", "flower", "bloom", "weed", "grass", "leaf"]
const SUBSTRING_MIN := 6         ## words at least this long also match inside longer words ("sunflower")
const DANGER_SUBSTRING_MIN := 5  ## ...and for danger words ("magmatic", "thornbush")


static func classify(seed_name: String) -> Dictionary:
	var tokens := _tokens(seed_name)
	var kind := "block"
	if _has(tokens, BACKGROUND_WORDS, SUBSTRING_MIN):
		kind = "background"
	elif _has(tokens, DECORATION_WORDS, SUBSTRING_MIN) or _ends_with(tokens, DECORATION_ENDINGS):
		kind = "decoration"
	var damage := _has(tokens, DANGER_WORDS, DANGER_SUBSTRING_MIN)
	var collision := true
	if kind == "background":
		collision = false
		damage = false
	elif kind == "decoration":
		collision = _has(tokens, SOLID_DECORATION_WORDS, SUBSTRING_MIN)
	elif _has(tokens, NONSOLID_BLOCK_WORDS, 99):
		collision = false
	if damage:
		collision = true  # damage is dealt by colliding with it
	var light := _has(tokens, LIGHT_WORDS, DANGER_SUBSTRING_MIN)
	var bg_tags: Array = []
	if kind == "background":
		if light:
			bg_tags.append("emits_light")
		if _has(tokens, BG_UNDERGROUND_WORDS, 99):
			bg_tags.append("underground")
		if _has(tokens, BG_OUTDOOR_WORDS, 99):
			bg_tags.append("outdoors")
	return { "kind": kind, "collision": collision, "damage": damage, "light": light, "bg_tags": bg_tags, "auto": true }


## A clean drop from anything: keeps a valid Dictionary, otherwise guesses from the name.
static func sanitize(d: Variant, seed_name: String) -> Dictionary:
	if typeof(d) != TYPE_DICTIONARY or not KINDS.has(d.get("kind", "")):
		return classify(seed_name)
	var is_bg: bool = d.kind == "background"
	var damage := bool(d.get("damage", false)) and not is_bg
	var light := bool(d.get("light", false))
	var bg_tags: Array = []
	if is_bg:
		var given: Variant = d.get("bg_tags", [])
		for t in BG_TAGS:  # keeps the checklist's own order
			if t != "emits_light" and typeof(given) == TYPE_ARRAY and given.has(t):
				bg_tags.append(t)
		if typeof(given) == TYPE_ARRAY and given.has("emits_light"):
			light = true
		if light:
			bg_tags.push_front("emits_light")
	return {
		"kind": d.kind,
		"collision": (bool(d.get("collision", true)) or damage) and not is_bg,
		"damage": damage,
		"light": light,
		"bg_tags": bg_tags,
		"auto": bool(d.get("auto", false)),
	}


static func drop_name(seed_name: String) -> String:
	var n := seed_name.strip_edges()
	if n.ends_with(" Seed"):
		n = n.substr(0, n.length() - 5)
	return n.strip_edges()


static func collision_text(drop: Dictionary) -> String:
	return "Collision" if drop.get("collision", true) else "No collision"


## "Block · Collision · Collision damage · Emits light"   /   "Background · Cave / underground · Emits light"
static func describe(drop: Dictionary) -> String:
	var kind: String = drop.get("kind", "block")
	var parts: PackedStringArray = [KIND_NAMES.get(kind, "Block")]
	if kind == "background":
		for t in drop.get("bg_tags", []):
			parts.append(BG_TAG_NAMES.get(t, t))
		if drop.get("light", false) and not drop.get("bg_tags", []).has("emits_light"):
			parts.append("Emits light")
		return " · ".join(parts)
	parts.append(collision_text(drop))
	if drop.get("damage", false):
		parts.append("Collision damage")
	if drop.get("light", false):
		parts.append("Emits light")
	return " · ".join(parts)


## "Collision" / "No collision" / "Collision damage": the short form for lists.
static func short_text(drop: Dictionary) -> String:
	if drop.get("kind", "block") == "background":
		return "Background"
	if drop.get("damage", false):
		return "Collision damage"
	return collision_text(drop)


static func short_color(drop: Dictionary) -> Color:
	if drop.get("damage", false):
		return DAMAGE_COLOR
	return COLLISION_COLOR if drop.get("collision", true) else NO_COLLISION_COLOR


## The word lists, for the reference that is written into every export.
static func word_lists() -> Dictionary:
	return {
		"background_words": BACKGROUND_WORDS,
		"light_words": LIGHT_WORDS,
		"background_underground_words": BG_UNDERGROUND_WORDS,
		"background_outdoor_words": BG_OUTDOOR_WORDS,
		"decoration_words": DECORATION_WORDS,
		"solid_decoration_words": SOLID_DECORATION_WORDS,
		"non_solid_block_words": NONSOLID_BLOCK_WORDS,
		"danger_words": DANGER_WORDS,
		"decoration_word_endings": DECORATION_ENDINGS,
	}


static func _tokens(seed_name: String) -> PackedStringArray:
	var n := drop_name(seed_name).to_lower()
	var cleaned := ""
	for ch in n:
		cleaned += ch if (ch >= "a" and ch <= "z") else " "
	return cleaned.split(" ", false)


static func _ends_with(tokens: PackedStringArray, endings: Array[String]) -> bool:
	for t in tokens:
		for e in endings:
			if t.length() > e.length() and (t.ends_with(e) or t.ends_with(e + "s")):
				return true
	return false


static func _has(tokens: PackedStringArray, words: Array[String], substring_min: int) -> bool:
	for t in tokens:
		for w in words:
			if t == w or t == w + "s" or t == w + "es":
				return true
			if w.length() >= substring_min and t.contains(w):
				return true
	return false
