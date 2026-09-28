extends RefCounted
## Aufträge (Port von tests/quests.test.ts).


func _setup() -> Dictionary:
	var s := TH.make(6100, {"beruf": 1})
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
