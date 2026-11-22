extends Node
## Autoload "Game": the dictionary of discovered seeds, every splice recipe, and saving.
##
## A seed is a Dictionary:
##   id, name, rarity, pattern (SeedArt.Pattern), colors [hex, hex], sprout (hex),
##   pattern_seed (int: variation inside the pattern), parents ([] for tier-1 seeds, else [id_a, id_b]),
##   tag ("farmable" / "not_farmable" / "bountiful"), crop (CropArt type id: what it grows into),
##   custom (true for tier-1 seeds you added),
##   found (unix time it was added),
##   made_by (the contributor: your name from Settings when you made it, or theirs when imported),
##   denied (true: you sent it to the graveyard - no approval stamp, see approvals.gd)
##
## RARITY RULE: a base seed is rarity 1. A spliced seed's rarity is the sum of its two
## parents' rarities, so it counts every base seed that went into the chain:
##   1 + 1 = 2,   (2+1) + 1 = 3 ... a rarity-3 seed spliced with a rarity-5 seed = 8.

signal seeds_changed
signal recipes_changed

const SAVE_PATH := "user://seed_splicer_save.json"
## 4: every seed above rarity 1 was rerolled with the farmable roll (below)
## 5: every seed has a `drop` (block/decoration, collision, collision damage - see drop_logic.gd)
## 6: every seed has a `category` (material + hardness - see category_logic.gd)
## 7: every seed has a `crop` (one of the CropArt crop types; older seeds got a random one)
const SAVE_VERSION := 7
const EXPORT_FORMAT := "seed-splicer-list"

## --- the farmable roll ------------------------------------------------------------------
## Every seed made by splicing (rarity 2 and up) gets its tag by chance:
##   rarity 11 and up : 75% Not Farmable, 25% Farmable
##   rarity 2 to 10   : 50% Not Farmable, 50% Farmable   ("forgiven" odds)
##   then 1 in 4 of the Farmable ones become Bountiful
## Rarity 1 seeds (the 4 you start with and the Tier 1 seeds you add yourself) are never rolled.
const NOT_FARMABLE_CHANCE := 0.75
const NOT_FARMABLE_CHANCE_FORGIVEN := 0.5
const FORGIVEN_MAX_RARITY := 10
const BOUNTIFUL_CHANCE := 0.25


static func not_farmable_chance(rarity: int) -> float:
	return NOT_FARMABLE_CHANCE_FORGIVEN if rarity <= FORGIVEN_MAX_RARITY else NOT_FARMABLE_CHANCE


## The tag a seed of this rarity rolls. Pass your own `rng` for repeatable results (tests).
static func roll_tag(rarity: int, rng: RandomNumberGenerator = null) -> String:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	if r.randf() < not_farmable_chance(rarity):
		return "not_farmable"
	return "bountiful" if r.randf() < BOUNTIFUL_CHANCE else "farmable"


## "50% Not Farmable · 37.5% Farmable · 12.5% Bountiful"
static func tag_odds_text(rarity: int) -> String:
	var nf := not_farmable_chance(rarity)
	var f := (1.0 - nf) * (1.0 - BOUNTIFUL_CHANCE)
	var b := (1.0 - nf) * BOUNTIFUL_CHANCE
	return "%s Not Farmable  ·  %s Farmable  ·  %s Bountiful" % [_pct(nf), _pct(f), _pct(b)]


static func _pct(p: float) -> String:
	var s := String.num(p * 100.0, 2)
	if "." in s:
		s = s.rstrip("0").rstrip(".")
	return s + "%"

## Every seed has one tag.
const TAGS: Array[String] = ["farmable", "not_farmable", "bountiful"]
const TAG_NAMES := { "farmable": "Farmable", "not_farmable": "Not Farmable", "bountiful": "Bountiful" }
const TAG_COLORS := { "farmable": Color("#7be36f"), "not_farmable": Color("#a19bb8"), "bountiful": Color("#ffc94a") }


static func tag_name(tag: String) -> String:
	return TAG_NAMES.get(tag, "Farmable")


static func tag_color(tag: String) -> Color:
	return TAG_COLORS.get(tag, TAG_COLORS.farmable)

var seeds := {}            # id -> seed Dictionary
var order: Array[String] = []  # discovery order
var recipes := {}          # "idA|idB" (sorted) -> result id
var recipe_order: Array[String] = []
var void_tokens: Array = []  # [{id, x, y}] what's floating in the void, restored on load
## Tag already rolled for a pair that has no recipe yet ("idA|idB" -> tag), so cancelling a splice
## and trying again can't be used to re-roll it. Removed once the recipe exists.
var pending_rolls := {}
## Filled when a reroll happened while loading: { total, counts }. main.gd shows it once, then clears it.
var reroll_report := {}
## Filled when seeds without a drop were sorted while loading: { total, collision, no_collision, damage }.
## main.gd shows it once, then clears it.
var drop_report := {}
## Filled when seeds without a crop type got a random one while loading: { total }. main.gd shows it once.
var crop_report := {}

const BASE_SEEDS := [
	{ "id": "dirt", "name": "Dirt Seed", "pattern": SeedArt.Pattern.HLINES,
		"colors": ["#8b5a34", "#5c3a22"], "sprout": "#7ccf4e", "pattern_seed": 2, "tag": "bountiful" },
	{ "id": "glowing_mushroom", "name": "Glowing Mushroom Seed", "pattern": SeedArt.Pattern.DOTS,
		"colors": ["#27b3c4", "#c9fff3"], "sprout": "#a6ff6e", "pattern_seed": 4, "tag": "bountiful" },
	{ "id": "stone", "name": "Stone Seed", "pattern": SeedArt.Pattern.HALF,
		"colors": ["#9a9cab", "#686a7c"], "sprout": "#8fc46a", "pattern_seed": 1, "tag": "bountiful" },
	{ "id": "magma_rock", "name": "Magma Rock Seed", "pattern": SeedArt.Pattern.ZIGZAG,
		"colors": ["#3b2a33", "#ff6a1c"], "sprout": "#e6c440", "pattern_seed": 5, "tag": "bountiful" },
]


## The official list version this save has merged (see official.gd), and what the last merge added.
var official_version := ""
var official_report := {}
## Seeds players submitted that the developer DENIED (never in your game): drawable seed dictionaries
## with made_by / parent_names / submission_id. They show in the Graveyard tab and ship in the
## graveyard on the next publish (tools/publish_update.py reads "graveyard" from the save).
var graveyard_extra: Array = []
## Seed names (lowercase) the developer REMOVED from the graveyard: not shown, never published.
## A seed of yours that is removed stays in your game (still marked denied, just not listed).
var graveyard_removed: Array = []


func _ready() -> void:
	if not load_game():
		reset()
	_load_stats()
	Official.load_live_cache()  # a newer live push than this release's files, if there was one
	official_report = Official.merge()


# --- rarity / recipes -------------------------------------------------------

## Two copies of the same seed can't be spliced together.
static func can_splice(a: String, b: String) -> bool:
	return a != b


static func recipe_key(a: String, b: String) -> String:
	return a + "|" + b if a <= b else b + "|" + a


func splice_rarity(a: String, b: String) -> int:
	return int(seeds[a].rarity) + int(seeds[b].rarity)


## Every [a, b] pair that makes `id`. The seed's own first recipe comes first, then any other
## splice that was given the same name (see link_recipe). Tier 1 seeds have none that matter.
func recipes_for(id: String) -> Array:
	var out: Array = []
	var own: Array = get_seed(id).get("parents", [])
	var own_key := ""
	if own.size() == 2 and seeds.has(own[0]) and seeds.has(own[1]):
		out.append([own[0], own[1]])
		own_key = recipe_key(own[0], own[1])
	for key in recipe_order:
		if recipes[key] == id and key != own_key:
			var pair := String(key).split("|")
			if pair.size() == 2 and seeds.has(pair[0]) and seeds.has(pair[1]):
				out.append([pair[0], pair[1]])
	return out


func result_of(a: String, b: String) -> String:
	return recipes.get(recipe_key(a, b), "")


func get_seed(id: String) -> Dictionary:
	return seeds.get(id, {})


