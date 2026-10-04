class_name PixelArt
extends RefCounted
## Pixel-Grafik: Bögen aus res://assets/pixel (PNG, in jedem Pixel-Editor
## bearbeitbar) plus index.json mit der Lage jedes Bildes.
##
## Tönbare Stellen sind in den Bögen mit fünf Magenta-Stufen markiert
## (TINT_KEYS). Beim Zeichnen werden sie durch eine Farbrampe aus der Farbe des
## Monsters (oder der Seltenheit) ersetzt. Eine Kachel ist 32 Pixel groß.

const TILE := 32
const DIR := "res://assets/pixel"

## Palette der Vorlagen (Zeichen in den Definitionen von tools/make_pixel_art.gd),
## abgestimmt auf den Stil von Tiny Swords (Pixel Frog): Kontur in dunklem
## Nachtblau statt Schwarz, gedämpfte, leicht entsättigte Farben, Pergament-
## und Holztöne, Türkis statt reinem Blau.
const PALETTE := {
	"k": "#161c2e", "K": "#2a2f45", "n": "#404e75", "N": "#5e6f86", "g": "#8c9a9d", "G": "#c8cdbf", "w": "#f6f2e1",
	"r": "#8d4848", "R": "#d65f5c", "o": "#d9945f", "y": "#dcaa46", "Y": "#f1d867",
	"l": "#9bb94e", "L": "#5da067", "e": "#385655", "E": "#28393f",
	"b": "#485884", "B": "#4697ac", "c": "#8cc3c4",
	"p": "#693d5b", "P": "#ab6e9c", "f": "#e0877e",
	"s": "#ecc89c", "S": "#cf9c71", "u": "#b4634e", "U": "#cf8a5a", "d": "#866353", "D": "#4d3f45",
	"h": "#efe1ab", "H": "#d5b583", "x": "#e76161",
}

## Magenta-Stufen für tönbare Stellen: Schatten, dunkel, Grundfarbe, hell, Glanz.
const TINT_KEYS := ["#400040", "#800080", "#c000c0", "#ff00ff", "#ff80ff"]

static var _index: Dictionary = {}
static var _sheets: Dictionary = {}
static var _images: Dictionary = {}
static var _tinted: Dictionary = {}
## Zur Laufzeit zusammengesetzte Bilder (Spielfigur mit Ausrüstung): Name -> Image.
static var _runtime: Dictionary = {}
static var _runtime_res: Dictionary = {}


static func _load() -> void:
	if not _index.is_empty():
		return
	var f := FileAccess.open(DIR + "/index.json", FileAccess.READ)
	if f == null:
		push_error("Pixel-Index fehlt: %s/index.json" % DIR)
		return
	_index = JSON.parse_string(f.get_as_text())


static func has(name: String) -> bool:
	_load()
	return _index.has(name) or _runtime.has(name)


static var _counts := {}


## Anzahl der Ruhebilder einer Figur (Name, Name_2, Name_3 …).
static func frame_count(name: String) -> int:
	var key := "r|" + name
	if not _counts.has(key):
		var n := 1 if has(name) else 0
		while has("%s_%d" % [name, n + 1]):
			n += 1
		_counts[key] = n
	return _counts[key]


## Anzahl der Laufbilder (Name_lauf1 …).
static func run_count(name: String) -> int:
	var key := "l|" + name
	if not _counts.has(key):
		var n := 0
		while has("%s_lauf%d" % [name, n + 1]):
			n += 1
		_counts[key] = n
	return _counts[key]


## Ein zur Laufzeit gebautes Bild unter einem Namen bereitstellen; danach geht
## es wie jedes Bild aus den Bögen (Tönen, Silhouette, Zeichnen).
static func register(name: String, img: Image, res: int = 1) -> void:
	_runtime[name] = img
	_runtime_res[name] = res


static func names(prefix: String = "") -> Array:
	_load()
	return _index.keys().filter(func(k): return String(k).begins_with(prefix))


static func sheet(sheet_name: String) -> Texture2D:
	if not _sheets.has(sheet_name):
		_sheets[sheet_name] = load("%s/%s.png" % [DIR, sheet_name])
	return _sheets[sheet_name]


static func _image(sheet_name: String) -> Image:
	if not _images.has(sheet_name):
		var tex := sheet(sheet_name)
		var img: Image = tex.get_image() if tex else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		_images[sheet_name] = img
	return _images[sheet_name]


## Lage eines Bildes: {sheet, rect}.
static func entry(name: String) -> Dictionary:
	_load()
	var e = _index.get(name)
	if e == null:
		return {}
	return {"sheet": e.sheet, "rect": Rect2i(int(e.x), int(e.y), int(e.w), int(e.h)), "res": int(e.get("res", 1))}


## Bildpixel je Kunstpixel: 1 für die 32er-Grafik, 2 für Figuren im
## Tiny-Swords-Stil (feiner gezeichnet, gleich groß auf dem Bildschirm).
static func res(name: String) -> int:
	if _runtime.has(name):
		return _runtime_res.get(name, 1)
	var e := entry(name)
	return e.get("res", 1) if not e.is_empty() else 1


## Größe in Kunstpixeln (bei feinen Figuren die halbe Bildgröße).
static func size_of(name: String) -> Vector2i:
	if _runtime.has(name):
		return (_runtime[name] as Image).get_size() / int(_runtime_res.get(name, 1))
	var e := entry(name)
	return e.rect.size / int(e.res) if not e.is_empty() else Vector2i.ZERO


