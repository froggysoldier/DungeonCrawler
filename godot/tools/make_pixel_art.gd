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
const T := PixelArt.TILE
const COLS := 16

## Zeichen, die wie # schattiert werden: [Grund, dunkel, hell].
const SHADE := {
	"#": ["3", "2", "4"], "y": ["y", "U", "Y"], "d": ["d", "D", "U"], "b": ["b", "K", "B"],
	"n": ["n", "K", "N"], "g": ["g", "N", "G"], "L": ["L", "e", "l"], "R": ["R", "r", "f"],
}
## Zeichen ohne eigenen Umriss.
const NO_OUTLINE := "kKzvqj"
## Ersatzfarben für die Zeichen ohne Umriss.
const ALIAS := {"z": "2", "v": "g", "q": "f", "j": "S"}

var errors := PackedStringArray()
## Bilder größer als eine Zelle, werden am Ende des Bogens abgelegt.
var _big: Array = []
## sheet -> Array von [name, Image]
var sheets := {}


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
		var big: Array = _big.filter(func(b): return b[0] == sheet_name)
		var big_h := 0
		for b in big:
			big_h = maxi(big_h, b[2].get_height())
		var img := Image.create(COLS * T, rows * T + ceili(big_h / float(T)) * T, false, Image.FORMAT_RGBA8)
		for i in list.size():
			var sub: Image = list[i][1]
			var at := Vector2i((i % COLS) * T, (i / COLS) * T)
			img.blit_rect(sub, Rect2i(Vector2i.ZERO, sub.get_size()), at)
			index[list[i][0]] = {"sheet": sheet_name, "x": at.x, "y": at.y, "w": sub.get_width(), "h": sub.get_height()}
		var bx := 0
		for b in big:
			var sub: Image = b[2]
			var at := Vector2i(bx, rows * T)
			img.blit_rect(sub, Rect2i(Vector2i.ZERO, sub.get_size()), at)
			index[b[1]] = {"sheet": sheet_name, "x": at.x, "y": at.y, "w": sub.get_width(), "h": sub.get_height()}
			bx += ceili(sub.get_width() / float(T)) * T
		img.save_png(out.path_join(sheet_name + ".png"))
		if preview != "":
			DirAccess.make_dir_recursive_absolute(preview)
			_preview(img, preview.path_join(sheet_name + ".png"))
	var f := FileAccess.open(out.path_join("index.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(index, " ", true) + "\n")
	f.close()
	print("%d Bilder in %d Bögen nach %s geschrieben." % [index.size(), sheets.size(), out])
	quit()


func _add(sheet_name: String, name: String, img: Image) -> void:
	# Große Bilder belegen mehrere Zellen: vorher auf eine neue Zeile gehen
	if img.get_width() > T or img.get_height() > T:
		_big.append([sheet_name, name, img])
		return
	if not sheets.has(sheet_name):
		sheets[sheet_name] = []
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
func sprite(name: String, rows: Array) -> Image:
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
				else:
					ch = fam[0]
			line.append(ch)
		out.append(line)
	# Umriss um alles außer den Zeichen ohne Umriss
	for y in h:
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
	for n in Defs.CREATURES:
		_add("kreaturen", "kreatur/" + n, sprite(n, Defs.CREATURES[n]))
	for n in Defs.OVERLAYS:
		_add("kreaturen", "aufsatz/" + n, sprite(n, Defs.OVERLAYS[n]))
	for n in Defs.MOUNTS:
		_add("kreaturen", "reittier/" + n, sprite(n, Defs.MOUNTS[n]))
	_add("kreaturen", "aufsatz/schatten", _shadow(14, 5))
	_add("kreaturen", "aufsatz/schatten_klein", _shadow(10, 3))
	_add("kreaturen", "aufsatz/ring", _ring(16, 7))
	_add("kreaturen", "aufsatz/ring_gross", _ring(20, 9))
	_add("kreaturen", "aufsatz/leuchten", _glow(32))
	_add("kreaturen", "aufsatz/leuchten_klein", _glow(16))
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
	for fl in [1, 2, 3]:
		for v in 4:
			_add("kacheln", "wand/%d_oben%d" % [fl, v], _wall(fl, v, false))
			_add("kacheln", "wand/%d_front%d" % [fl, v], _wall(fl, v, true))
	for boss in [false, true]:
		for hor in [true, false]:
			for open in [false, true]:
				_add("kacheln", "tuer/%s_%s_%s" % ["boss" if boss else "holz", "quer" if hor else "laengs", "offen" if open else "zu"], _door(open, hor, boss))
	_add("kacheln", "treppe", _stairs())


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
			var cx := _ri(5, 10)
			var cy := _ri(5, 10)
			var rx := _ri(3, 5)
			var ry := _ri(2, 3)
			for y in T:
				for x in T:
					var d := pow((x - cx) / float(rx), 2) + pow((y - cy) / float(ry), 2)
					if d <= 1.0 + _r() * 0.15:
						img.set_pixel(x, y, Color(0.12, 0.17, 0.24, 0.55))
			img.set_pixel(cx - 1, cy - 1, Color(0.7, 0.8, 0.95, 0.35))
			img.set_pixel(cx, cy - 1, Color(0.7, 0.8, 0.95, 0.25))
		"riss":
			var x := _ri(2, 5)
			var y := _ri(4, 11)
			while x < 14:
				img.set_pixel(x, y, Color(0, 0, 0, 0.55))
				x += 1
				if _r() < 0.45:
					y = clampi(y + (1 if _r() < 0.5 else -1), 1, 14)
					img.set_pixel(x, y, Color(0, 0, 0, 0.55))
				if _r() < 0.15:
					img.set_pixel(x, clampi(y + 1, 0, 15), Color(0, 0, 0, 0.3))
		"fleck":
			var cx := _ri(5, 10)
			var cy := _ri(5, 10)
			for y in T:
				for x in T:
					var d := pow((x - cx) / 4.0, 2) + pow((y - cy) / 2.6, 2)
					if d <= 1.0 and _r() < 0.9:
						img.set_pixel(x, y, Color(0.05, 0.03, 0.02, 0.3))
	return img


const PROJECTILES := {
	"stein": ["#c8c0b0", 3], "schleim": ["#8ce04a", 3], "bombe": ["#3a3a44", 4],
	"magie": ["#c080ff", 5], "feuer": ["#ff8a2a", 5], "blitz": ["#9fdcff", 5],
}


func _projectile(n: String) -> Image:
	var col := Color(PROJECTILES[n][0])
	var s: int = PROJECTILES[n][1]
	var img := Image.create(s + 2, s + 2, false, Image.FORMAT_RGBA8)
	var c := (s + 2) / 2.0
	for y in s + 2:
		for x in s + 2:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
			if d <= s / 2.0 + 0.2:
				var glow := n in ["magie", "feuer", "blitz"]
				img.set_pixel(x, y, Color.WHITE if glow and d < s / 4.0 else col)
			elif d <= s / 2.0 + 1.0:
				img.set_pixel(x, y, Color(PixelArt.PALETTE.k))
	if n == "bombe":
		img.set_pixel(s, 0, Color("#feae34"))
	return img


# ================================================================ Böden

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
}


func _floor(mat: String, v: int) -> Image:
	_rng = Rng.new(100 + v * 17 + mat.length() * 101)
	var spec: Dictionary = FLOORS[mat]
	var base := Color(spec.base)
	var gap := Color(spec.gap)
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	img.fill(gap)
	match mat:
		"pflaster":
			# Unregelmäßige Steine in versetzten Reihen
			var y := 0
			var row := 0
			while y < T:
				var hgt := 4 if y + 4 <= T else T - y
				var x := -(row % 2) * 3
				while x < T:
					var wd := _ri(4, 6)
					var col := _jit(base, 0.12, _r())
					for yy in range(y, y + hgt - 1):
						for xx in range(maxi(0, x), mini(T, x + wd - 1)):
							var c := col
							if yy == y:
								c = col.lightened(0.12)
							elif yy == y + hgt - 2:
								c = col.darkened(0.15)
							img.set_pixel(xx, yy, c)
					x += wd
				y += hgt
				row += 1
		"dielen":
			for p in 4:
				var y0 := p * 4
				var col := _jit(base, 0.08, _r())
				var cut := _ri(3, 12)
				for yy in range(y0, y0 + 3):
					for xx in T:
						var c := col
						if _r() < 0.18:
							c = col.darkened(0.12)
						if yy == y0:
							c = c.lightened(0.08)
						img.set_pixel(xx, yy, c)
				# Stoß und Nägel
				for yy in range(y0, y0 + 3):
					img.set_pixel(cut, yy, gap)
				img.set_pixel(cut + 1, y0 + 1, Color("#8f8a80"))
				img.set_pixel((cut + 8) % T, y0 + 1, Color("#8f8a80"))
		"fliesen":
			for ty in 2:
				for tx in 2:
					var col := base if (tx + ty) % 2 == 0 else base.darkened(0.08)
					col = _jit(col, 0.03, _r())
					for yy in range(ty * 8, ty * 8 + 7):
						for xx in range(tx * 8, tx * 8 + 7):
							img.set_pixel(xx, yy, col)
					img.set_pixel(tx * 8, ty * 8, col.lightened(0.18))
					img.set_pixel(tx * 8 + 1, ty * 8, col.lightened(0.1))
		"beton", "arena":
			for yy in T:
				for xx in T:
					img.set_pixel(xx, yy, _jit(base, 0.05, _r()))
			for i in 10:
				var c := base.darkened(0.18) if _r() < 0.6 else base.lightened(0.12)
				img.set_pixel(_ri(0, 15), _ri(0, 15), c)
			if mat == "beton":
				# Fugen der Platten
				for i in T:
					img.set_pixel(i, 0, gap)
					img.set_pixel(0, i, gap)
			else:
				for i in 3:
					var px := _ri(1, 14)
					var py := _ri(1, 14)
					img.set_pixel(px, py, Color("#b09a74"))
					img.set_pixel(px + 1, py, Color("#6c5a3e"))
		"ziegelboden":
			for r in 4:
				var y0 := r * 4
				var off := 4 if r % 2 == 1 else 0
				for b in 3:
					var x0 := b * 8 - off
					var col := _jit(base, 0.1, _r())
					for yy in range(y0, y0 + 3):
						for xx in range(maxi(0, x0), mini(T, x0 + 7)):
							var c := col.lightened(0.1) if yy == y0 else (col.darkened(0.12) if yy == y0 + 2 else col)
							img.set_pixel(xx, yy, c)
		"teppich":
			for yy in T:
				for xx in T:
					img.set_pixel(xx, yy, _jit(base, 0.04, _r()))
			var trim := Color(spec.trim)
			# Rautenmuster
			for i in 4:
				img.set_pixel(7 - i, 3 + i, trim.darkened(0.2))
				img.set_pixel(8 + i, 3 + i, trim.darkened(0.2))
				img.set_pixel(4 + i, 7 + i, trim.darkened(0.2))
				img.set_pixel(11 - i, 7 + i, trim.darkened(0.2))
			img.set_pixel(7, 7, trim)
			img.set_pixel(8, 8, trim)
		"marmor":
			for yy in T:
				for xx in T:
					img.set_pixel(xx, yy, _jit(base, 0.025, _r()))
			var vein := Color(spec.vein)
			var x := _ri(0, 6)
			var y := _ri(0, 15)
			for i in 14:
				img.set_pixel(clampi(x, 0, 15), clampi(y, 0, 15), vein)
				x += 1
				y += _ri(-1, 1)
			for i in T:
				img.set_pixel(i, T - 1, gap)
				img.set_pixel(T - 1, i, gap)
		"blutstein":
			for ty in 2:
				for tx in 2:
					var col := _jit(base, 0.1, _r())
					for yy in range(ty * 8, ty * 8 + 7):
						for xx in range(tx * 8, tx * 8 + 7):
							img.set_pixel(xx, yy, col)
					img.set_pixel(tx * 8, ty * 8, col.lightened(0.15))
			if v % 2 == 0:
				var x := _ri(2, 8)
				var y := _ri(3, 12)
				var vein := Color(spec.vein)
				for i in 5:
					img.set_pixel(x + i, y, vein)
					if i % 2 == 1:
						y += 1
	return img


# ================================================================ Wände, Türen, Treppe

func _wall(fl: int, v: int, face: bool) -> Image:
	_rng = Rng.new(300 + fl * 13 + v * 7 + (1 if face else 0))
	var th := Tiles.wall_theme(fl)
	var cap := Color(th.cap)
	var stone := Color(th.capStone)
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	img.fill(cap)
	# Mauerkrone von oben: große Platten
	var seam := _ri(5, 10)
	for yy in T:
		for xx in T:
			var c := _jit(stone, 0.06, _r())
			if xx == seam or (yy == 8 and xx < seam) or (yy == 5 and xx > seam):
				c = cap
			img.set_pixel(xx, yy, c)
	if not face:
		return img
	var top := 5
	var mortar := Color(th.mortar)
	var fc := Color(th.face)
	for yy in range(top, T):
		for xx in T:
			img.set_pixel(xx, yy, mortar)
	# Kante der Krone
	for xx in T:
		img.set_pixel(xx, top - 1, Color(th.lip).darkened(0.1))
	# Ziegel 8×3 im Verband
	var r := 0
	var y := top
	while y < T:
		var off := 4 if r % 2 == 1 else 0
		for b in 3:
			var x0 := b * 8 - off
			var col := _jit(fc, 0.1, _r())
			for yy in range(y, mini(T, y + 2)):
				for xx in range(maxi(0, x0), mini(T, x0 + 7)):
					var c := col.lightened(0.12) if yy == y else col
					img.set_pixel(xx, yy, c)
		y += 3
		r += 1
	# Schatten unten, wo die Wand auf den Boden trifft
	for xx in T:
		img.set_pixel(xx, T - 1, mortar.darkened(0.3))
	if th.has("moss"):
		var moss := Color(th.moss)
		for i in 5:
			var mx := _ri(0, 15)
			var my := _ri(top + 1, T - 2)
			img.set_pixel(mx, my, moss)
			if mx < 15:
				img.set_pixel(mx + 1, my, moss.darkened(0.2))
	return img


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
			img.set_pixel(0, yy, frame)
			img.set_pixel(1, yy, frame)
			img.set_pixel(14, yy, frame_d.darkened(0.2))
			img.set_pixel(15, yy, frame_d.darkened(0.2))
		for xx in T:
			img.set_pixel(xx, 0, frame.lightened(0.1))
			img.set_pixel(xx, 1, frame)
		if open:
			for yy in range(2, T):
				for xx in range(2, 14):
					img.set_pixel(xx, yy, k if yy < 8 else Color("#1e1a24"))
			for yy in range(2, T):
				img.set_pixel(2, yy, wood)
				img.set_pixel(3, yy, wood_d)
			return img
		for yy in range(2, T):
			for xx in range(2, 14):
				var c := wood if (xx - 2) % 4 != 3 else wood_d
				img.set_pixel(xx, yy, c)
		for xx in range(2, 14):
			img.set_pixel(xx, 5, band)
			img.set_pixel(xx, 12, band)
		img.set_pixel(11, 9, Color("#feae34"))
		img.set_pixel(11, 10, Color("#be4a2f"))
		if boss:
			for p in [Vector2i(4, 5), Vector2i(8, 5), Vector2i(12, 5), Vector2i(4, 12), Vector2i(8, 12), Vector2i(12, 12)]:
				img.set_pixelv(p, Color("#e43b44"))
		return img
	# Tür in einer senkrechten Wand: von oben als schmale Platte
	for xx in T:
		for yy in [0, 1, 14, 15]:
			img.set_pixel(xx, yy, frame if yy < 8 else frame_d)
	if open:
		for xx in range(3, 13):
			img.set_pixel(xx, 2, k)
			img.set_pixel(xx, 3, wood)
			img.set_pixel(xx, 4, wood_d)
			img.set_pixel(xx, 5, k)
		return img
	for yy in range(2, 14):
		img.set_pixel(5, yy, k)
		img.set_pixel(6, yy, wood.lightened(0.1))
		img.set_pixel(7, yy, wood)
		img.set_pixel(8, yy, wood)
		img.set_pixel(9, yy, wood_d)
		img.set_pixel(10, yy, k)
	for yy in [4, 11]:
		for xx in range(6, 10):
			img.set_pixel(xx, yy, band)
	return img


func _stairs() -> Image:
	var img := Image.create(T, T, false, Image.FORMAT_RGBA8)
	var k := Color(PixelArt.PALETTE.k)
	img.fill(Color("#6e6254"))
	for i in T:
		img.set_pixel(i, 0, Color("#8a7c6a"))
		img.set_pixel(0, i, Color("#8a7c6a"))
		img.set_pixel(i, T - 1, Color("#3e3730"))
		img.set_pixel(T - 1, i, Color("#3e3730"))
	for yy in range(2, 15):
		for xx in range(2, 14):
			img.set_pixel(xx, yy, k)
	# Stufen, nach unten dunkler und schmaler
	for s in 5:
		var y := 2 + s * 3
		var inset := s
		var light := 0.78 - s * 0.14
		var col := Color(light, light * 0.84, light * 0.62)
		for xx in range(2 + inset, 14 - inset):
			img.set_pixel(xx, y, col.lightened(0.25))
			img.set_pixel(xx, y + 1, col)
	# Goldene Geländer
	for yy in range(2, 15):
		var inset := (yy - 2) / 3
		img.set_pixel(1 + inset, yy, Color("#d9ae52"))
		img.set_pixel(14 - inset, yy, Color("#d9ae52"))
	return img
