extends SceneTree
## Nimmt die Vergleichswerte für die Tests neu auf: Karten (`maps.json`),
## Replays (`replays.json`) und Anzeige-Helfer (`ui.json`).
##
## Nur ausführen, wenn sich Inhalte in `data/` oder Spielregeln absichtlich
## geändert haben und `test_replay` deshalb abweicht. Danach die Änderungen
## an den Fixtures prüfen und mit einchecken.
##   godot --headless --path godot -s res://tools/record_fixtures.gd [-- zielordner]

const FIX := "res://tests/fixtures"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else ProjectSettings.globalize_path(FIX)
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_msec()
	_write(out.path_join("maps.json"), ReplayBot.maps())
	var reps := ReplayBot.replays()
	_write(out.path_join("replays.json"), reps)
	var r5: Dictionary = reps.filter(func(r): return r.seed == 5)[0]
	_write(out.path_join("ui.json"), ReplayBot.ui_checks(r5, 250))
	var summary := PackedStringArray()
	for r in reps:
		summary.append("Seed %d: %d Aktionen" % [r.seed, r.actions.size()])
	print("Replays: %s" % ", ".join(summary))
	print("Gespeichert in %s (%d s)" % [out, (Time.get_ticks_msec() - t0) / 1000])
	quit()


func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false, true) + "\n")
	f.close()
