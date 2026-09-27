class_name Observer
extends RefCounted
## Der Beobachter: zählt Merkmals-Kombinationen und leitet daraus dynamische
## Achievements und Skills ab (Port von src/engine/observer.ts).

const ABILITY_FACET := {
	"gift": "giftig", "explodiert": "explosiv", "diebisch": "diebisch", "rufer": "rufer",
	"regeneriert": "regeneriert", "schnell": "schnell", "fliegend": "fliegend", "gepanzert": "gepanzert",
	"blutig": "blutig", "brennend": "brennend", "blendend": "blendend", "furchterregend": "furchterregend",
}
const PART_WEIGHT := {"zauber": 0.5, "falle": 1.5, "bombe": 1, "blutung": 1, "feuer": 1.5, "gift": 1, "faust": 0, "tritt": 0, "knie": 0.5, "ellbogen": 0.5, "kopf": 1, "waffe": 0, "wurf": 0.5}
const MOVE_WEIGHT := {"normal": 0, "sprung": 1, "stampfen": 1, "anlauf": 1}
const DYN_MAX := 10


static func _chronicle(s: Dictionary) -> Dictionary:
	if s.get("chronicle") == null:
		s.chronicle = {"counts": {}, "stages": {}, "lastAward": -99}
	return s.chronicle


static func _monster_tags(def_id: String) -> Array:
	var m = Db.monster(def_id)
	return J.arr(m, "tags") if m != null else []


## Merkmale des Ziels, VOR dem Angriff erfasst.
static func target_facets(s: Dictionary, m: Dictionary) -> Array:
	var out := []
	var add := func(f: String) -> void:
		if not out.has(f):
			out.append(f)
	var facets: Dictionary = Db.t("facets", "TARGET_FACETS")
	for tag in _monster_tags(m.defId):
		if facets.has(tag):
			add.call("z:%s" % tag)
	if m.size == "winzig" or m.size == "gross" or m.size == "riesig":
		add.call("z:%s" % m.size)
	for a in J.arr(m, "abilities"):
		add.call("z:%s" % ABILITY_FACET[a])
	if m.behavior == "ranged" or m.get("range"):
		add.call("z:fernkampf")
	if m.behavior == "coward":
		add.call("z:feigling")
	if m.behavior == "stationary":
		add.call("z:lauerer")
	if m.rank == "elite":
		add.call("z:elite")
	if m.rank == "nachbarschaftsboss" or m.rank == "boroughboss":
		add.call("z:boss")
	if m.rank == "geist":
		add.call("z:geistcrawler")
	if m.downed > 0:
		add.call("z:liegend")
	if not m.aware:
		add.call("z:ahnungslos")
	if m.get("asleep"):
		add.call("z:schlafend")
	if m.get("fleeing"):
		add.call("z:fliehend")
	var c = m.get("conditions")
	if c != null:
		if J.num(c.get("blutung"), "turns") > 0:
			add.call("z:blutend")
		if J.num(c.get("brennen"), "turns") > 0:
			add.call("z:brennend_ziel")
		if J.num(c.get("gift"), "turns") > 0:
			add.call("z:vergiftet_ziel")
		if J.num(c.get("furcht"), "turns") > 0:
			add.call("z:veraengstigt")
		if J.num(c.get("blind"), "turns") > 0:
			add.call("z:geblendet")
	var diff: int = m.level - s.player.level
	if diff >= 3:
		add.call("z:staerker")
	if diff <= -3:
		add.call("z:schwaecher")
	return out


