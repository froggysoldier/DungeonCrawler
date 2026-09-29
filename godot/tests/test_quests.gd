extends RefCounted
## Aufträge.


func _setup(seed: int = 6100) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1})
	TH.tutorial(s)
	s.traps = []
	var room = J.find(s.map.rooms, func(r): return r.kind == "normal" and r.w >= 5)
	s.player.pos = {"x": room.x + 2, "y": room.y + 2}
	var pos = null
	for d in [[1, 0], [-1, 0], [0, 1]]:
		var q := {"x": s.player.pos.x + d[0], "y": s.player.pos.y + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y):
			pos = q
			break
	s.crawlers = [{"uid": "giver", "name": "Ole Pietsch", "background": "Imker", "personality": "freundlich", "level": 1, "xp": 0, "hp": 30, "maxHp": 30, "dmg": [2, 4], "pos": pos, "alive": true, "met": true, "party": false, "trust": 40, "kills": 0}]
	return s


func _offer_of(s: Dictionary, kind: String) -> Dictionary:
	for i in 60:
		var q = Quests.offer_quest(s, {"kind": "crawler", "ref": "giver", "name": "Ole Pietsch"})
		if q != null and q.kind == kind:
			return q
		s.quests = []
	push_error("kein Angebot " + kind)
	return {}


func test_jagd(t) -> void:
	var s := _setup()
	var q := _offer_of(s, "jagd")
	t.ok(Game.accept_quest_offer(s, q.id).ok, "angenommen")
	var gold: int = s.player.gold
	var tag := String(q.facet).substr(2)
	var def = J.find(Db.t("monsters", "MONSTERS"), func(m): return J.arr(m, "tags").has(tag) and m.floors.has(1))
	for i in q.count:
		var m := Monsters.spawn_monster(s, Db.monster(def.id), 1, {"x": 1, "y": 1}, 0)
		Events.emit(s, {"type": "kill", "monster": m, "technique": null})
	t.eq(q.status, "erledigt", "erledigt")
	t.gt(s.player.gold, gold, "Belohnung")


func test_liefern(t) -> void:
	var s := _setup()
	var q := _offer_of(s, "liefern")
	Game.accept_quest_offer(s, q.id)
	s.player.inventory = []
	t.ok(not Game.turn_in_quest(s, q.id).ok, "ohne Ware nicht")
	s.player.inventory.append(Items.create_item(s, q.itemIds[0], q.count))
	t.ok(Game.turn_in_quest(s, q.id).ok, "abgegeben")
	t.eq(q.status, "erledigt", "erledigt")
	t.has(s.achievements, "auftrag_erster")


func test_finden(t) -> void:
	var s := _setup()
	var q := _offer_of(s, "finden")
	Game.accept_quest_offer(s, q.id)
	var entry = J.find(s.items, func(e): return e.item.get("questId") == q.id)
	t.not_null(entry, "Andenken liegt irgendwo")
	s.items = J.without(s.items, entry)
	s.player.inventory.append(entry.item)
	t.ok(Game.turn_in_quest(s, q.id).ok, "abgegeben")
	t.ok(not J.some(s.player.inventory, func(i): return i.get("questId") != null), "nicht mehr im Rucksack")


func test_retten(t) -> void:
	var s := _setup()
	var q := _offer_of(s, "retten")
	Game.accept_quest_offer(s, q.id)
	var target = J.find(Crawlers.crawlers(s), func(c): return c.uid == q.targetUid)
	t.eq(target.personality, "verzweifelt", "verzweifelt")
	var spot = null
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var p := {"x": target.pos.x + d[0], "y": target.pos.y + d[1]}
		if MapGen.is_walkable(s.map, p.x, p.y) and not J.some(s.monsters, func(m): return m.pos.x == p.x and m.pos.y == p.y):
			spot = p
			break
	s.player.pos = spot
	s.monsters = []
	Game.wait(s)
	t.eq(q.status, "erledigt", "gerettet")
	t.eq(target.personality, "freundlich", "freundlich")


