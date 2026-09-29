extends RefCounted
## Sichtbare Effekte im Kampf: Die Engine meldet Angriff, Treffer und Tod, der
## Animator macht daraus Ausfallschritt, Aufblitzen, Pixelzerfall und Beben.


func _setup() -> Dictionary:
	var s := TH.make(21)
	s.pendingDialogs.clear()
	s.monsters = []
	var spot = TH.free_neighbor(s, s.player.pos)
	var m := Monsters.spawn_monster(s, TH.monster_def("kellerratte"), 1, spot, 0)
	m.ausweichen = -200
	m.aware = true
	s.monsters.append(m)
	return {"s": s, "m": m}


func test_angriff_meldet_ausfall_treffer_und_tod(t) -> void:
	var e := _setup()
	var s: Dictionary = e.s
	var m: Dictionary = e.m
	m.hp = 1
	var kinds: Array = []
	# Trefferchance höchstens 95 %: bis die Ratte fällt
	for i in 10:
		if not J.has_same(s.monsters, m):
			break
		t.ok(Game.attack(s, m.uid, {"part": "faust", "move": "normal"}).ok, "Angriff")
		kinds.append_array(Fx.drain_fx(s).map(func(f): return f.kind))
	t.has(kinds, "strike", "Ausfallschritt")
	t.has(kinds, "hit", "Treffer")
	t.has(kinds, "death", "Tod")


func test_monster_greift_an(t) -> void:
	var e := _setup()
	var s: Dictionary = e.s
	var m: Dictionary = e.m
	m.treffer = 500
	Fx.drain_fx(s)
	Ai.monster_turn(s, m)
	var fx := Fx.drain_fx(s)
	var strike = J.find(fx, func(f): return f.kind == "strike")
	t.not_null(strike, "Monster macht einen Ausfallschritt")
	if strike != null:
		t.eq([strike.from.x, strike.from.y], [m.pos.x, m.pos.y], "vom Monster aus")
		t.eq([strike.to.x, strike.to.y], [s.player.pos.x, s.player.pos.y], "zum Spieler hin")


func test_animator_macht_daraus_bewegung(t) -> void:
	var e := _setup()
	var s: Dictionary = e.s
	var m: Dictionary = e.m
	m.hp = 1
	var a := Animator.new()
	var before := a.snapshot(s)
	var fx: Array = []
	for i in 10:
		if not J.has_same(s.monsters, m):
			break
		before = a.snapshot(s)
		Game.attack(s, m.uid, {"part": "faust", "move": "normal"})
		fx = Fx.drain_fx(s)
	a.after(s, before, fx, 1000.0)
	t.gt(a.lunge("p", 1000.0 + Animator.LUNGE_MS / 2).length(), 0.2, "Spielfigur beugt sich vor")
	t.eq(a.lunge("p", 1000.0 + Animator.LUNGE_MS + 1), Vector2.ZERO, "und steht danach wieder")
	var bursts := a.bursts(1200.0)
	t.eq(bursts.size(), 1, "Ratte zerfällt")
	if not bursts.is_empty():
		t.eq(bursts[0].defId, "kellerratte", "richtiges Monster")
	t.eq(a.bursts(1000.0 + 60 + Animator.LUNGE_MS + Animator.BURST_MS + 1).size(), 0, "Zerfall endet")


func test_schwerer_treffer_bebt(t) -> void:
	var a := Animator.new()
	var s := TH.make(22)
	var before := a.snapshot(s)
	a.after(s, before, [{"kind": "hit", "at": J.pcopy(s.player.pos), "strong": true}], 1000.0)
	t.ok(a.flashing("p", 1050.0), "Spielfigur blitzt auf")
	t.ok(not a.flashing("p", 1000.0 + Animator.FLASH_MS + 1), "nur kurz")
	var moved := false
	for ms in [1020.0, 1060.0, 1100.0]:
		if a.shake(ms) != Vector2.ZERO:
			moved = true
	t.ok(moved, "Bild bebt")
	t.eq(a.shake(1000.0 + Animator.SHAKE_MS + 1), Vector2.ZERO, "Beben endet")


func test_stufenaufstieg_funkelt(t) -> void:
	var s := TH.make(23)
	Fx.drain_fx(s)
	Player.gain_xp(s, Progression.xp_to_next(s.player.level) + 1)
	var fx := Fx.drain_fx(s)
	t.ok(J.some(fx, func(f): return f.kind == "levelup"), "Engine meldet den Aufstieg")
	var a := Animator.new()
	a.after(s, a.snapshot(s), fx, 1000.0)
	t.eq(a.sparkles(1100.0).size(), 1, "Funken laufen")
	t.eq(a.sparkles(1000.0 + Animator.SPARKLE_MS + 1).size(), 0, "und enden")
