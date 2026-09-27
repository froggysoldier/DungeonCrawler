class_name Fov
extends RefCounted
## Sichtfeld und Sichtlinie (Port von src/engine/fov.ts).


## Sichtfeld per Strahlenwurf. Gibt die sichtbaren Kachel-Indizes als Menge zurück.
static func compute(m: Dictionary, origin: Dictionary, radius: int) -> Dictionary:
	var visible := {}
	var width: int = m.width
	var height: int = m.height
	visible[int(origin.y) * width + int(origin.x)] = true
	var steps := ceili(2.0 * PI * radius * 1.5)
	for i in steps:
		var a := (float(i) / steps) * PI * 2.0
		var dx := cos(a)
		var dy := sin(a)
		var x: float = origin.x + 0.5
		var y: float = origin.y + 0.5
		for d in radius:
			x += dx
			y += dy
			var tx := floori(x)
			var ty := floori(y)
			if tx < 0 or ty < 0 or tx >= width or ty >= height:
				break
			var i2 := ty * width + tx
			visible[i2] = true
			var t: String = m.tiles[i2]
			if t == "wall" or t == "door":
				break
	return visible


## Sichtlinie zwischen zwei Punkten (Bresenham).
static func has_line_of_sight(m: Dictionary, a: Dictionary, b: Dictionary) -> bool:
	var x0: int = a.x
	var y0: int = a.y
	var bx: int = b.x
	var by: int = b.y
	var dx := absi(bx - x0)
	var dy := -absi(by - y0)
	var sx := 1 if x0 < bx else -1
	var sy := 1 if y0 < by else -1
	var err := dx + dy
	while not (x0 == bx and y0 == by):
		if not (x0 == a.x and y0 == a.y) and MapGen.blocks_sight(m, x0, y0):
			return false
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return true


static func chebyshev(a: Dictionary, b: Dictionary) -> int:
	return maxi(absi(int(a.x) - int(b.x)), absi(int(a.y) - int(b.y)))
