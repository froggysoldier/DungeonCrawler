class_name Parity
extends RefCounted
## Hilfen für die Replay-Tests: Kurzzustand, Vergleich, Aktionen ausführen.

const TILE_CHARS := {"wall": "#", "floor": ".", "stairs": ">", "door": "+", "dooropen": "'", "wasser": "~", "schlamm": ",", "kiste": "k", "fass": "f", "kanal": "=", "bruecke": "H", "oel": ":", "wrack": "W", "wrack_leer": "w"}


## Kompakter Zustand für den Vergleich (Karte als Text statt riesiger Listen).
static func snapshot(s: Dictionary) -> Dictionary:
	var c: Dictionary = s.duplicate(true)
	var m: Dictionary = c.map
	var tiles := PackedStringArray()
	for t in m.tiles:
		tiles.append(TILE_CHARS[t])
	m.tiles = "".join(tiles)
	var ex := PackedStringArray()
	for e in m.explored:
		ex.append("1" if e else "0")
	m.explored = "".join(ex)
	m.roomAt = ",".join(PackedStringArray(m.roomAt.map(func(v): return str(v))))
	c.erase("fx")
	c.erase("sfx")
	return c


## Unterschiede zweier JSON-Werte (fehlend = null, Zahlen nach Wert).
static func diff(a: Variant, b: Variant, path: String = "", out: Array = [], limit: int = 12) -> Array:
	if out.size() >= limit:
		return out
	var an := a is int or a is float
	var bn := b is int or b is float
	if an and bn:
		var fa := float(a)
		var fb := float(b)
		# Godots JSON-Leser rundet in der letzten Stelle ungenau
		if fa != fb and absf(fa - fb) > 1e-9 * maxf(1.0, maxf(absf(fa), absf(fb))):
			out.append("%s: ist %s, soll %s" % [path, J.s(a), J.s(b)])
		return out
	if a is Dictionary and b is Dictionary:
		var keys := {}
		for k in a:
			keys[String(k)] = true
		for k in b:
			keys[String(k)] = true
		for k in keys:
			diff(a.get(k), b.get(k), "%s.%s" % [path, k], out, limit)
		return out
	if a is Array and b is Array:
		if a.size() != b.size():
			out.append("%s: Länge ist %d, soll %d" % [path, a.size(), b.size()])
		for i in mini(a.size(), b.size()):
			diff(a[i], b[i], "%s[%d]" % [path, i], out, limit)
		return out
	if typeof(a) != typeof(b) or a != b:
		var sa := str(a).substr(0, 160)
		var sb := str(b).substr(0, 160)
		out.append("%s: ist %s, soll %s" % [path, sa, sb])
	return out


static func digest(s: Dictionary) -> Array:
	return [s.rng, s.turn, s.player.hp, s.player.pos.x, s.player.pos.y, s.monsters.size(), s.get("logCounter") if s.get("logCounter") != null else s.log.size(), s.status]


static func run_action(s: Dictionary, a: String, args: Array) -> Dictionary:
	match a:
		"moveStep": return Game.move_step(s, args[0])
		"attack": return Game.attack(s, args[0], args[1])
		"wait": return Game.wait(s)
		"pickup": return Game.pickup(s, args[0] if args.size() > 0 else null)
		"useItem": return Game.use_item(s, args[0])
		"equip": return Game.equip(s, args[0])
		"openBox": return Game.open_box(s, args[0])
		"sleep": return Game.sleep(s)
		"descend": return Game.descend(s, args[0])
		"cast": return Game.cast(s, args[0], args[1] if args.size() > 1 else {})
		"defend": return Game.defend(s)
		"closeDoor": return Game.close_door(s, args[0])
		"chooseRaceAndClass": return Classes.choose(s, args[0], args[1])
		"useAbility": return Classes.use_ability(s, args[0])
		"talkCrawler": return Game.talk_crawler(s, args[0])
		"inviteCrawler": return Game.invite_crawler(s, args[0])
		"toilet": return Game.toilet(s)
		"buyOffer": return Game.buy_offer(s, args[0])
		"allocateStat": return Game.allocate_stat(s, args[0])
		"craftItem": return Game.craft_item(s, args[0])
		"answerTalkShow": return Game.answer_talk_show(s, args[0])
		"testHeal":
			s.player.hp = Player.max_hp(s)
			return {"ok": true}
	push_error("Unbekannte Aktion: %s" % a)
	return {"ok": false}
