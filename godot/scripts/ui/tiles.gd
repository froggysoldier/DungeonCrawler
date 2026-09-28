class_name Tiles
extends Node
## Prozedurale Kacheltexturen der Karte: Böden je
## Raumart, Mauerwerk je Etage, weiche Schatten an Wänden und Türen.
## Alles wird einmal in einen Offscreen-Viewport gezeichnet, ausgelesen und als
## Textur mit Mipmaps zwischengespeichert. Eine Kachel ist 32 Design-Einheiten groß.

signal ready_changed

const U := 32.0
## Auflösung einer Kachel in der Textur (Pixel).
const PX := 96
const COLS := 10

const MATERIALS := ["pflaster", "dielen", "fliesen", "beton", "ziegelboden", "teppich", "marmor", "blutstein", "arena"]
const AO_SIDES := ["n", "s", "w", "e", "nw", "ne", "sw", "se"]

const WALL_THEMES := {
	1: {"cap": "#191511", "capStone": "#29231c", "face": "#7b6c5a", "mortar": "#2b241c", "lip": "#a8977f"},
	2: {"cap": "#14161a", "capStone": "#232830", "face": "#6c737e", "mortar": "#22262c", "lip": "#9aa3ae"},
	3: {"cap": "#101512", "capStone": "#1d2821", "face": "#5d6d5e", "mortar": "#1b231d", "lip": "#8fa08e", "moss": "#4f7a3a"},
}

var textures: Dictionary = {}
var is_ready := false


class Cell:
	extends Control
	var fn: Callable

	func _draw() -> void:
		var pen := Pen.new(self)
		pen.scale(Tiles.PX / Tiles.U, Tiles.PX / Tiles.U)
		fn.call(pen)


static func wall_theme(floor: int) -> Dictionary:
	return WALL_THEMES[clampi(floor, 1, 3)]


# ---------------------------------------------------------------- Zufall je Kachel

static func _i32(v: int) -> int:
	v = v & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


## Deterministischer Zufall je Kachel: jede Stelle sieht bei jedem Zeichnen gleich aus.
static func hash(x: int, y: int, salt: int = 0) -> float:
	var h := _i32(x * 374761393 + y * 668265263 + salt * 2147483647)
	h = _i32(h ^ ((h & 0xFFFFFFFF) >> 13))
	var prod := float(h) * 1274126177.0
	var h2 := _i32(int(prod))
	var r := (h2 ^ ((h2 & 0xFFFFFFFF) >> 16)) & 0xFFFFFFFF
	return r / 4294967295.0


# ---------------------------------------------------------------- Bausteine

## Ein Stein, eine Fliese, ein Ziegel: gerundet, oben links Licht, unten rechts Schatten.
static func bevel(c: Pen, x: float, y: float, w: float, h: float, r: float, color: Variant, light: float = 0.13, dark: float = 0.3) -> void:
	c.fill_style = color
	c.begin_path()
	c.round_rect(x, y, w, h, r)
	c.fill()
	var g := c.linear_gradient(x, y, x + w * 0.6, y + h)
	g.add(0, Color(1, 244 / 255.0, 225 / 255.0, light))
	g.add(0.45, Color(1, 244 / 255.0, 225 / 255.0, 0))
	g.add(1, Color(0, 0, 0, dark))
	c.fill_style = g
	c.fill()
	c.stroke_style = Color(1, 244 / 255.0, 225 / 255.0, light * 0.6)
	c.line_width = 0.6
	c.begin_path()
	c.move_to(x + r, y + 0.5)
	c.line_to(x + w - r, y + 0.5)
	c.stroke()


static func specks(c: Pen, rnd: Callable, n: int, light: float, dark: float, size: float = 1.0) -> void:
	for k in n:
		c.fill_style = Color(1, 240 / 255.0, 215 / 255.0, light) if rnd.call(k + 100) > 0.5 else Color(0, 0, 0, dark)
		c.fill_rect(rnd.call(k + 200) * U, rnd.call(k + 300) * U, size, size)


# ---------------------------------------------------------------- Böden

static func draw_floor(c: Pen, mat: String, v: int) -> void:
	var rnd := func(k: int) -> float: return Tiles.hash(v * 31 + k, k * 7 + v, 99)
	match mat:
		"pflaster":
			c.fill_style = "#15120f"
			c.fill_rect(0, 0, U, U)
			var layouts := [
				[[1, 1, 15, 13], [17, 1, 14, 9], [17, 11, 14, 20], [1, 15, 9, 16], [11, 15, 5, 16]],
				[[1, 1, 10, 15], [12, 1, 19, 12], [1, 17, 14, 14], [16, 14, 15, 8], [16, 23, 15, 8]],
				[[1, 1, 19, 10], [21, 1, 10, 16], [1, 12, 12, 19], [14, 12, 6, 19], [21, 18, 10, 13]],
				[[1, 1, 13, 18], [15, 1, 16, 14], [1, 20, 17, 11], [19, 16, 12, 15], [15, 16, 3, 3]],
			]
			var lay: Array = layouts[v % 4]
			for k in lay.size():
				var r: Array = lay[k]
				bevel(c, r[0], r[1], r[2], r[3], 3.5, Pen.shade("#4a4036", 0.82 + rnd.call(k) * 0.32))
			specks(c, rnd, 26, 0.05, 0.22)
		"dielen":
			c.fill_style = "#1b120b"
			c.fill_rect(0, 0, U, U)
			for k in 4:
				var y := k * 8.0
				c.fill_style = Pen.shade("#5e432a", 0.82 + rnd.call(k) * 0.3)
				c.fill_rect(0, y + 0.5, U, 7)
				# Maserung
				c.stroke_style = "rgba(28,16,6,0.42)"
				c.line_width = 0.55
				for gi in 2:
					var gy: float = y + 2 + gi * 3 + rnd.call(k * 3 + gi) * 1.5
					c.begin_path()
					c.move_to(0, gy)
					c.bezier_curve_to(10, gy - 1 + rnd.call(k + gi + 20) * 2, 22, gy + 1.5 - rnd.call(k + gi + 30) * 2, U, gy)
					c.stroke()
				c.fill_style = "rgba(255,225,180,0.08)"
				c.fill_rect(0, y + 0.5, U, 1)
				c.fill_style = "rgba(0,0,0,0.3)"
				c.fill_rect(0, y + 6.5, U, 1)
				# Stoßfuge mit zwei Nägeln
				var cut := 3 + floorf(rnd.call(k + 9) * 26)
				c.fill_style = "#140c06"
				c.fill_rect(cut, y + 0.5, 1, 7)
				c.fill_style = "rgba(200,190,170,0.35)"
				c.fill_rect(cut - 2, y + 2, 1, 1)
				c.fill_rect(cut + 2, y + 5, 1, 1)
				if rnd.call(k + 40) > 0.8:
					c.fill_style = "rgba(30,16,6,0.6)"
					c.begin_path()
					c.ellipse(4 + rnd.call(k + 41) * 24, y + 4, 1.6, 1, 0, 0, TAU)
					c.fill()
		"fliesen":
			c.fill_style = "#16191c"
			c.fill_rect(0, 0, U, U)
			for yy in 2:
				for xx in 2:
					var base := "#56606a" if (xx + yy) % 2 else "#4a535b"
					bevel(c, xx * 16 + 1, yy * 16 + 1, 14, 14, 1.5, Pen.shade(base, 0.9 + rnd.call(xx * 2 + yy) * 0.18), 0.16, 0.22)
		"beton":
			c.fill_style = Pen.shade("#403c36", 0.9 + rnd.call(1) * 0.14)
			c.fill_rect(0, 0, U, U)
			specks(c, rnd, 60, 0.05, 0.16)
			# Fugen nur alle zwei Kacheln, damit kein strenges Raster entsteht
			c.fill_style = "rgba(0,0,0,0.18)"
			if v % 2:
				c.fill_rect(U - 1, 0, 1, U)
			if v >= 2:
				c.fill_rect(0, U - 1, U, 1)
			c.fill_style = "rgba(255,245,230,0.03)"
			c.fill_rect(0, 0, U, 1)
			c.fill_rect(0, 0, 1, U)
		"ziegelboden":
			c.fill_style = "#26140e"
			c.fill_rect(0, 0, U, U)
			for row in 4:
				var off := 8 if row % 2 else 0
				for col in range(-1, 2):
					bevel(c, col * 16 + off + 1, row * 8 + 1, 14, 6, 1, Pen.shade("#723f2d", 0.75 + rnd.call(row * 4 + col + 3) * 0.35), 0.12, 0.3)
		"teppich":
			c.fill_style = "#5a1d22"
			c.fill_rect(0, 0, U, U)
			# Gewebe
			c.stroke_style = "rgba(0,0,0,0.12)"
			c.line_width = 0.6
			var d := -U
			while d < U:
				c.begin_path()
				c.move_to(d, 0)
				c.line_to(d + U, U)
				c.stroke()
				d += 3
			# Ornament: Raute in der Mitte, Viertel an den Ecken ergeben ein Muster
			var diamond := func(x: float, y: float, r: float) -> void:
				c.begin_path()
				c.move_to(x, y - r)
				c.line_to(x + r, y)
				c.line_to(x, y + r)
				c.line_to(x - r, y)
				c.close_path()
				c.fill()
			c.fill_style = "rgba(214,170,90,0.55)"
			diamond.call(16, 16, 5)
			for pt in [[0, 0], [U, 0], [0, U], [U, U]]:
				diamond.call(pt[0], pt[1], 5)
			c.fill_style = "#5a1d22"
			diamond.call(16, 16, 2.4)
			c.fill_style = "rgba(255,220,160,0.06)"
			c.fill_rect(0, 0, U, U / 2)
		"marmor":
			c.fill_style = "#10141c"
			c.fill_rect(0, 0, U, U)
			for yy in 2:
				for xx in 2:
					var x := xx * 16 + 0.5
					var y := yy * 16 + 0.5
					c.fill_style = Pen.shade("#2c3850", 0.92 + rnd.call(xx + yy * 2) * 0.16)
					c.fill_rect(x, y, 15, 15)
					c.stroke_style = "rgba(200,215,255,0.22)"
					c.line_width = 0.6
					c.begin_path()
					c.move_to(x, y + rnd.call(xx * 5 + yy) * 15)
					c.bezier_curve_to(x + 5, y + rnd.call(xx + 7) * 15, x + 10, y + rnd.call(yy + 9) * 15, x + 15, y + rnd.call(xx + yy + 11) * 15)
					c.stroke()
					var g := c.linear_gradient(x, y, x + 15, y + 15)
					g.add(0, "rgba(255,255,255,0.12)")
					g.add(0.5, "rgba(255,255,255,0)")
					g.add(1, "rgba(0,0,0,0.2)")
					c.fill_style = g
					c.fill_rect(x, y, 15, 15)
		"blutstein":
			c.fill_style = "#120807"
			c.fill_rect(0, 0, U, U)
			var stones := [[1, 1, 17, 12], [19, 1, 12, 16], [1, 14, 12, 17], [14, 18, 17, 13]]
			for k in stones.size():
				var r: Array = stones[k]
				bevel(c, r[0], r[1], r[2], r[3], 2.5, Pen.shade("#4a2420", 0.78 + rnd.call(k) * 0.4), 0.1, 0.35)
			if rnd.call(9) > 0.55:
				c.fill_style = "rgba(130,12,12,0.45)"
				c.begin_path()
				c.ellipse(16, 16, 5 + rnd.call(3) * 4, 3, rnd.call(4) * 3, 0, TAU)
				c.fill()
			c.stroke_style = "rgba(190,30,20,0.35)"
			c.line_width = 0.6
			c.begin_path()
			c.move_to(rnd.call(20) * U, 0)
			c.line_to(rnd.call(21) * U, U * 0.5)
			c.line_to(rnd.call(22) * U, U)
			c.stroke()
		"arena":
			c.fill_style = Pen.shade("#6a5236", 0.9 + rnd.call(1) * 0.14)
			c.fill_rect(0, 0, U, U)
			specks(c, rnd, 70, 0.09, 0.18, 1.2)
			if rnd.call(5) > 0.6:
				c.fill_style = "rgba(50,30,15,0.18)"
				c.begin_path()
				c.ellipse(rnd.call(6) * U, rnd.call(7) * U, 9, 5, rnd.call(8) * 3, 0, TAU)
				c.fill()


static var _re_fliesen: RegEx
static var _re_beton: RegEx
static var _re_ziegel: RegEx


static func room_material(r: Variant) -> String:
	if r == null:
		return "pflaster"
	if _re_fliesen == null:
		_re_fliesen = RegEx.create_from_string("bad|dusch|wasch|küche|kueche|toilette|sauna|labor")
		_re_beton = RegEx.create_from_string("werkstatt|lager|garage|heizung|tank|schacht|bunker")
		_re_ziegel = RegEx.create_from_string("wein|gewölbe|kapelle|gruft|brunnen|ofen")
	match r.kind:
		"safe": return "teppich"
		"guild": return "marmor"
		"boss": return "blutstein"
		"arena": return "arena"
		"start": return "beton"
	var n: String = String(r.name).to_lower()
	if _re_fliesen.search(n):
		return "fliesen"
	if _re_beton.search(n):
		return "beton"
	if _re_ziegel.search(n):
		return "ziegelboden"
	var pool := ["dielen", "beton", "fliesen", "ziegelboden", "dielen"]
	return pool[int(r.id) % pool.size()]


# ---------------------------------------------------------------- Wände

static func draw_wall(c: Pen, floor: int, v: int, face: bool) -> void:
	var th := wall_theme(floor)
	var rnd := func(k: int) -> float: return Tiles.hash(v * 17 + k, k * 13 + v, 7)
	# Mauerkrone (von oben gesehen)
	var cg := c.linear_gradient(0, 0, U, U)
	cg.add(0, Pen.shade(th.capStone, 0.95 + rnd.call(1) * 0.1))
	cg.add(1, th.cap)
	c.fill_style = cg
	c.fill_rect(0, 0, U, U)
	# Zwei große, flache Deckplatten mit feiner Fuge
	c.stroke_style = "rgba(0,0,0,0.35)"
	c.line_width = 0.8
	c.begin_path()
	var seam: float = 10 + rnd.call(2) * 12
	c.move_to(seam, 0)
	c.line_to(seam, U)
	c.stroke()
	specks(c, rnd, 22, 0.035, 0.2)
	if not face:
		return
	# Sichtbare Mauerseite zum Raum hin
	var top := 12.0
	c.fill_style = th.mortar
	c.fill_rect(0, top, U, U - top)
	var rows := 2
	var rh := (U - top) / rows
	for row in rows:
		var off := 9 if row % 2 else 0
		for col in range(-1, 3):
			var x := col * 18 + off
			bevel(c, x + 1, top + row * rh + 1, 16, rh - 2, 1.2, Pen.shade(th.face, 0.74 + rnd.call(row * 4 + col + 30) * 0.3), 0.16, 0.34)
	if th.has("moss") and rnd.call(50) > 0.45:
		c.fill_style = Pen.rgba(th.moss, 0.55)
		for k in 5:
			c.begin_path()
			c.ellipse(rnd.call(k + 60) * U, U - 2 - rnd.call(k + 70) * 5, 2.5 + rnd.call(k + 80) * 3, 1.5, 0, 0, TAU)
			c.fill()
	# Lichtkante der Mauerkrone und Schatten darunter
	c.fill_style = th.lip
	c.fill_rect(0, top - 1.5, U, 1.5)
	c.fill_style = "rgba(0,0,0,0.45)"
	c.fill_rect(0, top, U, 1.2)
	var g := c.linear_gradient(0, top, 0, U)
	g.add(0, "rgba(0,0,0,0.05)")
	g.add(1, "rgba(0,0,0,0.42)")
	c.fill_style = g
	c.fill_rect(0, top, U, U - top)


