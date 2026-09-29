class_name Sprites
extends RefCounted
## Welche Pixel-Figur zu welcher Monsterart gehört, welches Bild zu welchem
## Gegenstand, dazu große Porträts (Versus-Bildschirm). Die Bilder liegen in
## res://assets/pixel (kreaturen.png, bosse.png, dinge.png).

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
	"abtruenniger_crawler": "mensch", "morlock": "zombie",
	"wutelementar": "elementar",
	"kanalkroko": "kroko",
	"fischmensch": "fisch", "nixe": "fisch", "kanalkoenigin": "fisch",
	"kanalhexe": "hexe", "kesselkoenigin": "hexe",
	"pilzmensch": "pilz",
	"mottenmann": "motte", "mottenmutter": "motte",
	"taubenschwarm": "vogel",
	"die_sammlerin": "mensch", "der_hausmeister": "mensch", "kammerjaeger": "mensch", "pfandbaron": "mensch", "hausverwalter": "mensch",
}


## Haustier-Art: Bild und Fellfarbe.
const PETS := {
	"Katze": ["katze", "#d08a4a"], "Hund": ["hund", "#a07850"], "Kellerraptor": ["raptor", "#6aa04a"],
	"Minidrache": ["drache", "#c8503a"], "Wolpertinger": ["hase", "#c8a878"], "Fledermaus": ["fledermaus", "#7a6a8a"],
	"Ratte": ["ratte", "#9a8a7a"], "Spinne": ["spinne", "#6a5a7a"],
}


## Bild je Gegenstandsart (ding/…); Ausrüstung zeigt das Symbol ihres Platzes.
const ITEM_SPRITES := {"gold": "gold", "karte": "karte", "box": "truhe", "verbrauch": "trank", "buch": "buch", "schrott": "mutter"}


## Farbe eines Gegenstands: Box-Stufe oder Seltenheit.
static func item_color(it: Dictionary) -> String:
	if it.kind == "box" and it.get("box") != null:
		return Db.world("BOX_TIER_COLORS")[it.box.tier]
	return Db.t("items", "RARITY_COLORS")[it.rarity]


## [Bildname, Farbe] für einen Gegenstand (Karte, Inventar, Tooltips).
static func item_sprite(it: Dictionary) -> Array:
	var col := item_color(it)
	if it.kind == "wurf":
		return ["ding/" + ("bombe" if it.get("explosion") else "stein"), null]
	if it.kind == "verbrauch" and col == "#c8c8c8":
		return ["ding/trank", "#d8604a"]
	if it.get("slot") != null:
		return [slot_sprite(it.slot), col]
	return ["ding/" + ITEM_SPRITES.get(it.kind, "edelstein"), col]


## Symbol eines Ausrüstungsplatzes (ring1/ring2 → Ring, fussring1/2 → Fußring).
static func slot_sprite(slot: String) -> String:
	var base := slot.trim_suffix("1").trim_suffix("2")
	return "ding/slot_" + base if PixelArt.has("ding/slot_" + base) else "ding/edelstein"


## [Bildname, Farbe] für ein Monster, wie es auf der Karte steht.
static func monster_sprite(m: Dictionary) -> Array:
	return [sprite_name(m.defId, m.get("rank") == "geist"), m.color]


## [Bildname, Farbe] für eine Haustier-Art; Unbekanntes wird ein allgemeines Haustier.
static func pet_sprite(species: String) -> Array:
	var e = PETS.get(species)
	return ["kreatur/" + e[0], e[1]] if e != null else ["kreatur/haustier", "#e0a0c8"]


## Voller Bildname einer Monsterart: eigene Boss-Figur, sonst die Kreatur.
static func sprite_name(def_id: String, rank_ghost: bool = false) -> String:
	if not rank_ghost and PixelArt.has("boss/" + def_id):
		return "boss/" + def_id
	return "kreatur/" + sprite_for(def_id, rank_ghost)


static func sprite_for(def_id: String, rank_ghost: bool = false) -> String:
	if rank_ghost:
		return "geist"
	return BY_DEF.get(def_id, "kobold")


