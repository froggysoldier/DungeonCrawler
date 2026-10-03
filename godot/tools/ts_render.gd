extends RefCounted
## Zeichnet Figuren im Stil von Tiny Swords (Pixel Frog) aus einfachen Formen:
## runde, gedrungene Körper, außen ein dicker Umriss in Nachtblau, innen feine
## Linien zwischen den Teilen, jede Form mit Licht oben links und Schatten
## unten rechts in drei Stufen. Das Bild ist 96 x 96 Pixel groß (zwei Pixel je
## Kunstpixel der übrigen Grafik), die Füße stehen auf Zeile FOOT.
##
## Formen (Koordinaten in Bildpixeln):
##   ["e", cx, cy, rx, ry, farbe, flags]          Ellipse
##   ["r", x, y, w, h, rundung, farbe, flags]     Rechteck mit runden Ecken
##   ["p", [x0, y0, x1, y1, ...], farbe, flags]   Vieleck
##   ["l", x0, y0, x1, y1, dicke, farbe, flags]   Strich mit runden Enden (Beine, Arme, Schwanz)
## Details ohne Umriss und Schattierung, nach dem Umriss gezeichnet:
##   ["d", x, y, r, farbe]                         Punkt
##   ["dl", x0, y0, x1, y1, farbe]                 Linie, ein Pixel breit
##   ["eye", x, y]                                 kleines dunkles Auge mit Glanzpunkt
##   ["eyeb", x, y, r, iris]                       großes rundes Auge mit Pupille
## Flags: "f" flach (keine Schattierung), "n" keine Linie zu Formen darunter,
##        "o" kein äußerer Umriss (Glühen, Flammen).
## Farben: Zeichen der Palette (PixelArt.PALETTE), "#rrggbb", "T" Tönfarbe,
##        "t" dunkle Tönfarbe, "TL" helle Tönfarbe.

const SIZE := 96
const FOOT := 89
const NAVY := Color("#161c2e")
const CREAM := Color("#fff4d0")
## Licht von oben links.
const LIGHT := Vector2(-0.55, -0.83)


static func _col(c: String) -> Color:
	if c.begins_with("#"):
		return Color(c)
	return Color(PixelArt.PALETTE.get(c, "#ff00ff"))


## Drei Töne (Schatten, Grund, Licht) einer Farbe; Tönfarben als Magenta-Stufen.
static func _tones(c: String) -> Array:
	var keys: Array = PixelArt.TINT_KEYS.map(func(k): return Color(k))
	match c:
		"T":
			return [keys[1], keys[2], keys[3]]
		"t":
			return [keys[0], keys[1], keys[2]]
		"TL":
			return [keys[2], keys[3], keys[4]]
	var b := _col(c)
	return [b.lerp(NAVY, 0.34), b, b.lerp(CREAM, 0.3)]


static func _inside(s: Array, x: float, y: float) -> bool:
	match s[0]:
		"e":
			var dx: float = (x - s[1]) / maxf(0.5, s[3])
			var dy: float = (y - s[2]) / maxf(0.5, s[4])
			return dx * dx + dy * dy <= 1.0
		"r":
			var rx: float = s[1]
			var ry: float = s[2]
			var rw: float = s[3]
			var rh: float = s[4]
			var rad: float = minf(s[5], minf(rw, rh) / 2.0)
			if x < rx or y < ry or x > rx + rw or y > ry + rh:
				return false
			var cx := clampf(x, rx + rad, rx + rw - rad)
			var cy := clampf(y, ry + rad, ry + rh - rad)
			return Vector2(x - cx, y - cy).length() <= rad + 0.01
		"p":
			var pts: Array = s[1]
			var n := pts.size() / 2
			var c := false
			var j := n - 1
			for i in n:
				var xi: float = pts[2 * i]
				var yi: float = pts[2 * i + 1]
				var xj: float = pts[2 * j]
				var yj: float = pts[2 * j + 1]
				if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
					c = not c
				j = i
			return c
		"l":
			var a := Vector2(s[1], s[2])
			var b := Vector2(s[3], s[4])
			var p := Vector2(x, y)
			var ab := b - a
			var t := 0.0 if ab.length_squared() == 0 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			return p.distance_to(a + ab * t) <= s[5] / 2.0
	return false


static func _color_arg(s: Array) -> String:
	match s[0]:
		"e": return s[5]
		"r": return s[6]
		"p": return s[2]
		"l": return s[6]
	return "k"


static func _flags(s: Array) -> String:
	var i: int = {"e": 6, "r": 7, "p": 3, "l": 7}.get(s[0], 99)
	return String(s[i]) if s.size() > i else ""


## Mittelpunkt und halbe Ausdehnung einer Form (für die Lichtrichtung).
static func _frame(s: Array) -> Rect2:
	match s[0]:
		"e":
			return Rect2(s[1] - s[3], s[2] - s[4], s[3] * 2, s[4] * 2)
		"r":
			return Rect2(s[1], s[2], s[3], s[4])
		"p":
			var pts: Array = s[1]
			var r := Rect2(pts[0], pts[1], 0, 0)
			for i in pts.size() / 2:
				r = r.expand(Vector2(pts[2 * i], pts[2 * i + 1]))
			return r
		"l":
			var half: float = s[5] / 2.0
			return Rect2(minf(s[1], s[3]) - half, minf(s[2], s[4]) - half, absf(s[3] - s[1]) + s[5], absf(s[4] - s[2]) + s[5])
	return Rect2()


