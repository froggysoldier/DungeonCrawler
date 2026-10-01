extends RefCounted
## Etage 3: Kanäle, Brücken, Siedlung (Kanalstadt).


func _floor3(seed: int) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1})
	TH.tutorial(s)
	TH.to_floor3(s)
	return s


func test_kanaele_und_bruecken(t) -> void:
	for seed in [4801, 4802, 4803]:
		var s := _floor3(seed)
		t.gt(s.map.tiles.count("kanal"), 60, "Kanäle (%d)" % seed)
		t.gt(s.map.tiles.count("bruecke"), 0, "Brücken (%d)" % seed)
		var i: int = s.map.tiles.find("kanal")
		var p := {"x": i % int(s.map.width), "y": i / int(s.map.width)}
		t.ok(not MapGen.is_walkable(s.map, p.x, p.y), "Kanal nicht begehbar")
		t.ok(not MapGen.blocks_sight(s.map, p.x, p.y), "Kanal durchsichtig")
		var b: int = s.map.tiles.find("bruecke")
		t.ok(MapGen.is_walkable(s.map, b % int(s.map.width), b / int(s.map.width)), "Brücke begehbar")
	var s1 := TH.make(4801, {"beruf": 1})
	t.eq(s1.map.tiles.count("kanal"), 0, "Etage 1 ohne Kanäle")


func test_alles_erreichbar(t) -> void:
	for seed in [4811, 4812, 4813, 4814]:
		var s := _floor3(seed)
		var m: Dictionary = s.map
		var ok := func(x: int, y: int) -> bool: return Dungeon.lock_at(s, J.pos(x, y)) == null
		for r in m.rooms:
			if r.get("sealed") or r.kind == "boss" or r.kind == "arena":
				continue
			var c := MapGen.center(r)
			if not MapGen.is_walkable(m, c.x, c.y):
				continue
			t.not_null(Pathfinding.find_path(m, s.player.pos, c, ok, 40000, true), "Raum %d (%d)" % [r.id, seed])
		t.not_null(Pathfinding.find_path(m, s.player.pos, TH.stairs(s), ok, 40000, true), "Treppe (%d)" % seed)


func test_siedlung_auf_jeder_karte(t) -> void:
	for seed in [4821, 4822, 4823, 4824, 4825, 4826]:
		var s := _floor3(seed)
		t.eq(s.map.rooms.filter(func(r): return r.get("siedlung")).size(), 3, "drei Räume (%d)" % seed)
		t.ge(Crawlers.crawlers(s).filter(func(c): return c.get("resident")).size(), 3, "Bewohner (%d)" % seed)


func test_siedlung(t) -> void:
	var s := _floor3(4821)
	var town: Array = s.map.rooms.filter(func(r): return r.get("siedlung"))
	t.eq(town.size(), 3, "drei Räume")
	var types := {}
	for r in town:
		types[r.shopType] = true
		t.ok(J.some(J.arr(r, "furniture"), func(f): return f.kind == "haendler"), "Händler in %s" % r.name)
		t.ok(not J.some(s.monsters, func(m): return MapGen.room_of(s.map, m.pos) != null and MapGen.room_of(s.map, m.pos).id == r.id), "keine Monster in %s" % r.name)
	t.eq(types.size(), 3, "verschiedene Händler")
	var residents: Array = Crawlers.crawlers(s).filter(func(c): return c.get("resident"))
	t.ge(residents.size(), 3, "Bewohner")
	# Bewohner bleiben
	var c: Dictionary = residents[0]
	s.player.pos = TH.free_neighbor(s, c.pos)
	t.ok(not Crawlers.invite(s, c.uid).ok, "Bewohner gehen nicht mit")
	# Monster betreten die Siedlung nicht
	var m := Monsters.spawn_monster(s, Db.monster("kloakenhund"), 7, {"x": 1, "y": 1}, 0)
	t.ok(not Ai._allowed_tile(s, m, MapGen.center(town[0])), "Monster bleiben draußen")
	# Händler mit festem Sortiment
	var shop := Shop.ensure_shop(s, town[0])
	t.eq(shop.type, town[0].shopType, "Sortiment passt zum Raum")


func test_neue_monster(t) -> void:
	var ids := ["schlickkrebs", "stromaal", "riesenegel", "gullyqualle", "lumpensammler", "rohrgolem", "schimmelteppich", "kloakenhund", "schleusenwaerter", "faulgasblase", "treibgut_mimic", "brueckentroll"]
	var s := TH.make(4831, {"beruf": 1})
	for id in ids:
		var def = Db.monster(id)
		t.not_null(def, id)
		t.has(def.floors, 3, "%s auf Etage 3" % id)
		t.ok(PixelArt.has(Sprites.sprite_name(id)), "%s hat ein Bild" % id)
		t.ok(J.some(Db.t("achievements", "ACHIEVEMENTS"), func(a): return a.id == "art_%s_1" % id), "%s im Bestiarium" % id)
		var m := Monsters.spawn_monster(s, def, def.levels[0], {"x": 1, "y": 1}, 0)
		t.gt(m.hp, 0, "%s spawnt" % id)
