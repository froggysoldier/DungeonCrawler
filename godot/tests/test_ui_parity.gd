extends RefCounted
## Vergleichstest der Oberflächen-Hilfen gegen die TypeScript-Version:
## Uhrzeit, nächste Achievement-Ziele, Bodenmaterial je Raum, Zufall je Kachel,
## Bonus- und Crawler-Beschreibungen, nahe Fallen, Sponsoren, Haustier und
## Skill-Texte – an festen Stellen einer aufgezeichneten Partie.


func _record(s: Dictionary, step: int) -> Dictionary:
	var items: Array = s.player.inventory.duplicate()
	for slot in s.player.equipment:
		if s.player.equipment[slot] != null:
			items.append(s.player.equipment[slot])
	return {
		"step": step,
		"time": ViewHelpers.format_time(s.turn),
		"goals": ViewHelpers.next_goals(s),
		"materials": s.map.rooms.map(func(r): return Tiles.room_material(r)),
		"bonuses": items.map(func(it): return Bonuses.describe(it.get("bonuses"))),
		"crawlers": J.arr(s, "crawlers").map(func(c): return Crawlers.describe(c)),
		"talkable": Crawlers.talkable(s).map(func(c): return c.uid),
		"traps": ViewHelpers.disarmable_traps(s).map(func(t): return t.uid),
		"sponsors": Sponsors.states(s).map(func(x): return "%s:%s" % [x.id, x.status]),
		"pet": PetEvo.form_name(s.player.pet) if s.player.get("pet") != null else null,
		"skills": s.player.skills.map(func(k): return [Skills.effect_text(Db.skill(k.id), k.level), Skills.effect_text(Db.skill(k.id), k.level + 1)]),
	}


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
		var d := Parity.diff(_record(s, step), want)
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
	t.eq(bad, 0, "Zufall je Kachel wie im Browser")


func test_format_time_matches(t) -> void:
	var ui: Dictionary = J.load_json("res://tests/fixtures/ui.json")
	var got: Array = [0, 1, 19, 20, 479, 480, 481, 2399, 12345].map(func(x): return ViewHelpers.format_time(x))
	t.eq(got, ui.times, "Uhrzeit")
