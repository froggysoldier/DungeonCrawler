class_name Combat
extends RefCounted
## Nahkampf, Würfe, Treffer und Kills.

const MOVE_NAMES := {"normal": "Normal", "sprung": "Sprung", "stampfen": "Stampfen", "anlauf": "Anlauf"}
const ATTACK_PARTS := ["faust", "tritt", "knie", "ellbogen", "kopf", "waffe", "wurf"]
const ATTACK_MOVES := ["normal", "sprung", "stampfen", "anlauf"]
const BASE_DAMAGE := {"faust": 3, "tritt": 4, "knie": 4, "ellbogen": 4, "kopf": 5}
const MOVE_MULT := {"normal": 1.0, "sprung": 1.5, "stampfen": 1.8, "anlauf": 1.4}
const MOVE_TREFFER := {"normal": 0, "sprung": -10, "stampfen": 15, "anlauf": -5}
const MOVE_COST := {"normal": 1, "sprung": 4, "stampfen": 2, "anlauf": 3}
const WURF_RANGE := 6
const ZONES := {
	"kopf": {"name": "Kopf", "treffer": -15, "schaden": 1.5, "effekt": "schwer zu treffen, +50 % Schaden, kann benommen machen (Gegner setzt aus)"},
	"koerper": {"name": "Körper", "treffer": 5, "schaden": 1.0, "effekt": "sicherstes Ziel, normaler Schaden"},
	"arme": {"name": "Arme", "treffer": -5, "schaden": 0.8, "effekt": "weniger Schaden, schwächt oft die Angriffe des Gegners für einige Züge"},
	"beine": {"name": "Beine", "treffer": -5, "schaden": 0.85, "effekt": "weniger Schaden, Gegner humpelt oft und fällt leichter um"},
}
const HIT_ZONES := ["kopf", "koerper", "arme", "beine"]


static func _zone(t: Dictionary) -> String:
	var z = t.get("zone")
	return z if z else "koerper"


static func _zone_modifier(s: Dictionary, target: Dictionary, t: Dictionary) -> float:
	var zone := _zone(t)
	var mod: float = ZONES[zone].treffer
	if zone != "koerper":
		mod += mini(15, Player.skill_level(s, "anatomie") * 2)
	if zone == "kopf":
		if target.downed > 0:
			mod += 25
		elif target.size == "riesig":
			mod -= 20
		elif target.size == "gross" and (t.part == "faust" or t.part == "kopf" or t.part == "ellbogen"):
			mod -= 10
		elif target.size == "winzig":
			mod -= 10
		if t.part == "tritt" and t.move == "sprung":
			mod += 10
	if zone == "beine" and Abilities.has(target, "fliegend"):
		mod -= 20
	return mod


static func attack_cost(t: Dictionary) -> int:
	return MOVE_COST[t.move] + (1 if t.part == "kopf" else 0)


static func technique_name(t: Dictionary) -> String:
	var part: String = Bonuses.PART_NAMES[t.part]
	var base := part if t.move == "normal" else "%s-%s" % [MOVE_NAMES[t.move], part]
	var z = t.get("zone")
	return ("%s (%s)" % [base, ZONES[z].name]) if z and z != "koerper" else base


## „Dein Tritt“, aber „Deine Faust“ und „Deine Waffe“.
static func your(t: Dictionary) -> String:
	return "Deine" if t.part == "faust" or t.part == "waffe" else "Dein"


static func is_in_safe_room(s: Dictionary, p: Dictionary) -> bool:
	var r = MapGen.room_of(s.map, p)
	return r != null and r.kind == "safe"


## Lootboxen öffnen geht in Safe Rooms und Gilden.
static func can_open_boxes(s: Dictionary, p: Dictionary) -> bool:
	var r = MapGen.room_of(s.map, p)
	return r != null and (r.kind == "safe" or r.kind == "guild")


