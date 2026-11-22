extends Node
## Autoload "Bank": your Mycoras, which seeds make them, the Shop's booster packs, offline earnings.
##
## MAKING MYCORAS: every 3 seconds each producing seed makes its Mycora drop (Mush Mantle's math,
## the average of 1 .. 1 + rarity / 4, see mycora.gd), times its boosts, times the weather:
##   approved by the developer (the stamp)      x10
##   approved WITH its art                       x25 (instead of x10)
##   RSR, the developer's 6-10 rating            x1, x1.75, x2.5, x3.25, x4
##   weather (weather.gd)                        Rain x2, Thunderstorm x100, Shooting Star x100
## The 4 base seeds always produce. Every other seed (graveyarded or not) produces only once you
## unlock it from a booster pack in the Shop.
## BOOSTER PACKS: PACK_PRICE each, opened 1, 3 or 5 at a time. A pack holds CARDS_PER_PACK seed
## cards: any seed in your game except the base seeds, a rarer seed less often (chance ~ 1 /
## rarity); the LAST card is always Rare or better (when your game has such a seed). A card you
## already unlocked pays 5 minutes of its Mycoras instead.
## While the game is closed your seeds keep producing for 1 HOUR (MAX_AWAY), then stop until you
## come back (the weather of that hour counts too).
## Saved in its own small file every 30 s and when the game closes.

signal changed

const TICK := 3.0
const SAVE_PATH := "user://seed_splicer_mycoras.json"
const PACK_PRICE := 10000
const CARDS_PER_PACK := 5
const PACK_COUNTS: Array[int] = [1, 3, 5]
const RARE_AT := 4  ## the guaranteed card is at least this rarity (Rare, see SeedArt.rarity_tier)
const DUPLICATE_SECONDS := 300.0
const APPROVED_MULT := 10.0
const ART_MULT := 25.0
const RSR_MULT := { 6: 1.0, 7: 1.75, 8: 2.5, 9: 3.25, 10: 4.0 }
const MAX_AWAY := 3600  ## offline earnings stop after 1 hour away

var mycoras := 0.0
var unlocked := {}   # seed id -> true
var packs := 0
var earned_total := 0.0
var last_time := 0
var away_report := {}  # { seconds, earned } after an offline catch-up
var _t := 0.0
var _save_t := 0.0


func _ready() -> void:
	_load()
	# offline earnings: the first hour after you closed the game (weather included), then nothing
	var now := Weather.now()
	if last_time > 0 and now > last_time:
		var away := now - last_time
		var counted := mini(away, MAX_AWAY)
		var got := rate_per_second() * Weather.boosted_seconds(last_time, last_time + counted)
		if got > 0.0 and away >= 60:
			_earn(got)
			away_report = { "seconds": away, "earned": got }
	last_time = now
	save()


func _process(delta: float) -> void:
	_t += delta
	_save_t += delta
	if _t >= TICK:
		_t -= TICK
		_earn(rate_per_tick() * Weather.current().mult)
		last_time = Weather.now()
	if _save_t >= 30.0:
		save()


func _exit_tree() -> void:
	last_time = Weather.now()
	save()


func _earn(n: float) -> void:
	mycoras += n
	earned_total += n
	changed.emit()


# --- production ------------------------------------------------------------------------------

static func is_base(id: String) -> bool:
	return Game.BASE_SEEDS.any(func(b): return b.id == id)


func produces(id: String) -> bool:
	return Game.seeds.has(id) and (is_base(id) or unlocked.has(id))


## A seed's boost (without the weather): the stamp / art / RSR.
static func boost(seed: Dictionary) -> float:
	var info := Approvals.info(seed)
	if info.is_empty():
		return 1.0
	var m := ART_MULT if info.art else APPROVED_MULT
	return m * float(RSR_MULT.get(int(info.rsr), 1.0))


## Mycoras one seed makes every 3 seconds (without the weather).
static func seed_rate(seed: Dictionary) -> float:
	if seed.is_empty() or not Mycora.drops_any(seed):
		return 0.0
	return (1.0 + Mycora.max_for(int(seed.get("rarity", 1)))) / 2.0 * boost(seed)


func rate_per_tick() -> float:
	var total := 0.0
	for id in Game.order:
		if produces(id):
			total += seed_rate(Game.seeds[id])
	return total


func rate_per_second() -> float:
	return rate_per_tick() / TICK


