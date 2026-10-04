extends SceneTree
## Erzeugt die Pixel-Bögen in res://assets/pixel aus den Vorlagen in
## tools/pixel_defs.gd und aus prozeduralen Mustern (Böden, Wände, Türen).
##
##   godot --headless --path godot -s res://tools/make_pixel_art.gd -- [--force] [--preview ordner]
##
## Die PNG-Bögen sind danach die Quelle: Sie lassen sich in jedem Pixel-Editor
## bearbeiten. Deshalb überschreibt das Werkzeug vorhandene Bögen nur mit
## --force. --preview schreibt zusätzlich vergrößerte Vorschaubilder.

const Defs := preload("res://tools/pixel_defs.gd")
## Figuren im Tiny-Swords-Stil (feiner, 96 x 96, zwei Bildpixel je Kunstpixel).
const TsFig := preload("res://tools/ts_figures.gd")
const T := PixelArt.TILE
const COLS := 16

## Zeichen, die wie # schattiert werden: [Grund, dunkel, hell].
const SHADE := {
	"#": ["3", "2", "4"], "y": ["y", "U", "Y"], "d": ["d", "D", "U"], "b": ["b", "K", "B"],
	"n": ["n", "K", "N"], "g": ["g", "N", "G"], "L": ["L", "e", "l"], "R": ["R", "r", "f"],
}
## Zeichen ohne eigenen Umriss.
const NO_OUTLINE := "kKzvqjFO"
## Ersatzfarben für die Zeichen ohne Umriss.
const ALIAS := {"z": "2", "v": "g", "q": "f", "j": "S", "F": "Y", "O": "o"}

