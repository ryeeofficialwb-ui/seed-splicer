class_name SeedNames
extends RefCounted
## Name ideas for a new splice. Not "parent word + parent word": a name is built from what the new
## seed IS, using the parents only as clues:
##   its MATERIALS (soil, stone, fire, plant...)  -> material nouns   (Shale, Silt, Cinder, Frond...)
##   its COLORS (the two parents' colors)         -> color words      (Cobalt, Russet, Jade...)
##   word pieces that fit those materials         -> new compounds    (Gloomwort, Brimvein, Frostcap...)
##   its RARITY                                    -> rare words       (Ancient, Hollow ... Celestial, Astral)
##                                                   and, for Mythic+, an invented name (Velmora, Quorith...)
## Every idea is checked against the seeds you already have and never reuses the parents' own words.
## Each call shuffles differently, so "Another idea" keeps finding new ones.

const MATERIAL_NOUNS := {
	"soil": ["Loam", "Silt", "Marl", "Humus", "Peat", "Tilth", "Clay", "Dune"],
	"stone": ["Shale", "Flint", "Slate", "Granite", "Basalt", "Cairn", "Scree", "Quarry"],
	"metal": ["Ingot", "Alloy", "Rivet", "Ore", "Filigree", "Gear", "Anvil", "Bolt"],
	"wood": ["Bark", "Burl", "Timber", "Bough", "Heartwood", "Thicket", "Grove", "Knot"],
	"plant": ["Frond", "Tendril", "Bloom", "Thistle", "Bramble", "Clover", "Sprig", "Fern"],
	"mushroom": ["Cap", "Morel", "Puffball", "Gill", "Truffle", "Mycel", "Chanterelle", "Toadstool"],
	"crystal": ["Prism", "Facet", "Shard", "Geode", "Quartz", "Gleam", "Lattice", "Spire"],
	"fire": ["Cinder", "Brimstone", "Scoria", "Pyre", "Ember", "Flare", "Kiln", "Ashfall"],
	"liquid": ["Tide", "Brook", "Mire", "Dew", "Ripple", "Marsh", "Spring", "Current"],
	"light": ["Lumen", "Glint", "Beacon", "Halo", "Flicker", "Radiance", "Lantern", "Spark"],
	"building": ["Brick", "Mortar", "Tile", "Arch", "Pillar", "Rampart", "Keystone", "Mason"],
	"background": ["Vista", "Horizon", "Backdrop", "Hollow", "Canopy", "Expanse", "Veil", "Dusk"],
	"object": ["Trinket", "Relic", "Totem", "Charm", "Lantern", "Keepsake", "Idol", "Bauble"],
	"other": ["Relic", "Wisp", "Oddity", "Curio", "Ember", "Shard", "Spirit", "Echo"],
}
## Word pieces for new compounds: a first half and a second half per material.
const HEADS := {
	"soil": ["Mud", "Dust", "Silt", "Furrow", "Loam", "Grit"],
	"stone": ["Flint", "Crag", "Slate", "Rock", "Grav", "Iron"],
	"metal": ["Rust", "Iron", "Brass", "Gild", "Steel", "Cog"],
	"wood": ["Oak", "Ash", "Burl", "Thorn", "Elder", "Briar"],
	"plant": ["Thorn", "Fern", "Moss", "Bramble", "Briar", "Clover"],
	"mushroom": ["Gloom", "Spore", "Myco", "Glim", "Puff", "Musk"],
	"crystal": ["Frost", "Glint", "Prism", "Shimmer", "Crys", "Opal"],
	"fire": ["Ember", "Brim", "Cinder", "Scorch", "Pyre", "Blaze"],
	"liquid": ["Tide", "Brine", "Dew", "Mire", "Rill", "Drizzle"],
	"light": ["Lumen", "Glow", "Sun", "Moon", "Star", "Beam"],
	"building": ["Brick", "Keep", "Arch", "Tower", "Vault", "Stone"],
	"background": ["Dusk", "Dawn", "Mist", "Haze", "Shade", "Gloam"],
	"object": ["Trink", "Rune", "Charm", "Bell", "Lock", "Key"],
	"other": ["Wisp", "Echo", "Odd", "Rune", "Hush", "Whim"],
}
const TAILS := {
	"soil": ["clod", "mire", "drift", "bed", "furrow"],
	"stone": ["stone", "crag", "fell", "tor", "flint"],
	"metal": ["forge", "plate", "spur", "wire", "anvil"],
	"wood": ["bark", "root", "wood", "bough", "knot"],
	"plant": ["wort", "bloom", "leaf", "thorn", "bud"],
	"mushroom": ["cap", "spore", "gill", "shroom", "stalk"],
	"crystal": ["shard", "glass", "spire", "facet", "gleam"],
	"fire": ["vein", "brand", "ash", "flare", "coal"],
	"liquid": ["pool", "tide", "drop", "fen", "well"],
	"light": ["glow", "beam", "wick", "light", "spark"],
	"building": ["wall", "hold", "gate", "spire", "keep"],
	"background": ["shade", "veil", "fall", "haze", "mist"],
	"object": ["trinket", "bell", "charm", "lock", "chime"],
	"other": ["wisp", "husk", "mote", "kin", "ling"],
}
## Hue bands (degrees) -> color words; plus pale / dark / grey ones.
const HUE_WORDS := [
	[15, ["Crimson", "Scarlet", "Ruby"]], [40, ["Copper", "Rust", "Amber"]], [65, ["Golden", "Saffron", "Honey"]],
	[95, ["Lime", "Chartreuse", "Meadow"]], [160, ["Jade", "Verdant", "Emerald"]], [200, ["Teal", "Lagoon", "Aqua"]],
	[250, ["Cobalt", "Azure", "Sapphire"]], [290, ["Violet", "Amethyst", "Indigo"]], [335, ["Orchid", "Rose", "Magenta"]],
	[361, ["Crimson", "Scarlet", "Garnet"]],
]
const PALE_WORDS := ["Pale", "Ivory", "Frosted", "Pearl"]
const DARK_WORDS := ["Midnight", "Obsidian", "Shadow", "Umbral"]
const GREY_WORDS := ["Ashen", "Slate", "Pewter", "Smoky"]
const BROWN_WORDS := ["Umber", "Russet", "Sepia", "Tawny"]
const RARE_WORDS := {
	"Rare": ["Hollow", "Twisted", "Whispering", "Wild"],
	"Epic": ["Ancient", "Gilded", "Elder", "Thundering"],
	"Legendary": ["Ancient", "Sovereign", "Radiant", "Fabled"],
	"Mythic": ["Eldritch", "Astral", "Primeval", "Phantom"],
	"Cosmic": ["Celestial", "Starborn", "Void", "Infinite"],
}
## Invented names (Mythic and up): syllables put together.
const SYL_A := ["Vel", "Quor", "Zan", "Mor", "Thal", "Ish", "Kyr", "Oro", "Syl", "Bri", "Nym", "Ae"]
const SYL_B := ["ora", "ith", "ane", "ivar", "elle", "undra", "is", "oth", "ara", "ix", "en", "yra"]


