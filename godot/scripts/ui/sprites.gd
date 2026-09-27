class_name Sprites
extends RefCounted
## Gezeichnete Kreaturen (Port von src/ui/sprites.ts): jede Monsterart hat eine
## erkennbare Silhouette. Gezeichnet wird in einem Raster von −50 bis 50 und
## skaliert, damit es auf der Karte und als großes Porträt gleich gut aussieht.

const BY_DEF := {
	"kellerratte": "ratte", "rattenmensch": "ratte", "rattenschamane": "ratte", "knochenratte": "ratte", "koenig_kanalratte": "ratte", "rattenkaiser": "ratte",
	"riesenkakerlake": "kakerlake",
	"kobold": "kobold", "kobold_schleuder": "kobold", "elster_goblin": "kobold", "kobold_bombe": "kobold", "schmuggler": "kobold", "wechselbalg": "kobold",
	"schleim": "schleim", "klaerschlamm": "schleim", "kommandant_schlamm": "schleim",
	"wolpertinger": "hase",
	"poltergeist": "geist", "nachtmahr": "geist",
	"grauer_spaeher": "alien",
	"muellsack_mimic": "sack",
	"tatzelwurm": "wurm", "neunauge": "wurm",
	"ghul": "zombie", "moorleiche": "zombie",
	"gnom_buerokrat": "gnom", "heinzelmann": "gnom", "gartenzwerg": "gnom",
	"kellerspinne": "spinne",
	"fledermaus": "fledermaus",
	"blaehkroete": "kroete",
	"irrlicht": "irrlicht",
	"abflusstentakel": "tentakel",
	"toaster_mimic": "maschine", "waschmaschine_mimic": "maschine", "muttis_mixer": "maschine", "heizungsbestie": "maschine",
	"grey_drohne": "drohne",
	"chupacabra": "hund", "ghulhund": "hund",
	"troll_lehrling": "troll", "schwarzmarkt_oger": "troll",
	"kellermeister": "skelett",
	"abtruenniger_crawler": "crawler", "morlock": "zombie",
	"wutelementar": "elementar",
	"kanalkroko": "kroko",
	"fischmensch": "fisch", "nixe": "fisch", "kanalkoenigin": "fisch",
	"kanalhexe": "hexe", "kesselkoenigin": "hexe",
	"pilzmensch": "pilz",
	"mottenmann": "motte", "mottenmutter": "motte",
	"taubenschwarm": "vogel",
	"die_sammlerin": "mensch", "der_hausmeister": "mensch", "kammerjaeger": "mensch", "pfandbaron": "mensch", "hausverwalter": "mensch",
}

const OUT := Color(10 / 255.0, 10 / 255.0, 14 / 255.0)


static func sprite_for(def_id: String, rank_ghost: bool = false) -> String:
	if rank_ghost:
		return "geist"
	return BY_DEF.get(def_id, "kobold")


static func pal(color: Variant) -> Dictionary:
	var c: Variant = color
	if c is String and not (c as String).match("#??????"):
		c = "#a39a8c"
	return {"body": Pen.css(c), "dark": Pen.shade(c, 0.55), "light": Pen.shade(c, 1.35)}


static func _p(body: String, dark: String, light: String) -> Dictionary:
	return {"body": Pen.css(body), "dark": Pen.css(dark), "light": Pen.css(light)}


## Pfad füllen mit Verlauf (oben hell, unten dunkel) und dunkler Kontur.
static func fill_shape(c: Pen, p: Dictionary, build: Callable, outline: float = 4.0) -> void:
	c.begin_path()
	build.call()
	var g := c.linear_gradient(0, -45, 0, 45)
	g.add(0, p.light)
	g.add(0.55, p.body)
	g.add(1, p.dark)
	c.fill_style = g
	c.stroke_style = OUT
	c.line_width = outline
	c.line_join = "round"
	c.stroke()
	c.fill()


