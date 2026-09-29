class_name Dungeon
extends RefCounted
## Gelände und besondere Räume auf allen Etagen:
##   Gelände   seichtes Wasser (löscht Brand), Schlamm (kostet einen Zug),
##             Kisten und Fässer (zerschlagbar, manchmal mit Inhalt)
##   Türen     verschlossene Türen (Schlüssel oder Schloss knacken), Geheimtüren
##             (mit Wahrnehmung entdecken)
##   Räume     Schatzkammer, Geheimkammer, Monsternest, Hinterhalt, Schrein,
##             Wanderhändler (room.feature)

const WATER := "wasser"
const MUD := "schlamm"
const CRATES := ["kiste", "fass"]
## Kacheln, die man betreten kann (zusätzlich zu Boden, Treppe, offener Tür).
const WALKABLE := [WATER, MUD]

const FEATURE_NAMES := {
	"schatz": "Schatzkammer", "geheim": "Geheimkammer", "nest": "Monsternest",
	"hinterhalt": "Hinterhalt", "schrein": "Schrein", "markt": "Wanderhändler",
}


# ================================================================ Erzeugen

static func _candidates(m: Dictionary) -> Array:
	return m.rooms.filter(func(r):
		if r.kind != "normal" or r.get("antechamberOf") != null or r.get("feature") != null:
			return false
		for y in range(r.y, r.y + r.h):
			for x in range(r.x, r.x + r.w):
				if m.tiles[MapGen.idx(m, x, y)] == "stairs":
					return false
		return true)


static func _passable(m: Dictionary, i: int, blocked: Dictionary) -> bool:
	if blocked.has(i):
		return false
	var t: String = m.tiles[i]
	return t == "floor" or t == "stairs" or t == "door" or t == "dooropen" or WALKABLE.has(t)


## Sind vom Start aus alle anderen Räume und Treppen erreichbar, wenn `blocked` zu ist?
static func _all_reachable(m: Dictionary, start: Dictionary, blocked: Dictionary, skip_room: int) -> bool:
	var w: int = m.width
	var seen := {MapGen.idx(m, start.x, start.y): true}
	var queue := [MapGen.idx(m, start.x, start.y)]
	while not queue.is_empty():
		var i: int = queue.pop_back()
		for d in MapGen.DIRS4:
			var nx: int = i % w + d[0]
			var ny: int = i / w + d[1]
			if not MapGen.in_bounds(m, nx, ny):
				continue
			var ni := ny * w + nx
			if seen.has(ni) or not _passable(m, ni, blocked):
				continue
			seen[ni] = true
			queue.append(ni)
	for r in m.rooms:
		if r.id == skip_room or r.get("sealed"):
			continue
		var c := MapGen.center(r)
		if not seen.has(MapGen.idx(m, c.x, c.y)) and _passable(m, MapGen.idx(m, c.x, c.y), {}):
			return false
	for i in m.tiles.size():
		if m.tiles[i] == "stairs" and not seen.has(i):
			return false
	return true


## Raum ummauern (Zugänge werden Türen). Gibt die Türen zurück; leer, wenn der
## Raum dadurch etwas anderes abschneiden würde (dann bleibt alles, wie es war).
static func _seal(m: Dictionary, r: Dictionary, start: Dictionary) -> Array:
	var tiles: Array = m.tiles.duplicate()
	var room_at: Array = m.roomAt.duplicate()
	var rect := [r.x, r.y, r.w, r.h]
	MapGen._add_walls_and_doors(m, r)
	var doors := []
	for y in range(r.y - 1, r.y + r.h + 1):
		for x in range(r.x - 1, r.x + r.w + 1):
			if MapGen.in_bounds(m, x, y) and m.tiles[MapGen.idx(m, x, y)] == "door":
				doors.append(J.pos(x, y))
	var blocked := {}
	for d in doors:
		blocked[MapGen.idx(m, d.x, d.y)] = true
	if doors.is_empty() or r.w < 2 or r.h < 2 or not _all_reachable(m, start, blocked, r.id):
		m.tiles = tiles
		m.roomAt = room_at
		r.x = rect[0]
		r.y = rect[1]
		r.w = rect[2]
		r.h = rect[3]
		return []
	r.sealed = true
	return doors


