extends RefCounted
## Bosskämpfe: Phasen und angekündigte Spezialangriffe (BossFight).


func _boss(s: Dictionary, id: String = "der_hausmeister", dist: int = 2) -> Dictionary:
	var r := TH.ready(s, 7)
	s.player.pos = {"x": r.x + 1, "y": r.y + 1}
	var def = BossFight.boss_def(id)
	var m := Monsters.spawn_boss(s, def, {"x": r.x + 1 + dist, "y": r.y + 1}, 0, r.id, 1)
	m.aware = true
	m.specialCd = 0
	s.monsters = [m]
	s.player.hp = 999
	return m


func test_daten_vollstaendig(t) -> void:
	var specials: Dictionary = Db.t("monsters", "BOSS_SPECIALS")
	for id in specials:
		var sp: Dictionary = specials[id]
		t.ok(["kreis", "ring", "flaeche", "hagel", "linie"].has(sp.form), "%s: Form" % id)
		for k in ["name", "warn", "hit", "miss", "mult"]:
			t.ok(sp.has(k), "%s: %s" % [id, k])
	for b in Db.t("monsters", "HOOD_BOSSES"):
		t.ge(J.arr(b, "specials").size(), 2, "%s: Spezialangriffe" % b.id)
		for sid in b.specials:
			t.ok(specials.has(sid), "%s: %s bekannt" % [b.id, sid])
		t.eq(J.arr(b, "phaseLines").size(), 2, "%s: Phasensätze" % b.id)


func test_ankuendigen_und_treffen(t) -> void:
	var s := TH.make(501, {"beruf": 1})
	var m := _boss(s)
	Ai.monster_turn(s, m)
	t.not_null(m.get("telegraph"), "angekündigt")
	t.gt(BossFight.danger_tiles(s).size(), 0, "Gefahrenfelder")
	# Auf ein markiertes Feld stellen
	var q: Dictionary = m.telegraph.tiles[0]
	if m.telegraph.id != "ansturm":
		s.player.pos = J.pcopy(q)
	var hp: int = s.player.hp
	var id: String = m.telegraph.id
	Ai.monster_turn(s, m)
	t.is_null(m.get("telegraph"), "ausgelöst")
	t.lt(s.player.hp, hp, "%s trifft" % id)


func test_ausweichen(t) -> void:
	var s := TH.make(502, {"beruf": 1})
	var m := _boss(s)
	Ai.monster_turn(s, m)
	t.not_null(m.get("telegraph"), "angekündigt")
	# Einen Platz ohne Markierung suchen
	var free = null
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var p := J.pos(m.pos.x + dx, m.pos.y + dy)
			if MapGen.is_walkable(s.map, p.x, p.y) and not BossFight.on_tile(m, p) and not Ai.occupied(s, p) and J.cheb(p, m.pos) > 1:
				free = p
	t.not_null(free, "freier Platz")
	s.player.pos = free
	var hp: int = s.player.hp
	Ai.monster_turn(s, m)
	t.eq(s.player.hp, hp, "kein Schaden")
	t.eq(int(s.counters.bossDodges), 1, "gezählt")


func test_abklingzeit(t) -> void:
	var s := TH.make(503, {"beruf": 1})
	var m := _boss(s, "der_hausmeister", 3)
	Ai.monster_turn(s, m)
	t.not_null(m.get("telegraph"), "angekündigt")
	s.player.pos = J.pos(0, 0)
	Ai.monster_turn(s, m)
	t.eq(int(m.specialCd), BossFight.COOLDOWN[0], "Pause")


func test_ansturm_bewegt_den_boss(t) -> void:
	var s := TH.make(504, {"beruf": 1})
	var m := _boss(s, "der_hausmeister", 4)
	var start := J.pcopy(m.pos)
	m.telegraph = {"id": "ansturm", "tiles": BossFight.target_tiles(s, m, BossFight.special_def("ansturm"))}
	t.gt(m.telegraph.tiles.size(), 1, "Bahn")
	Ai.monster_turn(s, m)
	t.lt(J.cheb(m.pos, s.player.pos), J.cheb(start, s.player.pos), "näher heran")
	t.lt(s.player.hp, 999, "gerammt")


func test_formen(t) -> void:
	var s := TH.make(505, {"beruf": 1})
	var m := _boss(s, "der_hausmeister", 2)
	var kreis := BossFight.target_tiles(s, m, {"form": "kreis", "radius": 1})
	t.ok(J.every(kreis, func(q): return J.cheb(q, m.pos) == 1), "Kreis um den Boss")
	var ring := BossFight.target_tiles(s, m, {"form": "ring", "radius": 2})
	t.ok(J.every(ring, func(q): return J.cheb(q, m.pos) == 2), "Ring")
	var flaeche := BossFight.target_tiles(s, m, {"form": "flaeche", "radius": 1})
	t.ok(J.some(flaeche, func(q): return q.x == s.player.pos.x and q.y == s.player.pos.y), "Fläche trifft den Crawler")
	var hagel := BossFight.target_tiles(s, m, {"form": "hagel", "count": 4})
	t.ok(J.some(hagel, func(q): return q.x == s.player.pos.x and q.y == s.player.pos.y), "Hagel zielt auf den Crawler")


func test_phasen(t) -> void:
	var s := TH.make(506, {"beruf": 1})
	var m := _boss(s, "koenig_kanalratte", 4)
	m.specialCd = 99
	t.eq(BossFight.phase(m), 0, "Anfang")
	m.hp = J.rnd(m.maxHp * 0.6)
	var before: int = s.monsters.size()
	Ai.monster_turn(s, m)
	t.eq(BossFight.phase(m), 1, "Phase 2")
	t.gt(s.monsters.size(), before, "Rufer holt Verstärkung")
	t.ok(J.some(s.log, func(l): return String(l.text).contains("pfeift")), "Phasensatz im Log")
	m.hp = J.rnd(m.maxHp * 0.2)
	Ai.monster_turn(s, m)
	t.eq(BossFight.phase(m), 2, "Phase 3")


func test_normale_monster_unberuehrt(t) -> void:
	var s := TH.make(507, {"beruf": 1})
	var m := TH.foe(s, "kellerratte", 1)
	t.ok(not BossFight.turn(s, m), "kein Boss")
	t.is_null(m.get("telegraph"), "keine Ankündigung")


## Bosse sind deutlich stärker als ihre Grundwerte; der Bezirksboss hat
## einen eigenen Faktor (boroughScale) und ist erst gegen Ende der Etage
## zu schaffen.
func test_boss_staerke_je_etage(t) -> void:
	var s := TH.make(6301, {"beruf": 1})
	for fl in [1, 2, 3]:
		var fd := Db.floor_def0(fl)
		t.ok(fd.has("bossScale") and fd.has("boroughScale"), "Etage %d: beide Faktoren" % fl)
		for def in Db.t("monsters", "HOOD_BOSSES"):
			if int(def.floors.min()) != fl:
				continue
			var m := Monsters.spawn_boss(s, def, {"x": 1, "y": 1}, 0, 0, fl)
			var scale: Dictionary = fd.boroughScale if def.rank == "boroughboss" else fd.bossScale
			t.eq(m.maxHp, J.rnd(def.hp * float(scale.hp)), "%s: Leben mit Etagenfaktor" % def.id)
			t.ge(m.maxHp, def.hp * 3, "%s: mindestens dreifache Grundwerte" % def.id)
