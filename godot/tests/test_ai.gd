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


func test_feiglinge_fliehen_erst_verletzt(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var gnom := _spawn(s, "gnom_buerokrat", 1, at.call(2))
	s.monsters = [gnom]
	Ai.monster_turn(s, gnom)
	t.ok(not gnom.get("fleeing", false), "unverletzt bleibt er")
	gnom.hp = int(gnom.maxHp * 0.4)
	Ai.monster_turn(s, gnom)
	Ai.monster_turn(s, gnom)
	t.eq(gnom.get("fleeing"), true, "verletzt flieht er")


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


func test_alarm_nur_fuer_artgenossen_und_nachbarn(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var a := _spawn(s, "ghul", 2, at.call(3))
	var fern := _spawn(s, "kobold", 2, at.call(8))
	var nah := _spawn(s, "kobold", 2, at.call(5))
	s.monsters = [a, fern, nah]
	Ai.monster_turn(s, a)
	t.ok(a.aware, "a bemerkt")
	t.ok(nah.aware, "andere Art direkt daneben wird aufmerksam")
	t.ok(not fern.aware, "andere Art weiter weg bleibt ahnungslos")


func test_monster_betreten_keine_safe_rooms(t) -> void:
	var s := TH.make(9101, {"beruf": 1})
	var safe = TH.room(s, "safe")
	var inside := MapGen.center(safe)
	var m := _spawn(s, "heinzelmann", 1, inside)
	t.ok(not Ai._allowed_tile(s, m, inside), "Safe Room ist für Monster gesperrt")


func test_kampfrunden(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var ghul := _spawn(s, "ghul", 2, at.call(5))
	ghul.aware = true
	s.monsters = [ghul]
	Rounds.after_turn(s)
	t.ok(Rounds.active(s), "Kampf läuft in Runden")
	var budget: int = s.round.move
	t.ge(budget, 4, "Bewegungsvorrat")
	var turn: int = s.turn
	var ghul_at: Dictionary = ghul.pos.duplicate()
	# Schritte kosten keine Zeit, der Gegner wartet
	var moved := 0
	for d in [[0, 1], [0, -1]]:
		var to := {"x": s.player.pos.x + d[0], "y": s.player.pos.y + d[1]}
		if Game.move_step(s, to).ok:
			moved += 1
	t.eq(s.turn, turn, "Schritte in der Runde kosten keine Zeit")
	t.eq(ghul.pos, ghul_at, "der Gegner wartet")
	t.eq(int(s.round.move), budget - moved, "Vorrat sinkt")
	# Ist der Vorrat leer, geht kein Schritt mehr
	s.round.move = 0
	t.ok(not Game.move_step(s, {"x": s.player.pos.x - 1, "y": s.player.pos.y}).ok, "ohne Vorrat kein Schritt")
	# Runde beenden: Gegner läuft mehrere Felder heran, neue Runde mit vollem Vorrat
	var before := J.cheb(ghul.pos, s.player.pos)
	Game.wait(s)
	t.eq(s.turn, turn + 1, "eine Runde ist ein Zug")
	t.ge(before - J.cheb(ghul.pos, s.player.pos), mini(2, before - 1), "Gegner kommt mehrere Felder näher")
	if Rounds.active(s):
		t.eq(int(s.round.move), int(s.round.max), "neue Runde, voller Vorrat")
	# Nach der Aktion darf man weiterlaufen; die Runde endet erst danach
	if Rounds.active(s):
		var n0: int = s.round.n
		var foe = s.monsters[0] if not s.monsters.is_empty() else null
		if foe != null:
			s.player.pos = MapGen.free_beside(s.map, foe.pos) if MapGen.free_beside(s.map, foe.pos) != null else s.player.pos
			if J.cheb(s.player.pos, foe.pos) <= 1:
				Game.attack(s, foe.uid, {"part": "faust", "move": "normal"})
				if Rounds.active(s) and J.has_same(s.monsters, foe):
					t.eq(int(s.round.n), n0, "Angriff beendet die Runde nicht")
					t.ok(s.round.acted, "Aktion verbraucht")
	# Ohne Gegner endet der Kampf
	s.monsters = []
	Game.wait(s)
	t.ok(not Rounds.active(s), "Kampf vorbei")


func test_haustier_laeuft_in_der_runde(t) -> void:
	var s := TH.make(9100, {"beruf": 1})
	var at := _arena(s)
	var ghul := _spawn(s, "ghul", 2, at.call(4))
	ghul.aware = true
	s.monsters = [ghul]
	var pet := Extras.make_pet_of("Katze", "Minka")
	pet.pos = at.call(1)
	s.player.pet = pet
	Ai.pet_close_in(s, Rounds.ALLY_SPEED - 1)
	t.eq(J.cheb(pet.pos, ghul.pos), 1, "Haustier läuft zum Gegner")
	# Ohne Gegner holt es den Crawler in einer Runde ein
	s.monsters = []
	pet.pos = at.call(4)
	Ai.pet_close_in(s, Rounds.ALLY_SPEED - 1)
	t.le(J.cheb(pet.pos, s.player.pos), 2, "Haustier folgt mehrere Felder")
