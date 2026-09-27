extends RefCounted
## Sichtfeld und Wegfindung liefern auf echten Etagen dasselbe wie TypeScript.

func _maps() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/maps.json"))


func test_fov_matches_typescript(t) -> void:
	for f in _maps():
		var m := FloorMap.from_dict(f)
		var vis := Fov.compute(m, Vector2i(int(f.from.x), int(f.from.y)), 7).keys()
		vis.sort()
		t.eq(vis, f.fov.map(func(x): return int(x)), "Seed %d: Sichtfeld" % f.seed)


func test_path_matches_typescript(t) -> void:
	for f in _maps():
		var m := FloorMap.from_dict(f)
		var path := Pathfinding.find_path(m, Vector2i(int(f.from.x), int(f.from.y)), Vector2i(int(f.to.x), int(f.to.y)), Callable(), 20000, true)
		var expected: Array = f.path if f.path != null else []
		t.eq(path.size(), expected.size(), "Seed %d: Weglänge" % f.seed)
		var same := path.size() == expected.size()
		for k in mini(path.size(), expected.size()):
			if path[k] != Vector2i(int(expected[k].x), int(expected[k].y)):
				same = false
		t.ok(same, "Seed %d: gleicher Weg wie TypeScript" % f.seed)


func test_line_of_sight(t) -> void:
	var m := FloorMap.new(5, 1, PackedStringArray(["floor", "floor", "wall", "floor", "floor"]))
	t.ok(Fov.has_line_of_sight(m, Vector2i(0, 0), Vector2i(1, 0)), "freie Sicht")
	t.ok(not Fov.has_line_of_sight(m, Vector2i(0, 0), Vector2i(4, 0)), "Wand blockiert")