## Eigener Zustand im Moment der Aktion.
static func self_facets(s: Dictionary) -> Array:
	var p: Dictionary = s.player
	var out := []
	var mh := Player.max_hp(s)
	var has_buff := func(name: String) -> bool: return J.some(p.buffs, func(b): return b.name == name)
	if p.hp < mh * 0.2:
		out.append("i:fasttot")
	elif p.hp < mh * 0.5:
		out.append("i:verletzt")
	if has_buff.call("Vergiftet"):
		out.append("i:vergiftet")
	if has_buff.call("Blutung"):
		out.append("i:blutend")
	if has_buff.call("Brennen"):
		out.append("i:brennend")
	if has_buff.call("Furcht"):
		out.append("i:veraengstigt")
	if has_buff.call("Geblendet"):
		out.append("i:geblendet")
	if has_buff.call("Mut angetrunken"):
		out.append("i:angetrunken")
	if has_buff.call("Wutanfall") or has_buff.call("Rasende Wut"):
		out.append("i:wuetend")
	if p.ausdauer <= 2:
		out.append("i:erschoepft")
	var eq: Dictionary = p.equipment
	if eq.get("fuesse") == null:
		out.append("i:barfuss")
	if eq.get("brust") == null and eq.get("beine") == null:
		out.append("i:nackt")
	if eq.get("brust") != null and eq.brust.baseId == "bademantel":
		out.append("i:bademantel")
	if s.monsters.filter(func(m): return J.cheb(m.pos, p.pos) <= 1).size() >= 3:
		out.append("i:umzingelt")
	if p.pet != null and p.pet.alive and J.cheb(p.pet.pos, p.pos) <= 2:
		out.append("i:haustier")
	if s.collapseAt - s.turn <= 20:
		out.append("i:letztestunde")
	if Player.current_weapon(s) == null:
		out.append("i:unbewaffnet")
	if MapGen.room_of(s.map, p.pos) == null:
		out.append("i:im_gang")
	return out


## Alle Facetten eines Angriffs: Technik, Ausführung, Ziel, Zustand, Ort.
static func attack_facets(s: Dictionary, target: Dictionary, t: Dictionary) -> Array:
	var out := ["t:%s" % t.part]
	if t.move != "normal":
		out.append("m:%s" % t.move)
	out.append_array(target_facets(s, target))
	out.append_array(self_facets(s))
	var room = MapGen.room_of(s.map, s.player.pos)
	if room != null and room.kind != "boss" and room.kind != "arena":
		out.append("o:%s" % room.name)
	return out


static func _facet_def(f: String) -> Variant:
	var i := f.find(":")
	var kind := f.substr(0, i)
	var id := f.substr(i + 1)
	if kind == "z":
		return Db.t("facets", "TARGET_FACETS").get(id)
	if kind == "i":
		return Db.t("facets", "SELF_FACETS").get(id)
	return null


static func _facet_weight(f: String) -> float:
	var i := f.find(":")
	var kind := f.substr(0, i)
	var id := f.substr(i + 1)
	if kind == "t":
		return PART_WEIGHT.get(id, 0)
	if kind == "m":
		return MOVE_WEIGHT.get(id, 0)
	if kind == "o":
		return 0.5
	var d = _facet_def(f)
	return J.num(d, "weight") if d != null else 0.0


static func _tech_label(fs: Array) -> Variant:
	for f in fs:
		if String(f).begins_with("m:"):
			return Db.t("facets", "MOVE_PLURAL")[String(f).substr(2)]
	for f in fs:
		if String(f).begins_with("t:"):
			return Db.t("facets", "PART_PLURAL")[String(f).substr(2)]
	return null


static func _first(fs: Array, prefix: String) -> Variant:
	for f in fs:
		if String(f).begins_with(prefix):
			return f
	return null


static func _describe_combo(fs: Array) -> Dictionary:
	var tech = _tech_label(fs)
	var z = _first(fs, "z:")
	var i = _first(fs, "i:")
	var o = _first(fs, "o:")
	var z_def = _facet_def(z) if z != null else null
	var i_def = _facet_def(i) if i != null else null
	var z_name = (z_def.short if z_def.get("short") != null else J.cap(z_def.label)) if z_def != null else null
	var i_name = (i_def.short if i_def.get("short") != null else J.cap(i_def.label)) if i_def != null else null
	var name: String
	if o != null:
		name = "Revier: %s" % String(o).substr(2)
	elif tech != null and z_name != null and i_name != null:
		name = "%s: %s gegen %s" % [i_name, tech, z_name]
	elif tech != null and z_name != null:
		name = "%s gegen %s" % [tech, z_name]
	elif tech != null and i_name != null:
		name = "%s: %s" % [i_name, tech]
	elif z_name != null and i_name != null:
		name = "%s: Siege gegen %s" % [i_name, z_name]
	elif z_name != null:
		name = "Jagd auf %s" % z_name
	else:
		name = tech if tech != null else "Unbekanntes Muster"
	return {
		"name": name, "tech": tech,
		"zLabel": z_def.label if z_def != null else null,
		"iLabel": i_def.label if i_def != null else null,
		"place": String(o).substr(2) if o != null else null,
		"iDef": i_def,
	}


