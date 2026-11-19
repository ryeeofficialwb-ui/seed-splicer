extends Node
## Autoload "Audio": background music (a shuffled playlist of loops) and sound effects.
##
##   Audio.play(&"splice")   play the sound for that game event (assets/audio/sfx/<event>.ogg)
##
## The volumes and the music choice are saved in UserSettings ("audio" section) and set in the
## Sound menu. The sound effects themselves are fixed: one file per event.
##
## CREDITS
##   Music: "Abstraction" (Ben Burnes / Tallbeard Studios), Music Loop Bundle, public domain (CC0).
##          https://tallbeard.itch.io/music-loop-bundle  https://abstractionmusic.com/
##   Sound effects: Cozy FX by Pizza Doggy ("Game Assets by Pizza Doggy"). Licensed for use inside
##          games only: don't share the .ogg files on their own (see assets/audio/sfx/LICENSE_NOTE.txt).

signal track_changed(title: String)

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC: Array[Dictionary] = [
	{ "title": "Primordial Soup", "file": "primordial_soup.ogg" },
	{ "title": "Coral Reef", "file": "coral_reef.ogg" },
	{ "title": "Evening Oasis", "file": "evening_oasis.ogg" },
	{ "title": "Glide", "file": "glide.ogg" },
	{ "title": "Chillout", "file": "chillout.ogg" },
	{ "title": "Night Drive", "file": "night_drive.ogg" },
]
const ARTIST := "Abstraction"

## Every event that makes a sound; each one plays SFX_DIR + "<event>.ogg".
##   click     any button          open      a window opens         spawn    a seed appears
##   pickup    you grab a seed     drop      you let go of it       splice   a known recipe merges
##   discover  a brand new seed    remove    right-click removes     error    something can't be done
##   success   import / export done
const EVENTS: Array[StringName] = [&"click", &"open", &"spawn", &"pickup", &"drop", &"splice", &"discover", &"remove", &"error", &"success"]
const SHUFFLE := -1
const POOL_SIZE := 8

var music_volume := 0.55
var sfx_volume := 0.8
var track_choice := SHUFFLE  ## SHUFFLE or an index into MUSIC (that one song on repeat)
var current_track := -1

var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next_player := 0
var _cache := {}  # path -> AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	music_volume = clampf(float(UserSettings.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(UserSettings.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	track_choice = clampi(int(UserSettings.get_value("audio", "track", SHUFFLE)), SHUFFLE, MUSIC.size() - 1)
	_apply_volumes()

	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.finished.connect(_on_track_finished)
	add_child(_music)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_start_music.call_deferred()


# --- sound effects -----------------------------------------------------------------------

func play(event: StringName) -> void:
	if sfx_volume <= 0.0:
		return
	var stream := _stream(SFX_DIR + String(event) + ".ogg")
	if stream == null:
		return
	var p := _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	p.stream = stream
	p.pitch_scale = randf_range(0.96, 1.04)  # a little variety when the same sound repeats
	p.play()


## True while any effect is playing (used by the self-test).
func is_sfx_playing() -> bool:
	return _pool.any(func(p): return p.playing)


# --- music --------------------------------------------------------------------------------

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	UserSettings.set_value("audio", "music_volume", music_volume)
	_apply_volumes()
	if music_volume > 0.0 and not _music.playing:
		_start_music()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	UserSettings.set_value("audio", "sfx_volume", sfx_volume)
	_apply_volumes()


## SHUFFLE for the whole playlist, or one song index to keep that song looping.
func set_track_choice(choice: int) -> void:
	track_choice = clampi(choice, SHUFFLE, MUSIC.size() - 1)
	UserSettings.set_value("audio", "track", track_choice)
	_play_track(track_choice if track_choice != SHUFFLE else _random_track())


func next_track() -> void:
	_play_track(_random_track() if track_choice == SHUFFLE else track_choice)


func current_title() -> String:
	return MUSIC[current_track].title if current_track >= 0 else ""


func is_music_playing() -> bool:
	return _music != null and _music.playing


func _start_music() -> void:
	if music_volume <= 0.0:
		return
	_play_track(track_choice if track_choice != SHUFFLE else _random_track())


func _play_track(i: int) -> void:
	var stream := _stream(MUSIC_DIR + MUSIC[i].file)
	if stream == null:
		return
	current_track = i
	_music.stream = stream
	_music.play()
	track_changed.emit(MUSIC[i].title)


func _on_track_finished() -> void:
	# the loops are short songs: one play each, then the next (or the same one again)
	_play_track(_random_track() if track_choice == SHUFFLE else track_choice)


func _random_track() -> int:
	if MUSIC.size() <= 1:
		return 0
	var i := randi() % MUSIC.size()
	while i == current_track:
		i = randi() % MUSIC.size()
	return i


# --- plumbing ------------------------------------------------------------------------------

func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, &"Master")


func _apply_volumes() -> void:
	for pair in [["Music", music_volume], ["SFX", sfx_volume]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			AudioServer.set_bus_mute(i, pair[1] <= 0.0)
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pair[1], 0.0001)))