## Vor den Bewohnern: Kammern ummauern, Gelände und Kisten verteilen.
static func shape(s: Dictionary, m: Dictionary, start_room: Dictionary) -> void:
	m.locks = {}
	m.secrets = []
	var start := MapGen.center(start_room)
	# Schatzkammer hinter verschlossener Tür, Geheimkammer hinter einer Wand
	for feature in ["schatz", "geheim"]:
		var cands: Array = R.shuffle(s, _candidates(m).filter(func(r): return r.w >= 4 and r.h >= 4 and r.w * r.h <= 56))
		for r in cands.slice(0, 10):
			var doors := _seal(m, r, start)
			if doors.is_empty():
				continue
			r.feature = feature
			if feature == "schatz":
				for d in doors:
					m.locks["%d,%d" % [d.x, d.y]] = r.id
				r.name = "Schatzkammer"
				r.description = "Regale bis unter die Decke, Kisten mit Vorhängeschlössern. Jemand hat hier Dinge gehortet, die er nicht teilen wollte."
			else:
				var keep: Dictionary = doors[0]
				for d in doors:
					m.tiles[MapGen.idx(m, d.x, d.y)] = "wall"
				m.secrets.append({"x": keep.x, "y": keep.y, "room": r.id, "found": false})
				r.name = "Geheimkammer"
				r.description = "Ein vergessener Hohlraum hinter der Mauer. Staub, Spinnweben – und etwas, das jemand versteckt hat."
			break
	# Wasser und Schlamm in einigen Räumen
	for r in m.rooms:
		if r.kind != "normal" or r.get("feature") != null:
			continue
		var roll := R.next(s)
		var tile := WATER if roll < 0.22 else (MUD if roll < 0.34 else "")
		if tile == "":
			continue
		var cx := R.int_(s, r.x, r.x + r.w - 1)
		var cy := R.int_(s, r.y, r.y + r.h - 1)
		var rx := R.int_(s, 1, 3)
		var ry := R.int_(s, 1, 2)
		for y in range(r.y, r.y + r.h):
			for x in range(r.x, r.x + r.w):
				var dx := (x - cx) / (rx + 0.5)
				var dy := (y - cy) / (ry + 0.5)
				if dx * dx + dy * dy <= 1.0 and m.tiles[MapGen.idx(m, x, y)] == "floor":
					m.tiles[MapGen.idx(m, x, y)] = tile
	# Schlammige Gangstücke
	var corridor := []
	for i in m.tiles.size():
		if m.tiles[i] == "floor" and m.roomAt[i] == -1:
			corridor.append(i)
	for n in mini(6, corridor.size()):
		var i: int = R.pick(s, corridor)
		for k in R.int_(s, 1, 3):
			if m.tiles[i] == "floor" and m.roomAt[i] == -1:
				m.tiles[i] = MUD
			var d: Array = MapGen.DIRS4[R.int_(s, 0, 3)]
			var ni: int = i + d[0] + d[1] * int(m.width)
			if ni >= 0 and ni < m.tiles.size():
				i = ni
	# Kisten und Fässer an den Wänden normaler Räume
	for r in m.rooms:
		if r.kind != "normal" or r.get("antechamberOf") != null or not R.chance(s, 0.4):
			continue
		var n := R.int_(s, 1, 3)
		for k in n:
			var spot = _wall_spot(s, m, r)
			if spot == null:
				break
			var i := MapGen.idx(m, spot.x, spot.y)
			m.tiles[i] = R.pick(s, CRATES)
			if not _room_open(m, r):
				m.tiles[i] = "floor"


