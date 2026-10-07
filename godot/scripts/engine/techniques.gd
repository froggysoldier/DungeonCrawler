class_name Techniques
extends RefCounted
## Techniken (data/techniques.json): Wer einen Skill hochlevelt oder einen
## Wert steigert, lernt neue Kampfweisen. Drei Arten:
##   ausfuehrung: schaltet eine Ausführung frei (Stampfen, Sprung, Anlauf),
##   angriff: Sonderangriff auf ein Ziel (Mächtiger Schlag, Finte …),
##   selbst: wirkt auf dich oder alle um dich herum (Ausweichrolle …).
## Gelernte Techniken stehen in player.techniques, Abklingzeiten in
## player.techCd (Züge; im Kampf ist eine Runde ein Zug).

const STAT_NAMES := {"str": "Stärke", "ges": "Geschick", "kon": "Konstitution", "int": "Intelligenz", "cha": "Charisma"}
## Ausführungen, die man erst lernen muss (Technik-ID je Ausführung).
const MOVE_TECH := {"stampfen": "stampfen", "sprung": "sprung", "anlauf": "anlauf"}


static func all() -> Array:
	return Db.t("techniques", "TECHNIQUES")


static func def(id: String) -> Variant:
	return Db.by_id("techniques", "TECHNIQUES", id)


# ================================================================ Lernen

## „Faustkampf Stufe 2“ oder „Intelligenz 10“.
static func need_text(n: Dictionary) -> String:
	if n.has("skill"):
		var sk = Db.skill(String(n.skill))
		return "%s Stufe %d" % [sk.name if sk != null else n.skill, int(n.level)]
	return "%s %d" % [STAT_NAMES.get(n.stat, n.stat), int(n.value)]


static func needs_text(d: Dictionary) -> String:
	return " oder ".join(d.needs.map(func(n): return need_text(n)))


static func need_met(s: Dictionary, n: Dictionary) -> bool:
	if n.has("skill"):
		return Player.skill_level(s, String(n.skill)) >= int(n.level)
	return float(Player.effective_stats(s).get(n.stat, 0)) >= float(n.value)


static func meets(s: Dictionary, d: Dictionary) -> bool:
	return J.some(d.needs, func(n): return need_met(s, n))


static func known(s: Dictionary, id: String) -> bool:
	return J.arr(s.player, "techniques").has(id)


## Gelernte Techniken einer Art (oder aller Arten), in Datenreihenfolge.
static func learned(s: Dictionary, art: String = "") -> Array:
	return all().filter(func(d): return known(s, d.id) and (art == "" or d.art == art))


## Neue Techniken lernen, sobald eine Bedingung erfüllt ist. Einmal gelernt,
## bleibt eine Technik (auch wenn ein Wert später durch Ausrüstung sinkt).
static func check(s: Dictionary) -> void:
	var p: Dictionary = s.player
	if p.get("techniques") == null:
		p.techniques = []
	for d in all():
		if p.techniques.has(d.id) or not meets(s, d):
			continue
		p.techniques.append(d.id)
		Log.add(s, "NEUE TECHNIK: %s! %s" % [d.name, d.description], "system")
		Log.toast(s, "Neue Technik: %s" % d.name, d.description, "skill")
		Events.emit(s, {"type": "techniqueLearned", "id": d.id})


# ================================================================ Ausführungen

static func _mounted(s: Dictionary) -> bool:
	var p: Dictionary = s.player
	return p.get("riding") and p.get("mount") != null and not p.mount.get("down")


static func move_ok(s: Dictionary, move: String) -> bool:
	if not MOVE_TECH.has(move):
		return true
	if move == "anlauf" and _mounted(s):
		return true
	return known(s, MOVE_TECH[move])


## Warum eine Ausführung noch nicht geht (oder null).
static func move_blocker(s: Dictionary, move: String) -> Variant:
	if move_ok(s, move):
		return null
	var d = def(MOVE_TECH[move])
	return "%s hast du noch nicht gelernt (ab %s)." % [d.name, needs_text(d)]


# ================================================================ Abklingzeit

static func cooldown(s: Dictionary, id: String) -> int:
	return int(J.num(s.player.get("techCd"), id))


