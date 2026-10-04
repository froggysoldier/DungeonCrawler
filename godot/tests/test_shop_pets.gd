extends RefCounted
## Laden, Pässe, Haustiere, Rubbellose.


func _make(seed: int = 1600) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1, "haustier": 3})
	TH.tutorial(s)
	return s


func _enter_safe(s: Dictionary) -> Dictionary:
	var safe = TH.room(s, "safe")
	s.player.pos = {"x": safe.x + 1, "y": safe.y + 1}
	s.monsters = []
	Game.move_step(s, {"x": safe.x + 2, "y": safe.y + 1})
	return safe


func _beside(s: Dictionary, id: String) -> Dictionary:
	var p: Dictionary = s.player.pos
	var spot = null
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1]]:
		var q := {"x": p.x + d[0], "y": p.y + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y) and not J.some(s.monsters, func(m): return m.pos.x == q.x and m.pos.y == q.y):
			spot = q
			break
	var m := Monsters.spawn_monster(s, Db.monster(id), 2, spot, 0)
	s.monsters.append(m)
	return m


func test_laden_erst_ab_etage_3(t) -> void:
	var s := _make()
	t.eq(Game.unlock_floor("handel"), 3, "Handel ab Etage 3")
	t.eq(Game.unlock_floor("auftraege"), 3, "Aufträge ab Etage 3")
	var room := _enter_safe(s)
	t.eq(room.get("shop"), null, "Etage 1: kein Laden")
	t.ok(not J.some(J.arr(room, "furniture"), func(f): return f.kind == "haendler"), "kein Händler im Safe Room")
	t.ok(not J.some(s.map.rooms, func(r): return r.get("feature") == "markt"), "kein Wanderhändler")
	t.eq(room.get("questOffered"), null, "kein Auftrag")
	t.ok(not Game.buy_offer(s, 0).ok, "kaufen geht nicht")
	var junk := Items.create_item(s, "bauhelm")
	s.player.inventory.append(junk)
	t.ok(not Game.sell_item(s, junk.uid).ok, "verkaufen geht nicht")
	t.eq(Game.unlock_floor_systems(s, 2), [], "Etage 2: noch nichts")
	t.eq(Game.unlock_floor_systems(s, 3), ["handel", "auftraege"], "Etage 3: Handel und Aufträge")


func test_laden(t) -> void:
	var s := _make()
	s.unlocks.append("handel")
	var room := _enter_safe(s)
	t.gt(room.shop.offers.size(), 5, "Angebote")
	s.player.gold = 1000
	var count: int = room.shop.offers.size()
	t.ok(Game.buy_offer(s, 0).ok, "kaufen")
	t.eq(room.shop.offers.size(), count - 1, "weniger Angebote")
	t.lt(s.player.gold, 1000, "bezahlt")
	t.ok(Game.haggle_offer(s, 0).ok, "feilschen")
	t.ok(not Game.haggle_offer(s, 0).ok, "nur einmal")
	var junk := Items.create_item(s, "bauhelm")
	s.player.inventory.append(junk)
	var gold: int = s.player.gold
	t.ok(Game.sell_item(s, junk.uid).ok, "verkaufen")
	t.gt(s.player.gold, gold, "Erlös")


func test_verkaufen_nur_im_safe_room(t) -> void:
	var s := _make()
	s.unlocks.append("handel")
	var junk := Items.create_item(s, "bauhelm")
	s.player.inventory.append(junk)
	t.ok(not Game.sell_item(s, junk.uid).ok, "draußen nicht")


func test_kobold_tattoo(t) -> void:
	var s := _make()
	var tattoo := Items.create_item(s, "tattoo_kobold")
	s.player.inventory.append(tattoo)
	t.ok(Game.use_item(s, tattoo.uid).ok, "Tattoo")
	var k := _beside(s, "kobold")
	k.aware = true
	k.treffer = 999
	var hp: int = s.player.hp
	for i in 5:
		Ai.monster_turn(s, k)
	t.eq(s.player.hp, hp, "geschützt")
	k.provoked = true
	k.aware = true
	for i in 5:
		if s.player.hp != hp:
			break
		k.pos = _beside(s, "kellerratte").pos
		s.monsters = s.monsters.filter(func(m): return m.defId != "kellerratte")
		Ai.monster_turn(s, k)
	t.lt(s.player.hp, hp, "nach Provokation Angriff")