## Grund, warum eine Technik nicht geht (oder null).
static func technique_blocker(s: Dictionary, target: Dictionary, t: Dictionary) -> Variant:
	var p: Dictionary = s.player
	var d := J.cheb(p.pos, target.pos)
	if is_in_safe_room(s, p.pos) or is_in_safe_room(s, target.pos):
		return "Im Safe Room ist Gewalt verboten."
	if t.part == "wurf":
		if t.move != "normal":
			return "Würfe gehen nur normal."
		if Player.throwables(s).is_empty():
			return "Du hast nichts zum Werfen."
		if d > WURF_RANGE:
			return "Zu weit weg zum Werfen."
		if not Fov.has_line_of_sight(s.map, p.pos, target.pos):
			return "Keine freie Wurfbahn."
		return null
	if d > 1:
		return "Zu weit weg – du musst direkt daneben stehen."
	if t.part == "waffe" and Player.current_weapon(s) == null:
		return "Du hast keine Waffe."
	if t.move == "stampfen" and target.downed <= 0 and target.size != "winzig":
		return "Stampfen geht nur auf Gegner, die am Boden liegen (oder winzig sind)."
	if t.move == "stampfen" and t.part != "tritt":
		return "Stampfen geht nur mit dem Fuß."
	if t.move == "stampfen" and Abilities.has(target, "fliegend"):
		return "%s fliegt – draufstampfen unmöglich." % Identify.name_of_cap(s, target)
	var mounted: bool = p.get("riding") and p.get("mount") != null and not p.mount.get("down")
	if t.move == "anlauf" and not mounted:
		var dir = p.lastMoveDir
		if dir == null:
			return "Für Anlauf musst du dich im letzten Zug auf den Gegner zubewegt haben."
		var dx := J.sign(target.pos.x - p.pos.x)
		var dy := J.sign(target.pos.y - p.pos.y)
		if dir.x * dx + dir.y * dy <= 0:
			return "Für Anlauf musst du dich im letzten Zug auf den Gegner zubewegt haben."
	if p.ausdauer < (1 if mounted and t.move == "anlauf" else attack_cost(t)):
		return "Nicht genug Ausdauer."
	return null


## Trefferchance in Prozent (5–95).
static func hit_chance(s: Dictionary, target: Dictionary, t: Dictionary) -> int:
	var b := Player.total_bonuses(s)
	var st := Player.effective_stats(s, b)
	var hit: float = 75 + (st.ges - 5) * 2 + J.num(b, "treffer") + MOVE_TREFFER[t.move] - target.ausweichen
	for row in Skills.matching_skills(s, t):
		hit += J.num(row.def, "matchTreffer") * row.st.level
	if t.part == "wurf":
		hit -= 5 + J.cheb(s.player.pos, target.pos) * 2
	if not target.aware:
		hit += 20
	if target.downed > 0:
		hit += 25
	hit += _zone_modifier(s, target, t)
	hit += Progression.level_gap_hit(s.player.level, target.level)
	var facets := Observer.attack_facets(s, target, t)
	hit += Observer.dyn_attack_bonus(s, facets, t).hit + Traits.trait_attack_bonus(s, facets).hit
	return maxi(5, mini(95, J.rnd(hit)))


