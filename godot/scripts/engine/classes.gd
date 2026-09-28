class_name Classes
extends RefCounted
## Rassen- und Klassenwahl, Klassenfähigkeiten.

const CLASS_LIST_SIZE := 10


static func race_options(s: Dictionary) -> Array:
	return Db.t("races", "RACES").map(func(race): return {"race": race, "available": race.get("requirement") == null or DataChecks.race_requirement(race.id, s)})


static func _class_req(s: Dictionary, klass: Dictionary) -> bool:
	return klass.get("requirement") != null and DataChecks.class_requirement(klass.id, s)


## Persönliche Klassenliste: zehn passende gewöhnliche Klassen, drei empfohlen.
static func class_options(s: Dictionary) -> Array:
	var scored: Array = Db.t("classes", "CLASSES").map(func(k): return {"klass": k, "score": DataChecks.class_score(k.id, s)}).filter(func(c): return c.score > -50)
	J.sort(scored, func(a, b):
		var d: float = b.score - a.score
		return d if d != 0 else J.cmp_text(a.klass.id, b.klass.id))
	var special := scored.filter(func(c): return c.klass.rarity != "normal" and _class_req(s, c.klass))
	var normal := scored.filter(func(c): return c.klass.rarity == "normal").slice(0, CLASS_LIST_SIZE)
	var both := special + normal
	var ranked: Array = J.sort(both.duplicate(), func(a, b): return b.score - a.score)
	var recommended := ranked.slice(0, 3).map(func(c): return c.klass.id)
	return both.map(func(c): return {"klass": c.klass, "score": c.score, "recommended": recommended.has(c.klass.id)})


static func class_skills_of(race_id: Variant, class_id: Variant) -> Array:
	var out := []
	if class_id:
		var k = Db.klass(class_id)
		if k != null:
			for id in k.skills:
				if not out.has(id):
					out.append(id)
	if race_id:
		var r = Db.race(race_id)
		if r != null and r.get("talent") and not out.has(r.talent):
			out.append(r.talent)
	return out


static func choose(s: Dictionary, race_id: String, class_id: String) -> Dictionary:
	if not s.pendingSelection:
		return {"ok": false, "message": "Gerade steht keine Auswahl an."}
	var race = J.find(race_options(s), func(r): return r.race.id == race_id)
	if race == null or not race.available:
		return {"ok": false, "message": "Diese Rasse ist für dich nicht freigeschaltet."}
	var klass = J.find(class_options(s), func(c): return c.klass.id == class_id)
	if klass == null:
		return {"ok": false, "message": "Diese Klasse steht nicht auf deiner Liste."}
	var p: Dictionary = s.player
	p.race = race_id
	p.klass = class_id
	p.abilityCooldown = 0
	if race_id == "mensch":
		p.statPoints += 4
	var def: Dictionary = klass.klass
	for i in def.skills.size():
		var id: String = def.skills[i]
		var existing = J.find(p.skills, func(k): return k.id == id)
		if i == 0:
			if existing != null:
				existing.level += 2
			else:
				Skills.learn_skill(s, id, 2)
		elif existing == null:
			Skills.learn_skill(s, id, 1)
	var talent = race.race.get("talent")
	if talent and not J.some(p.skills, func(k): return k.id == talent):
		Skills.learn_skill(s, talent, 1)
	p.classSkills = class_skills_of(race_id, class_id)
	for spell in J.arr(def, "spells"):
		Magic.learn_spell(s, spell)
	if not J.arr(def, "spells").is_empty():
		p.mp = Magic.max_mp(s)
	for g in J.arr(def, "gear"):
		Inventory.add_to_inventory(s, Items.create_item(s, g[0], g[1]))
	if not J.arr(def, "gear").is_empty():
		var names := []
		for g in def.gear:
			names.append(("%dx " % g[1] if g[1] > 1 else "") + Identify.item_name(s, Items.create_item(s, g[0])))
		Log.add(s, "Startausrüstung der Klasse: %s." % ", ".join(names), "loot")
	if class_id == "tierfluesterer" and p.pet != null:
		for i in 3:
			Ai.pet_level_up(s)
	s.pendingSelection = false
	s.unlocks.append("klasse")
	for u in ["inventar", "stats", "minimap", "skills"]:
		if not s.unlocks.has(u):
			s.unlocks.append(u)
	if p.hand != null:
		Inventory.add_to_inventory(s, p.hand)
		p.hand = null
	p.hp = Player.max_hp(s)
	var rdef: Dictionary = Db.race(race_id)
	var ab: Dictionary = Db.t("classes", "ABILITIES")[def.ability]
	Log.add(s, "Du bist jetzt: %s, %s. %s" % [String(rdef.name).replace(" (bleiben, wie du bist)", ""), def.name, rdef.comment], "system")
	Log.add(s, "Klassenfähigkeit freigeschaltet: %s – %s" % [ab.name, ab.description], "system")
	Log.add(s, "Klassenskills (wachsen schneller): %s." % ", ".join(p.classSkills.map(func(id):
		var sk = Db.skill(id)
		return sk.name if sk != null else id)), "system")
	Events.emit(s, {"type": "classChosen", "race": race_id, "klass": class_id})
	return {"ok": true}


