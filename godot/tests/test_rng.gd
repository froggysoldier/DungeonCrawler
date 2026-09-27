extends RefCounted
## Der Zufall muss bitgenau zur TypeScript-Version passen.

func _fixtures() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rng.json"))


func test_rng_matches_typescript(t) -> void:
	for f in _fixtures():
		var r := Rng.new(int(f.seed))
		# Als 32-Bit-Ganzzahl vergleichen: JSON-Kommazahlen verlieren sonst Stellen
		for v in f.words:
			t.eq(int(r.next() * 4294967296.0), int(v), "Seed %d: next()" % f.seed)
		for v in f.ints:
			t.eq(r.range_int(-5, 17), int(v), "Seed %d: range_int()" % f.seed)
		var arr := range(10)
		r.shuffle(arr)
		t.eq(arr, f.shuffled.map(func(x): return int(x)), "Seed %d: shuffle()" % f.seed)
		for v in f.weighted:
			t.eq(r.weighted([["a", 1], ["b", 3], ["c", 6]]), v, "Seed %d: weighted()" % f.seed)
		t.eq(r.state, int(f.state), "Seed %d: Endzustand" % f.seed)
