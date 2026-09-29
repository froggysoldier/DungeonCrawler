class_name Magic
extends RefCounted
## Zauber und Mana.

const TOME_VALUE := {"gewoehnlich": 10, "ungewoehnlich": 25, "selten": 60, "episch": 150, "legendaer": 400}


static func max_mp(s: Dictionary, b: Variant = null) -> int:
	if b == null:
		b = Player.total_bonuses(s)
	return int(maxf(1, Player.effective_stats(s, b).int + J.num(b, "maxMp")))


static func knows_spell(s: Dictionary, id: String) -> bool:
	return J.some(J.arr(s.player, "spells"), func(k): return k.id == id)


static func learn_spell(s: Dictionary, id: String, silent: bool = false) -> bool:
	var p: Dictionary = s.player
	if p.get("spells") == null:
		p.spells = []
	if knows_spell(s, id):
		return false
	p.spells.append({"id": id, "level": 1, "xp": 0})
	if not silent:
		var def: Dictionary = Db.spell(id)
		Log.add(s, "ZAUBER GELERNT: %s. %s" % [def.name, def.description], "system")
	return true


static func create_tome(s: Dictionary, spell_id: String) -> Dictionary:
	var def: Dictionary = Db.spell(spell_id)
	return Items.compact({
		"uid": Items.uid(s),
		"baseId": "buch_%s" % spell_id,
		"name": "Zauberbuch: %s" % def.name,
		"kind": "buch",
		"rarity": def.rarity,
		"spell": spell_id,
		"flavor": "%s Lesen verbraucht das Buch und lehrt dich den Zauber." % def.flavor,
		"wert": TOME_VALUE.get(def.rarity),
	})


static func random_tome(s: Dictionary, max_rarity: String) -> Dictionary:
	var order := ["gewoehnlich", "ungewoehnlich", "selten", "episch", "legendaer", "himmlisch"]
	var spells: Array = Db.t("spells", "SPELLS")
	var pool := spells.filter(func(sp): return sp.id != "heilen" and order.find(sp.rarity) <= order.find(max_rarity))
	return create_tome(s, R.pick(s, pool if not pool.is_empty() else spells).id)


static func read_tome(s: Dictionary, it: Dictionary) -> Dictionary:
	if not it.get("spell"):
		return {"ok": false, "message": "Das ist kein Zauberbuch."}
	if knows_spell(s, it.spell):
		return {"ok": false, "message": "Diesen Zauber kennst du schon."}
	learn_spell(s, it.spell)
	Log.add(s, "Du liest %s. Die Seiten zerfallen zu Staub, der Zauber bleibt in deinem Kopf." % Identify.item_name(s, it), "info")
	return {"ok": true}


static func spell_cost(id: String, chosen: Variant = null) -> int:
	var c = Db.spell(id).cost
	if not c is Array:
		return c
	return maxi(c[0], mini(c[1], chosen if chosen != null else c[0]))


static func _spell_level(s: Dictionary, id: String) -> int:
	var st = J.find(J.arr(s.player, "spells"), func(k): return k.id == id)
	return st.level if st != null else 1


static func _train_spell(s: Dictionary, id: String, amount: int) -> void:
	var st = J.find(J.arr(s.player, "spells"), func(k): return k.id == id)
	var max_level: int = Db.t("spells", "SPELL_MAX_LEVEL")
	if st == null or st.level >= max_level:
		return
	st.xp += amount
	while st.level < max_level and st.xp >= Rules.spell_xp_needed(st.level):
		st.xp -= Rules.spell_xp_needed(st.level)
		st.level += 1
		Log.add(s, "Zauber verbessert: %s ist jetzt Stufe %d." % [Db.spell(id).name, st.level], "system")


## Arkane Kunde verstärkt alle Zauberwirkungen.
static func arcane(s: Dictionary) -> float:
	return 1 + 0.04 * Player.skill_level(s, "arkane_kunde") + (0.3 if J.some(s.player.buffs, func(b): return b.name == "Manaflut") else 0.0)


