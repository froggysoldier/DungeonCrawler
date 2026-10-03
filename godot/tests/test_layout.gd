extends RefCounted
## Neuer Kartenaufbau (Haupt- und Nebengänge, Reviere, Nischen, Toiletten),
## Gegenstände aus der Entfernung, Waffe behalten, Werte vor der Klassenwahl.


func test_hauptgaenge_und_wenige_safe_rooms(t) -> void:
	for seed in [11, 12, 13]:
		var s := TH.make(seed)
		var m: Dictionary = s.map
		var safe: Array = m.rooms.filter(func(r): return r.kind == "safe")
		t.eq(safe.size(), 3, "drei Safe Rooms (%d)" % seed)
		var start = J.find(m.rooms, func(r): return r.kind == "start")
		for r in safe:
			t.ok(r.hood != start.hood, "kein Safe Room im Start-Viertel (%d)" % seed)
		# Hauptgänge: breite Achsen durch die Mitte der Etage
		var cx: int = m.width / 2
		var wide := 0
		for y in m.height:
			if MapGen.is_walkable(m, cx - 1, y) and MapGen.is_walkable(m, cx, y) and m.roomAt[MapGen.idx(m, cx - 1, y)] == -1:
				wide += 1
		t.gt(wide, 20, "senkrechter Hauptgang (%d)" % seed)


func test_reviere_mit_einer_art(t) -> void:
	var s := TH.make(14)
	var m: Dictionary = s.map
	var reviere: Array = m.rooms.filter(func(r): return r.get("revier") != null)
	t.ge(reviere.size(), 6, "mehrere Reviere")
	for r in reviere:
		var inside: Array = s.monsters.filter(func(mo): return MapGen.room_of(m, mo.pos) != null and MapGen.room_of(m, mo.pos).id == r.id)
		t.ok(not inside.is_empty(), "Revier bewohnt")
		t.ok(J.every(inside, func(mo): return mo.defId == r.revier.def), "nur eine Art im Revier")
	var others: Array = m.rooms.filter(func(r): return r.kind == "normal" and r.get("revier") == null and r.get("antechamberOf") == null and r.get("feature") == null)
	var crowded := 0
	for r in others:
		var n: int = s.monsters.filter(func(mo): return MapGen.room_of(m, mo.pos) != null and MapGen.room_of(m, mo.pos).id == r.id).size()
		if n > 1:
			crowded += 1
	t.eq(crowded, 0, "übrige Räume höchstens ein Einzelgänger")


func test_nachschub_nur_im_revier(t) -> void:
	var s := TH.make(15)
	TH.tutorial(s)
	s.player.level = 4
	s.monsters = []
	for i in 40:
		s.lastSpawnTurn = s.turn - 30
		Game._respawn(s)
	t.gt(s.monsters.size(), 0, "Nachschub kommt")
	for mo in s.monsters:
		var r = MapGen.room_of(s.map, mo.pos)
		t.ok(r != null and r.get("revier") != null and mo.defId == r.revier.def, "Nachschub im Revier, gleiche Art")


func test_keine_herumliegenden_gegenstaende(t) -> void:
	var s := TH.make(16)
	for e in s.items:
		var r = MapGen.room_of(s.map, e.pos)
		var ok: bool = r != null and (r.get("antechamberOf") != null or r.get("feature") != null or e.item.kind == "schluessel")
		t.ok(ok, "nur in Vorräumen, Sonderräumen oder als Schlüssel (%s)" % e.item.baseId)


func test_toiletten_ueberall(t) -> void:
	var found := 0
	var used := false
	for seed in [17, 18, 19]:
		var s := TH.make(seed)
		TH.tutorial(s)
		for r in s.map.rooms:
			if r.kind == "safe":
				continue
			for f in J.arr(r, "furniture"):
				if f.kind != "toilette":
					continue
				found += 1
				if not used:
					var spot = MapGen.free_beside(s.map, f.pos)
					if spot != null:
						s.monsters = []
						s.player.pos = spot
						s.player.blase = 50
						t.ok(Game.toilet(s).ok, "Toilette außerhalb eines Safe Rooms benutzbar")
						t.eq(int(s.player.blase), 0, "erleichtert")
						used = true
	t.gt(found, 3, "Toiletten in normalen Räumen und Nischen")
	t.ok(used, "eine Toilette ausprobiert")


func test_wenige_crawler_und_nicht_am_start(t) -> void:
	var s := TH.make(20)
	var start: Dictionary = s.player.pos
	t.le(J.arr(s, "crawlers").size(), 2, "Etage 1: höchstens zwei")
	for c in s.crawlers:
		t.ge(J.cheb(c.pos, start), 25, "nicht gleich am Start")


func test_karte_von_anfang_an(t) -> void:
	var s := TH.make(21)
	t.has(s.unlocks, "minimap")


func test_gegenstand_aus_der_entfernung(t) -> void:
	var s := TH.make(22)
	var it := Items.create_item(s, "stein")
	var p: Dictionary = s.player.pos
	t.eq(Identify.item_at_distance(s, it, J.pos(p.x + 5, p.y)).state, "fern", "zu weit weg")
	t.eq(Identify.item_at_distance(s, it, J.pos(p.x + 1, p.y)).state, "erkannt", "nah: erkannt")
	var rare := Items.generate_equipment(s, "legendaer")
	var near := Identify.item_at_distance(s, rare, J.pos(p.x + 1, p.y))
	t.eq(near.state, "unbekannt", "nah, aber unbekannt")
	t.ok(String(near.text).contains("kennst du nicht"), "sagt, dass man es nicht kennt")


func test_waffe_bleibt(t) -> void:
	var s := TH.make(23)
	var w := Items.create_item(s, "rohrzange")
	s.player.hand = w
	# Ohne Rucksack: Kleinkram nimmt einem nicht die Waffe weg
	s.items.append({"pos": J.pcopy(s.player.pos), "item": Items.create_item(s, "stein")})
	t.ok(not Game.pickup(s).ok, "Stein nicht statt der Waffe")
	t.eq(s.player.hand.uid, w.uid, "Waffe noch in der Hand")
	s.items = []
	TH.tutorial(s)
	t.not_null(s.player.equipment.get("waffe"), "in der Gilde angelegt")
	t.eq(s.player.equipment.waffe.uid, w.uid, "dieselbe Waffe")


func test_werte_vor_der_klassenwahl(t) -> void:
	var s := TH.make(24)
	TH.tutorial(s)
	var before: Dictionary = s.player.stats.duplicate()
	Player.gain_xp(s, Player.xp_to_next(s.player.level) + 1)
	t.eq(int(s.player.statPoints), 0, "keine Punkte zum Verteilen")
	var sum_before := 0
	var sum_after := 0
	for k in before:
		sum_before += int(before[k])
		sum_after += int(s.player.stats[k])
		t.le(int(s.player.stats[k]) - int(before[k]), 1, "gleichmäßig (%s)" % k)
	t.eq(sum_after - sum_before, 3, "drei Punkte verteilt")
	t.ok(not Game.allocate_stat(s, "str").ok, "frei verteilen erst nach der Wahl")
