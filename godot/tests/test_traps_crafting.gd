extends RefCounted
## Fallen und Handwerk.


func _make(seed: int = 2100) -> Dictionary:
	var s := TH.make(seed, {"beruf": 1})
	TH.tutorial(s)
	s.traps = []
	return s


func _free(s: Dictionary, p: Dictionary) -> Variant:
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]:
		var q := {"x": p.x + d[0], "y": p.y + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y) and not J.some(s.monsters, func(m): return m.pos.x == q.x and m.pos.y == q.y):
			return q
	return null


## Ein normales Feld außerhalb von Safe Rooms und Gilde.
func _open_spot(s: Dictionary) -> Dictionary:
	var re := RegEx.create_from_string("(?i)werkstatt|schmiede")
	var r = J.find(s.map.rooms, func(x): return x.kind == "normal" and re.search(x.name) == null)
	return {"x": r.x + 1, "y": r.y + 1}


func test_versteckte_fallen(t) -> void:
	var s := TH.make(2100, {"beruf": 1})
	t.ge(s.traps.size(), 8, "Fallen")
	for tr in s.traps:
		t.eq(tr.hidden, true, "versteckt")
		var r: int = s.map.roomAt[tr.pos.y * s.map.width + tr.pos.x]
		if r >= 0:
			t.eq(s.map.rooms[r].kind, "normal", "nur in normalen Räumen")


func test_falle_loest_aus(t) -> void:
	var s := _make()
	var spot := _open_spot(s)
	s.player.pos = spot.duplicate()
	var target = _free(s, spot)
	s.traps = [{"uid": "x", "pos": target, "kind": "baerenfalle", "hidden": true, "owner": "dungeon"}]
	var hp: int = s.player.hp
	s.player.stats.str = 1
	t.ok(Game.move_step(s, target).ok, "Schritt")
	t.lt(s.player.hp, hp, "Schaden")
	t.gt(J.num(s.player, "immobile"), 0.0, "festgehalten")
	t.is_null(Traps.trap_at(s, target), "Falle verbraucht")
	s.monsters = []
	Game.move_step(s, spot)
	t.eq(s.player.pos, target, "bleibt stehen")


func test_entschaerfen(t) -> void:
	var success := false
	for seed in 10:
		if success:
			break
		var s := _make(2200 + seed)
		s.player.stats.ges = 12
		var spot := _open_spot(s)
		s.player.pos = spot.duplicate()
		var tp = _free(s, spot)
		s.traps = [{"uid": "y", "pos": tp, "kind": "stolperdraht", "hidden": false, "owner": "dungeon"}]
		t.ok(Game.disarm_trap(s, "y").ok, "Versuch")
		success = J.some(s.player.inventory, func(i): return i.baseId == "fallenteile")
	t.ok(success, "Fallenteile")


func test_giftgas(t) -> void:
	var s := _make()
	Traps.spring_on_player(s, {"uid": "g", "pos": s.player.pos.duplicate(), "kind": "giftgas", "hidden": true, "owner": "dungeon"})
	t.ok(J.some(s.player.buffs, func(b): return b.name == "Vergiftet"), "vergiftet")


func test_verband(t) -> void:
	var s := _make()
	s.player.inventory.append(Items.create_item(s, "lappen", 2))
	t.ok(Game.craft_item(s, "verband").ok, "hergestellt")
	t.ok(J.some(s.player.inventory, func(i): return i.baseId == "verband"), "Verband")
	t.ok(not J.some(s.player.inventory, func(i): return i.baseId == "lappen"), "Lappen verbraucht")


func test_zutaten_und_werkbank(t) -> void:
	var s := _make()
	s.player.pos = _open_spot(s)
	t.ok(not Game.craft_item(s, "brandflasche").ok, "ohne Zutaten")
	s.player.inventory.append(Items.create_item(s, "dose"))
	s.player.inventory.append(Items.create_item(s, "naegel", 2))
	s.player.inventory.append(Items.create_item(s, "schwarzpulver"))
	var res := Game.craft_item(s, "nagelbombe")
	t.ok(not res.ok, "ohne Werkbank")
	t.matches(res.get("message"), "Werkbank")
	s.player.inventory.append(Items.create_item(s, "klappwerkbank"))
	t.ok(Game.craft_item(s, "nagelbombe").ok, "mit Werkbank")
	var bomb = J.find(s.player.inventory, func(i): return i.baseId == "nagelbombe")
	t.ge(J.num(bomb, "menge"), 2.0, "zwei Stück")


func test_brandflasche(t) -> void:
	var s := _make()
	var spot := _open_spot(s)
	s.player.pos = spot.duplicate()
	var far := {"x": spot.x + 3, "y": spot.y}
	s.player.inventory.append(Items.create_item(s, "brandflasche", 1))
	s.player.wurfWahl = "brandflasche"
	var a := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, far, 0)
	var b := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, _free(s, far), 0)
	for m in [a, b]:
		m.hp = 200
		m.maxHp = 200
	s.monsters = [a, b]
	for i in 5:
		if not J.some(s.player.inventory, func(x): return x.baseId == "brandflasche"):
			break
		Game.attack(s, a.uid, {"part": "wurf", "move": "normal"})
	t.lt(b.hp, 200, "b getroffen")
	t.lt(a.hp, 200, "a getroffen")


func test_eigene_fallen(t) -> void:
	var s := _make()
	var spot := _open_spot(s)
	s.player.pos = spot.duplicate()
	var trap := Items.create_item(s, "stachelfalle")
	s.player.inventory.append(trap)
	t.ok(Game.place_trap(s, trap.uid).ok, "aufgestellt")
	var own = Traps.trap_at(s, spot)
	t.eq(own.owner if own != null else null, "crawler", "eigene Falle")
	var hp: int = s.player.hp
	var next = _free(s, spot)
	Game.move_step(s, next)
	Game.move_step(s, spot)
	t.ge(s.player.hp, hp - 5, "keine Wirkung auf den Crawler")
	t.not_null(Traps.trap_at(s, spot), "bleibt liegen")
	Game.move_step(s, next)
	var rat := Monsters.spawn_monster(s, Db.monster("kellerratte"), 1, spot, 0)
	s.monsters = [rat]
	var rat_hp: int = rat.hp
	Traps.on_monster_step(s, rat)
	t.ok(rat.hp < rat_hp or not J.has_same(s.monsters, rat), "Monster getroffen")
	t.is_null(Traps.trap_at(s, spot), "ausgelöst")
	Game.wait(s)