static func player_attack(s: Dictionary, target: Dictionary, t: Dictionary) -> Dictionary:
	var blocker = technique_blocker(s, target, t)
	if blocker != null:
		return {"ok": false, "reason": blocker}
	var p: Dictionary = s.player
	var b := Player.total_bonuses(s)
	var st := Player.effective_stats(s, b)
	var skills := Skills.matching_skills(s, t)
	var ambush: bool = not target.aware
	var ram := 0
	if t.move == "anlauf":
		ram = J.rnd(Mounts.ram_bonus(s) * (1 + 0.08 * Player.skill_level(s, "reiten")) * (1.5 if Abilities.has_special(s, "sattelfest") else 1.0))
	p.ausdauer -= 1 if ram else attack_cost(t)
	if not ram and attack_cost(t) >= 3:
		Skills.train_skill(s, "stamina", Skills.learn_factor(s, target.level))

	# --- Wurfobjekt bestimmen und verbrauchen
	var thrown = null
	if t.part == "wurf":
		var src: Dictionary = Player.throwables(s)[0]
		thrown = src.duplicate()
		thrown.menge = 1
		if p.hand != null and p.hand.uid == src.uid:
			if int(J.nn(src, "menge", 1)) > 1:
				src.menge = int(J.nn(src, "menge", 1)) - 1
			else:
				p.hand = null
		else:
			src.menge = int(J.nn(src, "menge", 1)) - 1
			if int(J.nn(src, "menge", 0)) <= 0:
				p.inventory = p.inventory.filter(func(i): return i.uid != src.uid)
		s.counters.throws += 1

	var facets := Observer.attack_facets(s, target, t)
	target.provoked = true
	Ai.make_noise(s, target.pos, 4 if t.part == "wurf" else (5 if t.move == "normal" else 7))
	var is_hit := R.next(s) * 100 < hit_chance(s, target, t)

	var name := technique_name(t)
	if thrown != null:
		Fx.shot(s, p.pos, target.pos, "bombe" if thrown.get("explosion") else "stein")
	else:
		Fx.strike(s, p.pos, target.pos)
	if not is_hit:
		Fx.float_text(s, target.pos, "daneben", Fx.COLORS.info)
		s.counters.missStreak += 1
		Log.add(s, "%s %s verfehlt %s." % [your(t), name, Identify.name_of(s, target)], "kampf")
		target.aware = true
		if thrown != null and thrown.get("special") == "bumerang":
			_return_thrown(s, thrown)
		elif thrown != null and thrown.get("explosion"):
			_detonate(s, thrown, target.pos)
		elif thrown != null and thrown.get("wurfZustand"):
			_burst(s, thrown, target.pos)
		elif thrown != null:
			drop_near(s, thrown, target.pos)
		Events.emit(s, Items.compact({"type": "attack", "technique": t, "hit": false, "crit": false, "damage": 0, "target": target, "thrown": thrown, "facets": facets}))
		return {"ok": true}
	s.counters.missStreak = 0

	# --- Schaden
	var base: float
	if t.part == "waffe":
		var w = Player.current_weapon(s)
		base = (float(J.nn(w, "waffenSchaden", 2)) if w != null else 2.0) + st.str / 2.0
	elif t.part == "wurf":
		base = float(J.nn(thrown, "wurfSchaden", 2)) + st.ges / 3.0
	else:
		base = BASE_DAMAGE[t.part] + st.str / 2.0
	base += ram
	var sch = b.get("schaden")
	var pct: float = J.num(sch, t.part) + J.num(sch, "alle") + Observer.dyn_attack_bonus(s, facets, t).dmg + Traits.trait_attack_bonus(s, facets).dmg
	for row in skills:
		pct += J.num(row.def, "matchDamage") * row.st.level
	if ambush:
		pct += 25 * Player.skill_level(s, "hinterhalt")
		Skills.train_ambush(s)
		if target.get("asleep"):
			Skills.train_skill(s, "sneak", 2 * Skills.learn_factor(s, target.level))
	if Abilities.has_special(s, "jaeger") and J.num(s.counters.killsByDef, target.defId) >= 10:
		pct += 15
	var zone := _zone(t)
	var dmg: float = base * MOVE_MULT[t.move] * ZONES[zone].schaden * (1 + pct / 100.0) * (0.8 + R.next(s) * 0.4)
	if target.hp < target.maxHp * 0.35 and J.some(p.buffs, func(x): return x.name == "Gnadenstoß"):
		dmg *= 3
	if target.downed > 0:
		dmg *= 1.2
	if Abilities.has(target, "gepanzert") and t.part == "faust":
		dmg *= 0.5
	var crit_chance: float = 5 + J.num(b, "krit") + maxf(0, st.ges - 5) + (5 if zone == "kopf" else 0)
	var crit := R.next(s) * 100 < crit_chance
	if crit:
		dmg *= 2
		s.counters.crits += 1
	var final := maxi(1, J.rnd(dmg - target.ruestung))

	target.hp -= final
	target.aware = true
	Fx.float_text(s, target.pos, ("%d!" % final) if crit else str(final), Fx.COLORS.krit if crit else Fx.COLORS.schaden)
	Fx.hit(s, target.pos, crit)
	target.hitBy = J.uniq(J.arr(target, "hitBy") + [t.part])
	target.zonesHit = J.uniq(J.arr(target, "zonesHit") + [zone])
	s.counters.damageDealt += final
	var crit_txt := " KRITISCH!" if crit else ""
	Log.add(s, "%s%s %s trifft %s für %d Schaden.%s" % ["Überraschungsangriff! " if ambush else "", your(t), name, Identify.name_of(s, target), final, crit_txt], "kampf")

	# Kopfstoß tut auch dir weh – außer du bist geübt darin.
	if t.part == "kopf" and R.chance(s, maxf(0, 0.5 - Player.skill_level(s, "kopfnuss") * 0.1)):
		p.hp -= 1
		Log.add(s, "Aua. Dein Schädel brummt. (−1 HP)", "kampf")
		if p.hp <= 0:
			Death.handle_lethal(s, "am eigenen Kopfstoß gestorben")

	if target.hp > 0:
		_apply_zone_effect(s, target, zone, final)

	# Umwerfen
	if target.hp > 0 and (t.part == "tritt" or t.move == "anlauf" or t.move == "sprung" or zone == "beine"):
		var kd: float = 12 if t.part == "tritt" else 6
		if zone == "beine":
			kd += 15
		if zone == "kopf":
			kd -= 4
		if t.move == "sprung":
			kd += 13
		if t.move == "anlauf":
			kd += 12
		if ram:
			kd += 15
		for row in skills:
			kd += J.num(row.def, "knockdown") * row.st.level
		if target.size == "gross":
			kd /= 2.0
		if target.size == "riesig" or Abilities.has(target, "fliegend"):
			kd = 0
		if R.next(s) * 100 < kd:
			target.downed = 2
			s.counters.knockdowns += 1
			Log.add(s, "%s geht zu Boden!" % Identify.name_of_cap(s, target), "kampf")

	# Stiefel des ungebremsten Stampfens: Beben trifft Nachbarn
	var feet = p.equipment.get("fuesse")
	if t.move == "stampfen" and feet != null and feet.get("special") == "stampf_beben":
		for m in s.monsters.duplicate():
			if is_same(m, target) or J.cheb(m.pos, target.pos) > 1:
				continue
			var quake := maxi(1, J.rnd(final / 2.0) - m.ruestung)
			m.hp -= quake
			m.aware = true
			Log.add(s, "Das Beben erwischt %s für %d Schaden." % [Identify.name_of(s, m), quake], "kampf")
			if m.hp <= 0:
				kill_monster(s, m, t)

	if thrown != null:
		if thrown.get("special") == "bumerang":
			_return_thrown(s, thrown)
			Log.add(s, "%s fliegt zu dir zurück." % thrown.name, "kampf")
		elif thrown.get("explosion") or thrown.get("wurfZustand"):
			pass
		elif thrown.baseId == "flasche" or thrown.baseId == "kaffeetasse":
			Log.add(s, "%s zerschellt." % thrown.name, "kampf")
		else:
			drop_near(s, thrown, target.pos)

	if Abilities.has_special(s, "vampir") and t.part != "wurf":
		var heal := maxi(1, J.rnd(final * 0.15))
		p.hp = mini(Player.max_hp(s), p.hp + heal)

	Events.emit(s, Items.compact({"type": "attack", "technique": t, "hit": true, "crit": crit, "damage": final, "target": target, "thrown": thrown, "facets": facets}))
	if ram:
		Log.add(s, "%s rammt mit voller Wucht!" % p.mount.name, "kampf")
		Events.emit(s, {"type": "rammed", "kill": target.hp <= 0})
	if target.hp > 0:
		_apply_hit_conditions(s, target, t, final, crit)
	var at := J.pcopy(target.pos)
	if target.hp <= 0:
		kill_monster(s, target, t, false, facets)
	if thrown != null and thrown.get("explosion"):
		_detonate(s, thrown, at)
	elif thrown != null and thrown.get("wurfZustand"):
		_burst(s, thrown, at)
	return {"ok": true}


