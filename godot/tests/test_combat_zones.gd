extends RefCounted
## Trefferzonen (Port von tests/combat_zones.test.ts).


func _duel(t, s: Dictionary, id: String = "ghul") -> Dictionary:
	var r := TH.ready(s)
	var spot := {"x": r.x + 2, "y": r.y + 1}
	t.ok(MapGen.is_walkable(s.map, spot.x, spot.y), "Platz frei")
	var m := Monsters.spawn_monster(s, Db.monster(id), 2, spot, 0)
	m.aware = true
	m.abilities = []
	s.monsters = [m]
	return m


func test_kopf_schwerer_als_koerper(t) -> void:
	var s := TH.make(9900, {"beruf": 1})
	var m := _duel(t, s)
	var head := Combat.hit_chance(s, m, {"part": "faust", "move": "normal", "zone": "kopf"})
	var body := Combat.hit_chance(s, m, {"part": "faust", "move": "normal", "zone": "koerper"})
	t.lt(head, body, "Kopf schwerer")
	m.downed = 2
	t.gt(Combat.hit_chance(s, m, {"part": "faust", "move": "normal", "zone": "kopf"}), head, "liegend leichter")


func test_zoneneffekte(t) -> void:
	var effects := {}
	for seed in 40:
		if effects.size() >= 3:
			break
		var s := TH.make(9950 + seed, {"beruf": 1})
		var m := _duel(t, s)
		m.hp = 999
		m.maxHp = 999
		m.ausweichen = -300
		for zone in ["kopf", "arme", "beine"]:
			s.player.ausdauer = 20
			Game.attack(s, m.uid, {"part": "faust", "move": "normal", "zone": zone})
		if m.has("stunned"):
			effects["benommen"] = true
		if m.has("weakened"):
			effects["geschwaecht"] = true
		if m.has("slowed"):
			effects["humpelt"] = true
	var k := effects.keys()
	k.sort()
	t.eq(k, ["benommen", "geschwaecht", "humpelt"], "alle Effekte")


func test_benommene_setzen_aus(t) -> void:
	var s := TH.make(9900, {"beruf": 1})
	var m := _duel(t, s)
	m.stunned = 1
	var hp: int = s.player.hp
	Ai.monster_turn(s, m)
	t.eq(s.player.hp, hp, "kein Angriff")
	t.eq(m.stunned, 0, "Benommenheit vorbei")


func test_deckung(t) -> void:
	var s := TH.make(9900, {"beruf": 1})
	_duel(t, s)
	t.ok(Game.defend(s).ok, "Deckung")
	t.ok(J.some(s.log, func(l): return String(l.text).contains("Deckung")), "im Log")
	t.ok(not J.some(s.player.buffs, func(b): return b.name == "Deckung"), "nach dem Zug weg")
