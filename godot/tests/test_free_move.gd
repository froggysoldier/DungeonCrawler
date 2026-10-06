extends RefCounted
## Freie Bewegung: Wege glätten, keine Linie durch Wände, Meter, und
## Figuren, die in einer Kampfrunde mehrere Felder laufen, folgen dem Weg.


## Kleine Karte aus Zeichen: # Wand, . Boden.
func _map(rows: Array) -> Dictionary:
	var s := TH.make(5)
	var w: int = String(rows[0]).length()
	var tiles: Array = []
	for r in rows:
		for ch in String(r):
			tiles.append("wall" if ch == "#" else "floor")
	var n := tiles.size()
	var explored: Array = []
	var room_at: Array = []
	for i in n:
		explored.append(true)
		room_at.append(-1)
	s.map = {"width": w, "height": rows.size(), "tiles": tiles, "explored": explored, "roomAt": room_at, "rooms": []}
	s.monsters = []
	s.items = []
	s.traps = []
	s.crawlers = []
	s.player.pet = null
	s.player.pos = J.pos(1, 1)
	return s


func test_gerade_linien(t) -> void:
	var s := _map([
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	])
	var path = Game.plan_path(s, J.pos(8, 3))
	t.not_null(path, "Weg")
	var pts := FreeMove.smooth(s, Vector2(1, 1), path)
	t.eq(pts.size(), 2, "im offenen Raum eine gerade Linie")
	t.eq(pts[-1], Vector2(8, 3), "bis ans Ziel")
	t.ok(absf(FreeMove.length(pts) - Vector2(7, 2).length()) < 0.01, "Länge der Linie")
	t.eq(FreeMove.meters(6), "9 m", "6 Felder = 9 m")
	t.eq(FreeMove.meters(3), "4,5 m", "Komma")


func test_nicht_durch_waende(t) -> void:
	var s := _map([
		"#######",
		"#.....#",
		"####..#",
		"####..#",
		"#.....#",
		"#######",
	])
	t.ok(not FreeMove.clear_line(s, Vector2(1, 1), Vector2(1, 4)), "nicht durch die Wand")
	var path = Game.plan_path(s, J.pos(1, 4))
	var pts := FreeMove.smooth(s, Vector2(1, 1), path)
	t.gt(pts.size(), 2, "um die Ecke mit Knick")
	for n in range(1, pts.size()):
		t.ok(FreeMove.clear_line(s, pts[n - 1], pts[n]), "jedes Stück ist frei")
	# Ein Gegner läuft in einer Runde um die Ecke: unterwegs nie in der Wand
	var anim := Animator.new()
	var mon := {"uid": "m1", "pos": J.pos(1, 1)}
	s.monsters = [mon]
	var before := anim.snapshot(s)
	mon.pos = J.pos(1, 4)
	anim.after(s, before, [], 0.0)
	t.ok(anim.moving("m1"), "Gegner gleitet")
	for k in range(0, 21):
		var p := anim.draw_pos("m1", Vector2(1, 4), k * 60.0)
		var tile := FreeMove.tile_of(p)
		t.ok(MapGen.is_walkable(s.map, tile.x, tile.y), "Zwischenstand auf Boden (%s)" % p)
	t.eq(anim.draw_pos("m1", Vector2(1, 4), 99999.0), Vector2(1, 4), "kommt an")


func test_gegnerzug_nacheinander(t) -> void:
	var s := _map([
		"##########",
		"#........#",
		"#........#",
		"#........#",
		"##########",
	])
	s.round = {"move": 6, "max": 6, "n": 1, "acted": false}
	var anim := Animator.new()
	var a := {"uid": "a", "pos": J.pos(5, 1)}
	var b := {"uid": "b", "pos": J.pos(5, 3)}
	s.monsters = [a, b]
	var before := anim.snapshot(s)
	a.pos = J.pos(3, 1)
	b.pos = J.pos(3, 3)
	anim.after(s, before, [], 0.0)
	t.eq(anim.draw_pos("a", Vector2(3, 1), 100.0).x < 5.0, true, "der erste läuft sofort")
	t.eq(anim.draw_pos("b", Vector2(3, 3), 100.0), Vector2(5, 3), "der zweite wartet")
	t.ok(anim.draw_pos("b", Vector2(3, 3), 400.0).x < 5.0, "dann läuft der zweite")
	# Ohne Kampf laufen alle zugleich
	s.erase("round")
	var anim2 := Animator.new()
	a.pos = J.pos(5, 1)
	b.pos = J.pos(5, 3)
	before = anim2.snapshot(s)
	a.pos = J.pos(4, 1)
	b.pos = J.pos(4, 3)
	anim2.after(s, before, [], 0.0)
	t.ok(anim2.draw_pos("b", Vector2(4, 3), 60.0).x < 5.0, "ohne Kampf zugleich")
