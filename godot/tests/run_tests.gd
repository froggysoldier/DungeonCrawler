extends SceneTree
## Einfacher Testlauf ohne Zusatz-Plugins:
##   godot --headless --path godot -s res://tests/run_tests.gd
## Führt alle res://tests/test_*.gd aus. Jede Methode test_* bekommt einen
## Prüfer `t` mit ok(bedingung, text) und eq(ist, soll, text).
## Laufzeitfehler (SCRIPT ERROR, push_error) zählen als Fehlschlag, denn
## GDScript bricht bei ihnen nicht ab, sondern macht weiter.
## Beendet mit Code 1, wenn etwas fehlschlägt.


## Fängt Fehlermeldungen der Engine ab, auch aus anderen Threads.
class ErrorWatch:
	extends Logger
	var _mutex := Mutex.new()
	var _errors := PackedStringArray()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_ERROR and error_type != ERROR_TYPE_SCRIPT:
			return
		var text := rationale if rationale != "" else code
		_mutex.lock()
		_errors.append("Laufzeitfehler: %s (%s:%d, %s)" % [text, file, line, function])
		_mutex.unlock()

	## Gesammelte Fehler abholen und leeren.
	func take() -> PackedStringArray:
		_mutex.lock()
		var out := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return out


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

	func _cmp(cond: bool, msg: String, detail: String) -> void:
		checks += 1
		if not cond:
			failures.append("%s: %s – %s" % [current, msg, detail])

	func has(list: Variant, item: Variant, msg: String = "") -> void:
		_cmp(list != null and list.has(item), msg, "%s fehlt in %s" % [str(item), str(list).left(200)])

	func lacks(list: Variant, item: Variant, msg: String = "") -> void:
		_cmp(list == null or not list.has(item), msg, "%s sollte nicht enthalten sein" % str(item))

	func gt(a: Variant, b: Variant, msg: String = "") -> void:
		_cmp(a != null and a > b, msg, "%s ist nicht größer als %s" % [str(a), str(b)])

	func ge(a: Variant, b: Variant, msg: String = "") -> void:
		_cmp(a != null and a >= b, msg, "%s ist kleiner als %s" % [str(a), str(b)])

	func lt(a: Variant, b: Variant, msg: String = "") -> void:
		_cmp(a != null and a < b, msg, "%s ist nicht kleiner als %s" % [str(a), str(b)])

	func le(a: Variant, b: Variant, msg: String = "") -> void:
		_cmp(a != null and a <= b, msg, "%s ist größer als %s" % [str(a), str(b)])

	func matches(text: Variant, pattern: String, msg: String = "") -> void:
		var re := RegEx.create_from_string(pattern)
		_cmp(text != null and re.search(str(text)) != null, msg, "„%s“ passt nicht zu /%s/" % [str(text), pattern])

	func is_null(v: Variant, msg: String = "") -> void:
		_cmp(v == null, msg, "erwartet null, bekommen %s" % str(v).left(200))

	func not_null(v: Variant, msg: String = "") -> void:
		_cmp(v != null, msg, "Wert fehlt")


func _initialize() -> void:
	# Erst nach dem ersten Bild ist der Baum bereit (für Oberflächen-Tests)
	await process_frame
	# Autoloads sind bei -s nicht automatisch geladen: Daten selbst laden
	var data = load("res://scripts/autoload/game_data.gd").new()
	data.name = "GameData"
	data.load_all()
	var t := Checker.new()
	var watch := ErrorWatch.new()
	OS.add_logger(watch)
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	# Filter: godot ... -s res://tests/run_tests.gd -- replay
	var filter := OS.get_cmdline_user_args()
	if not filter.is_empty():
		files = files.filter(func(f): return f.contains(filter[0]))
	for file in files:
		var scr = load("res://tests/%s" % file)
		if scr == null or not scr.can_instantiate():
			t.checks += 1
			t.failures.append("%s: Skript lässt sich nicht laden" % file)
			print("  FEHLER  %s lässt sich nicht laden" % file)
			continue
		var inst = scr.new()
		if inst.has_method("setup"):
			inst.setup(data)
		for m in inst.get_method_list():
			if not String(m.name).begins_with("test_"):
				continue
			t.current = "%s › %s" % [file.get_basename(), m.name]
			var before := t.failures.size()
			# Tests dürfen auf Bilder warten (await)
			await inst.call(m.name, t)
			for e in watch.take():
				t.checks += 1
				t.failures.append("%s: %s" % [t.current, e])
			print(("  ok    " if t.failures.size() == before else "  FEHLER") + "  " + t.current)
	print("\n%d Prüfungen, %d Fehler" % [t.checks, t.failures.size()])
	for f in t.failures:
		printerr("  " + f)
	OS.remove_logger(watch)
	data.free()
	quit(1 if t.failures.size() else 0)