static func tick(s: Dictionary, turns: int) -> void:
	var cd = s.player.get("techCd")
	if cd == null:
		return
	for id in cd.keys():
		cd[id] = maxi(0, int(cd[id]) - turns)
		if cd[id] == 0:
			cd.erase(id)


## Gibt es eine Technik, die die Aktion der Runde nicht braucht und gerade
## gegen einen Gegner neben dir ginge? Dann endet die Runde nicht von selbst.
static func free_ready(s: Dictionary) -> bool:
	for d in learned(s, "angriff"):
		if not d.get("free") or cooldown(s, d.id) > 0 or int(s.player.ausdauer) < int(J.nn(d, "cost", 0)):
			continue
		if J.some(s.monsters, func(m): return J.cheb(m.pos, s.player.pos) <= 1 and Sight.player_sees(s, m.pos)):
			return true
	return false


# ================================================================ Angriffe

## Angriff einer Technik: Körperteil, Ausführung und Zone aus der Technik,
## sonst aus der gewählten Technik in der Kampfleiste (current).
static func attack_t(d: Dictionary, current: Dictionary) -> Dictionary:
	var part: String = String(current.get("part", "faust"))
	if d.get("part") != null:
		part = d.part
	elif d.get("parts") != null and not d.parts.has(part):
		part = d.parts[0]
	var zone = d.get("zone") if d.get("zone") != null else current.get("zone")
	return {"part": part, "move": String(J.nn(d, "move", "normal")), "zone": zone if zone else "koerper", "tech": d.id}


## Trefferzuschlag einer Technik (und offene Deckung des Ziels).
static func hit_bonus(target: Dictionary, t: Dictionary) -> float:
	var bonus := 25.0 if J.num(target, "exposed") > 0 else 0.0
	var d = def(String(t.tech)) if t.get("tech") else null
	if d == null:
		return bonus
	bonus += J.num(d, "hit")
	# Ohne Abzug für die Zone (Kinnhaken, Beinfeger …)
	if d.get("zoneFree"):
		bonus -= minf(0.0, float(Combat.ZONES[String(t.get("zone", "koerper"))].treffer))
	return bonus


## Schadensfaktor, Kritzuschlag, Rüstung ignorieren, Mana-Schaden.
static func mods(t: Dictionary) -> Dictionary:
	var d = def(String(t.tech)) if t.get("tech") else null
	if d == null:
		return {"dmg": 1.0, "krit": 0.0, "pierce": false, "mana": false}
	return {"dmg": float(J.nn(d, "dmg", 1.0)), "krit": J.num(d, "krit"), "pierce": bool(d.get("pierce", false)), "mana": bool(d.get("manaDamage", false))}


## „Dein Mächtiger Schlag“, „Deine Finte“.
static func your_name(t: Dictionary) -> String:
	var d = def(String(t.tech))
	return "%s %s" % ["Deine" if d.get("genus") == "f" else "Dein", d.name]


## Freies Feld neben dem Ziel, auf das man springen kann.
static func _leap_spot(s: Dictionary, target: Dictionary, reach: int) -> Variant:
	var p: Dictionary = s.player
	var best = null
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := J.pos(target.pos.x + dx, target.pos.y + dy)
			if (dx == 0 and dy == 0) or not MapGen.is_walkable(s.map, q.x, q.y) or Ai.occupied(s, q):
				continue
			if J.cheb(q, p.pos) > reach or Combat.is_in_safe_room(s, q) or not Fov.has_line_of_sight(s.map, p.pos, q):
				continue
			if best == null or J.cheb(q, p.pos) < J.cheb(best, p.pos):
				best = q
	return best


