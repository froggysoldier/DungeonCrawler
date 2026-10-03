extends SceneTree
## Holt die gebrauchten Teile aus dem Tiny-Swords-Pack (Pixel Frog, liegt in
## ../asset-pack) nach assets/tinyswords: Knöpfe, Papier, Holzrahmen, Bänder,
## Balken und Gelände. Bögen mit Lücken werden zu lückenlosen 9-Slices
## zusammengesetzt, Knöpfe für die dunkle Oberfläche umgefärbt und für kleine
## Elemente auf halbe Größe gebracht (Umrisse bleiben dabei erhalten).
##
## godot --headless --path godot -s res://tools/import_tinyswords.gd

const FREE := "asset-pack/Assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/"
const UPD := "asset-pack/Assets/Tiny Swords/Tiny Swords (Update 010)/"
const OUT := "res://assets/tinyswords/"

var base := ""
var made := 0


func _init() -> void:
	base = ProjectSettings.globalize_path("res://").path_join("..").simplify_path() + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "ui"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "terrain"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "fx"))
	_ui()
	_terrain()
	_fx()
	print("%d Bilder nach %s" % [made, OUT])
	quit()


func _load(rel: String) -> Image:
	var img := Image.load_from_file(base + rel)
	if img == null:
		push_error("fehlt: " + rel)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, name: String) -> void:
	# Oberflächenteile ohne durchsichtigen Rand, damit die 9-Slice-Ränder passen
	if name.begins_with("ui/"):
		img = img.get_region(img.get_used_rect())
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	made += 1


# ================================================================ Werkzeuge

## Bogen mit Lücken (Teile im 128er-Raster) zu einem lückenlosen 3x3-Bild.
func _assemble(img: Image, cols: Array, rows: Array) -> Image:
	var w := 0
	var h := 0
	for c in cols:
		w += c[1] - c[0]
	for r in rows:
		h += r[1] - r[0]
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var y := 0
	for r in rows:
		var x := 0
		for c in cols:
			out.blit_rect(img, Rect2i(c[0], r[0], c[1] - c[0], r[1] - r[0]), Vector2i(x, y))
			x += c[1] - c[0]
		y += r[1] - r[0]
	return out


## Halbe Größe: je 2x2 Pixel ein Pixel. Dunkle Umrisse gewinnen immer,
## sonst die häufigste Farbe – so bleiben Linien und Kanten scharf.
func _half(img: Image) -> Image:
	var w := img.get_width() / 2
	var h := img.get_height() / 2
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var px := [img.get_pixel(2 * x, 2 * y), img.get_pixel(2 * x + 1, 2 * y), img.get_pixel(2 * x, 2 * y + 1), img.get_pixel(2 * x + 1, 2 * y + 1)]
			var solid: Array = px.filter(func(c): return c.a > 0.5)
			if solid.size() < 2:
				continue
			var dark: Array = solid.filter(func(c): return c.v < 0.3)
			if not dark.is_empty():
				out.set_pixel(x, y, dark[0])
				continue
			var best: Color = solid[0]
			var best_n := 0
			for c in solid:
				var n: int = solid.filter(func(d): return d.is_equal_approx(c)).size()
				if n > best_n:
					best = c
					best_n = n
			out.set_pixel(x, y, best)
	return out


## Häufigste deckende Farbe.
func _dominant(img: Image) -> Color:
	var count := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				var k := c.to_html()
				count[k] = int(count.get(k, 0)) + 1
	var best := ""
	for k in count:
		if best == "" or count[k] > count[best]:
			best = k
	return Color.html(best)


## Füllung umfärben: Umriss (dunkel), heller Rand und gelber Hover-Rand
## bleiben, alles andere bekommt den Farbton von target und behält seine
## Helligkeit relativ zur Hauptfarbe (so bleiben Flecken und Schattenkante).
func _recolor(img: Image, target: Color, keep_rim: bool = true) -> Image:
	var out := img.duplicate()
	var ref := _dominant(img)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c.v < 0.3:
				continue
			if keep_rim and ((c.s < 0.25 and c.v > 0.7) or (c.h > 0.1 and c.h < 0.2 and c.s > 0.45 and c.v > 0.85)):
				continue
			var v := clampf(target.v * c.v / ref.v, 0.0, 1.0)
			out.set_pixel(x, y, Color.from_hsv(target.h, target.s, v, c.a))
	return out


