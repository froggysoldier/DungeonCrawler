class_name Ai
extends RefCounted
## Monster, Haustier und ihre Züge.

const DIRS := Pathfinding.DIRS


static func occupied(s: Dictionary, p: Dictionary, except: Variant = null) -> bool:
	if s.player.pos.x == p.x and s.player.pos.y == p.y:
		return true
	var pet = s.player.pet
	if pet != null and pet.alive and pet.pos.x == p.x and pet.pos.y == p.y:
		return true
	if Crawlers.crawler_at(s, p) != null:
		return true
	for m in s.monsters:
		if not is_same(m, except) and m.pos.x == p.x and m.pos.y == p.y:
			return true
	return false


static func monster_at(s: Dictionary, p: Dictionary) -> Variant:
	for m in s.monsters:
		if m.pos.x == p.x and m.pos.y == p.y:
			return m
	return null


## Alle besetzten Felder als Menge (Index -> true), wie occupied() sie
## sieht. Für Wegsuchen: einmal bauen statt für jedes Feld alle Figuren
## durchzugehen.
static func occupied_set(s: Dictionary, except: Variant = null) -> Dictionary:
	var w: int = s.map.width
	var out := {int(s.player.pos.y) * w + int(s.player.pos.x): true}
	var pet = s.player.pet
	if pet != null and pet.alive:
		out[int(pet.pos.y) * w + int(pet.pos.x)] = true
	for c in Crawlers.crawlers(s):
		if c.alive:
			out[int(c.pos.y) * w + int(c.pos.x)] = true
	for m in s.monsters:
		if not is_same(m, except):
			out[int(m.pos.y) * w + int(m.pos.x)] = true
	return out


static func _allowed_tile(s: Dictionary, m: Dictionary, p: Dictionary) -> bool:
	var r: int = s.map.roomAt[MapGen.idx(s.map, p.x, p.y)]
	if m.get("homeRoom") != null:
		return r == m.homeRoom
	var kind = s.map.rooms[r].kind if r >= 0 else null
	# In die Siedlung der Kanalstadt trauen sich Monster nicht
	if r >= 0 and s.map.rooms[r].get("siedlung"):
		return false
	# Safe Rooms: das schimmernde Feld an der Tür hält jedes Monster draußen
	return kind != "boss" and kind != "arena" and kind != "safe"


## Entfernung jedes Feldes zum Crawler in Schritten (nur Wände und
## geschlossene Türen zählen, keine Figuren), höchstens FIELD_RANGE weit;
## -1 = nicht erreichbar oder zu weit. Einmal pro Zug und Standort berechnet.
const FIELD_RANGE := 40
static var _field := PackedInt32Array()
static var _field_key := ""
static var _field_map: Dictionary = {}


static func player_field(s: Dictionary) -> PackedInt32Array:
	var m: Dictionary = s.map
	var key := "%d|%d|%d,%d" % [s.floor, s.turn, s.player.pos.x, s.player.pos.y]
	if key == _field_key and is_same(m, _field_map):
		return _field
	_field_key = key
	_field_map = m
	var w: int = m.width
	var h: int = m.height
	var field := PackedInt32Array()
	field.resize(w * h)
	field.fill(-1)
	var start: int = int(s.player.pos.y) * w + int(s.player.pos.x)
	field[start] = 0
	var frontier := PackedInt32Array([start])
	var dist := 0
	while not frontier.is_empty() and dist < FIELD_RANGE:
		dist += 1
		var next := PackedInt32Array()
		for i in frontier:
			var x := i % w
			var y := i / w
			var from := J.pos(x, y)
			for d in DIRS:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var ni := ny * w + nx
				if field[ni] >= 0:
					continue
				# Rückwärts gedacht: vom Nachbarn aus muss der Schritt hierher gehen
				if not Pathfinding.can_step(m, J.pos(nx, ny), from):
					continue
				field[ni] = dist
				next.append(ni)
		frontier = next
	_field = field
	return field


static func _neighbors_of(p: Dictionary) -> Array:
	return DIRS.map(func(d): return J.pos(p.x + d[0], p.y + d[1]))


