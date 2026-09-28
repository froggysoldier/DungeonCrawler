class_name Skills
extends RefCounted
## Skills lernen und trainieren.


static func technique_key(t: Dictionary) -> String:
	return "%s+%s" % [t.part, t.move]


static func _matches(def: Dictionary, part: String, move: String) -> bool:
	if def.trigger != "technique":
		return false
	if def.get("parts") != null and not def.parts.has(part):
		return false
	if def.get("moves") != null and not def.moves.has(move):
		return false
	return true


## Wie oft wurde eine zum Skill passende Aktion schon ausgeführt?
static func skill_progress(s: Dictionary, def: Dictionary) -> float:
	var uses: Dictionary = s.player.techniqueUses
	if def.trigger == "technique":
		var sum := 0.0
		for k in uses:
			var key := String(k)
			if key.begins_with("_"):
				continue
			var pm := key.split("+")
			if _matches(def, pm[0], pm[1] if pm.size() > 1 else ""):
				sum += uses[k]
		return sum
	return J.num(uses, "_%s" % def.trigger)


## Skills, die zu einer Technik passen (für Schaden- und Trefferboni).
static func matching_skills(s: Dictionary, t: Dictionary) -> Array:
	var out := []
	for st in s.player.skills:
		var def = Db.skill(st.id)
		if def != null and _matches(def, t.part, t.move):
			out.append({"st": st, "def": def})
	return out


static func learn_skill(s: Dictionary, id: String, level: int = 1, silent: bool = false) -> void:
	var existing = J.find(s.player.skills, func(k): return k.id == id)
	if existing != null:
		existing.level = maxi(existing.level, level)
		return
	s.player.skills.append({"id": id, "level": level, "xp": 0})
	if silent:
		return
	var def: Dictionary = Db.skill(id)
	Log.add(s, "NEUER SKILL: %s! %s" % [def.name, def.unlockText], "system")
	Log.toast(s, "Neuer Skill: %s" % def.name, def.description, "skill")
	Events.emit(s, {"type": "skillLearned", "skillId": id})


## Klassenskills lernen schneller.
static func _xp_multiplier(s: Dictionary, id: String) -> float:
	return 1.5 if J.arr(s.player, "classSkills").has(id) else 1.0


static func _add_skill_xp(s: Dictionary, id: String, amount: float) -> void:
	var st = J.find(s.player.skills, func(k): return k.id == id)
	var def = Db.skill(id)
	if st == null or def == null or st.level >= def.maxLevel:
		return
	st.xp += amount * _xp_multiplier(s, id)
	while st.level < def.maxLevel and st.xp >= Rules.skill_xp_needed(st.level):
		st.xp -= Rules.skill_xp_needed(st.level)
		st.level += 1
		Log.add(s, "Skill verbessert: %s ist jetzt Stufe %d." % [def.name, st.level], "system")
		var eff = Rules.skill_effect(id, st.level)
		Log.toast(s, "%s Stufe %d" % [def.name, st.level], eff if eff != null else def.description, "skill")
		Events.emit(s, {"type": "skillUp", "skillId": id, "level": st.level})
	if st.level >= def.maxLevel:
		st.xp = 0


static func _train_trigger(s: Dictionary, filter: Callable, amount: float) -> void:
	for def in Db.t("skills", "SKILLS"):
		if not filter.call(def):
			continue
		var has := J.some(s.player.skills, func(k): return k.id == def.id)
		if has:
			_add_skill_xp(s, def.id, amount)
		elif skill_progress(s, def) >= def.unlockAt:
			learn_skill(s, def.id)


static func _bump(s: Dictionary, key: String, by: float = 1) -> void:
	s.player.techniqueUses[key] = J.num(s.player.techniqueUses, key) + by


## Zählt eine Aktion und gibt den Skills eines Auslösers XP.
static func train_skill(s: Dictionary, trigger: String, amount: float = 1) -> void:
	_bump(s, "_%s" % trigger)
	_train_trigger(s, func(d): return d.trigger == trigger, amount)


## Lernfaktor nach Gegnerstärke.
static func learn_factor(s: Dictionary, target_level: int) -> float:
	return maxf(0.1, minf(1.5, Progression.level_diff_factor(target_level - s.player.level)))


static func on_event(s: Dictionary, e: Dictionary) -> void:
	match e.type:
		"attack":
			var t: Dictionary = e.technique
			_bump(s, technique_key(t))
			var f := learn_factor(s, e.target.level)
			_train_trigger(s, func(d): return _matches(d, t.part, t.move), (2 if e.hit else 1) * f)
		"kill":
			var f := learn_factor(s, e.monster.level)
			var t = e.get("technique")
			if t != null:
				_train_trigger(s, func(d): return _matches(d, t.part, t.move), 2 * f)
			_train_trigger(s, func(d): return d.trigger == "kill", f)
			if e.get("byPet") and not e.get("byAlly"):
				train_skill(s, "pet", f)
			if J.arr(e, "facets").has("t:bombe"):
				train_skill(s, "explode", 2 * f)
		"dodged":
			train_skill(s, "dodge", 1)
		"damageTaken":
			train_skill(s, "hurt", 1)
		"sleep":
			train_skill(s, "heal", 3)
		"eat":
			train_skill(s, "eat", 3)
		"trapDetected":
			train_skill(s, "trap", 3)
			train_skill(s, "perceive", 2)
		"trapDisarmed", "trapPlaced":
			train_skill(s, "trap", 3)
		"trapTriggered":
			if not e.onPlayer:
				train_skill(s, "trap", 2)
		"crafted":
			train_skill(s, "craft", 3)
		"enterRoom":
			if e.get("first"):
				train_skill(s, "perceive", 1)
		"haggle":
			train_skill(s, "haggle", 3 if e.success else 1)
		"petGained":
			train_skill(s, "pet", 3)
		"petLevel":
			train_skill(s, "pet", 2)
		"spellCast":
			train_skill(s, "cast", 2)
		"poisoned":
			train_skill(s, "poison", 1)
		"rammed":
			train_skill(s, "ride", 2)


static func train_ambush(s: Dictionary) -> void:
	train_skill(s, "ambush", 2)


## Wirkung eines Skills auf einer Stufe als Klartext.
static func effect_text(def: Dictionary, level: int) -> String:
	var eff = Rules.skill_effect(def.id, level)
	if eff != null:
		return eff
	var parts := []
	if def.get("matchDamage"):
		parts.append("+%s %% Schaden" % J.s(def.matchDamage * level))
	if def.get("matchTreffer"):
		parts.append("+%s %% Treffer" % J.s(def.matchTreffer * level))
	if def.get("knockdown"):
		parts.append("+%s %% Umwerfen" % J.s(def.knockdown * level))
	var b: Dictionary = def.perLevel
	if b.get("krit"):
		parts.append("+%s %% Krit" % J.s(b.krit * level))
	if b.get("ausweichen"):
		parts.append("+%s %% Ausweichen" % J.s(b.ausweichen * level).replace(".", ","))
	if b.get("maxHp"):
		parts.append("+%s max. HP" % J.s(b.maxHp * level))
	if b.get("maxAusdauer"):
		parts.append("+%s max. Ausdauer" % J.s(b.maxAusdauer * level))
	if b.get("xpBonus"):
		parts.append("+%s %% XP" % J.s(b.xpBonus * level))
	var text := " · ".join(parts)
	return text if not text.is_empty() else def.description
