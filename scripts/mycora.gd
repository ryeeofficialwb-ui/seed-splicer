class_name Mycora
extends RefCounted
## Mycoras: the currency orbs blocks drop (called Spores in Mush Mantle before). Same math as
## Mush Mantle's tools/gen_database.py, like Growtopia's gems:
##   Breaking a block rolls its block (25%) and its seed (25%). When neither comes out, it drops
##   1 to 1 + floor(rarity / 4) Mycoras instead (so 0.75 x 0.75 = 56.25% of breaks).
##   Harvesting a grown crop always gives its blocks, plus:
##     Farmable / Bountiful   its seed (25%), or Mycoras when no seed comes out (75%)
##     Not Farmable           Mycoras every harvest (it never gives a seed)
##   A Chest gives itself back, never Mycoras.

const BLOCK_CHANCE := 0.25
const SEED_CHANCE := 0.25
const COLOR := Color("#7dffc0")
const NO_MYCORAS := ["chest"]


## The most Mycoras one drop can give: +1 for every 4 rarity.
static func max_for(rarity: int) -> int:
	return 1 + maxi(rarity, 0) / 4


static func drops_any(seed: Dictionary) -> bool:
	return not NO_MYCORAS.has(String(seed.get("id", "")))


## How often breaking the block gives Mycoras (neither its block nor its seed came out).
static func break_chance() -> float:
	return (1.0 - BLOCK_CHANCE) * (1.0 - SEED_CHANCE)


## How often a harvest gives Mycoras.
static func harvest_chance(seed: Dictionary) -> float:
	return 1.0 if String(seed.get("tag", "")) == "not_farmable" else 1.0 - SEED_CHANCE


## On average, Mycoras per block broken.
static func average_per_break(seed: Dictionary) -> float:
	if not drops_any(seed):
		return 0.0
	return break_chance() * (1.0 + max_for(int(seed.get("rarity", 1)))) / 2.0


## "1-5" (or "-" for a seed whose block never drops Mycoras).
static func range_text(seed: Dictionary) -> String:
	if not drops_any(seed):
		return "-"
	var m := max_for(int(seed.get("rarity", 1)))
	return "1" if m == 1 else "1-%d" % m


static func break_text(seed: Dictionary) -> String:
	if not drops_any(seed):
		return "none (it gives itself back)"
	return "%s when neither its block nor its seed drops (%d%% of breaks), about %.1f per break" % [
		range_text(seed), roundi(break_chance() * 100.0), average_per_break(seed)]


static func harvest_text(seed: Dictionary) -> String:
	if not drops_any(seed):
		return "none"
	if String(seed.get("tag", "")) == "not_farmable":
		return "%s every harvest (it never gives a seed)" % range_text(seed)
	return "%s when its seed doesn't drop (%d%% of harvests)" % [range_text(seed), roundi(harvest_chance(seed) * 100.0)]