static func current_ability(s: Dictionary) -> Variant:
	var kid = s.player.get("klass")
	var k = Db.klass(kid) if kid else null
	if k == null:
		return null
	var out: Dictionary = Db.t("classes", "ABILITIES")[k.ability].duplicate()
	out.id = k.ability
	return out


static func _visible_monsters(s: Dictionary, range: int) -> Array:
	var vis := Game.visible_tiles(s)
	return s.monsters.filter(func(m): return vis.has(MapGen.idx(s.map, m.pos.x, m.pos.y)) and J.cheb(m.pos, s.player.pos) <= range and not Combat.is_in_safe_room(s, m.pos))


static func _hurt(s: Dictionary, m: Dictionary, dmg: float, verb: String) -> void:
	var final := maxi(1, J.rnd(dmg - m.ruestung))
	m.hp -= final
	m.aware = true
	s.counters.damageDealt += final
	Log.add(s, "%s trifft %s für %d Schaden." % [verb, Identify.name_of(s, m), final], "kampf")
	if m.hp <= 0:
		Combat.kill_monster(s, m, null)


static func _buff(s: Dictionary, name: String, turns: int, bonuses: Dictionary = {}, extra: Dictionary = {}) -> void:
	s.player.buffs = s.player.buffs.filter(func(b): return b.name != name)
	var b := {"name": name, "turns": turns, "bonuses": bonuses}
	b.merge(extra)
	s.player.buffs.append(b)


static func _nearest_visible(s: Dictionary, range: int) -> Variant:
	var p: Dictionary = s.player
	var list: Array = _visible_monsters(s, range).filter(func(m): return Fov.has_line_of_sight(s.map, p.pos, m.pos))
	J.sort(list, func(a, b): return J.cheb(a.pos, p.pos) - J.cheb(b.pos, p.pos))
	return list[0] if not list.is_empty() else null


