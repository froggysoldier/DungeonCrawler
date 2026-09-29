extends RefCounted
## Türen.


func _doors_of(s: Dictionary, kind: String) -> Array:
	var out := []
	for r in s.map.rooms.filter(func(x): return x.kind == kind):
		for y in range(r.y - 1, r.y + r.h + 1):
			for x in range(r.x - 1, r.x + r.w + 1):
				if MapGen.tile_at(s.map, x, y) == "door":
					out.append({"x": x, "y": y})
	return out


func test_gilden_und_safe_rooms_haben_tueren(t) -> void:
	for seed in [11, 12, 13, 14, 15, 16]:
		var s := TH.make(seed, {"beruf": 1})
		for r in s.map.rooms.filter(func(x): return x.kind == "guild" or x.kind == "safe"):
			var c := {"x": r.x + r.w / 2, "y": r.y + r.h / 2}
			var any := func(_x, _y): return true
			t.is_null(Pathfinding.find_path(s.map, s.player.pos, c, any, 20000, false), "ohne Türen zu (%d)" % seed)
			t.not_null(Pathfinding.find_path(s.map, s.player.pos, c, any, 20000, true), "durch Türen erreichbar (%d)" % seed)
		t.ge(_doors_of(s, "safe").size(), 1, "Safe-Room-Tür")
		t.ge(_doors_of(s, "guild").size(), 1, "Gildentür")


func test_tuer_oeffnen_und_schliessen(t) -> void:
	var s := TH.make(21, {"beruf": 1})
	var door: Dictionary = _doors_of(s, "guild")[0]
	var front = null
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var q := {"x": door.x + d[0], "y": door.y + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y) and s.map.roomAt[MapGen.idx(s.map, q.x, q.y)] == -1:
			front = q
			break
	s.player.pos = front.duplicate()
	s.monsters = []
	var turn: int = s.turn
	t.ok(Game.move_step(s, door).ok, "öffnen")
	t.eq(s.player.pos, front, "bleibt stehen")
	t.eq(MapGen.tile_at(s.map, door.x, door.y), "dooropen", "offen")
	t.eq(s.turn, turn + 1, "ein Zug")
	t.ok(Game.move_step(s, door).ok, "hindurch")
	t.eq(s.player.pos, door, "in der Tür")
	Game.move_step(s, front)
	s.monsters = []
	t.ok(Game.close_door(s, door).ok, "schließen")
	t.eq(MapGen.tile_at(s.map, door.x, door.y), "door", "zu")
