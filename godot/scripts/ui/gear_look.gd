class_name GearLook
extends RefCounted
## Sichtbare Ausrüstung über der Spielfigur (blauer Arbeiter aus dem Pack).
## Jedes Teil ist eine kleine Zeichnung im Stil des Packs (TsRender, feiner
## Umriss), in der Farbe seiner Seltenheit. Es hängt an einem Ankerpunkt der
## Figur (Kopf, Körper, linke/rechte Hand, linker/rechter Fuß) und wandert in
## jedem Ruhe- und Laufbild mit (Ankerpunkte: assets/tinyswords/anker.json).
## Koordinaten der Formen beziehen sich auf das erste Ruhebild (128 x 128).

const BASE := "kreatur/spieler_pawn"
const SIZE := 128

## Form je Gegenstand; ohne Eintrag gilt die erste Form des Platzes.
const VARIANT_OF := {
	"wollmuetze": "muetze", "bauhelm": "helm", "kochtopf": "helm", "cap": "cap", "kronkorkenkrone": "krone",
	"fahrradhelm": "helm", "aluhut": "spitzhut", "cowboyhut": "hut", "feuerwehrhelm": "helm", "partyhut": "spitzhut",
	"pfandkrone": "krone", "offiziersmuetze": "cap", "rostkrone": "krone", "stirnband": "band",
	"sonnenbrille": "brille", "taucherbrille": "schutzbrille", "brille": "brille", "skibrille": "schutzbrille",
	"clownsnase": "nase", "sturmhaube": "maske", "monokel": "brille", "gasmaske": "maske", "goldzahn": "nase",
	"lederjacke": "jacke", "warnweste": "weste", "bademantel": "mantel", "schlafanzug": "mantel", "anzug": "jacke",
	"arbeitsjacke": "jacke", "sportshirt": "shirt", "tshirt": "shirt", "hemd": "shirt", "bluse": "shirt",
	"pullover": "shirt", "kleid": "mantel", "winterjacke": "jacke", "uniformjacke": "jacke",
	"rucksack": "rucksack", "laptoptasche": "rucksack", "superheldenumhang": "umhang", "wanderrucksack": "rucksack",
	"gitarrenkoffer": "rucksack", "mottenfluegel_umhang": "umhang", "duschvorhang_mantel": "umhang", "oelkanister_rucksack": "rucksack",
	"bratpfanne": "pfanne", "kochmesser": "messer", "handtasche": "tasche", "handtasche_der_sammlerin": "tasche",
	"rohrzange": "werkzeug", "schraubenschluessel": "werkzeug", "brecheisen": "werkzeug",
	"schal": "schal", "kopfhoerer": "schal",
}

## Formen je Platz (erste = Standard) und ihr Ankerpunkt.
const SLOTS := {
	"ruecken": {"anchor": "koerper", "behind": true, "variants": ["umhang", "rucksack"]},
	"beine": {"anchor": "fuss", "variants": ["hose"]},
	"fuesse": {"anchor": "fuss", "variants": ["stiefel"]},
	"brust": {"anchor": "koerper", "variants": ["jacke", "shirt", "mantel", "weste"]},
	"guertel": {"anchor": "koerper", "variants": ["guertel"]},
	"hals": {"anchor": "koerper", "variants": ["kette", "schal"]},
	"schultern": {"anchor": "koerper", "variants": ["polster"]},
	"arme": {"anchor": "hand", "variants": ["schiene"]},
	"haende": {"anchor": "hand", "variants": ["handschuh"]},
	"kopf": {"anchor": "kopf", "variants": ["helm", "muetze", "cap", "hut", "spitzhut", "krone", "band"]},
	"gesicht": {"anchor": "kopf", "variants": ["brille", "schutzbrille", "maske", "nase"]},
	"waffe": {"anchor": "rh", "variants": ["schlaeger", "werkzeug", "messer", "pfanne", "tasche"]},
}

## Zeichenreihenfolge über der Figur (der Rücken liegt darunter).
const ORDER := ["beine", "fuesse", "brust", "guertel", "hals", "schultern", "arme", "haende_l", "kopf", "gesicht", "waffe", "haende_r"]

static var _anchors := {}
static var _pieces := {}


static func anchors() -> Dictionary:
	if _anchors.is_empty():
		var f := FileAccess.open("res://assets/tinyswords/anker.json", FileAccess.READ)
		if f != null:
			_anchors = JSON.parse_string(f.get_as_text())
	return _anchors


static func variant(slot: String, base_id: String) -> String:
	var v: String = VARIANT_OF.get(base_id, "")
	var list: Array = SLOTS[slot].variants
	return v if v in list else list[0]


## Halbe Ellipse als Vieleck (Kuppel), Grundlinie bei base.
static func dome(cx: float, base: float, rx: float, ry: float) -> Array:
	var pts: Array = []
	for i in 17:
		var a := PI * i / 16.0
		pts.append(cx + rx * cos(a))
		pts.append(base - ry * sin(a))
	return pts


