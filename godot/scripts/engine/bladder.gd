class_name Bladder
extends RefCounted
## Die Toiletten-Regel.

const WARNINGS := [
	[60, "Du müsstest mal. Nichts Dringendes. Noch nicht."],
	[80, "Du musst jetzt wirklich dringend. Such eine Toilette in einem Safe Room."],
	[95, "ES IST GLEICH SO WEIT. Die Systemstimme erinnert an die Regel: nur in Toiletten!"],
]


static func add(s: Dictionary, amount: float) -> void:
	var p: Dictionary = s.player
	var before := J.num(p, "blase")
	p.blase = minf(100, before + amount)
	for w in WARNINGS:
		var t: int = w[0]
		if before < t and p.blase >= t:
			Log.add(s, w[1], "gefahr" if t >= 80 else "info")
			if t >= 80:
				Log.toast(s, "Blase", w[1], "warnung")
	if p.blase >= 100:
		_accident(s)


static func tick(s: Dictionary, turns: int) -> void:
	if not s.unlocks.has("inventar"):
		return
	add(s, turns / 6.0)


static func _accident(s: Dictionary) -> void:
	var p: Dictionary = s.player
	p.blase = 0
	Log.add(s, "Oh nein. Es ist passiert. Nicht in einer Toilette. Die Luft beginnt zu brodeln …", "gefahr")
	var def = Monsters.def_by_id("wutelementar")
	var spot = null
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if spot != null or (dx == 0 and dy == 0):
				continue
			var q := J.pos(p.pos.x + dx, p.pos.y + dy)
			if MapGen.is_walkable(s.map, q.x, q.y) and not J.some(s.monsters, func(m): return m.pos.x == q.x and m.pos.y == q.y):
				spot = q
	if def != null and spot != null:
		var m := Monsters.spawn_monster(s, def, maxi(15, p.level + 12), spot, -1)
		m.aware = true
		s.monsters.append(m)
		Log.add(s, "Ein WUTELEMENTAR erscheint. Es ist sehr, sehr wütend über das, was du getan hast. LAUF.", "gefahr")
		Log.toast(s, "Wutelementar!", "Du hast gegen die Toiletten-Regel verstoßen. Lauf!", "warnung")
	Events.emit(s, {"type": "accident"})


static func use_toilet(s: Dictionary) -> Dictionary:
	var p: Dictionary = s.player
	if J.num(p, "blase") < 5:
		return {"ok": false, "message": "Du musst gerade nicht."}
	p.blase = 0
	Log.add(s, "Du benutzt die Toilette. Erleichterung. Die Systemstimme dreht diskret die Kamera weg. Meistens.", "info")
	Events.emit(s, {"type": "relief"})
	return {"ok": true}