static func _bump(c: Dictionary, key: String) -> int:
	c.counts[key] = int(J.num(c.counts, key)) + 1
	return c.counts[key]


## Welche Kombinationen einer Aktion gezählt werden.
static func _combos(fs: Array) -> Array:
	var tech := fs.filter(func(f): return String(f).begins_with("t:") or String(f).begins_with("m:"))
	var z := fs.filter(func(f): return String(f).begins_with("z:"))
	var i := fs.filter(func(f): return String(f).begins_with("i:") and f != "i:unbewaffnet")
	var o := fs.filter(func(f): return String(f).begins_with("o:"))
	var out := []
	for zz in z:
		out.append([zz])
	for oo in o:
		out.append([oo])
	for t in tech:
		for zz in z:
			out.append([t, zz])
		for ii in i:
			out.append([t, ii])
	for zz in z:
		for ii in i:
			out.append([zz, ii])
	var main = _first(tech, "m:")
	if main == null and not tech.is_empty():
		main = tech[0]
	if main != null:
		for zz in z:
			for ii in i:
				out.append([main, zz, ii])
	return out


static func _sorted_key(fs: Array) -> String:
	return "+".join(J.sort_text(fs.duplicate()))


static func observe(s: Dictionary, e: Dictionary) -> void:
	if s.status != "playing":
		return
	var c := _chronicle(s)
	match e.type:
		"kill":
			if e.get("facets") == null or e.get("byPet"):
				return
			for f in e.facets:
				_bump(c, "total|kill|%s" % f)
			var keys := _combos(e.facets).map(func(fs): return {"fs": fs, "key": "kill|%s" % _sorted_key(fs)})
			for k in keys:
				_bump(c, k.key)
			_award_patterns(s, keys)
			_train_dyn_skills(s, e.facets, 2 * Skills.learn_factor(s, e.monster.level))
		"attack":
			if e.get("facets") == null or not e.hit:
				return
			var tech: Array = e.facets.filter(func(f): return String(f).begins_with("t:") or String(f).begins_with("m:"))
			for t in tech:
				_bump(c, "total|hit|%s" % t)
			var ctx: Array = e.facets.filter(func(f):
				if not (String(f).begins_with("z:") or String(f).begins_with("i:")):
					return false
				var d = _facet_def(f)
				return d != null and d.get("skill"))
			for t in tech:
				for f in ctx:
					_maybe_unlock_skill(s, "angriff", t, f, _bump(c, "hit|%s+%s" % [t, f]))
			_train_dyn_skills(s, e.facets, Skills.learn_factor(s, e.target.level))
		"dodged":
			for f in J.arr(e, "facets"):
				var d = _facet_def(f)
				if d != null and d.get("skill"):
					_maybe_unlock_skill(s, "ausweichen", null, f, _bump(c, "dodge|%s" % f))
		"damageTaken":
			for f in J.arr(e, "facets"):
				var d = _facet_def(f)
				if d != null and d.get("skill"):
					_maybe_unlock_skill(s, "abhaertung", null, f, _bump(c, "hurt|%s" % f))


static func _award_patterns(s: Dictionary, keys: Array) -> void:
	var c := _chronicle(s)
	var stages: Array = Db.t("facets", "STAGES")
	var best = null
	for k in keys:
		var next := int(J.num(c.stages, k.key))
		var stage := -1
		for i in stages.size():
			if c.counts[k.key] >= stages[i]:
				stage = i
		if stage < next:
			continue
		var base := 0.0
		for f in k.fs:
			base += _facet_weight(f)
		base += (k.fs.size() - 1) * 0.5
		var score := base + stage * 1.3
		if score < 3:
			continue
		if best == null or score > best.score:
			best = {"fs": k.fs, "key": k.key, "stage": stage, "score": score}
	if best == null:
		return
	if s.turn - c.lastAward < 10 and best.score < 5.5:
		return
	c.stages[best.key] = best.stage + 1
	for k in keys:
		if k.key == best.key:
			continue
		var covered: bool = J.every(k.fs, func(f): return best.fs.has(f)) or J.every(best.fs, func(f): return k.fs.has(f))
		if covered:
			c.stages[k.key] = maxi(int(J.num(c.stages, k.key)), best.stage + 1)
	c.lastAward = s.turn
	_grant_pattern(s, best.fs, best.stage, best.score, c.counts[best.key])