## Warum die Technik gerade nicht geht (oder null). Prüft alles außer dem
## Angriff selbst (den prüft Combat.technique_blocker).
static func blocker(s: Dictionary, d: Dictionary, target: Variant) -> Variant:
	var p: Dictionary = s.player
	if not known(s, d.id):
		return "%s hast du noch nicht gelernt (ab %s)." % [d.name, needs_text(d)]
	if d.art == "ausfuehrung":
		return "%s ist eine Ausführung – wähle sie in der Kampfleiste unter „Wie“." % d.name
	var cd := cooldown(s, d.id)
	if cd > 0:
		return "%s braucht noch %d %s." % [d.name, cd, "Zug" if cd == 1 else "Züge"]
	if int(p.ausdauer) < int(J.nn(d, "cost", 0)):
		return "Zu erschöpft für %s (%d Ausdauer nötig)." % [d.name, int(d.cost)]
	if int(J.num(d, "mp")) > 0 and int(J.num(p, "mp")) < int(d.mp):
		return "Zu wenig Mana für %s (%d nötig)." % [d.name, int(d.mp)]
	if d.art == "angriff":
		if target == null:
			return "Kein Ziel für %s." % d.name
		if d.get("need") == "downed" and target.downed <= 0 and target.size != "winzig":
			return "%s geht nur gegen Gegner, die am Boden liegen." % d.name
		if d.get("need") == "unaware" and target.aware:
			return "%s geht nur gegen Gegner, die dich nicht bemerkt haben." % d.name
		if d.get("leap") and J.cheb(p.pos, target.pos) > 1 and _leap_spot(s, target, int(d.leap)) == null:
			return "Kein Platz zum Hinspringen (höchstens %d Felder)." % int(d.leap)
		var t := attack_t(d, {"part": "faust"})
		if t.part == "wurf" and int(J.nn(d, "hits", 1)) > 1:
			var n := 0
			for it in Player.throwables(s):
				n += int(J.nn(it, "menge", 1))
			if n < int(d.hits):
				return "Für %s brauchst du %d Wurfgeschosse." % [d.name, int(d.hits)]
		return null
	# Selbst
	var violent: bool = d.get("knockAround") != null or d.get("pushAround") != null or d.get("fear") != null or d.get("exposeAround") != null
	if violent and Combat.is_in_safe_room(s, p.pos):
		return "Im Safe Room ist Gewalt verboten."
	if d.get("mounted") and not _mounted(s):
		return "%s geht nur im Sattel." % d.name
	if d.get("pet") and (p.get("pet") == null or not p.pet.get("alive", false)):
		return "Du hast kein Haustier dabei."
	if d.get("cure") != null and d.get("heal") == null and not J.some(d.cure, func(c): return Conditions.player_has(s, c)):
		return "Nichts, was %s helfen würde." % d.name
	return null


## Technik ausführen (Kosten und Abklingzeit zieht Game.use_technique ab).
static func perform(s: Dictionary, d: Dictionary, target: Variant, current: Dictionary) -> Dictionary:
	if d.art == "angriff":
		return _attack(s, d, target, current)
	return _self(s, d)


static func _attack(s: Dictionary, d: Dictionary, target: Dictionary, current: Dictionary) -> Dictionary:
	var p: Dictionary = s.player
	var t := attack_t(d, current)
	# Hechtsprung: erst heranspringen
	if d.get("leap") and J.cheb(p.pos, target.pos) > 1:
		var spot = _leap_spot(s, target, int(d.leap))
		if spot == null:
			return {"ok": false, "reason": "Kein Platz zum Hinspringen."}
		# Erst prüfen, ob der Angriff von dort ginge (Ausdauer, Ausführung …)
		var from := J.pcopy(p.pos)
		p.pos = spot
		var block0 = Combat.technique_blocker(s, target, t)
		if block0 != null:
			p.pos = from
			return {"ok": false, "reason": block0}
		p.lastMoveDir = {"x": J.sign(spot.x - from.x), "y": J.sign(spot.y - from.y)}
		Log.add(s, "Du hechtest heran!", "kampf")
	var block = Combat.technique_blocker(s, target, t)
	if block != null:
		return {"ok": false, "reason": block}
	var targets := [target]
	if d.get("area"):
		targets = s.monsters.filter(func(m): return J.cheb(m.pos, p.pos) <= 1 and Combat.technique_blocker(s, m, t) == null)
		Log.add(s, "%s!" % d.name, "kampf")
	var hits := int(J.nn(d, "hits", 1))
	var any_hit := false
	for m in targets:
		for i in hits:
			if s.status != "playing" or not J.has_same(s.monsters, m):
				break
			if i > 0 and Combat.technique_blocker(s, m, t) != null:
				break
			var r := Combat.player_attack(s, m, t)
			if not r.get("hit", false):
				continue
			any_hit = true
			if J.has_same(s.monsters, m) and m.hp > 0:
				_on_hit(s, d, m, int(r.get("damage", 0)))
	# Doppelfinte: gleich ein voller Angriff hinterher
	if d.get("follow") and s.status == "playing" and J.has_same(s.monsters, target):
		var normal := {"part": String(current.get("part", "faust")), "move": "normal", "zone": current.get("zone", "koerper")}
		if Combat.technique_blocker(s, target, normal) == null:
			Combat.player_attack(s, target, normal)
	if d.get("selfDamage") and s.status == "playing":
		p.hp -= int(d.selfDamage)
		Log.add(s, "Dein Schädel brummt. (−%d HP)" % int(d.selfDamage), "kampf")
		if p.hp <= 0:
			Death.handle_lethal(s, "am eigenen %s gestorben" % d.name)
	return {"ok": true, "hit": any_hit}


