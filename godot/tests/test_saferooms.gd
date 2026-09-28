extends RefCounted
## Safe Rooms, Bodenfunde und Boss-Kammern (Port von tests/saferooms.test.ts).


func _floors(seed: int) -> Array:
	var out := []
	var s := TH.make(seed, {"beruf": 1})
	out.append(s.duplicate(true))
	while s.floor < 3:
		TH.teleport(s, TH.stairs(s))
		Game.descend(s, {"ghosts": []})
		out.append(s.duplicate(true))
	return out


func _is_lair(r: Dictionary) -> bool:
	return r.kind == "boss" or r.kind == "arena"


func test_automat_und_wirt(t) -> void:
	for seed in [21, 22, 23]:
		for s in _floors(seed):
			for r in s.map.rooms.filter(func(x): return x.kind == "safe"):
				var kinds: Array = J.arr(r, "furniture").map(func(f): return f.kind)
				t.has(kinds, "automat", "%d/%d/%s" % [seed, s.floor, r.name])
				if r.get("safeVariant") == "restaurant":
					t.has(kinds, "wirt", "Wirt")
				for f in J.arr(r, "furniture"):
					t.ok(is_same(MapGen.furniture_at(s.map, f.pos), f), "gefunden")
					var reach := false
					for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
						var p := {"x": f.pos.x + d[0], "y": f.pos.y + d[1]}
						var ro = MapGen.room_of(s.map, p)
						if ro != null and ro.id == r.id and MapGen.furniture_at(s.map, p) == null and MapGen.tile_at(s.map, p.x, p.y) == "floor":
							reach = true
					t.ok(reach, "%s erreichbar" % f.kind)


func test_automat_einmal(t) -> void:
	var s := TH.make(24, {"beruf": 1})
	var room = J.find(s.map.rooms, func(r): return r.kind == "safe" and J.some(J.arr(r, "furniture"), func(f): return f.kind == "automat"))
	var auto = J.find(room.furniture, func(f): return f.kind == "automat")
	s.player.pos = {"x": room.x + room.w / 2, "y": room.y + room.h / 2}
	s.currentRoom = room.id
	t.ok(Game.use_furniture(s, auto).ok, "erster Zug")
	t.eq(s.pendingReveal.items.size(), 1, "ein Gegenstand")
	t.ok(not Game.use_furniture(s, auto).ok, "nur einmal")


func test_nur_material_am_boden(t) -> void:
	var ids := {}
	for b in Db.t("items", "BASE_ITEMS"):
		if b.kind == "schrott" or ["stein", "ziegel", "flasche", "dose", "schraubenmutter"].has(b.id):
			ids[b.id] = true
	for seed in [31, 32, 33]:
		for s in _floors(seed):
			for e in s.items:
				var r = MapGen.room_of(s.map, e.pos)
				if r != null and r.get("antechamberOf") != null:
					continue
				t.ok(ids.has(e.item.get("baseId", "")), "%d/%d: %s" % [seed, s.floor, e.item.get("baseId")])


func test_boss_kammern_mit_vorraum(t) -> void:
	var lairs := 0
	var any := func(_x, _y): return true
	for seed in [41, 42, 43]:
		for s in _floors(seed):
			for lair in s.map.rooms.filter(_is_lair):
				lairs += 1
				t.not_null(J.find(s.map.rooms, func(r): return r.get("antechamberOf") == lair.id), "%d/%d: Vorraum" % [seed, s.floor])
				var c := {"x": lair.x + lair.w / 2, "y": lair.y + lair.h / 2}
				t.is_null(Pathfinding.find_path(s.map, s.player.pos, c, any, 20000, false), "ohne Tür zu")
				t.not_null(Pathfinding.find_path(s.map, s.player.pos, c, any, 20000, true), "mit Tür erreichbar")
	t.gt(lairs, 0, "Kammern vorhanden")


func test_kammer_verriegelt(t) -> void:
	for seed in [51, 52, 53, 54]:
		for s in _floors(seed):
			var lair = J.find(s.map.rooms, func(r): return _is_lair(r) and J.some(s.monsters, func(m): return m.get("homeRoom") == r.id and (m.rank == "nachbarschaftsboss" or m.rank == "boroughboss")))
			if lair == null:
				continue
			var door = null
			var inside = null
			for y in range(lair.y - 1, lair.y + lair.h + 1):
				for x in range(lair.x - 1, lair.x + lair.w + 1):
					if door != null:
						break
					var tl := MapGen.tile_at(s.map, x, y)
					if tl != "door" and tl != "dooropen":
						continue
					for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
						var p := {"x": x + d[0], "y": y + d[1]}
						var ro = MapGen.room_of(s.map, p)
						if ro != null and ro.id == lair.id and MapGen.tile_at(s.map, p.x, p.y) == "floor":
							door = {"x": x, "y": y}
							inside = p
			if door == null:
				continue
			s.monsters = s.monsters.filter(func(m): return m.get("homeRoom") == lair.id)
			s.player.pos = inside
			s.currentRoom = lair.id
			var locked = Game.locked_lair(s)
			t.eq(locked.id if locked != null else null, lair.id, "verriegelt")
			t.ok(not Game.move_step(s, door).ok, "kein Hinaus")
			s.monsters = []
			t.is_null(Game.locked_lair(s), "nach dem Boss offen")
			return
	t.ok(false, "keine Boss-Kammer gefunden")
