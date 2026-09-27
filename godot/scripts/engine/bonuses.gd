class_name Bonuses
extends RefCounted
## Bonuswerte addieren und beschreiben (Port von src/engine/bonuses.ts).

const SCALAR := ["maxHp", "maxMp", "maxAusdauer", "ruestung", "ausweichen", "treffer", "krit", "hpRegen", "xpBonus", "dornen", "lichtradius"]

const LABELS := {
	"maxHp": "max. HP", "maxMp": "max. Mana", "maxAusdauer": "max. Ausdauer", "ruestung": "Rüstung", "ausweichen": "% Ausweichen",
	"treffer": "% Treffer", "krit": "% Krit", "hpRegen": "HP-Regeneration", "xpBonus": "% XP", "dornen": "Dornenschaden",
	"lichtradius": "Sichtweite",
}

const STAT_NAMES := {"str": "Stärke", "ges": "Geschick", "kon": "Konstitution", "int": "Intelligenz", "cha": "Charisma"}

const PART_NAMES := {
	"faust": "Faust", "tritt": "Tritt", "knie": "Knie", "ellbogen": "Ellbogen", "kopf": "Kopfstoß", "waffe": "Waffe", "wurf": "Wurf", "alle": "alle Angriffe",
}


## Addiert Bonus b in Bonus a (verändert a) und gibt a zurück.
static func add(a: Dictionary, b: Variant, factor: float = 1) -> Dictionary:
	if b == null:
		return a
	if b.get("stats") != null:
		if a.get("stats") == null:
			a.stats = {}
		for k in b.stats:
			a.stats[k] = J.num(a.stats, k) + b.stats[k] * factor
	if b.get("schaden") != null:
		if a.get("schaden") == null:
			a.schaden = {}
		for k in b.schaden:
			a.schaden[k] = J.num(a.schaden, k) + b.schaden[k] * factor
	for key in SCALAR:
		var v = b.get(key)
		if v:
			a[key] = J.num(a, key) + v * factor
	return a


static func _round1(v: float) -> float:
	return J.rnd(v * 10) / 10.0


static func _sign(v: float) -> String:
	return ("+" + J.s(_round1(v))) if v >= 0 else J.s(_round1(v))


static func describe(b: Variant) -> Array:
	var out := []
	if b == null:
		return out
	if b.get("stats") != null:
		for k in b.stats:
			if b.stats[k]:
				out.append("%s %s" % [_sign(b.stats[k]), STAT_NAMES[k]])
	if b.get("schaden") != null:
		for k in b.schaden:
			if b.schaden[k]:
				out.append("%s %% Schaden (%s)" % [_sign(b.schaden[k]), PART_NAMES.get(k, k)])
	for k in LABELS:
		var v = b.get(k)
		if v:
			out.append("%s %s" % [_sign(v), LABELS[k]])
	return out
