extends RefCounted
## Anzeige-Helfer an festen Stellen einer aufgezeichneten Partie: Uhrzeit,
## nächste Achievement-Ziele, Bodenmaterial je Raum, Zufall je Kachel,
## Bonus- und Crawler-Beschreibungen, nahe Fallen, Sponsoren, Haustier und
## Skill-Texte. Aufnahme mit tools/record_fixtures.gd.


func test_ui_helpers_match(t) -> void:
	var ui: Dictionary = J.load_json("res://tests/fixtures/ui.json")
	var replays: Array = J.load_json("res://tests/fixtures/replays.json")
	var r: Dictionary = replays.filter(func(x): return x.seed == ui.seed)[0]
	var opts: Dictionary = r.opts.duplicate()
	opts.meta = Meta.empty_meta()
	var s := Game.new_game(opts)
	var checks: Array = ui.checks
	var ci := {"n": 0}
	var compare := func(step: int) -> void:
		var want: Dictionary = checks[ci.n]
		t.eq(want.step, step, "Prüfpunkt")
		var d := Parity.diff(ReplayBot.ui_record(s, step), want)
		t.ok(d.is_empty(), "Schritt %d:\n    %s" % [step, "\n    ".join(d.slice(0, 12))])
		ci.n += 1
	compare.call(0)
	for i in r.actions.size():
		var a: Dictionary = r.actions[i]
		Parity.run_action(s, a.a, a.args)
		if (i + 1) % int(ui.every) == 0 or i == r.actions.size() - 1:
			compare.call(i + 1)
	t.eq(ci.n, checks.size(), "Anzahl Prüfpunkte")


func test_tile_hash_matches(t) -> void:
	var ui: Dictionary = J.load_json("res://tests/fixtures/ui.json")
	var got: Array = []
	for y in range(-3, 60, 7):
		for x in range(-2, 90, 11):
			for salt in [0, 3, 5, 6, 41, 50, 99]:
				got.append(Tiles.hash(x, y, salt))
	t.eq(got.size(), ui.hashes.size(), "Anzahl")
	var bad := 0
	for i in got.size():
		if absf(float(got[i]) - float(ui.hashes[i])) > 1e-12:
			bad += 1
	t.eq(bad, 0, "Zufall je Kachel wie aufgezeichnet")


func test_format_time_matches(t) -> void:
	var ui: Dictionary = J.load_json("res://tests/fixtures/ui.json")
	var got: Array = [0, 1, 19, 20, 479, 480, 481, 2399, 12345].map(func(x): return ViewHelpers.format_time(x))
	t.eq(got, ui.times, "Uhrzeit")