static func _step_toward(s: Dictionary, m: Dictionary, goal: Dictionary) -> void:
	# Geister schweben durch Wände und bleiben an keiner Ecke hängen
	if Abilities.has(m, "geisterhaft"):
		var drift: Array = _neighbors_of(m.pos) + [J.pos(m.pos.x + 1, m.pos.y + 1), J.pos(m.pos.x - 1, m.pos.y - 1), J.pos(m.pos.x + 1, m.pos.y - 1), J.pos(m.pos.x - 1, m.pos.y + 1)]
		drift = drift.filter(func(p): return MapGen.in_bounds(s.map, p.x, p.y) and not occupied(s, p, m) and _allowed_tile(s, m, p))
		J.sort(drift, func(a, b): return J.cheb(a, goal) - J.cheb(b, goal))
		if not drift.is_empty() and J.cheb(drift[0], goal) < J.cheb(m.pos, goal):
			m.pos = drift[0]
		return
	# Auf den Crawler zu: dem gemeinsamen Entfernungsfeld folgen (eine
	# Rechnung pro Zug statt einer Wegsuche je Gegner und Schritt)
	if goal.x == s.player.pos.x and goal.y == s.player.pos.y:
		var field := player_field(s)
		var w0: int = s.map.width
		var here: int = field[int(m.pos.y) * w0 + int(m.pos.x)]
		if here > 0:
			var best = null
			var best_d := here
			for d in DIRS:
				var q := J.pos(m.pos.x + d[0], m.pos.y + d[1])
				if not MapGen.in_bounds(s.map, q.x, q.y):
					continue
				var fd: int = field[q.y * w0 + q.x]
				if fd < 0 or fd >= best_d:
					continue
				if not Pathfinding.can_step(s.map, m.pos, q) or occupied(s, q, m) or not _allowed_tile(s, m, q):
					continue
				best = q
				best_d = fd
			if best != null:
				m.pos = best
			return
	var occ := occupied_set(s, m)
	var w: int = s.map.width
	var path = Pathfinding.find_path(s.map, m.pos, goal, func(x, y): return _allowed_tile(s, m, J.pos(x, y)) and not occ.has(y * w + x), 250)
	var next = path[0] if path != null and not path.is_empty() else null
	if next != null and not occupied(s, next, m) and _allowed_tile(s, m, next):
		m.pos = next
		return
	# Fallback: gierig in Richtung Ziel
	var opts: Array = _neighbors_of(m.pos).filter(func(p): return Pathfinding.can_step(s.map, m.pos, p) and not occupied(s, p, m) and _allowed_tile(s, m, p))
	J.sort(opts, func(a, b): return J.cheb(a, goal) - J.cheb(b, goal))
	if not opts.is_empty() and J.cheb(opts[0], goal) < J.cheb(m.pos, goal):
		m.pos = opts[0]


static func _step_away(s: Dictionary, m: Dictionary, from: Dictionary) -> void:
	var opts: Array = _neighbors_of(m.pos).filter(func(p): return Pathfinding.can_step(s.map, m.pos, p) and not occupied(s, p, m) and _allowed_tile(s, m, p))
	J.sort(opts, func(a, b): return J.cheb(b, from) - J.cheb(a, from))
	if not opts.is_empty() and J.cheb(opts[0], from) >= J.cheb(m.pos, from):
		m.pos = opts[0]


static func _wander(s: Dictionary, m: Dictionary) -> void:
	if not R.chance(s, 0.3):
		return
	var d: Array = R.pick(s, DIRS)
	var p := J.pos(m.pos.x + d[0], m.pos.y + d[1])
	if Pathfinding.can_step(s.map, m.pos, p) and not occupied(s, p, m) and _allowed_tile(s, m, p):
		m.pos = p


static func _can_see_player(s: Dictionary, m: Dictionary, range: int) -> bool:
	var d := J.cheb(m.pos, s.player.pos)
	return d <= range and Fov.has_line_of_sight(s.map, m.pos, s.player.pos)