# --- booster packs ------------------------------------------------------------------------------

## Every seed a card can show, with its weight (1 / rarity). rare_only: only Rare or better.
func pack_pool(rare_only := false) -> Array:
	var out: Array = []
	for id in Game.order:
		if not is_base(id) and (not rare_only or int(Game.seeds[id].rarity) >= RARE_AT):
			out.append({ "id": id, "weight": 1.0 / maxf(1.0, float(Game.seeds[id].rarity)) })
	return out


## The pool of the guaranteed last card: Rare or better, or everything if you have none of those.
func rare_pool() -> Array:
	var rare := pack_pool(true)
	return rare if not rare.is_empty() else pack_pool()


## Chance of one seed on a normal card (0..1).
func chance_of(id: String) -> float:
	return chance_in(pack_pool(), id)


static func chance_in(pool: Array, id: String) -> float:
	var total := 0.0
	var mine := 0.0
	for p in pool:
		total += p.weight
		if p.id == id:
			mine = p.weight
	return mine / total if total > 0.0 else 0.0


func pick(rng: RandomNumberGenerator, pool: Array = []) -> String:
	if pool.is_empty():
		pool = pack_pool()
	var total := 0.0
	for p in pool:
		total += p.weight
	var r := rng.randf() * total
	for p in pool:
		r -= p.weight
		if r <= 0.0:
			return p.id
	return pool[-1].id if not pool.is_empty() else ""


## The price of opening n packs at once.
static func packs_price(n: int) -> float:
	return float(PACK_PRICE * n)


## Opens n packs at once (1, 3 or 5).
## { ok, error, packs: [[card x CARDS_PER_PACK] per pack], new_count, payout }
## A card is { id, new, payout, rare_slot }. Cards resolve in order, so a seed that shows up twice
## in one opening is new the first time and a duplicate (paying Mycoras) after that.
func open_packs(n: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var out := { "ok": false, "error": "", "packs": [], "new_count": 0, "payout": 0.0 }
	if not PACK_COUNTS.has(n):
		out.error = "Packs come in 1, 3 or 5."
		return out
	if mycoras < packs_price(n):
		out.error = "You need %s Mycoras for %s." % [fmt(packs_price(n)), "a pack" if n == 1 else "%d packs" % n]
		return out
	if pack_pool().is_empty():
		out.error = "Splice a seed first: packs only hold seeds in your game."
		return out
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	mycoras -= packs_price(n)
	packs += n
	var normal := pack_pool()
	var rare := rare_pool()
	for k in n:
		var cards: Array = []
		for c in CARDS_PER_PACK:
			var last := c == CARDS_PER_PACK - 1
			var id := pick(rng, rare if last else normal)
			var card := { "id": id, "new": not unlocked.has(id), "payout": 0.0, "rare_slot": last }
			if card.new:
				unlocked[id] = true
				out.new_count += 1
			else:
				card.payout = seed_rate(Game.seeds[id]) * DUPLICATE_SECONDS / TICK
				out.payout += card.payout
			cards.append(card)
		out.packs.append(cards)
	out.ok = true
	if out.payout > 0.0:
		_earn(out.payout)
	save()
	changed.emit()
	return out


# --- saving ---------------------------------------------------------------------------------------

func save() -> void:
	_save_t = 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({ "mycoras": mycoras, "unlocked": unlocked.keys(), "packs": packs,
			"earned_total": earned_total, "last_time": last_time }, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary:
		return
	mycoras = maxf(0.0, float(d.get("mycoras", 0.0)))
	packs = int(d.get("packs", d.get("chests", 0)))  # (old saves counted chests)
	earned_total = float(d.get("earned_total", 0.0))
	last_time = int(d.get("last_time", 0))
	unlocked.clear()
	for id in d.get("unlocked", []):
		unlocked[String(id)] = true


## Reset Progress: Mycoras and unlocks go too.
func reset() -> void:
	mycoras = 0.0
	unlocked.clear()
	packs = 0
	earned_total = 0.0
	last_time = Weather.now()
	save()
	changed.emit()


## 1234567 -> "1,234,567"; big numbers shortened: 12.3M, 4.56B
static func fmt(n: float) -> String:
	if n >= 1e9:
		return "%.2fB" % (n / 1e9)
	if n >= 1e7:
		return "%.1fM" % (n / 1e6)
	var s := str(int(floor(n)))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
