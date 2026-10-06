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
	var n := width * height
	# Felder werden erst bei Bedarf eingestuft und dann gemerkt:
	# Bit 1 geprüft, Bit 2 begehbar, Bit 4 Tür, Bit 8 Zusatzbedingung geprüft, Bit 16 erfüllt
	var info := PackedByteArray()
	info.resize(n)
	var has_pass := passable.is_valid()
	var start_i: int = int(from.y) * width + int(from.x)
	var goal_i := ty * width + tx
	var g := PackedFloat64Array()
	g.resize(n)
	g.fill(INF)
	g[start_i] = 0.0
	var came := PackedInt32Array()
	came.resize(n)
	var closed := PackedByteArray()
	closed.resize(n)
	# Offene Liste als Heap; bei gleichem Wert gewinnt der früher eingefügte
	# Eintrag (wie bei der einfachen Suche, damit die Wege gleich bleiben)
	var heap := _Heap.new()
	heap.push(0.0, start_i)
	var nodes := 0
	while heap.size() > 0:
		var i: int = heap.pop()
		if i == goal_i:
			var path := []
			var cur := i
			while cur != start_i:
				path.append({"x": cur % width, "y": cur / width})
				cur = came[cur]
			path.reverse()
			return path
		if closed[i]:
			continue
		closed[i] = 1
		nodes += 1
		if nodes > max_nodes:
			return null
		var x := i % width
		var y := i / width
		var here := _info(info, tiles, i, through_doors)
		for d in DIRS:
			var dx: int = d[0]
			var dy: int = d[1]
			var nx := x + dx
			var ny := y + dy
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var ni := ny * width + nx
			var there := _info(info, tiles, ni, through_doors)
			if there & 2 == 0:
				continue
			# Keine Diagonale durch Wandecken und nicht schräg durch Türrahmen
			if dx != 0 and dy != 0:
				if _info(info, tiles, y * width + nx, through_doors) & 2 == 0 or _info(info, tiles, ny * width + x, through_doors) & 2 == 0 or here & 4 or there & 4:
					continue
			if ni != goal_i and has_pass:
				var pv: int = info[ni]
				if pv & 8 == 0:
					pv |= 8 | (16 if passable.call(nx, ny) else 0)
					info[ni] = pv
				if pv & 16 == 0:
					continue
			var ng: float = g[i] + (1.01 if dx != 0 and dy != 0 else 1.0)
			if ng < g[ni]:
				g[ni] = ng
				came[ni] = i
				heap.push(ng + maxi(absi(nx - tx), absi(ny - ty)), ni)
	return null


static func _info(info: PackedByteArray, tiles: Array, i: int, through_doors: bool) -> int:
	var v: int = info[i]
	if v & 1:
		return v
	var t: String = tiles[i]
	v |= 1
	if t == "floor" or t == "stairs" or t == "dooropen" or t == "wasser" or t == "schlamm" or t == "bruecke" or t == "oel" or (through_doors and t == "door"):
		v |= 2
	if t == "door" or t == "dooropen":
		v |= 4
	info[i] = v
	return v


## Kleinster Wert zuerst, bei Gleichstand der früher eingefügte.
class _Heap:
	var f: Array[float] = []
	var seq: Array[int] = []
	var val: Array[int] = []
	var _n := 0

	func size() -> int:
		return f.size()

	func _less(a: int, b: int) -> bool:
		return f[a] < f[b] or (f[a] == f[b] and seq[a] < seq[b])

	func _swap(a: int, b: int) -> void:
		var tf := f[a]
		f[a] = f[b]
		f[b] = tf
		var ts := seq[a]
		seq[a] = seq[b]
		seq[b] = ts
		var tv := val[a]
		val[a] = val[b]
		val[b] = tv

	func push(fv: float, v: int) -> void:
		f.append(fv)
		seq.append(_n)
		val.append(v)
		_n += 1
		var k := f.size() - 1
		while k > 0:
			var up := (k - 1) / 2
			if not _less(k, up):
				break
			_swap(k, up)
			k = up

	func pop() -> int:
		var top := val[0]
		var last := f.size() - 1
		_swap(0, last)
		f.resize(last)
		seq.resize(last)
		val.resize(last)
		var k := 0
		while true:
			var l := k * 2 + 1
			if l >= last:
				break
			var c := l
			if l + 1 < last and _less(l + 1, l):
				c = l + 1
			if not _less(c, k):
				break
			_swap(c, k)
			k = c
		return top


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
