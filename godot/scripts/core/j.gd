class_name J
extends RefCounted
## Hilfsfunktionen mit festgelegtem Verhalten (Rundung, stabile Sortierung,
## Zahlenformat wie in JavaScript). Die Spiellogik stammt aus der früheren
## TypeScript-Version; Spielstände und Replays hängen davon ab, dass diese
## Hilfen genau so bleiben.


## Math.round: rundet .5 immer nach oben (auch bei negativen Zahlen).
static func rnd(x: float) -> int:
	return floori(x + 0.5)


## Zahl als Text wie String(number) in JavaScript: 3 statt 3.0, 1.5 bleibt 1.5.
static func s(v: Variant) -> String:
	if v is int:
		return str(v)
	if v is float:
		var f: float = v
		if is_nan(f):
			return "NaN"
		if is_inf(f):
			return "Infinity" if f > 0 else "-Infinity"
		if f == floorf(f) and absf(f) < 1e21:
			return str(int(f))
		# Kürzeste Darstellung, die denselben Wert ergibt
		for p in range(1, 18):
			var t := String.num(f, p)
			if t.to_float() == f:
				return t
		return String.num(f, 17)
	return str(v)


## Zahl mit Tausenderpunkten wie toLocaleString('de-DE') (ganze Zahlen).
static func de(n: Variant) -> String:
	var v := rnd(float(n)) if n is float else int(n)
	var neg := v < 0
	var digits := str(absi(v))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if neg else "") + out


## Stabile Sortierung wie Array.prototype.sort mit Vergleichsfunktion.
## cmp(a, b) liefert eine Zahl (< 0: a zuerst). Sortiert an Ort und Stelle.
static func sort(arr: Array, cmp: Callable) -> Array:
	if arr.size() < 2:
		return arr
	var tmp := arr.duplicate()
	_merge(arr, tmp, 0, arr.size(), cmp)
	return arr


static func _merge(a: Array, tmp: Array, lo: int, hi: int, cmp: Callable) -> void:
	if hi - lo < 2:
		return
	if hi - lo <= 8:
		# Einfügesortierung für kleine Stücke (stabil)
		for i in range(lo + 1, hi):
			var v = a[i]
			var j := i - 1
			while j >= lo and float(cmp.call(a[j], v)) > 0:
				a[j + 1] = a[j]
				j -= 1
			a[j + 1] = v
		return
	var mid := (lo + hi) >> 1
	_merge(a, tmp, lo, mid, cmp)
	_merge(a, tmp, mid, hi, cmp)
	var i := lo
	var j := mid
	var k := lo
	while i < mid and j < hi:
		if float(cmp.call(a[j], a[i])) < 0:
			tmp[k] = a[j]
			j += 1
		else:
			tmp[k] = a[i]
			i += 1
		k += 1
	while i < mid:
		tmp[k] = a[i]
		i += 1
		k += 1
	while j < hi:
		tmp[k] = a[j]
		j += 1
		k += 1
	for x in range(lo, hi):
		a[x] = tmp[x]


## Array.prototype.sort() ohne Vergleichsfunktion: nach Text sortieren.
static func sort_text(arr: Array) -> Array:
	return sort(arr, func(a, b): return -1 if str(a) < str(b) else (1 if str(a) > str(b) else 0))


## Vergleich zweier Texte (für localeCompare bei einfachen IDs).
static func cmp_text(a: String, b: String) -> int:
	return -1 if a < b else (1 if a > b else 0)


## [...new Set(arr)]: doppelte Einträge entfernen, Reihenfolge behalten.
static func uniq(arr: Array) -> Array:
	var seen := {}
	var out := []
	for v in arr:
		if seen.has(v):
			continue
		seen[v] = true
		out.append(v)
	return out


## Math.log10 (exakt für Zehnerpotenzen).
static func log10(x: float) -> float:
	var r := log(x) / log(10.0)
	var n := roundf(r)
	if absf(r - n) < 1e-9 and pow(10.0, n) == x:
		return n
	return r


## Math.sign
static func sign(x: float) -> int:
	return 1 if x > 0 else (-1 if x < 0 else 0)


## String.prototype.replace mit Text: ersetzt nur das erste Vorkommen.
static func replace1(text: String, what: String, with: String) -> String:
	var i := text.find(what)
	if i < 0:
		return text
	return text.substr(0, i) + with + text.substr(i + what.length())


## Erster Buchstabe groß (charAt(0).toUpperCase() + slice(1)).
static func cap(text: String) -> String:
	if text.is_empty():
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)


static func pos(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y}


static func pcopy(p: Dictionary) -> Dictionary:
	return {"x": int(p.x), "y": int(p.y)}


static func peq(a: Dictionary, b: Dictionary) -> bool:
	return a.x == b.x and a.y == b.y


## Chebyshev-Abstand zweier Positionen.
static func cheb(a: Dictionary, b: Dictionary) -> int:
	return maxi(absi(int(a.x) - int(b.x)), absi(int(a.y) - int(b.y)))


## Wert oder Ersatz, wenn er fehlt oder null ist (a ?? b).
static func nn(d: Dictionary, key: String, fallback: Variant) -> Variant:
	var v = d.get(key)
	return fallback if v == null else v


## Zahl aus einem Dictionary (fehlend = 0).
static func num(d: Variant, key: String) -> float:
	if d == null:
		return 0.0
	var v = d.get(key)
	return 0.0 if v == null else float(v)


## Liste aus einem Dictionary (fehlend = leere Liste, die nicht gespeichert wird).
static func arr(d: Variant, key: String) -> Array:
	if d == null:
		return []
	var v = d.get(key)
	return [] if v == null else v


## Entfernt Einträge per Identität (filter(x => x !== item)).
static func without(list: Array, item: Variant) -> Array:
	return list.filter(func(x): return not is_same(x, item))


## Enthält die Liste genau dieses Objekt (includes mit Identität)?
static func has_same(list: Array, item: Variant) -> bool:
	for x in list:
		if is_same(x, item):
			return true
	return false


## Summe über eine Liste.
static func sum(list: Array, f: Callable) -> float:
	var t := 0.0
	for x in list:
		t += float(f.call(x))
	return t


## Erstes Element, das die Bedingung erfüllt (oder null).
static func find(list: Array, f: Callable) -> Variant:
	for x in list:
		if f.call(x):
			return x
	return null


## Index des ersten Elements, das die Bedingung erfüllt (oder -1).
static func find_index(list: Array, f: Callable) -> int:
	for i in list.size():
		if f.call(list[i]):
			return i
	return -1


static func some(list: Array, f: Callable) -> bool:
	for x in list:
		if f.call(x):
			return true
	return false


static func every(list: Array, f: Callable) -> bool:
	for x in list:
		if not f.call(x):
			return false
	return true


## Wandelt Zahlen aus JSON (immer float) in int um, wenn sie ganzzahlig sind.
static func normalize(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if f == floorf(f) and absf(f) < 9.0e15:
			return int(f)
		return f
	if v is Array:
		var a: Array = v
		for i in a.size():
			a[i] = normalize(a[i])
		return a
	if v is Dictionary:
		var d: Dictionary = v
		for k in d.keys():
			d[k] = normalize(d[k])
		return d
	return v


## JSON lesen und Zahlen normalisieren.
static func parse(text: String) -> Variant:
	return normalize(JSON.parse_string(text))


static func load_json(path: String) -> Variant:
	return parse(FileAccess.get_file_as_string(path))
