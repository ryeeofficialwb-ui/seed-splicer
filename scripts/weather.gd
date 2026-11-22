class_name Weather
extends RefCounted
## THE WEATHER: every 5 minutes on the 24-hour clock (12:00, 12:05, 12:10 ...) the sky rolls:
##   Rain            1 in 10    all Mycoras x2     for those 5 minutes
##   Thunderstorm    1 in 50    all Mycoras x100   for those 5 minutes (thunder and lightning)
##   Shooting Star   1 in 250   all Mycoras x100   for those 5 minutes
## They stack: Thunderstorm + Rain x200, Shooting Star + Thunderstorm x10000. The thunder roll
## comes after the other two, so the Rain and Shooting Stars of every slot stayed the same. The roll comes from the world clock (UTC) and a fixed formula, so every
## player has the same weather at the same moment, and the game knows the weather of any past
## 5 minutes (offline earnings use it).

const SLOT := 300            ## 5 minutes
const RAIN_CHANCE := 10      ## 1 in 10
const STAR_CHANCE := 250     ## 1 in 250
const THUNDER_CHANCE := 50   ## 1 in 50
const RAIN_MULT := 2.0
const STAR_MULT := 100.0
const THUNDER_MULT := 100.0
const SALT := 0x5EED5911

## Tests can move the clock (seconds added to the real time).
static var clock_offset := 0


static func now() -> int:
	return int(Time.get_unix_time_from_system()) + clock_offset


static func slot_of(unix: int) -> int:
	return int(floor(unix / float(SLOT)))


## The weather of one 5-minute slot: { rain, star, thunder, mult, start, end }
static func of_slot(slot: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(slot ^ SALT)
	var rain := rng.randi_range(1, RAIN_CHANCE) == 1
	var star := rng.randi_range(1, STAR_CHANCE) == 1
	var thunder := rng.randi_range(1, THUNDER_CHANCE) == 1
	var mult := (RAIN_MULT if rain else 1.0) * (STAR_MULT if star else 1.0) * (THUNDER_MULT if thunder else 1.0)
	return { "rain": rain, "star": star, "thunder": thunder, "mult": mult, "start": slot * SLOT, "end": (slot + 1) * SLOT }


static func current() -> Dictionary:
	return of_slot(slot_of(now()))


## "Rain  x2" / "Thunderstorm  x100" / "Shooting Star + Rain  x200" / "" (clear)
static func name_of(w: Dictionary) -> String:
	var parts := PackedStringArray()
	if w.star:
		parts.append("Shooting Star")
	if w.get("thunder", false):
		parts.append("Thunderstorm")
	if w.rain:
		parts.append("Rain")
	return "" if parts.is_empty() else "%s  x%d" % [" + ".join(parts), int(w.mult)]


## The weather's icon in assets/ui (the strongest weather wins).
static func icon_of(w: Dictionary) -> String:
	if w.star:
		return "w_star"
	if w.get("thunder", false):
		return "w_thunder"
	if w.rain:
		return "w_rain"
	return "w_clear"


## Weather-weighted seconds between two times: each second counts its slot's multiplier.
## (Offline earnings: rate per second x this.)
static func boosted_seconds(from_unix: int, to_unix: int) -> float:
	if to_unix <= from_unix:
		return 0.0
	var total := 0.0
	var t := from_unix
	while t < to_unix:
		var w := of_slot(slot_of(t))
		var end := mini(int(w.end), to_unix)
		total += (end - t) * float(w.mult)
		t = end
	return total
