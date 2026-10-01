extends RefCounted
## Etage 2: Parkdecks, Autowracks, Öl, eigene Bosse und Monster (Tiefgarage).


func _floor2(seed: int) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1})
	TH.tutorial(s)
	TH.teleport(s, TH.stairs(s))
	Game.descend(s, {"ghosts": []})
	return s


func test_parkdecks_wracks_oel(t) -> void:
	for seed in [5201, 5202, 5203]:
		var s := _floor2(seed)
		t.eq(s.floor, 2, "Etage 2")
		t.eq(Db.floor_def(2).name, "Die Tiefgaragen", "Name")
		t.ge(s.map.rooms.filter(func(r): return r.get("parkdeck")).size(), 1, "Parkdecks (%d)" % seed)
		t.gt(s.map.tiles.count("wrack"), 0, "Wracks (%d)" % seed)
		t.gt(s.map.tiles.count("oel"), 0, "Öl (%d)" % seed)
		var i: int = s.map.tiles.find("oel")
		t.ok(MapGen.is_walkable(s.map, i % int(s.map.width), i / int(s.map.width)), "Öl begehbar")
		var wi: int = s.map.tiles.find("wrack")
		t.ok(not MapGen.is_walkable(s.map, wi % int(s.map.width), wi / int(s.map.width)), "Wrack versperrt")
	var s1 := TH.make(5201, {"beruf": 1})
	t.eq(s1.map.tiles.count("wrack"), 0, "Etage 1 ohne Wracks")


func test_alles_erreichbar(t) -> void:
	for seed in [5211, 5212, 5213, 5214]:
		var s := _floor2(seed)
		var m: Dictionary = s.map
		var ok := func(x: int, y: int) -> bool: return Dungeon.lock_at(s, J.pos(x, y)) == null
		for r in m.rooms:
			if r.get("sealed") or r.kind == "boss" or r.kind == "arena":
				continue
			var c := MapGen.center(r)
			if MapGen.is_walkable(m, c.x, c.y):
				t.not_null(Pathfinding.find_path(m, s.player.pos, c, ok, 40000, true), "Raum %d (%d)" % [r.id, seed])
		t.not_null(Pathfinding.find_path(m, s.player.pos, TH.stairs(s), ok, 40000, true), "Treppe (%d)" % seed)


func test_wrack_durchsuchen(t) -> void:
	var s := TH.make(5221, {"beruf": 1})
	var r := TH.ready(s)
	var at := J.pos(r.x + 2, r.y + 1)
	s.map.tiles[MapGen.idx(s.map, at.x, at.y)] = "wrack"
	var turn: int = s.turn
	t.ok(Game.move_step(s, at).ok, "hineinlaufen")
	t.eq(MapGen.tile_at(s.map, at.x, at.y), "wrack_leer", "ausgeräumt")
	t.eq(s.player.pos, J.pos(r.x + 1, r.y + 1), "bleibt stehen")
	t.eq(s.turn, turn + 1, "ein Zug")
	t.eq(int(s.counters.wrecksSearched), 1, "gezählt")
	t.ok(not Game.search_wreck(s, at).ok, "nur einmal")


func test_alarmanlage(t) -> void:
	var s := TH.make(5222, {"beruf": 1})
	var r := TH.ready(s)
	var at := J.pos(r.x + 2, r.y + 1)
	var alarms := 0
	for k in 60:
		s.map.tiles[MapGen.idx(s.map, at.x, at.y)] = "wrack"
		var m := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, J.pos(r.x + 3, r.y + 2), 0)
		m.asleep = true
		m.aware = false
		s.monsters = [m]
		Tiefgarage.search(s, at)
		if m.aware:
			alarms += 1
			t.ok(not m.asleep, "geweckt")
	t.gt(alarms, 3, "Alarm kommt vor")
	t.lt(alarms, 30, "aber nicht ständig")


func test_oel_rutschen_und_brennen(t) -> void:
	var s := TH.make(5223, {"beruf": 1})
	var r := TH.ready(s)
	var a := J.pos(r.x + 1, r.y + 1)
	var b := J.pos(r.x + 2, r.y + 1)
	var slips := 0
	for k in 40:
		s.player.pos = J.pcopy(a)
		s.player.erase("mud")
		s.map.tiles[MapGen.idx(s.map, b.x, b.y)] = "oel"
		Game.move_step(s, b)
		if s.player.get("mud"):
			slips += 1
	t.gt(slips, 3, "man rutscht aus")
	t.lt(slips, 30, "nicht immer")
	# Brennend ins Öl: Flammen
	s.player.pos = J.pcopy(a)
	s.player.erase("mud")
	s.map.tiles[MapGen.idx(s.map, b.x, b.y)] = "oel"
	Conditions.inflict_player(s, "brennen", 2, 1, "Test")
	Game.move_step(s, b)
	t.eq(MapGen.tile_at(s.map, b.x, b.y), "floor", "Öl verbrannt")
	t.ok(Conditions.player_has(s, "brennen"), "brennt weiter")


func test_eigene_bosse_und_monster(t) -> void:
	var own: Array = Db.t("monsters", "HOOD_BOSSES").filter(func(b): return b.floors[0] == 2 and b.rank == "nachbarschaftsboss")
	t.eq(own.size(), 4, "vier eigene Nachbarschaftsbosse")
	for b in own:
		t.ok(PixelArt.has("boss/" + b.id), "%s hat eine Figur" % b.id)
		t.ge(J.arr(b, "specials").size(), 2, "%s: Spezialangriffe" % b.id)
		for l in b.loot:
			t.ok(Items.base_exists(l), "%s: Beute %s" % [b.id, l])
	var s := _floor2(5231)
	var bosses: Array = s.monsters.filter(func(m): return m.rank == "nachbarschaftsboss")
	t.ok(J.every(bosses, func(m): return own.map(func(b): return b.id).has(m.defId)), "Etage 2 nutzt ihre eigenen Bosse")
	for id in ["rostkaefer", "oelschleim", "abgasgeist", "parkautomat", "garagenkatze", "reifenstapel_mimic"]:
		var def = Db.monster(id)
		t.not_null(def, id)
		t.eq(def.floors, [2], "%s nur auf Etage 2" % id)
		t.ok(PixelArt.has(Sprites.sprite_name(id)), "%s hat ein Bild" % id)
		t.ok(J.some(Db.t("achievements", "ACHIEVEMENTS"), func(a): return a.id == "art_%s_1" % id), "%s im Bestiarium" % id)