static func _boss(m: Dictionary) -> bool:
	return m.rank == "nachbarschaftsboss" or m.rank == "boroughboss"


static func _on_hit(s: Dictionary, d: Dictionary, m: Dictionary, dmg: int) -> void:
	var on = d.get("onHit")
	if on == null:
		return
	var who := Identify.name_of_cap(s, m)
	if on.has("stunned") and m.rank != "boroughboss":
		m.stunned = maxi(int(J.num(m, "stunned")), int(on.stunned))
		Log.add(s, "%s ist benommen und setzt aus." % who, "kampf")
	if on.has("downed") and m.size != "riesig" and not Abilities.has(m, "fliegend") and m.downed <= 0:
		m.downed = int(on.downed)
		s.counters.knockdowns += 1
		Log.add(s, "%s geht zu Boden!" % who, "kampf")
	if on.has("exposed"):
		m.exposed = maxi(int(J.num(m, "exposed")), int(on.exposed))
		Log.add(s, "%s ist offen – deine Angriffe treffen leichter." % who, "kampf")
	if on.has("weakened"):
		m.weakened = maxi(int(J.num(m, "weakened")), int(on.weakened))
	if on.has("slowed"):
		m.slowed = maxi(int(J.num(m, "slowed")), int(on.slowed))
		Log.add(s, "%s humpelt." % who, "kampf")
	if on.has("push"):
		push(s, m, s.player.pos, int(on.push))
	if on.has("quake"):
		for o in s.monsters.duplicate():
			if is_same(o, m) or J.cheb(o.pos, m.pos) > 1 or Combat.is_in_safe_room(s, o.pos):
				continue
			var q := maxi(1, J.rnd(dmg * float(on.quake)) - int(o.ruestung))
			o.hp -= q
			o.aware = true
			Fx.float_text(s, o.pos, str(q), Fx.COLORS.schaden)
			Fx.hit(s, o.pos)
			Log.add(s, "Die Schockwelle trifft %s für %d Schaden." % [Identify.name_of(s, o), q], "kampf")
			if o.hp <= 0:
				Combat.kill_monster(s, o, null)


## Gegner von from weg zurückstoßen. Bosse und Riesen rühren sich nicht;
## wer gegen eine Wand prallt, nimmt Schaden.
static func push(s: Dictionary, m: Dictionary, from: Dictionary, n: int) -> void:
	if not J.has_same(s.monsters, m) or m.hp <= 0:
		return
	var who := Identify.name_of_cap(s, m)
	if _boss(m) or m.size == "riesig":
		Log.add(s, "%s rührt sich keinen Zentimeter." % who, "kampf")
		return
	var dx := J.sign(m.pos.x - from.x)
	var dy := J.sign(m.pos.y - from.y)
	if dx == 0 and dy == 0:
		return
	var moved := 0
	for i in n:
		var q := J.pos(m.pos.x + dx, m.pos.y + dy)
		var room = MapGen.room_of(s.map, q)
		if not MapGen.is_walkable(s.map, q.x, q.y) or Ai.occupied(s, q, m) or (room != null and room.kind == "safe"):
			var bump := 2 + floori(Player.effective_stats(s).str / 3.0)
			m.hp -= bump
			Fx.float_text(s, m.pos, str(bump), Fx.COLORS.schaden)
			Log.add(s, "%s prallt gegen ein Hindernis: %d Schaden." % [who, bump], "kampf")
			if m.hp <= 0:
				Combat.kill_monster(s, m, null)
			return
		m.pos = q
		moved += 1
		Traps.on_monster_step(s, m)
		if not J.has_same(s.monsters, m):
			return
	if moved > 0:
		Log.add(s, "%s wird zurückgestoßen." % who, "kampf")