## Freies Randfeld eines Raums, das an keinen Gang grenzt.
static func _wall_spot(s: Dictionary, m: Dictionary, r: Dictionary) -> Variant:
	for t in 12:
		var edge := R.int_(s, 0, 3)
		var x: int
		var y: int
		match edge:
			0:
				x = R.int_(s, r.x, r.x + r.w - 1)
				y = r.y
			1:
				x = R.int_(s, r.x, r.x + r.w - 1)
				y = r.y + r.h - 1
			2:
				x = r.x
				y = R.int_(s, r.y, r.y + r.h - 1)
			_:
				x = r.x + r.w - 1
				y = R.int_(s, r.y, r.y + r.h - 1)
		if m.tiles[MapGen.idx(m, x, y)] != "floor":
			continue
		var ok := true
		for d in MapGen.DIRS4:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if not MapGen.in_bounds(m, nx, ny):
				continue
			var inside: bool = nx >= r.x and ny >= r.y and nx < r.x + r.w and ny < r.y + r.h
			if not inside and m.tiles[MapGen.idx(m, nx, ny)] != "wall":
				ok = false
		if ok:
			return J.pos(x, y)
	return null


## Alle begehbaren Felder eines Raums hängen noch zusammen.
static func _room_open(m: Dictionary, r: Dictionary) -> bool:
	var free := []
	for y in range(r.y, r.y + r.h):
		for x in range(r.x, r.x + r.w):
			if _passable(m, MapGen.idx(m, x, y), {}):
				free.append(MapGen.idx(m, x, y))
	if free.is_empty():
		return false
	var seen := {free[0]: true}
	var queue := [free[0]]
	var w: int = m.width
	while not queue.is_empty():
		var i: int = queue.pop_back()
		for d in MapGen.DIRS4:
			var nx: int = i % w + d[0]
			var ny: int = i / w + d[1]
			if nx < r.x or ny < r.y or nx >= r.x + r.w or ny >= r.y + r.h:
				continue
			var ni := ny * w + nx
			if not seen.has(ni) and _passable(m, ni, {}):
				seen[ni] = true
				queue.append(ni)
	return seen.size() == free.size()


static func _free_spot(s: Dictionary, m: Dictionary, r: Dictionary, occupied: Dictionary) -> Variant:
	var c := MapGen.center(r)
	var key := "%d,%d" % [c.x, c.y]
	if m.tiles[MapGen.idx(m, c.x, c.y)] == "floor" and not occupied.has(key):
		occupied[key] = true
		return c
	return MapGen._random_floor_in(s, m, r, occupied)