func find_by_name(seed_name: String) -> String:
	var n := seed_name.strip_edges().to_lower()
	for id in seeds:
		if String(seeds[id].name).to_lower() == n:
			return id
	return ""


## Adds a brand new seed made from a + b and records the recipe. Returns its id.
func add_spliced_seed(a: String, b: String, look: Dictionary) -> String:
	var id := _unique_id(look.name)
	var seed := {
		"id": id,
		"name": String(look.name).strip_edges(),
		"rarity": splice_rarity(a, b),
		"pattern": int(look.pattern),
		"colors": [look.colors[0], look.colors[1]],
		"sprout": look.sprout,
		"pattern_seed": int(look.pattern_seed),
		"tag": tag_roll_for(a, b),  # always the roll, whatever the popup said
		"crop": CropArt.valid_type(look.get("crop"), id),
		"fruit_count": clampi(int(look.get("fruit_count", 0)), 0, CropArt.MAX_FRUIT),
		"drop": DropLogic.sanitize(look.get("drop"), String(look.name)),
		"category": CategoryLogic.sanitize(look.get("category"), String(look.name), DropLogic.sanitize(look.get("drop"), String(look.name))),
		"parents": [a, b],
		"custom": false,
		"made_by": player_name(),
		"found": int(Time.get_unix_time_from_system()),
	}
	pending_rolls.erase(recipe_key(a, b))
	seeds[id] = seed
	order.append(id)
	_add_recipe(a, b, id)
	seeds_changed.emit()
	save_game()
	return id


## Your own tier-1 seed (from the Add Seed button). Rarity 1, no parents.
func add_custom_seed(look: Dictionary) -> String:
	var id := _unique_id(look.name)
	seeds[id] = {
		"id": id,
		"name": String(look.name).strip_edges(),
		"rarity": 1,
		"pattern": int(look.pattern),
		"colors": [look.colors[0], look.colors[1]],
		"sprout": look.sprout,
		"pattern_seed": int(look.pattern_seed),
		"tag": _valid_tag(look.get("tag", "")),
		"crop": CropArt.valid_type(look.get("crop"), id),
		"fruit_count": clampi(int(look.get("fruit_count", 0)), 0, CropArt.MAX_FRUIT),
		"drop": DropLogic.sanitize(look.get("drop"), String(look.name)),
		"category": CategoryLogic.sanitize(look.get("category"), String(look.name), DropLogic.sanitize(look.get("drop"), String(look.name))),
		"parents": [],
		"custom": true,
		"made_by": player_name(),
		"found": int(Time.get_unix_time_from_system()),
	}
	order.append(id)
	seeds_changed.emit()
	save_game()
	return id


## Your name (Settings > You): written on every seed you make, shown next to the approval stamp.
static func player_name() -> String:
	var n := String(UserSettings.get_value("profile", "name", "")).strip_edges().left(32)
	return "" if DevMode.name_problem(n) != "" else n


static func set_player_name(n: String) -> void:
	UserSettings.set_value("profile", "name", n.strip_edges().left(32))


## Sends a seed to the graveyard (or brings it back). It keeps existing, but loses its stamp.
func set_denied(id: String, on: bool) -> void:
	if not seeds.has(id):
		return
	if on:
		seeds[id].denied = true
	else:
		seeds[id].erase("denied")
	seeds_changed.emit()
	save_game()


# --- statistics: time played (its own small file, saved every 30 s and on quit) ---------------

const STATS_PATH := "user://seed_splicer_stats.json"
var stats := { "play_seconds": 0.0, "sessions": 0, "first_played": 0 }
var _stats_dirty := 0.0


func _load_stats() -> void:
	if FileAccess.file_exists(STATS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			stats.play_seconds = maxf(0.0, float(parsed.get("play_seconds", 0.0)))
			stats.sessions = maxi(0, int(parsed.get("sessions", 0)))
			stats.first_played = int(parsed.get("first_played", 0))
	if stats.first_played == 0:
		stats.first_played = int(Time.get_unix_time_from_system())
	stats.sessions += 1
	save_stats()


func save_stats() -> void:
	var f := FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(stats, "	"))
	_stats_dirty = 0.0


func _process(delta: float) -> void:
	stats.play_seconds += delta
	_stats_dirty += delta
	if _stats_dirty >= 30.0:
		save_stats()


func _exit_tree() -> void:
	save_stats()


## "3h 05m 12s"
static func duration_text(seconds: float) -> String:
	var t := int(seconds)
	var h := t / 3600
	var m := (t / 60) % 60
	var sec := t % 60
	if h > 0:
		return "%dh %02dm %02ds" % [h, m, sec]
	return "%dm %02ds" % [m, sec]


func _valid_tag(tag: Variant) -> String:
	return tag if TAGS.has(tag) else "farmable"


## a + b now makes an existing seed (you gave a new splice a name you already had).
## The seed keeps the rarity of the first chain that made it.
func link_recipe(a: String, b: String, result: String) -> void:
	pending_rolls.erase(recipe_key(a, b))
	_add_recipe(a, b, result)
	save_game()


## The tag a NEW seed made from a + b gets. Rolled the first time you ask and then kept, so
## opening the splice popup, cancelling and splicing again shows the same result.
func tag_roll_for(a: String, b: String) -> String:
	var key := recipe_key(a, b)
	if not pending_rolls.has(key):
		pending_rolls[key] = roll_tag(splice_rarity(a, b))
		save_game()
	return pending_rolls[key]


## Rerolls the tag of every seed above rarity 1 (rarity 1 seeds keep theirs).
## Returns { total, counts: { farmable, not_farmable, bountiful } } and keeps it in reroll_report.
func reroll_all() -> Dictionary:
	var counts := { "farmable": 0, "not_farmable": 0, "bountiful": 0 }
	var total := 0
	for id in order:
		var s: Dictionary = seeds[id]
		if int(s.rarity) <= 1:
			continue
		# Seeded by the seed's id: still a random-looking roll, but rerolling the same seed again
		# (say an older copy of the game writes the old save back) always lands on the same result.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("tag-reroll-v4:" + String(id))
		s.tag = roll_tag(int(s.rarity), rng)
		counts[s.tag] += 1
		total += 1
	reroll_report = { "total": total, "counts": counts }
	seeds_changed.emit()
	recipes_changed.emit()
	save_game()
	return reroll_report


func update_look(id: String, look: Dictionary) -> void:
	var s: Dictionary = seeds[id]
	s.name = String(look.name).strip_edges()
	s.pattern = int(look.pattern)
	s.colors = [look.colors[0], look.colors[1]]
	s.sprout = look.sprout
	s.pattern_seed = int(look.pattern_seed)
	s.tag = _valid_tag(look.get("tag", ""))
	s.crop = CropArt.valid_type(look.get("crop"), id)
	s.fruit_count = clampi(int(look.get("fruit_count", 0)), 0, CropArt.MAX_FRUIT)
	s.drop = DropLogic.sanitize(look.get("drop"), s.name)
	# a category that is still a guess follows the (new) name
	var cat := CategoryLogic.sanitize(s.get("category"), s.name, s.drop)
	s.category = CategoryLogic.classify(s.name, s.drop) if cat.status == "auto" else cat
	seeds_changed.emit()
	recipes_changed.emit()
	save_game()


# --- categories (the Categories tab) ------------------------------------------------------

## You set a seed's material and hardness yourself: it is "changed" and never guessed again.
func set_category(id: String, material: String, hardness: int) -> void:
	if not seeds.has(id) or not CategoryLogic.MATERIALS.has(material):
		return
	seeds[id].category = { "material": material, "hardness": clampi(hardness, 1, 5), "status": "changed" }
	seeds_changed.emit()
	save_game()


## Ticking "OK" agrees with the guess (it is kept as it is from now on). Unticking makes it a
## guess again: it goes back to what the word lists say.
func agree_category(id: String, agree: bool) -> void:
	agree_categories([id], agree)


