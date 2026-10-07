extends RefCounted
## Inhalte und Monster-Fähigkeiten.


func _make(seed: int = 500) -> Dictionary:
	return TH.make(seed, [0, 0, 3, 0, 0])


func _beside(s: Dictionary, id: String, level: int = 2) -> Dictionary:
	s.monsters = []
	var p: Dictionary = s.player.pos
	var spot = null
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1]]:
		var q := {"x": p.x + d[0], "y": p.y + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y):
			spot = q
			break
	var m := Monsters.spawn_monster(s, Db.monster(id), level, spot, 0)
	m.aware = true
	s.monsters.append(m)
	return m


func _poisoned(s: Dictionary) -> bool:
	return J.some(s.player.buffs, func(b): return b.name == "Vergiftet")


func test_eindeutige_ids(t) -> void:
	var items: Array = Db.t("items", "BASE_ITEMS") + Db.t("items", "UNIQUE_ITEMS")
	for list in [Db.t("monsters", "MONSTERS"), Db.t("monsters", "HOOD_BOSSES"), Db.t("achievements", "ACHIEVEMENTS"), Db.t("skills", "SKILLS"), items]:
		var ids: Array = list.map(func(x): return x.id)
		t.eq(J.uniq(ids).size(), ids.size(), "eindeutig")


func test_boss_beute_existiert(t) -> void:
	for b in Db.t("monsters", "HOOD_BOSSES"):
		for id in b.loot:
			t.ok(Items.base_exists(id), id)


func test_etagen_haben_monster_und_bosse(t) -> void:
	var monsters: Array = Db.t("monsters", "MONSTERS")
	var bosses: Array = Db.t("monsters", "HOOD_BOSSES")
	for f in [1, 2, 3]:
		t.ge(monsters.filter(func(m): return m.floors.has(f)).size(), 8, "Etage %d: Monster" % f)
		t.eq(bosses.filter(func(b): return b.rank == "boroughboss" and b.floors.has(f)).size(), 1, "Etage %d: Borough-Boss" % f)
		t.ge(bosses.filter(func(b): return b.rank == "nachbarschaftsboss" and b.floors.has(f)).size(), 4, "Etage %d: Nachbarschaftsbosse" % f)


func test_umfang(t) -> void:
	t.ge(Db.t("monsters", "MONSTERS").size(), 40, "Monster")
	t.ge(Db.t("items", "BASE_ITEMS").size() + Db.t("items", "UNIQUE_ITEMS").size(), 150, "Gegenstände")
	t.ge(Db.t("achievements", "ACHIEVEMENTS").size(), 120, "Achievements")


func test_gift_und_gegengift(t) -> void:
	var s := _make()
	var spider := _beside(s, "kellerspinne")
	spider.treffer = 999
	for i in 20:
		if _poisoned(s):
			break
		s.player.hp = 100
		Ai.monster_turn(s, spider)
	t.ok(_poisoned(s), "vergiftet")
	t.has(s.achievements, "vergiftet")
	s.monsters = []
	var hp: int = s.player.hp
	Game.end_turn(s)
	t.lt(s.player.hp, hp + 1, "Giftschaden")
	s.unlocks.append("inventar")
	var anti := Items.create_item(s, "gegengift")
	s.player.inventory.append(anti)
	Game.use_item(s, anti.uid)
	t.ok(not _poisoned(s), "geheilt")


func test_blaehkroete_explodiert(t) -> void:
	var s := _make(501)
	var toad := _beside(s, "blaehkroete")
	toad.hp = 1
	toad.ausweichen = -500
	var hp: int = s.player.hp
	Game.attack(s, toad.uid, {"part": "faust", "move": "normal"})
	t.ok(not J.has_same(s.monsters, toad), "besiegt")
	t.lt(s.player.hp, hp, "Explosion trifft")
	t.ok(J.some(s.log, func(l): return String(l.text).contains("explodiert")), "im Log")


func test_diebe(t) -> void:
	var s := _make(502)
	s.player.gold = 50
	var thief := _beside(s, "elster_goblin")
	thief.treffer = 999
	for i in 30:
		if J.num(thief, "stolenGold") > 0:
			break
		s.player.hp = 100
		if TH.cheb(thief.pos, s.player.pos) > 1:
			break
		Ai.monster_turn(s, thief)
	t.gt(J.num(thief, "stolenGold"), 0.0, "Gold geklaut")
	t.lt(s.player.gold, 50, "weniger Gold")
	t.eq(thief.get("fleeing"), true, "flieht")


func test_rufer_holen_verstaerkung(t) -> void:
	var s := _make(503)
	var shaman := _beside(s, "rattenschamane", 3)
	for i in 80:
		if s.monsters.size() != 1:
			break
		s.player.hp = 100
		Ai.monster_turn(s, shaman)
	t.gt(s.monsters.size(), 1, "Verstärkung")


func test_fliegende_nicht_stampfen(t) -> void:
	var s := _make(504)
	s.player.techniques.append("stampfen")
	var bat := _beside(s, "fledermaus")
	t.matches(Combat.technique_blocker(s, bat, {"part": "tritt", "move": "stampfen"}), "fliegt")