func test_scheitern_beim_abstieg(t) -> void:
	var s := _setup()
	var q := _offer_of(s, "finden")
	Game.accept_quest_offer(s, q.id)
	TH.teleport(s, TH.stairs(s))
	Game.descend(s, {"ghosts": []})
	var found = J.find(Quests.quests(s), func(x): return x.id == q.id)
	t.eq(found.status if found != null else null, "gescheitert", "gescheitert")


func test_nest_auftrag(t) -> void:
	var s := _setup()
	var q := _offer_of(s, "nest")
	t.ok(Game.accept_quest_offer(s, q.id).ok, "angenommen")
	# Das Tutorial hat die Karte geleert: ein Bewohner fürs Nest
	var room: Dictionary = s.map.rooms[q.roomId]
	var m := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, MapGen.center(room), room.hood)
	m.nest = room.id
	s.monsters.append(m)
	Combat.kill_monster(s, m, null)
	t.eq(q.status, "erledigt", "Nest leer, Auftrag erledigt")


func test_schatz_auftrag(t) -> void:
	var s := _setup(1)
	var q := _offer_of(s, "schatz")
	t.ok(Game.accept_quest_offer(s, q.id).ok, "angenommen")
	var room: Dictionary = s.map.rooms[q.roomId]
	room.visited = true
	Dungeon.on_enter_room(s, room, true)
	t.eq(q.status, "erledigt", "Kammer betreten, Auftrag erledigt")


func test_auftragskette(t) -> void:
	var s := _setup()
	var giver := {"kind": "crawler", "ref": "giver", "name": "Ole Pietsch"}
	var q = Quests._make(s, giver, "jagd", {"id": "onkel_bert", "name": "Rache für Onkel Bert", "step": 0, "total": 3})
	t.not_null(q, "erster Teil")
	t.ok(String(q.title).begins_with("Rache für Onkel Bert (1/3)"), "Titel mit Teil")
	t.ok(Game.accept_quest_offer(s, q.id).ok, "angenommen")
	var gold1: int = q.reward.gold
	Quests._complete(s, q)
	var next = Quests.quest_of(s, "giver")
	t.not_null(next, "Folgeauftrag angeboten")
	t.eq(next.chain.step, 1, "Teil 2")
	t.eq(next.status, "angebot", "als Angebot")
	t.ge(next.reward.xp, q.reward.xp, "mehr Belohnung")
	Game.accept_quest_offer(s, next.id)
	Quests._complete(s, next)
	var last = Quests.quest_of(s, "giver")
	t.not_null(last, "letzter Teil")
	t.ok(last.reward.box, "letzter Teil mit Box")
	Game.accept_quest_offer(s, last.id)
	var items: int = s.player.inventory.size()
	Quests._complete(s, last)
	t.has(s.chainsDone, "onkel_bert")
	t.gt(s.player.inventory.size(), items, "Abschlussgeschenk")
	t.is_null(Quests.quest_of(s, "giver"), "keine weiteren Teile")
	t.gt(gold1, 0, "Belohnung")


func test_texte_vollstaendig(t) -> void:
	for seed in range(6200, 6215):
		var s := TH.make(seed, {"beruf": 1})
		TH.tutorial(s)
		for i in 12:
			var q = Quests.offer_quest(s, {"kind": "crawler" if i % 3 else "laden", "ref": "x%d" % i, "name": "Test"})
			if q == null:
				continue
			t.ok(not String(q.text).contains("{"), "Platzhalter ersetzt: %s" % q.text)
			t.ok(not String(q.title).contains("{"), "Titel: %s" % q.title)
			t.ok(Quests.hint(s, q) != "", "Hinweis für %s" % q.kind)
	for c in Db.t("quests", "QUEST_CHAINS"):
		for st in c.steps:
			t.ok(["jagd", "finden", "liefern", "retten", "boss", "nest", "schatz"].has(st.kind), "%s: Art" % c.id)
			if st.has("want"):
				for id in st.want.ids:
					t.ok(Items.base_exists(id), "%s: %s" % [c.id, id])
	for w in Db.t("quests", "DELIVER_WANTS"):
		for id in w.ids:
			t.ok(Items.base_exists(id), "Lieferung: %s" % id)