## Up to `count` name ideas (with " Seed") for splicing a + b, none already in your game.
static func ideas(a: Dictionary, b: Dictionary, rarity: int, count := 8, rng: RandomNumberGenerator = null) -> Array[String]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var banned := _words_of(a).merged(_words_of(b))
	var mats: Array = _materials(a, b)
	var colors: Array = _color_words(a) + _color_words(b)
	var tier: String = SeedArt.rarity_tier(rarity)[0]
	var out: Array[String] = []
	var tries := 0
	while out.size() < count and tries < 400:
		tries += 1
		var m: String = mats[rng.randi_range(0, mats.size() - 1)]
		var m2: String = mats[rng.randi_range(0, mats.size() - 1)]
		var name := ""
		match rng.randi_range(0, 5 if RARE_WORDS.has(tier) else 3):
			0, 1:  # Cobalt Shale
				name = "%s %s" % [_pick(colors, rng), _pick(MATERIAL_NOUNS[m], rng)]
			2:  # Gloomwort
				name = _compound(m, m2, rng)
			3:  # Russet Frostcap
				name = "%s %s" % [_pick(colors, rng), _compound(m, m2, rng)]
			4:  # Ancient Brimvein
				name = "%s %s" % [_pick(RARE_WORDS[tier], rng), _compound(m, m2, rng)]
			_:  # Velmora (Mythic+), else Hollow Flint
				if tier in ["Mythic", "Cosmic"]:
					name = _pick(SYL_A, rng) + _pick(SYL_B, rng)
				else:
					name = "%s %s" % [_pick(RARE_WORDS[tier], rng), _pick(MATERIAL_NOUNS[m], rng)]
		if _uses_banned(name, banned):
			continue
		var full := name + " Seed"
		if not out.has(full) and Game.find_by_name(full) == "":
			out.append(full)
	if out.is_empty():  # (practically never) a numbered fallback
		var i := 2
		while Game.find_by_name("Sprout %d Seed" % i) != "":
			i += 1
		out.append("Sprout %d Seed" % i)
	return out


