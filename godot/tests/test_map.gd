extends RefCounted
## Sichtfeld und Wegfindung liefern auf echten Etagen dasselbe wie TypeScript.

func _maps() -> Array:
	return J.load_json("res://tests/fixtures/maps.json")


func test_fov_matches_typescript(t) -> void:
	for f in _maps():
		var m: Dictionary = f
		var vis := Fov.compute(m, f.from, 7).keys()
		vis.sort()
		t.eq(vis, f.fov.map(func(x): return int(x)), "Seed %d: Sichtfeld" % f.seed)


func test_path_matches_typescript(t) -> void:
	for f in _maps():
		var m: Dictionary = f
		var path = Pathfinding.find_path(m, f.from, f.to, Callable(), 20000, true)
		t.eq(path, f.path, "Seed %d: gleicher Weg wie TypeScript" % f.seed)


func test_line_of_sight(t) -> void:
	var m := {"width": 5, "height": 1, "tiles": ["floor", "floor", "wall", "floor", "floor"]}
	t.ok(Fov.has_line_of_sight(m, J.pos(0, 0), J.pos(1, 0)), "freie Sicht")
	t.ok(not Fov.has_line_of_sight(m, J.pos(0, 0), J.pos(4, 0)), "Wand blockiert")