# ================================================================ Selbst

static func _self(s: Dictionary, d: Dictionary) -> Dictionary:
	var p: Dictionary = s.player
	var st := Player.effective_stats(s)
	Log.add(s, "%s!" % d.name, "kampf")
	if d.get("unbind") and J.num(p, "immobile") > 0:
		p.immobile = 0
		Log.add(s, "Du reißt dich los.", "kampf")
	if d.get("cure") != null:
		for c in d.cure:
			if Conditions.clear_player(s, String(c)):
				Log.add(s, "%s ist vorbei." % Conditions.CONDITIONS[c].name, "info")
	if d.get("heal") != null:
		var h: Dictionary = d.heal
		var amount := J.num(h, "base") + J.num(h, "pct") * Player.max_hp(s)
		if h.get("skill") != null:
			amount += J.num(h, "perSkill") * Player.skill_level(s, String(h.skill))
		amount += J.num(h, "int") * float(st.int)
		var before: int = p.hp
		p.hp = mini(Player.max_hp(s), p.hp + maxi(1, J.rnd(amount)))
		Fx.float_text(s, p.pos, "+%d" % (p.hp - before), Fx.COLORS.heilung)
		Log.add(s, "Du heilst %d Lebenspunkte." % (p.hp - before), "info")
	if d.get("stamina") != null:
		var before: int = p.ausdauer
		p.ausdauer = mini(Player.max_ausdauer(s), p.ausdauer + J.rnd(float(d.stamina) * Player.max_ausdauer(s)))
		Log.add(s, "Du bekommst %d Ausdauer zurück." % (p.ausdauer - before), "info")
	if d.get("buff") != null:
		var b: Dictionary = d.buff
		p.buffs = p.buffs.filter(func(x): return x.name != b.name)
		p.buffs.append({"name": b.name, "turns": int(b.turns), "bonuses": b.bonuses.duplicate(true)})
	if d.get("extraMove") and Rounds.active(s):
		s.round.move = int(s.round.move) + int(d.extraMove)
	if d.get("vanish"):
		var lost := 0
		for m in s.monsters:
			if m.get("homeRoom") == null and m.aware and J.cheb(m.pos, p.pos) >= int(d.vanish):
				m.aware = false
				lost += 1
		Log.add(s, "Du drückst dich in die Schatten. %s" % ("%d Gegner verlieren dich aus den Augen." % lost if lost > 0 else "Niemand weit genug weg, der dich aus den Augen verlieren könnte."), "kampf")
	for m in s.monsters.duplicate():
		if not J.has_same(s.monsters, m):
			continue
		var dist := J.cheb(m.pos, p.pos)
		if d.get("knockAround") and dist <= 1 and m.size != "riesig" and not Abilities.has(m, "fliegend") and not Combat.is_in_safe_room(s, m.pos):
			m.downed = maxi(m.downed, int(d.knockAround))
			m.aware = true
			Log.add(s, "%s geht zu Boden!" % Identify.name_of_cap(s, m), "kampf")
		if d.get("pushAround") and dist <= 1:
			push(s, m, p.pos, int(d.pushAround))
		if d.get("fear") and dist <= int(d.fear) and m.level <= p.level and Sight.player_sees(s, m.pos):
			Conditions.inflict(s, m, "furcht", 4, 1)
		if d.get("exposeAround") and dist <= int(d.exposeAround) and Sight.player_sees(s, m.pos):
			m.exposed = maxi(int(J.num(m, "exposed")), 2)
			m.aware = true
	if d.get("exposeAround"):
		Log.add(s, "Deine Sprüche sitzen: Die Gegner werden unvorsichtig.", "kampf")
	if d.get("hype"):
		Viewers.add_spectacle(s, float(d.hype), "show")
	return {"ok": true}
