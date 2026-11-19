class_name CategoryLogic
extends RefCounted
## The CATEGORY of what a seed drops: its MATERIAL (Stone, Wood, Metal, Plant...) and how HARD it
## is to break (1 Very soft ... 5 Very hard). Guessed from the seed's name with the word lists
## below; you (the owner) agree with each guess or change it in the Categories tab.
##
## A category is a Dictionary on the seed (seed.category):
##   material  one of MATERIALS
##   hardness  1..5 (HARDNESS_NAMES); MushMantle hits to break: HARDNESS_HITS
##   status    "auto"    still a guess: follows the name and these word lists
##             "agreed"  you agreed with the guess: it never changes again
##             "changed" you set it yourself: it never changes again

const MATERIALS: Array[String] = ["soil", "stone", "metal", "wood", "plant", "mushroom", "crystal", "fire",
	"liquid", "light", "building", "background", "object", "other"]
const MATERIAL_NAMES := {
	"soil": "Soil & Sand", "stone": "Stone", "metal": "Metal", "wood": "Wood", "plant": "Plant",
	"mushroom": "Mushroom", "crystal": "Glass & Crystal", "fire": "Lava & Fire", "liquid": "Liquid",
	"light": "Light", "building": "Building", "background": "Background", "object": "Object", "other": "Other",
}
const MATERIAL_COLORS := {
	"soil": Color("#b58a5a"), "stone": Color("#a7a9b8"), "metal": Color("#8fb4d6"), "wood": Color("#c98a4b"),
	"plant": Color("#7be36f"), "mushroom": Color("#d58ad6"), "crystal": Color("#8ff0f0"), "fire": Color("#ff7a3d"),
	"liquid": Color("#5aa8ff"), "light": Color("#ffe066"), "building": Color("#e0a0a0"), "background": Color("#7d7890"),
	"object": Color("#c4c0d4"), "other": Color("#9a94b0"),
}
const HARDNESS_NAMES: Array[String] = ["", "Very soft", "Soft", "Medium", "Hard", "Very hard"]
## Suggested MushMantle "hits" (Fist hits to break) for each hardness: Dirt 4, Wood 5, Stone 8, Obsidian 12.
const HARDNESS_HITS: Array[int] = [0, 2, 4, 5, 8, 12]
const STATUSES: Array[String] = ["auto", "agreed", "changed"]

## Checked IN THIS ORDER, first match wins ("Magma Rock" is Lava & Fire before it is Stone,
## "Sandstone" is Stone before it is Sand).
const MATERIAL_WORDS := [
	["background", ["background", "backdrop"]],
	["fire", ["lava", "magma", "fire", "flame", "inferno", "molten", "ember", "blaze", "brimstone", "sulfur"]],
	["light", ["torch", "lantern", "lamp", "candle", "chandelier", "lightbulb", "beacon"]],
	["metal", ["iron", "gold", "golden", "copper", "steel", "metal", "ore", "bronze", "silver", "tin", "brass", "chain",
		"anvil", "bucket", "nail", "pipe", "rust", "titanium", "cobalt", "platinum", "mithril", "spike", "bars", "safe",
		"vault", "sprinkler", "gear", "robot"]],
	["crystal", ["glass", "crystal", "quartz", "gem", "diamond", "ruby", "emerald", "sapphire", "amethyst", "ice",
		"window", "prism", "pearl", "geode", "opal", "jade", "lapis", "lazuli", "amber", "topaz", "jasper", "onyx",
		"garnet", "turquoise", "citrine", "peridot"]],
	["mushroom", ["mushroom", "shroom", "fungus", "fungi", "spore", "mycelium", "truffle", "puffball", "toadstool"]],
	["plant", ["grass", "flower", "rose", "daffodil", "tulip", "lily", "orchid", "wheat", "yam", "potato", "carrot",
		"beet", "turnip", "onion", "bush", "hedge", "shrub", "leaf", "leaves", "vine", "moss", "fern", "sapling", "root",
		"cactus", "bamboo", "reed", "herb", "weed", "crop", "fruit", "apple", "melon", "pumpkin", "corn", "rice",
		"cotton", "petal", "clover", "ivy", "thorn", "nettle", "thistle", "lemon", "cherry", "flytrap", "snapper",
		"banana", "grape", "olive", "coconut", "seaweed", "kelp", "algae", "lettuce", "cabbage", "pepper", "tomato"]],
	["wood", ["wood", "wooden", "log", "plank", "timber", "bark", "branch", "stick", "door", "table", "chair", "crate",
		"barrel", "fence", "ladder", "bench", "shelf", "bookshelf", "workbench", "chest", "bed", "sign", "loom", "gate",
		"charcoal"]],
	["liquid", ["water", "oil", "honey", "slime", "goo", "acid", "juice", "milk", "syrup"]],
	["stone", ["stone", "rock", "cobble", "cobblestone", "gravel", "pebble", "pumice", "obsidian", "basalt",
		"granite", "marble", "slate", "flint", "boulder", "bedrock", "coal", "cavern", "cave", "limestone",
		"mantlestone", "rubble", "asphalt", "pathway", "path"]],
	["soil", ["soil", "dirt", "mud", "clay", "loam", "sand", "dust", "ash", "cinder", "earth", "peat", "silt",
		"mulch", "compost", "snow", "fertilizer", "manure"]],
	["building", ["block", "brick", "concrete", "tile", "wool", "carpet", "roof", "wall", "pillar", "column",
		"plaster", "cement", "platform"]],
	["object", ["well", "sign", "banner", "flag", "painting", "pot", "vase", "clock", "mirror", "statue", "rope",
		"furnace", "sifter", "bell", "cone", "toilet", "fishbowl", "fishtank", "tank", "bowl"]],
]
## Endings that also count ("Blueberry", "Deathcap", "Firewood", "Glowstone").
const MATERIAL_ENDINGS := [
	["mushroom", ["cap", "shroom"]],
	["plant", ["berry", "flower", "weed", "grass", "leaf", "root"]],
	["wood", ["wood"]],
	["stone", ["stone", "rock"]],
]
## How hard it is for each material (1..5) unless a word below says otherwise.
const MATERIAL_HARDNESS := {
	"background": 1, "plant": 1, "mushroom": 1, "light": 1, "liquid": 1, "object": 2, "soil": 2, "fire": 2,
	"crystal": 3, "wood": 3, "building": 3, "other": 3, "stone": 4, "metal": 4,
}
const VERY_HARD_WORDS: Array[String] = ["obsidian", "bedrock", "diamond", "adamant", "titanium", "mantle", "mantlestone",
	"reinforced", "mithril", "platinum"]
