extends RefCounted
## Klänge der Engine.


func test_klaenge_werden_angemeldet(t) -> void:
	var s := TH.make(4242, {"beruf": 1})
	t.ok(J.some(Fx.drain_sfx(s), func(x): return x.kind == "achievement"), "Start-Achievement")
	Player.gain_xp(s, 500)
	t.ok(J.some(Fx.drain_sfx(s), func(x): return x.kind == "levelup"), "Level-Aufstieg")
	TH.tutorial(s)
	var safe = TH.room(s, "safe")
	s.player.pos = {"x": safe.x + 1, "y": safe.y + 1}
	s.monsters = []
	Game.move_step(s, {"x": safe.x + 2, "y": safe.y + 1})
	Fx.drain_sfx(s)
	var box := Items.create_box(s, "abenteurer", "gold")
	s.player.boxes.append(box)
	t.ok(Game.open_box(s, box.uid).ok, "Box offen")
	var b = J.find(Fx.drain_sfx(s), func(x): return x.kind == "box")
	t.eq(b.tier if b != null else null, "gold", "Box-Klang")