static func ell(c: Pen, x: float, y: float, rx: float, ry: float, rot: float = 0.0) -> void:
	c.move_to(x + rx * cos(rot), y + rx * sin(rot))
	c.ellipse(x, y, rx, ry, rot, 0, TAU)


static func eyes(c: Pen, pts: Array, r: float = 3.2, color: Variant = "#fff6c8") -> void:
	for pt in pts:
		c.fill_style = OUT
		c.begin_path()
		c.arc(pt[0], pt[1], r + 1.4, 0, TAU)
		c.fill()
		c.fill_style = color
		c.begin_path()
		c.arc(pt[0], pt[1], r, 0, TAU)
		c.fill()


static func stroke_line(c: Pen, color: Variant, w: float, pts: Array) -> void:
	c.stroke_style = OUT
	c.line_width = w + 3
	c.line_cap = "round"
	c.line_join = "round"
	c.begin_path()
	for i in pts.size():
		if i:
			c.line_to(pts[i][0], pts[i][1])
		else:
			c.move_to(pts[i][0], pts[i][1])
	c.stroke()
	c.stroke_style = color
	c.line_width = w
	c.stroke()
	c.line_cap = "butt"


static func _teeth(c: Pen, xs: Array, y0: float, y1: float, half: float) -> void:
	for x in xs:
		c.begin_path()
		c.move_to(x - half, y0)
		c.line_to(x, y1)
		c.line_to(x + half, y0)
		c.fill()


