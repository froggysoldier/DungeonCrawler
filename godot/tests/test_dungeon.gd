extends RefCounted
## Gelände und besondere Räume (Dungeon).


func _room_of_feature(s: Dictionary, feature: String) -> Variant:
	return J.find(s.map.rooms, func(r): return r.get("feature") == feature)


## Freies Nachbarfeld, auf das man sich stellen kann (Boden, nicht im Raum r).
func _floor_beside(s: Dictionary, at: Dictionary, outside_of: Variant = null) -> Variant:
	for d in MapGen.DIRS4:
		var q := J.pos(at.x + d[0], at.y + d[1])
		if MapGen.tile_at(s.map, q.x, q.y) != "floor":
			continue
		if outside_of != null and MapGen.room_of(s.map, q) != null and MapGen.room_of(s.map, q).id == outside_of.id:
			continue
		return q
	return null


func test_besondere_raeume_entstehen(t) -> void:
	var seen := {}
	for seed in range(1, 11):
		var s := TH.make(seed, {"beruf": 1})
		for r in s.map.rooms:
			if r.get("feature") != null:
				seen[r.feature] = int(seen.get(r.feature, 0)) + 1
		var tiles := {}
		for tile in s.map.tiles:
			tiles[tile] = true
		t.ok(tiles.has("wasser") or tiles.has("schlamm"), "Gelände (%d)" % seed)
		# Jede Schatzkammer hat einen Schlüssel auf der Etage
		var treasure = _room_of_feature(s, "schatz")
		if treasure != null:
			t.ok(J.some(s.items, func(e): return e.item.kind == "schluessel" and int(e.item.opens) == treasure.id), "Schlüssel liegt (%d)" % seed)
			t.ok(s.map.locks.values().has(treasure.id), "Tür verschlossen (%d)" % seed)
			t.ok(treasure.get("sealed", false), "ummauert (%d)" % seed)
	for f in ["schatz", "geheim", "nest", "schrein", "markt", "hinterhalt"]:
		t.ge(int(seen.get(f, 0)), 3, "%s kommt vor" % f)


func test_alles_bleibt_erreichbar(t) -> void:
	for seed in range(1, 9):
		var s := TH.make(seed, {"beruf": 1})
		var m: Dictionary = s.map
		# Durch alle normalen Türen, aber nicht durch Schlösser oder Geheimwände
		var passable := func(x: int, y: int) -> bool: return Dungeon.lock_at(s, J.pos(x, y)) == null
		for r in m.rooms:
			if r.get("sealed") or r.kind == "boss" or r.kind == "arena":
				continue
			var c := MapGen.center(r)
			if not MapGen.is_walkable(m, c.x, c.y):
				continue
			t.not_null(Pathfinding.find_path(m, s.player.pos, c, passable, 40000, true), "Raum %d erreichbar (%d)" % [r.id, seed])
		t.not_null(Pathfinding.find_path(m, s.player.pos, TH.stairs(s), passable, 40000, true), "Treppe erreichbar (%d)" % seed)


func test_kiste_zerschlagen(t) -> void:
	var s := TH.make(31, {"beruf": 1})
	var r := TH.ready(s)
	var at := J.pos(r.x + 2, r.y + 1)
	s.map.tiles[MapGen.idx(s.map, at.x, at.y)] = "kiste"
	var turn: int = s.turn
	t.ok(Game.move_step(s, at).ok, "hineinlaufen")
	t.eq(MapGen.tile_at(s.map, at.x, at.y), "floor", "zerschlagen")
	t.eq(s.player.pos, J.pos(r.x + 1, r.y + 1), "bleibt stehen")
	t.eq(s.turn, turn + 1, "ein Zug")
	t.eq(int(s.counters.cratesSmashed), 1, "gezählt")
	t.ok(not Game.smash(s, at).ok, "nichts mehr da")


func test_kisten_inhalt_verteilt(t) -> void:
	var s := TH.make(32, {"beruf": 1})
	var r := TH.ready(s)
	var at := J.pos(r.x + 2, r.y + 1)
	var loot := 0
	var mimics := 0
	for k in 200:
		s.map.tiles[MapGen.idx(s.map, at.x, at.y)] = "fass"
		s.items = []
		s.monsters = []
		Dungeon.smash(s, at)
		loot += 1 if not s.items.is_empty() else 0
		mimics += 1 if not s.monsters.is_empty() else 0
	t.gt(loot, 80, "oft etwas drin")
	t.lt(loot, 160, "nicht immer")
	t.lt(mimics, 25, "Mimic selten")


