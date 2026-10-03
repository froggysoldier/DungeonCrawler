class_name Sprites
extends RefCounted
## Welche Pixel-Figur zu welcher Monsterart gehört, welches Bild zu welchem
## Gegenstand, dazu große Porträts (Versus-Bildschirm). Die Bilder liegen in
## res://assets/pixel (kreaturen.png, bosse.png, dinge.png).

const BY_DEF := {
	"kellerratte": "ratte", "rattenmensch": "ratte", "rattenschamane": "ratte", "knochenratte": "ratte", "koenig_kanalratte": "ratte", "rattenkaiser": "ratte",
	"riesenkakerlake": "kakerlake",
	"kobold": "kobold", "kobold_schleuder": "kobold", "elster_goblin": "kobold", "kobold_bombe": "kobold_tnt", "schmuggler": "kobold", "wechselbalg": "kobold",
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
	"rostkaefer": "kakerlake", "oelschleim": "schleim", "abgasgeist": "geist", "parkautomat": "maschine",
	"garagenkatze": "katze", "reifenstapel_mimic": "sack",
	"parkwaechter": "mensch", "rostkoenigin": "maschine", "oelschlick": "schleim", "abschleppwurm": "wurm",
	"schlickkrebs": "krebs", "stromaal": "aal", "riesenegel": "egel", "gullyqualle": "qualle",
	"lumpensammler": "mensch", "rohrgolem": "maschine", "schimmelteppich": "pilz", "kloakenhund": "hund",
	"schleusenwaerter": "zombie", "faulgasblase": "irrlicht", "treibgut_mimic": "sack", "brueckentroll": "troll",
	"die_sammlerin": "mensch", "der_hausmeister": "mensch", "kammerjaeger": "mensch", "pfandbaron": "mensch", "hausverwalter": "mensch",
}


## Haustier-Art: Bild und Fellfarbe.
const PETS := {
	"Katze": ["katze", "#d08a4a"], "Hund": ["hund", "#a07850"], "Kellerraptor": ["raptor", "#6aa04a"],
	"Minidrache": ["drache", "#c8503a"], "Wolpertinger": ["hase", "#c8a878"], "Fledermaus": ["fledermaus", "#7a6a8a"],
	"Ratte": ["ratte", "#9a8a7a"], "Spinne": ["spinne", "#6a5a7a"],
}


## Bild je Gegenstandsart (ding/…); Ausrüstung zeigt das Symbol ihres Platzes.
const ITEM_SPRITES := {"gold": "gold", "karte": "karte", "box": "truhe", "verbrauch": "trank", "buch": "buch", "schrott": "mutter", "schluessel": "schluessel"}


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
	PixelArt.draw_foot(ci, "aufsatz/schatten", foot + Vector2(0, 6 * scale), scale)
	PixelArt.draw_foot(ci, name, foot, scale, tint, flip)
	var img := PixelArt.image(name)
	var top: int = img.get_used_rect().position.y / PixelArt.res(name) if img else 0
	var origin := foot - Vector2(sz.x * scale / 2.0, sz.y * scale)
	if opts.get("crown", false) and not name.begins_with("boss/"):
		var ks := PixelArt.size_of("aufsatz/krone")
		PixelArt.draw(ci, "aufsatz/krone", origin + Vector2((sz.x - ks.x) / 2 * scale, (top - ks.y - 1) * scale), scale)
	if opts.get("unknown", false):
		PixelArt.draw(ci, "aufsatz/frage", origin + Vector2((sz.x - 10) * scale, (top - 6) * scale), scale)


## Die Spielfigur als Porträt (name aus hero_name, sonst ohne Ausrüstung).
static func draw_hero(ci: CanvasItem, foot: Vector2, scale: int, flip: bool = false, name: String = "kreatur/held") -> void:
	PixelArt.draw_foot(ci, "aufsatz/schatten", foot + Vector2(0, 6 * scale), scale)
	PixelArt.draw_foot(ci, name, foot, scale, null, flip)


# ---------------------------------------------------------------- Spielfigur

