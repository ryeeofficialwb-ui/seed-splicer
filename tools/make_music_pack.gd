extends SceneTree
## Builds SeedSplicer-music.pck: the songs as plain .ogg files (no Godot import, so smaller) in
## their own resource pack. The game loads it at start (Audio.mount_music_pack); game updates
## never carry the music again.
##   godot --headless --path . --script tools/make_music_pack.gd -- <out.pck>

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var dir := "res://assets/audio/music/"
	var pk := PCKPacker.new()
	if pk.pck_start(out) != OK:
		printerr("can't write ", out)
		quit(1)
		return
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "ogg":
			pk.add_file(dir + f, ProjectSettings.globalize_path(dir + f))
			n += 1
	pk.flush()
	print("music pack: %d songs -> %s" % [n, out])
	quit(0 if n > 0 else 1)
