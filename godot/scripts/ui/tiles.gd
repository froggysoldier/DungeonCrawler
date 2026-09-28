class_name Tiles
extends Node
## Hilfen für die Kacheln der Karte: Bodenmaterial je Raum, Mauerfarben je
## Etage und ein fester Zufall je Kachel. Die Bilder selbst liegen als
## Pixel-Bögen in res://assets/pixel (siehe PixelArt).

signal ready_changed

const MATERIALS := ["pflaster", "dielen", "fliesen", "beton", "ziegelboden", "teppich", "marmor", "blutstein", "arena"]

const WALL_THEMES := {
	1: {"cap": "#191511", "capStone": "#29231c", "face": "#7b6c5a", "mortar": "#2b241c", "lip": "#a8977f"},
	2: {"cap": "#14161a", "capStone": "#232830", "face": "#6c737e", "mortar": "#22262c", "lip": "#9aa3ae"},
	3: {"cap": "#101512", "capStone": "#1d2821", "face": "#5d6d5e", "mortar": "#1b231d", "lip": "#8fa08e", "moss": "#4f7a3a"},
}

var is_ready := false


static func wall_theme(floor: int) -> Dictionary:
	return WALL_THEMES[clampi(floor, 1, 3)]


# ---------------------------------------------------------------- Zufall je Kachel

static func _i32(v: int) -> int:
	v = v & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v


## Deterministischer Zufall je Kachel: jede Stelle sieht bei jedem Zeichnen gleich aus.
static func hash(x: int, y: int, salt: int = 0) -> float:
	var h := _i32(x * 374761393 + y * 668265263 + salt * 2147483647)
	h = _i32(h ^ ((h & 0xFFFFFFFF) >> 13))
	var prod := float(h) * 1274126177.0
	var h2 := _i32(int(prod))
	var r := (h2 ^ ((h2 & 0xFFFFFFFF) >> 16)) & 0xFFFFFFFF
	return r / 4294967295.0


static var _re_fliesen: RegEx
static var _re_beton: RegEx
static var _re_ziegel: RegEx


static func room_material(r: Variant) -> String:
	if r == null:
		return "pflaster"
	if _re_fliesen == null:
		_re_fliesen = RegEx.create_from_string("bad|dusch|wasch|küche|kueche|toilette|sauna|labor")
		_re_beton = RegEx.create_from_string("werkstatt|lager|garage|heizung|tank|schacht|bunker")
		_re_ziegel = RegEx.create_from_string("wein|gewölbe|kapelle|gruft|brunnen|ofen")
	match r.kind:
		"safe": return "teppich"
		"guild": return "marmor"
		"boss": return "blutstein"
		"arena": return "arena"
		"start": return "beton"
	var n: String = String(r.name).to_lower()
	if _re_fliesen.search(n):
		return "fliesen"
	if _re_beton.search(n):
		return "beton"
	if _re_ziegel.search(n):
		return "ziegelboden"
	var pool := ["dielen", "beton", "fliesen", "ziegelboden", "dielen"]
	return pool[int(r.id) % pool.size()]


## Lädt die Pixel-Bögen vor. Asynchron wie früher, damit Aufrufer sich erst
## danach mit ready_changed verbinden können.
func build() -> void:
	PixelArt.names()
	if is_inside_tree():
		await get_tree().process_frame
	is_ready = true
	ready_changed.emit()
