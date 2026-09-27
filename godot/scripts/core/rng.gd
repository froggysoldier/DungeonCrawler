class_name Rng
extends RefCounted
## Deterministischer Zufall (mulberry32), bitgenau wie src/engine/rng.ts.
## Der Zustand ist ein vorzeichenbehafteter 32-Bit-Wert, genau wie im
## TypeScript-Spielstand, damit Seeds und Spielstände übertragbar bleiben.

const MASK := 0xFFFFFFFF

var state: int


func _init(seed_value: int = 0) -> void:
	state = _i32(seed_value)


static func _u32(x: int) -> int:
	return x & MASK


static func _i32(x: int) -> int:
	x &= MASK
	return x - 0x100000000 if x >= 0x80000000 else x


## 32-Bit-Multiplikation wie Math.imul (Ergebnis als u32).
static func _imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var lo := a * (b & 0xFFFF)
	var hi := (a * (b >> 16)) & 0xFFFF
	return (lo + (hi << 16)) & MASK


## Gleichverteilte Zahl in [0, 1).
func next() -> float:
	state = _i32(state + 0x6d2b79f5)
	var t := _u32(state)
	t = _imul(t ^ (t >> 15), t | 1)
	t = t ^ _u32(t + _imul(t ^ (t >> 7), t | 61))
	return float(_u32(t ^ (t >> 14))) / 4294967296.0


## Ganzzahl im Bereich [min_v, max_v] (inklusive).
func range_int(min_v: int, max_v: int) -> int:
	return min_v + floori(next() * (max_v - min_v + 1))


func chance(p: float) -> bool:
	return next() < p


func pick(arr: Array) -> Variant:
	return arr[floori(next() * arr.size())]


## entries: Array von [Wert, Gewicht]
func weighted(entries: Array) -> Variant:
	var total := 0.0
	for e in entries:
		total += e[1]
	var r := next() * total
	for e in entries:
		r -= e[1]
		if r < 0:
			return e[0]
	return entries[entries.size() - 1][0]


func shuffle(arr: Array) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := floori(next() * (i + 1))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr
