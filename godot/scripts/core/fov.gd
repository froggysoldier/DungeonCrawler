class_name Fov
extends RefCounted
## Sichtfeld und Sichtlinie (Port von src/engine/fov.ts).


## Sichtfeld per Strahlenwurf. Gibt die sichtbaren Kachel-Indizes zurück.
static func compute(m: FloorMap, origin: Vector2i, radius: int) -> Dictionary:
	var visible := {}
	visible[m.idx(origin.x, origin.y)] = true
	var steps := ceili(2.0 * PI * radius * 1.5)
	for i in steps:
		var a := (float(i) / steps) * PI * 2.0
		var dx := cos(a)
		var dy := sin(a)
		var x := origin.x + 0.5
		var y := origin.y + 0.5
		for d in radius:
			x += dx
			y += dy
			var tx := floori(x)
			var ty := floori(y)
			if not m.in_bounds(tx, ty):
				break
			visible[m.idx(tx, ty)] = true
			if m.blocks_sight(tx, ty):
				break
	return visible


## Sichtlinie zwischen zwei Punkten (Bresenham).
static func has_line_of_sight(m: FloorMap, a: Vector2i, b: Vector2i) -> bool:
	var x0 := a.x
	var y0 := a.y
	var dx := absi(b.x - x0)
	var dy := -absi(b.y - y0)
	var sx := 1 if x0 < b.x else -1
	var sy := 1 if y0 < b.y else -1
	var err := dx + dy
	while not (x0 == b.x and y0 == b.y):
		if not (x0 == a.x and y0 == a.y) and m.blocks_sight(x0, y0):
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return true


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
