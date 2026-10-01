class_name Pathfinding
extends RefCounted
## A*-Suche mit 8 Richtungen. Reihenfolge der Richtungen und Auswahl aus
## der offenen Liste sind festgelegt, damit bei gleichem Seed gleiche Wege
## entstehen.

const DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]


## Pfad ohne Startfeld (Liste von {x, y}) oder null, wenn es keinen gibt.
## passable: optionale Zusatzbedingung Callable(x, y) -> bool.
static func find_path(m: Dictionary, from: Dictionary, to: Dictionary, passable: Callable = Callable(), max_nodes: int = 4000, through_doors: bool = false) -> Variant:
	var width: int = m.width
	var height: int = m.height
	var tiles: Array = m.tiles
	var tx: int = to.x
	var ty: int = to.y
	if tx < 0 or ty < 0 or tx >= width or ty >= height:
		return null
	var walk := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= width or y >= height:
			return false
		var t: String = tiles[y * width + x]
		return t == "floor" or t == "stairs" or t == "dooropen" or t == "wasser" or t == "schlamm" or t == "bruecke" or t == "oel" or (through_doors and t == "door")
	var is_door := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= width or y >= height:
			return false
		var t: String = tiles[y * width + x]
		return t == "door" or t == "dooropen"
	var has_pass := passable.is_valid()
	var start_i: int = int(from.y) * width + int(from.x)
	var goal_i := ty * width + tx
	var g := {start_i: 0.0}
	var came := {}
	var open_i: Array[int] = [start_i]
	var open_f: Array[float] = [0.0]
	var closed := {}
	var nodes := 0
	while not open_i.is_empty():
		var best := 0
		for k in range(1, open_i.size()):
			if open_f[k] < open_f[best]:
				best = k
		var i: int = open_i[best]
		open_i.remove_at(best)
		open_f.remove_at(best)
		if i == goal_i:
			var path := []
			var cur := i
			while cur != start_i:
				path.append({"x": cur % width, "y": cur / width})
				cur = came[cur]
			path.reverse()
			return path
		if closed.has(i):
			continue
		closed[i] = true
		nodes += 1
		if nodes > max_nodes:
			return null
		var x := i % width
		var y := i / width
		for d in DIRS:
			var dx: int = d[0]
			var dy: int = d[1]
			var nx := x + dx
			var ny := y + dy
			if not walk.call(nx, ny):
				continue
			# Keine Diagonale durch Wandecken und nicht schräg durch Türrahmen
			if dx != 0 and dy != 0 and (not walk.call(x + dx, y) or not walk.call(x, y + dy) or is_door.call(x, y) or is_door.call(nx, ny)):
				continue
			var ni := ny * width + nx
			if ni != goal_i and has_pass and not passable.call(nx, ny):
				continue
			var ng: float = g[i] + (1.01 if dx != 0 and dy != 0 else 1.0)
			if ng < g.get(ni, INF):
				g[ni] = ng
				came[ni] = i
				open_i.append(ni)
				open_f.append(ng + maxi(absi(nx - tx), absi(ny - ty)))
	return null


static func is_door(m: Dictionary, x: int, y: int) -> bool:
	var t := MapGen.tile_at(m, x, y)
	return t == "door" or t == "dooropen"


static func can_step(m: Dictionary, from: Dictionary, to: Dictionary) -> bool:
	if not MapGen.is_walkable(m, to.x, to.y):
		return false
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	if dx != 0 and dy != 0 and (not MapGen.is_walkable(m, from.x + dx, from.y) or not MapGen.is_walkable(m, from.x, from.y + dy)):
		return false
	if dx != 0 and dy != 0 and (is_door(m, from.x, from.y) or is_door(m, to.x, to.y)):
		return false
	return true