## Formen eines Teils; Hände und Füße als [links, rechts].
static func shapes(slot: String, v: String) -> Variant:
	var hands := [Vector2(46, 110), Vector2(82, 107)]
	var feet := [Vector2(58.7, 118.6), Vector2(70.1, 117.8)]
	match slot:
		"kopf":
			match v:
				"helm":
					return [["p", dome(63, 80, 27, 25), "T"], ["r", 35, 76, 57, 6, 3, "T"], ["d", 50, 68, 1.5, "w"], ["d", 63, 62, 1.5, "w"], ["d", 76, 68, 1.5, "w"]]
				"muetze":
					return [["e", 63, 52, 5, 5, "TL"], ["p", dome(63, 80, 25, 24), "T"], ["r", 37, 74, 53, 8, 3, "TL"]]
				"cap":
					return [["e", 87, 79, 13, 4, "t"], ["p", dome(62, 80, 24, 20), "T"], ["d", 62, 62, 2, "TL"]]
				"hut":
					return [["r", 46, 50, 34, 26, 8, "T"], ["r", 46, 66, 34, 5, 1, "t"], ["e", 63, 76, 35, 6, "T"]]
				"spitzhut":
					return [["p", [44, 80, 84, 80, 68, 34], "T"], ["e", 68, 33, 4, 4, "Y"], ["d", 58, 70, 2, "w"], ["d", 70, 58, 2, "w"], ["d", 74, 74, 2, "w"]]
				"krone":
					return [["p", [44, 74, 44, 58, 51, 66, 57, 54, 63, 64, 70, 54, 76, 66, 82, 58, 82, 74], "T"], ["d", 57, 68, 2, "R"], ["d", 70, 68, 2, "c"]]
				"band":
					return [["l", 40, 84, 30, 92, 4, "T"], ["l", 40, 84, 32, 80, 4, "T"], ["r", 38, 80, 52, 7, 3, "T"]]
		"gesicht":
			match v:
				"brille":
					return [["e", 68, 96, 4.5, 4, "T"], ["e", 81, 95, 4.5, 4, "T"], ["d", 68, 96, 2.5, "c"], ["d", 81, 95, 2.5, "c"], ["dl", 72, 95, 77, 95, "k"]]
				"schutzbrille":
					return [["r", 38, 92, 50, 4, 1, "t"], ["e", 69, 95, 6, 5, "T"], ["e", 82, 94, 6, 5, "T"], ["d", 69, 95, 3.5, "c"], ["d", 82, 94, 3.5, "c"]]
				"maske":
					return [["r", 62, 98, 27, 9, 4, "T"], ["d", 74, 102, 2, "t"]]
				"nase":
					return [["e", 87, 99, 3.5, 3.5, "T"]]
		"brust":
			match v:
				"jacke":
					return [["r", 44, 103, 43, 14, 5, "T"], ["p", [58, 103, 66, 103, 62, 109], "TL"], ["p", [66, 103, 74, 103, 70, 109], "TL"], ["dl", 66, 105, 66, 116, "k"]]
				"shirt":
					return [["r", 45, 104, 41, 12, 5, "T"], ["d", 70, 110, 2.5, "w"]]
				"mantel":
					return [["p", [44, 103, 87, 103, 90, 120, 41, 120], "T"], ["r", 44, 110, 44, 3, 1, "t"]]
				"weste":
					return [["r", 44, 103, 43, 14, 5, "T"], ["dl", 46, 108, 85, 108, "Y"], ["dl", 46, 113, 85, 113, "Y"]]
		"schultern":
			return [["e", 47, 105, 7, 4.5, "T"], ["e", 84, 104, 7, 4.5, "T"], ["d", 47, 104, 1.2, "w"], ["d", 84, 103, 1.2, "w"]]
		"guertel":
			return [["r", 44, 112, 43, 4, 2, "T"], ["r", 63, 111, 6, 6, 1, "y"]]
		"hals":
			match v:
				"kette":
					return [["dl", 57, 104, 66, 109, "y"], ["dl", 75, 104, 66, 109, "y"], ["e", 66, 111, 3, 3, "T"]]
				"schal":
					return [["r", 54, 100, 28, 6, 3, "T"], ["l", 58, 104, 56, 115, 4, "T"]]
		"ruecken":
			match v:
				"umhang":
					return [["p", [52, 99, 40, 103, 31, 116, 34, 122, 64, 122, 66, 106], "T"], ["l", 48, 106, 38, 118, 2, "t", "n"]]
				"rucksack":
					return [["r", 30, 92, 18, 22, 4, "T"], ["r", 30, 92, 18, 8, 3, "t"], ["d", 39, 103, 1.5, "y"]]
		"waffe":
			var h: Vector2 = hands[1]
			match v:
				"schlaeger":
					return [["l", h.x + 2, h.y + 3, h.x + 18, h.y - 30, 5, "T"], ["l", h.x + 1, h.y + 5, h.x + 4, h.y - 1, 4, "D"]]
				"werkzeug":
					return [["l", h.x + 2, h.y + 4, h.x + 14, h.y - 24, 4, "T"], ["p", [h.x + 8, h.y - 26, h.x + 20, h.y - 30, h.x + 22, h.y - 22, h.x + 14, h.y - 20], "T"]]
				"messer":
					return [["l", h.x + 1, h.y + 4, h.x + 4, h.y - 3, 4, "D"], ["p", [h.x + 1, h.y - 3, h.x + 8, h.y - 3, h.x + 14, h.y - 26, h.x + 6, h.y - 16], "T"]]
				"pfanne":
					return [["l", h.x + 2, h.y + 3, h.x + 10, h.y - 14, 3, "D"], ["e", h.x + 15, h.y - 23, 9, 8, "T"], ["d", h.x + 15, h.y - 23, 4.5, "K"]]
				"tasche":
					return [["l", h.x, h.y - 2, h.x + 6, h.y - 8, 2, "D"], ["l", h.x + 6, h.y - 8, h.x + 12, h.y - 2, 2, "D"], ["r", h.x - 1, h.y - 2, 16, 13, 4, "T"]]
		"haende":
			return hands.map(func(p): return [["e", p.x, p.y + 1, 4.5, 4.5, "T"]])
		"arme":
			return hands.map(func(p): return [["r", p.x - 5, p.y - 6, 10, 4, 2, "T"]])
		"beine":
			return feet.map(func(p): return [["r", p.x - 5, p.y - 5, 10, 5, 2, "T"]])
		"fuesse":
			return feet.map(func(p): return [["e", p.x + 1, p.y + 2, 5.5, 3, "T"]])
	return []