## Umgebungsverdeckung: Böden werden an Wänden weich dunkler.
static func draw_ao(c: Pen, side: String) -> void:
	var depth := 11.0 if side == "n" else (5.0 if side == "s" else 8.0)
	var g: Pen.Grad
	match side:
		"n": g = c.linear_gradient(0, 0, 0, depth)
		"s": g = c.linear_gradient(0, U, 0, U - depth)
		"w": g = c.linear_gradient(0, 0, depth, 0)
		"e": g = c.linear_gradient(U, 0, U - depth, 0)
		_:
			var x := 0.0 if side.contains("w") else U
			var y := 0.0 if side.contains("n") else U
			g = c.radial_gradient(x, y, 0, x, y, 9)
	var strength := 0.5 if side == "n" else (0.22 if side == "s" else (0.35 if side.length() == 2 else 0.38))
	g.add(0, Color(0, 0, 0, strength))
	g.add(1, Color(0, 0, 0, 0))
	c.fill_style = g
	c.fill_rect(0, 0, U, U)


# ---------------------------------------------------------------- Türen

static func draw_door(c: Pen, open: bool, horizontal: bool, boss: bool) -> void:
	c.save()
	if not horizontal:
		c.translate(U / 2, U / 2)
		c.rotate(PI / 2)
		c.translate(-U / 2, -U / 2)
	var mid := U / 2
	# Schwelle aus Stein
	bevel(c, 0, mid - 5, U, 10, 1, "#5a4d3e", 0.14, 0.3)
	# Zarge
	bevel(c, 0, mid - 7, 4, 14, 1, "#4a3522", 0.2, 0.4)
	bevel(c, U - 4, mid - 7, 4, 14, 1, "#4a3522", 0.2, 0.4)
	if not open:
		# Türblatt: Bretter, Eisenbänder, Klinke
		c.fill_style = "rgba(0,0,0,0.45)"
		c.fill_rect(4, mid - 4, U - 8, 9)
		bevel(c, 4, mid - 5, U - 8, 9, 1, "#5a1c18" if boss else "#8e5e2f", 0.18, 0.35)
		c.stroke_style = "rgba(40,20,8,0.7)"
		c.line_width = 0.7
		var x := 9.0
		while x < U - 5:
			c.begin_path()
			c.move_to(x, mid - 4.5)
			c.line_to(x, mid + 3.5)
			c.stroke()
			x += 5
		c.fill_style = "#c0392b" if boss else "#6f6a62"
		c.fill_rect(5, mid - 3.2, U - 10, 1.4)
		c.fill_rect(5, mid + 1.2, U - 10, 1.4)
		if boss:
			# Nieten und ein schweres Schloss
			c.fill_style = "#e8b04a"
			var nx := 7.0
			while nx < U - 6:
				c.fill_rect(nx, mid - 0.6, 1.4, 1.4)
				nx += 4
			bevel(c, U / 2 - 3, mid - 3.5, 6, 7, 1, "#2a2a2e", 0.2, 0.4)
		c.fill_style = "#e7c46a"
		c.begin_path()
		c.arc(U - 9, mid - 0.5, 1.6, 0, TAU)
		c.fill()
	else:
		# Offen: das Türblatt steht aufgeklappt an der Zarge
		c.fill_style = "rgba(0,0,0,0.4)"
		c.fill_rect(5, mid - 17, 5, 14)
		bevel(c, 4, mid - 18, 4, 15, 1, "#7e532b", 0.2, 0.35)
		c.fill_style = "#e7c46a"
		c.fill_rect(4.8, mid - 15, 2.2, 1.6)
	c.restore()


