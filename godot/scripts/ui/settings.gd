class_name Settings
extends RefCounted
## Einstellungen, die sich das Spiel merkt (Zoom, Ton, Tippgeräusch).

const PATH := "user://settings.cfg"
static var _cfg: ConfigFile


static func _load() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


static func get_value(key: String, fallback: Variant) -> Variant:
	return _load().get_value("spiel", key, fallback)


static func set_value(key: String, value: Variant) -> void:
	_load().set_value("spiel", key, value)
	_cfg.save(PATH)
