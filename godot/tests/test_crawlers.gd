extends RefCounted
## Andere Crawler.


func _tutorial(s: Dictionary) -> void:
	var guild = TH.room(s, "guild")
	s.player.pos = {"x": guild.x + 1, "y": guild.y + 1}
	s.monsters = []
	Game.move_step(s, {"x": guild.x + 2, "y": guild.y + 1})
	s.traps = []


func _open_spot(s: Dictionary) -> Dictionary:
	var r = J.find(s.map.rooms, func(x): return x.kind == "normal" and x.w >= 5)
	return {"x": r.x + 2, "y": r.y + 2}


## Crawler mit gewünschter Persönlichkeit direkt neben den Spieler stellen.
func _neighbor(s: Dictionary, personality: String) -> Dictionary:
	var spot = TH.free_neighbor(s, s.player.pos)
	var c := {
		"uid": "npc%d" % Crawlers.crawlers(s).size(), "name": "Heike Brandt", "background": "Imkerin", "personality": personality,
		"level": 1, "xp": 0, "hp": 20, "maxHp": 24, "dmg": [3, 5], "pos": spot, "alive": true, "met": false, "party": false, "trust": 40, "kills": 0,
	}
	s.crawlers = [c]
	return c


func test_bevoelkerung_sinkt(t) -> void:
	var s := TH.make(3100, {"beruf": 1})
	t.ge(Crawlers.crawlers(s).size(), 4, "Crawler auf der Etage")
	var start: int = Crawlers.population(s).alive
	_tutorial(s)
	for i in 300:
		s.monsters = []
		s.player.hp = 100
		Game.wait(s)
	t.lt(Crawlers.population(s).alive, start, "weniger")
	t.ok(J.some(s.log, func(l): return String(l.text).begins_with("SYSTEMMELDUNG: Es verbleiben")), "Meldung")


func test_freundliche_schliessen_sich_an(t) -> void:
	var joined := false
	for seed in 10:
		if joined:
			break
		var s := TH.make(3200 + seed, {"beruf": 1})
		_tutorial(s)
		s.player.pos = _open_spot(s)
		s.player.stats.cha = 12
		var c := _neighbor(s, "freundlich")
		Game.talk_crawler(s, c.uid)
		Game.invite_crawler(s, c.uid)
		if not c.party:
			continue
		joined = true
		t.eq(Crawlers.party(s).size(), 1, "in der Party")
		TH.teleport(s, TH.stairs(s))
		var before: int = Crawlers.population(s).alive
		t.ok(Game.descend(s, {"ghosts": []}).ok, "hinab")
		t.has(Crawlers.party(s).map(func(x): return x.name), "Heike Brandt")
		t.lt(Crawlers.population(s).alive, before, "Bevölkerung sinkt")
		t.ok(Game.dismiss_crawler(s, c.uid).ok, "entlassen")
		t.eq(Crawlers.party(s).size(), 0, "Party leer")
	t.ok(joined, "jemand ist beigetreten")


func test_eigenbroetler_geben_tipps(t) -> void:
	var s := TH.make(3100, {"beruf": 1})
	_tutorial(s)
	s.player.pos = _open_spot(s)
	var c := _neighbor(s, "eigenbroetler")
	var explored: int = s.map.explored.count(true)
	t.ok(Game.ask_crawler_tip(s, c.uid).ok, "Tipp")
	t.ok(not Game.ask_crawler_tip(s, c.uid).ok, "nur einmal")
	Game.invite_crawler(s, c.uid)
	t.eq(c.party, false, "kommt nicht mit")
	var traps_known := J.some(J.arr(s, "traps"), func(x): return not x.get("hidden", false))
	var re := RegEx.create_from_string("Treppenhaus|Safe Room|Fallen")
	t.ok(J.some(s.log, func(l): return String(l.text).begins_with("Heike Brandt: „") and re.search(l.text) != null), "Tipp im Log")
	t.ok(s.map.explored.count(true) >= explored or traps_known, "Wissen gewonnen")


func test_verzweifelte_werden_freundlich(t) -> void:
	var s := TH.make(3100, {"beruf": 1})
	_tutorial(s)
	s.player.pos = _open_spot(s)
	var c := _neighbor(s, "verzweifelt")
	c.hp = 3
	var potion := Items.create_item(s, "heiltrank")
	s.player.inventory.append(potion)
	t.ok(Game.heal_crawler(s, c.uid, potion.uid).ok, "geheilt")
	t.gt(c.hp, 3, "HP")
	t.eq(c.personality, "freundlich", "freundlich")
	t.ok(not J.some(s.player.inventory, func(i): return i.uid == potion.uid), "Trank verbraucht")


func test_feindselige_werden_gegner(t) -> void:
	var s := TH.make(3100, {"beruf": 1})
	_tutorial(s)
	s.player.pos = _open_spot(s)
	var c := _neighbor(s, "feindselig")
	Game.talk_crawler(s, c.uid)
	t.eq(Crawlers.crawlers(s).size(), 0, "kein Crawler mehr")
	var m = J.find(s.monsters, func(x): return x.defId == "abtruenniger_crawler")
	t.eq(m.name if m != null else null, "Heike Brandt", "als Gegner")


func test_party_kaempft_mit(t) -> void:
	var s := TH.make(3100, {"beruf": 1})
	_tutorial(s)
	s.player.pos = _open_spot(s)
	var c := _neighbor(s, "freundlich")
	c.party = true
	var spot = null
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var q := {"x": c.pos.x + d[0], "y": c.pos.y + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y) and not (q.x == s.player.pos.x and q.y == s.player.pos.y):
			spot = q
			break
	var rat := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, spot, 0)
	rat.hp = 60
	rat.maxHp = 60
	s.monsters = [rat]
	for i in 10:
		Game.wait(s)
	t.ok(rat.hp < 60 or not J.has_same(s.monsters, rat), "Ratte verletzt")


func test_fremde_kills_zaehlen_nicht(t) -> void:
	var s := TH.make(3101, {"beruf": 1})
	_tutorial(s)
	s.player.pos = _open_spot(s)
	var rat := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, TH.free_neighbor(s, s.player.pos), 0)
	s.monsters = [rat]
	var kills: int = s.counters.kills
	var xp: int = s.player.xp
	Combat.kill_monster(s, rat, null, "Heike Brandt", null, false)
	t.ok(not J.has_same(s.monsters, rat), "Ratte tot")
	t.eq(s.counters.kills, kills, "kein Kill für dich")
	t.eq(s.player.xp, xp, "keine Erfahrung für dich")
	var rat2 := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, TH.free_neighbor(s, s.player.pos), 0)
	s.monsters = [rat2]
	Combat.kill_monster(s, rat2, null, "Heike Brandt", null, true)
	t.eq(s.counters.kills, kills + 1, "Party-Kill zählt")


func test_friedliche_lassen_dich_vorbei(t) -> void:
	var s := TH.make(3102, {"beruf": 1})
	_tutorial(s)
	s.player.pos = _open_spot(s)
	s.monsters = []
	var c := _neighbor(s, "eigenbroetler")
	var from: Dictionary = J.pcopy(s.player.pos)
	var to: Dictionary = J.pcopy(c.pos)
	t.ok(Game.move_step(s, to).ok, "vorbeigedrängt")
	t.eq(s.player.pos, to, "du stehst jetzt dort")
	t.eq(c.pos, from, "der Crawler steht auf deinem alten Feld")
	var h := _neighbor(s, "feindselig")
	t.ok(not Game.move_step(s, h.pos).ok, "Feindselige lassen dich nicht durch")