func agree_categories(ids: Array, agree: bool) -> void:
	for id in ids:
		if not seeds.has(id):
			continue
		var s: Dictionary = seeds[id]
		var cat := CategoryLogic.sanitize(s.get("category"), s.name, s.drop)
		if agree:
			if cat.status == "auto":
				cat.status = "agreed"
		else:
			cat = CategoryLogic.classify(s.name, s.drop)
		s.category = cat
	seeds_changed.emit()
	save_game()


## { auto, agreed, changed }: how many categories are still guesses, agreed, changed by you.
func category_summary() -> Dictionary:
	var r := { "auto": 0, "agreed": 0, "changed": 0 }
	for id in order:
		r[seeds[id].get("category", {}).get("status", "auto")] += 1
	return r


func _add_recipe(a: String, b: String, result: String) -> void:
	var key := recipe_key(a, b)
	if not recipes.has(key):
		recipe_order.append(key)
	recipes[key] = result
	recipes_changed.emit()


func _unique_id(seed_name: String) -> String:
	var base := seed_name.strip_edges().to_lower().replace(" seed", "").to_snake_case()
	base = base.replace(" ", "_").replace("-", "_")
	if base.is_empty():
		base = "seed"
	var id := base
	var n := 2
	while seeds.has(id):
		id = "%s_%d" % [base, n]
		n += 1
	return id


# --- first look for a fresh splice -------------------------------------------

## Starting appearance for a new splice: colors inherited from the parents, a random
## pattern, and a suggested name. The player can change all of it in the popup.
func suggest_look(a: String, b: String) -> Dictionary:
	var sa: Dictionary = seeds[a]
	var sb: Dictionary = seeds[b]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var c1 := Color(sa.colors[0])
	var c2 := Color(sb.colors[0]) if a != b else Color(sa.colors[1])
	if c1.is_equal_approx(c2):
		c2 = Color(sb.colors[1])
	c1 = _jitter(c1, rng)
	c2 = _jitter(c2, rng)
	var sprout := Color(sa.sprout).lerp(Color(sb.sprout), 0.5)
	var suggested := suggest_names(a, b)[0]
	return {
		"name": suggested,
		"drop": DropLogic.classify(suggested),  # a guess from the name; the popup updates it as you rename
		"pattern": rng.randi_range(0, SeedArt.Pattern.size() - 1),
		"colors": ["#" + c1.to_html(false), "#" + c2.to_html(false)],
		"sprout": "#" + _jitter(sprout, rng).to_html(false),
		"pattern_seed": rng.randi_range(0, 99999),
		"tag": tag_roll_for(a, b),  # rolled, not chosen (see roll_tag)
		"crop": CropArt.type_ids()[rng.randi_range(0, CropArt.type_ids().size() - 1)],  # you can pick another
	}


func _jitter(c: Color, rng: RandomNumberGenerator) -> Color:
	return Color.from_hsv(fposmod(c.h + rng.randf_range(-0.03, 0.03), 1.0),
		clampf(c.s + rng.randf_range(-0.06, 0.06), 0.0, 1.0),
		clampf(c.v + rng.randf_range(-0.06, 0.06), 0.05, 1.0))


## Name ideas for a + b, best first, none already in the dictionary (see seed_names.gd: built from
## the new seed's materials, colors and rarity, never by gluing the parents' names together).
func suggest_names(a: String, b: String) -> Array[String]:
	return SeedNames.ideas(seeds[a], seeds[b], splice_rarity(a, b))


func _words(seed_name: String) -> PackedStringArray:
	var n := seed_name.strip_edges()
	if n.ends_with(" Seed"):
		n = n.substr(0, n.length() - 5)
	var parts := n.split(" ", false)
	if parts.is_empty():
		parts = PackedStringArray([n])
	return parts


# --- save / load -------------------------------------------------------------

func reset() -> void:
	BlockArt.clear_all()
	seeds.clear()
	order.clear()
	recipes.clear()
	recipe_order.clear()
	void_tokens.clear()
	pending_rolls.clear()
	official_version = ""
	graveyard_extra.clear()
	graveyard_removed.clear()
	for b in BASE_SEEDS:
		var s: Dictionary = b.duplicate(true)
		s.rarity = 1
		s.parents = []
		s.tag = b.get("tag", "farmable")
		s.crop = CropArt.random_type(s.id)
		s.drop = DropLogic.classify(s.name)
		s.category = CategoryLogic.classify(s.name, s.drop)
		s.custom = false
		s.found = 0
		seeds[s.id] = s
		order.append(s.id)
	seeds_changed.emit()
	recipes_changed.emit()
	save_game()


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"seeds": order.map(func(id): return seeds[id]),
		"recipes": recipe_order.map(func(k): return { "pair": k, "result": recipes[k] }),
		"void": void_tokens,
		"rolls": pending_rolls,
		"official_version": official_version,
		"graveyard": graveyard_extra,
		"graveyard_removed": graveyard_removed,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("seeds"):
		return false
	seeds.clear()
	order.clear()
	recipes.clear()
	recipe_order.clear()
	var sorted_drops := 0
	var relogic_drops := 0
	var given_crops := 0
	for s in parsed.seeds:
		s.rarity = int(s.rarity)
		s.pattern = int(s.pattern)
		s.pattern_seed = int(s.pattern_seed)
		s.tag = _valid_tag(s.get("tag", ""))
		if not CropArt.is_type(s.get("crop")):
			s.crop = CropArt.random_type(String(s.id))  # older saves: a random crop type, fixed by the id
			given_crops += 1
		s.custom = bool(s.get("custom", false))
		s.made_by = String(s.get("made_by", "")).strip_edges().left(32)
		if not s.get("denied", false):
			s.erase("denied")
		if typeof(s.get("drop")) != TYPE_DICTIONARY or not DropLogic.KINDS.has(s.drop.get("kind", "")):
			s.drop = DropLogic.classify(String(s.name))  # saves from before drops: sort it by logic
			sorted_drops += 1
		else:
			s.drop = DropLogic.sanitize(s.drop, String(s.name))
			if s.drop.auto:  # a guess always follows the current logic; a hand-set drop never changes
				var fresh := DropLogic.classify(String(s.name))
				if fresh != s.drop:
					s.drop = fresh
					relogic_drops += 1
		# category: a guess ("auto") follows the current word lists; agreed / changed ones never move
		var cat := CategoryLogic.sanitize(s.get("category"), String(s.name), s.drop)
		if cat.status == "auto":
			cat = CategoryLogic.classify(String(s.name), s.drop)
		if cat != s.get("category"):
			relogic_drops += 1
		s.category = cat
		seeds[s.id] = s
		order.append(s.id)
	for r in parsed.get("recipes", []):
		if seeds.has(r.result):
			recipes[r.pair] = r.result
			recipe_order.append(r.pair)
	void_tokens = parsed.get("void", [])
	official_version = String(parsed.get("official_version", ""))
	graveyard_extra = parsed.get("graveyard", []) if parsed.get("graveyard") is Array else []
	graveyard_removed = parsed.get("graveyard_removed", []).map(func(n): return String(n).strip_edges().to_lower()) if parsed.get("graveyard_removed") is Array else []
	pending_rolls.clear()
	var saved_rolls: Variant = parsed.get("rolls", {})
	if typeof(saved_rolls) == TYPE_DICTIONARY:
		for k in saved_rolls:
			if TAGS.has(saved_rolls[k]):
				pending_rolls[k] = saved_rolls[k]
	var version := int(parsed.get("version", 1))
	# saves from before version 3: the 4 base seeds became Bountiful
	if version < 3:
		for b in BASE_SEEDS:
			if seeds.has(b.id):
				seeds[b.id].tag = "bountiful"
	# saves from before version 4: every seed above rarity 1 is rerolled, once
	if version < 4:
		reroll_all()
	# saves from before version 5: the drops were just sorted by logic (above); say what came out, and keep it
	if sorted_drops > 0:
		drop_report = drop_summary()
		drop_report.total = sorted_drops
		save_game()
	elif relogic_drops > 0 or given_crops > 0 or version < SAVE_VERSION:
		save_game()
	if given_crops > 0:
		crop_report = { "total": given_crops }
	return true