static func _shot_style(s: Dictionary, m: Dictionary) -> String:
	var f := Observer.target_facets(s, m)
	if f.has("z:schleim"):
		return "schleim"
	if String(m.defId).contains("schleuder") or f.has("z:kobold"):
		return "stein"
	if f.has("z:elementar") or f.has("z:hexe") or f.has("z:alien") or f.has("z:geist"):
		return "magie"
	if f.has("z:konstrukt"):
		return "blitz"
	return "pfeil"


static func _attack_player(s: Dictionary, m: Dictionary, ranged: bool) -> void:
	var p: Dictionary = s.player
	if Combat.is_in_safe_room(s, p.pos):
		var dest = MapGen.random_open_tile(s, m.pos, 25, func(q): return occupied(s, q, m) or J.cheb(q, p.pos) < 8)
		if dest != null:
			m.pos = dest
			m.aware = false
			Log.add(s, "%s will dich im Safe Room angreifen – und wird mit einem lauten *PLOPP* weggebeamt." % Identify.name_of_cap(s, m), "system")
		return
	var b := Player.total_bonuses(s)
	var source := Observer.target_facets(s, m).filter(func(f): return f != "z:ahnungslos")
	if ranged and not source.has("z:fernkampf"):
		source.append("z:fernkampf")
	var defense := Observer.dyn_defense_bonus(s, source)
	var blind := 30 if Conditions.has_condition(m, "blind") else 0
	var hit := maxf(5, minf(95, m.treffer - Player.ausweichen(s, b) - defense.ausweichen - (5 if ranged else 0) + Progression.level_gap_hit(m.level, p.level) - blind))
	var verb := "schießt auf dich" if ranged else "greift an"
	if ranged:
		Fx.shot(s, m.pos, p.pos, _shot_style(s, m))
	else:
		Fx.strike(s, m.pos, p.pos)
	var covered := J.some(p.buffs, func(x): return x.name == "Deckung")
	if covered:
		Skills.train_skill(s, "block", Skills.learn_factor(s, m.level))
	if R.next(s) * 100 >= hit:
		Fx.float_text(s, p.pos, "ausgewichen", Fx.COLORS.info)
		s.counters.hitTakenStreak = 0
		Log.add(s, "%s %s – du weichst aus." % [Identify.name_of_cap(s, m), verb], "kampf")
		Observer.train_defense(s, source, "ausweichen")
		Events.emit(s, {"type": "dodged", "source": m.name, "facets": source})
		if not ranged:
			Skills.train_skill(s, "counter", Skills.learn_factor(s, m.level))
			if R.chance(s, Player.skill_level(s, "konter") * 0.03 + (0.15 if Abilities.has_special(s, "konterprofi") else 0.0)):
				Combat.counter_strike(s, m)
		return
	var raw := R.int_(s, m.dmg[0], m.dmg[1])
	if m.get("weakened") and m.weakened > 0:
		raw = maxi(1, J.rnd(raw * 0.7))
	for buff in p.buffs:
		if not buff.get("absorb") or raw <= 0:
			continue
		var taken := mini(buff.absorb, raw)
		buff.absorb -= taken
		raw -= taken
		Log.add(s, "%s fängt %d Schaden ab." % [buff.name, taken], "kampf")
		if buff.absorb <= 0:
			buff.turns = 0
	if raw <= 0:
		Events.emit(s, {"type": "dodged", "source": m.name, "facets": source})
		return
	var pain := minf(0.25, Player.skill_level(s, "schmerzresistenz") * 0.015)
	var dmg := maxi(1, J.rnd(Player.armor_damage(raw, J.num(b, "ruestung")) * (1 - defense.reduktion / 100.0) * (1 - pain)))
	if Mounts.mount_absorbs(s, dmg, Identify.name_of_cap(s, m)):
		return
	if dmg >= Player.max_hp(s, b) * 0.15:
		Skills.train_skill(s, "bighit", Skills.learn_factor(s, m.level))
	if defense.reduktion:
		Observer.train_defense(s, source, "abhaertung")
	m.hitPlayer = true
	p.hp -= dmg
	Fx.float_text(s, p.pos, "-%d" % dmg, Fx.COLORS.gegenSpieler)
	Fx.hit(s, p.pos, dmg >= Player.max_hp(s, b) * 0.15)
	s.counters.damageTaken += dmg
	s.counters.hitTakenStreak += 1
	Log.add(s, "%s %s und trifft dich für %d Schaden." % [Identify.name_of_cap(s, m), verb, dmg], "gefahr")
	if b.get("dornen") and not ranged:
		m.hp -= b.dornen
		Log.add(s, "Deine Dornen stechen %s für %s Schaden." % [Identify.name_of(s, m), J.s(b.dornen)], "kampf")
		if m.hp <= 0:
			Combat.kill_monster(s, m, null)
	if p.hp <= 0:
		Death.handle_lethal(s, "getötet %s" % Identify.von(s, m))
		return
	Events.emit(s, {"type": "damageTaken", "amount": dmg, "source": m.name, "facets": source})
	Abilities.on_monster_hit(s, m)
	_monster_condition_hit(s, m, dmg)


