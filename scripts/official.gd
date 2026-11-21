class_name Official
extends RefCounted
## The official seed list that ships with every update (res://data/official_list.json, written by
## tools/publish_update.py from the developer's save): every approved seed, its recipe, who made it
## and its block art. When a player's game starts on a new version, every official seed they don't
## have yet is added to their game (the developer's own game never merges: it IS the list).
## Block art: a seed with no art of your own shows the official drawing.

const PATH := "res://data/official_list.json"
## The latest live push (Submissions > Push to players), kept so the game starts with it offline.
const LIVE_CACHE := "user://official_live.json"
## The live version this game has (0 = none yet).
static var live_version := 0

static var _data: Variant = null
static var _art := {}  # lowercase name -> Image (or null)


static func data() -> Dictionary:
	if _data == null:
		_data = {}
		if FileAccess.file_exists(PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("seeds")) == TYPE_ARRAY:
				_data = parsed
	return _data


static func version() -> String:
	return String(data().get("version", ""))


static func seed_count() -> int:
	return data().get("seeds", []).size()


## The official block art for a seed of this name, or null.
static func art_for(seed_name: String) -> Image:
	var key := seed_name.strip_edges().to_lower()
	if _art.has(key):
		return _art[key]
	if _art.is_empty():  # build the name -> art table once
		for s in data().get("seeds", []):
			if typeof(s) == TYPE_DICTIONARY and String(s.get("block_art", "")) != "":
				_art[String(s.get("name", "")).strip_edges().to_lower()] = s.block_art
		_art[""] = null
	var v: Variant = _art.get(key)
	if typeof(v) == TYPE_STRING:
		var img := Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(v)) == OK:
			img.convert(Image.FORMAT_RGBA8)
			v = img
		else:
			v = null
		_art[key] = v
	elif not _art.has(key):
		_art[key] = null
	return _art[key]


## Adds every official seed (and its recipes) the player doesn't have yet. Once per version.
## Returns { seeds_added, recipes_added, version } or {} when there was nothing to do.
static func merge(force := false) -> Dictionary:
	if DevMode.on() and not force:
		return {}
	var v := version()
	if v == "" or (v == Game.official_version and not force):
		return {}
	var preview: Dictionary = Game.preview_from(data())
	if not preview.ok:
		return {}
	var r: Dictionary = Game.apply_import(preview, Game.import_offer_ids(preview))
	Game.official_version = v
	Game.save_game()
	return { "seeds_added": int(r.seeds_added), "recipes_added": int(r.recipes_added), "version": v }


## Starts the game with the last live push if it is newer than this release's own files.
static func load_live_cache() -> void:
	if not FileAccess.file_exists(LIVE_CACHE):
		return
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(LIVE_CACHE))
	if not c is Dictionary or not c.get("payload") is Dictionary:
		return
	var p: Dictionary = c.payload
	if int(p.get("official", {}).get("published", 0)) <= int(data().get("published", 0)):
		return  # the release is newer: it already has everything
	live_version = int(c.get("version", 0))
	use_data(p.official)
	Approvals.use_data(p.approvals)


## A live push arrived: use it, keep it for next time, and (players) add the new seeds now.
## Returns merge()'s report ({} when nothing new came in).
static func apply_live(payload: Dictionary, version: int) -> Dictionary:
	if not payload.get("official") is Dictionary or not payload.get("approvals") is Dictionary:
		return {}
	live_version = version
	use_data(payload.official)
	Approvals.use_data(payload.approvals)
	BlockArt.refresh_all()
	var f := FileAccess.open(LIVE_CACHE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({ "version": version, "payload": payload }))
		f.close()
	var r := merge()
	Game.seeds_changed.emit()
	return r


## Tests: use this list instead of the shipped one.
static func use_data(d: Dictionary) -> void:
	_data = d
	_art.clear()