static func bleed_chance(w: Variant) -> float:
	if w == null:
		return 0.0
	return J.num(w, "blutung") + J.num(w, "upgrades") * 20


static func _apply_hit_conditions(s: Dictionary, m: Dictionary, t: Dictionary, dmg: int, crit: bool) -> void:
	var bleed_power := 1 + floori(dmg / 6.0)
	var rage := J.some(s.player.buffs, func(b): return b.name == "Blutrausch")
	if t.part == "waffe":
		var chance := bleed_chance(Player.current_weapon(s)) + (15 if crit else 0) + (20 if Abilities.has_special(s, "klingenmeister") else 0)
		if rage or (chance > 0 and R.chance(s, chance / 100.0)):
			Conditions.inflict(s, m, "blutung", 4, bleed_power)
	elif t.part != "wurf":
		if rage or (t.part == "faust" and Abilities.has_special(s, "krallen") and R.chance(s, 0.2)):
			Conditions.inflict(s, m, "blutung", 4, bleed_power)
	if t.part != "wurf" and Abilities.has_special(s, "giftklinge") and m.hp > 0 and R.chance(s, 0.25):
		Conditions.inflict(s, m, "gift", 5, 1 + floori(s.player.level / 4.0))


static func _burst(s: Dictionary, thrown: Dictionary, at: Dictionary) -> void:
	var c: Dictionary = thrown.wurfZustand
	var r: int = J.nn(c, "radius", 0)
	Log.add(s, "Der Beutel platzt in einer dichten grauen Wolke." if thrown.baseId == "staubbeutel" else "%s platzt auf." % thrown.name, "kampf")
	var power: int = c.power + floori(s.player.level / 4.0)
	for m in s.monsters.duplicate():
		if J.cheb(m.pos, at) <= r:
			Conditions.inflict(s, m, c.id, c.turns, power)
	if J.cheb(s.player.pos, at) <= r:
		Conditions.inflict_player(s, c.id, maxi(1, c.turns - 1), c.power, "Deine eigene Wolke")


