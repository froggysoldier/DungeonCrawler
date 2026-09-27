class_name Player
extends RefCounted
## Werte des Crawlers (Port von src/engine/player.ts).

const CURSE_EFFECTS := {
	"Kleingedrucktes": {"maxHp": -5, "stats": {"cha": -1}},
}


## Summe aller Boni aus Ausrüstung, Buffs, Skills und Flüchen.
static func total_bonuses(s: Dictionary) -> Dictionary:
	var b := {}
	var p: Dictionary = s.player
	for slot in p.equipment:
		var item = p.equipment[slot]
		if item != null:
			Bonuses.add(b, item.get("bonuses"))
	for buff in p.buffs:
		Bonuses.add(b, buff.get("bonuses"))
	for sk in p.skills:
		var def = Db.skill(sk.id)
		if def != null:
			Bonuses.add(b, def.get("perLevel"), sk.level)
	for c in p.curses:
		Bonuses.add(b, CURSE_EFFECTS.get(c))
	if p.get("race"):
		var r = Db.race(p.race)
		if r != null:
			Bonuses.add(b, r.get("bonuses"))
	if p.get("klass"):
		var k = Db.klass(p.klass)
		if k != null:
			Bonuses.add(b, k.get("bonuses"))
	Bonuses.add(b, Traits.trait_bonuses(s))
	# Fähigkeiten eines entwickelten Haustiers
	var pet = p.pet
	if pet != null and pet.alive and J.arr(pet, "abilities").has("schutz"):
		Bonuses.add(b, {"ruestung": 2})
	if pet != null and pet.alive and J.arr(pet, "abilities").has("spaeher"):
		Bonuses.add(b, {"lichtradius": 1})
	var mount = p.get("mount")
	if p.get("riding") and mount != null and not mount.get("down"):
		var md = Db.t("mounts", "MOUNTS").get(mount.id)
		Bonuses.add(b, {"ruestung": md.get("ruestung", 0) if md != null and md.get("ruestung") != null else 0})
	# Sondereigenschaften von Rasse und Klasse, die vom Zustand abhängen
	var eq: Dictionary = p.equipment
	if Abilities.has_special(s, "nudist") and eq.get("kopf") == null and eq.get("brust") == null and eq.get("beine") == null:
		Bonuses.add(b, {"ruestung": 4, "ausweichen": 10})
	if Abilities.has_special(s, "zaeh") and p.hp < max_hp(s, b) * 0.25:
		Bonuses.add(b, {"schaden": {"alle": 30}, "ausweichen": 10})
	return b


static func effective_stats(s: Dictionary, b: Variant = null) -> Dictionary:
	if b == null:
		b = total_bonuses(s)
	var out: Dictionary = s.player.stats.duplicate()
	if b.get("stats") != null:
		for k in b.stats:
			out[k] = maxf(1, out[k] + b.stats[k])
	return out


static func max_hp(s: Dictionary, b: Variant = null) -> int:
	if b == null:
		b = total_bonuses(s)
	var st := effective_stats(s, b)
	return int(maxf(5, s.player.maxHpBase + st.kon * 2 + (s.player.level - 1) * 4 + J.num(b, "maxHp")))


static func max_ausdauer(s: Dictionary, b: Variant = null) -> int:
	if b == null:
		b = total_bonuses(s)
	var st := effective_stats(s, b)
	return int(maxf(4, s.player.maxAusdauerBase + st.ges + floorf(st.kon / 2.0) + J.num(b, "maxAusdauer")))


static func ausweichen(s: Dictionary, b: Variant = null) -> float:
	if b == null:
		b = total_bonuses(s)
	var st := effective_stats(s, b)
	return maxf(0, (st.ges - 5) * 1.5 + 5 + J.num(b, "ausweichen"))


static func lichtradius(s: Dictionary, b: Variant = null) -> int:
	if b == null:
		b = total_bonuses(s)
	return maxi(2, floori(6 + J.num(b, "lichtradius") + 1e-9))


static func xp_to_next(level: int) -> int:
	return Progression.xp_to_next(level)


static func gain_xp(s: Dictionary, amount: float) -> int:
	var b := total_bonuses(s)
	var gained := J.rnd(amount * (1 + J.num(b, "xpBonus") / 100.0))
	var p: Dictionary = s.player
	p.xp += gained
	if s.get("stats") == null:
		s.stats = {}
	s.stats["xp.gesamt"] = J.num(s.stats, "xp.gesamt") + gained
	while p.xp >= xp_to_next(p.level):
		p.xp -= xp_to_next(p.level)
		p.level += 1
		p.statPoints += 3
		p.hp = mini(max_hp(s), p.hp + ceili(max_hp(s) / 2.0))
		Log.add(s, "LEVEL %d! %s (+3 Stat-Punkte)" % [p.level, R.pick(s, Db.world("LEVEL_UP_QUIPS"))], "system")
		Log.toast(s, "Level %d!" % p.level, "+3 Stat-Punkte zum Verteilen.", "level")
		Events.emit(s, {"type": "levelUp", "level": p.level})
	return gained


static func clamp_vitals(s: Dictionary) -> void:
	var b := total_bonuses(s)
	s.player.hp = mini(s.player.hp, max_hp(s, b))
	s.player.ausdauer = mini(s.player.ausdauer, max_ausdauer(s, b))


static func skill_level(s: Dictionary, id: String) -> int:
	for k in s.player.skills:
		if k.id == id:
			return k.level
	return 0


static func current_weapon(s: Dictionary) -> Variant:
	var w = s.player.equipment.get("waffe")
	if w != null:
		return w
	var hand = s.player.hand
	if hand != null and hand.get("slot") == "waffe":
		return hand
	return null


static func throwables(s: Dictionary) -> Array:
	var out := []
	var hand = s.player.hand
	if hand != null and hand.kind == "wurf":
		out.append(hand)
	for it in s.player.inventory:
		if it.kind == "wurf":
			out.append(it)
	# Gewähltes Wurfobjekt zuerst, Sprengsätze sonst zuletzt
	var pick = s.player.get("wurfWahl")
	var rank := func(i: Dictionary) -> int:
		if pick and i.baseId == pick:
			return 0
		return 2 if i.get("explosion") else 1
	return J.sort(out, func(a, b): return rank.call(a) - rank.call(b))