# ---------------------------------------------------------------- Aufbau des Speichers

## Alle Texturen erzeugen: [Schlüssel, Zeichenfunktion].
static func _jobs() -> Array:
	var out: Array = []
	for mat in MATERIALS:
		for v in 4:
			out.append(["f:%s:%d" % [mat, v], func(c: Pen): Tiles.draw_floor(c, mat, v)])
	for fl in [1, 2, 3]:
		for v in 4:
			for face in [false, true]:
				out.append(["w:%d:%d:%d" % [fl, v, 1 if face else 0], func(c: Pen): Tiles.draw_wall(c, fl, v, face)])
	for side in AO_SIDES:
		out.append(["ao:" + side, func(c: Pen): Tiles.draw_ao(c, side)])
	for open in [false, true]:
		for hor in [false, true]:
			for boss in [false, true]:
				out.append(["d:%d:%d:%d" % [1 if open else 0, 1 if hor else 0, 1 if boss else 0], func(c: Pen): Tiles.draw_door(c, open, hor, boss)])
	return out


## Zeichnet alle Texturen einmal in einen Offscreen-Viewport.
func build() -> void:
	var jobs := _jobs()
	var rows := ceili(jobs.size() / float(COLS))
	var vp := SubViewport.new()
	vp.size = Vector2i(COLS * PX, rows * PX)
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(vp)
	for i in jobs.size():
		var cell := Cell.new()
		cell.fn = jobs[i][1]
		cell.clip_contents = true
		cell.position = Vector2((i % COLS) * PX, (i / COLS) * PX)
		cell.size = Vector2(PX, PX)
		vp.add_child(cell)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.convert(Image.FORMAT_RGBA8)
		for i in jobs.size():
			var sub := img.get_region(Rect2i((i % COLS) * PX, (i / COLS) * PX, PX, PX))
			sub.generate_mipmaps()
			textures[jobs[i][0]] = ImageTexture.create_from_image(sub)
	vp.queue_free()
	is_ready = true
	ready_changed.emit()


func floor_tex(mat: String, v: int) -> Texture2D:
	return textures.get("f:%s:%d" % [mat, v])


func wall_tex(floor: int, v: int, face: bool) -> Texture2D:
	return textures.get("w:%d:%d:%d" % [clampi(floor, 1, 3), v, 1 if face else 0])


func ao_tex(side: String) -> Texture2D:
	return textures.get("ao:" + side)


func door_tex(open: bool, horizontal: bool, boss: bool) -> Texture2D:
	return textures.get("d:%d:%d:%d" % [1 if open else 0, 1 if horizontal else 0, 1 if boss else 0])