static func _grant_pattern(s: Dictionary, fs: Array, stage: int, score: float, count: int) -> void:
	var d := _describe_combo(fs)
	var id := "muster:%s:%d" % [_sorted_key(fs), stage]
	var name := "%s %s" % [d.name, Db.t("facets", "STAGE_NUMERALS")[stage]]
	var details := ["Getötet: %d × %s" % [count, d.zLabel if d.zLabel != null else "Gegner"]]
	if d.tech != null:
		details.append("Technik: %s" % d.tech)
	if d.iLabel != null:
		details.append("Zustand: %s" % d.iLabel)
	if d.place != null:
		details.append("Ort: %s" % d.place)
	var description := " · ".join(details)
	var comment: String = J.replace1(J.replace1(R.pick(s, Db.t("facets", "PATTERN_COMMENTS")), "{zahl}", str(count)), "{was}", d.name)
	var first: bool = not s.firstEver.has(id)
	var tiers: Array = Db.world("BOX_TIERS")
	var tier_idx := maxi(0, mini(tiers.size() - 1, floori(score / 2.2) + (1 if first else 0) - 1))
	var tier: String = tiers[tier_idx]
	var t = _first(fs, "t:")
	var box: String
	if d.iDef != null and d.iDef.get("box") != null:
		box = d.iDef.box
	elif fs.has("z:boss"):
		box = "boss"
	elif t != null:
		box = Db.t("facets", "PART_BOX")[String(t).substr(2)]
	else:
		box = "abenteurer"
	s.player.boxes.append(Items.create_box(s, box, tier))
	s.achievements.append(id)
	if s.get("dynAchievements") == null:
		s.dynAchievements = []
	s.dynAchievements.append({"id": id, "name": name, "description": description, "comment": comment, "tier": tier, "box": box, "turn": s.turn, "floor": s.floor})
	Fx.sound(s, {"kind": "achievement", "tier": tier})
	var tier_name: String = Db.world("BOX_TIER_NAMES")[tier]
	var box_name: String = Db.world("BOX_TYPE_NAMES")[box]
	Log.add(s, "DIE SYSTEMSTIMME HAT ETWAS BEMERKT: %s – %s" % [name, description], "achievement")
	Log.add(s, comment, "achievement")
	Log.add(s, "Belohnung: %s %s.%s" % [tier_name, box_name, " Zum ersten Mal in deiner Karriere – Box-Stufe erhöht!" if first else ""], "loot")
	Log.toast(s, name, description, "achievement")


# ================================================================ Dynamische Skills

static func _threshold(kind: String) -> int:
	match kind:
		"angriff":
			return Db.t("facets", "SKILL_UNLOCK_HITS")
		"ausweichen":
			return 10
	return 15


static func _skill_name(kind: String, tech: Variant, facet: String) -> Dictionary:
	var def: Dictionary = _facet_def(facet)
	var label: String = def.short if def.get("short") != null else J.cap(def.label)
	if kind == "ausweichen":
		return {"name": "Ausweichen gegen %s" % label, "description": "+1,5 %% Ausweichen pro Stufe gegen %s." % def.label}
	if kind == "abhaertung":
		return {"name": "Abgehärtet gegen %s" % label, "description": "−5 %% erlittener Schaden pro Stufe durch %s (max. 40 %%)." % def.label}
	var t: String = _tech_label([tech])
	if facet.begins_with("i:"):
		return {"name": "%s: %s" % [label, t], "description": "+6 %% Schaden und +1,5 %% Treffer pro Stufe für %s, wenn du %s bist." % [t, def.label]}
	return {"name": "%s gegen %s" % [t, label], "description": "+6 %% Schaden und +1,5 %% Treffer pro Stufe für %s gegen %s." % [t, def.label]}


static func _maybe_unlock_skill(s: Dictionary, kind: String, tech: Variant, facet: String, count: int) -> void:
	if count < _threshold(kind):
		return
	var key := "%s|%s|%s" % [kind, tech if tech != null else "", facet]
	var p: Dictionary = s.player
	if p.get("dynSkills") == null:
		p.dynSkills = []
	if J.some(p.dynSkills, func(k): return k.key == key):
		return
	var sn := _skill_name(kind, tech, facet)
	var skill := {"key": key, "name": sn.name, "description": sn.description, "kind": kind, "facet": facet, "level": 1, "xp": 0}
	if tech != null and String(tech).begins_with("t:"):
		skill.part = String(tech).substr(2)
	if tech != null and String(tech).begins_with("m:"):
		skill.move = String(tech).substr(2)
	p.dynSkills.append(skill)
	Log.add(s, "NEUER SKILL ENTDECKT: %s. %s" % [sn.name, sn.description], "system")
	Log.toast(s, "Neuer Skill: %s" % sn.name, sn.description, "skill")


