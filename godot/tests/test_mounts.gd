extends RefCounted
## Reittiere und Fahrzeuge.


func _make() -> Dictionary:
	var s := TH.make(8100, {"beruf": 1})
	TH.tutorial(s)
	s.traps = []
	s.crawlers = []
	return s


func _open_room(s: Dictionary) -> Dictionary:
	return J.find(s.map.rooms, func(r): return r.kind == "normal" and r.w >= 7 and r.h >= 4)


func test_zwei_schritte_pro_zug(t) -> void:
	var s := _make()
	var key := Items.create_item(s, "zuendschluessel_wagen")
	s.player.inventory.append(key)
	t.ok(Game.use_item(s, key.uid).ok, "Schlüssel")
	var room := _open_room(s)
	s.player.pos = {"x": room.x, "y": room.y + 1}
	t.ok(Game.ride_toggle(s).ok, "aufsitzen")
	var turn: int = s.turn
	var fuel: int = s.player.mount.fuel
	for i in range(1, 5):
		s.monsters = []
		Game.move_step(s, {"x": room.x + i, "y": room.y + 1})
	t.eq(s.turn - turn, 2, "zwei Züge")
	t.eq(s.player.mount.fuel, fuel - 4, "Benzin")
	s.player.inventory.append(Items.create_item(s, "benzinkanister"))
	t.ok(Game.refuel_mount(s).ok, "tanken")
	t.gt(s.player.mount.fuel, fuel - 4, "voller")


func test_rammen(t) -> void:
	var s := _make()
	var whistle := Items.create_item(s, "pfeife_eber")
	s.player.inventory.append(whistle)
	Game.use_item(s, whistle.uid)
	var room := _open_room(s)
	s.player.pos = {"x": room.x + 1, "y": room.y + 1}
	var spot := {"x": room.x + 2, "y": room.y + 1}
	t.ok(MapGen.is_walkable(s.map, spot.x, spot.y), "frei")
	var m := Monsters.spawn_monster(s, Db.monster("ghul"), 3, spot, 0)
	m.hp = 999
	m.maxHp = 999
	m.ausweichen = -200
	m.abilities = []
	s.monsters = [m]
	var tech := {"part": "faust", "move": "anlauf"}
	t.ok(not Game.attack(s, m.uid, tech).ok, "zu Fuß ohne Anlauf nicht")
	Game.ride_toggle(s)
	for i in 5:
		if m.hp != 999:
			break
		s.player.ausdauer = 20
		t.ok(Game.attack(s, m.uid, tech).ok, "beritten")
	t.lt(m.hp, 999 - 10, "Rammschaden")
	t.ok(J.some(s.log, func(l): return String(l.text).contains("rammt")), "im Log")


func test_absteigen_im_safe_room(t) -> void:
	var s := _make()
	var whistle := Items.create_item(s, "pfeife_pony")
	s.player.inventory.append(whistle)
	Game.use_item(s, whistle.uid)
	var safe = TH.room(s, "safe")
	s.player.pos = {"x": safe.x + 1, "y": safe.y + 1}
	t.ok(not Game.ride_toggle(s).ok, "kein Reiten im Safe Room")
