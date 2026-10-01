class_name Tiefgarage
extends RefCounted
## Etage 2, die Tiefgaragen:
##   Parkdecks   große Räume mit Reihen von Autowracks und einer freien Fahrspur
##   Wracks      versperren den Weg, aber nicht die Sicht; hineinlaufen heißt
##               durchsuchen (einmal): Kram, Gold, Vorräte, selten Ausrüstung –
##               und manchmal springt die Alarmanlage an
##   Öl          begehbar; man rutscht leicht aus (verliert den nächsten Zug),
##               und wer brennend hineintritt, setzt die Pfütze in Brand

const OIL := "oel"
const WRECK := "wrack"
const WRECK_EMPTY := "wrack_leer"
const FLOOR_NO := 2
const SLIP_CHANCE := 0.3
const ALARM_CHANCE := 0.2
const DECK_NAMES := ["Parkdeck A", "Parkdeck B", "Parkdeck C", "Parkdeck D"]


static func is_wreck(t: String) -> bool:
	return t == WRECK or t == WRECK_EMPTY


# ================================================================ Erzeugen

## Feld am Rand eines Raums, das an einen Zugang grenzt? Dort steht kein Auto.
static func _near_entrance(m: Dictionary, r: Dictionary, x: int, y: int) -> bool:
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]:
		var nx: int = x + d[0]
		var ny: int = y + d[1]
		var inside: bool = nx >= r.x and ny >= r.y and nx < r.x + r.w and ny < r.y + r.h
		if not inside and MapGen.tile_at(m, nx, ny) != "wall":
			return true
	return false


## Nach Dungeon.shape: Parkdecks einrichten, Öl verteilen (nur Etage 2).
static func shape(s: Dictionary, m: Dictionary) -> void:
	var cands: Array = m.rooms.filter(func(r):
		if r.kind != "normal" or r.get("feature") != null or r.get("sealed") or r.get("antechamberOf") != null:
			return false
		if r.w < 6 or r.h < 4:
			return false
		for y in range(r.y, r.y + r.h):
			for x in range(r.x, r.x + r.w):
				if m.tiles[MapGen.idx(m, x, y)] == "stairs":
					return false
		return true)
	J.sort(cands, func(a, b): return b.w * b.h - a.w * a.h)
	var decks: Array = cands.slice(0, 4)
	for i in decks.size():
		var r: Dictionary = decks[i]
		r.parkdeck = true
		r.name = DECK_NAMES[i]
		r.description = "Ein Parkdeck mit verblassten Markierungen. Autos stehen in Reihen, als würden ihre Besitzer gleich zurückkommen. Sie kommen nicht."
		# Zwei Reihen Wracks an den Längsseiten, jedes zweite Feld, Mitte bleibt frei
		for y in [r.y, r.y + r.h - 1]:
			for x in range(r.x + 1, r.x + r.w - 1, 2):
				var idx := MapGen.idx(m, x, y)
				if m.tiles[idx] != "floor" or _near_entrance(m, r, x, y) or not R.chance(s, 0.75):
					continue
				m.tiles[idx] = WRECK
				if not Dungeon._room_open(m, r):
					m.tiles[idx] = "floor"
		# Ölpfützen auf dem Deck
		for k in R.int_(s, 1, 3):
			var cx := R.int_(s, r.x + 1, r.x + r.w - 2)
			var cy := R.int_(s, r.y + 1, r.y + r.h - 2)
			for d in [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]:
				var idx := MapGen.idx(m, cx + d[0], cy + d[1])
				if m.tiles[idx] == "floor" and R.chance(s, 0.7):
					m.tiles[idx] = OIL
	# Öl auch in einigen Gängen
	var corridor := []
	for i in m.tiles.size():
		if m.tiles[i] == "floor" and m.roomAt[i] == -1:
			corridor.append(i)
	for n in mini(8, corridor.size()):
		m.tiles[R.pick(s, corridor)] = OIL


# ================================================================ Im Spiel