static func _spell_hurt(s: Dictionary, m: Dictionary, dmg: float, label: String) -> bool:
	var facets := ["t:zauber"] + Observer.target_facets(s, m) + Observer.self_facets(s)
	dmg *= arcane(s)
	var final := maxi(1, J.rnd(dmg - m.ruestung / 2.0))
	m.hp -= final
	m.aware = true
	Fx.float_text(s, m.pos, str(final), Fx.COLORS.mana)
	Fx.hit(s, m.pos)
	s.counters.damageDealt += final
	Log.add(s, "%s trifft %s für %d Schaden." % [label, Identify.name_of(s, m), final], "kampf")
	if m.hp <= 0:
		Combat.kill_monster(s, m, null, false, facets)
		return true
	return false


static func _buff(p: Dictionary, name: String, value: Dictionary) -> void:
	p.buffs = p.buffs.filter(func(b): return b.name != name)
	p.buffs.append(value)


## opts: {targetUid, pos, mana}
static func cast_spell(s: Dictionary, id: String, opts: Dictionary = {}) -> Dictionary:
	var p: Dictionary = s.player
	var def = Db.spell(id)
	if def == null or not knows_spell(s, id):
		return {"ok": false, "message": "Diesen Zauber kennst du nicht."}
	var cd := int(J.num(p.get("spellCooldowns"), id))
	if cd > 0:
		return {"ok": false, "message": "%s lädt noch (%d Züge)." % [def.name, cd]}
	var cost := spell_cost(id, opts.get("mana"))
	if J.num(p, "mp") < cost:
		return {"ok": false, "message": "Nicht genug Mana (%s kostet %d)." % [def.name, cost]}
	var level := _spell_level(s, id)
	var st := Player.effective_stats(s)
	var kills := 0
	var range_v: int = def.get("range") if def.get("range") != null else 6

	var target = null
	if def.target == "gegner":
		target = J.find(s.monsters, func(m): return m.uid == opts.get("targetUid"))
		if target == null:
			return {"ok": false, "message": "Wähle ein Ziel: Klicke nach dem Zauber auf einen Gegner."}
		if J.cheb(p.pos, target.pos) > range_v:
			return {"ok": false, "message": "Das Ziel ist zu weit weg."}
		if not Fov.has_line_of_sight(s.map, p.pos, target.pos):
			return {"ok": false, "message": "Keine freie Sicht auf das Ziel."}
		if Combat.is_in_safe_room(s, p.pos) or Combat.is_in_safe_room(s, target.pos):
			return {"ok": false, "message": "Im Safe Room ist Gewalt verboten."}
	if def.target == "feld":
		var t = opts.get("pos")
		if t == null:
			return {"ok": false, "message": "Wähle ein Feld: Klicke nach dem Zauber auf ein freies Feld."}
		if J.cheb(p.pos, t) > range_v or not Fov.has_line_of_sight(s.map, p.pos, t):
			return {"ok": false, "message": "Dieses Feld ist außer Reichweite."}
		if not MapGen.is_walkable(s.map, t.x, t.y) or J.some(s.monsters, func(m): return m.pos.x == t.x and m.pos.y == t.y):
			return {"ok": false, "message": "Dieses Feld ist nicht frei."}

	match id:
		"heilen":
			var amount := J.rnd(Player.max_hp(s) * (0.2 + 0.03 * (level - 1)) * arcane(s))
			p.hp = mini(Player.max_hp(s), p.hp + amount)
			Fx.float_text(s, p.pos, "+%d" % amount, Fx.COLORS.heilung)
			Log.add(s, "Warmes Licht umhüllt dich. +%d HP." % amount, "info")
		"geschoss":
			var dmg: float = cost * 2.5 + st.int * 0.5 + level * (0.8 + R.next(s) * 0.4)
			Fx.shot(s, p.pos, target.pos, "magie")
			if _spell_hurt(s, target, dmg, "Dein Magisches Geschoss (%d Mana)" % cost):
				kills += 1
		"fackel":
			_buff(p, "Fackel", {"name": "Fackel", "turns": 100 + level * 10, "bonuses": {"lichtradius": 2}})
			Log.add(s, "Ein kleines Licht schwebt über deinem Kopf.", "info")
		"irrlichtruestung":
			var shield := J.rnd((6 + level * 2 + st.int) * arcane(s))
			_buff(p, "Irrlichtrüstung", {"name": "Irrlichtrüstung", "turns": 60, "bonuses": {}, "absorb": shield})
			Log.add(s, "Irrlichter tanzen um dich herum. Schild: %d." % shield, "info")
		"pfuetzensprung":
			p.pos = J.pcopy(opts.pos)
			Log.add(s, "Du versinkst in einer Pfütze und tauchst woanders wieder auf.", "info")
		"feuerball":
			var center := J.pcopy(target.pos)
			var dmg: float = 10 + st.int + level * 2
			Fx.shot(s, p.pos, center, "feuer")
			Log.add(s, "Ein Feuerball rast los und explodiert!", "kampf")
			for m in s.monsters.filter(func(x): return J.cheb(x.pos, center) <= 1):
				if _spell_hurt(s, m, dmg, "Der Feuerball"):
					kills += 1
				else:
					Conditions.inflict(s, m, "brennen", 3, 2 + floori(level / 2.0))
			if J.cheb(p.pos, center) <= 1:
				var self_dmg := J.rnd(dmg / 2.0)
				p.hp -= self_dmg
				Log.add(s, "Du stehst zu nah dran. Der Feuerball erwischt auch dich: −%d HP." % self_dmg, "gefahr")
				if p.hp <= 0:
					Death.handle_lethal(s, "vom eigenen Feuerball verbrannt")
				else:
					Conditions.inflict_player(s, "brennen", 2, 2, "Dein Feuerball")
		"schutzhuelle":
			var around: Array = s.monsters.filter(func(m): return J.cheb(m.pos, p.pos) <= 1)
			for m in around:
				var dx := J.sign(m.pos.x - p.pos.x)
				var dy := J.sign(m.pos.y - p.pos.y)
				for i in 3:
					var n := J.pos(m.pos.x + dx, m.pos.y + dy)
					if not MapGen.is_walkable(s.map, n.x, n.y) or J.some(s.monsters, func(o): return not is_same(o, m) and o.pos.x == n.x and o.pos.y == n.y):
						break
					if m.get("homeRoom") != null and s.map.roomAt[MapGen.idx(s.map, n.x, n.y)] != m.homeRoom:
						break
					m.pos = n
				if m.size != "riesig" and not Abilities.has(m, "fliegend"):
					m.downed = 2
			Log.add(s, "Eine Blase aus Kraft explodiert um dich herum. %s" % (("%d Gegner fliegen durch die Luft." % around.size()) if not around.is_empty() else "Niemand war in der Nähe. Schade drum."), "kampf")
		"schattenmantel":
			for m in s.monsters:
				if m.get("homeRoom") == null:
					m.aware = false
			_buff(p, "Schattenmantel", {"name": "Schattenmantel", "turns": 10 + level * 2, "bonuses": {"ausweichen": 5}})
			Log.add(s, "Du ziehst die Schatten um dich. Niemand weiß mehr, wo du bist.", "info")
		"entgiften":
			if not Abilities.cure(s):
				Log.add(s, "Da war gar kein Gift. Die Minze war trotzdem nett.", "info")
		"frostnadel":
			Fx.shot(s, p.pos, target.pos, "magie")
			if _spell_hurt(s, target, 5 + st.int * 0.6 + level, "Die Frostnadel"):
				kills += 1
			else:
				target.slowed = maxi(int(J.num(target, "slowed")), 4)
				Log.add(s, "%s wird langsam vor Kälte." % Identify.name_of_cap(s, target), "kampf")
		"blitzkette":
			var hit := [target]
			var cur: Dictionary = target
			for k in 2:
				var nxt = null
				for m in s.monsters:
					if not hit.has(m) and J.cheb(m.pos, cur.pos) <= 2 and not Combat.is_in_safe_room(s, m.pos):
						nxt = m
						break
				if nxt == null:
					break
				hit.append(nxt)
				cur = nxt
			var dmg: float = 8 + st.int * 0.7 + level * 1.5
			var from: Dictionary = p.pos
			for i in hit.size():
				Fx.shot(s, from, hit[i].pos, "blitz")
				from = hit[i].pos
				if _spell_hurt(s, hit[i], dmg * [1.0, 0.7, 0.5][i], "Der Kettenblitz"):
					kills += 1
		"donnerschlag":
			var around: Array = s.monsters.filter(func(m): return J.cheb(m.pos, p.pos) <= 1 and not Combat.is_in_safe_room(s, m.pos))
			Fx.hit(s, p.pos, true)
			Log.add(s, "Ein Donnerschlag rollt durch den Raum.", "kampf")
			for m in around:
				if _spell_hurt(s, m, 4 + st.int * 0.5 + level, "Der Donnerschlag"):
					kills += 1
				else:
					m.stunned = maxi(int(J.num(m, "stunned")), 1)
		"blenden":
			Fx.shot(s, p.pos, target.pos, "magie")
			if Conditions.inflict(s, target, "blind", 3 + floori(level / 3.0), 1):
				Log.add(s, "%s ist geblendet." % Identify.name_of_cap(s, target), "kampf")
			else:
				Log.add(s, "%s kneift die Augen zu. Das Licht verpufft." % Identify.name_of_cap(s, target), "kampf")
			target.aware = true
		"schreck":
			var scared := 0
			for m in s.monsters:
				if J.cheb(m.pos, p.pos) <= 3 and not BossFight.is_boss(m) and Conditions.inflict(s, m, "furcht", 3 + floori(level / 3.0), 1):
					scared += 1
			Log.add(s, "Du wächst zu einer Schreckgestalt. %s" % (("%d Gegner ergreifen die Flucht." % scared) if scared > 0 else "Niemand lässt sich beeindrucken."), "kampf")
		"regeneration":
			_buff(p, "Regeneration", {"name": "Regeneration", "turns": 40, "bonuses": {"hpRegen": 1 + floori(level / 5.0)}})
			Log.add(s, "Deine Wunden beginnen zu kribbeln und sich zu schließen.", "info")
		"steinhaut":
			_buff(p, "Steinhaut", {"name": "Steinhaut", "turns": 40, "bonuses": {"ruestung": 3 + floori(level / 4.0)}})
			Log.add(s, "Deine Haut wird grau und hart wie Beton.", "info")
		"saeurespritzer":
			Fx.shot(s, p.pos, target.pos, "schleim")
			var armor_before: int = target.ruestung
			if _spell_hurt(s, target, 4 + st.int * 0.5 + level, "Der Säurespritzer"):
				kills += 1
			else:
				target.ruestung = maxi(0, armor_before - 2)
				if armor_before > 0:
					Log.add(s, "Die Säure frisst sich in die Panzerung von %s." % Identify.name_of(s, target), "kampf")
	p.mp = J.num(p, "mp") - cost
	var cds: Dictionary = p.spellCooldowns.duplicate() if p.get("spellCooldowns") != null else {}
	cds[id] = def.cooldown
	p.spellCooldowns = cds
	_train_spell(s, id, 1 + kills)
	Events.emit(s, {"type": "spellCast", "spell": id, "kills": kills})
	return {"ok": true}


## Zeit vergeht: Mana regeneriert, Abklingzeiten laufen ab.
static func tick(s: Dictionary, turns: int) -> void:
	var p: Dictionary = s.player
	if p.get("spellCooldowns") != null:
		for k in p.spellCooldowns.keys():
			p.spellCooldowns[k] = maxi(0, p.spellCooldowns[k] - turns)
	if not J.arr(p, "spells").is_empty():
		var lvl := Player.skill_level(s, "arkane_kunde")
		var every := 4 if lvl >= 10 else (5 if lvl >= 5 else 6)
		var ticks := floori(s.turn / float(every)) - floori((s.turn - turns) / float(every))
		p.mp = mini(max_mp(s), int(J.num(p, "mp")) + ticks)