## Gelben Hover-Rand des Packs auf einen umgefärbten Knopf legen.
func _hovered(img: Image, hover: Image) -> Image:
	var out := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var c := hover.get_pixel(x, y)
			if c.a > 0.5 and c.h > 0.1 and c.h < 0.2 and c.s > 0.45 and c.v > 0.85:
				out.set_pixel(x, y, c)
	return out


## Alles außer dem Umriss grau und dunkel (deaktivierte Knöpfe).
func _grey(img: Image, level: float) -> Image:
	var out := img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c.v < 0.3:
				continue
			out.set_pixel(x, y, Color.from_hsv(0.62, 0.12, c.v * level, c.a))
	return out


## Graustufen-Füllung zum Einfärben per modulate (Balken).
func _white(img: Image) -> Image:
	var out := img.duplicate()
	var ref := _dominant(img)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var v := clampf(c.v / ref.v, 0.0, 1.25) * 0.8
			out.set_pixel(x, y, Color(v, v, v, c.a))
	return out


# ================================================================ Oberfläche

func _ui() -> void:
	var b := UPD + "UI/Buttons/"
	var blue := _load(b + "Button_Blue_9Slides.png")
	var blue_p := _load(b + "Button_Blue_9Slides_Pressed.png")
	var hover := _load(b + "Button_Hover_9Slides.png")
	var red := _load(b + "Button_Red_9Slides.png")
	var red_p := _load(b + "Button_Red_9Slides_Pressed.png")
	var off := _load(b + "Button_Disable_9Slides.png")
	# Dunkle Knöpfe für helle Schrift, Gold für Hauptaktionen, Rot für Gefahr
	var slate := Color("#3b5667")
	var gold := Color("#d9a441")
	var sel := Color("#4e4a33")
	var sets := {
		"btn": [_recolor(blue, slate), _hovered(_recolor(blue, Color("#46657a")), hover), _recolor(blue_p, Color("#2f4757"))],
		"btn_primary": [_recolor(blue, gold), _hovered(_recolor(blue, Color("#e8b850")), hover), _recolor(blue_p, Color("#bf8d33"))],
		"btn_danger": [_recolor(red, Color("#9c4a48")), _hovered(_recolor(red, Color("#ad5450")), hover), _recolor(red_p, Color("#82403f"))],
		"btn_sel": [_hovered(_recolor(blue, sel), hover), _hovered(_recolor(blue, Color("#5a5539")), hover), _recolor(blue_p, sel)],
	}
	for k in sets:
		_save(_half(sets[k][0]), "ui/%s" % k)
		_save(_half(sets[k][1]), "ui/%s_hover" % k)
		_save(_half(sets[k][2]), "ui/%s_pressed" % k)
	_save(_half(_grey(off, 0.42)), "ui/btn_disabled")
	# Geschnitzte Fläche (Reiter, Etiketten), dunkel gebeizt
	var carved := _load(UPD + "UI/Banners/Carved_9Slides.png")
	_save(_half(_recolor(carved, Color("#6b5a4a"), false)), "ui/carved")
	_save(_half(_recolor(carved, Color("#8a6e4c"), false)), "ui/carved_active")
	# Papier mit Goldornament (Karten, Dialoge, Hinweise)
	var f := FREE + "UI Elements/UI Elements/"
	var cells := [[0, 64], [128, 192], [256, 320]]
	var paper := _assemble(_load(f + "Papers/SpecialPaper.png"), cells, cells)
	_save(paper, "ui/paper")
	_save(_half(paper), "ui/paper_small")
	var big := [[0, 128], [192, 256], [320, 448]]
	var wood := _assemble(_load(f + "Wood Table/WoodTable.png"), big, big)
	_save(wood, "ui/wood")
	_save(_half(wood), "ui/wood_small")
	var banner := _assemble(_load(f + "Banners/Banner.png"), big, big)
	_save(_half(banner), "ui/parchment")
	# Bänder (3-Slice) für Überschriften
	for c in ["Yellow", "Red", "Blue"]:
		_save(_half(_load(UPD + "UI/Ribbons/Ribbon_%s_3Slides.png" % c)), "ui/ribbon_%s" % c.to_lower())
	# Balken: Holzrahmen und hellgraue Füllung zum Einfärben
	var bar := _assemble(_load(f + "Bars/BigBar_Base.png"), cells, [[0, 64]])
	_save(_half(bar), "ui/bar")
	_save(_half(_white(_load(f + "Bars/BigBar_Fill.png"))), "ui/bar_fill")


