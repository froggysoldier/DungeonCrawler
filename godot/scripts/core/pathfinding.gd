class_name Pathfinding
extends RefCounted
## A*-Suche mit 8 Richtungen (Port von src/engine/path.ts).
## Die Reihenfolge der Richtungen und die Auswahl aus der offenen Liste
## entsprechen genau der TypeScript-Version, damit gleiche Wege entstehen.

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


## Gibt den Pfad ohne Startfeld zurück oder ein leeres Array, wenn es keinen gibt.
## passable: optionale Zusatzbedingung Callable(x, y) -> bool.
static func find_path(m: FloorMap, from: Vector2i, to: Vector2i, passable: Callable = Callable(), max_nodes: int = 4000, through_doors: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not m.in_bounds(to.x, to.y):
		return result
	var walk := func(x: int, y: int) -> bool:
		return m.is_walkable(x, y) or (through_doors and m.tile_at(x, y) == "door")
	var start_i := m.idx(from.x, from.y)
	var goal_i := m.idx(to.x, to.y)
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
			var cur := i
			while cur != start_i:
				result.append(Vector2i(cur % m.width, cur / m.width))
				cur = came[cur]
			result.reverse()
			return result
		if closed.has(i):
			continue
		closed[i] = true
		nodes += 1
		if nodes > max_nodes:
			return result
		var x := i % m.width
		var y := i / m.width
		for d in DIRS:
			var nx := x + d.x
			var ny := y + d.y
			if not m.in_bounds(nx, ny) or not walk.call(nx, ny):
				continue
			# Keine Diagonale durch Wandecken und nicht schräg durch Türrahmen
			if d.x != 0 and d.y != 0 and (not walk.call(x + d.x, y) or not walk.call(x, y + d.y) or m.is_door(x, y) or m.is_door(nx, ny)):
				continue
			var ni := m.idx(nx, ny)
			if ni != goal_i and passable.is_valid() and not passable.call(nx, ny):
				continue
			var ng: float = g[i] + (1.01 if d.x != 0 and d.y != 0 else 1.0)
			if ng < g.get(ni, INF):
				g[ni] = ng
				came[ni] = i
				open_i.append(ni)
				open_f.append(ng + maxi(absi(nx - to.x), absi(ny - to.y)))
	return result


static func can_step(m: FloorMap, from: Vector2i, to: Vector2i) -> bool:
	if not m.is_walkable(to.x, to.y):
		return false
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx != 0 and dy != 0 and (not m.is_walkable(from.x + dx, from.y) or not m.is_walkable(from.x, from.y + dy)):
		return false
	if dx != 0 and dy != 0 and (m.is_door(from.x, from.y) or m.is_door(to.x, to.y)):
		return false
	return true