## How many seeds have collision / no collision / collision damage.
func drop_summary() -> Dictionary:
	var r := { "total": seeds.size(), "collision": 0, "no_collision": 0, "damage": 0 }
	for id in order:
		var d: Dictionary = seeds[id].drop
		if d.collision:
			r.collision += 1
		else:
			r.no_collision += 1
		if d.damage:
			r.damage += 1
	return r


# --- sharing: export / import a splicing list ---------------------------------

## Writes your whole dictionary + every splice to a JSON file you can send to a friend.
## The file also carries a "reference" section that explains every field and the designer's rules
## (it is written for Claude Code, which will build the new seeds, blocks and decorations from it).
## Importing ignores the reference.
func export_list(path: String) -> Error:
	var sheet_path := sprite_sheet_path(path)
	var sheet := build_sprite_sheet()
	var data := {
		"format": EXPORT_FORMAT,
		"version": SAVE_VERSION,
		"exported": Time.get_datetime_string_from_system(false, true),
		"username": player_name(),
		"reference": reference_notes(),
		"sprite_sheet": sheet.info.merged({ "file": sheet_path.get_file() }),
		"seeds": order.map(func(id): return _signed(seeds[id])),
		"recipes": recipe_order.map(func(k): return { "pair": k, "result": recipes[k] }),
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return sheet.image.save_png(sheet_path)


## A seed for an export: one of yours that was made before you had a username is signed with it
## (the 4 base seeds stay unsigned).
func _signed(s: Dictionary) -> Dictionary:
	if String(s.get("made_by", "")) != "" or BASE_SEEDS.any(func(b): return b.id == s.id):
		return s
	var out := s.duplicate()
	out.made_by = player_name()
	return out


## Seeds a player can upload (Settings > Upload my seeds): theirs (signed with their name, or
## unsigned and made by splicing / added in this game) and not already on the official list.
func my_unofficial_seeds() -> Array:
	var me := player_name().to_lower()
	return order.filter(func(id):
		var s: Dictionary = seeds[id]
		if BASE_SEEDS.any(func(b): return b.id == id) or Approvals.is_approved(s):
			return false
		var by := String(s.get("made_by", "")).to_lower()
		return by == me or by == "")


## One seed as a small Seed Splicer list for an online submission: the seed, every seed it is
## made from (all the way down), their recipes, and the block art you drew for them (base64 PNG,
## like the official list). The developer's game imports it as it would an Export List.
func submission_payload(id: String) -> Dictionary:
	var need := {}
	var stack: Array = [id]
	while not stack.is_empty():
		var x: String = stack.pop_back()
		if need.has(x) or not seeds.has(x):
			continue
		need[x] = true
		for p in seeds[x].get("parents", []):
			stack.append(p)
	var out_seeds: Array = []
	for x in order:
		if not need.has(x):
			continue
		var s := _signed(seeds[x]).duplicate()
		s.erase("denied")
		var art_file := "user://block_art/%s.png" % String(x).validate_filename()
		if FileAccess.file_exists(art_file):
			s.block_art = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(art_file))
		out_seeds.append(s)
	var out_recipes: Array = []
	for k in recipe_order:
		var pair := String(k).split("|")
		if need.has(pair[0]) and need.has(pair[1]) and need.has(recipes[k]):
			out_recipes.append({ "pair": k, "result": recipes[k] })
	return { "format": EXPORT_FORMAT, "version": SAVE_VERSION, "username": player_name(), "top": id,
		"seeds": out_seeds, "recipes": out_recipes }


## EVERYTHING PLAYERS GET from a push (Submissions > Push to players) or a release, built from
## your game: { official: the seed list (seeds + recipes + block art, see official.gd),
## approvals: stamps, art approval, RSR and the graveyard (see approvals.gd) }.
## Same rules as tools/publish_update.py: every seed you have that isn't in your graveyard is
## approved, signed with its made_by or your name; your graveyard + denied submissions + earlier
## denied seeds are the graveyard.
const DRAW_FIELDS := ["rarity", "pattern", "colors", "sprout", "pattern_seed", "crop", "tag", "category", "drop", "fruit_count"]


func build_official_payload(version_label: String) -> Dictionary:
	var me := player_name()
	var now := int(Time.get_unix_time_from_system())
	var approved: Array = []
	var denied: Array = []
	var seen := {}
	var keep := {}
	var list_seeds: Array = []
	for id in order:
		var s: Dictionary = seeds[id]
		var by := String(s.get("made_by", "")).strip_edges()
		if by == "":
			by = me
		var key := String(s.name).strip_edges().to_lower()
		seen[key] = true
		if s.get("denied", false):
			if graveyard_removed.has(key):
				continue  # removed from the graveyard: not approved, not listed
			var d := { "name": s.name, "made_by": by }
			for k in DRAW_FIELDS:
				if s.has(k):
					d[k] = s[k]
			d.parent_names = s.get("parents", []).map(func(p): return String(get_seed(p).get("name", "?")))
			denied.append(d)
			continue
		if s.get("unstamped", false):
			continue  # stamp revoked: not approved, not handed out (players keep their copy)
		keep[id] = true
		var rsr := int(s.get("rsr", 0))
		approved.append({ "name": s.name, "made_by": by, "art": art_approved(id), "rsr": rsr if rsr >= 6 and rsr <= 10 else null })
		var o := s.duplicate(true)
		o.erase("denied")
		o.made_by = by
		var art_file := "user://block_art/%s.png" % String(id).validate_filename()
		if FileAccess.file_exists(art_file):
			o.block_art = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(art_file))
		list_seeds.append(o)
	for g in graveyard_extra:
		var key := String(g.get("name", "")).strip_edges().to_lower()
		if key != "" and not seen.has(key) and not graveyard_removed.has(key):
			var d: Dictionary = g.duplicate(true)
			d.erase("submission_id")
			denied.append(d)
			seen[key] = true
	for d in Approvals.official_denied():
		var key := String(d.get("name", "")).strip_edges().to_lower()
		if key != "" and not seen.has(key) and not graveyard_removed.has(key):
			denied.append(d)
			seen[key] = true
	var recs: Array = []
	for k in recipe_order:
		var pair := String(k).split("|")
		if keep.has(pair[0]) and keep.has(pair[1]) and keep.has(recipes[k]):
			recs.append({ "pair": k, "result": recipes[k] })
	return {
		"official": { "format": EXPORT_FORMAT, "official": true, "version": version_label, "username": me, "published": now,
			"seeds": list_seeds, "recipes": recs },
		"approvals": { "format": Approvals.FORMAT, "version": version_label, "publisher": me, "published": now,
			"approved": approved, "denied": denied },
	}


## The developer's RSR (RyeScale Rating) for a seed: 6..10, or 0 = not rated. Ships with the next
## update; an approved seed's Mycoras get x1 (6) .. x4 (10), see bank.gd.
func set_rating(id: String, rsr: int) -> void:
	if not seeds.has(id):
		return
	if rsr >= 6 and rsr <= 10:
		seeds[id].rsr = rsr
	else:
		seeds[id].erase("rsr")
	save_game()
	seeds_changed.emit()


## Is this seed's block art approved (x25 instead of x10)? Your own art counts as approved unless
## you say otherwise; a player's art only when you approved it with the seed.
func art_approved(id: String) -> bool:
	if not seeds.has(id) or not BlockArt.has_art(id):
		return false
	return bool(seeds[id].get("art_ok", true))


## Deletes a seed from your list for good (developer, Seeds panel > Delete seed): its recipes,
## block art and unlock go too. Seeds made from it stay, without that recipe. Base seeds can't go.
## Your next push / update leaves it out (players who have it keep their copy).
func delete_seed(id: String) -> bool:
	if not seeds.has(id) or BASE_SEEDS.any(func(b): return b.id == id):
		return false
	for k in recipe_order.duplicate():
		var pair := String(k).split("|")
		if recipes.get(k, "") == id or pair.has(id):
			recipes.erase(k)
			recipe_order.erase(k)
	for other in order:
		if seeds[other].get("parents", []).has(id):
			seeds[other].parents = []
	seeds.erase(id)
	order.erase(id)
	void_tokens = void_tokens.filter(func(t): return String(t.get("id", "")) != id)
	BlockArt.remove(id)
	Bank.unlocked.erase(id)
	Bank.save()
	save_game()
	seeds_changed.emit()
	recipes_changed.emit()
	return true


## THE NUKE (developer): take the approval stamp off a seed. It stays in your game, but it isn't on
## the official list any more: the next push / update takes its stamp away from every player (who
## keep their copy) and new players don't get it. on = false gives the stamp back.
func set_unstamped(id: String, on: bool) -> void:
	if not seeds.has(id):
		return
	if on:
		seeds[id].unstamped = true
	else:
		seeds[id].erase("unstamped")
	save_game()
	seeds_changed.emit()


func set_art_ok(id: String, ok: bool) -> void:
	if not seeds.has(id):
		return
	seeds[id].art_ok = ok
	save_game()
	seeds_changed.emit()


## Takes a seed out of the graveyard for good (developer): it isn't listed or published any more.
func remove_from_graveyard(seed_name: String) -> void:
	var key := seed_name.strip_edges().to_lower()
	if key == "" or graveyard_removed.has(key):
		return
	graveyard_removed.append(key)
	graveyard_extra = graveyard_extra.filter(func(g): return String(g.get("name", "")).strip_edges().to_lower() != key)
	save_game()
	seeds_changed.emit()


func is_removed_from_graveyard(seed_name: String) -> bool:
	return graveyard_removed.has(seed_name.strip_edges().to_lower())


## The developer denied a submission: its seed goes to the graveyard (once per seed name).
## Returns true if it was added.
func bury_submission(payload: Dictionary, username: String, submission_id: int, explicit := false) -> bool:
	var top: Dictionary = {}
	var names := {}
	for s in payload.get("seeds", []):
		if s is Dictionary:
			names[String(s.get("id", ""))] = String(s.get("name", "?"))
			if String(s.get("id", "")) == String(payload.get("top", "")):
				top = s
	if top.is_empty():
		return false
	var key := String(top.get("name", "")).strip_edges().to_lower()
	if key == "" or graveyard_extra.any(func(g): return String(g.get("name", "")).strip_edges().to_lower() == key):
		return false
	if graveyard_removed.has(key):
		if not explicit:
			return false  # you removed it from the graveyard: the sync never brings it back
		graveyard_removed.erase(key)  # you just denied it again: it goes back in
	var g := {}
	for k in ["name", "rarity", "pattern", "colors", "sprout", "pattern_seed", "crop", "tag", "category", "drop", "fruit_count"]:
		if top.has(k):
			g[k] = top[k]
	g.made_by = username if username != "" else String(top.get("made_by", "unknown"))
	g.parent_names = top.get("parents", []).map(func(p): return names.get(String(p), "?"))
	g.submission_id = submission_id
	graveyard_extra.append(g)
	save_game()
	seeds_changed.emit()
	return true


## The developer approves a submission: its seeds come in (credited as in the payload) with the
## block art the player drew for the ones that are new. Returns apply_import's result.
func import_submission(payload: Dictionary, with_art := true) -> Dictionary:
	var preview := preview_from(payload)
	if not preview.ok:
		return preview
	var before := {}
	for id in order:
		before[id] = true
	var r := apply_import(preview, import_offer_ids(preview))
	# block art for the seeds that just arrived (never over art you already have)
	for s in payload.get("seeds", []):
		var b64 := String(s.get("block_art", ""))
		var mine := find_by_name(String(s.get("name", "")))
		if not with_art or b64 == "" or mine == "" or before.has(mine) or BlockArt.has_art(mine):
			continue
		var img := Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) == OK and img.get_size() == Vector2i(BlockArt.FRAMES * BlockArt.SIZE, BlockArt.SIZE):
			img.convert(Image.FORMAT_RGBA8)
			BlockArt.set_art(mine, img)
	return r


## REVIEWING A SUBMISSION ONE SEED AT A TIME (developer, Settings > Submissions): a submission is a
## player's seed plus its whole recipe chain. Only seeds that aren't in your game yet need review,
## and they're reviewed from the bottom of the chain up: the next step is the first such seed whose
## ingredients are all in your game already. Returns { ok, error, their_id, name, parents (names),
## step (1-based), steps, seed (theirs) }; their_id = "" when the whole chain is in your game.
func submission_next_step(payload: Dictionary) -> Dictionary:
	var preview := preview_from(payload)
	var out := { "ok": preview.ok, "error": preview.get("error", ""), "their_id": "", "name": "", "parents": [], "step": 0, "steps": 0, "seed": {} }
	if not preview.ok:
		return out
	var names := {}
	for x in payload.get("seeds", []):
		if x is Dictionary:
			names[String(x.get("id", x.get("name", "")))] = String(x.get("name", "?"))
	var steps: Array = preview.new_seeds
	out.steps = steps.size()
	for i in steps.size():
		var n: Dictionary = steps[i]
		if n.parents.all(func(p): return preview.known.has(p)):
			out.their_id = n.their_id
			out.name = n.seed.name
			out.parents = n.parents.map(func(p): return names.get(p, "?"))
			out.step = 1
			out.seed = n.seed
			for x in payload.get("seeds", []):
				if x is Dictionary and String(x.get("id", x.get("name", ""))) == n.their_id:
					out.seed = x
			return out
	return out


## Brings ONE seed of a submission into your game (see submission_next_step), credited to the
## player, with their block art if with_art. denied: it goes straight to your graveyard (it can still
## be spliced). Returns { ok, error, id }.
func import_submission_step(payload: Dictionary, their_id: String, with_art := true, denied := false) -> Dictionary:
	var preview := preview_from(payload)
	if not preview.ok:
		return { "ok": false, "error": preview.error, "id": "" }
	apply_import(preview, [their_id])
	var src: Dictionary = {}
	for x in payload.get("seeds", []):
		if x is Dictionary and String(x.get("id", x.get("name", ""))) == their_id:
			src = x
	var id := find_by_name(String(src.get("name", "")))
	if id == "":
		return { "ok": false, "error": "That seed didn't come in.", "id": "" }
	var b64 := String(src.get("block_art", ""))
	if with_art and b64 != "" and not BlockArt.has_art(id):
		var img := Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) == OK and img.get_size() == Vector2i(BlockArt.FRAMES * BlockArt.SIZE, BlockArt.SIZE):
			img.convert(Image.FORMAT_RGBA8)
			BlockArt.set_art(id, img)
	if denied:
		set_denied(id, true)
	save_game()
	seeds_changed.emit()
	return { "ok": true, "error": "", "id": id }


## The sprite sheet sits next to the list: seed_splicer_list.json -> seed_splicer_list_seeds.png
static func sprite_sheet_path(list_path: String) -> String:
	return list_path.get_basename() + "_seeds.png"


## The sheet's columns, left to right: BlockArt.FRAMES block-art boxes (frame 0 = the block, the
## others spare for animation), then the growth stages (seed, sprout, sapling, crop, and last the tiny planted leaf).
const SHEET_BLOCK_COLUMNS: int = BlockArt.FRAMES
const SHEET_SEED_COLUMN: int = SHEET_BLOCK_COLUMNS  # x = 4 * 32


static func sheet_column_names() -> Array:
	var out: Array = ["block"]
	for f in range(1, BlockArt.FRAMES):
		out.append("block_anim_%d" % f)
	return out + CropArt.STAGE_NAMES.map(func(n): return n.to_lower())


