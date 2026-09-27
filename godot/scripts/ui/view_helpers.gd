class_name ViewHelpers
extends RefCounted
## Kleine Hilfen, die nur die Oberfläche braucht (Port aus der Web-Version):
## Spielzeit als Uhrzeit, nahe Fallen, nächste Achievement-Ziele.

const BEAST_STAGES := [1, 10, 30]


## Züge als Uhrzeit (3 Minuten pro Zug), ab einem Tag mit „T“.
static func format_time(turns: int) -> String:
	var minutes := turns * 3
	var d := minutes / 1440
	var h := (minutes % 1440) / 60
	var m := minutes % 60
	var hm := "%02d:%02d" % [h, m]
	return "%d T %s" % [d, hm] if d > 0 else hm


## Bekannte Fallen neben dem Crawler (oder unter ihm).
static func disarmable_traps(s: Dictionary) -> Array:
	return J.arr(s, "traps").filter(func(t): return not t.get("hidden", false) and J.cheb(t.pos, s.player.pos) <= 1)


## Das jeweils nächste offene Ziel jeder Achievement-Familie (für die Übersicht).
static func next_goals(s: Dictionary) -> Array:
	var out: Array = []
	var have := {}
	for id in s.achievements:
		have[id] = true
	for fam in Db.t("achievement_families", "familyTable"):
		var stage = null
		for n in fam.stages:
			if not have.has("fam_%s_%s" % [fam.id, J.s(n)]):
				stage = n
				break
		if stage == null:
			continue
		var value: float = float(DataChecks._family_value(fam).call(s))
		out.append({"category": fam.category, "description": String(fam.text).replace("{n}", J.de(stage)), "value": value, "target": stage})
	for m in Db.t("monsters", "MONSTERS"):
		var kills := Stats.stat(s, "kills.art." + m.id)
		if not kills or not Stats.stat(s, "bekannt." + m.id):
			continue
		var idx := -1
		for k in BEAST_STAGES.size():
			if not have.has("art_%s_%d" % [m.id, k + 1]):
				idx = k
				break
		if idx < 0:
			continue
		var n: int = BEAST_STAGES[idx]
		out.append({"category": "bestiarium", "description": "Besiege %d-mal: %s." % [n, m.name], "value": kills, "target": n})
	return out
