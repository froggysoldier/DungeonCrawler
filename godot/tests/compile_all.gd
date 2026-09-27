extends SceneTree
## Lädt alle Skripte, damit Godot Syntax- und Typfehler meldet.

func _initialize() -> void:
	var bad := 0
	for dir in ["res://scripts/core", "res://scripts/engine", "res://scripts/autoload", "res://scenes", "res://scripts/ui"]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".gd"):
				continue
			var scr = load("%s/%s" % [dir, f])
			if scr == null or not scr.can_instantiate():
				printerr("FEHLER: %s/%s" % [dir, f])
				bad += 1
	print("%d Skripte mit Fehlern" % bad)
	quit(1 if bad else 0)
