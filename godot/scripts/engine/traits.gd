class_name Traits
extends RefCounted
## Eigenschaften aus dem Vorleben.


static func trait_bonuses(s: Dictionary) -> Dictionary:
	var b := {}
	for id in J.arr(s.player, "traits"):
		var t = Db.trait_def(id)
		if t != null:
			Bonuses.add(b, t.get("bonuses"))
	return b


## Situative Boni (Ängste, Erfahrung) für einen konkreten Angriff.
static func trait_attack_bonus(s: Dictionary, facets: Array) -> Dictionary:
	var hit := 0.0
	var dmg := 0.0
	for id in J.arr(s.player, "traits"):
		var t = Db.trait_def(id)
		if t == null:
			continue
		for v in J.arr(t, "vs"):
			if not facets.has(v.facet):
				continue
			hit += J.num(v, "hit")
			dmg += J.num(v, "dmg")
	return {"hit": hit, "dmg": dmg}


static func trait_special(s: Dictionary, special: String) -> bool:
	for id in J.arr(s.player, "traits"):
		var t = Db.trait_def(id)
		if t != null and t.get("special") == special:
			return true
	return false


static func trait_follower_mult(s: Dictionary) -> float:
	var m := 1.0
	for id in J.arr(s.player, "traits"):
		var t = Db.trait_def(id)
		m *= float(t.get("followerMult")) if t != null and t.get("followerMult") != null else 1.0
	return m


## Prüft nach Kämpfen, ob eine Angst überwunden wurde.
static func on_event(s: Dictionary, e: Dictionary) -> void:
	if e.type != "kill" and e.type != "attack":
		return
	var p: Dictionary = s.player
	for id in J.arr(p, "traits").duplicate():
		var t = Db.trait_def(id)
		if t == null or t.get("overcome") == null or not DataChecks.trait_overcome(id, s):
			continue
		var next: Dictionary = Db.trait_def(t.overcome.becomes)
		var traits := J.arr(p, "traits").filter(func(x): return x != id)
		traits.append(next.id)
		p.traits = traits
		Log.add(s, "ÜBERWUNDEN: %s. Neue Eigenschaft: %s. %s" % [t.name, next.name, t.overcome.text], "system")
		Log.toast(s, "Überwunden: %s" % t.name, "Neu: %s" % next.name, "skill")