# ================================================================ Gelände

## Klippen-Block des Tilesets (erhöhte Fläche, rechts): 4 Spalten (links,
## Mitte, rechts, einzeln) x 6 Reihen (oben, Mitte, unten, einzeln, Felswand,
## Felswand am Wasser). Für jede Etage umgefärbt: Oberseite = Fels von oben,
## Wand = Mauerwerk zum Raum hin.
const WALLS := {
	1: {"top": "#5d4c4b", "face": "#6f9a98", "rim": "#a99a8a"},
	2: {"top": "#4d5262", "face": "#8e979c", "rim": "#a3a9b5"},
	3: {"top": "#4f6a45", "face": "#58806f", "rim": "#9fbf8a"},
}


func _is_grass(c: Color) -> bool:
	return c.h > 0.1 and c.h < 0.36 and c.s > 0.28 and c.v >= 0.3


func _is_stone(c: Color) -> bool:
	return c.h > 0.4 and c.h < 0.6 and c.s > 0.12 and c.v >= 0.3 and c.v < 0.9


func _is_rim(c: Color) -> bool:
	return c.h > 0.3 and c.h < 0.5 and c.s <= 0.3 and c.v >= 0.85


## Pixel einer Klasse umfärben, Helligkeit relativ zur Hauptfarbe der Klasse.
func _recolor_where(img: Image, pred: Callable, target: Color, contrast: float = 1.0) -> void:
	var count := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and pred.call(c):
				var k := c.to_html()
				count[k] = int(count.get(k, 0)) + 1
	var ref_k := ""
	for k in count:
		if ref_k == "" or count[k] > count[ref_k]:
			ref_k = k
	if ref_k == "":
		return
	var ref := Color.html(ref_k)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and pred.call(c):
				var k := 1.0 + contrast * (c.v / ref.v - 1.0)
				img.set_pixel(x, y, Color.from_hsv(target.h, target.s, clampf(target.v * k, 0.0, 1.0), c.a))


func _terrain() -> void:
	var t := FREE + "Terrain/Tileset/"
	var block := _load(t + "Tilemap_color1.png").get_region(Rect2i(320, 0, 256, 384))
	for fl in WALLS:
		var w: Dictionary = WALLS[fl]
		var img := block.duplicate()
		_recolor_where(img, _is_grass, Color(w.top), 1.8)
		_recolor_where(img, _is_stone, Color(w.face))
		_recolor_where(img, _is_rim, Color(w.rim))
		_save(img, "terrain/wall_%d" % fl)
	for i in [1, 2, 3, 4, 5]:
		var img := _load(t + "Tilemap_color%d.png" % i)
		_save(img, "terrain/tilemap_%d" % i)
	_save(_load(t + "Water Foam.png"), "terrain/foam")
	_save(_load(t + "Shadow.png"), "terrain/shadow")
	var w := _load(t + "Water Background color.png")
	_save(w, "terrain/water")
	for i in [1, 2, 3, 4]:
		_save(_load(FREE + "Terrain/Decorations/Rocks/Rock%d.png" % i), "terrain/rock_%d" % i)
		_save(_load(FREE + "Terrain/Decorations/Bushes/Bushe%d.png" % i), "terrain/bush_%d" % i)


# ================================================================ Effekte

func _fx() -> void:
	var p := FREE + "Particle FX/"
	for n in ["Explosion_01", "Explosion_02", "Fire_01", "Fire_02", "Fire_03", "Dust_01", "Dust_02", "Water Splash"]:
		_save(_load(p + n + ".png"), "fx/" + n.to_lower().replace(" ", "_"))