## Nach den Bewohnern: Inhalte der besonderen Räume, Schlüssel, Nest, Schrein, Händler, Hinterhalt.
static func populate(s: Dictionary, m: Dictionary, monsters: Array, items: Array, occupied: Dictionary, floor: int, start: Dictionary) -> void:
	var mob_level: Array = Db.floor_def(floor).mobLevel
	for r in m.rooms:
		match r.get("feature"):
			"schatz":
				items.append({"pos": _free_spot(s, m, r, occupied), "item": Items.create_gold(s, R.int_(s, 25, 60) * floor)})
				for k in 2:
					var p = MapGen._random_floor_in(s, m, r, occupied)
					if p != null:
						items.append({"pos": p, "item": Items.roll_ground_item(s)})
				var p2 = MapGen._random_floor_in(s, m, r, occupied)
				if p2 != null:
					items.append({"pos": p2, "item": Items.generate_equipment(s, "selten" if R.chance(s, 0.5) else "ungewoehnlich")})
				# Der Schlüssel liegt anderswo im selben Viertel
				var holders: Array = m.rooms.filter(func(q): return q.kind == "normal" and q.get("feature") == null and q.get("antechamberOf") == null and q.hood == r.hood)
				if holders.is_empty():
					holders = m.rooms.filter(func(q): return q.kind == "normal" and q.get("feature") == null)
				var holder = R.pick(s, holders) if not holders.is_empty() else null
				var kp = MapGen._random_floor_in(s, m, holder, occupied) if holder != null else null
				if kp != null:
					var key := Items.create_item(s, "schluessel")
					key.opens = r.id
					items.append({"pos": kp, "item": key})
			"geheim":
				var p = _free_spot(s, m, r, occupied)
				if p != null:
					items.append({"pos": p, "item": Items.roll_ground_item(s)})
				var p3 = MapGen._random_floor_in(s, m, r, occupied)
				if p3 != null:
					items.append({"pos": p3, "item": Items.create_gold(s, R.int_(s, 10, 30) * floor) if R.chance(s, 0.6) else Items.create_item(s, "heiltrank")})
	items.assign(items.filter(func(e): return e.pos != null))
	var cands: Array = R.shuffle(s, _candidates(m).filter(func(r): return r.w * r.h >= 20 and MapGen.dist(MapGen.center(r), start) > 12))
	# Monsternest: ein Rudel schwacher Monster um ein Nest
	if not cands.is_empty():
		var r: Dictionary = cands.pop_front()
		r.feature = "nest"
		var spot = _free_spot(s, m, r, occupied)
		if spot != null:
			r.furniture = [{"kind": "nest", "pos": spot}]
		var def: Dictionary = Monsters.pick_monster_def(s, floor, mob_level[0])
		for k in R.int_(s, 4, 6):
			var p = MapGen._random_floor_in(s, m, r, occupied)
			if p == null:
				break
			var mob := Monsters.spawn_monster(s, def, Monsters.clamp_level(def, mob_level[0]), p, r.hood)
			mob.nest = r.id
			monsters.append(mob)
		r.description += " In der Mitte ein stinkendes Nest aus Lumpen, Knochen und Verpackungsmüll."
	# Schreine
	for k in (2 if floor >= 2 else 1):
		if cands.is_empty():
			break
		var r: Dictionary = cands.pop_front()
		var spot = _free_spot(s, m, r, occupied)
		if spot == null:
			continue
		r.feature = "schrein"
		r.furniture = [{"kind": "schrein", "pos": spot}]
		r.description += " Zwischen dem Gerümpel steht ein kleiner Schrein mit einer flackernden Kerze. Jemand hat Opfergaben hingelegt."
	# Wanderhändler
	if not cands.is_empty():
		var r: Dictionary = cands.pop_front()
		var spot = _free_spot(s, m, r, occupied)
		if spot != null:
			r.feature = "markt"
			r.furniture = [{"kind": "haendler", "pos": spot}]
			r.description += " Hinter einem Klapptisch steht ein Händler mit einem Bauchladen voller Kram. Er sieht nicht so aus, als hätte er Angst."
	# Hinterhalt: ein leerer Raum, in dem es beim Betreten zu spät ist
	if not cands.is_empty():
		var r: Dictionary = cands.pop_front()
		r.feature = "hinterhalt"
		r.ambush = {"level": mob_level[1], "count": R.int_(s, 2, 3) + (1 if floor >= 3 else 0)}
		monsters.assign(monsters.filter(func(mo): return MapGen.room_of(m, mo.pos) == null or MapGen.room_of(m, mo.pos).id != r.id))


# ================================================================ Im Spiel

static func is_crate(t: String) -> bool:
	return CRATES.has(t)


static func lock_at(s: Dictionary, at: Dictionary) -> Variant:
	var locks: Dictionary = J.nn(s.map, "locks", {})
	return locks.get("%d,%d" % [at.x, at.y])


static func has_key_for(s: Dictionary, at: Dictionary) -> bool:
	var room_id = lock_at(s, at)
	return room_id != null and _key_for(s, room_id) != null


## Kisten und Fässer direkt neben dem Crawler (auch schräg).
static func adjacent_crates(s: Dictionary) -> Array:
	var out := []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := J.pos(s.player.pos.x + dx, s.player.pos.y + dy)
			if (dx != 0 or dy != 0) and is_crate(MapGen.tile_at(s.map, q.x, q.y)):
				out.append(q)
	return out


static func _key_for(s: Dictionary, room_id: int) -> Variant:
	return J.find(s.player.inventory, func(i): return i.kind == "schluessel" and int(J.num(i, "opens")) == room_id)


static func _unlock(s: Dictionary, room_id: int) -> void:
	var locks: Dictionary = s.map.locks
	for k in locks.keys():
		if locks[k] == room_id:
			locks.erase(k)