## Einzelbild als Image (für Rahmen und Werkzeuge).
static func image(name: String) -> Image:
	if _runtime.has(name):
		return (_runtime[name] as Image).duplicate()
	var e := entry(name)
	if e.is_empty():
		return null
	var img := _image(e.sheet)
	return img.get_region(e.rect) if img else null


# ---------------------------------------------------------------- Tönen

static func _shift_hue(h: float, target: float, amount: float) -> float:
	var d := target - h
	if d > 0.5:
		d -= 1.0
	elif d < -0.5:
		d += 1.0
	return fposmod(h + clampf(d, -amount, amount), 1.0)


## Farbrampe aus einer Grundfarbe im Stil von Tiny Swords: die Mitte ist die
## Grundfarbe selbst, Schatten (etwas entsättigt) gehen zum Nachtblau der
## Kontur, Licht zu warmem Creme.
static func ramp(base: Color) -> Array:
	var b := base
	var navy := Color("#161c2e")
	var cream := Color("#fff4d0")
	return [
		b.lerp(navy, 0.62),
		b.lerp(navy, 0.32),
		b,
		b.lerp(cream, 0.28),
		b.lerp(cream, 0.55),
	]


static func _to_color(c: Variant) -> Color:
	if c is Color:
		return c
	var t := String(c)
	if t.length() == 7 and t.begins_with("#"):
		return Color(t)
	return Color("#a39a8c")


## Textur eines Bildes, tönbare Stellen in der gegebenen Farbe. Ohne Farbe
## bleiben sie grau. Ergebnis wird zwischengespeichert.
static func texture(name: String, tint: Variant = null) -> Texture2D:
	var key := "%s|%s" % [name, str(tint)]
	if _tinted.has(key):
		return _tinted[key]
	var img := image(name)
	if img == null:
		_tinted[key] = null
		return null
	var cols := ramp(_to_color(tint if tint != null else "#8b9bb4"))
	var keys: Array = TINT_KEYS.map(func(k): return Color(k))
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a < 0.5:
				continue
			for i in keys.size():
				if p.is_equal_approx(keys[i]):
					img.set_pixel(x, y, Color(cols[i], p.a))
					break
	var tex := ImageTexture.create_from_image(img)
	_tinted[key] = tex
	return tex


## Weiße Silhouette eines Bildes (Aufblitzen bei Treffern).
static func silhouette(name: String) -> Texture2D:
	var key := "%s|weiss" % name
	if _tinted.has(key):
		return _tinted[key]
	var img := image(name)
	if img == null:
		return null
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_tinted[key] = tex
	return tex


static var _pixel_lists := {}


## Alle sichtbaren Pixel eines getönten Bildes als [Vector2i, Color] (zum Zerfallen).
static func pixels(name: String, tint: Variant = null) -> Array:
	var key := "%s|%s" % [name, str(tint)]
	if _pixel_lists.has(key):
		return _pixel_lists[key]
	var out: Array = []
	var tex := texture(name, tint)
	if tex != null:
		var img := tex.get_image()
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					out.append([Vector2i(x, y), c])
	_pixel_lists[key] = out
	return out


# ---------------------------------------------------------------- Zeichnen

## Zeichnet ein Bild mit linker oberer Ecke bei pos (Bildschirmpixel), skaliert
## um den ganzzahligen Faktor scale. flip spiegelt waagerecht.
static func draw(ci: CanvasItem, name: String, pos: Vector2, scale: int, tint: Variant = null, flip: bool = false, modulate: Color = Color.WHITE) -> void:
	draw_texture(ci, texture(name, tint), pos, scale, flip, modulate, res(name))


## Eine fertige Textur ganzzahlig vergrößert zeichnen (auch gespiegelt);
## res: Bildpixel je Kunstpixel.
static func draw_texture(ci: CanvasItem, tex: Texture2D, pos: Vector2, scale: int, flip: bool = false, modulate: Color = Color.WHITE, res: int = 1) -> void:
	if tex == null:
		return
	var sz := Vector2(tex.get_size()) * scale / float(res)
	if not flip:
		ci.draw_texture_rect(tex, Rect2(pos.round(), sz), false, modulate)
		return
	# Gespiegelt: über eine Transformation, negative Breiten verschieben das Bild
	ci.draw_set_transform(pos.round() + Vector2(sz.x, 0), 0.0, Vector2(-1, 1))
	ci.draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false, modulate)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Wie draw, aber mittig unten bei foot (Füße der Figur auf der Kachel).
static func draw_foot(ci: CanvasItem, name: String, foot: Vector2, scale: int, tint: Variant = null, flip: bool = false, modulate: Color = Color.WHITE) -> void:
	var sz := size_of(name)
	draw(ci, name, foot - Vector2(sz.x * scale / 2.0, sz.y * scale), scale, tint, flip, modulate)


## Für Tests und Werkzeuge: Zwischenspeicher leeren (nach neuem Erzeugen der Bögen).
static func reset() -> void:
	_index = {}
	_sheets = {}
	_images = {}
	_tinted = {}
	_runtime = {}
	_runtime_res = {}
	_counts = {}
	_pixel_lists = {}