static func _detonate(s: Dictionary, thrown: Dictionary, at: Dictionary) -> void:
	var dmg := J.rnd(J.num(thrown, "explosion") * (1 + 0.1 * Player.skill_level(s, "handwerk") + 0.08 * Player.skill_level(s, "sprengmeister")) + Player.effective_stats(s).ges / 3.0)
	Skills.train_skill(s, "explode", 1)
	Log.add(s, "Die Brandflasche zerplatzt in einer Feuerwolke!" if thrown.baseId == "brandflasche" else "%s detoniert mit ohrenbetäubendem Knall!" % thrown.name, "kampf")
	Traps.blast(s, at, dmg, "bombe", "vom eigenen Sprengsatz (%s) zerlegt" % thrown.name, thrown.get("wurfZustand"))


static func _apply_zone_effect(s: Dictionary, m: Dictionary, zone: String, dmg: int) -> void:
	var big_hit: bool = dmg >= m.maxHp * 0.15
	var skill := Player.skill_level(s, "anatomie") * 0.02
	if zone != "koerper":
		Skills.train_skill(s, "zone", Skills.learn_factor(s, m.level))
	if zone == "kopf" and m.rank != "boroughboss" and R.chance(s, (0.35 if big_hit else 0.15) + skill):
		m.stunned = maxi(int(J.num(m, "stunned")), 1)
		Stats.track(s, "zonen.benommen")
		Log.add(s, "%s ist benommen und taumelt." % Identify.name_of_cap(s, m), "kampf")
	elif zone == "arme" and R.chance(s, 0.4 + skill):
		m.weakened = maxi(int(J.num(m, "weakened")), 3)
		Stats.track(s, "zonen.geschwaecht")
		Log.add(s, "%s kann den Arm kaum noch heben. Seine Angriffe werden schwächer." % Identify.name_of_cap(s, m), "kampf")
	elif zone == "beine" and R.chance(s, 0.35 + skill):
		m.slowed = maxi(int(J.num(m, "slowed")), 4)
		Stats.track(s, "zonen.humpelt")
		Log.add(s, "%s humpelt." % Identify.name_of_cap(s, m), "kampf")


## Konter nach einem ausgewichenen Nahkampfangriff.
static func counter_strike(s: Dictionary, m: Dictionary) -> void:
	if not J.has_same(s.monsters, m) or is_in_safe_room(s, s.player.pos):
		return
	var st := Player.effective_stats(s)
	var lvl := Player.skill_level(s, "konter")
	var dmg := maxi(1, J.rnd((3 + st.str / 2.0) * (1 + 0.1 * lvl) * (0.8 + R.next(s) * 0.4) - m.ruestung))
	m.hp -= dmg
	s.counters.damageDealt += dmg
	Fx.strike(s, s.player.pos, m.pos)
	Fx.float_text(s, m.pos, str(dmg), Fx.COLORS.schaden)
	Fx.hit(s, m.pos)
	Log.add(s, "Du weichst aus und konterst sofort: %d Schaden an %s." % [dmg, Identify.name_of(s, m, "dat")], "kampf")
	var t := {"part": "faust", "move": "normal"}
	if m.hp > 0:
		return
	var stats: Dictionary = s.stats.duplicate() if s.get("stats") != null else {}
	stats._konter = 1
	s.stats = stats
	kill_monster(s, m, t, false, Observer.attack_facets(s, m, t))
	s.stats._konter = 0