static func render(shapes: Array) -> Image:
	var n := SIZE
	var owner := PackedInt32Array()
	owner.resize(n * n)
	owner.fill(-1)
	var bodies: Array = shapes.filter(func(s): return s[0] in ["e", "r", "p", "l"])
	for si in bodies.size():
		var s: Array = bodies[si]
		var fr := _frame(s).grow(1)
		for y in range(maxi(0, floori(fr.position.y)), mini(n, ceili(fr.end.y) + 1)):
			for x in range(maxi(0, floori(fr.position.x)), mini(n, ceili(fr.end.x) + 1)):
				if _inside(s, x + 0.5, y + 0.5):
					owner[y * n + x] = si
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	# Flächen mit drei Tönen
	for y in n:
		for x in n:
			var si := owner[y * n + x]
			if si < 0:
				continue
			var s: Array = bodies[si]
			var tones := _tones(_color_arg(s))
			var tone := 1
			if not _flags(s).contains("f"):
				var fr := _frame(s)
				var c := fr.get_center()
				var nrm := Vector2((x + 0.5 - c.x) / maxf(1.0, fr.size.x / 2.0), (y + 0.5 - c.y) / maxf(1.0, fr.size.y / 2.0))
				var lit := nrm.dot(LIGHT)
				if lit > 0.42:
					tone = 2
				elif lit < -0.38 or nrm.y > 0.62:
					tone = 0
			img.set_pixel(x, y, tones[tone])
	# Feine Linien, wo eine Form über einer anderen liegt
	var out := img.duplicate()
	for y in n:
		for x in n:
			var si := owner[y * n + x]
			if si < 0 or _flags(bodies[si]).contains("n"):
				continue
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= n or ny >= n:
					continue
				var o := owner[ny * n + nx]
				if o >= 0 and o < si and _color_arg(bodies[o]) != _color_arg(bodies[si]):
					out.set_pixel(x, y, NAVY)
					break
	# Dicker Umriss außen: ein Ring über Ecken, ein zweiter über Kanten
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < n and y < n and owner[y * n + x] >= 0 and not _flags(bodies[owner[y * n + x]]).contains("o")
	var ring := PackedByteArray()
	ring.resize(n * n)
	for y in n:
		for x in n:
			if owner[y * n + x] >= 0:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if solid.call(x + dx, y + dy):
						ring[y * n + x] = 1
	for y in n:
		for x in n:
			if owner[y * n + x] >= 0:
				continue
			var hit := ring[y * n + x] == 1
			if not hit:
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var nx: int = x + d[0]
					var ny: int = y + d[1]
					if nx >= 0 and ny >= 0 and nx < n and ny < n and ring[ny * n + nx] == 1:
						hit = true
			if hit:
				out.set_pixel(x, y, NAVY)
	# Details
	for s in shapes:
		match s[0]:
			"d":
				var r: float = s[3]
				for y in range(floori(s[2] - r), ceili(s[2] + r) + 1):
					for x in range(floori(s[1] - r), ceili(s[1] + r) + 1):
						if Vector2(x + 0.5 - s[1], y + 0.5 - s[2]).length() <= r + 0.01 and x >= 0 and y >= 0 and x < n and y < n:
							out.set_pixel(x, y, _tones(s[4])[1])
			"dl":
				var a := Vector2(s[1], s[2])
				var b := Vector2(s[3], s[4])
				var steps := maxi(1, ceili(a.distance_to(b)))
				for i in steps + 1:
					var p := a.lerp(b, float(i) / steps).floor()
					if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
						out.set_pixel(int(p.x), int(p.y), _tones(s[5])[1])
			"eye":
				var ex: int = s[1]
				var ey: int = s[2]
				for p in [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2], [1, 2]]:
					out.set_pixel(ex + p[0], ey + p[1], NAVY)
				out.set_pixel(ex, ey, Color("#f6f2e1"))
			"eyeb":
				var r2: float = s[3]
				for y in range(floori(s[2] - r2 - 1), ceili(s[2] + r2) + 2):
					for x in range(floori(s[1] - r2 - 1), ceili(s[1] + r2) + 2):
						var dd := Vector2(x + 0.5 - s[1], y + 0.5 - s[2]).length()
						if dd <= r2 + 1.0:
							out.set_pixel(x, y, NAVY if dd > r2 else Color("#f6f2e1"))
				var iris: Color = _tones(s[4] if s.size() > 4 else "k")[1]
				var pr := maxf(1.0, r2 * 0.55)
				for y in range(floori(s[2] - pr), ceili(s[2] + pr) + 1):
					for x in range(floori(s[1] - pr + 1), ceili(s[1] + pr + 1) + 1):
						if Vector2(x + 0.5 - (s[1] + 1), y + 0.5 - s[2]).length() <= pr:
							out.set_pixel(x, y, iris)
	return out