static func _draw_kind(c: Pen, kind: String, p: Dictionary, t: float) -> void:
	match kind:
		"ratte":
			stroke_line(c, p.dark, 3, [[-20, 18], [-36, 10], [-44, -4], [-40, -14]])
			fill_shape(c, p, func():
				ell(c, -4, 12, 24, 16)
				ell(c, 20, 2, 13, 11))
			fill_shape(c, p, func():
				ell(c, 18, -10, 6, 7)
				ell(c, 27, -8, 5, 6), 3)
			c.fill_style = "#ff9aa8"
			c.begin_path()
			c.arc(33, 4, 3, 0, TAU)
			c.fill()
			eyes(c, [[24, -1]], 2.6, "#ff4040")
			stroke_line(c, p.dark, 2.5, [[-14, 26], [-14, 32]])
			stroke_line(c, p.dark, 2.5, [[8, 26], [8, 32]])
		"kakerlake":
			for sg in [-1, 1]:
				for k in [-12, 0, 12]:
					stroke_line(c, p.dark, 2.5, [[k, 0], [k + 6 * sg, 18 * sg], [k + 14 * sg, 26 * sg]])
			fill_shape(c, p, func(): ell(c, 0, 0, 30, 17))
			fill_shape(c, p, func(): ell(c, 30, 0, 9, 9), 3)
			stroke_line(c, p.dark, 1.5, [[36, -4], [48, -20]])
			stroke_line(c, p.dark, 1.5, [[36, 4], [48, 20]])
			c.stroke_style = "rgba(0,0,0,0.4)"
			c.line_width = 2
			c.begin_path()
			c.move_to(-30, 0)
			c.line_to(22, 0)
			c.stroke()
		"kobold":
			fill_shape(c, p, func():
				c.move_to(-14, 40)
				c.line_to(-16, 10)
				c.quadratic_curve_to(0, 2, 16, 10)
				c.line_to(14, 40)
				c.close_path())
			fill_shape(c, p, func():
				ell(c, 0, -10, 17, 16)
				c.move_to(-15, -14)
				c.line_to(-38, -26)
				c.line_to(-14, -4)
				c.move_to(15, -14)
				c.line_to(38, -26)
				c.line_to(14, -4))
			eyes(c, [[-6, -12], [6, -12]], 3, "#ffe14a")
			c.stroke_style = OUT
			c.line_width = 2.5
			c.begin_path()
			c.move_to(-7, 0)
			c.quadratic_curve_to(0, 4, 7, 0)
			c.stroke()
		"schleim":
			var wob := sin(t / 300.0) * 2
			fill_shape(c, p, func():
				c.move_to(-36, 34)
				c.bezier_curve_to(-40, 0, -24, -30 - wob, 0, -30 - wob)
				c.bezier_curve_to(24, -30 - wob, 40, 0, 36, 34)
				c.quadratic_curve_to(0, 42, -36, 34))
			c.fill_style = "rgba(255,255,255,0.35)"
			c.begin_path()
			c.ellipse(-14, -14, 7, 4, -0.6, 0, TAU)
			c.fill()
			eyes(c, [[-9, 4], [9, 4]], 3.5, "#101010")
		"hase":
			fill_shape(c, p, func():
				ell(c, -2, 18, 24, 18)
				ell(c, 16, -4, 13, 12)
				ell(c, 10, -26, 4, 12, -0.2)
				ell(c, 20, -26, 4, 12, 0.2))
			stroke_line(c, "#d9c29a", 2.5, [[6, -34], [0, -46], [-6, -44]])
			stroke_line(c, "#d9c29a", 2.5, [[24, -34], [30, -46], [36, -44]])
			eyes(c, [[20, -6]], 2.6)
		"geist":
			var f := sin(t / 250.0) * 3
			var keep := c.alpha
			c.alpha = keep * 0.9
			fill_shape(c, p, func():
				c.move_to(-26, 30 + f)
				c.line_to(-26, -8)
				c.bezier_curve_to(-26, -40, 26, -40, 26, -8)
				c.line_to(26, 30 + f)
				c.line_to(16, 22 + f)
				c.line_to(8, 32 + f)
				c.line_to(0, 22 + f)
				c.line_to(-8, 32 + f)
				c.line_to(-16, 22 + f)
				c.close_path())
			c.alpha = keep
			eyes(c, [[-9, -10], [9, -10]], 4, "#101018")
			c.fill_style = "#101018"
			c.begin_path()
			c.ellipse(0, 6, 5, 7, 0, 0, TAU)
			c.fill()
		"alien":
			fill_shape(c, p, func():
				c.move_to(-10, 40)
				c.line_to(-8, 12)
				c.line_to(8, 12)
				c.line_to(10, 40)
				c.close_path())
			fill_shape(c, p, func():
				c.move_to(0, 16)
				c.bezier_curve_to(-30, 4, -30, -38, 0, -38)
				c.bezier_curve_to(30, -38, 30, 4, 0, 16))
			c.fill_style = OUT
			c.begin_path()
			c.ellipse(-10, -12, 8, 5, 0.5, 0, TAU)
			c.ellipse(10, -12, 8, 5, -0.5, 0, TAU)
			c.fill()
		"sack":
			fill_shape(c, p, func():
				c.move_to(-30, 36)
				c.bezier_curve_to(-40, 0, -24, -24, -8, -26)
				c.line_to(-4, -36)
				c.line_to(4, -36)
				c.line_to(8, -26)
				c.bezier_curve_to(24, -24, 40, 0, 30, 36)
				c.close_path())
			c.fill_style = OUT
			c.begin_path()
			c.ellipse(0, 10, 18, 9, 0, 0, TAU)
			c.fill()
			c.fill_style = "#f2ecd8"
			_teeth(c, [-14, -7, 0, 7, 14], 3, 9, 3)
			eyes(c, [[-9, -10], [9, -10]], 3, "#ffe14a")
		"wurm":
			fill_shape(c, p, func():
				c.move_to(-44, 26)
				c.bezier_curve_to(-30, -4, -10, 36, 6, 8)
				c.bezier_curve_to(14, -6, 20, -18, 30, -18)
				c.line_to(34, -8)
				c.bezier_curve_to(24, -6, 22, 10, 12, 22)
				c.bezier_curve_to(-4, 42, -24, 14, -38, 34)
				c.close_path())
			fill_shape(c, p, func(): ell(c, 34, -18, 13, 11), 3)
			eyes(c, [[38, -22]], 2.8, "#ffe14a")
			stroke_line(c, p.dark, 2.5, [[-6, 26], [-10, 36]])
			stroke_line(c, p.dark, 2.5, [[14, 16], [16, 28]])
		"zombie":
			fill_shape(c, p, func():
				c.move_to(-15, 40)
				c.line_to(-17, 2)
				c.quadratic_curve_to(0, -6, 17, 2)
				c.line_to(15, 40)
				c.close_path())
			stroke_line(c, p.body, 6, [[14, 6], [36, 4]])
			stroke_line(c, p.body, 6, [[-14, 8], [24, 12]])
			fill_shape(c, p, func(): ell(c, 2, -16, 14, 15))
			eyes(c, [[-3, -18], [8, -17]], 2.8, "#d8ff6a")
			c.stroke_style = OUT
			c.line_width = 2
			c.begin_path()
			c.move_to(-4, -6)
			c.line_to(8, -7)
			c.stroke()
		"gnom":
			fill_shape(c, p, func():
				c.move_to(-18, 40)
				c.line_to(-14, 6)
				c.line_to(14, 6)
				c.line_to(18, 40)
				c.close_path())
			fill_shape(c, _p("#f1c9a0", "#b98a60", "#ffe3c8"), func(): ell(c, 0, -2, 12, 11))
			fill_shape(c, _p("#d23a32", "#8a1c18", "#ff6a5a"), func():
				c.move_to(-15, -6)
				c.line_to(4, -44)
				c.line_to(15, -6)
				c.close_path())
			fill_shape(c, _p("#eeeeee", "#aaaaaa", "#ffffff"), func():
				c.move_to(-11, 2)
				c.quadratic_curve_to(0, 30, 11, 2)
				c.close_path(), 3)
			eyes(c, [[-4, -3], [4, -3]], 2, "#101010")
		"spinne":
			var w := sin(t / 160.0) * 2
			for sg in [-1, 1]:
				for ka in [[-10, -1], [-3, -0.3], [4, 0.3], [11, 1]]:
					var k: float = ka[0]
					var a: float = ka[1]
					stroke_line(c, p.dark, 3, [[k * 0.6, 4], [sg * 22 + k * 0.5, -16 + a * 8 + w], [sg * 40 + k * 0.4, 20 + a * 6]])
			fill_shape(c, p, func():
				ell(c, 0, 14, 20, 17)
				ell(c, 0, -10, 12, 10))
			c.fill_style = "rgba(200,30,30,0.85)"
			c.begin_path()
			c.move_to(0, 6)
			c.line_to(5, 13)
			c.line_to(0, 20)
			c.line_to(-5, 13)
			c.fill()
			eyes(c, [[-5, -13], [5, -13], [-2, -8], [2, -8]], 2, "#ff3030")
		"fledermaus":
			var flap := sin(t / 120.0) * 8
			fill_shape(c, p, func():
				c.move_to(0, -4)
				c.bezier_curve_to(-18, -24 - flap, -38, -18 - flap, -48, -6 - flap)
				c.line_to(-40, 2)
				c.line_to(-32, -2)
				c.line_to(-26, 8)
				c.line_to(-16, 2)
				c.line_to(-8, 12)
				c.line_to(0, 8)
				c.line_to(8, 12)
				c.line_to(16, 2)
				c.line_to(26, 8)
				c.line_to(32, -2)
				c.line_to(40, 2)
				c.line_to(48, -6 - flap)
				c.bezier_curve_to(38, -18 - flap, 18, -24 - flap, 0, -4))
			fill_shape(c, p, func():
				ell(c, 0, 0, 9, 12)
				c.move_to(-7, -9)
				c.line_to(-9, -20)
				c.line_to(-2, -12)
				c.move_to(7, -9)
				c.line_to(9, -20)
				c.line_to(2, -12), 3)
			eyes(c, [[-3.5, -3], [3.5, -3]], 2, "#ff4040")
		"kroete":
			fill_shape(c, p, func():
				ell(c, 0, 14, 32, 22)
				ell(c, -14, -8, 9, 9)
				ell(c, 14, -8, 9, 9))
			c.fill_style = "rgba(0,0,0,0.25)"
			for pt in [[-14, 18], [8, 22], [16, 10], [-4, 8]]:
				c.begin_path()
				c.arc(pt[0], pt[1], 3.5, 0, TAU)
				c.fill()
			eyes(c, [[-14, -9], [14, -9]], 4, "#ffd23a")
			c.stroke_style = OUT
			c.line_width = 2.5
			c.begin_path()
			c.move_to(-16, 6)
			c.quadratic_curve_to(0, 14, 16, 6)
			c.stroke()
		"irrlicht":
			var r := 18 + sin(t / 200.0) * 2
			var g := c.radial_gradient(0, 0, 2, 0, 0, 44)
			g.add(0, "rgba(255,255,255,0.95)")
			g.add(0.3, p.light)
			g.add(1, "rgba(0,0,0,0)")
			c.fill_style = g
			c.begin_path()
			c.arc(0, 0, 44, 0, TAU)
			c.fill()
			c.fill_style = "#ffffff"
			c.begin_path()
			c.arc(0, 0, r * 0.45, 0, TAU)
			c.fill()
		"tentakel":
			var w := sin(t / 220.0) * 6
			fill_shape(c, _p("#3a3f47", "#1f2228", "#5a606a"), func(): ell(c, 0, 34, 30, 8), 3)
			fill_shape(c, p, func():
				c.move_to(-12, 34)
				c.bezier_curve_to(-18, 0, 10 + w, -10, -2 + w, -38)
				c.bezier_curve_to(16 + w, -14, 8, 4, 12, 34)
				c.close_path())
			c.fill_style = "rgba(255,220,230,0.6)"
			for y in [22, 8, -6]:
				c.begin_path()
				c.arc(2 + w * (1 - (y + 10) / 40.0), y, 3, 0, TAU)
				c.fill()
		"maschine":
			fill_shape(c, p, func(): c.round_rect(-30, -30, 60, 62, 8))
			c.fill_style = OUT
			c.begin_path()
			c.arc(0, 6, 17, 0, TAU)
			c.fill()
			c.fill_style = "rgba(150,200,255,0.35)"
			c.begin_path()
			c.arc(0, 6, 13, 0, TAU)
			c.fill()
			c.fill_style = "#ffe14a"
			c.fill_rect(-22, -24, 8, 5)
			c.fill_style = "#ff5a4a"
			c.fill_rect(-10, -24, 8, 5)
			eyes(c, [[-7, 4], [7, 4]], 3, "#ff3a3a")
			c.fill_style = "#f2ecd8"
			_teeth(c, [-9, -3, 3, 9], 12, 17, 2.5)
		"drohne":
			var spin := t / 40.0
			for x in [-28, 28]:
				stroke_line(c, p.dark, 3, [[x * 0.4, -2], [x, -10]])
				c.stroke_style = "rgba(220,230,255,0.6)"
				c.line_width = 3
				c.begin_path()
				c.move_to(x - 14 * cos(spin), -12)
				c.line_to(x + 14 * cos(spin), -12)
				c.stroke()
			fill_shape(c, p, func(): c.round_rect(-18, -8, 36, 20, 8))
			eyes(c, [[0, 2]], 5, "#ff4040")
		"hund":
			stroke_line(c, p.dark, 3.5, [[-28, 4], [-40, -12]])
			fill_shape(c, p, func():
				ell(c, -6, 8, 26, 14)
				ell(c, 24, -8, 12, 11)
				c.move_to(30, -4)
				c.line_to(42, 0)
				c.line_to(30, 4)
				c.move_to(18, -16)
				c.line_to(20, -30)
				c.line_to(26, -17))
			for x in [-22, -10, 6, 14]:
				stroke_line(c, p.dark, 4, [[x, 18], [x, 34]])
			eyes(c, [[27, -10]], 2.6, "#ff4040")
		"troll":
			fill_shape(c, p, func():
				c.move_to(-26, 40)
				c.line_to(-30, 0)
				c.quadratic_curve_to(0, -18, 30, 0)
				c.line_to(26, 40)
				c.close_path())
			stroke_line(c, p.body, 9, [[-26, 4], [-38, 30]])
			stroke_line(c, p.body, 9, [[26, 4], [38, 30]])
			fill_shape(c, p, func(): ell(c, 0, -20, 15, 14))
			eyes(c, [[-6, -22], [6, -22]], 2.6, "#ffe14a")
			c.fill_style = "#f2ecd8"
			c.begin_path()
			c.move_to(-7, -12)
			c.line_to(-5, -18)
			c.line_to(-3, -12)
			c.move_to(3, -12)
			c.line_to(5, -18)
			c.line_to(7, -12)
			c.fill()
		"skelett":
			var bone := _p("#e9e2cf", "#a39a82", "#ffffff")
			stroke_line(c, bone.body, 4, [[0, -4], [0, 26]])
			for y in [2, 9, 16]:
				stroke_line(c, bone.body, 3, [[-12, y], [12, y]])
			stroke_line(c, bone.body, 3.5, [[0, 26], [-10, 42]])
			stroke_line(c, bone.body, 3.5, [[0, 26], [10, 42]])
			stroke_line(c, bone.body, 3.5, [[-12, 2], [-22, 22]])
			stroke_line(c, bone.body, 3.5, [[12, 2], [22, 22]])
			fill_shape(c, bone, func(): ell(c, 0, -20, 14, 14))
			c.fill_style = OUT
			c.begin_path()
			c.arc(-5, -21, 4, 0, TAU)
			c.arc(5, -21, 4, 0, TAU)
			c.fill()
		"mensch", "crawler":
			fill_shape(c, p, func():
				c.move_to(-18, 40)
				c.line_to(-20, 4)
				c.quadratic_curve_to(0, -6, 20, 4)
				c.line_to(18, 40)
				c.close_path())
			fill_shape(c, _p("#e8b890", "#a87a58", "#ffd8b8"), func(): ell(c, 0, -16, 13, 14))
			fill_shape(c, _p("#4a3526", "#2a1c12", "#6a4c36"), func():
				c.move_to(-13, -18)
				c.bezier_curve_to(-14, -36, 14, -36, 13, -18)
				c.quadratic_curve_to(0, -24, -13, -18), 3)
			eyes(c, [[-5, -15], [5, -15]], 2, "#101010")
		"elementar":
			var f := sin(t / 120.0) * 4
			fill_shape(c, p, func():
				c.move_to(-26, 36)
				c.bezier_curve_to(-40, 6, -18, -6, -16, -24 + f)
				c.bezier_curve_to(-8, -14, -6, -34, 2, -44 - f)
				c.bezier_curve_to(8, -26, 20, -30, 20, -20 + f)
				c.bezier_curve_to(40, 0, 36, 20, 26, 36)
				c.close_path())
			eyes(c, [[-8, 6], [8, 6]], 4, "#ffffff")
		"kroko":
			fill_shape(c, p, func():
				c.move_to(-46, 12)
				c.quadratic_curve_to(-30, -6, -6, -8)
				c.line_to(34, -10)
				c.line_to(46, -2)
				c.line_to(34, 6)
				c.line_to(-6, 16)
				c.quadratic_curve_to(-30, 22, -46, 12))
			c.fill_style = "#f2ecd8"
			for x in [10, 16, 22, 28, 34]:
				c.begin_path()
				c.move_to(x, -2)
				c.line_to(x + 2, 3)
				c.line_to(x + 4, -2)
				c.fill()
			for x in [-22, -4]:
				stroke_line(c, p.dark, 5, [[x, 14], [x - 4, 28]])
			eyes(c, [[14, -12]], 2.8, "#ffe14a")
		"fisch":
			fill_shape(c, p, func():
				c.move_to(-14, 40)
				c.line_to(-16, 2)
				c.quadratic_curve_to(0, -6, 16, 2)
				c.line_to(14, 40)
				c.close_path())
			fill_shape(c, p, func():
				ell(c, 0, -16, 16, 13)
				c.move_to(-6, -28)
				c.line_to(0, -42)
				c.line_to(6, -28))
			eyes(c, [[-8, -18], [8, -18]], 4, "#e0ff8a")
			c.stroke_style = OUT
			c.line_width = 2.5
			c.begin_path()
			c.move_to(-8, -7)
			c.line_to(8, -7)
			c.stroke()
		"hexe":
			fill_shape(c, p, func():
				c.move_to(-24, 40)
				c.line_to(-10, 0)
				c.line_to(10, 0)
				c.line_to(24, 40)
				c.close_path())
			fill_shape(c, _p("#9ac27a", "#5a7a44", "#c2e2a2"), func(): ell(c, 0, -10, 11, 12))
			fill_shape(c, _p("#2a2238", "#15101c", "#463a5c"), func():
				c.move_to(-24, -16)
				c.line_to(24, -16)
				c.line_to(6, -20)
				c.line_to(10, -46)
				c.line_to(-8, -20)
				c.close_path(), 3)
			eyes(c, [[-4, -10], [4, -10]], 2, "#ffe14a")
		"pilz":
			fill_shape(c, _p("#e8dcc0", "#a89c80", "#fff4dc"), func():
				c.move_to(-12, 40)
				c.line_to(-10, -4)
				c.line_to(10, -4)
				c.line_to(12, 40)
				c.close_path())
			fill_shape(c, p, func():
				c.move_to(-38, 0)
				c.bezier_curve_to(-36, -40, 36, -40, 38, 0)
				c.quadratic_curve_to(0, 8, -38, 0))
			c.fill_style = "rgba(255,255,255,0.75)"
			for d in [[-18, -14, 5], [6, -22, 6], [22, -8, 4]]:
				c.begin_path()
				c.arc(d[0], d[1], d[2], 0, TAU)
				c.fill()
			eyes(c, [[-5, 12], [5, 12]], 2.4, "#101010")
		"motte":
			var flap := sin(t / 150.0) * 5
			fill_shape(c, p, func():
				c.move_to(0, -4)
				c.bezier_curve_to(-24, -40 - flap, -48, -20 - flap, -34, 6)
				c.bezier_curve_to(-30, 20, -10, 20, 0, 6)
				c.bezier_curve_to(10, 20, 30, 20, 34, 6)
				c.bezier_curve_to(48, -20 - flap, 24, -40 - flap, 0, -4))
			c.fill_style = "rgba(0,0,0,0.3)"
			c.begin_path()
			c.arc(-22, -12, 6, 0, TAU)
			c.arc(22, -12, 6, 0, TAU)
			c.fill()
			fill_shape(c, _p("#3a3034", "#1a1416", "#5a4a50"), func(): ell(c, 0, 4, 7, 20), 3)
			eyes(c, [[-3, -12], [3, -12]], 2.4, "#ff3030")
		"vogel":
			fill_shape(c, p, func():
				ell(c, -2, 10, 22, 16)
				ell(c, 18, -8, 11, 10)
				c.move_to(-20, 6)
				c.line_to(-40, 0)
				c.line_to(-20, 16))
			fill_shape(c, _p("#e6a23a", "#9a661a", "#ffc86a"), func():
				c.move_to(27, -9)
				c.line_to(38, -5)
				c.line_to(27, -3)
				c.close_path(), 2.5)
			c.fill_style = "rgba(120,200,160,0.5)"
			c.begin_path()
			c.ellipse(12, 2, 7, 4, 0, 0, TAU)
			c.fill()
			eyes(c, [[20, -10]], 2.4, "#ff7a3a")
			stroke_line(c, "#e6a23a", 2.5, [[-4, 24], [-6, 34]])
			stroke_line(c, "#e6a23a", 2.5, [[6, 24], [6, 34]])
		"haustier":
			stroke_line(c, p.dark, 3.5, [[-22, 10], [-34, -6]])
			fill_shape(c, p, func():
				ell(c, -4, 14, 20, 12)
				ell(c, 18, -2, 12, 11)
				c.move_to(10, -10)
				c.line_to(12, -24)
				c.line_to(18, -12)
				c.move_to(20, -12)
				c.line_to(28, -22)
				c.line_to(28, -8))
			eyes(c, [[15, -3], [23, -3]], 2.2, "#9fffb0")