## Sichtbare Ausrüstung an der Figur (HeroLook zeichnet sie): GEAR_BEHIND
## hinter der Figur, GEAR_BODY am Körper, GEAR_TOP über dem Kopf.
const GEAR_BEHIND := ["ruecken"]
const GEAR_BODY := ["beine", "fuesse", "brust", "guertel", "hals", "schultern", "arme", "haende"]
const GEAR_TOP := ["gesicht", "kopf", "waffe"]
const OUTLINE := Color("#161c2e")
## Ab dieser Bildzeile bewegen sich im Laufbild nur die Beine (um WALK_STEP nach außen).
const WALK_ROW := HeroLook.WALK_ROW
const WALK_STEP := 3


## Laufbild: unterhalb von WALK_ROW rückt alles von der Mitte weg.
static func _walk_frame(img: Image) -> Image:
	var w := img.get_width()
	var out := img.duplicate() as Image
	out.fill_rect(Rect2i(0, WALK_ROW, w, img.get_height() - WALK_ROW), Color(0, 0, 0, 0))
	for y in range(WALK_ROW, img.get_height()):
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var nx := x + (-WALK_STEP if x < w / 2 else WALK_STEP)
			if nx >= 0 and nx < w:
				out.set_pixel(nx, y, c)
	return out

## Hautfarbe und Körperbau je Rasse (normal, klein, gross, breit). Kopf, Haare
## und Anbauten jeder Rasse zeichnet HeroLook.
const RACE_LOOKS := {
	"mensch": {"skin": "#e8b796", "body": "normal"},
	"elf": {"skin": "#f4e2d0", "body": "normal"},
	"halbork": {"skin": "#8fb45a", "body": "gross"},
	"zwerg": {"skin": "#e0a47e", "body": "breit"},
	"gnom": {"skin": "#f0c0a0", "body": "klein"},
	"halbling": {"skin": "#e8b08a", "body": "klein"},
	"kobold": {"skin": "#c07838", "body": "klein"},
	"kellerfee": {"skin": "#f8d4e4", "body": "klein"},
	"echsenmensch": {"skin": "#5c9a4a", "body": "normal"},
	"salamander": {"skin": "#d8603a", "body": "normal"},
	"hobgoblin": {"skin": "#c8783a", "body": "normal"},
	"katzenmensch": {"skin": "#d8843a", "body": "normal"},
	"troll": {"skin": "#7f9a78", "body": "gross"},
	"minotaurus": {"skin": "#744428", "body": "gross"},
	"golem": {"skin": "#b8804a", "body": "gross"},
	"kelleroger": {"skin": "#b8966a", "body": "gross"},
	"pilzling": {"skin": "#ece0c8", "body": "normal"},
	"vampir": {"skin": "#e8e4f0", "body": "normal"},
	"rattling": {"skin": "#9a8a80", "body": "normal"},
	"schattenwesen": {"skin": "#4a4264", "body": "normal"},
	"wasserspeier": {"skin": "#8e8e96", "body": "breit"},
	"ghulblut": {"skin": "#98a888", "body": "normal"},
	"blechmensch": {"skin": "#a8b0b8", "body": "normal"},
	"drachenblut": {"skin": "#c86a40", "body": "normal"},
}


## Bildname der Spielfigur mit Rasse und angelegter Ausrüstung. Sie wird einmal
## im Tiny-Swords-Stil gezeichnet (samt Laufbild „_2“) und unter einem Namen
## aus Rasse, Plätzen und Farben abgelegt.
static func hero_name(p: Dictionary) -> String:
	var eq: Dictionary = J.nn(p, "equipment", {})
	var race := String(p.get("race")) if p.get("race") != null else "mensch"
	if not RACE_LOOKS.has(race):
		race = "mensch"
	var parts: Array = [race]
	var colors := {}
	for slot in GEAR_BEHIND + GEAR_BODY + GEAR_TOP:
		if eq.get(slot) != null:
			colors[slot] = item_color(eq[slot])
			parts.append("%s=%s" % [slot, colors[slot]])
	var name := "kreatur/held@" + ",".join(parts)
	if not PixelArt.has(name):
		var look: Dictionary = RACE_LOOKS[race]
		var img := TsRender.render(HeroLook.shapes(race, look.body, look.skin, colors, 0))
		PixelArt.register(name, img, 2)
		PixelArt.register(name + "_2", _walk_frame(img), 2)
	return name
