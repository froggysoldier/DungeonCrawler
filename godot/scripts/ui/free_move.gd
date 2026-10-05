class_name FreeMove
extends RefCounted
## Freie Bewegung auf der Karte: Die Figur läuft stufenlos und auf geraden
## Linien, wie in Baldur's Gate. Im Hintergrund rechnet das Spiel weiter in
## Feldern: Wechselt die Figur auf ein neues Feld, ist das ein Schritt.
## Positionen in Feldern wie auf der Karte (ganze Zahl = Feld, Mitte bei +0.5
## gezeichnet); das Feld einer Position ist die gerundete Position.

## Laufgeschwindigkeit in Feldern pro Sekunde.
const SPEED := 1000.0 / Animator.STEP_MS
## So weit hält die Figur auf geraden Linien Abstand zu Wandecken (in Feldern).
const CLEARANCE := 0.28
## Ein Feld sind 1,5 Meter.
const METERS := 1.5


static func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.y))


## Länge in Metern als Text („4,5 m“).
static func meters(tiles: float) -> String:
	var m := tiles * METERS
	if absf(m - roundf(m)) < 0.05:
		return "%d m" % roundi(m)
	return ("%.1f m" % m).replace(".", ",")


## Darf eine gerade Linie über dieses Feld führen?
static func _open(s: Dictionary, t: Vector2i) -> bool:
	var m: Dictionary = s.map
	if not MapGen.in_bounds(m, t.x, t.y) or not m.explored[MapGen.idx(m, t.x, t.y)]:
		return false
	if not MapGen.is_walkable(m, t.x, t.y) or Pathfinding.is_door(m, t.x, t.y):
		return false
	var tp := J.pos(t.x, t.y)
	return MapGen.furniture_at(m, tp) == null and not Traps.avoid_tile(s, t.x, t.y) and Ai.monster_at(s, tp) == null


## Führt die gerade Linie a -> b nur über freie Felder, mit Abstand zu Ecken?
static func clear_line(s: Dictionary, a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return true
	var side := Vector2(-d.y, d.x) / len * CLEARANCE
	var n := ceili(len / 0.1)
	var prev := tile_of(a)
	var goal := tile_of(b)
	for k in range(1, n + 1):
		var q := a + d * (float(k) / n)
		var t := tile_of(q)
		if t != prev:
			var ok := _open(s, t) or (t == goal and MapGen.is_walkable(s.map, t.x, t.y))
			if not ok or not Pathfinding.can_step(s.map, J.pos(prev.x, prev.y), J.pos(t.x, t.y)):
				return false
			prev = t
		for o in [side, -side]:
			var e := tile_of(q + o)
			if e != t and not MapGen.is_walkable(s.map, e.x, e.y):
				return false
	return true


## Weg aus Feldern zu wenigen geraden Stücken glätten (Fadenziehen). Türen
## bleiben feste Punkte: Durch einen Türrahmen geht es nur gerade hindurch.
static func smooth(s: Dictionary, start: Vector2, path: Array) -> Array:
	var pts: Array = [start]
	for p in path:
		pts.append(Vector2(p.x, p.y))
	var out: Array = [start]
	var i := 0
	while i < pts.size() - 1:
		var j := i + 1
		var k := pts.size() - 1
		while k > i + 1:
			if _no_door_between(s, pts, i, k) and clear_line(s, pts[i], pts[k]):
				j = k
				break
			k -= 1
		out.append(pts[j])
		i = j
	return out


static func _no_door_between(s: Dictionary, pts: Array, i: int, k: int) -> bool:
	for n in range(i + 1, k):
		var t := tile_of(pts[n])
		if Pathfinding.is_door(s.map, t.x, t.y):
			return false
	return true


## Länge eines Linienzugs in Feldern.
static func length(pts: Array) -> float:
	var l := 0.0
	for n in range(1, pts.size()):
		l += (pts[n] as Vector2).distance_to(pts[n - 1])
	return l


## Punkt nach dist Feldern auf dem Linienzug.
static func point_at(pts: Array, dist: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var left := dist
	for n in range(1, pts.size()):
		var a: Vector2 = pts[n - 1]
		var b: Vector2 = pts[n]
		var l := a.distance_to(b)
		if left <= l:
			return a.lerp(b, left / maxf(l, 0.0001))
		left -= l
	return pts[-1]
