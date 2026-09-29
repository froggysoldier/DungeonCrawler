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


## Die Spielfigur als Porträt.
static func draw_hero(ci: CanvasItem, foot: Vector2, scale: int, flip: bool = false) -> void:
	PixelArt.draw_foot(ci, "aufsatz/schatten", foot + Vector2(0, 3 * scale), scale)
	PixelArt.draw_foot(ci, "kreatur/held", foot, scale, null, flip)
