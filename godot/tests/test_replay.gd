extends RefCounted
## Aufgezeichnete Partien nachspielen: Start, jeder Zug (Kurzzustand) und
## Zwischenstände müssen exakt übereinstimmen. Weicht etwas ab, hat sich das
## Spielverhalten geändert. War das Absicht (neue Inhalte, neue Regeln), die
## Aufnahmen mit tools/record_fixtures.gd erneuern.


func _replays() -> Array:
	return J.load_json("res://tests/fixtures/replays.json")


func _new_game(r: Dictionary) -> Dictionary:
	var opts: Dictionary = r.opts.duplicate()
	opts.meta = Meta.empty_meta()
	return Game.new_game(opts)


func test_new_game_matches(t) -> void:
	for r in _replays():
		var t0 := Time.get_ticks_msec()
		var s := _new_game(r)
		print("    Seed %d: neues Spiel in %d ms" % [r.seed, Time.get_ticks_msec() - t0])
		var d := Parity.diff(Parity.snapshot(s), r.start)
		t.ok(d.is_empty(), "Seed %d: Startzustand\n    %s" % [r.seed, "\n    ".join(d)])


func test_replay_matches(t) -> void:
	for r in _replays():
		var s := _new_game(r)
		if not Parity.diff(Parity.snapshot(s), r.start).is_empty():
			continue
		var last_ok := 0
		var failed := false
		for i in r.actions.size():
			var a: Dictionary = r.actions[i]
			if OS.get_environment("REPLAY_TRACE") != "":
				print("    %d %s" % [i + 1, a.a])
			Parity.run_action(s, a.a, a.args)
			var dg := Parity.digest(s)
			var cp = r.checkpoints.get(str(i + 1))
			var mismatch := Parity.diff(dg, r.digests[i])
			if cp != null:
				mismatch.append_array(Parity.diff(Parity.snapshot(s), cp))
			if not mismatch.is_empty():
				t.ok(false, "Seed %d: Abweichung nach Aktion %d (%s %s), zuletzt gleich bei %d\n    %s" % [r.seed, i + 1, a.a, JSON.stringify(a.args), last_ok, "\n    ".join(mismatch)])
				failed = true
				break
			if cp != null:
				last_ok = i + 1
		if not failed:
			t.ok(true, "")