## Teil gezeichnet (Tönstufen noch magenta), zwischengespeichert.
static func _piece(slot: String, v: String) -> Array:
	var key := slot + "/" + v
	if not _pieces.has(key):
		var sh: Variant = shapes(slot, v)
		var imgs: Array = []
		if slot in ["haende", "arme", "beine", "fuesse"]:
			for part in sh:
				imgs.append(TsRender.render(part, SIZE, true))
		else:
			imgs.append(TsRender.render(sh, SIZE, true))
		_pieces[key] = imgs
	return _pieces[key]


static func _tinted(img: Image, color: String) -> Image:
	var out := img.duplicate() as Image
	var ramp := PixelArt.ramp(Color(color))
	var keys: Array = PixelArt.TINT_KEYS.map(func(k): return Color(k))
	for y in out.get_height():
		for x in out.get_width():
			var c := out.get_pixel(x, y)
			if c.a < 0.5:
				continue
			for i in keys.size():
				if c.is_equal_approx(keys[i]):
					out.set_pixel(x, y, ramp[i])
					break
	return out


## Versatz eines Ankerpunkts in einem Bild gegenüber dem ersten Ruhebild.
static func _offset(frame: String, anchor: String) -> Vector2i:
	var a: Dictionary = anchors()
	var f: Dictionary = a.get(frame, {})
	var f0: Dictionary = a.get(BASE, {})
	if f.is_empty() or f0.is_empty():
		return Vector2i.ZERO
	var p: Array = f[anchor]
	var p0: Array = f0[anchor]
	return Vector2i(roundi(p[0] - p0[0]), roundi(p[1] - p0[1]))


## Alle Bilder der Spielfigur mit Ausrüstung (gear: Platz -> [Form, Farbe]).
static func compose(gear: Dictionary) -> Dictionary:
	var layers := {}
	for slot in gear:
		var imgs := _piece(slot, gear[slot][0]).map(func(i): return _tinted(i, gear[slot][1]))
		if imgs.size() == 2:
			var single := {"haende": "hand", "arme": "hand", "beine": "fuss", "fuesse": "fuss"}
			var kind: String = single[slot]
			var left := "lh" if kind == "hand" else "lf"
			var right := "rh" if kind == "hand" else "rf"
			if slot == "haende":
				layers["haende_l"] = [imgs[0], left]
				layers["haende_r"] = [imgs[1], right]
			else:
				layers[slot] = [imgs[0], left, imgs[1], right]
		else:
			layers[slot] = [imgs[0], SLOTS[slot].anchor]
	var out := {}
	var frames: Array = [BASE]
	for i in range(2, PixelArt.frame_count(BASE) + 1):
		frames.append("%s_%d" % [BASE, i])
	for i in range(1, PixelArt.run_count(BASE) + 1):
		frames.append("%s_lauf%d" % [BASE, i])
	for tag in ["angriff", "treffer"]:
		for i in range(1, PixelArt.seq_count(BASE, tag) + 1):
			frames.append("%s_%s%d" % [BASE, tag, i])
	for fr in frames:
		var base := PixelArt.image(fr)
		# Angriffsbilder liegen auf einer größeren Fläche; die Anker gleichen das aus
		var img := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
		if layers.has("ruecken"):
			_blend(img, layers.ruecken, fr)
		img.blend_rect(base, Rect2i(Vector2i.ZERO, base.get_size()), Vector2i.ZERO)
		for key in ORDER:
			if layers.has(key):
				_blend(img, layers[key], fr)
		out[fr] = img
	return out


static func _blend(img: Image, layer: Array, frame: String) -> void:
	var i := 0
	while i < layer.size():
		var src: Image = layer[i]
		var off := _offset(frame, layer[i + 1])
		img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), off)
		i += 2
