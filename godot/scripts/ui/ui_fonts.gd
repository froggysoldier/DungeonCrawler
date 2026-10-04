class_name UiFonts
extends RefCounted
## Schrift des Spiels: Jersey 10 (SIL Open Font License), eine kräftige
## Pixelschrift im Stil von Tiny Swords, für Titel, Knöpfe, Werte, Chat und
## Texte. Es gibt sie nur in einer Stärke; fett ist leicht verstärkt, kursiv
## geneigt. Fehlende Zeichen kommen aus Montserrat.
## Jersey 10 wirkt bei gleicher Punktzahl kleiner als eine normale Schrift:
## px() rechnet die Größen der Oberfläche um.

const SCALE := 1.45

static var _base: FontFile
static var _cache: Dictionary = {}


static func _load(path: String) -> FontFile:
	var f = load(path)
	if f is FontFile:
		return f
	# Ohne Import (z. B. frisch geklont): Datei direkt lesen
	var ff := FontFile.new()
	ff.load_dynamic_font(ProjectSettings.globalize_path(path))
	return ff


static func _jersey() -> FontFile:
	if _base == null:
		_base = _load("res://assets/fonts/Jersey10.ttf")
		_base.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_base.hinting = TextServer.HINTING_NONE
		_base.fallbacks = [_load("res://assets/fonts/Montserrat.woff2")]
	return _base


## Schriftgröße der Oberfläche (in der Größe einer normalen Schrift gedacht).
static func px(size: float) -> int:
	return roundi(size * SCALE)


## Schrift mit Stärke (ab 600 fett), kursiv, Zeichenabstand.
static func get_font(weight: int = 400, is_italic: bool = false, spacing: int = 0) -> Font:
	var key := weight * 2 + (1 if is_italic else 0) + spacing * 10000
	var f = _cache.get(key)
	if f != null:
		return f
	var v := FontVariation.new()
	v.base_font = _jersey()
	if weight >= 600:
		v.variation_embolden = 0.35
	if is_italic:
		v.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	if spacing != 0:
		v.spacing_glyph = spacing
	_cache[key] = v
	return v


## Dieselbe Schrift für Titel, Knöpfe und die Karte (früher eine eigene).
static func pixel(weight: int = 400, spacing: int = 0) -> Font:
	return get_font(weight, false, spacing)