static func _monster_condition_hit(s: Dictionary, m: Dictionary, dmg: int) -> void:
	if s.status != "playing":
		return
	var who := Identify.name_of_cap(s, m)
	if Abilities.has(m, "blutig") and R.chance(s, 0.3):
		Conditions.inflict_player(s, "blutung", 4, 1 + floori(m.level / 4.0) + (1 if dmg >= 8 else 0), who)
	if Abilities.has(m, "brennend") and R.chance(s, 0.35):
		Conditions.inflict_player(s, "brennen", 3, 2 + floori(m.level / 4.0), who)
	if Abilities.has(m, "blendend") and R.chance(s, 0.25):
		Conditions.inflict_player(s, "blind", 3, 1, who)


static func _attack_pet(s: Dictionary, m: Dictionary) -> void:
	var pet: Dictionary = s.player.pet
	if R.chance(s, 0.3):
		Log.add(s, "%s schnappt nach %s, verfehlt aber." % [Identify.name_of_cap(s, m), pet.name], "kampf")
		return
	var dmg := maxi(1, R.int_(s, m.dmg[0], m.dmg[1]) - 1)
	pet.hp -= dmg
	Log.add(s, "%s trifft %s für %d Schaden." % [Identify.name_of_cap(s, m), pet.name, dmg], "gefahr")
	if pet.hp <= 0:
		pet.hp = 0
		pet.alive = false
		Log.add(s, "%s bricht bewusstlos zusammen und verschwindet in einem Transportlicht. Schlaf in einem Safe Room, dann kommt %s zurück." % [pet.name, pet.name], "gefahr")


static func _perception_range(s: Dictionary, m: Dictionary) -> int:
	if Conditions.has_condition(m, "blind"):
		return 1
	var r := 9 if m.behavior == "ranged" or m.get("range") else 8
	if m.size == "winzig":
		r -= 1
	if J.some(s.player.buffs, func(b): return b.name == "Schattenmantel"):
		r = floori(r / 2.0)
	r -= floori(Player.skill_level(s, "schleichen") / 4.0)
	return maxi(2, r)


static func _spot_chance(s: Dictionary, d: int) -> float:
	var sneak := Player.skill_level(s, "schleichen") * 0.04
	if d <= 1:
		return 1.0
	if d <= 2:
		return maxf(0.6, 1 - sneak)
	if d <= 5:
		return maxf(0.3, 0.95 - sneak)
	return maxf(0.1, 0.6 - sneak)


static func _wants_to_flee(s: Dictionary, m: Dictionary, d: int) -> bool:
	if Conditions.has_condition(m, "furcht"):
		return true
	if m.rank != "normal":
		return false
	# Feiglinge kämpfen, bis sie verletzt sind; dann laufen sie davon
	if m.behavior == "coward":
		return d <= 4 and m.hp < m.maxHp * 0.6
	if m.get("stolenGold"):
		return true
	var small_animal: bool = (m.size == "winzig" or m.size == "klein") and Observer.target_facets(s, m).has("z:tier")
	return small_animal and m.hp < m.maxHp * 0.25


