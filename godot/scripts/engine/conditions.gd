class_name Conditions
extends RefCounted
## Zustände im Kampf: Blutung, Brennen, Gift, Furcht, Blindheit.

const CONDITIONS := {
	"blutung": {"name": "Blutung", "state": "blutet", "color": "#e0434a", "text": "verliert jeden Zug Lebenspunkte", "buff": "Blutung", "death": "verblutet"},
	"brennen": {"name": "Brennen", "state": "brennt", "color": "#ff8a2a", "text": "nimmt jeden Zug Feuerschaden, Tiere geraten in Panik", "buff": "Brennen", "death": "verbrannt"},
	"gift": {"name": "Gift", "state": "vergiftet", "color": "#7bd66b", "text": "verliert langsam Lebenspunkte", "buff": "Vergiftet", "death": "an einer Vergiftung gestorben"},
	"furcht": {"name": "Furcht", "state": "verängstigt", "color": "#b38cff", "text": "flieht und greift nicht an", "buff": "Furcht", "death": "vor Angst gestorben"},
	"blind": {"name": "Blindheit", "state": "geblendet", "color": "#d9d9d9", "text": "trifft kaum und sieht fast nichts", "buff": "Geblendet", "death": "blind in den Tod gelaufen"},
}
const IDS := ["blutung", "brennen", "gift", "furcht", "blind"]
const PART := {"blutung": "blutung", "brennen": "feuer", "gift": "gift"}
const IMMUNITY := {"blutung": "blutlos", "brennen": "feuerfest", "gift": "giftimmun", "furcht": "furchtlos", "blind": "scharfsichtig"}


static func susceptibility(s: Dictionary, m: Dictionary, id: String) -> float:
	var f := Observer.target_facets(s, m)
	var boss: bool = m.rank == "nachbarschaftsboss" or m.rank == "boroughboss"
	match id:
		"blutung":
			if f.has("z:konstrukt") or f.has("z:geist") or f.has("z:elementar") or f.has("z:schleim"):
				return 0
			if f.has("z:untot") or f.has("z:pflanze") or f.has("z:mimic"):
				return 0.5
			return 1
		"brennen":
			if Abilities.has(m, "brennend") or f.has("z:geist"):
				return 0
			if f.has("z:aquatisch") or f.has("z:schleim") or f.has("z:konstrukt"):
				return 0.5
			if f.has("z:pflanze") or f.has("z:insekt") or f.has("z:untot"):
				return 2
			return 1
		"gift":
			if Abilities.has(m, "gift") or f.has("z:konstrukt") or f.has("z:geist") or f.has("z:untot") or f.has("z:elementar"):
				return 0
			if f.has("z:mimic") or f.has("z:pflanze"):
				return 0.5
			return 1
		"furcht":
			if boss or f.has("z:konstrukt") or f.has("z:untot") or f.has("z:mimic") or f.has("z:elementar"):
				return 0
			if m.rank == "elite" or m.get("enraged"):
				return 0.5
			return 1
		"blind":
			if f.has("z:konstrukt") or f.has("z:schleim") or f.has("z:pflanze") or f.has("z:mimic"):
				return 0
			if boss:
				return 0.5
			return 1
	return 1


static func has_condition(m: Dictionary, id: String) -> bool:
	var c = m.get("conditions")
	return c != null and J.num(c.get(id), "turns") > 0


static func inflict(s: Dictionary, m: Dictionary, id: String, turns: int, power: float, source: String = "du") -> bool:
	var sus := susceptibility(s, m, id)
	var seen := Sight.player_sees(s, m.pos)
	var def: Dictionary = CONDITIONS[id]
	if sus <= 0:
		if seen:
			Log.add(s, "%s ist immun gegen %s." % [Identify.name_of_cap(s, m), def.name], "kampf")
		return false
	if sus < 1 and not R.chance(s, sus):
		if seen:
			Log.add(s, "%s widersteht der %s." % [Identify.name_of_cap(s, m), def.name], "kampf")
		return false
	if m.get("conditions") == null:
		m.conditions = {}
	var cur = m.conditions.get(id)
	if id == "brennen" and source == "du" and Abilities.has_special(s, "brandstifter"):
		power *= 1.5
		turns += 1
	var strength := maxi(1, J.rnd(power * (1.5 if sus > 1 else 1.0)))
	if cur != null and cur.turns > 0:
		cur.turns = maxi(cur.turns, turns)
		cur.power = mini(strength * 3, cur.power + strength) if id == "blutung" else maxi(cur.power, strength)
	else:
		m.conditions[id] = {"turns": turns, "power": strength}
		if seen:
			Log.add(s, "%s %s!" % [Identify.name_of_cap(s, m), def.state], "kampf")
			Fx.float_text(s, m.pos, def.state, def.color)
	if id == "furcht":
		m.fleeing = true
		m.asleep = false
	if source == "du":
		Stats.track(s, "zustand.%s" % id)
	return true


