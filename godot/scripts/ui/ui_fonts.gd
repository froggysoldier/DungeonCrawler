class_name UiFonts
extends RefCounted
## Montserrat (SIL Open Font License) in allen benötigten Stärken.
## Die Schriftdatei ist variabel; die Stärke wird über die Achse „wght“ gewählt.

static var _base: FontFile
static var _base_italic: FontFile
static var _cache: Dictionary = {}


static func _load(path: String) -> FontFile:
	var f = load(path)
	if f is FontFile:
		return f
	# Ohne Import (z. B. frisch geklont): Datei direkt lesen
	var ff := FontFile.new()
	ff.load_dynamic_font(ProjectSettings.globalize_path(path))
	return ff


## Schrift mit Stärke (400 normal, 500, 600, 700 fett, 800 extra fett).
static func get_font(weight: int = 400, is_italic: bool = false, spacing: int = 0) -> Font:
	var key := weight * 2 + (1 if is_italic else 0) + spacing * 10000
	var f = _cache.get(key)
	if f != null:
		return f
	if _base == null:
		_base = _load("res://assets/fonts/Montserrat.woff2")
		_base_italic = _load("res://assets/fonts/Montserrat-Italic.woff2")
	var v := FontVariation.new()
	v.base_font = _base_italic if is_italic else _base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	if spacing != 0:
		v.spacing_glyph = spacing
	_cache[key] = v
	return v


static var _pixel_base: FontFile


## Pixelify Sans (SIL Open Font License) für Titel, Knöpfe und die Karte.
## Scharf bei Größen in Zehnerschritten: ein Schriftpixel ist 1/10 der Größe.
static func pixel(weight: int = 400, spacing: int = 0) -> Font:
	var key := -weight - spacing * 10000
	var f = _cache.get(key)
	if f != null:
		return f
	if _pixel_base == null:
		_pixel_base = _load("res://assets/fonts/PixelifySans.ttf")
	var v := FontVariation.new()
	v.base_font = _pixel_base
	var ts := TextServerManager.get_primary_interface()
	v.variation_opentype = {ts.name_to_tag("wght"): clampi(weight, 400, 700)}
	# Ohne Ligaturen: „fl“ sähe in Pixelify sonst wie „A“ aus
	v.opentype_features = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0, ts.name_to_tag("dlig"): 0}
	if spacing != 0:
		v.spacing_glyph = spacing
	_cache[key] = v
	return v