static func _spot_player(s: Dictionary, m: Dictionary, text: String) -> void:
	m.aware = true
	m.asleep = false
	m.lastSeen = J.pcopy(s.player.pos)
	m.searching = 0
	if Sight.player_sees(s, m.pos):
		Log.add(s, text, "gefahr")
	if Abilities.has(m, "furchterregend") and not m.get("roared") and J.cheb(m.pos, s.player.pos) <= 6:
		m.roared = true
		if Sight.player_sees(s, m.pos):
			Log.add(s, "%s stößt einen markerschütternden Schrei aus." % Identify.name_of_cap(s, m), "gefahr")
		Conditions.inflict_player(s, "furcht", 4, 1, Identify.name_of_cap(s, m))
	# Artgenossen im Umkreis von 6 Feldern hören den Alarm; andere Arten nur,
	# wenn sie direkt daneben (3 Felder) im selben Raum stehen.
	var warned := 0
	var room := int(s.map.roomAt[MapGen.idx(s.map, m.pos.x, m.pos.y)])
	for o in s.monsters:
		if is_same(o, m) or o.aware or o.get("asleep") or o.get("homeRoom") != null:
			continue
		var d := J.cheb(o.pos, m.pos)
		var kin: bool = o.defId == m.defId and d <= 6
		var near: bool = d <= 3 and room >= 0 and int(s.map.roomAt[MapGen.idx(s.map, o.pos.x, o.pos.y)]) == room
		if not kin and not near:
			continue
		o.aware = true
		o.lastSeen = J.pcopy(s.player.pos)
		warned += 1
	if warned and Sight.player_sees(s, m.pos):
		Log.add(s, "%s schlägt Alarm: %s." % [Identify.name_of_cap(s, m), "ein weiteres Wesen wird aufmerksam" if warned == 1 else "%d weitere Wesen werden aufmerksam" % warned], "gefahr")


## Lärm weckt Schlafende und lockt Wache an.
static func make_noise(s: Dictionary, at: Dictionary, radius: int) -> void:
	for m in s.monsters:
		if m.get("homeRoom") != null or J.cheb(m.pos, at) > radius:
			continue
		if m.get("asleep"):
			m.asleep = false
			if Sight.player_sees(s, m.pos):
				Log.add(s, "%s schreckt aus dem Schlaf hoch." % Identify.name_of_cap(s, m), "gefahr")
			continue
		if not m.aware:
			m.lastSeen = J.pcopy(at)
			m.searching = 12


## Kampfrunde: ein wacher Gegner läuft vor seinem eigentlichen Zug bis zu
## steps Felder heran (Fernkämpfer nur, bis sie schießen können; Fliehende
## laufen weg). Den letzten Schritt oder den Angriff macht monster_turn.
static func close_in(s: Dictionary, m: Dictionary, steps: int) -> void:
	if steps <= 0 or not J.has_same(s.monsters, m) or not m.get("aware", false) or m.get("asleep"):
		return
	if m.downed > 0 or (m.get("stunned") and m.stunned > 0) or m.get("mudStuck") or m.behavior == "stationary":
		return
	var p: Dictionary = s.player
	var ranged: bool = m.behavior == "ranged" or not not m.get("range")
	var reach := int(J.nn(m, "range", 4))
	for k in steps:
		if s.status != "playing" or not J.has_same(s.monsters, m):
			return
		var d := J.cheb(m.pos, p.pos)
		var from = m.pos
		if m.get("fleeing") or Conditions.has_condition(m, "furcht"):
			_step_away(s, m, p.pos)
		elif d <= 1 or (ranged and d <= reach and Fov.has_line_of_sight(s.map, m.pos, p.pos)):
			return
		else:
			_step_toward(s, m, p.pos)
		if is_same(m.pos, from):
			return
		Traps.on_monster_step(s, m)
		Dungeon.on_monster_step(s, m)