## Zu Beginn eines Monsterzugs. Gibt true zurück, wenn das Monster daran gestorben ist.
static func turn(s: Dictionary, m: Dictionary, kill: Callable) -> bool:
	var c = m.get("conditions")
	if c == null:
		return false
	for id in IDS:
		var cur = c.get(id)
		if cur == null or cur.turns <= 0:
			continue
		cur.turns -= 1
		var part = PART.get(id)
		if part != null:
			var dmg := maxi(1, cur.power)
			m.hp -= dmg
			s.counters.damageDealt += dmg
			if Sight.player_sees(s, m.pos):
				Fx.float_text(s, m.pos, str(dmg), CONDITIONS[id].color)
				Log.add(s, "%s %s: %d Schaden." % [Identify.name_of_cap(s, m), CONDITIONS[id].state, dmg], "kampf")
			if m.hp <= 0:
				kill.call(m, part)
				return true
		if cur.turns <= 0:
			c.erase(id)
			if id == "furcht":
				m.fleeing = false
			if Sight.player_sees(s, m.pos):
				var what: String
				match id:
					"furcht": what = "fasst wieder Mut"
					"blind": what = "kann wieder sehen"
					"brennen": what = "brennt nicht mehr"
					"blutung": what = "blutet nicht mehr"
					_: what = "hat das Gift überstanden"
				Log.add(s, "%s %s." % [Identify.name_of_cap(s, m), what], "kampf")
	return false


static func condition_list(m: Dictionary) -> Array:
	var out := []
	for id in IDS:
		if has_condition(m, id):
			var d: Dictionary = CONDITIONS[id]
			out.append({"id": id, "name": d.name, "state": d.state, "color": d.color, "turns": m.conditions[id].turns})
	return out


static func player_immune(s: Dictionary, id: String) -> bool:
	var special = IMMUNITY.get(id)
	return special != null and Abilities.has_special(s, special)


static func inflict_player(s: Dictionary, id: String, turns: int, power: int, source: String) -> bool:
	var p: Dictionary = s.player
	if id == "gift":
		Abilities.poison(s, source, power)
		return true
	var def: Dictionary = CONDITIONS[id]
	if player_immune(s, id):
		var verb := "blenden" if id == "blind" else ("einschüchtern" if id == "furcht" else ("in Brand setzen" if id == "brennen" else "aufschlitzen"))
		Log.add(s, "%s will dich %s – es perlt an dir ab." % [source, verb], "info")
		return false
	var st := Player.effective_stats(s)
	if id == "furcht" and R.chance(s, minf(0.75, 0.1 + (st.cha - 5) * 0.05 + (p.level - 1) * 0.02)):
		Log.add(s, "%s versucht, dir Angst einzujagen. Du lachst nur." % source, "info")
		return false
	if id == "blind" and R.chance(s, minf(0.6, 0.05 + (st.ges - 5) * 0.04)):
		Log.add(s, "%s will dich blenden – du drehst rechtzeitig den Kopf weg." % source, "info")
		return false
	var existing = J.find(p.buffs, func(b): return b.name == def.buff)
	var bonuses := {}
	if id == "furcht":
		bonuses = {"treffer": -15, "schaden": {"alle": -15}}
	elif id == "blind":
		bonuses = {"treffer": -25, "lichtradius": -4}
	var dot = power if id == "blutung" or id == "brennen" else null
	if existing != null:
		existing.turns = maxi(existing.turns, turns)
		if dot:
			existing.dot = mini(power * 3, int(J.num(existing, "dot")) + power) if id == "blutung" else maxi(int(J.num(existing, "dot")), power)
	else:
		p.buffs.append(Items.compact({"name": def.buff, "turns": turns, "bonuses": bonuses, "dot": dot, "debuff": true}))
	Fx.float_text(s, p.pos, def.state, def.color)
	var what: String
	match id:
		"blutung": what = "Du blutest! (%d Schaden pro Zug – ein Verband hilft)" % power
		"brennen": what = "Du brennst! (%d Schaden pro Zug – Warten heißt: am Boden wälzen)" % power
		"furcht": what = "Die Angst packt dich. Deine Hände zittern (−15 % Treffer und Schaden)."
		_: what = "Du bist geblendet! Du siehst kaum noch etwas (−25 % Treffer, weniger Sicht)."
	Log.add(s, "%s: %s" % [source, what], "gefahr")
	Events.emit(s, {"type": "conditioned", "condition": id, "source": source})
	return true


static func clear_player(s: Dictionary, id: String) -> bool:
	var name: String = CONDITIONS[id].buff
	var before: int = s.player.buffs.size()
	s.player.buffs = s.player.buffs.filter(func(b): return b.name != name)
	return s.player.buffs.size() < before


static func player_has(s: Dictionary, id: String) -> bool:
	return J.some(s.player.buffs, func(b): return b.name == CONDITIONS[id].buff)


static func death_by_buff(name: String) -> String:
	for id in IDS:
		if CONDITIONS[id].buff == name:
			return CONDITIONS[id].death
	return "an den Folgen gestorben"