## Großes Porträt: Figur (voller Bildname) ganzzahlig vergrößert, Füße mittig
## bei foot. opts: flip, crown (nicht bei eigenen Boss-Figuren), unknown.
static func draw_portrait(ci: CanvasItem, name: String, tint: Variant, foot: Vector2, scale: int, opts: Dictionary = {}) -> void:
	var flip: bool = opts.get("flip", false)
	var sz := PixelArt.size_of(name)
	PixelArt.draw_foot(ci, "aufsatz/schatten", foot + Vector2(0, 3 * scale), scale)
	PixelArt.draw_foot(ci, name, foot, scale, tint, flip)
	var img := PixelArt.image(name)
	var top: int = img.get_used_rect().position.y if img else 0
	var origin := foot - Vector2(sz.x * scale / 2.0, sz.y * scale)
	if opts.get("crown", false) and not name.begins_with("boss/"):
		PixelArt.draw(ci, "aufsatz/krone", origin + Vector2((sz.x / 2 - 4) * scale, (top - 6) * scale), scale)
	if opts.get("unknown", false):
		PixelArt.draw(ci, "aufsatz/frage", origin + Vector2((sz.x - 5) * scale, (top - 3) * scale), scale)


## Die Spielfigur als Porträt (name aus hero_name, sonst ohne Ausrüstung).
static func draw_hero(ci: CanvasItem, foot: Vector2, scale: int, flip: bool = false, name: String = "kreatur/held") -> void:
	PixelArt.draw_foot(ci, "aufsatz/schatten", foot + Vector2(0, 3 * scale), scale)
	PixelArt.draw_foot(ci, name, foot, scale, null, flip)


# ---------------------------------------------------------------- Ausrüstung an der Figur

## Sichtbare Ausrüstungsplätze in Zeichenreihenfolge; GEAR_BEHIND liegt hinter der Figur.
const GEAR_BEHIND := ["ruecken"]
const GEAR_FRONT := ["beine", "fuesse", "brust", "guertel", "hals", "schultern", "arme", "haende", "gesicht", "kopf", "waffe"]
const OUTLINE := Color("#181425")


## Haut- und Haarfarbe je Rasse; ohne Haarfarbe ist der Kopf kahl (Hautfarbe).
## Merkmale (Ohren, Hörner, Schwänze …) liegen als rasse/<id> in kreaturen.png.
const RACE_LOOKS := {
	"halbork": {"skin": "#8fb45a", "hair": "#2a2622"},
	"elf": {"skin": "#f2e0cc", "hair": "#e8dca0"},
	"zwerg": {"skin": "#e0a47e", "hair": "#a8452a"},
	"gnom": {"skin": "#f0c0a0", "hair": "#e8e8f0"},
	"halbling": {"skin": "#e8b08a", "hair": "#7a4a22"},
	"echsenmensch": {"skin": "#5c9a4a", "hair": null},
	"hobgoblin": {"skin": "#c8783a", "hair": "#2a1e18"},
	"katzenmensch": {"skin": "#e8b796", "hair": "#d8843a"},
	"troll": {"skin": "#8a9e7a", "hair": "#4a5a3a"},
	"minotaurus": {"skin": "#8a5a3a", "hair": "#3a2418"},
	"golem": {"skin": "#b8804a", "hair": null},
	"pilzling": {"skin": "#e8dcc0", "hair": null},
	"vampir": {"skin": "#e6e2ee", "hair": "#1c1a2a"},
	"kobold": {"skin": "#b8743a", "hair": null},
	"salamander": {"skin": "#d8603a", "hair": "#f0a030"},
	"rattling": {"skin": "#c8b4a8", "hair": "#8a7a6a"},
	"kelleroger": {"skin": "#b09468", "hair": "#4a3a2a"},
	"schattenwesen": {"skin": "#4a4264", "hair": "#18142a"},
	"wasserspeier": {"skin": "#8e8e96", "hair": null},
	"kellerfee": {"skin": "#f8d8e8", "hair": "#f0a0e0"},
	"ghulblut": {"skin": "#9aaa8a", "hair": "#3a3a30"},
	"blechmensch": {"skin": "#a8b0b8", "hair": null},
	"drachenblut": {"skin": "#e0a070", "hair": "#b03020"},
}


