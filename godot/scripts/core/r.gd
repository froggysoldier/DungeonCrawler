class_name R
extends RefCounted
## Zufall über den Spielstand: Der Zustand liegt
## in s.rng und wird mit dem Spielstand gespeichert.


static func next(s: Dictionary) -> float:
	var st := Rng._i32(int(s.rng) + 0x6d2b79f5)
	s.rng = st
	var t := Rng._u32(st)
	t = Rng._imul(t ^ (t >> 15), t | 1)
	t = t ^ Rng._u32(t + Rng._imul(t ^ (t >> 7), t | 61))
	return float(Rng._u32(t ^ (t >> 14))) / 4294967296.0


## Ganzzahl im Bereich [a, b] (inklusive).
static func int_(s: Dictionary, a: int, b: int) -> int:
	return a + floori(next(s) * (b - a + 1))


static func chance(s: Dictionary, p: float) -> bool:
	return next(s) < p


static func pick(s: Dictionary, arr: Array) -> Variant:
	return arr[floori(next(s) * arr.size())]


## entries: Array von [Wert, Gewicht]
static func weighted(s: Dictionary, entries: Array) -> Variant:
	var total := 0.0
	for e in entries:
		total += float(e[1])
	var r := next(s) * total
	for e in entries:
		r -= float(e[1])
		if r < 0:
			return e[0]
	return entries[entries.size() - 1][0]


static func shuffle(s: Dictionary, arr: Array) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := floori(next(s) * (i + 1))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr
