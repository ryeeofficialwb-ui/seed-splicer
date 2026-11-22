class_name SpriteFolder
extends Node
## Keeps an up-to-date copy of the sprite sheet in a folder you can see:
##   - playing from the Godot editor: the project's own sprites/ folder (E:\seed-splicer\sprites)
##   - the exported game: a sprites folder next to SeedSplicer.exe
## (if that folder can't be written, the game's save folder is used instead).
##
## It holds seed_splicer_sprites.png (the same 32x32 sheet Export Sprite Sheet makes),
## seed_splicer_sprites.json (which seed is on which row) and block_art/<seed id>.png (each seed's
## block art strip). It is rewritten a moment after anything changes. It is only a copy to look at:
## to change block art, draw on the sheet and use Import Sprite Sheet.

const SHEET_FILE := "seed_splicer_sprites.png"
const INFO_FILE := "seed_splicer_sprites.json"
const DELAY := 1.5  ## seconds to wait after the last change before writing

static var _dir := ""
var _timer: Timer
var _pending := false


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = DELAY
	_timer.timeout.connect(write_now)
	add_child(_timer)
	Game.seeds_changed.connect(queue_write)
	Game.recipes_changed.connect(queue_write)
	queue_write()


## The folder the copy goes in (made on the first write).
static func folder() -> String:
	if _dir == "":
		_dir = _preferred()
	return _dir


static func _preferred() -> String:
	if OS.has_feature("editor"):
		if not OS.get_cmdline_user_args().is_empty():
			# dev_shot test runs reset the game: mirror into the (scratch) user folder, never the project's sprites/
			return ProjectSettings.globalize_path("user://sprites_test")
		return ProjectSettings.globalize_path("res://sprites")
	return OS.get_executable_path().get_base_dir().path_join("sprites")


func queue_write() -> void:
	_pending = true
	_timer.start()


## Writes the copy now if a change is waiting (call before quitting).
func flush() -> void:
	if _pending:
		write_now()


func write_now() -> Error:
	_pending = false
	var err := _write(folder())
	if err != OK and _dir != ProjectSettings.globalize_path("user://sprites"):
		_dir = ProjectSettings.globalize_path("user://sprites")  # e.g. the game sits in a read-only folder
		err = _write(_dir)
	return err


func _write(dir: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(dir.path_join("block_art"))
	if err != OK:
		return err
	if dir == ProjectSettings.globalize_path("res://sprites"):
		_touch(dir.path_join(".gdignore"), "")  # keeps Godot from importing these PNGs as game assets
	_touch(dir.path_join("README.txt"), "This folder is a copy that Seed Splicer writes by itself (it is redone whenever your seeds change).\n\n"
		+ SHEET_FILE + "  every seed's art on a 32x32 grid, one row per seed:\n"
		+ "    4 block-art boxes (block + 3 animation frames), then seed, sprout, sapling, crop (fully grown, with its block fruits)\n"
		+ INFO_FILE + "  which seed is on which row\n"
		+ "block_art/  each seed's block art strip (4 boxes of 32x32)\n\n"
		+ "Editing these files changes nothing in the game. To change block art: draw on the sprite sheet,\n"
		+ "then use Import Sprite Sheet in the Seeds panel.\n")
	var sheet: Dictionary = Game.build_sprite_sheet()
	err = (sheet.image as Image).save_png(dir.path_join(SHEET_FILE))
	if err != OK:
		return err
	var f := FileAccess.open(dir.path_join(INFO_FILE), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(sheet.info, "\t"))
	f.close()
	# block art: one strip per seed that has some (old strips of removed seeds are cleared out)
	var art_dir := dir.path_join("block_art")
	var d := DirAccess.open(art_dir)
	if d != null:
		for file in d.get_files():
			if file.get_extension() == "png":
				d.remove(file)
	for id in Game.order:
		var art := BlockArt.get_art(id)
		if art != null:
			art.save_png(art_dir.path_join(String(id).validate_filename() + ".png"))
	return OK


static func _touch(path: String, text: String) -> void:
	if FileAccess.file_exists(path):
		var old := FileAccess.get_file_as_string(path)
		if old == text:
			return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