static func monster_turn(s: Dictionary, m: Dictionary) -> void:
	var before := J.pcopy(m.pos)
	_monster_turn(s, m)
	if s.status == "playing" and J.has_same(s.monsters, m) and (m.pos.x != before.x or m.pos.y != before.y):
		Dungeon.on_monster_step(s, m)


static func _monster_turn(s: Dictionary, m: Dictionary) -> void:
	if s.status != "playing" or not J.has_same(s.monsters, m):
		return
	var died := Conditions.turn(s, m, func(x, part): Combat.kill_monster(s, x, null, false, ["t:%s" % part] + Observer.target_facets(s, x) + Observer.self_facets(s)))
	if died or not J.has_same(s.monsters, m) or s.status != "playing":
		return
	if m.downed > 0:
		m.downed -= 1
		if m.downed == 0 and Sight.player_sees(s, m.pos):
			Log.add(s, "%s rappelt sich wieder auf." % Identify.name_of_cap(s, m), "kampf")
		return
	if m.aware:
		m.asleep = false
	if m.get("mudStuck"):
		m.erase("mudStuck")
		return
	if m.get("stunned") and m.stunned > 0:
		m.stunned -= 1
		if Sight.player_sees(s, m.pos):
			Log.add(s, "%s ist noch benommen." % Identify.name_of_cap(s, m), "kampf")
		return
	if m.get("weakened"):
		m.weakened -= 1
	if m.get("asleep"):
		if J.cheb(m.pos, s.player.pos) <= 1 and R.chance(s, maxf(0.15, 0.5 - Player.skill_level(s, "schleichen") * 0.025)):
			_spot_player(s, m, "%s wacht auf und sieht dich!" % Identify.name_of_cap(s, m))
		elif J.cheb(m.pos, s.player.pos) <= 2:
			Skills.train_skill(s, "sneak", Skills.learn_factor(s, m.level))
		return
	Abilities.start_of_turn(s, m)
	if BossFight.turn(s, m):
		return
	var p: Dictionary = s.player
	if Conditions.has_condition(m, "brennen") and m.rank == "normal" and J.some(Observer.target_facets(s, m), func(f): return f == "z:tier" or f == "z:ratte" or f == "z:insekt") and R.chance(s, 0.5):
		var before = m.pos
		_wander(s, m)
		if is_same(m.pos, before):
			_step_away(s, m, p.pos)
		return
	if Conditions.has_condition(m, "blind") and J.cheb(m.pos, p.pos) > 1 and R.chance(s, 0.5):
		_wander(s, m)
		return
	var d := J.cheb(m.pos, p.pos)
	var sees := _can_see_player(s, m, _perception_range(s, m))

	if not m.aware:
		if m.get("homeRoom") != null:
			var pr = MapGen.room_of(s.map, p.pos)
			if pr != null and pr.id == m.homeRoom:
				_spot_player(s, m, "%s bemerkt dich!" % Identify.name_of_cap(s, m))
		elif sees:
			if R.chance(s, _spot_chance(s, d)):
				_spot_player(s, m, "%s hat dich entdeckt!" % Identify.name_of_cap(s, m))
			else:
				Skills.train_skill(s, "sneak", Skills.learn_factor(s, m.level))
	if not m.aware:
		if m.get("searching") and m.get("lastSeen") != null and m.behavior != "stationary" and m.get("homeRoom") == null:
			m.searching -= 1
			_step_toward(s, m, m.lastSeen)
			if J.cheb(m.pos, m.lastSeen) <= 1:
				m.searching = 0
			return
		if m.behavior != "stationary" and m.get("homeRoom") == null:
			_wander(s, m)
		return
	if Extras.pass_protects(s, m):
		m.aware = false
		_wander(s, m)
		return

	if sees:
		m.lastSeen = J.pcopy(p.pos)
	elif m.get("homeRoom") == null:
		m.aware = false
		m.searching = 15
		if m.get("lastSeen") != null and m.behavior != "stationary":
			_step_toward(s, m, m.lastSeen)
		return

	var pet = p.pet if p.pet != null and p.pet.alive else null
	var pet_adj: bool = pet != null and J.cheb(m.pos, pet.pos) <= 1

	if not m.get("fleeing") and _wants_to_flee(s, m, d):
		m.fleeing = true
		if Sight.player_sees(s, m.pos):
			Log.add(s, "%s ergreift die Flucht!" % Identify.name_of_cap(s, m), "kampf")
	if m.get("fleeing"):
		if not _wants_to_flee(s, m, d) and m.behavior != "coward":
			m.fleeing = false
		else:
			var from = m.pos
			_step_away(s, m, p.pos)
			if Abilities.has(m, "schnell"):
				_step_away(s, m, p.pos)
			# In die Ecke gedrängt: wehrt sich, statt stehen zu bleiben
			if not is_same(m.pos, from) or d > 1 or Conditions.has_condition(m, "furcht"):
				return

	if (m.rank == "elite" or m.rank == "nachbarschaftsboss" or m.rank == "boroughboss") and not m.get("enraged") and m.hp < m.maxHp * 0.3:
		m.enraged = true
		m.dmg = [J.rnd(m.dmg[0] * 1.3), J.rnd(m.dmg[1] * 1.3)]
		m.treffer += 5
		if Sight.player_sees(s, m.pos):
			Log.add(s, "%s gerät in Raserei! Die Angriffe werden härter." % Identify.name_of_cap(s, m), "gefahr")

	if Crawlers.monster_hits_crawler(s, m):
		return
	var ranged: bool = m.behavior == "ranged" or not not m.get("range")
	# Fernkämpfer weichen ab und zu einen Schritt zurück, um wieder zu schießen
	if ranged and d <= 1 and R.chance(s, 0.3):
		var before = m.pos
		_step_away(s, m, p.pos)
		if not is_same(m.pos, before):
			return
	if d <= 1:
		if pet_adj and R.chance(s, 0.25):
			_attack_pet(s, m)
		else:
			_attack_player(s, m, false)
		return
	if pet_adj and not ranged:
		_attack_pet(s, m)
		return
	if ranged and d <= int(J.nn(m, "range", 4)) and Fov.has_line_of_sight(s.map, m.pos, p.pos):
		_attack_player(s, m, true)
		return
	if m.behavior == "stationary":
		return
	if m.get("slowed") and m.slowed > 0:
		m.slowed -= 1
		if m.slowed % 2 == 1:
			return
		_step_toward(s, m, p.pos)
		return
	_step_toward(s, m, p.pos)
	if Abilities.has(m, "schnell") and J.cheb(m.pos, p.pos) > 1:
		_step_toward(s, m, p.pos)


