class_name UserSettings
extends RefCounted
## Small settings file (display mode, resolution, where the splices window sits...).
## Separate from your game save so resetting progress never touches your display settings.

const PATH := "user://seed_splicer_settings.cfg"

static var _cfg: ConfigFile


static func _c() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)  # fine if it doesn't exist yet
	return _cfg


static func get_value(section: String, key: String, default: Variant = null) -> Variant:
	var c := _c()
	return c.get_value(section, key) if c.has_section_key(section, key) else default


static func set_value(section: String, key: String, value: Variant) -> void:
	_c().set_value(section, key, value)
	_c().save(PATH)