func test_ei_schluepft(t) -> void:
	var s := _make()
	s.monsters = []
	s.player.inventory.append(Items.create_item(s, "ei_raptor"))
	for i in 170:
		if s.player.get("pet") != null:
			break
		s.monsters = []
		s.player.hp = 100
		Game.wait(s)
	var pet = s.player.get("pet")
	t.eq(pet.species if pet != null else null, "Kellerraptor", "geschlüpft")
	t.gt(s.achievements.size(), 0, "Achievements")


func test_zaehmen_mit_leckerli(t) -> void:
	var tamed := false
	for seed in range(1, 20):
		if tamed:
			break
		var s := _make(1700 + seed)
		var w := _beside(s, "wolpertinger")
		w.hp = 1
		var treat := Items.create_item(s, "leckerli")
		s.player.inventory.append(treat)
		Game.use_item(s, treat.uid)
		var pet = s.player.get("pet")
		tamed = pet != null and pet.species == "Wolpertinger"
	t.ok(tamed, "gezähmt")


func test_superkeks(t) -> void:
	var s := Game.new_game({"name": "Test", "answers": {"beruf": 1, "haustier": 0}, "seed": 1800, "meta": Meta.empty_meta()})
	TH.tutorial(s)
	var keks := Items.create_item(s, "superkeks")
	s.player.inventory.append(keks)
	Game.use_item(s, keks.uid)
	t.eq(s.player.pet.get("caster"), true, "zaubert")
	var pp: Dictionary = s.player.pet.pos
	var spot = null
	for d in [[2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [-1, -1], [1, -1], [-1, 1]]:
		var q := {"x": pp.x + d[0], "y": pp.y + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y) and Fov.has_line_of_sight(s.map, pp, q):
			spot = q
			break
	var target := Monsters.spawn_monster(s, Db.monster("ghul"), 3, spot, 0)
	target.aware = true
	s.monsters = [target]
	var hp: int = target.hp
	for i in 30:
		if target.hp != hp:
			break
		Ai.pet_turn(s)
	t.lt(target.hp, hp, "Zauber trifft")


func test_rubbellose(t) -> void:
	var outcomes := {}
	var s := _make()
	for i in 60:
		var lot := Items.create_item(s, "rubbellos")
		s.player.inventory.append(lot)
		var before: int = s.log.size()
		Game.use_item(s, lot.uid)
		var text := " ".join(s.log.slice(before).map(func(l): return l.text))
		if text.contains("NICHT GEWONNEN"):
			outcomes["niete"] = true
		elif text.contains("Gold"):
			outcomes["gold"] = true
		else:
			outcomes["anders"] = true
		s.monsters = []
	t.ge(outcomes.size(), 3, "verschiedene Ergebnisse")


func test_feilschen_beim_wanderhaendler(t) -> void:
	var s := TH.make(3201, {"beruf": 1})
	TH.ready(s)
	var room = J.find(s.map.rooms, func(r): return r.get("feature") == "markt")
	if room == null:
		room = J.find(s.map.rooms, func(r): return r.kind == "normal")
		room.feature = "markt"
	var shop := Shop.ensure_shop(s, room)
	# Das teuerste Angebot: bei Kleinkram rundet ein Rabatt sonst auf denselben Preis
	var pick := 0
	for i in shop.offers.size():
		if shop.offers[i].price > shop.offers[pick].price:
			pick = i
	var offer: Dictionary = shop.offers[pick]
	var before: int = offer.price
	# Charisma 0: Feilschen misslingt fast sicher, der Preis darf nicht sinken
	s.player.stats.cha = 0
	for i in shop.offers.size():
		shop.offers[i].erase("haggled")
	Shop.haggle(s, room, pick)
	if String(s.log.back().text).contains("beleidigt"):
		t.gt(offer.price, before, "misslungenes Feilschen macht es teurer (%d -> %d)" % [before, offer.price])
	else:
		t.lt(offer.price, before, "gelungenes Feilschen macht es billiger")
	t.eq(int(offer.base), before, "eigener Grundpreis")