const HARD_WORDS: Array[String] = ["quartz", "crystal", "gem", "granite", "basalt", "marble", "iron", "steel", "cobble",
	"cobblestone", "flint", "geode", "ruby", "emerald", "sapphire", "amethyst"]
const SOFT_WORDS: Array[String] = ["gravel", "pebble", "sand", "dust", "ash", "cinder", "glass", "pumice", "clay", "snow",
	"wool", "mud"]
const VERY_SOFT_WORDS: Array[String] = ["leaf", "leaves", "petal", "moss", "grass", "flower", "spore", "web", "cobweb"]
const SUBSTRING_MIN := 5  ## words at least this long also match inside longer words ("cobblestone" has "stone")


## A fresh guess from the name. `drop` (optional) helps when no word matches:
## an unknown decoration is an Object, an unknown block is Other, a background is a Background.
static func classify(seed_name: String, drop: Dictionary = {}) -> Dictionary:
	var tokens := _tokens(seed_name)
	var material := ""
	for entry in MATERIAL_WORDS:
		if _has(tokens, entry[1]):
			material = entry[0]
			break
	if material == "":
		for entry in MATERIAL_ENDINGS:
			if _ends_with(tokens, entry[1]):
				material = entry[0]
				break
	if material == "":
		material = "object" if drop.get("kind", "block") == "decoration" else "other"
	if drop.get("kind", "block") == "background":
		material = "background"  # a background drop is always the Background material
	var hardness: int = MATERIAL_HARDNESS.get(material, 3)
	if material == "background":
		pass
	elif _has(tokens, VERY_HARD_WORDS):
		hardness = 5
	elif _has(tokens, HARD_WORDS):
		hardness = 4
	elif _has(tokens, SOFT_WORDS):
		hardness = mini(hardness, 2)
	elif _has(tokens, VERY_SOFT_WORDS):
		hardness = 1
	return { "material": material, "hardness": hardness, "status": "auto" }


## A clean category from anything; a missing or broken one is guessed from the name.
static func sanitize(c: Variant, seed_name: String, drop: Dictionary = {}) -> Dictionary:
	if typeof(c) != TYPE_DICTIONARY or not MATERIALS.has(c.get("material", "")):
		return classify(seed_name, drop)
	var status: String = c.get("status", "auto")
	if not STATUSES.has(status):
		status = "auto"
	return { "material": c.material, "hardness": clampi(int(c.get("hardness", 3)), 1, 5), "status": status }


static func material_name(m: String) -> String:
	return MATERIAL_NAMES.get(m, "Other")


static func hardness_name(h: int) -> String:
	return "%d %s" % [h, HARDNESS_NAMES[clampi(h, 1, 5)]]


## "Stone · 4 Hard"
static func describe(c: Dictionary) -> String:
	return "%s · %s" % [material_name(c.get("material", "other")), hardness_name(int(c.get("hardness", 3)))]


static func word_lists() -> Dictionary:
	var by_material := {}
	for entry in MATERIAL_WORDS:
		by_material[entry[0]] = entry[1]
	return {
		"checked_in_this_order": MATERIAL_WORDS.map(func(e): return e[0]),
		"material_words": by_material,
		"material_endings": MATERIAL_ENDINGS,
		"default_hardness_per_material": MATERIAL_HARDNESS,
		"very_hard_words (5)": VERY_HARD_WORDS, "hard_words (4)": HARD_WORDS,
		"soft_words (2)": SOFT_WORDS, "very_soft_words (1)": VERY_SOFT_WORDS,
	}


static func _tokens(seed_name: String) -> PackedStringArray:
	var n := DropLogic.drop_name(seed_name).to_lower()
	var cleaned := ""
	for ch in n:
		cleaned += ch if (ch >= "a" and ch <= "z") else " "
	return cleaned.split(" ", false)


static func _has(tokens: PackedStringArray, words: Array) -> bool:
	for t in tokens:
		for w in words:
			if t == w or t == w + "s" or t == w + "es":
				return true
			if String(w).length() >= SUBSTRING_MIN and t.contains(w):
				return true
	return false


static func _ends_with(tokens: PackedStringArray, endings: Array) -> bool:
	for t in tokens:
		for e in endings:
			if t.length() > String(e).length() and (t.ends_with(e) or t.ends_with(e + "s")):
				return true
	return false