## In der Kampfrunde läuft das Haustier wie die Gegner mehrere Felder: zu
## einem Gegner, der den Crawler bedroht, sonst hinter dem Crawler her.
static func pet_close_in(s: Dictionary, steps: int) -> void:
	var pet = s.player.pet
	if pet == null or not pet.alive:
		return
	var p: Dictionary = s.player
	for k in steps:
		if s.status != "playing":
			return
		if J.some(s.monsters, func(m): return J.cheb(m.pos, pet.pos) <= 1 and not Combat.is_in_safe_room(s, m.pos)):
			return
		var threats: Array = s.monsters.filter(func(m): return m.aware and J.cheb(m.pos, p.pos) <= 4 and J.cheb(m.pos, pet.pos) <= 8 and not Combat.is_in_safe_room(s, m.pos))
		var goal = null
		if not threats.is_empty():
			J.sort(threats, func(a, b): return J.cheb(a.pos, pet.pos) - J.cheb(b.pos, pet.pos))
			goal = threats[0].pos
		elif J.cheb(pet.pos, p.pos) > 2:
			goal = p.pos
		if goal == null:
			return
		var g: Dictionary = goal
		var occ := occupied_set(s)
		var w: int = s.map.width
		var path = Pathfinding.find_path(s.map, pet.pos, g, func(x, y): return not occ.has(y * w + x) or (x == g.x and y == g.y), 120)
		var next = path[0] if path != null and not path.is_empty() else null
		if next == null or occupied(s, next):
			return
		pet.pos = next