## Ein Autowrack durchsuchen (kostet einen Zug).
static func search(s: Dictionary, at: Dictionary) -> Dictionary:
	var m: Dictionary = s.map
	var t := MapGen.tile_at(m, at.x, at.y)
	if t == WRECK_EMPTY:
		return {"ok": false, "message": "Das Wrack ist schon ausgeräumt. Nur ein Duftbaum ist noch da."}
	if t != WRECK:
		return {"ok": false, "message": "Hier ist kein Wrack."}
	m.tiles[MapGen.idx(m, at.x, at.y)] = WRECK_EMPTY
	s.counters.wrecksSearched = int(J.num(s.counters, "wrecksSearched")) + 1
	var drop = _free_beside(s, at)
	var roll := R.next(s)
	if drop == null or roll < 0.3:
		Log.add(s, "Du durchwühlst das Handschuhfach. Quittungen, ein Kaugummi, eine Sonnenbrille ohne Gläser. Nichts Brauchbares.", "info")
	elif roll < 0.6:
		s.items.append({"pos": drop, "item": Items.create_item(s, R.pick(s, ["kleiner_heiltrank", "schokoriegel", "energydrink", "dosenbier", "traubenzucker", "pflaster"]))})
		Log.add(s, "Im Kofferraum liegt eine Tüte vom letzten Einkauf. Einiges davon ist noch gut.", "loot")
	elif roll < 0.8:
		s.items.append({"pos": drop, "item": Items.create_gold(s, R.int_(s, 5, 15) * s.floor)})
		Log.add(s, "Unter der Fußmatte: Münzen für den Parkautomaten. Der braucht sie nicht mehr.", "loot")
	elif roll < 0.92:
		s.items.append({"pos": drop, "item": Items.generate_equipment(s, "ungewoehnlich" if R.chance(s, 0.4) else "gewoehnlich")})
		Log.add(s, "Auf der Rückbank liegt etwas, das man anziehen oder schwingen kann.", "loot")
	else:
		s.items.append({"pos": drop, "item": Items.create_item(s, R.pick(s, ["benzinkanister", "klebeband", "naegel", "lappen"]))})
		Log.add(s, "Im Kofferraum: Werkzeugkiste. Fast leer, aber nicht ganz.", "loot")
	if R.chance(s, ALARM_CHANCE):
		var woke := 0
		for mo in s.monsters:
			if J.cheb(mo.pos, at) <= 9 and mo.get("homeRoom") == null:
				mo.asleep = false
				mo.aware = true
				mo.lastSeen = J.pcopy(s.player.pos)
				woke += 1
		Log.add(s, "WIU WIU WIU! Die Alarmanlage springt an. %s" % ("Ringsum regt sich etwas." if woke > 0 else "Zum Glück hört es niemand."), "gefahr")
		Events.emit(s, {"type": "carAlarm", "woke": woke})
	Events.emit(s, {"type": "wreckSearched"})
	return {"ok": true}


## Freies Feld neben dem Wrack, auf das die Beute fällt (oder null).
static func _free_beside(s: Dictionary, at: Dictionary) -> Variant:
	if J.cheb(at, s.player.pos) == 1 and MapGen.is_walkable(s.map, s.player.pos.x, s.player.pos.y):
		return J.pcopy(s.player.pos)
	for d in MapGen.DIRS4:
		var q := J.pos(at.x + d[0], at.y + d[1])
		if MapGen.is_walkable(s.map, q.x, q.y) and MapGen.furniture_at(s.map, q) == null:
			return q
	return null


## Ein Wesen betritt eine Ölpfütze. burning: brennt es gerade?
## Gibt "slip", "fire" oder "" zurück.
static func step_on_oil(s: Dictionary, at: Dictionary, burning: bool) -> String:
	if MapGen.tile_at(s.map, at.x, at.y) != OIL:
		return ""
	if burning:
		s.map.tiles[MapGen.idx(s.map, at.x, at.y)] = "floor"
		return "fire"
	return "slip" if R.chance(s, SLIP_CHANCE) else ""


## Wracks direkt neben dem Crawler, die man noch durchsuchen kann.
static func adjacent_wrecks(s: Dictionary) -> Array:
	var out := []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := J.pos(s.player.pos.x + dx, s.player.pos.y + dy)
			if (dx != 0 or dy != 0) and MapGen.tile_at(s.map, q.x, q.y) == WRECK:
				out.append(q)
	return out
