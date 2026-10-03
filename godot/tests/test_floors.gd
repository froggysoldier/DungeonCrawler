extends RefCounted
## Etagen 2 und 3.


func _to_floor(s: Dictionary, floor: int) -> void:
	while s.floor < floor:
		TH.teleport(s, TH.stairs(s))
		Game.descend(s, {"ghosts": []})


func test_publikum_auf_etage_2(t) -> void:
	var s := TH.make(700)
	_to_floor(s, 2)
	t.has(s.unlocks, "zuschauer")
	t.ok(J.some(s.pendingDialogs, func(d): return J.some(d.pages, func(p): return String(p).contains("PUBLIKUM"))), "Dialog")
	var m := Monsters.spawn_monster(s, Db.monster("kellerratte"), 2, s.player.pos, 0)
	var before: int = s.viewers.follower
	Events.emit(s, {"type": "kill", "monster": m, "technique": {"part": "tritt", "move": "stampfen"}})
	t.gt(s.viewers.follower, before, "Follower")
	t.gt(s.viewers.hype, 0, "Hype")


func test_fan_boxen(t) -> void:
	var s := TH.make(701)
	_to_floor(s, 2)
	var boxes: int = s.player.boxes.size()
	s.viewers.follower = 99
	var m := Monsters.spawn_monster(s, Db.monster("kellerratte"), 2, s.player.pos, 0)
	Events.emit(s, {"type": "kill", "monster": m, "technique": {"part": "faust", "move": "normal"}})
	t.gt(s.player.boxes.size(), boxes, "neue Box")
	t.ok(J.some(s.player.boxes, func(b): return b.box.type == "fan"), "Fan-Box")


func test_wahl_vor_dem_weitergehen(t) -> void:
	var s := TH.make(702)
	_to_floor(s, 3)
	t.eq(s.pendingSelection, true, "Wahl offen")
	var next = TH.free_neighbor(s, s.player.pos)
	t.ok(not Game.move_step(s, next).ok, "blockiert")


func test_empfehlung_nach_kampfstil(t) -> void:
	var s := TH.make(703)
	s.player.techniqueUses = {"tritt+normal": 80, "faust+normal": 5}
	var opts := Classes.class_options(s)
	t.eq(opts[0].klass.id, "kickboxer", "Kickboxer")
	t.eq(opts.filter(func(o): return o.get("recommended", false)).size(), 3, "drei Empfehlungen")
	s.player.techniqueUses = {"wurf+normal": 60}
	s.counters.throws = 60
	t.eq(Classes.class_options(s)[0].klass.id, "steinschleuderer", "Steinschleuderer")


func test_besondere_rassen_gesperrt(t) -> void:
	var s := TH.make(704)
	t.eq(J.find(Classes.race_options(s), func(r): return r.race.id == "troll").available, false, "gesperrt")
	s.counters.knockdowns = 20
	t.eq(J.find(Classes.race_options(s), func(r): return r.race.id == "troll").available, true, "frei")


func test_wahl_wendet_boni_an(t) -> void:
	var s := TH.make(705)
	_to_floor(s, 3)
	var opt: Dictionary = Classes.class_options(s)[0]
	var str: int = s.player.stats.str
	t.ok(Classes.choose(s, "halbork", opt.klass.id).ok, "Wahl")
	t.eq(s.pendingSelection, false, "erledigt")
	t.eq(s.player.race, "halbork", "Rasse")
	t.has(s.achievements, "klasse")
	t.eq(s.player.stats.str, str, "Basiswerte bleiben")


func test_jede_faehigkeit_einsetzbar(t) -> void:
	for c in Db.t("classes", "CLASSES"):
		var s := TH.make(706)
		_to_floor(s, 3)
		s.pendingSelection = false
		s.player.klass = c.id
		s.player.abilityCooldown = 0
		s.monsters = s.monsters.filter(func(m): return absi(m.pos.x - s.player.pos.x) > 3 or absi(m.pos.y - s.player.pos.y) > 3)
		var m := Monsters.spawn_monster(s, Db.monster("fischmensch"), 7, TH.free_neighbor(s, s.player.pos), 0)
		s.monsters.append(m)
		var res := Classes.use_ability(s, {"part": "tritt", "move": "normal"})
		t.ok(res.ok, "%s: %s" % [c.id, J.nn(res, "message", "")])
		t.gt(s.player.abilityCooldown, 0, "%s: Abklingzeit" % c.id)
		t.ok(not Classes.use_ability(s, {"part": "tritt", "move": "normal"}).ok, "%s: nicht sofort wieder" % c.id)


func test_alte_spielstaende(t) -> void:
	var s := TH.make(707)
	s.erase("viewers")
	s.erase("pendingSelection")
	var m := Meta.migrate(s)
	t.eq(m.viewers.follower, 0, "Follower ergänzt")
	t.eq(m.pendingSelection, false, "Wahl ergänzt")


func test_etagenfaktor_fuer_monster(t) -> void:
	var s := TH.make(4401, {"beruf": 1})
	var def = Db.monster("kellerratte")
	s.floor = 1
	var a := Monsters.spawn_monster(s, def, 2, {"x": 1, "y": 1}, 0)
	s.floor = 2
	var b := Monsters.spawn_monster(s, def, 2, {"x": 1, "y": 1}, 0)
	t.gt(b.maxHp, a.maxHp * 3, "Etage 2: deutlich mehr HP")
	t.gt(b.dmg[1], a.dmg[1] * 2, "Etage 2: deutlich mehr Schaden")
	t.gt(b.xp, a.xp, "Etage 2: mehr Erfahrung")


func test_seltenheit_waechst_mit_der_etage(t) -> void:
	var s := TH.make(4402, {"beruf": 1})
	s.floor = 1
	t.eq(Items.cap_rarity(s, "legendaer"), "selten", "Etage 1: höchstens selten")
	t.eq(Items.cap_rarity(s, "legendaer", true), "episch", "Boss-Box eine Stufe mehr")
	t.eq(Items.cap_rarity(s, "gewoehnlich"), "gewoehnlich", "darunter unverändert")
	# Eine Box von Etage 1 bleibt begrenzt, auch wenn man sie erst auf Etage 3 öffnet
	var box := Items.create_box(s, "abenteurer", "himmlisch")
	t.eq(int(box.box.floor), 1, "Box merkt sich die Etage")
	s.floor = 3
	var order: Array = Db.t("items", "RARITY_ORDER")
	for i in 20:
		for it in Items.roll_box_contents(s, "abenteurer", "himmlisch", int(box.box.floor)):
			if it.get("slot") != null:
				t.le(order.find(it.rarity), order.find("selten"), "Inhalt höchstens selten (%s)" % it.rarity)


func test_nachschub_waechst_mit_der_zeit(t) -> void:
	var s := TH.make(4403, {"beruf": 1})
	s.player.level = 5
	var dur: int = Db.floor_def0(1).duration
	var early := 0
	var late := 0
	for i in 200:
		s.turn = s.floorStartTurn + 10
		early = maxi(early, Monsters.respawn_level(s))
		s.turn = s.floorStartTurn + int(dur * 0.95)
		var lv := Monsters.respawn_level(s)
		late = maxi(late, lv)
		t.le(lv, s.player.level + 1, "nie mehr als eine Stufe über dem Crawler")
	t.gt(late, early, "kurz vor dem Einsturz stärkerer Nachschub")