## Gegen eine verschlossene Tür laufen: mit Schlüssel aufschließen, sonst Hinweis.
static func try_door(s: Dictionary, at: Dictionary) -> Dictionary:
	var room_id: int = lock_at(s, at)
	var key = _key_for(s, room_id)
	if key == null:
		return {"ok": false, "message": "Die Tür ist verschlossen. Du brauchst den passenden Schlüssel – oder geschickte Finger (Schloss knacken)."}
	s.player.inventory = J.without(s.player.inventory, key)
	_unlock(s, room_id)
	Log.add(s, "Der rostige Schlüssel passt. Das Schloss springt mit einem Knacken auf.", "loot")
	Events.emit(s, {"type": "doorUnlocked"})
	return {"ok": true, "unlocked": true}


static func lockpick_chance(s: Dictionary) -> float:
	var st := Player.effective_stats(s)
	return clampf(0.2 + (st.ges - 5) * 0.05 + Player.skill_level(s, "fallenkunde") * 0.05, 0.05, 0.85)


## Schloss knacken: kostet einen Zug; misslingt es, hört man es vielleicht.
static func pick_lock(s: Dictionary, at: Dictionary) -> Dictionary:
	var room_id = lock_at(s, at)
	if room_id == null:
		return {"ok": false, "message": "Hier ist kein Schloss."}
	if absi(at.x - s.player.pos.x) + absi(at.y - s.player.pos.y) != 1:
		return {"ok": false, "message": "Dafür musst du direkt vor der Tür stehen."}
	Skills.train_skill(s, "trap", 1)
	if R.chance(s, lockpick_chance(s)):
		_unlock(s, room_id)
		Log.add(s, "Klick. Das Schloss gibt nach. Du hast es geknackt.", "loot")
		Events.emit(s, {"type": "lockPicked"})
	else:
		Log.add(s, "Der Draht rutscht ab. Das Schloss hält.", "info")
		if R.chance(s, 0.3):
			var woke := 0
			for mo in s.monsters:
				if J.cheb(mo.pos, s.player.pos) <= 6 and mo.get("asleep"):
					mo.asleep = false
					woke += 1
			if woke > 0:
				Log.add(s, "Das Klappern war zu laut. Irgendwo in der Nähe regt sich etwas.", "gefahr")
	return {"ok": true}


## Kiste oder Fass zerschlagen: meist Kram, manchmal Gold, selten eine Überraschung.
static func smash(s: Dictionary, at: Dictionary) -> Dictionary:
	var m: Dictionary = s.map
	var t := MapGen.tile_at(m, at.x, at.y)
	if not is_crate(t):
		return {"ok": false, "message": "Hier ist nichts zum Zerschlagen."}
	m.tiles[MapGen.idx(m, at.x, at.y)] = "floor"
	s.counters.cratesSmashed = int(J.num(s.counters, "cratesSmashed")) + 1
	var what := "die Kiste" if t == "kiste" else "das Fass"
	var roll := R.next(s)
	if roll < 0.4:
		Log.add(s, "Du schlägst %s kaputt. Leer." % what, "info")
	elif roll < 0.72:
		s.items.append({"pos": J.pcopy(at), "item": Items.roll_material(s)})
		Log.add(s, "Du schlägst %s kaputt. Zwischen den Splittern liegt etwas." % what, "loot")
	elif roll < 0.88:
		s.items.append({"pos": J.pcopy(at), "item": Items.create_gold(s, R.int_(s, 3, 12) * s.floor)})
		Log.add(s, "Du schlägst %s kaputt. Münzen klimpern auf den Boden." % what, "loot")
	elif roll < 0.96:
		s.items.append({"pos": J.pcopy(at), "item": Items.create_item(s, R.pick(s, ["kleiner_heiltrank", "schokoriegel", "pflaster", "energydrink"]))})
		Log.add(s, "Du schlägst %s kaputt. Jemand hat hier Vorräte versteckt." % what, "loot")
	else:
		var def = Monsters.def_by_id("muellsack_mimic")
		if def == null:
			def = Monsters.pick_monster_def(s, s.floor, Db.floor_def(s.floor).mobLevel[0])
		var mob := Monsters.spawn_monster(s, def, Monsters.clamp_level(def, Db.floor_def(s.floor).mobLevel[1]), J.pcopy(at), MapGen.hood_of(m, at))
		mob.aware = true
		s.monsters.append(mob)
		Log.add(s, "Du schlägst %s auf – und es schlägt zurück! Das war kein Behälter." % what, "gefahr")
	Events.emit(s, {"type": "crateSmashed"})
	return {"ok": true}