static func drop_near(s: Dictionary, item: Dictionary, pos: Dictionary) -> void:
	s.items.append({"pos": J.pcopy(pos), "item": item})


static func _return_thrown(s: Dictionary, item: Dictionary) -> void:
	var p: Dictionary = s.player
	var same = J.find(p.inventory, func(i): return i.baseId == item.baseId)
	if same != null:
		same.menge = int(J.nn(same, "menge", 0)) + 1
	elif p.hand == null and not s.unlocks.has("inventar"):
		p.hand = item
	else:
		p.inventory.append(item)


static func _explode(s: Dictionary, m: Dictionary) -> void:
	var dmg := R.int_(s, 3, 6) + floori(m.level / 2.0)
	Log.add(s, "%s explodiert mit einem feuchten KNALL!" % Identify.name_of_cap(s, m), "gefahr")
	for o in s.monsters.duplicate():
		if J.cheb(o.pos, m.pos) > 1:
			continue
		o.hp -= dmg
		Log.add(s, "Die Explosion trifft %s für %d Schaden." % [Identify.name_of(s, o), dmg], "kampf")
		if o.hp <= 0:
			kill_monster(s, o, null)
	var pet = s.player.pet
	if pet != null and pet.alive and J.cheb(pet.pos, m.pos) <= 1:
		pet.hp -= dmg
		if pet.hp <= 0:
			pet.hp = 0
			pet.alive = false
			Log.add(s, "%s wird von der Explosion umgehauen und verschwindet bewusstlos in einem Transportlicht." % pet.name, "gefahr")
	if J.cheb(s.player.pos, m.pos) <= 1 and s.status == "playing":
		var taken := ceili(dmg / 2.0) if Abilities.has_special(s, "explosionsschutz") else dmg
		s.player.hp -= taken
		s.counters.damageTaken += taken
		Log.add(s, "Die Explosion erwischt dich für %d Schaden." % taken, "gefahr")
		if s.player.hp <= 0:
			Death.handle_lethal(s, "durch die Explosion %s zerfetzt" % Identify.von(s, m))
		else:
			Events.emit(s, {"type": "explosion", "damage": taken, "source": m.name})


## by_pet: true = Haustier, Text = Name eines anderen Crawlers.
## credit: false, wenn ein fremder Crawler (nicht in der Party) getötet hat –
## dann gibt es für dich weder Erfahrung noch Zähler, Kopfgeld oder Boss-Box.
## Ein fremder Crawler hat getötet: Beute fällt, das Viertel merkt sich den
## Boss, aber dir wird nichts gutgeschrieben.
static func _uncredited_kill(s: Dictionary, m: Dictionary, killer: Variant) -> void:
	if Sight.player_sees(s, m.pos):
		Log.add(s, "%s tötet %s!" % [String(killer), Identify.name_of(s, m)], "kampf")
	for drop in Items.roll_mob_drop(s, m.level, m.rank == "elite"):
		drop_near(s, drop, m.pos)
	if m.get("loot") != null:
		for id in m.loot:
			drop_near(s, Items.create_item(s, id), m.pos)
	if m.rank == "nachbarschaftsboss":
		var hood = s.map.hoods[m.hood] if m.hood >= 0 and m.hood < s.map.hoods.size() else null
		if hood != null:
			hood.bossAlive = false
		drop_near(s, Items.create_area_map(s, m.hood), m.pos)
	if m.defId == "abtruenniger_crawler":
		Crawlers.population(s).alive -= 1