## Setzt die Klassenfähigkeit ein. technique wird für den Wirbelwind genutzt.
static func use_ability(s: Dictionary, technique: Dictionary) -> Dictionary:
	if s.status != "playing":
		return {"ok": false, "message": "Das Spiel ist vorbei."}
	var ab = current_ability(s)
	if ab == null:
		return {"ok": false, "message": "Du hast noch keine Klasse."}
	var p: Dictionary = s.player
	if J.num(p, "abilityCooldown") > 0:
		return {"ok": false, "message": "%s lädt noch (%s Züge)." % [ab.name, J.s(p.abilityCooldown)]}
	if not ab.get("peaceful") and Combat.is_in_safe_room(s, p.pos):
		return {"ok": false, "message": "Im Safe Room ist Gewalt verboten."}
	var st := Player.effective_stats(s)
	match ab.id:
		"wutanfall":
			_buff(s, "Wutanfall", 8, {"schaden": {"alle": 50}, "ausweichen": -10})
			Log.add(s, "Du brüllst, bis dein Gesicht rot anläuft. WUTANFALL!", "system")
		"wirbelwind":
			var targets: Array = s.monsters.filter(func(m): return J.cheb(m.pos, p.pos) <= 1)
			if targets.is_empty():
				return {"ok": false, "message": "Niemand in Reichweite für einen Wirbelwind."}
			var t := {"part": "tritt", "move": "normal"} if technique.part == "wurf" else {"part": technique.part, "move": "normal"}
			Log.add(s, "Du drehst dich wie ein Kreisel!", "system")
			for m in targets:
				p.ausdauer += Combat.attack_cost(t)
				Combat.player_attack(s, m, t)
		"erdbeben":
			Log.add(s, "Du springst hoch und landest mit beiden Füßen. Der Boden bebt!", "system")
			for m in s.monsters.filter(func(x): return J.cheb(x.pos, p.pos) <= 2 and not Combat.is_in_safe_room(s, x.pos)):
				if m.size != "riesig" and not Abilities.has(m, "fliegend"):
					m.downed = 2
				_hurt(s, m, 4 + st.str + p.level, "Das Beben")
		"kampfschrei":
			for m in _visible_monsters(s, 7):
				Conditions.inflict(s, m, "furcht", 6, 1)
			_buff(s, "Kampfschrei", 10, {"schaden": {"alle": 20}})
			Log.add(s, "Dein Kampfschrei hallt durch die Gänge. Deine Gegner nehmen Reißaus!", "system")
		"bollwerk":
			_buff(s, "Bollwerk", 10, {"ruestung": 6})
			Log.add(s, "Du spannst jeden Muskel an. Du bist eine Mauer.", "system")
		"schattenschritt":
			for m in s.monsters:
				if m.get("homeRoom") == null:
					m.aware = false
			_buff(s, "Aus dem Schatten", 5, {"schaden": {"alle": 50}})
			Log.add(s, "Du verschmilzt mit den Schatten. Niemand weiß mehr, wo du bist.", "system")
		"steinhagel":
			var targets: Array = _visible_monsters(s, Combat.WURF_RANGE).filter(func(m): return Fov.has_line_of_sight(s.map, p.pos, m.pos)).slice(0, 4)
			if targets.is_empty():
				return {"ok": false, "message": "Kein Ziel in Wurfreichweite."}
			Log.add(s, "Aus dem Nichts erscheinen Steine in deinen Händen – und fliegen!", "system")
			for m in targets:
				_hurt(s, m, 4 + st.ges / 2.0 + p.level, "Ein magischer Stein")
		"bombe":
			var target = _nearest_visible(s, 6)
			if target == null:
				return {"ok": false, "message": "Kein Ziel für die Bombe in Sicht."}
			var center := J.pcopy(target.pos)
			Log.add(s, "Du wirfst deine selbstgebastelte Bombe. Sie tickt. Dann: BUMM!", "system")
			for m in s.monsters.filter(func(x): return J.cheb(x.pos, center) <= 1):
				_hurt(s, m, 8 + st.int + p.level * 1.5, "Die Explosion")
		"heilung":
			var amount := J.rnd(Player.max_hp(s) * 0.4)
			p.hp = mini(Player.max_hp(s), p.hp + amount)
			if p.pet != null:
				p.pet.alive = true
				p.pet.hp = p.pet.maxHp
			Log.add(s, "Du atmest tief durch. +%d HP." % amount, "system")
		"showtime":
			Log.add(s, "Du drehst dich zur Kamera, zwinkerst und machst eine absurde Pose. Das Publikum rastet aus!", "system")
			Viewers.add_spectacle(s, 40, "boss")
			Viewers.fan_gift(s)
		"blutrausch":
			_buff(s, "Blutrausch", 8, {"schaden": {"alle": 15}})
			Log.add(s, "Deine Augen werden rot. Jeder Treffer soll bluten.", "system")
		"gnadenstoss":
			_buff(s, "Gnadenstoß", 3)
			Log.add(s, "Du suchst die Schwachstelle. Wer wankt, fällt jetzt.", "system")
		"giftwolke":
			var target = _nearest_visible(s, 7)
			if target == null:
				return {"ok": false, "message": "Kein Ziel für die Giftwolke in Sicht."}
			var center := J.pcopy(target.pos)
			Log.add(s, "Du zerdrückst eine Phiole. Eine grüne Wolke quillt hervor.", "system")
			for m in s.monsters.filter(func(x): return J.cheb(x.pos, center) <= 2 and not Combat.is_in_safe_room(s, x.pos)):
				Conditions.inflict(s, m, "gift", 6, 2 + floori(p.level / 4.0))
			if J.cheb(p.pos, center) <= 2:
				Conditions.inflict_player(s, "gift", 4, 1, "Deine eigene Giftwolke")
		"brandsatz":
			var near: Array = s.monsters.filter(func(x): return J.cheb(x.pos, p.pos) <= 2 and not Combat.is_in_safe_room(s, x.pos))
			if near.is_empty():
				return {"ok": false, "message": "Niemand in der Nähe, den du anzünden könntest."}
			Log.add(s, "Ein Ring aus Flammen schießt um dich herum aus dem Boden!", "system")
			for m in near:
				Conditions.inflict(s, m, "brennen", 3, 3 + floori(p.level / 3.0))
		"blitzlicht":
			var targets := _visible_monsters(s, 4)
			if targets.is_empty():
				return {"ok": false, "message": "Niemand in Sicht, den du blenden könntest."}
			Log.add(s, "Du reißt die Kamera hoch. BLITZ! Für einen Moment ist alles weiß.", "system")
			for m in targets:
				Conditions.inflict(s, m, "blind", 3, 1)
			Viewers.add_spectacle(s, 6, "achievement")
		"meditation":
			p.ausdauer = Player.max_ausdauer(s)
			if not J.arr(p, "spells").is_empty():
				p.mp = mini(Magic.max_mp(s), int(J.num(p, "mp")) + ceili(Magic.max_mp(s) / 2.0))
			_buff(s, "Meditation", 6, {"ausweichen": 10})
			Log.add(s, "Du schließt die Augen. Einatmen. Ausatmen. Die Welt wird langsam.", "system")
		"rudelruf":
			var pet = p.pet
			if pet == null:
				return {"ok": false, "message": "Du hast kein Haustier, das du rufen könntest."}
			pet.alive = true
			pet.hp = pet.maxHp
			if J.cheb(pet.pos, p.pos) > 2:
				pet.pos = J.pcopy(p.pos)
			_buff(s, "Rudelruf", 10)
			Log.add(s, "Du pfeifst. %s ist sofort da, mit gefletschten Zähnen und doppelter Wut." % pet.name, "system")
		"zeitlupe":
			var targets := _visible_monsters(s, 8)
			if targets.is_empty():
				return {"ok": false, "message": "Niemand in Sicht."}
			for m in targets:
				m.slowed = maxi(int(J.num(m, "slowed")), 6)
			Log.add(s, "Die Zeit dehnt sich. Deine Gegner bewegen sich wie durch Sirup.", "system")
		"rauchbombe":
			Log.add(s, "PUFF! Eine dichte Rauchwolke hüllt dich ein.", "system")
			for m in s.monsters:
				if J.cheb(m.pos, p.pos) <= 1:
					Conditions.inflict(s, m, "blind", 3, 1)
				elif m.get("homeRoom") == null:
					m.aware = false
		"langfinger":
			var m = J.find(s.monsters, func(x): return J.cheb(x.pos, p.pos) <= 1 and not x.get("pickpocketed"))
			if m == null:
				return {"ok": false, "message": "Neben dir steht niemand, den du noch bestehlen könntest."}
			m.pickpocketed = true
			var gold: int = 5 + m.level * 3 + int(J.num(m, "stolenGold"))
			m.stolenGold = 0
			Inventory.add_to_inventory(s, Items.create_gold(s, gold))
			Log.add(s, "Deine Finger sind schneller als %s. Du erbeutest %d Gold." % [Identify.name_of(s, m), gold], "loot")
			if R.chance(s, 0.3):
				var loot := Items.roll_ground_item(s)
				Inventory.add_to_inventory(s, loot)
				Log.add(s, "Außerdem: %s." % Identify.item_name(s, loot), "loot")
			m.aware = true
			m.provoked = true
		"notreparatur":
			var mount = p.get("mount")
			if mount != null:
				mount.down = false
				mount.hp = mount.maxHp
				if mount.get("fuel") != null:
					mount.fuel = mini(Mounts.fuel_max(s), mount.fuel + 30)
				Log.add(s, "Klebeband, Kabelbinder, ein beherzter Tritt: %s ist wieder wie neu." % mount.name, "system")
			else:
				Log.add(s, "Du flickst deine Ausrüstung mit Klebeband und Blech.", "system")
			_buff(s, "Schrottpanzer", 10, {"ruestung": 4})
		"motivationsrede":
			for c in Crawlers.party(s):
				c.hp = mini(c.maxHp, c.hp + J.rnd(c.maxHp * 0.3))
			if p.pet != null and p.pet.alive:
				p.pet.hp = mini(p.pet.maxHp, p.pet.hp + J.rnd(p.pet.maxHp * 0.3))
			p.hp = mini(Player.max_hp(s), p.hp + J.rnd(Player.max_hp(s) * 0.1))
			_buff(s, "Motiviert", 10, {"schaden": {"alle": 15}})
			Log.add(s, "„Wir schaffen das. Und wenn nicht, dann wenigstens mit Stil!“ Alle stehen etwas gerader.", "system")
		"arkanschild":
			var absorb: int = 10 + st.int * 2 + p.level
			_buff(s, "Arkaner Schild", 30, {}, {"absorb": absorb})
			Log.add(s, "Ein schimmernder Schild legt sich um dich. Er fängt %d Schaden ab." % absorb, "system")
		"manaflut":
			p.mp = Magic.max_mp(s)
			_buff(s, "Manaflut", 10)
			Log.add(s, "Mana strömt in dich hinein, bis deine Fingerspitzen knistern.", "system")
		"totstellen":
			for m in s.monsters:
				if m.get("homeRoom") == null:
					m.aware = false
					m.erase("lastSeen")
					m.searching = 0
			var heal := J.rnd(Player.max_hp(s) * 0.15)
			p.hp = mini(Player.max_hp(s), p.hp + heal)
			Log.add(s, "Du fällst um und rührst dich nicht mehr. Sehr überzeugend. Niemand interessiert sich mehr für dich. (+%d HP)" % heal, "system")
	p.abilityCooldown = ab.cooldown
	Events.emit(s, {"type": "abilityUsed", "ability": ab.id})
	Game.end_turn(s)
	return {"ok": true}