func test_schlamm_kostet_einen_zug(t) -> void:
	var s := TH.make(33, {"beruf": 1})
	var r := TH.ready(s)
	var mud := J.pos(r.x + 2, r.y + 1)
	s.map.tiles[MapGen.idx(s.map, mud.x, mud.y)] = "schlamm"
	t.ok(Game.move_step(s, mud).ok, "hinein")
	t.eq(s.player.pos, mud, "steht im Schlamm")
	var turn: int = s.turn
	var next := J.pos(r.x + 3, r.y + 1)
	t.ok(Game.move_step(s, next).ok, "Versuch")
	t.eq(s.player.pos, mud, "steckt fest")
	t.eq(s.turn, turn + 1, "Zug verbraucht")
	t.ok(Game.move_step(s, next).ok, "heraus")
	t.eq(s.player.pos, next, "frei")


func test_schlamm_haelt_monster_auf(t) -> void:
	var s := TH.make(34, {"beruf": 1})
	var m := TH.foe(s, "kellerratte", 1)
	s.map.tiles[MapGen.idx(s.map, m.pos.x, m.pos.y)] = "schlamm"
	Dungeon.on_monster_step(s, m)
	t.ok(m.get("mudStuck", false), "festgesteckt")
	var hp: int = s.player.hp
	Ai.monster_turn(s, m)
	t.ok(not m.has("mudStuck"), "nur ein Zug")
	t.eq(s.player.hp, hp, "greift in dem Zug nicht an")


func test_wasser_loescht_brand(t) -> void:
	var s := TH.make(35, {"beruf": 1})
	var r := TH.ready(s)
	var water := J.pos(r.x + 2, r.y + 1)
	s.map.tiles[MapGen.idx(s.map, water.x, water.y)] = "wasser"
	Conditions.inflict_player(s, "brennen", 5, 2, "Test")
	t.ok(Conditions.player_has(s, "brennen"), "brennt")
	Game.move_step(s, water)
	t.eq(s.player.pos, water, "im Wasser")
	t.ok(not Conditions.player_has(s, "brennen"), "gelöscht")


func _treasure_door(s: Dictionary) -> Variant:
	for k in s.map.locks.keys():
		var parts: PackedStringArray = String(k).split(",")
		var at := J.pos(int(parts[0]), int(parts[1]))
		var room: Dictionary = s.map.rooms[s.map.locks[k]]
		var front = _floor_beside(s, at, room)
		if front != null:
			return {"door": at, "front": front, "room": room}
	return null


func test_verschlossene_tuer_und_schluessel(t) -> void:
	var s := TH.make(1, {"beruf": 1})
	TH.ready(s)
	var info = _treasure_door(s)
	t.not_null(info, "Schatzkammer mit Tür")
	s.player.pos = info.front.duplicate()
	s.monsters = []
	var res := Game.move_step(s, info.door)
	t.ok(not res.ok, "ohne Schlüssel zu")
	t.eq(MapGen.tile_at(s.map, info.door.x, info.door.y), "door", "bleibt zu")
	var key := Items.create_item(s, "schluessel")
	key.opens = info.room.id
	s.player.inventory.append(key)
	t.ok(Dungeon.has_key_for(s, info.door), "Schlüssel passt")
	t.ok(Game.move_step(s, info.door).ok, "aufschließen")
	t.eq(MapGen.tile_at(s.map, info.door.x, info.door.y), "dooropen", "offen")
	t.ok(not J.some(s.player.inventory, func(i): return i.kind == "schluessel"), "Schlüssel verbraucht")
	t.ok(not s.map.locks.values().has(info.room.id), "alle Schlösser der Kammer offen")


func test_schloss_knacken(t) -> void:
	var s := TH.make(1, {"beruf": 1})
	TH.ready(s)
	var info = _treasure_door(s)
	s.player.pos = info.front.duplicate()
	s.monsters = []
	var c := Dungeon.lockpick_chance(s)
	t.ok(c >= 0.05 and c <= 0.85, "Chance in Grenzen")
	var tries := 0
	while Dungeon.lock_at(s, info.door) != null and tries < 60:
		t.ok(Game.pick_lock(s, info.door).ok, "Versuch")
		tries += 1
	t.is_null(Dungeon.lock_at(s, info.door), "geknackt")
	t.ok(not Game.pick_lock(s, info.door).ok, "kein Schloss mehr")


func test_geheimtuer_entdecken(t) -> void:
	for seed in range(1, 12):
		var s := TH.make(seed, {"beruf": 1})
		if J.arr(s.map, "secrets").is_empty():
			continue
		TH.ready(s)
		var sec: Dictionary = s.map.secrets[0]
		var at := J.pos(sec.x, sec.y)
		t.eq(MapGen.tile_at(s.map, at.x, at.y), "wall", "zunächst Wand")
		var front = _floor_beside(s, at, s.map.rooms[sec.room])
		t.not_null(front, "Gang davor")
		s.player.pos = front.duplicate()
		s.player.stats.int = 10
		var tries := 0
		while not sec.found and tries < 80:
			Game.wait(s)
			s.monsters = []
			tries += 1
		t.ok(sec.found, "entdeckt")
		t.eq(MapGen.tile_at(s.map, at.x, at.y), "door", "wird Tür")
		return
	t.ok(false, "keine Geheimkammer gefunden")