var errors := PackedStringArray()
## Bilder größer als eine Zelle, werden am Ende des Bogens abgelegt.
var _big: Array = []
## sheet -> Array von [name, Image]
var sheets := {}
## Bildpixel je Kunstpixel, nur für feine Figuren (Name -> 2).
var res := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var force := args.has("--force")
	var preview := ""
	var pi := args.find("--preview")
	if pi >= 0 and pi + 1 < args.size():
		preview = args[pi + 1]
	var out := ProjectSettings.globalize_path(PixelArt.DIR)
	if FileAccess.file_exists(out.path_join("index.json")) and not force:
		print("Bögen existieren schon (%s). Zum Überschreiben --force angeben." % out)
		quit(1)
		return
	_build_all()
	if not errors.is_empty():
		for e in errors:
			printerr("  " + e)
		print("%d Fehler in den Vorlagen, nichts geschrieben." % errors.size())
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var index := {}
	for sheet_name in sheets:
		var list: Array = sheets[sheet_name]
		var rows := ceili(list.size() / float(COLS))
		# Große Bilder zeilenweise unter die Zellen legen
		var big: Array = _big.filter(func(b): return b[0] == sheet_name)
		var places: Array = []
		var bx := 0
		var by := rows * T
		var shelf := 0
		for b in big:
			var bw := ceili(b[2].get_width() / float(T)) * T
			if bx + bw > COLS * T:
				bx = 0
				by += shelf
				shelf = 0
			places.append(Vector2i(bx, by))
			bx += bw
			shelf = maxi(shelf, ceili(b[2].get_height() / float(T)) * T)
		var img := Image.create(COLS * T, by + shelf if not big.is_empty() else rows * T, false, Image.FORMAT_RGBA8)
		for i in list.size():
			var sub: Image = list[i][1]
			var at := Vector2i((i % COLS) * T, (i / COLS) * T)
			img.blit_rect(sub, Rect2i(Vector2i.ZERO, sub.get_size()), at)
			index[list[i][0]] = _entry(list[i][0], sheet_name, at, sub)
		for bi in big.size():
			var sub: Image = big[bi][2]
			var at: Vector2i = places[bi]
			img.blit_rect(sub, Rect2i(Vector2i.ZERO, sub.get_size()), at)
			index[big[bi][1]] = _entry(big[bi][1], sheet_name, at, sub)
		img.save_png(out.path_join(sheet_name + ".png"))
		if preview != "":
			DirAccess.make_dir_recursive_absolute(preview)
			_preview(img, preview.path_join(sheet_name + ".png"))
	var f := FileAccess.open(out.path_join("index.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(index, " ", true) + "\n")
	f.close()
	print("%d Bilder in %d Bögen nach %s geschrieben." % [index.size(), sheets.size(), out])
	quit()


func _entry(name: String, sheet_name: String, at: Vector2i, sub: Image) -> Dictionary:
	var e := {"sheet": sheet_name, "x": at.x, "y": at.y, "w": sub.get_width(), "h": sub.get_height()}
	if res.has(name):
		e.res = res[name]
	return e


## Feine Figur aus tools/ts_figures.gd (mit zweitem Bild, falls vorhanden).
func _add_ts(sheet_name: String, prefix: String, name: String, frames: int) -> void:
	for f in frames:
		var full := prefix + name + ("_2" if f == 1 else "")
		res[full] = 2
		_add(sheet_name, full, TsFig.image(name, f))


func _add(sheet_name: String, name: String, img: Image) -> void:
	if not sheets.has(sheet_name):
		sheets[sheet_name] = []
	# Große Bilder belegen mehrere Zellen und kommen ans Ende des Bogens
	if img.get_width() > T or img.get_height() > T:
		_big.append([sheet_name, name, img])
		return
	sheets[sheet_name].append([name, img])


## Vergrößerte Vorschau auf Schachbrett, damit Durchsichtiges erkennbar bleibt.
func _preview(img: Image, path: String) -> void:
	var k := 6
	var big := Image.create(img.get_width() * k, img.get_height() * k, false, Image.FORMAT_RGBA8)
	for y in big.get_height():
		for x in big.get_width():
			var c := Color("#3a3f4a") if ((x / 8) + (y / 8)) % 2 == 0 else Color("#2e323b")
			big.set_pixel(x, y, c)
	var scaled := img.duplicate()
	# Tönbare Stellen in einer Beispielfarbe zeigen
	var cols := PixelArt.ramp(Color("#9a8466"))
	var keys: Array = PixelArt.TINT_KEYS.map(func(c): return Color(c))
	for y in scaled.get_height():
		for x in scaled.get_width():
			var p: Color = scaled.get_pixel(x, y)
			for i in keys.size():
				if p.a > 0.5 and p.is_equal_approx(keys[i]):
					scaled.set_pixel(x, y, cols[i])
	scaled.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	big.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i.ZERO)
	big.save_png(path)


# ================================================================ Vorlagen

static func _color_of(ch: String) -> Color:
	if ALIAS.has(ch):
		ch = ALIAS[ch]
	if ch >= "1" and ch <= "5" and ch.length() == 1:
		return Color(PixelArt.TINT_KEYS[int(ch) - 1])
	return Color(PixelArt.PALETTE[ch])


func _valid(ch: String) -> bool:
	return ch == "." or ch == "#" or ALIAS.has(ch) or PixelArt.PALETTE.has(ch) or (ch >= "1" and ch <= "5")


## Baut ein Bild aus Zeichenzeilen: Schattierung, dann Umriss.
func sprite(name: String, rows: Array, outline: bool = true, eyes: bool = false) -> Image:
	var h := rows.size()
	var w := String(rows[0]).length()
	var grid: Array = []
	for y in h:
		var row := String(rows[y])
		if row.length() != w:
			errors.append("%s: Zeile %d hat %d statt %d Zeichen" % [name, y, row.length(), w])
			row = row.rpad(w, ".").left(w)
		var line: Array = []
		for x in w:
			var ch := row[x]
			if not _valid(ch):
				errors.append("%s: unbekanntes Zeichen „%s“ in Zeile %d" % [name, ch, y])
				ch = "."
			line.append(ch)
		grid.append(line)
	# Vorlagen sind im groben Raster gezeichnet (16, Bosse 24, Figuren 20):
	# Scale2x glättet Schrägen, Größeres wird gleichmäßig auf 32 verkleinert
	grid = _shrink(_scale2x(grid), T)
	h = grid.size()
	w = (grid[0] as Array).size()
	var empty := func(x: int, y: int) -> bool:
		return x < 0 or y < 0 or x >= w or y >= h or grid[y][x] == "."
	var out: Array = []
	for y in h:
		var line: Array = []
		for x in w:
			var ch: String = grid[y][x]
			if SHADE.has(ch):
				var fam: Array = SHADE[ch]
				if empty.call(x, y + 1) or empty.call(x + 1, y):
					ch = fam[1]
				elif empty.call(x, y - 1) or empty.call(x - 1, y):
					ch = fam[2]
				elif (empty.call(x, y + 2) or empty.call(x + 2, y)) and (x + y) % 2 == 0 and y + 1 < h and grid[y + 1][x] == grid[y][x]:
					# Halbschatten: gerastert eine Reihe innerhalb der Schattenkante
					ch = fam[1]
				else:
					ch = fam[0]
			line.append(ch)
		out.append(line)
	if eyes:
		_glints(grid, out)
	# Umriss um alles außer den Zeichen ohne Umriss
	for y in (h if outline else 0):
		for x in w:
			if grid[y][x] != ".":
				continue
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n: String = grid[ny][nx]
				if n != "." and not NO_OUTLINE.contains(n):
					out[y][x] = "k"
					break
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var ch: String = out[y][x]
			if ch != ".":
				img.set_pixel(x, y, _color_of(ch))
	return img


func _build_all() -> void:
	var units := TsFig.units()
	for n in Defs.CREATURES:
		var base: String = n.trim_suffix("_2")
		if TsFig.CREATURES.has(base) or units.has(base):
			continue
		_add("kreaturen", "kreatur/" + n, sprite(n, Defs.CREATURES[n], true, true))
	for n in TsFig.CREATURES:
		_add_ts("kreaturen", "kreatur/", n, TsFig.frames(n))
	# Figuren aus dem Pack mit allen Ruhe- und Laufbildern
	for n in units:
		var c: Array = units[n]
		for i in c[0]:
			var full: String = "kreatur/" + n + ("" if i == 0 else "_%d" % (i + 1))
			res[full] = 2
			_add("einheiten", full, TsFig.unit_image(n, str(i)))
		for i in c[1]:
			var full: String = "kreatur/%s_lauf%d" % [n, i + 1]
			res[full] = 2
			_add("einheiten", full, TsFig.unit_image(n, "lauf%d" % i))
	for n in Defs.OVERLAYS:
		_add("kreaturen", "aufsatz/" + n, sprite(n, Defs.OVERLAYS[n]))
	for n in Defs.BOSSES:
		if TsFig.BOSSES.has(n) or Sprites.PACK_BOSSES.has(n):
			continue
		_add("bosse", "boss/" + n, _bottom(sprite(n, Defs.BOSSES[n], true, true), 2))
	for n in TsFig.BOSSES:
		_add_ts("bosse", "boss/", n, TsFig.frames(n))
	for n in Defs.MOUNTS:
		_add("kreaturen", "reittier/" + n, sprite(n, Defs.MOUNTS[n], true, true))
	# Die Spielfigur ist eine blaue Einheit aus dem Pack (siehe unten)
	_add("kreaturen", "aufsatz/schatten", _shadow(28, 10))
	_add("kreaturen", "aufsatz/schatten_klein", _shadow(20, 6))
	_add("kreaturen", "aufsatz/ring", _ring(32, 14))
	_add("kreaturen", "aufsatz/ring_gross", _ring(40, 18))
	_add("kreaturen", "aufsatz/leuchten", _glow(64))
	_add("kreaturen", "aufsatz/leuchten_klein", _glow(32))
	for n in Defs.ITEMS:
		_add("dinge", "ding/" + n, sprite(n, Defs.ITEMS[n]))
	for n in Defs.TRAPS:
		_add("dinge", "falle/" + n, sprite(n, Defs.TRAPS[n]))
	for n in Defs.FURNITURE:
		_add("einrichtung", "moebel/" + n, sprite(n, Defs.FURNITURE[n]))
	for v in 3:
		_add("einrichtung", "fleck/pfuetze%d" % v, _decal("pfuetze", v))
		_add("einrichtung", "fleck/riss%d" % v, _decal("riss", v))
		_add("einrichtung", "fleck/fleck%d" % v, _decal("fleck", v))
	for n in PROJECTILES:
		_add("dinge", "geschoss/" + n, _projectile(n))
	for mat in FLOORS:
		for v in 4:
			_add("kacheln", "boden/%s%d" % [mat, v], _floor(mat, v))
	for boss in [false, true]:
		for hor in [true, false]:
			for open in [false, true]:
				_add("kacheln", "tuer/%s_%s_%s" % ["boss" if boss else "holz", "quer" if hor else "laengs", "offen" if open else "zu"], _door(open, hor, boss))
	_add("kacheln", "treppe", _stairs())


## Zeichen, deren kleine, fast quadratische Flecken als Augen gelten.
const EYES := "kRYc"


## Augenglanz: kleine Flecken (2 bis 4 Pixel, fast quadratisch) aus einem
## Augenzeichen, rundum von anderer Farbe umgeben, bekommen oben links einen
## weißen Punkt.
static func _glints(grid: Array, out: Array) -> void:
	var h := grid.size()
	var w := (grid[0] as Array).size()
	var seen := {}
	for y in h:
		for x in w:
			var ch: String = grid[y][x]
			if not EYES.contains(ch) or seen.has(Vector2i(x, y)):
				continue
			var comp: Array = []
			var stack: Array = [Vector2i(x, y)]
			seen[Vector2i(x, y)] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				comp.append(p)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and not seen.has(q) and grid[q.y][q.x] == ch:
						seen[q] = true
						stack.append(q)
			var lo := Vector2i(w, h)
			var hi := Vector2i(-1, -1)
			for p in comp:
				lo = Vector2i(mini(lo.x, p.x), mini(lo.y, p.y))
				hi = Vector2i(maxi(hi.x, p.x), maxi(hi.y, p.y))
			var bw := hi.x - lo.x + 1
			var bh := hi.y - lo.y + 1
			if bw < 2 or bh < 2 or bw > 4 or bh > 4 or absi(bw - bh) > 1 or comp.size() < bw * bh - 2:
				continue
			var inside := true
			for p in comp:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = p + d
					if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or grid[q.y][q.x] == ".":
						inside = false
			if not inside:
				continue
			var tl: Vector2i = comp[0]
			for p in comp:
				if p.y < tl.y or (p.y == tl.y and p.x < tl.x):
					tl = p
			out[tl.y][tl.x] = "w"


## Scale2x (EPX) auf dem Zeichenraster: jede Zelle wird zu 2 × 2, Kanten
## zwischen gleichen Nachbarn werden schräg geglättet.
static func _scale2x(grid: Array) -> Array:
	var h := grid.size()
	var w := (grid[0] as Array).size()
	var at := func(x: int, y: int) -> String:
		return grid[y][x] if x >= 0 and y >= 0 and x < w and y < h else "."
	var out: Array = []
	for y in h * 2:
		var line: Array = []
		line.resize(w * 2)
		out.append(line)
	for y in h:
		for x in w:
			var p: String = grid[y][x]
			var a: String = at.call(x, y - 1)
			var b: String = at.call(x + 1, y)
			var c: String = at.call(x - 1, y)
			var d: String = at.call(x, y + 1)
			out[2 * y][2 * x] = a if c == a and c != d and a != b else p
			out[2 * y][2 * x + 1] = b if a == b and a != c and b != d else p
			out[2 * y + 1][2 * x] = c if d == c and d != b and c != a else p
			out[2 * y + 1][2 * x + 1] = d if b == d and b != a and d != c else p
	return out


## Spiegelgleich verteilte Zeilen/Spalten, die beim Verkleinern von n auf m wegfallen.
static func _drop_set(n: int, m: int) -> Dictionary:
	var k := n - m
	var out := {}
	if k <= 0:
		return out
	var step := float(n) / k
	for i in k / 2:
		var v := int(step / 2.0 + i * step)
		out[v] = true
		out[n - 1 - v] = true
	if k % 2 == 1:
		out[n / 2] = true
	return out


## Raster, das größer als size ist, gleichmäßig auf size verkleinern.
static func _shrink(grid: Array, size: int) -> Array:
	var h := grid.size()
	var w := (grid[0] as Array).size()
	if w <= size and h <= size:
		return grid
	var dx := _drop_set(w, mini(w, size))
	var dy := _drop_set(h, mini(h, size))
	var out: Array = []
	for y in h:
		if dy.has(y):
			continue
		var line: Array = []
		for x in w:
			if not dx.has(x):
				line.append(grid[y][x])
		out.append(line)
	return out


## Bild nach unten schieben, bis unten nur noch `margin` leere Zeilen bleiben.
func _bottom(img: Image, margin: int) -> Image:
	var used := img.get_used_rect()
	var shift := img.get_height() - margin - used.end.y
	if shift <= 0:
		return img
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.blit_rect(img, used, Vector2i(used.position.x, used.position.y + shift))
	return out


# ================================================================ Hilfen

var _rng := Rng.new(1)


func _r() -> float:
	return _rng.next()


func _ri(a: int, b: int) -> int:
	return a + floori(_r() * (b - a + 1))


static func _jit(c: Color, amount: float, r: float) -> Color:
	var f := 1.0 + (r * 2.0 - 1.0) * amount
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


static func _fill(img: Image, rect: Rect2i, c: Color) -> void:
	img.fill_rect(rect, c)


func _shadow(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
			var d := dx * dx + dy * dy
			if d <= 1.0:
				img.set_pixel(x, y, Color(0.02, 0.02, 0.05, 0.5 if d < 0.55 else 0.3))
	return img


func _ring(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var pts := {}
	var rx := (w - 1) / 2.0
	var ry := (h - 1) / 2.0
	for i in 720:
		var a := deg_to_rad(i / 2.0)
		pts[Vector2i(roundi(rx + cos(a) * rx), roundi(ry + sin(a) * ry))] = true
	for p in pts:
		if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
			img.set_pixelv(p, Color.WHITE)
	return img


## Gestuftes Leuchten (weiß, wird beim Zeichnen eingefärbt), mittig.
func _glow(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length() / r
			var a := 0.0
			if d < 0.38:
				a = 0.5
			elif d < 0.62:
				a = 0.34
			elif d < 0.82:
				a = 0.2
			elif d < 1.0:
				a = 0.09
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


func _decal(kind: String, v: int) -> Image:
	_rng = Rng.new(900 + v * 31 + kind.length())
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	match kind:
		"pfuetze":
			var cx := _ri(10, 21)
			var cy := _ri(10, 21)
			var rx := _ri(6, 10)
			var ry := _ri(4, 6)
			for y in T:
				for x in T:
					var d := pow((x - cx) / float(rx), 2) + pow((y - cy) / float(ry), 2)
					if d <= 1.0 + _r() * 0.12:
						img.set_pixel(x, y, Color(0.12, 0.17, 0.24, 0.55 if d > 0.5 else 0.62))
			# Spiegelung
			for i in 3:
				img.set_pixel(cx - 3 + i, cy - 2, Color(0.7, 0.8, 0.95, 0.35))
			img.set_pixel(cx - 4, cy - 1, Color(0.7, 0.8, 0.95, 0.25))
		"riss":
			var x := _ri(3, 9)
			var y := _ri(8, 23)
			while x < 28:
				img.set_pixel(x, y, Color(0, 0, 0, 0.55))
				x += 1
				if _r() < 0.35:
					y = clampi(y + (1 if _r() < 0.5 else -1), 2, 29)
					img.set_pixel(x, y, Color(0, 0, 0, 0.55))
				if _r() < 0.12:
					# Seitenast
					var bx := x
					var by := y
					for i in _ri(2, 4):
						bx += 1
						by += 1 if (v % 2 == 0) else -1
						img.set_pixel(clampi(bx, 0, T - 1), clampi(by, 0, T - 1), Color(0, 0, 0, 0.35))
		"fleck":
			var cx := _ri(10, 21)
			var cy := _ri(10, 21)
			for y in T:
				for x in T:
					var d := pow((x - cx) / 8.0, 2) + pow((y - cy) / 5.2, 2)
					if d <= 1.0 and _r() < 0.9:
						img.set_pixel(x, y, Color(0.05, 0.03, 0.02, 0.3 if d > 0.4 else 0.38))
	return img


const PROJECTILES := {
	"stein": ["#c8c0b0", 6], "schleim": ["#8ce04a", 6], "bombe": ["#3a3a44", 8],
	"magie": ["#c080ff", 10], "feuer": ["#ff8a2a", 10], "blitz": ["#9fdcff", 10],
}


func _projectile(n: String) -> Image:
	var col := Color(PROJECTILES[n][0])
	var s: int = PROJECTILES[n][1]
	var img := Image.create(s + 2, s + 2, false, Image.FORMAT_RGBA8)
	var c := (s + 2) / 2.0
	var glow := n in ["magie", "feuer", "blitz"]
	for y in s + 2:
		for x in s + 2:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
			if d <= s / 2.0:
				var cc := col
				if glow and d < s / 4.0:
					cc = Color.WHITE
				elif d < s / 2.0 - 1.0 and x < c and y < c:
					cc = col.lightened(0.25)
				elif d >= s / 2.0 - 1.0 and (x >= c or y >= c):
					cc = col.darkened(0.25)
				img.set_pixel(x, y, cc)
			elif d <= s / 2.0 + 1.0:
				img.set_pixel(x, y, Color(PixelArt.PALETTE.k))
	if n == "bombe":
		img.set_pixel(s, 0, Color("#feae34"))
		img.set_pixel(s - 1, 1, Color("#8a7c6a"))
	return img


# ================================================================ Böden (32 × 32)

const FLOORS := {
	"pflaster": {"base": "#5d5449", "gap": "#2b2520"},
	"dielen": {"base": "#6b4a2e", "gap": "#33221a"},
	"fliesen": {"base": "#6f7c80", "gap": "#3a4146"},
	"beton": {"base": "#595b5c", "gap": "#3e4042"},
	"ziegelboden": {"base": "#73402d", "gap": "#37231b"},
	"teppich": {"base": "#6a2332", "gap": "#3e1320", "trim": "#b8863a"},
	"marmor": {"base": "#aba597", "gap": "#8a8478", "vein": "#7d776c"},
	"blutstein": {"base": "#3f1f22", "gap": "#1d0d10", "vein": "#8a2a2a"},
	"arena": {"base": "#8a7350", "gap": "#6c5a3e"},
	# Gelände (Dungeon.WATER, Dungeon.MUD): kacheln nahtlos
	"wasser": {"base": "#2c5878", "gap": "#1c3a52"},
	"schlamm": {"base": "#4f3d2a", "gap": "#33271b"},
	# Kanalstadt (Kanalstadt.CANAL, Kanalstadt.BRIDGE)
	"kanal": {"base": "#16383a", "gap": "#081a1e"},
	"bruecke": {"base": "#7a5a3a", "gap": "#2c1e14"},
	"bruecke_quer": {"base": "#7a5a3a", "gap": "#2c1e14"},
	# Tiefgaragen (Tiefgarage.OIL): schwarzes Öl auf Beton mit buntem Schimmer
	"oel": {"base": "#1c1c22", "gap": "#595b5c"},
}


## Ein Stein, eine Platte oder ein Ziegel mit heller Ober- und Links-, dunkler
## Unter- und Rechtskante und leicht gesprenkelter Fläche.
func _block(img: Image, x0: int, y0: int, w: int, h: int, col: Color, speck: float = 0.06) -> void:
	for yy in range(y0, y0 + h):
		for xx in range(x0, x0 + w):
			if xx < 0 or yy < 0 or xx >= T or yy >= T:
				continue
			var c := _jit(col, speck, _r())
			if yy == y0 or xx == x0:
				c = col.lightened(0.14)
			elif yy == y0 + h - 1 or xx == x0 + w - 1:
				c = col.darkened(0.18)
			img.set_pixel(xx, yy, c)


func _floor(mat: String, v: int) -> Image:
	_rng = Rng.new(100 + v * 17 + mat.length() * 101)
	var spec: Dictionary = FLOORS[mat]
	var base := Color(spec.base)
	var gap := Color(spec.gap)
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	img.fill(gap)
	match mat:
		"pflaster":
			# Unregelmäßige Steine in versetzten Reihen, 1 Pixel Fuge
			var y := 0
			var row := 0
			while y < T:
				var hgt := _ri(7, 9) if y + 9 <= T else T - y
				var x := -(row % 2) * _ri(4, 7)
				while x < T:
					var wd := _ri(8, 13)
					_block(img, x, y, wd - 1, hgt - 1, _jit(base, 0.12, _r()), 0.05)
					x += wd
				y += hgt
				row += 1
		"dielen":
			for p in 4:
				var y0 := p * 8
				var col := _jit(base, 0.08, _r())
				var cut := _ri(6, 25)
				for yy in range(y0, y0 + 7):
					for xx in T:
						var c := col
						if yy == y0:
							c = col.lightened(0.1)
						elif yy == y0 + 6:
							c = col.darkened(0.12)
						img.set_pixel(xx, yy, _jit(c, 0.03, _r()))
				# Maserung: lange, dunkle Striche
				for g in 3:
					var gy := y0 + _ri(1, 5)
					var gx := _ri(0, T - 1)
					for i in _ri(5, 11):
						img.set_pixel((gx + i) % T, gy, col.darkened(0.16))
				# Stoß und Nägel
				for yy in range(y0, y0 + 7):
					img.set_pixel(cut, yy, gap)
				for nx in [(cut + 2) % T, (cut + 16) % T]:
					img.set_pixel(nx, y0 + 2, Color("#9a958a"))
					img.set_pixel(nx, y0 + 4, Color("#6a655c"))
		"fliesen":
			for ty in 2:
				for tx in 2:
					var col := base if (tx + ty) % 2 == 0 else base.darkened(0.08)
					_block(img, tx * 16, ty * 16, 15, 15, _jit(col, 0.03, _r()), 0.02)
					img.set_pixel(tx * 16 + 2, ty * 16 + 2, col.lightened(0.28))
					img.set_pixel(tx * 16 + 3, ty * 16 + 2, col.lightened(0.18))
					img.set_pixel(tx * 16 + 2, ty * 16 + 3, col.lightened(0.18))
		"beton", "arena":
			for yy in T:
				for xx in T:
					img.set_pixel(xx, yy, _jit(base, 0.05, _r()))
			for i in 26:
				var c := base.darkened(0.18) if _r() < 0.6 else base.lightened(0.12)
				var qx := _ri(0, T - 1)
				var qy := _ri(0, T - 1)
				img.set_pixel(qx, qy, c)
				if _r() < 0.3:
					img.set_pixel(mini(qx + 1, T - 1), qy, c)
			if mat == "beton":
				# Fugen der Platten
				for i in T:
					img.set_pixel(i, 0, gap)
					img.set_pixel(0, i, gap)
					img.set_pixel(i, 1, base.lightened(0.08))
					img.set_pixel(1, i, base.lightened(0.08))
			else:
				# Sand mit Kieseln
				for i in 6:
					var qx := _ri(2, 28)
					var qy := _ri(2, 28)
					img.set_pixel(qx, qy, Color("#b09a74"))
					img.set_pixel(qx + 1, qy, Color("#9a8460"))
					img.set_pixel(qx, qy + 1, Color("#6c5a3e"))
					img.set_pixel(qx + 1, qy + 1, Color("#5a4a32"))
		"ziegelboden":
			for r in 4:
				var y0 := r * 8
				var off := 8 if r % 2 == 1 else 0
				for b in 3:
					_block(img, b * 16 - off, y0, 15, 7, _jit(base, 0.1, _r()), 0.05)
		"teppich":
			for yy in T:
				for xx in T:
					var c := _jit(base, 0.04, _r())
					# feine Webstruktur
					if (xx + yy) % 4 == 0:
						c = c.darkened(0.06)
					img.set_pixel(xx, yy, c)
			var trim := Color(spec.trim)
			# Raute mit Füllung
			for i in 9:
				for q in [Vector2i(15 - i, 6 + i), Vector2i(16 + i, 6 + i), Vector2i(7 + i, 15 + i), Vector2i(24 - i, 15 + i)]:
					img.set_pixelv(q, trim.darkened(0.2))
			for i in 5:
				for q in [Vector2i(15 - i, 11 + i), Vector2i(16 + i, 11 + i), Vector2i(11 + i, 16 + i), Vector2i(20 - i, 16 + i)]:
					img.set_pixelv(q, trim.darkened(0.45))
			for q in [Vector2i(15, 15), Vector2i(16, 15), Vector2i(15, 16), Vector2i(16, 16)]:
				img.set_pixelv(q, trim)
		"marmor":
			for yy in T:
				for xx in T:
					img.set_pixel(xx, yy, _jit(base, 0.025, _r()))
			var vein := Color(spec.vein)
			for n in 2:
				var x := _ri(0, 12)
				var y := _ri(0, T - 1)
				for i in 30:
					img.set_pixel(clampi(x, 0, T - 1), clampi(y, 0, T - 1), vein if n == 0 else vein.lightened(0.15))
					x += 1
					if _r() < 0.5:
						y += _ri(-1, 1)
			for i in T:
				img.set_pixel(i, T - 1, gap)
				img.set_pixel(T - 1, i, gap)
		"blutstein":
			for ty in 2:
				for tx in 2:
					_block(img, tx * 16, ty * 16, 15, 15, _jit(base, 0.1, _r()), 0.08)
			if v % 2 == 0:
				var x := _ri(4, 16)
				var y := _ri(6, 24)
				var vein := Color(spec.vein)
				for i in 11:
					img.set_pixel(x + i, y, vein)
					if i % 2 == 1:
						y += 1 if _r() < 0.7 else 0
					if i % 3 == 0:
						img.set_pixel(x + i, y + 1, vein.darkened(0.3))
		"wasser":
			# Tiefes Blau mit waagerechten Wellen, nahtlos an den Rändern
			for yy in T:
				for xx in T:
					var w := sin((xx + v * 5) * TAU / 16.0 + yy * 0.9) * 0.5 + 0.5
					var c := base.lerp(gap, 0.35 * (1.0 - w))
					img.set_pixel(xx, yy, _jit(c, 0.02, _r()))
			for n in 4:
				var y := (n * 8 + _ri(1, 6)) % T
				var x := _ri(0, T - 1)
				for i in _ri(4, 8):
					img.set_pixel((x + i) % T, y, base.lightened(0.25))
					if i > 0 and i < 3:
						img.set_pixel((x + i) % T, (y + 1) % T, base.lightened(0.1))
		"oel":
			# Betonrand, darauf eine glänzende schwarze Lache mit Regenbogenschlieren
			for yy in T:
				for xx in T:
					img.set_pixel(xx, yy, _jit(gap, 0.05, _r()))
			var cx := 16.0 + _ri(-2, 2)
			var cy := 16.0 + _ri(-2, 2)
			for yy in T:
				for xx in T:
					var dx := (xx - cx) / (13.0 + v)
					var dy := (yy - cy) / (11.0 + (3 - v))
					var wob := sin(xx * 0.7 + v) * 0.08 + cos(yy * 0.5 + v * 2) * 0.08
					if dx * dx + dy * dy <= 1.0 + wob:
						img.set_pixel(xx, yy, _jit(base, 0.04, _r()))
			var sheen := [Color("#5a3a7a"), Color("#2a6a6a"), Color("#7a6a2a"), Color("#3a4a8a")]
			for n in 3:
				var y := int(cy) - 6 + n * 5
				var x := int(cx) - 7 + _ri(0, 4)
				for i in _ri(5, 9):
					if img.get_pixel(clampi(x + i, 0, T - 1), y) .r < 0.2:
						img.set_pixel(clampi(x + i, 0, T - 1), y, sheen[(n + i / 3) % sheen.size()])
			img.set_pixel(int(cx) - 4, int(cy) - 5, Color("#d0d0e0"))
			img.set_pixel(int(cx) - 3, int(cy) - 5, Color("#8a8aa0"))
		"kanal":
			# Tiefes, dunkles Wasser mit trägen Schlieren, nahtlos
			for yy in T:
				for xx in T:
					var w := sin((xx + v * 7) * TAU / 32.0 + yy * 0.45) * 0.5 + 0.5
					img.set_pixel(xx, yy, _jit(base.lerp(gap, 0.5 * (1.0 - w)), 0.02, _r()))
			for n in 3:
				var y := (n * 11 + _ri(0, 8)) % T
				var x := _ri(0, T - 1)
				for i in _ri(6, 12):
					img.set_pixel((x + i) % T, y, base.lightened(0.18))
			if v == 3:
				# Treibgut
				var tx := _ri(6, 22)
				var ty := _ri(8, 22)
				for i in 5:
					img.set_pixel(tx + i, ty, Color("#6a5a3a"))
					img.set_pixel(tx + i, ty + 1, Color("#4a3a26"))
		"bruecke", "bruecke_quer":
			# Planken über Wasser; Geländer an den Seiten (längs: links und rechts)
			var water := Color("#1c3a4a")
			img.fill(water)
			for p in 8:
				var col := _jit(base, 0.1, _r())
				for i in T:
					for k in 3:
						var a := p * 4 + k
						var c := col if k < 2 else gap
						if k == 0:
							c = col.lightened(0.12)
						if i < 3 or i > 28:
							continue
						if mat == "bruecke":
							img.set_pixel(i, a, c)
						else:
							img.set_pixel(a, i, c)
			for i in T:
				for k in 2:
					var rail := Color("#4a3422") if k == 0 else Color("#6a4c30")
					if mat == "bruecke":
						img.set_pixel(1 + k, i, rail)
						img.set_pixel(29 + k, i, rail)
					else:
						img.set_pixel(i, 1 + k, rail)
						img.set_pixel(i, 29 + k, rail)
		"schlamm":
			# Braune Masse mit dunklen Mulden, nassem Glanz und Blasen
			for yy in T:
				for xx in T:
					img.set_pixel(xx, yy, _jit(base, 0.06, _r()))
			for n in 5:
				var cx := _ri(3, 28)
				var cy := _ri(3, 28)
				var rr := _ri(2, 4)
				for yy in range(cy - rr, cy + rr + 1):
					for xx in range(cx - rr - 1, cx + rr + 2):
						var dx := (xx - cx) / (rr + 1.0)
						var dy := float(yy - cy) / rr
						if dx * dx + dy * dy <= 1.0:
							img.set_pixel(posmod(xx, T), posmod(yy, T), _jit(gap, 0.05, _r()))
				img.set_pixel(posmod(cx - 1, T), posmod(cy - rr, T), base.lightened(0.18))
			for n in 3:
				var bx := _ri(2, 29)
				var by := _ri(2, 29)
				img.set_pixel(bx, by, base.lightened(0.35))
				img.set_pixel(bx + 1, by, base.lightened(0.15))
				img.set_pixel(bx, by + 1, gap.darkened(0.2))
	return img


# ================================================================ Türen, Treppe (32 × 32)
# Wände kommen aus dem Tiny-Swords-Pack (tools/import_tinyswords.gd).

func _door(open: bool, horizontal: bool, boss: bool) -> Image:
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var k := Color(PixelArt.PALETTE.k)
	var wood := Color("#8a5a32") if not boss else Color("#5a6988")
	var wood_d := Color("#5e3a20") if not boss else Color("#3a4466")
	var band := Color("#3a4466") if not boss else Color("#a22633")
	var frame := Color("#6e6254")
	var frame_d := Color("#3e3730")
	if horizontal:
		# Tür in einer waagerechten Wand: Vorderansicht
		img.fill(frame_d)
		for yy in T:
			for xx in [0, 1, 2, 3]:
				img.set_pixel(xx, yy, frame if xx < 3 else frame_d)
			for xx in [28, 29, 30, 31]:
				img.set_pixel(xx, yy, frame_d.darkened(0.2))
		for xx in T:
			img.set_pixel(xx, 0, frame.lightened(0.15))
			for yy in [1, 2, 3]:
				img.set_pixel(xx, yy, frame)
		if open:
			for yy in range(4, T):
				for xx in range(4, 28):
					img.set_pixel(xx, yy, k if yy < 16 else Color("#1e1a24"))
			for yy in range(4, T):
				for xx in [4, 5]:
					img.set_pixel(xx, yy, wood)
				for xx in [6, 7]:
					img.set_pixel(xx, yy, wood_d)
			return img
		for yy in range(4, T):
			for xx in range(4, 28):
				var col := wood if (xx - 4) % 8 != 7 else wood_d
				if (xx - 4) % 8 == 0:
					col = wood.lightened(0.1)
				img.set_pixel(xx, yy, _jit(col, 0.03, _r()))
		for yy in [10, 11, 24, 25]:
			for xx in range(4, 28):
				img.set_pixel(xx, yy, band if yy % 2 == 0 else band.darkened(0.3))
		for q in [Vector2i(22, 18), Vector2i(23, 18), Vector2i(22, 19), Vector2i(23, 19)]:
			img.set_pixelv(q, Color("#feae34"))
		img.set_pixel(22, 20, Color("#be4a2f"))
		img.set_pixel(23, 20, Color("#be4a2f"))
		if boss:
			for p in [Vector2i(8, 10), Vector2i(16, 10), Vector2i(24, 10), Vector2i(8, 24), Vector2i(16, 24), Vector2i(24, 24)]:
				img.set_pixelv(p, Color("#e43b44"))
				img.set_pixel(p.x + 1, p.y, Color("#e43b44"))
				img.set_pixel(p.x, p.y + 1, Color("#a22633"))
				img.set_pixel(p.x + 1, p.y + 1, Color("#a22633"))
		return img
	# Tür in einer senkrechten Wand: von oben als schmale Platte
	for xx in T:
		for yy in [0, 1, 2, 3, 28, 29, 30, 31]:
			img.set_pixel(xx, yy, frame if yy < 16 else frame_d)
	if open:
		for xx in range(6, 26):
			for yy in [4, 5]:
				img.set_pixel(xx, yy, k)
			for yy in [6, 7]:
				img.set_pixel(xx, yy, wood)
			for yy in [8, 9]:
				img.set_pixel(xx, yy, wood_d)
			for yy in [10, 11]:
				img.set_pixel(xx, yy, k)
		return img
	for yy in range(4, 28):
		for xx in [10, 11]:
			img.set_pixel(xx, yy, k)
		img.set_pixel(12, yy, wood.lightened(0.15))
		img.set_pixel(13, yy, wood.lightened(0.05))
		for xx in [14, 15, 16, 17]:
			img.set_pixel(xx, yy, wood)
		img.set_pixel(18, yy, wood_d)
		img.set_pixel(19, yy, wood_d)
		for xx in [20, 21]:
			img.set_pixel(xx, yy, k)
	for yy in [8, 9, 22, 23]:
		for xx in range(12, 20):
			img.set_pixel(xx, yy, band)
	return img


func _stairs() -> Image:
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var k := Color(PixelArt.PALETTE.k)
	img.fill(Color("#6e6254"))
	for i in T:
		for j in 2:
			img.set_pixel(i, j, Color("#8a7c6a"))
			img.set_pixel(j, i, Color("#8a7c6a"))
			img.set_pixel(i, T - 1 - j, Color("#3e3730"))
			img.set_pixel(T - 1 - j, i, Color("#3e3730"))
	for yy in range(4, 30):
		for xx in range(4, 28):
			img.set_pixel(xx, yy, k)
	# Stufen, nach unten dunkler und schmaler
	for st in 5:
		var y := 4 + st * 6
		var inset := st * 2
		var light := 0.78 - st * 0.14
		var col := Color(light, light * 0.84, light * 0.62)
		for xx in range(4 + inset, 28 - inset):
			img.set_pixel(xx, y, col.lightened(0.3))
			img.set_pixel(xx, y + 1, col.lightened(0.1))
			img.set_pixel(xx, y + 2, col)
			img.set_pixel(xx, y + 3, col.darkened(0.25))
	# Goldene Geländer
	for yy in range(4, 30):
		var inset := (yy - 4) / 3
		for d in 2:
			img.set_pixel(2 + inset + d, yy, Color("#d9ae52") if d == 0 else Color("#a07c30"))
			img.set_pixel(29 - inset - d, yy, Color("#d9ae52") if d == 0 else Color("#a07c30"))
	return img
