extends RefCounted
## Gegnerverhalten.


func _arena(s: Dictionary) -> Callable:
	var r := TH.ready(s, 9)
	s.player.pos = {"x": r.x, "y": r.y + 1}
	return func(dx: int) -> Dictionary: return {"x": r.x + dx, "y": r.y + 1}


func _spawn(s: Dictionary, id: String, level: int, pos: Dictionary) -> Dictionary:
	return Monsters.spawn_monster(s, Db.monster(id), level, pos, 0)


func test_wer_dich_sieht_kommt(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var ghul := _spawn(s, "ghul", 2, at.call(4))
	s.monsters = [ghul]
	Ai.monster_turn(s, ghul)
	t.ok(ghul.aware, "bemerkt")
	t.lt(ghul.pos.x, at.call(4).x, "kommt näher")


func test_verletzte_fliehen_nicht(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var ghul := _spawn(s, "ghul", 2, at.call(3))
	ghul.hp = 1
	s.monsters = [ghul]
	for i in 6:
		Ai.monster_turn(s, ghul)
	t.ok(not ghul.get("fleeing", false), "flieht nicht")


func test_feiglinge_halten_abstand(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var gnom := _spawn(s, "gnom_buerokrat", 1, at.call(2))
	s.monsters = [gnom]
	Ai.monster_turn(s, gnom)
	Ai.monster_turn(s, gnom)
	t.eq(gnom.get("fleeing"), true, "flieht")


func test_schlafende_wachen_durch_laerm(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var ghul := _spawn(s, "ghul", 2, at.call(5))
	ghul.asleep = true
	s.monsters = [ghul]
	for i in 4:
		Ai.monster_turn(s, ghul)
	t.ok(ghul.asleep, "schläft weiter")
	t.eq(ghul.pos, at.call(5), "bleibt stehen")
	Ai.make_noise(s, at.call(6), 6)
	t.ok(not ghul.asleep, "aufgewacht")


func test_warnen_artgenossen(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var a := _spawn(s, "ghul", 2, at.call(3))
	var b := _spawn(s, "ghul", 2, at.call(8))
	s.monsters = [a, b]
	Ai.monster_turn(s, a)
	t.ok(a.aware, "a bemerkt")
	t.ok(b.aware or not MapGen.is_walkable(s.map, at.call(8).x, at.call(8).y), "b gewarnt")
