class_name MapGen
extends RefCounted
## Etagen erzeugen.

const MAP_W := 84
const MAP_H := 60
const DIRS4 := [[1, 0], [-1, 0], [0, 1], [0, -1]]


static func idx(m: Dictionary, x: int, y: int) -> int:
	return y * int(m.width) + x


static func in_bounds(m: Dictionary, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < m.width and y < m.height


static func tile_at(m: Dictionary, x: int, y: int) -> String:
	return m.tiles[idx(m, x, y)] if in_bounds(m, x, y) else "wall"


static func is_walkable(m: Dictionary, x: int, y: int) -> bool:
	var t := tile_at(m, x, y)
	return t == "floor" or t == "stairs" or t == "dooropen" or t == Dungeon.WATER or t == Dungeon.MUD or t == Kanalstadt.BRIDGE or t == Tiefgarage.OIL


## Wände und geschlossene Türen blockieren die Sicht.
static func blocks_sight(m: Dictionary, x: int, y: int) -> bool:
	var t := tile_at(m, x, y)
	return t == "wall" or t == "door"


## Gilden, Safe Rooms und Kammern: Rand wird Mauer, Zugänge werden Türen.
static func _add_walls_and_doors(m: Dictionary, r: Dictionary) -> void:
	var rx: int = r.x
	var ry: int = r.y
	var rw: int = r.w
	var rh: int = r.h
	var inside := func(x: int, y: int) -> bool: return x >= rx and x < rx + rw and y >= ry and y < ry + rh
	var edge := func(x: int, y: int) -> bool: return x == rx or y == ry or x == rx + rw - 1 or y == ry + rh - 1
	var corner := func(x: int, y: int) -> bool: return (x == rx or x == rx + rw - 1) and (y == ry or y == ry + rh - 1)
	var candidates := []
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			if not edge.call(x, y):
				continue
			for d in DIRS4:
				var dx: int = d[0]
				var dy: int = d[1]
				var qx := x + dx
				var qy := y + dy
				if inside.call(qx, qy) or not in_bounds(m, qx, qy):
					continue
				if m.tiles[idx(m, qx, qy)] == "wall" or m.roomAt[idx(m, qx, qy)] != -1:
					continue
				if not corner.call(x, y):
					candidates.append(J.pos(x, y))
					continue
				# Gang trifft genau auf eine Ecke: Tür eins weiter setzen und den Gang anschließen
				var along: Dictionary
				if dx != 0:
					along = J.pos(x, y + 1 if y == ry else y - 1)
				else:
					along = J.pos(x + 1 if x == rx else x - 1, y)
				if corner.call(along.x, along.y):
					continue
				var ox: int = along.x + dx
				var oy: int = along.y + dy
				if in_bounds(m, ox, oy) and m.roomAt[idx(m, ox, oy)] == -1:
					m.tiles[idx(m, ox, oy)] = "floor"
					candidates.append(along)
	# Rand zu Wänden machen
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			if not edge.call(x, y):
				continue
			m.tiles[idx(m, x, y)] = "wall"
			m.roomAt[idx(m, x, y)] = -1
	# Benachbarte Zugänge zusammenfassen: eine Tür pro Gruppe
	var used := {}
	for c in candidates:
		var key := "%d,%d" % [c.x, c.y]
		if used.has(key):
			continue
		var group := [c]
		used[key] = true
		var k := 0
		while k < group.size():
			for o in candidates:
				var ok := "%d,%d" % [o.x, o.y]
				if not used.has(ok) and absi(o.x - group[k].x) + absi(o.y - group[k].y) == 1:
					used[ok] = true
					group.append(o)
			k += 1
		var door: Dictionary = group[floori(group.size() / 2.0)]
		m.tiles[idx(m, door.x, door.y)] = "door"
	r.x = rx + 1
	r.y = ry + 1
	r.w = rw - 2
	r.h = rh - 2


static func room_of(m: Dictionary, p: Dictionary) -> Variant:
	if not in_bounds(m, p.x, p.y):
		return null
	var r: int = m.roomAt[idx(m, p.x, p.y)]
	return m.rooms[r] if r >= 0 else null


static func hood_of(m: Dictionary, p: Dictionary) -> int:
	var left: bool = p.x < m.width / 2.0
	var top: bool = p.y < m.height / 2.0
	if top:
		return 0 if left else 1
	return 3 if left else 2


## Liegt in diesem Raum ein Feld der Art t (etwa die Treppe)?
static func room_has_tile(m: Dictionary, r: Dictionary, t: String) -> bool:
	for y in range(r.y, r.y + r.h):
		for x in range(r.x, r.x + r.w):
			if m.tiles[idx(m, x, y)] == t:
				return true
	return false


## Erstes begehbares Feld ohne Möbel direkt neben at (vier Richtungen) oder null.
static func free_beside(m: Dictionary, at: Dictionary) -> Variant:
	for d in DIRS4:
		var q := J.pos(at.x + d[0], at.y + d[1])
		if is_walkable(m, q.x, q.y) and furniture_at(m, q) == null:
			return q
	return null


static func center(r: Dictionary) -> Dictionary:
	return J.pos(floori(r.x + r.w / 2.0), floori(r.y + r.h / 2.0))


static func dist(a: Dictionary, b: Dictionary) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _overlaps(a: Dictionary, rooms: Array) -> bool:
	for r in rooms:
		if a.x - 2 < r.x + r.w and a.x + a.w + 2 > r.x and a.y - 2 < r.y + r.h and a.y + a.h + 2 > r.y:
			return true
	return false


## Hauptgang: zwei Felder breit, waagerecht oder senkrecht.
static func _hall(m: Dictionary, halls: Dictionary, x0: int, y0: int, x1: int, y1: int) -> void:
	var horizontal := y0 == y1
	for t in range(mini(x0, x1) if horizontal else mini(y0, y1), (maxi(x0, x1) if horizontal else maxi(y0, y1)) + 2):
		for k in 2:
			var x: int = t if horizontal else x0 + k
			var y: int = y0 + k if horizontal else t
			if x < 1 or y < 1 or x >= m.width - 1 or y >= m.height - 1:
				continue
			m.tiles[idx(m, x, y)] = "floor"
			halls[idx(m, x, y)] = true


## Liegt ein Raum (mit einem Feld Rand) auf einem Hauptgang?
static func _touches(m: Dictionary, halls: Dictionary, r: Dictionary) -> bool:
	for y in range(r.y - 1, r.y + r.h + 1):
		for x in range(r.x - 1, r.x + r.w + 1):
			if in_bounds(m, x, y) and halls.has(idx(m, x, y)):
				return true
	return false


## Sackgassen: kurze Gänge vom Hauptgang ins Gestein, am Ende eine kleine
## Nische (eigener kleiner Raum der Art „nische“, manchmal mit Toilette).
static func _niches(s: Dictionary, m: Dictionary, halls: Dictionary, count: int) -> void:
	var keys: Array = halls.keys()
	var made := 0
	var tries := 0
	while made < count and tries < 200:
		tries += 1
		var start: int = R.pick(s, keys)
		var d: Array = R.pick(s, DIRS4)
		var x: int = start % int(m.width)
		var y: int = start / int(m.width)
		var len := R.int_(s, 4, 8)
		var path := []
		var ok := true
		for k in range(1, len + 1):
			var px: int = x + d[0] * k
			var py: int = y + d[1] * k
			if px < 3 or py < 3 or px >= m.width - 4 or py >= m.height - 4 or halls.has(idx(m, px, py)) or m.tiles[idx(m, px, py)] != "wall" or _near_room(m, px, py):
				ok = false
				break
			path.append(J.pos(px, py))
		if not ok or path.is_empty():
			continue
		var end: Dictionary = path[path.size() - 1]
		var room := {"id": m.rooms.size(), "x": end.x - (1 if d[0] < 0 else 0), "y": end.y - (1 if d[1] < 0 else 0), "w": 2, "h": 2, "kind": "nische", "hood": hood_of(m, end), "name": "Nische", "description": "Ein schmaler Gang endet hier in einer kleinen Nische. Jemand hat sie vor langer Zeit gemauert und dann vergessen."}
		var free := true
		for yy in range(room.y - 1, room.y + room.h + 1):
			for xx in range(room.x - 1, room.x + room.w + 1):
				if not in_bounds(m, xx, yy) or m.roomAt[idx(m, xx, yy)] != -1 or halls.has(idx(m, xx, yy)):
					free = false
		if not free:
			continue
		for q in path:
			m.tiles[idx(m, q.x, q.y)] = "floor"
		_carve_room(m, room)
		m.rooms.append(room)
		made += 1


static func _near_room(m: Dictionary, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if in_bounds(m, x + dx, y + dy) and m.roomAt[idx(m, x + dx, y + dy)] != -1:
				return true
	return false


static func _carve_room(m: Dictionary, r: Dictionary) -> void:
	for y in range(r.y, r.y + r.h):
		for x in range(r.x, r.x + r.w):
			m.tiles[idx(m, x, y)] = "floor"
			m.roomAt[idx(m, x, y)] = r.id


## Gang von a nach b graben; Kammern werden umgangen, bestehende Gänge bevorzugt.
static func _carve_corridor(m: Dictionary, a: Dictionary, b: Dictionary, forbidden: Dictionary) -> bool:
	var width: int = m.width
	var height: int = m.height
	var start := idx(m, a.x, a.y)
	var goal := idx(m, b.x, b.y)
	var dist_map := {start: 0}
	var came := {}
	var open_i: Array[int] = [start]
	var open_f: Array[int] = [0]
	var done := {}
	while not open_i.is_empty():
		var best := 0
		for k in range(1, open_i.size()):
			if open_f[k] < open_f[best]:
				best = k
		var i: int = open_i[best]
		open_i.remove_at(best)
		open_f.remove_at(best)
		if i == goal:
			break
		if done.has(i):
			continue
		done[i] = true
		var x := i % width
		var y := i / width
		for d in DIRS4:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if nx < 1 or ny < 1 or nx >= width - 1 or ny >= height - 1:
				continue
			var ni := ny * width + nx
			if forbidden.has(ni) and ni != start and ni != goal:
				continue
			var cost := 3 if m.tiles[ni] == "wall" else 1
			var nd: int = dist_map[i] + cost
			if not dist_map.has(ni) or nd < dist_map[ni]:
				dist_map[ni] = nd
				came[ni] = i
				open_i.append(ni)
				open_f.append(nd + absi(nx - b.x) + absi(ny - b.y))
	if not came.has(goal):
		return false
	var cur := goal
	while cur != start:
		if m.tiles[cur] == "wall":
			m.tiles[cur] = "floor"
		cur = came[cur]
	return true


static func _random_floor_in(s: Dictionary, m: Dictionary, r: Dictionary, occupied: Dictionary) -> Variant:
	for i in 40:
		var p := J.pos(R.int_(s, r.x, r.x + r.w - 1), R.int_(s, r.y, r.y + r.h - 1))
		var key := "%d,%d" % [p.x, p.y]
		if m.tiles[idx(m, p.x, p.y)] == "floor" and not occupied.has(key):
			occupied[key] = true
			return p
	# Kaum freier Boden (etwa ein Kanal mitten durch): der Reihe nach suchen
	for y in range(r.y, r.y + r.h):
		for x in range(r.x, r.x + r.w):
			var key := "%d,%d" % [x, y]
			if m.tiles[idx(m, x, y)] == "floor" and not occupied.has(key):
				occupied[key] = true
				return J.pos(x, y)
	return null


static func _assign(r: Variant, kind: String, name: String, description: String) -> void:
	if r == null:
		return
	r.kind = kind
	r.name = name
	r.description = description


static func _fill(size: int, value: Variant) -> Array:
	var a := []
	a.resize(size)
	a.fill(value)
	return a


static func generate_floor(s: Dictionary, floor: int, ghosts: Array) -> Dictionary:
	var def := Db.floor_def(floor)
	var hood_names: Array = Db.world("HOOD_NAMES")
	var hoods := []
	for id in hood_names.size():
		hoods.append({"id": id, "name": hood_names[id], "bossAlive": true, "mapFound": false})
	var m := {
		"width": MAP_W,
		"height": MAP_H,
		"tiles": _fill(MAP_W * MAP_H, "wall"),
		"roomAt": _fill(MAP_W * MAP_H, -1),
		"rooms": [],
		"hoods": hoods,
		"explored": _fill(MAP_W * MAP_H, false),
	}

	# --- Zentrale Arena des Borough-Bosses mit Treppenhaus
	var arena := {
		"id": 0, "x": MAP_W / 2 - 6, "y": MAP_H / 2 - 5, "w": 13, "h": 10,
		"kind": "arena", "hood": -1, "name": "Das Große Gewölbe",
		"description": "Ein riesiges Ziegelgewölbe. In der Mitte blubbert ein Kessel, groß wie ein Pool. Hinter ihm: ein Schild mit einem Pfeil nach unten.",
	}
	m.rooms.append(arena)

	# --- Hauptgänge: ein Ring um das Gewölbe, zwei Achsen, die die Etage in
	# vier Viertel teilen, und in jedem Viertel ein eigenes Gangkreuz. Alle
	# zwei Felder breit. Die schmalen Nebengänge zu den Räumen kommen danach.
	var cx := MAP_W / 2
	var cy := MAP_H / 2
	var halls := {}
	var ring := {"x0": arena.x - 7, "y0": arena.y - 7, "x1": arena.x + arena.w + 5, "y1": arena.y + arena.h + 5}
	_hall(m, halls, ring.x0, ring.y0, ring.x1, ring.y0)
	_hall(m, halls, ring.x0, ring.y1, ring.x1, ring.y1)
	_hall(m, halls, ring.x0, ring.y0, ring.x0, ring.y1)
	_hall(m, halls, ring.x1, ring.y0, ring.x1, ring.y1)
	_hall(m, halls, cx - 1, R.int_(s, 3, 6), cx - 1, ring.y0)
	_hall(m, halls, cx - 1, ring.y1, cx - 1, MAP_H - R.int_(s, 5, 8))
	_hall(m, halls, R.int_(s, 3, 6), cy - 1, ring.x0, cy - 1)
	_hall(m, halls, ring.x1, cy - 1, MAP_W - R.int_(s, 5, 8), cy - 1)
	for hood in 4:
		var left := hood == 0 or hood == 3
		var top := hood < 2
		var hy: int = R.int_(s, 6, ring.y0 - 5) if top else R.int_(s, ring.y1 + 5, MAP_H - 8)
		var vx: int = R.int_(s, 6, ring.x0 - 5) if left else R.int_(s, ring.x1 + 5, MAP_W - 8)
		var outer_x: int = R.int_(s, 3, 9) if left else MAP_W - R.int_(s, 5, 11)
		var outer_y: int = R.int_(s, 3, 7) if top else MAP_H - R.int_(s, 5, 9)
		_hall(m, halls, outer_x, hy, cx - 1, hy)
		_hall(m, halls, vx, outer_y, vx, cy - 1)
	var ring_rect := {"x": ring.x0, "y": ring.y0, "w": ring.x1 - ring.x0 + 2, "h": ring.y1 - ring.y0 + 2}

	# Vorraum des Gewölbes: zwischen Ring und Gewölbe, genau ein Zugang
	var vorraum := {"id": m.rooms.size(), "x": cx - 3, "y": arena.y - 4, "w": 7, "h": 3, "kind": "normal", "hood": -1, "name": "", "description": "", "antechamberOf": arena.id}
	m.rooms.append(vorraum)

	# --- Räume je Viertel, mit Abstand zu den Hauptgängen
	var half_w := MAP_W / 2
	var half_h := MAP_H / 2
	for hood in 4:
		var qx := 0 if hood == 0 or hood == 3 else half_w
		var qy := 0 if hood < 2 else half_h
		var placed := 0
		var tries := 0
		while tries < 1200 and placed < 15:
			tries += 1
			var w := R.int_(s, 5, 11)
			var h := R.int_(s, 4, 8)
			var x := R.int_(s, qx + 1, qx + half_w - w - 2)
			var y := R.int_(s, qy + 1, qy + half_h - h - 2)
			var cand := {"x": x, "y": y, "w": w, "h": h}
			if _overlaps(cand, m.rooms) or _overlaps(cand, [ring_rect]) or _touches(m, halls, cand):
				continue
			m.rooms.append({"id": m.rooms.size(), "x": x, "y": y, "w": w, "h": h, "kind": "normal", "hood": hood, "name": "", "description": ""})
			placed += 1
	# --- Raumtypen zuweisen
	var hood_rooms := func(h: int) -> Array: return m.rooms.filter(func(r): return r.hood == h and r.kind == "normal")
	var start_hood := R.int_(s, 0, 3)
	var corner := J.pos(0 if start_hood == 0 or start_hood == 3 else MAP_W, 0 if start_hood < 2 else MAP_H)
	var start_room: Dictionary = J.sort(hood_rooms.call(start_hood), func(a, b): return dist(center(a), corner) - dist(center(b), corner))[0]
	var arrival: Dictionary = Db.world("START_ROOM") if floor == 1 else Db.world("ARRIVAL_ROOM")
	_assign(start_room, "start", arrival.name, arrival.description)

	# Gilde: im Start-Viertel in mittlerer Entfernung, plus eine weitere woanders
	var guild_room: Dictionary = Db.world("GUILD_ROOM")
	var guild_candidates: Array = J.sort(hood_rooms.call(start_hood), func(a, b): return dist(center(a), center(start_room)) - dist(center(b), center(start_room)))
	if not guild_candidates.is_empty():
		var guild1 = guild_candidates[mini(2, guild_candidates.size() - 1)]
		_assign(guild1, "guild", guild_room.name, guild_room.description)
	var other_hood := (start_hood + 2) % 4
	var other_rooms: Array = hood_rooms.call(other_hood)
	var guild2 = R.pick(s, other_rooms) if not other_rooms.is_empty() else _pick_empty(s)
	_assign(guild2, "guild", guild_room.name, guild_room.description)

	# Boss-Kammern: der vom Start am weitesten entfernte große Raum je Viertel
	var boss_rooms := []
	for h in 4:
		var cands: Array = hood_rooms.call(h).filter(func(r): return r.w * r.h >= 30)
		var list: Array = cands if not cands.is_empty() else hood_rooms.call(h)
		J.sort(list, func(a, b): return dist(center(b), center(start_room)) - dist(center(a), center(start_room)))
		if not list.is_empty():
			var room: Dictionary = list[0]
			_assign(room, "boss", "Kammer: %s" % hood_names[h], "Die Luft ist schwer. Irgendetwas Großes lebt hier – und es bewacht das ganze Viertel.")
			boss_rooms.append(room)

	# Safe Rooms: wenige und nicht gleich am Start – je eins in den drei
	# anderen Vierteln, in einigem Abstand
	var safe_hoods := [0, 1, 2, 3].filter(func(h): return h != start_hood)
	for hood in safe_hoods.slice(0, int(J.nn(def, "safeRooms", 3))):
		var pool: Array = hood_rooms.call(hood).filter(func(r): return dist(center(r), center(start_room)) >= 20)
		var cands: Array = pool.filter(func(r): return r.w >= 7 and r.h >= 5 and r.w * r.h <= 60)
		var room
		if not cands.is_empty():
			room = R.pick(s, cands)
		else:
			# Kein passender Raum: der größte, damit Automat, Wirt und Bett Platz haben
			var all: Array = J.sort(hood_rooms.call(hood).filter(func(r): return dist(center(r), center(start_room)) >= 12), func(a, b): return b.w * b.h - a.w * a.h)
			room = all[0] if not all.is_empty() else _pick_empty(s)
		if room == null:
			continue
		var variant := "freebie" if R.chance(s, 0.5) else "restaurant"
		var flavor: Dictionary = Db.world("SAFE_ROOM_FREEBIE") if variant == "freebie" else Db.world("SAFE_ROOM_RESTAURANT")
		_assign(room, "safe", flavor.name, flavor.description)
		room.safeVariant = variant

	for r in m.rooms:
		_carve_room(m, r)

	# --- Nebengänge: jeder Raum an den nächsten Hauptgang, manche zusätzlich
	# an einen Nachbarraum (Schleifen), Kammern nur über ihren Vorraum.
	var is_lair := func(r: Dictionary) -> bool: return r.kind == "boss" or r.kind == "arena"
	var hubs: Array = m.rooms.filter(func(r): return not is_lair.call(r) and r.id != vorraum.id)
	var hall_list: Array = halls.keys()
	var forbidden_for := func(room_ids: Array) -> Dictionary:
		var set := {}
		for r in m.rooms:
			if (not is_lair.call(r) and r.id != vorraum.id) or room_ids.has(r.id):
				continue
			for y in range(r.y - 1, r.y + r.h + 1):
				for x in range(r.x - 1, r.x + r.w + 1):
					set[idx(m, x, y)] = true
		return set
	var edges := []
	for r in hubs:
		var c := center(r)
		var best: int = hall_list[0]
		var best_d := 1 << 30
		for hi in hall_list:
			var d := absi(hi % MAP_W - c.x) + absi(hi / MAP_W - c.y)
			if d < best_d:
				best_d = d
				best = hi
		var to := J.pos(best % MAP_W, best / MAP_W)
		if not _carve_corridor(m, c, to, forbidden_for.call([r.id])):
			_carve_corridor(m, c, to, {})
		if R.chance(s, 0.4):
			var near: Array = J.sort(hubs.filter(func(q): return q.id != r.id and dist(center(q), c) <= 20), func(p, q): return dist(center(p), c) - dist(center(q), c)).slice(0, 2)
			if not near.is_empty():
				edges.append([r.id, R.pick(s, near).id])
	# Jede Kammer hat genau einen Zugang – über ihren Vorraum. Der Gang
	# dorthin darf keinen Hauptgang berühren, sonst ginge es am Vorraum vorbei.
	var hall_margin := {}
	for hi in hall_list:
		for d in [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]:
			hall_margin[hi + d[0] + d[1] * MAP_W] = true
	for lair in m.rooms.filter(is_lair):
		if lair.id == arena.id:
			edges.append([vorraum.id, arena.id])
			continue
		var free: Array = hubs.filter(func(r): return r.kind == "normal" and r.get("antechamberOf") == null)
		J.sort(free, func(p, q): return dist(center(lair), center(p)) - dist(center(lair), center(q)))
		var linked := false
		for cand in free.slice(0, 5):
			var forbid: Dictionary = forbidden_for.call([cand.id, lair.id])
			forbid.merge(hall_margin)
			if _carve_corridor(m, center(cand), center(lair), forbid):
				cand.antechamberOf = lair.id
				linked = true
				break
		if not linked and not free.is_empty():
			free[0].antechamberOf = lair.id
			edges.append([free[0].id, lair.id])
	_carve_corridor(m, J.pos(cx, ring.y0 + 1), center(vorraum), forbidden_for.call([vorraum.id]))
	for e in edges:
		var from := center(m.rooms[e[0]])
		var to := center(m.rooms[e[1]])
		if not _carve_corridor(m, from, to, forbidden_for.call([e[0], e[1]])):
			_carve_corridor(m, from, to, {})
	# Sackgassen mit kleinen Nischen an den Hauptgängen
	_niches(s, m, halls, 6)

	# Gilden, Safe Rooms und Kammern: Mauern und Türen
	for r in m.rooms:
		if r.kind == "guild" or r.kind == "safe" or is_lair.call(r):
			_add_walls_and_doors(m, r)

	for r in m.rooms:
		if r.kind == "safe":
			_furnish(s, m, r)

	# Übrige Räume bekommen Namen und Beschreibungen
	var flavor_src: Array = def.flavors if def.get("flavors") != null else Db.world("ROOM_FLAVORS")
	var flavors: Array = R.shuffle(s, flavor_src.duplicate())
	var fi := 0
	for r in m.rooms:
		if r.kind != "normal":
			continue
		var f: Dictionary = flavors[fi % flavors.size()]
		fi += 1
		r.name = f.name
		r.description = f.description
		if r.get("antechamberOf") != null:
			var lair: Dictionary = m.rooms[r.antechamberOf]
			r.name = "Vorraum: %s" % f.name
			r.description = "%s Eine schwere, mit rotem Eisen beschlagene Tür führt von hier in %s. Wer sie durchschreitet, kommt erst wieder heraus, wenn der Boss besiegt ist. Hier haben andere ihre Sachen zurückgelassen." % [f.description, "das Große Gewölbe" if lair.kind == "arena" else "eine Boss-Kammer"]

	# --- Treppenhäuser: eins in der Arena, zwei in abgelegenen Räumen
	var arena_c := center(arena)
	m.tiles[idx(m, arena_c.x, arena.y + 1)] = "stairs"
	var far_rooms: Array = J.sort(m.rooms.filter(func(r): return r.kind == "normal"), func(a, b): return dist(center(b), center(start_room)) - dist(center(a), center(start_room)))
	var stair_rooms := []
	for k in [0, 3]:
		if k < far_rooms.size():
			stair_rooms.append(far_rooms[k])
	for r in stair_rooms:
		var c := center(r)
		m.tiles[idx(m, c.x, c.y)] = "stairs"
		r.description += " In einer Ecke führt eine schmale Treppe in die Tiefe."

	# --- Gelände, Kammern, Kisten
	Dungeon.shape(s, m, start_room)
	if floor == Kanalstadt.FLOOR_NO:
		Kanalstadt.shape(s, m)
	if floor == Tiefgarage.FLOOR_NO:
		Tiefgarage.shape(s, m)

	# --- Bewohner
	var occupied := {}
	var start := center(start_room)
	occupied["%d,%d" % [start.x, start.y]] = true
	var monsters := []
	var items := []
	var max_dist := MAP_W + MAP_H

	# Bosse: bevorzugt die „eigenen“ Bosse dieser Etage, sonst welche von oben
	var hood_bosses: Array = Db.t("monsters", "HOOD_BOSSES")
	var own := hood_bosses.filter(func(b): return b.rank == "nachbarschaftsboss" and b.floors[0] == floor)
	var visiting := hood_bosses.filter(func(b): return b.rank == "nachbarschaftsboss" and b.floors[0] != floor and b.floors.has(floor))
	var bosses: Array = R.shuffle(s, own) + R.shuffle(s, visiting)
	for i in boss_rooms.size():
		var room: Dictionary = boss_rooms[i]
		var p := center(room)
		occupied["%d,%d" % [p.x, p.y]] = true
		monsters.append(Monsters.spawn_boss(s, bosses[i % bosses.size()], p, room.hood, room.id, floor))
	var borough = J.find(hood_bosses, func(b): return b.rank == "boroughboss" and b.floors.has(floor))
	if borough == null:
		borough = J.find(hood_bosses, func(b): return b.rank == "boroughboss")
	var arena_boss_pos := J.pos(arena_c.x, arena_c.y + 1)
	occupied["%d,%d" % [arena_boss_pos.x, arena_boss_pos.y]] = true
	monsters.append(Monsters.spawn_boss(s, borough, arena_boss_pos, -1, arena.id, floor))

	# --- Monster: in Revieren. Je Viertel ein paar Räume, in denen eine einzige
	# Art lebt (und nachkommt); die übrigen Räume sind meist leer, ab und zu
	# streift ein Einzelgänger herum. Vorräume der Kammern sind bewacht.
	var mob_level: Array = def.mobLevel
	var level_at := func(d: float) -> int:
		return maxi(mob_level[0], J.rnd(mob_level[0] + pow(d, 1.3) * 1.6 * (mob_level[1] - mob_level[0]) + R.int_(s, -1, 0)))
	var free_rooms: Array = m.rooms.filter(func(r): return r.kind == "normal" and r.get("antechamberOf") == null and r.get("feature") == null and not room_has_tile(m, r, "stairs"))
	var per_hood: int = int(J.nn(def, "reviere", 2 if floor == 1 else 3))
	for h in 4:
		var pool: Array = R.shuffle(s, free_rooms.filter(func(r): return r.hood == h and r.w * r.h >= 16 and dist(center(r), start) >= 22))
		var chosen := []
		for r in pool:
			if chosen.size() >= per_hood:
				break
			if J.some(chosen, func(c): return dist(center(c), center(r)) < 10):
				continue
			chosen.append(r)
		for r in chosen:
			var d := dist(center(r), start) / float(max_dist)
			var rlv: int = mob_level[0] if floor == 1 and d < 0.3 else level_at.call(d)
			var mdef: Dictionary = Monsters.pick_monster_def(s, floor, rlv)
			var lv := Monsters.clamp_level(mdef, rlv)
			r.revier = {"def": mdef.id, "level": lv}
			r.description += " Spuren, Kratzer und Gestank: Das hier ist ein Revier."
			var n: int = R.int_(s, 2, 3) if floor == 1 and d < 0.3 else R.int_(s, 3, 5)
			for k in n:
				var p = _random_floor_in(s, m, r, occupied)
				if p == null:
					break
				var mob := Monsters.spawn_monster(s, mdef, lv, p, r.hood, d > (0.35 if floor == 1 else 0.2) and R.chance(s, 0.07))
				if mob.behavior != "stationary" and R.chance(s, 0.3):
					mob.asleep = true
				monsters.append(mob)
	for r in m.rooms:
		if r.kind != "normal" or r.get("revier") != null:
			continue
		var d := dist(center(r), start) / float(max_dist)
		var count := 0
		if r.get("antechamberOf") != null:
			count = R.int_(s, 2, 3)
		elif d >= 0.1 and R.chance(s, 0.35 if floor == 1 else 0.15):
			# Auf Etage 1 mehr Einzelgänger: daran wächst man, bevor man ins Revier geht
			count = 1
		for k in count:
			var mdef: Dictionary = Monsters.pick_monster_def(s, floor, level_at.call(d))
			var p = _random_floor_in(s, m, r, occupied)
			if p == null:
				break
			var mob := Monsters.spawn_monster(s, mdef, Monsters.clamp_level(mdef, level_at.call(d)), p, r.hood, false)
			if mob.behavior != "stationary" and R.chance(s, 0.3):
				mob.asleep = true
			monsters.append(mob)

	# --- Bodenfunde: Gegenstände liegen nicht einfach herum. Nur in den
	# Vorräumen der Kammern haben andere ihre Sachen zurückgelassen.
	for r in m.rooms:
		if r.kind != "normal" or r.get("antechamberOf") == null:
			continue
		for i in R.int_(s, 2, 4):
			var p = _random_floor_in(s, m, r, occupied)
			if p != null:
				items.append({"pos": p, "item": Items.roll_ground_item(s)})

	# --- Besondere Räume: Schatz, Nest, Schrein, Händler, Hinterhalt
	# Die Siedlung der Kanalstadt zuerst, damit sie die Räume nahe der Mitte bekommt
	if floor == Kanalstadt.FLOOR_NO:
		Kanalstadt.populate(s, m, monsters, occupied)
	Dungeon.populate(s, m, monsters, items, occupied, floor, start)

	# Geister früherer Crawler, die auf dieser Etage gestorben sind
	var floor_ghosts := ghosts.filter(func(g): return g.floor == floor).slice(0, 2)
	for g in floor_ghosts:
		var candidates := far_rooms.slice(0, 8).filter(func(r): return r.get("feature") != "hinterhalt")
		var room = R.pick(s, candidates) if not candidates.is_empty() else _pick_empty(s)
		var p = _random_floor_in(s, m, room, occupied) if room != null else null
		if p != null:
			monsters.append(Monsters.spawn_ghost(s, g, p, room.hood))

	# --- Toiletten gibt es nicht nur in Safe Rooms: in manchen Räumen und Nischen
	for r in m.rooms:
		if not J.arr(r, "furniture").is_empty() or r.get("feature") != null or r.get("antechamberOf") != null:
			continue
		if (r.kind == "nische" and R.chance(s, 0.5)) or (r.kind == "normal" and r.get("revier") == null and R.chance(s, 0.2)):
			_place_furniture(m, r, ["toilette"])
			if J.arr(r, "furniture").is_empty():
				r.erase("furniture")
			else:
				r.description += " In einer Ecke steht eine Toilette. Einfach so."

	return {"map": m, "monsters": monsters, "items": items, "start": start}


## R.pick auf eine leere Liste: in JavaScript kommt undefined heraus, der
## Zufallszustand rückt trotzdem weiter.
static func _pick_empty(s: Dictionary) -> Variant:
	R.next(s)
	return null


## Safe Rooms einrichten: Automat, Wirt, Händler (erst ab der Etage mit
## Handel), Bett, Toilette und der Bildschirm für die Highlights.
static func _furnish(s: Dictionary, m: Dictionary, r: Dictionary) -> void:
	var kinds := ["automat"]
	if r.get("safeVariant") == "restaurant":
		kinds.append("wirt")
	if int(s.floor) >= Game.unlock_floor("handel"):
		kinds.append("haendler")
	kinds.append_array(["bett", "toilette", "bildschirm"])
	_place_furniture(m, r, kinds)


## Möbel an den Rand eines Raums stellen, ohne Türen oder Wege zu verstellen.
static func _place_furniture(m: Dictionary, r: Dictionary, kinds: Array) -> void:
	var door_within := func(x: int, y: int, d: int) -> bool:
		for dy in range(-d, d + 1):
			for dx in range(-d, d + 1):
				var t2 := tile_at(m, x + dx, y + dy)
				if t2 == "door" or t2 == "dooropen":
					return true
		return false
	var edge := func(x: int, y: int) -> bool: return x == r.x or y == r.y or x == r.x + r.w - 1 or y == r.y + r.h - 1
	var floor_tiles := []
	for y in range(r.y, r.y + r.h):
		for x in range(r.x, r.x + r.w):
			if m.tiles[idx(m, x, y)] == "floor":
				floor_tiles.append(J.pos(x, y))
	var top: Array = J.sort(floor_tiles.filter(func(p): return p.y == r.y and not door_within.call(p.x, p.y, 2)), func(a, b): return a.x - b.x)
	var rest: Array = J.sort(floor_tiles.filter(func(p): return p.y != r.y and edge.call(p.x, p.y) and not door_within.call(p.x, p.y, 2)), func(a, b): return (b.y - a.y) if b.y != a.y else (a.x - b.x))
	var preferred := []
	for i in top.size():
		if i % 2 == 0:
			preferred.append(top[i])
	for i in rest.size():
		if i % 2 == 0:
			preferred.append(rest[i])
	for i in top.size():
		if i % 2 == 1:
			preferred.append(top[i])
	for i in rest.size():
		if i % 2 == 1:
			preferred.append(rest[i])
	var fallback: Array = J.sort(floor_tiles.filter(func(p): return not door_within.call(p.x, p.y, 1)), func(a, b): return int(edge.call(b.x, b.y)) - int(edge.call(a.x, a.y)))
	var pool := preferred.duplicate()
	for p in fallback:
		if not J.some(preferred, func(q): return q.x == p.x and q.y == p.y):
			pool.append(p)
	r.furniture = []
	for kind in kinds:
		while not pool.is_empty():
			var pos: Dictionary = pool.pop_front()
			# Nicht vor einen offenen Zugang stellen (Gänge münden in normale Räume ohne Tür)
			if r.kind != "safe" and r.kind != "guild" and _at_entrance(m, r, pos):
				continue
			r.furniture.append({"kind": kind, "pos": pos})
			if _room_connected(m, r) and J.every(r.furniture, func(f): return _has_free_side(m, r, f.pos)):
				break
			r.furniture.pop_back()


static func _at_entrance(m: Dictionary, r: Dictionary, p: Dictionary) -> bool:
	for d in DIRS4:
		var x: int = p.x + d[0]
		var y: int = p.y + d[1]
		if x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h:
			continue
		if is_walkable(m, x, y):
			return true
	return false


static func _has_free_side(m: Dictionary, r: Dictionary, p: Dictionary) -> bool:
	for d in DIRS4:
		var x: int = p.x + d[0]
		var y: int = p.y + d[1]
		if x < r.x or y < r.y or x >= r.x + r.w or y >= r.y + r.h:
			continue
		if m.tiles[idx(m, x, y)] == "floor" and not J.some(J.arr(r, "furniture"), func(f): return f.pos.x == x and f.pos.y == y):
			return true
	return false


static func _room_connected(m: Dictionary, r: Dictionary) -> bool:
	var blocked := {}
	for f in J.arr(r, "furniture"):
		blocked["%d,%d" % [f.pos.x, f.pos.y]] = true
	var free := []
	for y in range(r.y, r.y + r.h):
		for x in range(r.x, r.x + r.w):
			if m.tiles[idx(m, x, y)] != "wall" and not blocked.has("%d,%d" % [x, y]):
				free.append(J.pos(x, y))
	if free.is_empty():
		return false
	var seen := {"%d,%d" % [free[0].x, free[0].y]: true}
	var queue := [free[0]]
	while not queue.is_empty():
		var c: Dictionary = queue.pop_front()
		for d in DIRS4:
			var nx: int = c.x + d[0]
			var ny: int = c.y + d[1]
			var key := "%d,%d" % [nx, ny]
			if seen.has(key) or blocked.has(key):
				continue
			if nx < r.x or ny < r.y or nx >= r.x + r.w or ny >= r.y + r.h:
				continue
			if m.tiles[idx(m, nx, ny)] == "wall":
				continue
			seen[key] = true
			queue.append(J.pos(nx, ny))
	return seen.size() == free.size()


static func furniture_at(m: Dictionary, p: Dictionary) -> Variant:
	var r: int = m.roomAt[idx(m, p.x, p.y)] if in_bounds(m, p.x, p.y) else -1
	if r < 0:
		return null
	return J.find(J.arr(m.rooms[r], "furniture"), func(f): return f.pos.x == p.x and f.pos.y == p.y)


## Zufällige begehbare Position, die nicht in einem Safe Room liegt.
static func random_open_tile(s: Dictionary, near: Dictionary, radius: int, avoid: Callable) -> Variant:
	var m: Dictionary = s.map
	for i in 200:
		var p := J.pos(near.x + R.int_(s, -radius, radius), near.y + R.int_(s, -radius, radius))
		if not in_bounds(m, p.x, p.y) or not is_walkable(m, p.x, p.y):
			continue
		var r = room_of(m, p)
		if r != null and (r.kind == "safe" or r.kind == "guild"):
			continue
		if avoid.call(p):
			continue
		return p
	return null