static func kill_monster(s: Dictionary, m: Dictionary, t: Variant, by_pet: Variant = false, facets: Variant = null, credit: bool = true) -> void:
	if not J.has_same(s.monsters, m):
		return
	Fx.death(s, m)
	s.monsters = J.without(s.monsters, m)
	Dungeon.on_kill(s, m)
	if not credit:
		_uncredited_kill(s, m, by_pet)
		return
	s.counters.kills += 1
	ShowEvents.on_kill(s, m)
	s.counters.killsByDef[m.defId] = int(J.num(s.counters.killsByDef, m.defId)) + 1
	if m.rank == "elite":
		s.counters.eliteKills += 1
	if t != null:
		var key := Skills.technique_key(t)
		s.player.techniqueKills[key] = int(J.num(s.player.techniqueKills, key)) + 1
	var killer: String
	if by_pet is String:
		killer = by_pet
	elif by_pet and s.player.pet != null:
		killer = s.player.pet.name
	else:
		killer = "Du"
	var witnessed := killer == "Du" or Sight.player_sees(s, m.pos)
	if witnessed:
		Log.add(s, "%s %s!" % ["Du tötest" if killer == "Du" else "%s tötet" % killer, Identify.name_of(s, m)], "kampf")
	var reward := Progression.kill_xp(s, m)
	var xp := Player.gain_xp(s, reward.xp)
	if witnessed:
		var note := ""
		if reward.diff <= -2:
			note = " (%s – der Gegner war schwächer als du)" % Progression.CHALLENGES[reward.challenge].hint
		elif reward.diff >= 2:
			note = " (%s – ein stärkerer Gegner)" % Progression.CHALLENGES[reward.challenge].hint
		if reward.rush >= 0.1:
			note += " (Endspurt +%d %%)" % J.rnd(reward.rush * 100)
		Log.add(s, "+%d XP%s" % [xp, note], "info")

	for drop in Items.roll_mob_drop(s, m.level, m.rank == "elite"):
		drop_near(s, drop, m.pos)
	if m.get("stolenGold"):
		drop_near(s, Items.create_gold(s, m.stolenGold), m.pos)
		Log.add(s, "Dein gestohlenes Gold (%s) fällt klimpernd zu Boden." % J.s(m.stolenGold), "loot")
	if m.get("loot") != null:
		for id in m.loot:
			drop_near(s, Items.create_item(s, id), m.pos)
	if m.defId == "kobold_bombe" and R.chance(s, 0.6):
		drop_near(s, Items.create_item(s, "schwarzpulver"), m.pos)

	if m.rank == "nachbarschaftsboss":
		s.counters.bossKills += 1
		var hood = s.map.hoods[m.hood] if m.hood >= 0 and m.hood < s.map.hoods.size() else null
		if hood != null:
			hood.bossAlive = false
		drop_near(s, Items.create_area_map(s, m.hood), m.pos)
		s.player.boxes.append(Items.create_box(s, "boss", "gold" if s.floor >= 2 else "silber"))
		Log.add(s, "Nachbarschafts-Boss besiegt! Im %s spawnen keine neuen Monster mehr. Eine Gebietskarte liegt am Boden. Du erhältst eine Boss-Box." % (hood.name if hood != null else "Viertel"), "system")
		Log.add(s, "Mit einem Klacken entriegelt sich die Tür der Kammer.", "system")
	if m.rank == "boroughboss":
		s.counters.bossKills += 1
		s.player.boxes.append(Items.create_box(s, "boss", "platin" if s.floor >= 2 else "gold"))
		Log.add(s, "Borough-Boss besiegt! Der Weg zur Treppe ist frei. Du erhältst eine Boss-Box.", "system")
	if m.rank == "geist" and m.get("ghostOf"):
		s.ghostsDefeated.append(m.ghostOf)
	if m.rank == "geist" and m.get("ghostItems") != null:
		for it in m.ghostItems:
			var copy: Dictionary = it.duplicate()
			copy.uid = "%sg%d" % [it.uid, s.turn]
			drop_near(s, copy, m.pos)
		Log.add(s, "Der Geist zerfällt. Zurück bleibt, was %s einst getragen hat." % m.ghostOf, "system")
	if m.defId == "abtruenniger_crawler":
		Crawlers.population(s).alive -= 1
	var fl: Array = facets if facets != null else []
	if fl.has("t:falle") or fl.has("t:bombe"):
		s.counters.trapKills += 1
	Events.emit(s, Items.compact({"type": "kill", "monster": m, "technique": t, "byPet": not not by_pet, "byAlly": by_pet is String, "facets": facets}))
	if Abilities.has(m, "explodiert"):
		_explode(s, m)
