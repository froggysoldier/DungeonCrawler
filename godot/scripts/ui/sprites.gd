class_name Sprites
extends RefCounted
## Welche Pixel-Figur zu welcher Monsterart gehört, welches Bild zu welchem
## Gegenstand, dazu große Porträts (Versus-Bildschirm). Die Bilder liegen in
## res://assets/pixel (kreaturen.png, bosse.png, dinge.png).

const BY_DEF := {
	"kellerratte": "ratte", "rattenmensch": "ratte", "rattenschamane": "ratte", "knochenratte": "ratte", "koenig_kanalratte": "ratte", "rattenkaiser": "ratte",
	"riesenkakerlake": "kakerlake",
	# Goblins aus dem Pack: Fackel, Dynamit, Fass; abgewandelte Haut; der Schmuggler reitet einen Eber
	"kobold": "kobold", "kobold_schleuder": "kobold", "elster_goblin": "kobold", "kobold_bombe": "kobold_tnt", "schmuggler": "rpg_ork_reiter", "wechselbalg": "wechselbalg",
	"gnom_buerokrat": "gnom", "heinzelmann": "gnom", "gartenzwerg": "gnom",
	"troll_lehrling": "rpg_ork", "brueckentroll": "rpg_werbaer", "schwarzmarkt_oger": "rpg_ork_elite",
	"fischmensch": "fischmensch",
	"muellsack_mimic": "fass", "reifenstapel_mimic": "fass", "treibgut_mimic": "fass",
	# Menschen aus dem Pack (rote Einheiten, Teamfarbe = Farbe der Art)
	"abtruenniger_crawler": "rpg_axtkaempfer", "lumpensammler": "mensch_holz", "schleusenwaerter": "rpg_skelett_ruestung",
	"ghul": "rpg_skelett", "moorleiche": "rpg_skelett_bogen", "morlock": "rpg_ork_ruestung",
	# Tiny RPG Character Pack: Skelette, Orks, Schleim, Fledermaus, Werwesen, Totenbeschwörer
	"kellermeister": "rpg_skelett_schwert", "nachtmahr": "rpg_nekromant",
	"kanalhexe": "rpg_zauberer", "kesselkoenigin": "moench", "pfandbaron": "mensch_messer", "hausverwalter": "moench",
	"die_sammlerin": "mensch_gold", "der_hausmeister": "mensch_hammer", "kammerjaeger": "bogen", "parkwaechter": "krieger",
	# Schädel und Schaf aus dem Pack
	"wolpertinger": "schaf",
	"schleim": "rpg_schleim", "klaerschlamm": "rpg_schleim", "kommandant_schlamm": "schleim",
	"poltergeist": "geist",
	"grauer_spaeher": "alien",
	"tatzelwurm": "wurm", "neunauge": "wurm",
	"kellerspinne": "spinne",
	"fledermaus": "rpg_fledermaus",
	"blaehkroete": "kroete",
	"irrlicht": "irrlicht",
	"abflusstentakel": "tentakel",
	"toaster_mimic": "toaster", "waschmaschine_mimic": "waschmaschine", "muttis_mixer": "maschine", "heizungsbestie": "maschine",
	"grey_drohne": "drohne",
	"chupacabra": "rpg_werwolf", "ghulhund": "rpg_werwolf",
	"wutelementar": "elementar",
	"kanalkroko": "kroko",
	"nixe": "fisch", "kanalkoenigin": "fisch",
	"pilzmensch": "pilz",
	"mottenmann": "motte", "mottenmutter": "motte",
	"taubenschwarm": "vogel",
	"rostkaefer": "kaefer", "oelschleim": "rpg_schleim", "abgasgeist": "geist", "parkautomat": "parkautomat",
	"garagenkatze": "katze",
	"rostkoenigin": "maschine", "oelschlick": "schleim", "abschleppwurm": "wurm",
	"schlickkrebs": "krebs", "stromaal": "aal", "riesenegel": "egel", "gullyqualle": "qualle",
	"rohrgolem": "rohrgolem", "schimmelteppich": "schimmel", "kloakenhund": "rpg_werwolf",
	"faulgasblase": "irrlicht",
}

## Bosse, die eine Figur aus dem Pack bekommen statt eines eigenen Bildes.
const PACK_BOSSES := ["die_sammlerin", "der_hausmeister", "kesselkoenigin", "kammerjaeger", "pfandbaron", "hausverwalter", "parkwaechter", "schwarzmarkt_oger"]


## Andere Crawler: Menschen aus dem Tiny RPG Pack und der Royal Mage, je Crawler fest gewählt.
const CRAWLER_LOOKS := ["rpg_ritter", "rpg_templer", "rpg_soldat", "rpg_schwertkaempfer", "rpg_bogenschuetzin", "rpg_lanzenreiter", "rpg_priester", "magier", "mensch"]


static func crawler_sprite(cr: Dictionary) -> String:
	var key := String(J.nn(cr, "name", J.nn(cr, "uid", "")))
	return "kreatur/" + CRAWLER_LOOKS[absi(key.hash()) % CRAWLER_LOOKS.size()]


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
	if not rank_ghost and not def_id in PACK_BOSSES and PixelArt.has("boss/" + def_id):
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

const OUTLINE := Color("#161c2e")

## Hautfarbe und Körperbau je Rasse (normal, klein, gross, breit), für
## Beschreibungen; gezeichnet wird die Spielfigur als Einheit aus dem Pack.
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


## Bildname der Spielfigur: der blaue Arbeiter aus dem Pack, darüber die
## sichtbare Ausrüstung (GearLook) in der Form des Gegenstands und der Farbe
## seiner Seltenheit. Alle Ruhe- und Laufbilder werden einmal zusammengesetzt
## und unter einem Namen aus Plätzen, Formen und Farben abgelegt.
static func hero_name(p: Dictionary) -> String:
	var eq: Dictionary = J.nn(p, "equipment", {})
	var gear := {}
	var parts: Array = []
	for slot in GearLook.SLOTS:
		var it = eq.get(slot)
		if it == null:
			continue
		gear[slot] = [GearLook.variant(slot, String(J.nn(it, "baseId", ""))), item_color(it)]
		parts.append("%s=%s:%s" % [slot, gear[slot][0], gear[slot][1]])
	if gear.is_empty():
		return GearLook.BASE
	var name := "kreatur/held@" + ",".join(parts)
	if not PixelArt.has(name):
		var frames := GearLook.compose(gear)
		for fr in frames:
			PixelArt.register(name + String(fr).trim_prefix(GearLook.BASE), frames[fr], 2)
	return name