## Bildname der Spielfigur mit Rasse und angelegter Ausrüstung. Die schlichte
## Figur für Menschen ohne sichtbare Ausrüstung; sonst wird sie einmal
## zusammengesetzt (auch das Laufbild „_2“) und unter einem Namen aus Rasse,
## Plätzen und Farben abgelegt.
static func hero_name(p: Dictionary) -> String:
	var eq: Dictionary = J.nn(p, "equipment", {})
	var race := String(p.get("race")) if p.get("race") != null else ""
	if not RACE_LOOKS.has(race):
		race = ""
	var parts: Array = []
	if race != "":
		parts.append("rasse=" + race)
	for slot in GEAR_BEHIND + GEAR_FRONT:
		if eq.get(slot) != null and PixelArt.has("ausruestung/" + slot):
			parts.append("%s=%s" % [slot, item_color(eq[slot])])
	if parts.is_empty():
		return "kreatur/held"
	var name := "kreatur/held@" + ",".join(parts)
	if not PixelArt.has(name):
		PixelArt.register(name, _compose_hero(eq, race, ""))
		PixelArt.register(name + "_2", _compose_hero(eq, race, "_2"))
	return name


static func _compose_hero(eq: Dictionary, race: String, frame: String) -> Image:
	var base := PixelArt.image("kreatur/held" + frame)
	var skin: Variant = null
	if race != "":
		skin = RACE_LOOKS[race].skin
		_recolor(base, RACE_LOOKS[race])
	var img := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
	var extra := {}
	if race != "":
		_overlay(img, "rasse/%s_hinten" % race, frame, skin, extra)
	for slot in GEAR_BEHIND:
		if eq.get(slot) != null:
			_overlay(img, "ausruestung/" + slot, frame, item_color(eq[slot]), extra)
	for y in base.get_height():
		for x in base.get_width():
			var c := base.get_pixel(x, y)
			if c.a > 0.5:
				img.set_pixel(x, y, c)
				extra.erase(Vector2i(x, y))
	if race != "":
		_overlay(img, "rasse/" + race, frame, skin, extra)
	for slot in GEAR_FRONT:
		if eq.get(slot) != null:
			_overlay(img, "ausruestung/" + slot, frame, item_color(eq[slot]), extra)
	# Umriss dort, wo Merkmale oder Ausrüstung über die Figur hinausragen
	var w := img.get_width()
	var h := img.get_height()
	var edge: Array = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if extra.has(Vector2i(x, y) + d):
					edge.append(Vector2i(x, y))
					break
	for q in edge:
		img.set_pixelv(q, OUTLINE)
	return img


## Haut (überall) und Haare (nur oben am Kopf) der Figur in die Farben der Rasse.
static func _recolor(img: Image, look: Dictionary) -> void:
	var pal: Dictionary = PixelArt.PALETTE
	var sr := PixelArt.ramp(Color(look.skin))
	var hr := PixelArt.ramp(Color(look.hair)) if look.hair != null else [sr[1], sr[1], sr[2], sr[3], sr[4]]
	var skin := {Color(pal.s).to_html(false): sr[2], Color(pal.S).to_html(false): sr[1]}
	var hair := {Color(pal.d).to_html(false): hr[2], Color(pal.D).to_html(false): hr[0], Color(pal.U).to_html(false): hr[3]}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var key := c.to_html(false)
			if skin.has(key):
				img.set_pixel(x, y, skin[key])
			elif y <= 3 and hair.has(key):
				img.set_pixel(x, y, hair[key])


## Ein Aufsatz über das Bild (Laufbild „_2“, wenn es eines gibt); merkt sich die Pixel.
static func _overlay(img: Image, n: String, frame: String, tint: Variant, marks: Dictionary) -> void:
	if not PixelArt.has(n):
		return
	if PixelArt.has(n + frame):
		n += frame
	var src := PixelArt.texture(n, tint).get_image()
	for y in mini(src.get_height(), img.get_height()):
		for x in mini(src.get_width(), img.get_width()):
			var c := src.get_pixel(x, y)
			if c.a > 0.5:
				img.set_pixel(x, y, c)
				marks[Vector2i(x, y)] = true