## Nach einem Schritt: Wasser löscht Feuer, Schlamm hält fest.
static func on_player_step(s: Dictionary) -> void:
	var p: Dictionary = s.player
	var t := MapGen.tile_at(s.map, p.pos.x, p.pos.y)
	if t == WATER:
		if Conditions.clear_player(s, "brennen"):
			Log.add(s, "Zischend erlöschen die Flammen im Wasser.", "info")
		elif not s.get("wetNoted"):
			s.wetNoted = true
			Log.add(s, "Du watest durch knöcheltiefes, kaltes Wasser. Feuer hat hier keine Chance.", "info")
	elif t == MUD:
		p.mud = true
		Log.add(s, "Schmatz. Deine Füße versinken im Schlamm.", "info")


## Steckt der Crawler im Schlamm, kostet der nächste Schritt einen Zug.
static func stuck_in_mud(s: Dictionary) -> bool:
	if not s.player.get("mud"):
		return false
	s.player.erase("mud")
	Log.add(s, "Du ziehst die Füße mühsam aus dem Schlamm.", "info")
	return true


## Monster: Schlamm kostet sie ihren nächsten Zug, Wasser löscht Brand.
static func on_monster_step(s: Dictionary, mo: Dictionary) -> void:
	var t := MapGen.tile_at(s.map, mo.pos.x, mo.pos.y)
	if t == MUD:
		mo.mudStuck = true
	elif t == WATER and Conditions.has_condition(mo, "brennen"):
		mo.conditions.erase("brennen")


## Geheimtüren entdecken: wie Fallen, mit Intelligenz und Wahrnehmung.
static func detect(s: Dictionary, vis: Dictionary) -> void:
	for sec in J.arr(s.map, "secrets"):
		if sec.found:
			continue
		var at := J.pos(sec.x, sec.y)
		var d := J.cheb(at, s.player.pos)
		if d > 2 or not vis.has(MapGen.idx(s.map, sec.x, sec.y)):
			continue
		var st := Player.effective_stats(s)
		var chance := clampf(0.08 + (st.int - 5) * 0.03 + Player.skill_level(s, "wahrnehmung") * 0.04 + (0.1 if d == 1 else 0.0), 0.03, 0.6)
		if not R.chance(s, chance):
			continue
		sec.found = true
		s.map.tiles[MapGen.idx(s.map, sec.x, sec.y)] = "door"
		Skills.train_skill(s, "perceive", 2)
		Log.add(s, "Ein Luftzug, wo keiner sein sollte. Du entdeckst eine Geheimtür!", "loot")
		Events.emit(s, {"type": "secretFound"})


## Beim Betreten: Hinterhalt auslösen.
static func on_enter_room(s: Dictionary, room: Dictionary, first: bool) -> void:
	if room.get("feature") == "hinterhalt" and room.get("ambush") != null and not room.get("sprung"):
		room.sprung = true
		var entrances := []
		for y in range(room.y - 1, room.y + room.h + 1):
			for x in range(room.x - 1, room.x + room.w + 1):
				var inside: bool = x >= room.x and y >= room.y and x < room.x + room.w and y < room.y + room.h
				if inside or not MapGen.is_walkable(s.map, x, y):
					continue
				if Ai.occupied(s, J.pos(x, y)) or (x == s.player.pos.x and y == s.player.pos.y):
					continue
				entrances.append(J.pos(x, y))
		if entrances.is_empty():
			return
		var n: int = room.ambush.count
		for k in n:
			var at: Dictionary = entrances[k % entrances.size()]
			if Ai.occupied(s, at):
				continue
			var def: Dictionary = Monsters.pick_monster_def(s, s.floor, room.ambush.level)
			var mob := Monsters.spawn_monster(s, def, Monsters.clamp_level(def, room.ambush.level), J.pcopy(at), room.hood)
			mob.aware = true
			s.monsters.append(mob)
		Log.add(s, "Ein Pfiff. Aus den Gängen hinter dir treten Gestalten. Das war ein Hinterhalt!", "gefahr")
		Events.emit(s, {"type": "ambush"})
	elif first and room.get("feature") == "schatz":
		Log.add(s, "Die Schatzkammer! Hier lohnt es sich, jede Ecke abzusuchen.", "loot")
		Events.emit(s, {"type": "treasureFound", "room": room.id})
	elif room.get("feature") == "markt":
		var shop := Shop.ensure_shop(s, room)
		if first:
			Log.add(s, "%s (%s): %s" % [String(shop.keeper).split(",")[0], shop.get("title", "Wanderhändler"), shop.get("greeting", "„Nur hereinspaziert.“")], "dialog")