## Every seed's art on a strict 32x32 grid (no padding, no spacing), ONE ROW PER SEED in the same
## order as the export's "seeds" list. Columns: 0-3 your block art (empty until you draw it and
## import the sheet), 4 seed, 5 sprout, 6 sapling, 7 crop (fully grown), 8 planted (a tiny leaf). Column 4 is also the seed
## item's icon. Returns { image, info } where info describes the layout for the export file.
func build_sprite_sheet() -> Dictionary:
	var cell := SeedArt.SIZE
	var cols := SHEET_BLOCK_COLUMNS + CropArt.STAGE_NAMES.size()
	var count := order.size()
	var rows := maxi(1, count)
	var img := Image.create_empty(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cells := []
	for i in count:
		var id: String = order[i]
		var art := BlockArt.get_art(id)
		if art != null:
			img.blit_rect(art, Rect2i(0, 0, SHEET_BLOCK_COLUMNS * cell, cell), Vector2i(0, i * cell))
		for st in CropArt.STAGE_NAMES.size():
			img.blit_rect(CropArt.render(seeds[id], st), Rect2i(0, 0, cell, cell), Vector2i((SHEET_SEED_COLUMN + st) * cell, i * cell))
		cells.append({ "row": i, "id": id, "name": seeds[id].name, "crop": seeds[id].crop, "y": i * cell,
			"block_frames": BlockArt.frame_count(id),
			"crop_fruit": CropArt.fruit_count(seeds[id]) if BlockArt.fruit(id) != null else 0 })
	return {
		"image": img,
		"info": {
			"cell_size": cell,
			"columns": cols,
			"column_names": sheet_column_names(),
			"rows": rows,
			"width": cols * cell,
			"height": rows * cell,
			"padding": 0,
			"cells": cells,
		},
	}


## Export Sprite Sheet: only the PNG (the same sheet Export List writes next to the list).
func export_sprite_sheet(path: String) -> Error:
	return build_sprite_sheet().image.save_png(path)


## Import Sprite Sheet: reads the block-art columns (0-3) of a sheet you exported and drew on, and
## keeps them with each seed. The seed / crop columns are made from the seeds' colors, so changes
## drawn there are not taken. A row is matched to its seed by the seed picture in column 4 (so the
## rows can't get mixed up); if that picture changed since (you restyled the seed), by its row number.
## A row whose block boxes are empty removes that seed's block art.
## Returns { ok, error, rows, with_art, cleared, by_picture, by_position, unmatched }.
func import_sprite_sheet(path: String) -> Dictionary:
	var out := { "ok": false, "error": "", "rows": 0, "with_art": 0, "cleared": 0, "by_picture": 0,
		"by_position": 0, "unmatched": 0 }
	var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
	if img == null:
		out.error = "Couldn't open that picture."
		return out
	img.convert(Image.FORMAT_RGBA8)
	var cell := SeedArt.SIZE
	var cols := SHEET_BLOCK_COLUMNS + CropArt.STAGE_NAMES.size()
	# sheets exported before the planted column was added (8 columns) still import: only the block
	# columns and the seed column are read
	var old_cols := cols - 1
	if (img.get_width() != cols * cell and img.get_width() != old_cols * cell) or img.get_height() % cell != 0:
		out.error = "That isn't a Seed Splicer sprite sheet (it should be %d px wide, 32 px per row; this one is %dx%d)." % [cols * cell, img.get_width(), img.get_height()]
		return out
	# which seed each seed picture belongs to
	var by_art := {}  # image bytes -> [ids]
	for id in order:
		var key := SeedArt.render(seeds[id]).get_data()
		if not by_art.has(key):
			by_art[key] = []
		by_art[key].append(id)
	@warning_ignore("integer_division")
	var rows := img.get_height() / cell
	var taken := {}
	var plan := []  # [id, strip]
	for r in rows:
		var seed_cell := img.get_region(Rect2i(SHEET_SEED_COLUMN * cell, r * cell, cell, cell))
		var id := ""
		for cand in by_art.get(seed_cell.get_data(), []):
			if not taken.has(cand):
				id = cand
				break
		if id != "":
			out.by_picture += 1
		elif r < order.size() and not taken.has(order[r]) and not seed_cell.is_invisible():
			id = order[r]
			out.by_position += 1
		else:
			out.unmatched += 1
			continue
		taken[id] = true
		plan.append([id, img.get_region(Rect2i(0, r * cell, SHEET_BLOCK_COLUMNS * cell, cell))])
	out.rows = rows
	for p in plan:
		var had := BlockArt.has_art(p[0])
		if p[1].is_invisible():
			if had:
				out.cleared += 1
			BlockArt.remove(p[0])
		else:
			BlockArt.set_art(p[0], p[1])
			out.with_art += 1
	out.ok = true
	seeds_changed.emit()
	return out


## The explanation written into every export. Single source of truth: the rules the designer
## decided, the meaning of each field, and how it maps onto MushMantle's block database.
static func reference_notes() -> Dictionary:
	return {
		"read_me_first": "This file is an export from Seed Splicer, a prototype tool the designer uses to invent seeds. "
			+ "It is meant to be given to Claude Code so it can add the new seeds, crops, blocks and decorations to the game "
			+ "MushMantle (a Godot 4 game). 'seeds' lists every seed, 'recipes' lists which two seeds splice into which. "
			+ "This 'reference' section explains the fields and the rules the designer decided. Where a value says "
			+ "'auto': true it was only guessed from the seed's name by keyword logic: treat it as a first draft. Where "
			+ "'auto' is false the designer chose it by hand: treat it as final.",
		"IMPORTANT_RULES": [
			"SEEDS THEMSELVES DO NOT DEAL DAMAGE. The seed item, the planted sprout and the grown crop never have "
				+ "collision damage (or any damage). Only a seed's DROP (the block or decoration it gives when harvested) "
				+ "can have collision damage. Do not add damage to seeds, sprouts or crops.",
			"Every seed has a 'drop': what it gives when harvested. The drop is a BLOCK, a DECORATION or a BACKGROUND, and a "
				+ "block or decoration may or may not have COLLISION. The drop's name is the seed's name without ' Seed' (Glass Seed drops Glass).",
			"drop.collision = true means the drop is solid: the player collides with it and cannot walk through. "
				+ "false means the player walks through it.",
			"drop.damage = true is the COLLISION DAMAGE tag: colliding with / touching that drop hurts the player. "
				+ "It only ever appears together with collision = true. Drops that look dangerous (lava, magma, fire, "
				+ "spikes, cactus, thorns, blades, acid, poison...) got it.",
			"drop.kind = 'background' is a picture for the background layer (name has Background / Backdrop...). It never collides "
				+ "and never deals damage. Its checklist is drop.bg_tags, any of: emits_light, underground (cave), outdoors (sky), animated.",
			"drop.light = true is the EMITS LIGHT tag: the block, decoration or background gives off light (torches, lava, a glowing cave "
				+ "background). Any kind can have it. For a background it is also listed as 'emits_light' in drop.bg_tags.",
			"The designer will later choose collision / no collision (and damage) by hand for any drop; "
				+ "'drop.auto' = false marks those. Never overwrite a drop whose auto is false.",
			"MYCORAS are the currency (MushMantle called them Spores; same math, scripts/mycora.gd): breaking a block rolls its block "
				+ "(25%) and its seed (25%); when neither comes out it drops 1 to 1 + floor(rarity / 4) Mycoras. A harvest always gives "
				+ "the blocks, plus the seed (25%) or else Mycoras for Farmable / Bountiful, and Mycoras every time for Not Farmable. "
				+ "A Chest gives itself back, never Mycoras.",
		],
		"seed_fields": {
			"id": "unique id of the seed",
			"name": "display name, e.g. 'Glass Seed'",
			"rarity": "tier. Tier 1 (rarity 1) seeds are the starting seeds; a spliced seed's rarity = the sum of its two parents' rarities",
			"pattern": "look of the seed art: " + ", ".join(PackedStringArray(SeedArt.PATTERN_NAMES)) + " (index into that list)",
			"colors": "two hex colors used by the pattern",
			"sprout": "hex color of the sprout leaves on the seed art",
			"pattern_seed": "random variation inside the pattern (art only)",
			"tag": "farmable | not_farmable | bountiful (see 'tags')",
			"fruit_count": "0 = automatic (1-4, picked once per seed); 1-4 = how many block fruits the grown crop picture carries, set by the designer",
			"crop": "what the seed grows into, one of: " + ", ".join(PackedStringArray(CropArt.types().map(func(t): return "%s (%s)" % [t.id, t.name])))
				+ ". Art only: every crop type is painted in its seed's own colors (colors[0] = main / leaves or cap, "
				+ "colors[1] = accents like fruit, cones, blossoms or spots, sprout = stems and young leaves). See 'sprite_sheet'.",
			"drop": "{ kind: 'block'|'decoration'|'background', collision: bool, damage: bool, light: bool, bg_tags: [..], auto: bool } (see IMPORTANT_RULES)",
			"category": "{ material, hardness: 1-5, status: 'auto'|'agreed'|'changed' } - what the drop is made of and how hard it is to break (see 'categories')",
			"parents": "[idA, idB] of the first recipe that made it; empty for tier 1 seeds",
			"custom": "true if the designer added it as their own tier 1 seed",
			"found": "unix time it was added (0 for the 4 starting seeds)",
		},
		"sprite_sheet": "Every export also writes a PNG next to this file (named in sprite_sheet.file) with every seed's art "
			+ "on a strict 32x32 grid: no padding, no spacing, transparent background. ONE ROW PER SEED, in the same order as "
			+ "'seeds' (row i = seeds[i], pixel y = i * 32; sprite_sheet.cells lists each row's id, name, crop and how many "
			+ "block frames are drawn). NINE COLUMNS (sprite_sheet.column_names): x = 0 the BLOCK (the seed's drop, drawn by the "
			+ "designer), x = 32 / 64 / 96 spare block frames for an animation (empty unless drawn; block_frames counts the drawn "
			+ "boxes), then the 4 growth stages: x = 128 seed, x = 160 sprout, x = 192 sapling, x = 224 crop (fully grown), and last x = 256 PLANTED. "
			+ "PLANTED is just a tiny leaf in the seed's colors: the picture to show right after a seed is planted (the seed item "
			+ "itself is far too big to look right in the ground). It comes after the seed and before the sprout in the growth order, "
			+ "but sits at the far right of the sheet so the older columns did not move. MushMantle's older tools simply ignore it. "
			+ "The grown crop (x = 224) carries 1-4 small copies of the seed's block hanging on it like fruit (the block "
			+ "art shrunk to 9x9 on the same 32x32 pixel grid, never smoothed); sprite_sheet.cells[i].crop_fruit is how many "
			+ "(0 = no block art yet, so no fruit). It is only a picture of the grown crop: what a harvest drops is set by 'tags'. "
			+ "The seed column is also the SEED_* item icon. The bottom pixel row of the sprout / sapling / crop cells is the "
			+ "ground: the plant grows up from it. MushMantle's art is native 32x32 too (GameData.ART_SIZE) and its tile pages "
			+ "are 4 columns wide (a block's art is a row, its variants / animation frames are the columns, 128 rows per page): "
			+ "the 4 block columns of a row are that drop block's tile row; seed / sprout / sapling are the 3 visual growth stages "
			+ "(GameData.CROP_STAGES = 3, the atlas variants of the CRP_*_SPROUT block) and crop is the grown CRP_* block. "
			+ "If a row has no block art yet (block_frames = 0), ask the designer before inventing one.",
		"recipes": "Each entry: pair = 'idA|idB' (order doesn't matter) and result = the id of the seed it makes. "
			+ "A seed can have several recipes. In MushMantle recipes live in GameData.splices().",
		"tags": {
			"farmable": "MushMantle rule: a farmable crop drops 1-16 of its block (always) and 25% of the time a seed.",
			"not_farmable": "MushMantle rule: a non-farmable crop drops only 1-4 of its block and never gives seeds.",
			"bountiful": "NEW tier above farmable, invented in Seed Splicer. The designer has not defined its numbers yet: ask before implementing.",
			"how_assigned": "Seeds made by splicing roll their tag: rarity 2-10: 50% not farmable, 37.5% farmable, 12.5% bountiful; "
				+ "rarity 11+: 75% not farmable, 18.75% farmable, 6.25% bountiful. Tier 1 seeds keep the tag the designer chose.",
		},
		"mushmantle_mapping": {
			"collision": "BlockType.solid, i.e. \"solid\": true in data/game_data.json (and scripts/core/game_data.gd). "
				+ "collision = false means leaving solid out (the .non_solid() flag in BlockDB).",
			"damage": "\"damage\": N in game_data.json (hearts of contact damage, BlockType.contact_damage). BLK_LAVA is the "
				+ "existing example: \"solid\": true, \"damage\": 1. The amount for the new damaging drops is not decided: ask the "
				+ "designer, 1 heart (like Lava) is a sensible default.",
			"background": "decorations named '... Background' use the background layer: \"category\": \"Background\", \"background\": true (see BLK_CAVE_BACKGROUND). Never solid.",
			"door": "\"door\": true, \"category\": \"Door\", not solid (see BLK_DOOR).",
			"seeds_and_crops": "A seed is an item that plants a crop that grows through a sprout stage (see the existing SEED_*, CRP_*_SPROUT and CRP_* entries in game_data.gd). Seeds and crops carry no damage.",
		},
		"categories": {
			"about": "Every drop has a material and a hardness. 'status' says who decided: 'auto' = guessed from the name by keyword logic "
				+ "(a draft), 'agreed' = the designer confirmed the guess, 'changed' = the designer picked it. Treat agreed and changed as final.",
			"materials": CategoryLogic.MATERIAL_NAMES,
			"hardness": { "1": "Very soft", "2": "Soft", "3": "Medium", "4": "Hard", "5": "Very hard" },
			"mushmantle_hits": "Suggested MushMantle \"hits\" (Fist hits to break) per hardness: 1 -> 2, 2 -> 4, 3 -> 5, 4 -> 8, 5 -> 12 "
				+ "(existing examples: Dirt 4, Wood 5, Stone 8, Obsidian 12). MushMantle's \"material\" field is \"wood\" or \"mushroom\" "
				+ "for the Stone Axe; map material 'wood' -> \"wood\" and 'mushroom' -> \"mushroom\", leave it empty otherwise.",
			"words": CategoryLogic.word_lists(),
		},
		"drop_logic": {
			"about": "How 'auto' drops were guessed from the name (lowercase words; plural 's' ignored; long words also match inside longer words).",
			"rule_0": "If the name has a background word -> kind = background (no collision, no damage). A light word -> light = true. A background also gets underground / outdoors from its words.",
			"rule_1": "Otherwise, if the name has a decoration word -> kind = decoration (collision false unless it also has a solid decoration word). Otherwise kind = block with collision true.",
			"rule_2": "Blocks named after a liquid or gas (non_solid_block_words) have collision false.",
			"rule_3": "If the name has a danger word -> damage = true and collision = true.",
			"words": DropLogic.word_lists(),
		},
	}


## Importing a friend's list happens in two steps, so you can say yes or no to each new seed:
##   1. read_import(path)  reads the file and changes nothing. It returns a "preview".
##   2. apply_import(preview, chosen)  adds only the new seeds you picked, plus every splice
##      whose seeds you then all have.
## Seeds are matched by name (case-insensitive): one you already have keeps YOUR look, tag,
## drop and rarity and is never offered. If you both spliced the same pair, yours wins.
## import_list(path) does both steps and takes every new seed (used by tests).

## Preview: { ok, error, known (their id -> my id), new_seeds: [ { their_id, seed, parents } ],
##            recipes: [ { pair: [their a, their b], result: their id } ] }
## `seed` is the cleaned seed as it would be added (without an id yet); `parents` are their ids.
func read_import(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return { "ok": false, "error": "File not found.", "known": {}, "new_seeds": [], "recipes": [] }
	return preview_from(JSON.parse_string(FileAccess.get_file_as_string(path)))


## The import preview of a parsed list (a file, or the official list). Who made each new seed:
## its own made_by, else the list's username, else "unknown". A reserved name (RyeeRue...) in a
## player's file is never believed: those seeds count as unknown.
func preview_from(parsed: Variant) -> Dictionary:
	var out := { "ok": false, "error": "", "known": {}, "new_seeds": [], "recipes": [], "username": "" }
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("seeds")) != TYPE_ARRAY:
		out.error = "That file isn't a Seed Splicer list."
		return out
	if parsed.has("format") and parsed.format != EXPORT_FORMAT:
		out.error = "That file isn't a Seed Splicer list."
		return out
	var official: bool = parsed.get("official", false)
	var uname := String(parsed.get("username", "")).strip_edges().left(32)
	if not official and DevMode.is_reserved(uname):
		uname = ""
	out.username = uname
	var names_seen := {}  # lowercase name -> their id, so a name listed twice is offered once
	for s in parsed.seeds:
		if typeof(s) != TYPE_DICTIONARY or String(s.get("name", "")).strip_edges() == "":
			continue
		var their_id := String(s.get("id", s.name))
		var mine := find_by_name(s.name)
		if mine != "":
			out.known[their_id] = mine
			continue
		var lname := String(s.name).strip_edges().to_lower()
		if names_seen.has(lname):
			continue
		names_seen[lname] = their_id
		var colors: Array = s.get("colors", [])
		var parents: Array = s.get("parents", []) if typeof(s.get("parents")) == TYPE_ARRAY else []
		out.new_seeds.append({
			"their_id": their_id,
			"parents": parents.map(func(p): return String(p)),
			"clash": "",  # filled below: your seed that their recipe for this one already makes

			"seed": {
				"name": String(s.name).strip_edges().left(40),
				"rarity": maxi(1, int(s.get("rarity", 1))),
				"pattern": clampi(int(s.get("pattern", 0)), 0, SeedArt.Pattern.size() - 1),
				"colors": [_valid_color(colors[0] if colors.size() > 0 else null, "#888888"),
					_valid_color(colors[1] if colors.size() > 1 else null, "#555555")],
				"sprout": _valid_color(s.get("sprout"), "#7ccf4e"),
				"pattern_seed": int(s.get("pattern_seed", 0)),
				"tag": _valid_tag(s.get("tag", "")),
				"crop": CropArt.valid_type(s.get("crop"), String(s.name).strip_edges().to_lower()),
				"fruit_count": clampi(int(s.get("fruit_count", 0)), 0, CropArt.MAX_FRUIT),
				# their drop if they sent one (an older export: guess it from the name)
				"drop": DropLogic.sanitize(s.get("drop"), String(s.name)),
			"category": CategoryLogic.sanitize(s.get("category"), String(s.name), DropLogic.sanitize(s.get("drop"), String(s.name))),
				"custom": bool(s.get("custom", false)),
				"made_by": _credit(String(s.get("made_by", "")), uname, official),
			},
		})
	for r in parsed.get("recipes", []):
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var pair := String(r.get("pair", "")).split("|")
		if pair.size() == 2:
			out.recipes.append({ "pair": [pair[0], pair[1]], "result": String(r.get("result", "")) })
	# Cross-check recipes: a new seed of theirs whose recipe uses two seeds you have, where that
	# pair ALREADY makes one of your seeds (same splice, different name). Your recipe wins.
	for n in out.new_seeds:
		var ps: Array = n.parents
		if ps.size() == 2 and out.known.has(ps[0]) and out.known.has(ps[1]):
			var key := recipe_key(out.known[ps[0]], out.known[ps[1]])
			if recipes.has(key):
				n.clash = recipes[key]
	out.ok = true
	return out


func _credit(made_by: String, uname: String, official: bool) -> String:
	var by := made_by.strip_edges().left(32)
	if by != "" and (official or not DevMode.is_reserved(by)):
		return by
	return uname if uname != "" else "unknown"


## Their ids of the new seeds a preview offers.
static func import_offer_ids(preview: Dictionary) -> Array:
	return preview.new_seeds.map(func(n): return n.their_id)


## The new seeds `chosen` still needs as ingredients (their ids, not chosen and not already yours),
## for the seeds in `for_ids`.
static func import_missing(preview: Dictionary, chosen: Array, for_ids: Array) -> Array:
	var missing: Array = []
	for n in preview.new_seeds:
		if not for_ids.has(n.their_id):
			continue
		for p in n.parents:
			if not preview.known.has(p) and not chosen.has(p) and not missing.has(p):
				missing.append(p)
	return missing


## `chosen` plus every new seed they need to be made, all the way down.
static func import_with_needed(preview: Dictionary, chosen: Array) -> Array:
	var out := chosen.duplicate()
	var grew := true
	while grew:
		var add := import_missing(preview, out, out).filter(func(p): return import_offer_ids(preview).has(p))
		grew = not add.is_empty()
		out.append_array(add)
	return out


## How many splices would come in with this choice (nothing is changed).
func import_recipe_count(preview: Dictionary, chosen: Array) -> int:
	var have := func(their: String) -> bool: return preview.known.has(their) or chosen.has(their)
	var n := 0
	var seen := {}
	for r in preview.recipes:
		var a: String = r.pair[0]
		var b: String = r.pair[1]
		if a == b or not have.call(a) or not have.call(b) or not have.call(r.result):
			continue
		if preview.known.has(a) and preview.known.has(b) and recipes.has(recipe_key(preview.known[a], preview.known[b])):
			continue  # you already have this splice
		var k := a + "|" + b if a <= b else b + "|" + a
		if not seen.has(k):
			seen[k] = true
			n += 1
	return n


## Adds the chosen new seeds (their ids) and the splices that come with them.
## Returns { ok, error, seeds_added, seeds_declined, seeds_known, recipes_added, recipes_skipped }.
func apply_import(preview: Dictionary, chosen: Array) -> Dictionary:
	var out := { "ok": preview.get("ok", false), "error": preview.get("error", ""), "seeds_added": 0,
		"seeds_declined": 0, "seeds_known": preview.get("known", {}).size(), "recipes_added": 0, "recipes_skipped": 0,
		"recipes_kept_yours": 0 }
	if not out.ok:
		return out
	var idmap: Dictionary = preview.known.duplicate()  # their id -> my id
	var new_ids: Array[String] = []
	var their_parents := {}  # my new id -> their parent ids
	for n in preview.new_seeds:
		if not chosen.has(n.their_id):
			out.seeds_declined += 1
			continue
		var id := _unique_id(n.seed.name)
		var s: Dictionary = n.seed.duplicate(true)
		s.id = id
		s.parents = []
		s.found = int(Time.get_unix_time_from_system())
		seeds[id] = s
		order.append(id)
		idmap[n.their_id] = id
		new_ids.append(id)
		their_parents[id] = n.parents
		out.seeds_added += 1

	# link parents now that every id is known, and re-apply the rarity rule with MY parents.
	# A seed whose ingredients you left out keeps the rarity it had in their game.
	# YOUR RECIPE ALWAYS WINS: if that pair of seeds already makes one of your seeds, the
	# imported seed does not get those parents (it comes in without a recipe, with their rarity).
	for id in new_ids:
		var tp: Array = their_parents[id]
		if tp.size() == 2 and idmap.has(tp[0]) and idmap.has(tp[1]):
			var pa: String = idmap[tp[0]]
			var pb: String = idmap[tp[1]]
			if recipes.has(recipe_key(pa, pb)):
				out.recipes_kept_yours += 1
				continue
			seeds[id].parents = [pa, pb]
			seeds[id].rarity = int(seeds[pa].rarity) + int(seeds[pb].rarity)
		elif tp.is_empty():
			seeds[id].rarity = 1

	for r in preview.recipes:
		var ta: String = r.pair[0]
		var tb: String = r.pair[1]
		if not idmap.has(ta) or not idmap.has(tb) or not idmap.has(r.result):
			out.recipes_skipped += 1
			continue
		var a: String = idmap[ta]
		var b: String = idmap[tb]
		if not can_splice(a, b) or recipes.has(recipe_key(a, b)):  # your recipe for this pair wins
			out.recipes_skipped += 1
			continue
		var key := recipe_key(a, b)
		recipe_order.append(key)
		recipes[key] = idmap[r.result]
		out.recipes_added += 1

	seeds_changed.emit()
	recipes_changed.emit()
	save_game()
	return out


## Reads a friend's list and takes every new seed in it.
func import_list(path: String) -> Dictionary:
	var preview := read_import(path)
	return apply_import(preview, import_offer_ids(preview) if preview.ok else [])


func _valid_color(c: Variant, fallback: String) -> String:
	if typeof(c) == TYPE_STRING and Color.html_is_valid(c):
		return "#" + Color.html(c).to_html(false)
	return fallback
