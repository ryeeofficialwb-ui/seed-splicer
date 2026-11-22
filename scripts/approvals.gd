class_name Approvals
extends RefCounted
## The official seed list that ships with every update (res://data/approvals.json).
## tools/publish_update.py writes it from the developer's own save when an update is published:
##   approved  every seed the developer has (not sent to the graveyard), with who made it.
##             A seed of YOURS with the same name gets the approval stamp + that contributor's name.
##   denied    seeds the developer sent to the graveyard: the Dictionary's Graveyard tab shows them.
## A seed you send to the graveyard yourself (Dictionary > "Send to graveyard") is marked
## `denied` in your save: it loses its stamp and moves to the Graveyard tab too.
## THE DEVELOPER'S OWN GAME doesn't wait for a publish: every seed in it that isn't in the graveyard
## and whose stamp wasn't revoked (Dictionary > Revoke stamp, `unstamped`) has the stamp right away,
## signed with whoever made it (the player who submitted it, else you). That's exactly what the next
## Push to players / update gives everyone.
## Graveyard seeds can still be spliced, but make only GRAVE_RATE Mycoras every 3 s (bank.gd).

const PATH := "res://data/approvals.json"
const FORMAT := "seed-splicer-approvals"
const STAMP_SMALL := preload("res://assets/stamp/approval_stamp_24.png")
const STAMP_BIG := preload("res://assets/stamp/approval_stamp_64.png")
const STAMP_COLOR := Color("#ffb347")

static var _loaded := false
static var _test_data := false  ## use_data() was called: tests use their own list, even in the editor
static var _approved := {}   # lowercase name -> contributor
static var _info := {}       # lowercase name -> { art: bool (approved with its art), rsr: 0 or 6..10 }
static var _denied: Array = []  # seed dictionaries (enough to draw them)
static var version := ""
static var publisher := ""


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_approved.clear()
	_info.clear()
	_denied.clear()
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("format", "") != FORMAT:
		return
	version = String(parsed.get("version", ""))
	publisher = String(parsed.get("publisher", ""))
	for a in parsed.get("approved", []):
		if typeof(a) == TYPE_DICTIONARY and String(a.get("name", "")).strip_edges() != "":
			_add(a)
	for d in parsed.get("denied", []):
		if typeof(d) == TYPE_DICTIONARY and String(d.get("name", "")).strip_edges() != "":
			_denied.append(d)


## Loads `data` instead of the shipped file (tests).
static func use_data(data: Dictionary) -> void:
	_loaded = true
	_test_data = true
	_approved.clear()
	_info.clear()
	_denied.clear()
	version = String(data.get("version", ""))
	publisher = String(data.get("publisher", ""))
	for a in data.get("approved", []):
		_add(a)
	for d in data.get("denied", []):
		_denied.append(d)


static func _add(a: Dictionary) -> void:
	var key := String(a.name).strip_edges().to_lower()
	var by := String(a.get("made_by", "")).strip_edges()
	_approved[key] = by if by != "" else publisher
	var rsr := int(a.get("rsr", 0)) if a.get("rsr") != null else 0
	_info[key] = { "art": bool(a.get("art", false)), "rsr": rsr if rsr >= 6 and rsr <= 10 else 0 }


## The developer's game reads stamps straight from its own save (see the top of this file).
static func _live() -> bool:
	return DevMode.on() and not _test_data


## An approved seed's boosts: { art, rsr } ({} if it isn't approved). See bank.gd.
## art = approved with its BLOCK art (the seed's own picture doesn't count).
static func info(seed: Dictionary) -> Dictionary:
	if approved_by(seed) == "":
		return {}
	if _live():
		var id := String(seed.get("id", ""))
		var rsr := int(seed.get("rsr", 0))
		return { "art": Game.art_approved(id), "rsr": rsr if rsr >= 6 and rsr <= 10 else 0 }
	return _info.get(String(seed.get("name", "")).strip_edges().to_lower(), { "art": false, "rsr": 0 })


## In the graveyard: sent there by you, or on the official denied list. It can still be spliced
## but makes only Bank.GRAVE_RATE Mycoras.
static func is_graveyard(seed: Dictionary) -> bool:
	if seed.is_empty():
		return false
	if seed.get("denied", false):
		return true
	_ensure()
	var key := String(seed.get("name", "")).strip_edges().to_lower()
	return not _approved.has(key) and _denied.any(func(d): return String(d.get("name", "")).strip_edges().to_lower() == key)


## The graveyard as published (the official denied list, without your own marks).
static func official_denied() -> Array:
	_ensure()
	return _denied.duplicate(true)


static func reload() -> void:
	_loaded = false
	_ensure()


## Who made this seed, if it is approved (has the stamp); "" if it isn't.
static func approved_by(seed: Dictionary) -> String:
	_ensure()
	if seed.is_empty() or seed.get("denied", false):
		return ""
	if _live():
		if seed.get("unstamped", false) or not Game.seeds.has(String(seed.get("id", ""))):
			return ""
		var made := String(seed.get("made_by", "")).strip_edges()
		return made if made != "" else (Game.player_name() if Game.player_name() != "" else "you")
	var key := String(seed.get("name", "")).strip_edges().to_lower()
	if not _approved.has(key):
		return ""
	var by: String = _approved[key]
	return by if by != "" else "?"


static func is_approved(seed: Dictionary) -> bool:
	return approved_by(seed) != ""


static func official_count() -> int:
	_ensure()
	if _live():
		return Game.order.filter(func(id): return approved_by(Game.seeds[id]) != "").size()
	return _approved.size()


## Every seed in the graveyard: the official denied list plus the ones you sent there yourself.
## [{ seed: Dictionary (drawable), local_id: String ("" if you don't have it), official: bool }]
static func graveyard() -> Array:
	_ensure()
	var out: Array = []
	var names := {}
	for id in Game.order:
		var s: Dictionary = Game.seeds[id]
		if s.get("denied", false) and not Game.is_removed_from_graveyard(String(s.name)):
			names[String(s.name).to_lower()] = out.size()
			out.append({ "seed": s, "local_id": id, "official": false })
	for d in _denied + Game.graveyard_extra:
		var key := String(d.name).strip_edges().to_lower()
		if Game.is_removed_from_graveyard(key):
			continue
		if names.has(key):
			out[names[key]].official = true
			continue
		var s: Dictionary = d.duplicate(true)
		s.id = "grave:" + key
		s.rarity = maxi(1, int(s.get("rarity", 1)))
		s.pattern = int(s.get("pattern", 0))
		s.pattern_seed = int(s.get("pattern_seed", 0))
		if typeof(s.get("colors")) != TYPE_ARRAY or s.colors.size() < 2:
			s.colors = ["#777777", "#444444"]
		s.sprout = String(s.get("sprout", "#7ccf4e"))
		s.crop = CropArt.valid_type(s.get("crop"), key)
		names[key] = out.size()
		out.append({ "seed": s, "local_id": Game.find_by_name(String(d.name)), "official": not d.has("submission_id") })
	return out