## Nest ausgeräumt? Dann liegt dort etwas.
static func on_kill(s: Dictionary, mo: Dictionary) -> void:
	var nest = mo.get("nest")
	if nest == null:
		return
	if J.some(s.monsters, func(x): return x.get("nest") == nest):
		return
	var room: Dictionary = s.map.rooms[nest]
	var at: Dictionary = MapGen.center(room)
	for f in J.arr(room, "furniture"):
		if f.kind == "nest":
			at = f.pos
			f.kind = "nest_leer"
	s.items.append({"pos": J.pcopy(at), "item": Items.create_gold(s, R.int_(s, 15, 35) * s.floor)})
	s.items.append({"pos": J.pcopy(at), "item": Items.roll_ground_item(s)})
	Log.add(s, "Das Nest ist leer. Zwischen Knochen und Lumpen glänzt etwas.", "loot")
	Events.emit(s, {"type": "nestCleared", "room": nest})


## Beten am Schrein: meist ein Segen, manchmal Stille, selten ein Fluch.
const BLESSINGS := [
	{"name": "Segen der Stärke", "turns": 80, "bonuses": {"stats": {"str": 2}}},
	{"name": "Segen der Flinkheit", "turns": 80, "bonuses": {"stats": {"ges": 2}}},
	{"name": "Segen der Zähigkeit", "turns": 80, "bonuses": {"ruestung": 2}},
	{"name": "Segen des Glücks", "turns": 80, "bonuses": {"krit": 5, "treffer": 5}},
]
const CURSES := [
	{"name": "Fluch der Schwäche", "turns": 40, "bonuses": {"stats": {"str": -1}}, "debuff": true},
	{"name": "Fluch der Tollpatschigkeit", "turns": 40, "bonuses": {"treffer": -6}, "debuff": true},
]


static func pray(s: Dictionary, f: Dictionary) -> Dictionary:
	if f.kind != "schrein":
		return {"ok": false, "message": "Die Kerze ist aus. Der Schrein schweigt."}
	f.kind = "schrein_leer"
	var p: Dictionary = s.player
	var roll: float = R.next(s) + Player.effective_stats(s).cha * 0.01
	if roll < 0.18:
		var c: Dictionary = R.pick(s, CURSES).duplicate(true)
		p.buffs = p.buffs.filter(func(b): return b.name != c.name)
		p.buffs.append(c)
		Log.add(s, "Die Kerze flackert und erlischt. Etwas Kaltes streift deinen Nacken: %s (%d Züge)." % [c.name, c.turns], "gefahr")
	elif roll < 0.33:
		Log.add(s, "Du wartest. Nichts passiert. Die Kerze brennt herunter.", "info")
	elif roll < 0.55:
		p.hp = Player.max_hp(s)
		p.ausdauer = Player.max_ausdauer(s)
		Log.add(s, "Warmes Licht füllt den Raum. Deine Wunden schließen sich.", "loot")
	else:
		var b: Dictionary = R.pick(s, BLESSINGS).duplicate(true)
		p.buffs = p.buffs.filter(func(x): return x.name != b.name)
		p.buffs.append(b)
		Log.add(s, "Die Flamme wird hell und ruhig. Du fühlst dich gestärkt: %s (%d Züge)." % [b.name, b.turns], "loot")
	Events.emit(s, {"type": "prayed"})
	return {"ok": true}
