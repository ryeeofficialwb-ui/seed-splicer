extends Node
## Autoload "Bank": your Mycoras, which seeds make them, the Seed Chest, and offline earnings.
##
## MAKING MYCORAS: every 3 seconds each producing seed makes its Mycora drop (Mush Mantle's math,
## the average of 1 .. 1 + rarity / 4, see mycora.gd), times its boosts, times the weather:
##   approved by the developer (the stamp)      x10
##   approved WITH its art                       x25 (instead of x10)
##   RSR, the developer's 6-10 rating            x1, x1.75, x2.5, x3.25, x4
##   weather (weather.gd)                        Rain x2, Shooting Star x100
## The 4 base seeds always produce. Every other seed (graveyarded or not) produces only once you
## unlock it from the Seed Chest. The chest costs CHEST_PRICE; any seed in your game except the
## base seeds can come out, a rarer seed less often (chance ~ 1 / rarity). A seed you already
## unlocked pays 5 minutes of its Mycoras instead.
## While the game is closed you keep earning (the weather you missed counts too).
## Saved in its own small file every 30 s and when the game closes.

signal changed

const TICK := 3.0
const SAVE_PATH := "user://seed_splicer_mycoras.json"
const CHEST_PRICE := 5000
const DUPLICATE_SECONDS := 300.0
const APPROVED_MULT := 10.0
const ART_MULT := 25.0
const RSR_MULT := { 6: 1.0, 7: 1.75, 8: 2.5, 9: 3.25, 10: 4.0 }
const MAX_AWAY := 365 * 24 * 3600

var mycoras := 0.0
var unlocked := {}   # seed id -> true
var chests := 0
var earned_total := 0.0
var last_time := 0
var away_report := {}  # { seconds, earned } after an offline catch-up
var _t := 0.0
var _save_t := 0.0


func _ready() -> void:
	_load()
	# offline earnings: everything since the last save, weather included
	var now := Weather.now()
	if last_time > 0 and now > last_time:
		var away := mini(now - last_time, MAX_AWAY)
		var got := rate_per_second() * Weather.boosted_seconds(now - away, now)
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


# --- the Seed Chest ------------------------------------------------------------------------------

## Every seed that can come out of the chest, with its weight (1 / rarity).
func chest_pool() -> Array:
	var out: Array = []
	for id in Game.order:
		if not is_base(id):
			out.append({ "id": id, "weight": 1.0 / maxf(1.0, float(Game.seeds[id].rarity)) })
	return out


## Chance of one seed coming out (0..1).
func chance_of(id: String) -> float:
	var total := 0.0
	var mine := 0.0
	for p in chest_pool():
		total += p.weight
		if p.id == id:
			mine = p.weight
	return mine / total if total > 0.0 else 0.0


func pick(rng: RandomNumberGenerator) -> String:
	var pool := chest_pool()
	var total := 0.0
	for p in pool:
		total += p.weight
	var r := rng.randf() * total
	for p in pool:
		r -= p.weight
		if r <= 0.0:
			return p.id
	return pool[-1].id if not pool.is_empty() else ""


## Opens one chest. { ok, error, id, new, payout }
func open_chest(rng: RandomNumberGenerator = null) -> Dictionary:
	if mycoras < CHEST_PRICE:
		return { "ok": false, "error": "You need %s Mycoras." % fmt(CHEST_PRICE) }
	if chest_pool().is_empty():
		return { "ok": false, "error": "Splice a seed first: the chest only holds seeds in your game." }
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var id := pick(rng)
	mycoras -= CHEST_PRICE
	chests += 1
	var out := { "ok": true, "error": "", "id": id, "new": not unlocked.has(id), "payout": 0.0 }
	if out.new:
		unlocked[id] = true
	else:
		out.payout = seed_rate(Game.seeds[id]) * DUPLICATE_SECONDS / TICK
		_earn(out.payout)
	save()
	changed.emit()
	return out


# --- saving ---------------------------------------------------------------------------------------

func save() -> void:
	_save_t = 0.0
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({ "mycoras": mycoras, "unlocked": unlocked.keys(), "chests": chests,
			"earned_total": earned_total, "last_time": last_time }, "\t"))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not d is Dictionary:
		return
	mycoras = maxf(0.0, float(d.get("mycoras", 0.0)))
	chests = int(d.get("chests", 0))
	earned_total = float(d.get("earned_total", 0.0))
	last_time = int(d.get("last_time", 0))
	unlocked.clear()
	for id in d.get("unlocked", []):
		unlocked[String(id)] = true


## Reset Progress: Mycoras and unlocks go too.
func reset() -> void:
	mycoras = 0.0
	unlocked.clear()
	chests = 0
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
