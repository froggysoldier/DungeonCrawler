extends SceneTree
## Einfacher Testlauf ohne Zusatz-Plugins:
##   godot --headless --path godot -s res://tests/run_tests.gd
## Führt alle res://tests/test_*.gd aus. Jede Methode test_* bekommt einen
## Prüfer `t` mit ok(bedingung, text) und eq(ist, soll, text).
## Beendet mit Code 1, wenn etwas fehlschlägt.

class Checker:
	var failures := PackedStringArray()
	var checks := 0
	var current := ""

	func ok(cond: bool, msg: String = "") -> void:
		checks += 1
		if not cond:
			failures.append("%s: %s" % [current, msg])

	func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
		checks += 1
		if actual != expected:
			failures.append("%s: %s – erwartet %s, bekommen %s" % [current, msg, str(expected), str(actual)])


func _initialize() -> void:
	# Erst nach dem ersten Bild ist der Baum bereit (für Oberflächen-Tests)
	await process_frame
	# Autoloads sind bei -s nicht automatisch geladen: Daten selbst laden
	var data = load("res://scripts/autoload/game_data.gd").new()
	data.name = "GameData"
	data.load_all()
	var t := Checker.new()
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	# Filter: godot ... -s res://tests/run_tests.gd -- replay
	var filter := OS.get_cmdline_user_args()
	if not filter.is_empty():
		files = files.filter(func(f): return f.contains(filter[0]))
	for file in files:
		var inst = load("res://tests/%s" % file).new()
		if inst.has_method("setup"):
			inst.setup(data)
		for m in inst.get_method_list():
			if not String(m.name).begins_with("test_"):
				continue
			t.current = "%s › %s" % [file.get_basename(), m.name]
			var before := t.failures.size()
			# Tests dürfen auf Bilder warten (await)
			await inst.call(m.name, t)
			print(("  ok    " if t.failures.size() == before else "  FEHLER") + "  " + t.current)
	print("\n%d Prüfungen, %d Fehler" % [t.checks, t.failures.size()])
	for f in t.failures:
		printerr("  " + f)
	data.free()
	quit(1 if t.failures.size() else 0)