static func dyn_xp_needed(level: int) -> int:
	return 12 + level * 10


static func _matches(k: Dictionary, facets: Array, part: Variant, move: Variant) -> bool:
	if not facets.has(k.facet):
		return false
	if k.get("part") and k.part != part:
		return false
	if k.get("move") and k.move != move:
		return false
	return true


static func _train_dyn_skills(s: Dictionary, facets: Array, amount: float) -> void:
	var tp = _first(facets, "t:")
	var part = String(tp).substr(2) if tp != null else null
	var mp = _first(facets, "m:")
	var move = String(mp).substr(2) if mp != null else "normal"
	for k in J.arr(s.player, "dynSkills"):
		if k.kind != "angriff" or not _matches(k, facets, part, move) or k.level >= DYN_MAX:
			continue
		k.xp += amount
		while k.level < DYN_MAX and k.xp >= dyn_xp_needed(k.level):
			k.xp -= dyn_xp_needed(k.level)
			k.level += 1
			Log.add(s, "Skill verbessert: %s ist jetzt Stufe %d." % [k.name, k.level], "system")


static func dyn_attack_bonus(s: Dictionary, facets: Array, t: Dictionary) -> Dictionary:
	var dmg := 0.0
	var hit := 0.0
	for k in J.arr(s.player, "dynSkills"):
		if k.kind != "angriff" or not _matches(k, facets, t.part, t.move):
			continue
		dmg += 6 * k.level
		hit += 1.5 * k.level
	return {"dmg": dmg, "hit": hit}


static func dyn_defense_bonus(s: Dictionary, source_facets: Array) -> Dictionary:
	var ausweichen := 0.0
	var reduktion := 0.0
	for k in J.arr(s.player, "dynSkills"):
		if not source_facets.has(k.facet):
			continue
		if k.kind == "ausweichen":
			ausweichen += 1.5 * k.level
		if k.kind == "abhaertung":
			reduktion += 5 * k.level
	return {"ausweichen": ausweichen, "reduktion": minf(40, reduktion)}


static func train_defense(s: Dictionary, source_facets: Array, kind: String) -> void:
	for k in J.arr(s.player, "dynSkills"):
		if k.kind != kind or not source_facets.has(k.facet) or k.level >= DYN_MAX:
			continue
		k.xp += 1
		if k.xp >= dyn_xp_needed(k.level):
			k.xp -= dyn_xp_needed(k.level)
			k.level += 1
			Log.add(s, "Skill verbessert: %s ist jetzt Stufe %d." % [k.name, k.level], "system")


## Fortschritt zu noch nicht entdeckten Skills.
static func skill_hints(s: Dictionary) -> Array:
	var c = s.get("chronicle")
	if c == null:
		return []
	var owned := {}
	for k in J.arr(s.player, "dynSkills"):
		owned[k.key] = true
	var out := []
	for key in c.counts:
		var n: float = c.counts[key]
		var parts := String(key).split("|")
		var kind := parts[0]
		var rest := parts[1] if parts.size() > 1 else ""
		var skill_kind := ""
		var tech = null
		var facet: String
		if kind == "hit":
			skill_kind = "angriff"
			var tf := rest.split("+")
			tech = tf[0]
			facet = tf[1] if tf.size() > 1 else ""
		elif kind == "dodge":
			skill_kind = "ausweichen"
			facet = rest
		elif kind == "hurt":
			skill_kind = "abhaertung"
			facet = rest
		else:
			continue
		var d = _facet_def(facet)
		if d == null or not d.get("skill"):
			continue
		if owned.has("%s|%s|%s" % [skill_kind, tech if tech != null else "", facet]):
			continue
		var needed := _threshold(skill_kind)
		if n < needed * 0.4:
			continue
		out.append({"name": _skill_name(skill_kind, tech, facet).name, "progress": n, "needed": needed})
	J.sort(out, func(a, b): return b.progress / b.needed - a.progress / a.needed)
	return out.slice(0, 8)