## Zeichnet eine Kreatur mittig bei (cx, cy) mit der Kantenlänge size.
## opts: time, flip, crown, unknown.
static func draw_sprite(c: Pen, kind: String, color: Variant, cx: float, cy: float, size: float, opts: Dictionary = {}) -> void:
	c.save()
	c.translate(cx, cy)
	var s := size / 100.0
	var flip: bool = opts.get("flip", false)
	c.scale(-s if flip else s, s)
	_draw_kind(c, kind, pal(color), float(opts.get("time", 0.0)))
	if opts.get("unknown", false):
		# Die Gestalt siehst du, nur was es genau ist, weißt du nicht: kleines Fragezeichen
		c.scale(-1 if flip else 1, 1)
		c.begin_path()
		c.arc(30, -34, 13, 0, TAU)
		c.fill_style = "rgba(20, 20, 26, 0.92)"
		c.fill()
		c.line_width = 3
		c.stroke_style = "#e8e2d4"
		c.stroke()
		c.font(19, 800)
		c.text_align = "center"
		c.text_baseline = "middle"
		c.fill_style = "#e8e2d4"
		c.fill_text("?", 30, -33)
		c.scale(-1 if flip else 1, 1)
	if opts.get("crown", false):
		c.scale(-1 if flip else 1, 1)
		c.fill_style = "#ffcc33"
		c.stroke_style = OUT
		c.line_width = 3
		c.begin_path()
		c.move_to(-16, -38)
		c.line_to(-16, -50)
		c.line_to(-8, -43)
		c.line_to(0, -54)
		c.line_to(8, -43)
		c.line_to(16, -50)
		c.line_to(16, -38)
		c.close_path()
		c.stroke()
		c.fill()
	c.restore()


## Die Spielfigur: ein Mensch mit goldenem Mantel.
static func draw_hero(c: Pen, cx: float, cy: float, size: float, flip: bool = false) -> void:
	c.save()
	c.translate(cx, cy)
	var s := size / 100.0
	c.scale(-s if flip else s, s)
	fill_shape(c, _p("#d9a634", "#8a6414", "#ffd873"), func():
		c.move_to(-18, 40)
		c.line_to(-21, 4)
		c.quadratic_curve_to(0, -6, 21, 4)
		c.line_to(18, 40)
		c.close_path())
	stroke_line(c, "#b88a24", 6, [[20, 8], [30, 24]])
	stroke_line(c, "#b88a24", 6, [[-20, 8], [-30, 24]])
	fill_shape(c, _p("#f0c49a", "#b08660", "#ffe0c0"), func(): ell(c, 0, -16, 13, 14))
	fill_shape(c, _p("#5a3a22", "#2e1c0e", "#7a5434"), func():
		c.move_to(-13, -18)
		c.bezier_curve_to(-15, -38, 15, -38, 13, -18)
		c.quadratic_curve_to(4, -26, -13, -18), 3)
	eyes(c, [[-5, -15], [5, -15]], 2, "#101010")
	c.restore()