func test_schrein_einmal_beten(t) -> void:
	var s := TH.make(36, {"beruf": 1})
	TH.ready(s)
	var outcomes := {}
	for k in 40:
		var f := {"kind": "schrein", "pos": J.pos(0, 0)}
		s.player.buffs = []
		s.player.hp = 1
		t.ok(Dungeon.pray(s, f).ok, "beten")
		t.eq(f.kind, "schrein_leer", "erlischt")
		t.ok(not Dungeon.pray(s, f).ok, "nur einmal")
		if s.player.hp == Player.max_hp(s):
			outcomes["heilung"] = true
		for b in s.player.buffs:
			outcomes["fluch" if b.get("debuff") else "segen"] = true
	t.ok(outcomes.has("segen"), "Segen kommt vor")
	t.ok(outcomes.has("heilung"), "Heilung kommt vor")
	t.ok(outcomes.has("fluch"), "Fluch kommt vor")


func test_nest_ausraeumen(t) -> void:
	for seed in range(1, 8):
		var s := TH.make(seed, {"beruf": 1})
		var nest = _room_of_feature(s, "nest")
		if nest == null:
			continue
		var mobs: Array = s.monsters.filter(func(m): return m.get("nest") == nest.id)
		t.ge(mobs.size(), 3, "Rudel")
		var spot: Dictionary = nest.furniture[0].pos
		for m in mobs:
			Combat.kill_monster(s, m, null)
		var near_nest := func() -> Array: return s.items.filter(func(e): return J.cheb(e.pos, spot) <= 1)
		t.ge(near_nest.call().size(), 2, "Beute beim Nest")
		t.ok(J.every(near_nest.call(), func(e): return MapGen.furniture_at(s.map, e.pos) == null), "Beute liegt nicht auf dem Nest (erreichbar)")
		t.ok(J.some(nest.furniture, func(f): return f.kind == "nest_leer"), "Nest leer")
		return
	t.ok(false, "kein Nest gefunden")


func test_hinterhalt(t) -> void:
	for seed in range(1, 8):
		var s := TH.make(seed, {"beruf": 1})
		var room = _room_of_feature(s, "hinterhalt")
		if room == null:
			continue
		TH.ready(s)
		t.ok(not J.some(s.monsters, func(m): return MapGen.room_of(s.map, m.pos) != null and MapGen.room_of(s.map, m.pos).id == room.id), "leer")
		var before: int = s.monsters.size()
		Dungeon.on_enter_room(s, room, true)
		t.gt(s.monsters.size(), before, "Gegner tauchen auf")
		t.ok(J.every(s.monsters.slice(before), func(m): return m.aware), "sofort wach")
		var after: int = s.monsters.size()
		Dungeon.on_enter_room(s, room, false)
		t.eq(s.monsters.size(), after, "nur einmal")
		return
	t.ok(false, "kein Hinterhalt gefunden")


func test_wanderhaendler(t) -> void:
	for seed in range(1, 8):
		var s := TH.make(seed, {"beruf": 1})
		var room = _room_of_feature(s, "markt")
		if room == null:
			continue
		TH.ready(s)
		var f: Dictionary = room.furniture[0]
		s.player.pos = MapGen._random_floor_in(s, s.map, room, {"%d,%d" % [f.pos.x, f.pos.y]: true})
		s.monsters = []
		Game.after_move(s)
		t.not_null(room.get("shop"), "Laden da")
		s.player.gold = 5000
		t.ok(Game.buy_offer(s, 0).ok, "kaufen")
		t.lt(s.player.gold, 5000, "bezahlt")
		return
	t.ok(false, "kein Händler gefunden")


func test_haendlertypen(t) -> void:
	var s := TH.make(41, {"beruf": 1})
	var seen := {}
	for i in 40:
		var room := {"id": 900 + i, "feature": "markt", "kind": "normal"}
		var shop := Shop.ensure_shop(s, room)
		seen[shop.type] = true
		t.gt(shop.offers.size(), 0, "%s: Angebote" % shop.type)
		t.ok(String(shop.title) != "", "Titel")
		if shop.type == "apotheke":
			t.ok(J.every(shop.offers, func(o): return o.item.kind == "verbrauch" or o.item.kind == "buch"), "Apotheke nur Tränke und Bücher")
		if shop.type == "waffen":
			t.ok(J.some(shop.offers, func(o): return o.item.get("slot") == "waffe"), "Waffenhändler hat Waffen")
	for id in ["waffen", "apotheke", "schrott", "kurio"]:
		t.ok(seen.has(id), "%s kommt vor" % id)
