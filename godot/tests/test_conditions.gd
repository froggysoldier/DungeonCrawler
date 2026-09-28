extends RefCounted
## Zustände.


func _arena(s: Dictionary) -> Dictionary:
	var guild = TH.room(s, "guild")
	s.player.pos = {"x": guild.x + 1, "y": guild.y + 1}
	s.monsters = []
	Game.move_step(s, {"x": guild.x + 2, "y": guild.y + 1})
	s.player.pet = null
	s.crawlers = []
	s.traps = []
	var room = J.find(s.map.rooms, func(r): return r.kind == "normal" and r.w >= 6 and r.h >= 3)
	s.player.pos = {"x": room.x + 1, "y": room.y + 1}
	return {"x": room.x + 2, "y": room.y + 1}


func _foe(t, s: Dictionary, id: String, at: Dictionary, level: int = 2) -> Dictionary:
	t.ok(MapGen.is_walkable(s.map, at.x, at.y), "Platz frei")
	var m := Monsters.spawn_monster(s, Db.monster(id), level, at, 0)
	m.aware = true
	m.asleep = false
	m.abilities = J.arr(m, "abilities").filter(func(a): return a != "regeneriert")
	s.monsters.append(m)
	return m


func _at(p: Dictionary, dx: int) -> Dictionary:
	return {"x": p.x + dx, "y": p.y}


func test_anfaelligkeit(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	var spot := _arena(s)
	var zwerg := _foe(t, s, "gartenzwerg", spot)
	t.eq(Conditions.susceptibility(s, zwerg, "blutung"), 0.0, "Konstrukte bluten nicht")
	t.eq(Conditions.inflict(s, zwerg, "blutung", 4, 2), false, "keine Blutung")
	var ghul := _foe(t, s, "ghul", _at(spot, 1))
	t.eq(Conditions.susceptibility(s, ghul, "gift"), 0.0, "Untote kein Gift")
	var kak := _foe(t, s, "riesenkakerlake", _at(spot, 2))
	t.eq(Conditions.susceptibility(s, kak, "brennen"), 2.0, "Insekten brennen gut")


func test_bosse_furchtlos(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	var m := _foe(t, s, "kellerratte", _arena(s), 1)
	m.rank = "nachbarschaftsboss"
	t.eq(Conditions.inflict(s, m, "furcht", 5, 1), false, "keine Furcht")


func test_blutung_kann_toeten(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	var m := _foe(t, s, "kellerratte", _at(_arena(s), 3), 1)
	m.aware = false
	t.ok(Conditions.inflict(s, m, "blutung", 4, 3), "Blutung")
	var hp: int = m.hp
	Ai.monster_turn(s, m)
	t.lt(m.hp, hp, "Schaden")
	m.hp = 1
	Ai.monster_turn(s, m)
	t.ok(not J.has_same(s.monsters, m), "tot")
	t.eq(Stats.stat(s, "kills.teil.blutung"), 1.0, "Kill durch Blutung")


func test_kochmesser_blutung(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	var spot := _arena(s)
	s.player.equipment.waffe = Items.create_item(s, "kochmesser")
	var bled := false
	for i in 40:
		if bled:
			break
		var m: Dictionary = s.monsters[0] if not s.monsters.is_empty() else _foe(t, s, "tatzelwurm", spot, 3)
		m.hp = m.maxHp
		s.player.ausdauer = 20
		Combat.player_attack(s, m, {"part": "waffe", "move": "normal"})
		bled = Conditions.has_condition(m, "blutung")
	t.ok(bled, "blutet")


func test_staubbeutel_blendet(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	var spot := _arena(s)
	var a := _foe(t, s, "kobold", _at(spot, 2))
	var b := _foe(t, s, "kobold", _at(spot, 3))
	s.player.inventory.append(Items.create_item(s, "staubbeutel", 1))
	s.player.wurfWahl = "staubbeutel"
	s.unlocks.append("inventar")
	Combat.player_attack(s, a, {"part": "wurf", "move": "normal"})
	t.ok(Conditions.has_condition(a, "blind"), "a blind")
	t.ok(Conditions.has_condition(b, "blind"), "b blind")
	t.ge(Stats.stat(s, "zustand.blind"), 2.0, "gezählt")


func test_furcht_flucht(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	var m := _foe(t, s, "kobold", _arena(s))
	var hp: int = s.player.hp
	t.ok(Conditions.inflict(s, m, "furcht", 6, 1), "Furcht")
	var d0 := TH.cheb(m.pos, s.player.pos)
	for i in 3:
		Ai.monster_turn(s, m)
	t.ge(TH.cheb(m.pos, s.player.pos), d0, "weicht zurück")
	t.eq(s.player.hp, hp, "kein Angriff")


func test_crawler_blutung_verband(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	_arena(s)
	s.player.hp = Player.max_hp(s)
	t.ok(Conditions.inflict_player(s, "blutung", 5, 2, "Test"), "Blutung")
	t.ok(Conditions.player_has(s, "blutung"), "blutet")
	var hp: int = s.player.hp
	Game.wait(s)
	t.lt(s.player.hp, hp, "Schaden")
	var v := Items.create_item(s, "verband")
	s.player.inventory.append(v)
	s.unlocks.append("inventar")
	Game.use_item(s, v.uid)
	t.ok(not Conditions.player_has(s, "blutung"), "gestoppt")


func test_warten_erstickt_flammen(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	_arena(s)
	Conditions.inflict_player(s, "brennen", 3, 2, "Test")
	t.ok(Conditions.player_has(s, "brennen"), "brennt")
	Game.wait(s)
	t.ok(not Conditions.player_has(s, "brennen"), "gelöscht")


func test_verbluten(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	_arena(s)
	s.player.curses = []
	s.player.hp = 1
	Conditions.inflict_player(s, "blutung", 5, 3, "Test")
	Game.wait(s)
	t.ok(s.status == "dead" or s.player.hp > 0, "tot oder lebendig")
	if s.status == "dead":
		t.eq(s.deathCause, Conditions.CONDITIONS.blutung.death, "Ursache")


func test_feuerwesen_setzen_in_brand(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	var m := _foe(t, s, "toaster_mimic", _arena(s))
	m.behavior = "melee"
	m.erase("range")
	m.treffer = 200
	var burning := false
	for i in 40:
		if burning:
			break
		s.player.hp = Player.max_hp(s)
		Ai.monster_turn(s, m)
		burning = Conditions.player_has(s, "brennen")
	t.ok(burning, "brennt")
