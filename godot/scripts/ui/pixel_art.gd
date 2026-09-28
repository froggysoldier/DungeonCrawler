class_name PixelArt
extends RefCounted
## Pixel-Grafik: Bögen aus res://assets/pixel (PNG, in jedem Pixel-Editor
## bearbeitbar) plus index.json mit der Lage jedes Bildes.
##
## Tönbare Stellen sind in den Bögen mit fünf Magenta-Stufen markiert
## (TINT_KEYS). Beim Zeichnen werden sie durch eine Farbrampe aus der Farbe des
## Monsters (oder der Seltenheit) ersetzt. Eine Kachel ist 16 Pixel groß.

const TILE := 16
const DIR := "res://assets/pixel"

## Palette der Vorlagen (Zeichen in den Definitionen von tools/make_pixel_art.gd).
const PALETTE := {
	"k": "#181425", "K": "#262b44", "n": "#3a4466", "N": "#5a6988", "g": "#8b9bb4", "G": "#c0cbdc", "w": "#ffffff",
	"r": "#a22633", "R": "#e43b44", "o": "#f77622", "y": "#feae34", "Y": "#fee761",
	"l": "#63c74d", "L": "#3e8948", "e": "#265c42", "E": "#193c3e",
	"b": "#124e89", "B": "#0099db", "c": "#2ce8f5",
	"p": "#68386c", "P": "#b55088", "f": "#f6757a",
	"s": "#e8b796", "S": "#c28569", "u": "#be4a2f", "U": "#d77643", "d": "#733e39", "D": "#3e2731",
	"h": "#ead4aa", "H": "#e4a672", "x": "#ff0044",
}

## Magenta-Stufen für tönbare Stellen: Schatten, dunkel, Grundfarbe, hell, Glanz.
const TINT_KEYS := ["#400040", "#800080", "#c000c0", "#ff00ff", "#ff80ff"]

static var _index: Dictionary = {}
static var _sheets: Dictionary = {}
static var _images: Dictionary = {}
static var _tinted: Dictionary = {}


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
	return _index.has(name)


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
	return {"sheet": e.sheet, "rect": Rect2i(int(e.x), int(e.y), int(e.w), int(e.h))}


static func size_of(name: String) -> Vector2i:
	var e := entry(name)
	return e.rect.size if not e.is_empty() else Vector2i.ZERO


## Einzelbild als Image (für Rahmen und Werkzeuge).
static func image(name: String) -> Image:
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


## Farbrampe aus einer Grundfarbe: Schatten und Dunkel kühler, Licht wärmer.
static func ramp(base: Color) -> Array:
	var h := base.h
	var s := base.s
	var v := base.v
	var warm := 0.13
	var cool := 0.68
	return [
		Color.from_hsv(_shift_hue(h, cool, 0.05), minf(1.0, s * 1.1 + 0.1), v * 0.36),
		Color.from_hsv(_shift_hue(h, cool, 0.03), minf(1.0, s * 1.05 + 0.05), v * 0.62),
		base,
		Color.from_hsv(_shift_hue(h, warm, 0.03), s * 0.85, minf(1.0, v * 1.22 + 0.06)),
		Color.from_hsv(_shift_hue(h, warm, 0.05), s * 0.6, minf(1.0, v * 1.45 + 0.14)),
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


# ---------------------------------------------------------------- Zeichnen

## Zeichnet ein Bild mit linker oberer Ecke bei pos (Bildschirmpixel), skaliert
## um den ganzzahligen Faktor scale. flip spiegelt waagerecht.
static func draw(ci: CanvasItem, name: String, pos: Vector2, scale: int, tint: Variant = null, flip: bool = false, modulate: Color = Color.WHITE) -> void:
	var tex := texture(name, tint)
	if tex == null:
		return
	var sz := Vector2(tex.get_size()) * scale
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