static func pet_turn(s: Dictionary) -> void:
	var pet = s.player.pet
	if pet == null or not pet.alive or s.status != "playing":
		return
	var p: Dictionary = s.player
	var targets: Array = s.monsters.filter(func(m): return J.cheb(m.pos, pet.pos) <= 1 and not Combat.is_in_safe_room(s, m.pos))
	J.sort(targets, func(a, b): return J.cheb(a.pos, p.pos) - J.cheb(b.pos, p.pos))
	var spell_target = Extras.pet_cast(s, pet)
	if spell_target != null:
		var dmg := maxi(1, J.rnd(2 + pet.level * 1.5 - spell_target.ruestung / 2.0))
		Fx.shot(s, pet.pos, spell_target.pos, "magie")
		spell_target.hp -= dmg
		spell_target.aware = true
		Log.add(s, "%s schießt Magische Geschosse aus den Augen: %d Schaden an %s." % [pet.name, dmg, Identify.name_of(s, spell_target, "dat")], "kampf")
		if spell_target.hp <= 0:
			Combat.kill_monster(s, spell_target, null, true)
		return
	var pet_kill := func(m: Dictionary) -> void:
		pet.xp += m.xp
		while pet.xp >= pet.level * 60:
			pet.xp -= pet.level * 60
			pet_level_up(s)
		Combat.kill_monster(s, m, null, true)
	if PetEvo.pet_ability_turn(s, pet, pet_kill):
		return
	if not targets.is_empty():
		var t: Dictionary = targets[0]
		var bites := 2 if J.arr(pet, "abilities").has("doppelbiss") else 1
		var i := 0
		while i < bites and J.has_same(s.monsters, t):
			i += 1
			if R.chance(s, 0.25):
				Log.add(s, "%s schnappt nach %s, verfehlt aber." % [pet.name, Identify.name_of(s, t)], "kampf")
				continue
			var dmg := J.rnd((R.int_(s, pet.dmg[0], pet.dmg[1]) + PetEvo.pet_bite_bonus(s)) * (1 + Player.skill_level(s, "tierkunde") * 0.06))
			if J.some(p.equipment.values(), func(it): return it != null and it.get("special") == "katzenfreund"):
				dmg = J.rnd(dmg * 1.5)
			if J.some(p.buffs, func(b): return b.name == "Rudelruf"):
				dmg *= 2
			var dealt := maxi(1, dmg - t.ruestung)
			t.hp -= dealt
			t.aware = true
			Log.add(s, "%s beißt %s für %d Schaden." % [pet.name, Identify.name_of(s, t), dealt], "kampf")
			if t.hp <= 0:
				pet_kill.call(t)
		return
	# Folgen
	if J.cheb(pet.pos, p.pos) > 2:
		var occ := occupied_set(s)
		var w: int = s.map.width
		var path = Pathfinding.find_path(s.map, pet.pos, p.pos, func(x, y): return not occ.has(y * w + x), 300)
		var next = path[0] if path != null and not path.is_empty() else null
		if next != null and not (next.x == p.pos.x and next.y == p.pos.y) and not occupied(s, next):
			pet.pos = next
		elif J.cheb(pet.pos, p.pos) > 8:
			for d in DIRS:
				var q := J.pos(p.pos.x + d[0], p.pos.y + d[1])
				if Pathfinding.can_step(s.map, p.pos, q) and not occupied(s, q):
					pet.pos = q
					break


static func pet_level_up(s: Dictionary) -> void:
	var pet = s.player.pet
	if pet == null:
		return
	pet.level += 1
	pet.maxHp += 5
	pet.hp = pet.maxHp
	pet.dmg = [pet.dmg[0] + 1, pet.dmg[1] + 1]
	Log.add(s, "%s steigt auf Stufe %d auf!" % [pet.name, pet.level], "system")
	Events.emit(s, {"type": "petLevel", "level": pet.level})
	PetEvo.check_evolve(s)