static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	return list[rng.randi_range(0, list.size() - 1)]


static func _compound(m: String, m2: String, rng: RandomNumberGenerator) -> String:
	var head: String = _pick(HEADS[m], rng)
	var tail: String = _pick(TAILS[m2], rng)
	if head.to_lower().ends_with(tail) or tail.begins_with(head.to_lower()):
		tail = _pick(TAILS["other"], rng)
	return head + tail


## The materials the new seed leans towards: both parents' (from their category), never empty.
static func _materials(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for s in [a, b]:
		var m := String(s.get("category", {}).get("material", ""))
		if m == "" or not MATERIAL_NOUNS.has(m):
			m = _guess_material(String(s.get("name", "")))
		out.append(m)
	return out


static func _guess_material(seed_name: String) -> String:
	var n := seed_name.to_lower()
	for pair in [["mushroom", "mushroom"], ["magma", "fire"], ["lava", "fire"], ["stone", "stone"], ["rock", "stone"],
			["dirt", "soil"], ["soil", "soil"], ["mud", "soil"], ["crystal", "crystal"], ["glass", "crystal"],
			["wood", "wood"], ["tree", "wood"], ["flower", "plant"], ["leaf", "plant"], ["water", "liquid"]]:
		if n.contains(pair[0]):
			return pair[1]
	return "other"


## Color words for a seed's two colors.
static func _color_words(s: Dictionary) -> Array:
	var out: Array = []
	for hex in s.get("colors", ["#808080", "#808080"]):
		var c := Color(String(hex))
		if c.v < 0.22:
			out.append_array(DARK_WORDS)
		elif c.s < 0.15:
			out.append_array(PALE_WORDS if c.v > 0.8 else GREY_WORDS)
		elif c.h * 360.0 > 15.0 and c.h * 360.0 < 45.0 and c.v < 0.6:
			out.append_array(BROWN_WORDS)
		else:
			for band in HUE_WORDS:
				if c.h * 360.0 < band[0]:
					out.append_array(band[1])
					break
	return out


## The words of a seed's name (without "Seed"), lowercase, to keep out of its children's names.
static func _words_of(s: Dictionary) -> Dictionary:
	var out := {}
	for w in String(s.get("name", "")).to_lower().replace(" seed", "").split(" ", false):
		if w.length() >= 3:
			out[w] = true
	return out


static func _uses_banned(name: String, banned: Dictionary) -> bool:
	var low := name.to_lower()
	for w in banned:
		if low.contains(w):
			return true
	return false
