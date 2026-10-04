class_name TH
extends RefCounted
## Hilfen für die Spiellogik-Tests.


static func make(seed: int = 1234, answers: Variant = [0, 0, 0, 0, 0], meta: Variant = null) -> Dictionary:
	return Game.new_game({"name": "Test", "answers": answers, "seed": seed, "meta": meta if meta != null else Meta.empty_meta()})


static func teleport(s: Dictionary, p: Dictionary) -> void:
	s.player.pos = {"x": int(p.x), "y": int(p.y)}


static func room(s: Dictionary, kind: String) -> Variant:
	return J.find(s.map.rooms, func(r): return r.kind == kind)


static func stairs(s: Dictionary) -> Dictionary:
	var i: int = s.map.tiles.find("stairs")
	return {"x": i % int(s.map.width), "y": i / int(s.map.width)}


static func free_neighbor(s: Dictionary, p: Dictionary) -> Variant:
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var q := {"x": int(p.x) + d[0], "y": int(p.y) + d[1]}
		if MapGen.is_walkable(s.map, q.x, q.y):
			return q
	return null


static func monster_def(id: String) -> Dictionary:
	return Db.monster(id)


## Ein Monster direkt neben den Crawler setzen (alle anderen entfernen).
static func spawn_near(s: Dictionary, def_id: String = "kellerratte", level: int = 1, clear: bool = true) -> Dictionary:
	if clear:
		s.monsters = []
	var spot = free_neighbor(s, s.player.pos)
	var m := Monsters.spawn_monster(s, Db.monster(def_id), level, spot, 0)
	s.monsters.append(m)
	return m


static func ids(list: Array) -> Array:
	return list.map(func(x): return x.id)


static func cheb(a: Dictionary, b: Dictionary) -> int:
	return J.cheb(a, b)


## Spielbereit machen: Tutorial in der Gilde erledigen, leerer normaler Raum
## (mindestens min_w breit). Gibt die linke obere Ecke des Raums zurück.
static func ready(s: Dictionary, min_w: int = 5) -> Dictionary:
	var guild = room(s, "guild")
	s.player.pos = {"x": guild.x + 1, "y": guild.y + 1}
	s.monsters = []
	Game.move_step(s, {"x": guild.x + 2, "y": guild.y + 1})
	s.player.pet = null
	s.crawlers = []
	s.traps = []
	var r = J.find(s.map.rooms, func(x): return x.kind == "normal" and x.w >= min_w)
	if r == null:
		# Kein so breiter Raum: der breiteste normale
		r = J.sort(s.map.rooms.filter(func(x): return x.kind == "normal"), func(a, b): return b.w - a.w)[0]
	s.player.pos = {"x": r.x + 1, "y": r.y + 1}
	return r


## Gegner neben den spielbereiten Crawler setzen (wach, ohne Fähigkeiten).
static func foe(s: Dictionary, id: String, level: int) -> Dictionary:
	var r := ready(s)
	var m := Monsters.spawn_monster(s, Db.monster(id), level, {"x": r.x + 2, "y": r.y + 1}, 0)
	m.aware = true
	m.abilities = []
	s.monsters.append(m)
	return m


## Bis Etage 3 hinabsteigen (Treppe für Treppe).
static func to_floor3(s: Dictionary) -> void:
	while s.floor < 3:
		teleport(s, stairs(s))
		Game.descend(s, {"ghosts": []})


## Nur das Tutorial in der Gilde erledigen (Inventar, Zauber, Stats frei).
static func tutorial(s: Dictionary) -> void:
	var guild = room(s, "guild")
	s.player.pos = {"x": guild.x + 1, "y": guild.y + 1}
	s.monsters = []
	Game.move_step(s, {"x": guild.x + 2, "y": guild.y + 1})


## Wacher Gegner direkt neben dem Crawler (die anderen bleiben).
static func beside(s: Dictionary, id: String, level: int = 2) -> Dictionary:
	var m := Monsters.spawn_monster(s, Db.monster(id), level, free_neighbor(s, s.player.pos), 0)
	m.aware = true
	s.monsters.append(m)
	return m
