class_name BossFight
extends RefCounted
## Bosskämpfe: Phasen und angekündigte Spezialangriffe.
##
##   Phasen      bei 66 % und 33 % Lebenspunkten; jede Phase hat einen eigenen
##               Satz, ruft je nach Boss Verstärkung und verkürzt die Pause
##               zwischen den Spezialangriffen.
##   Angriffe    werden einen Zug vorher angekündigt: Die betroffenen Felder
##               leuchten rot (m.telegraph). Wer im nächsten Zug noch darauf
##               steht, wird getroffen – ausweichen heißt: weg da.
##
## Die Angriffe stehen in data/monsters.json unter BOSS_SPECIALS, welche ein Boss
## beherrscht unter HOOD_BOSSES[].specials, seine Sätze unter phaseLines.

const PHASE_AT := [0.66, 0.33]
## Züge zwischen zwei Spezialangriffen je Phase.
const COOLDOWN := [5, 4, 3]


static func is_boss(m: Dictionary) -> bool:
	return m.rank == "nachbarschaftsboss" or m.rank == "boroughboss"


static func special_def(id: String) -> Dictionary:
	return Db.t("monsters", "BOSS_SPECIALS")[id]


static func boss_def(id: String) -> Variant:
	return J.find(Db.t("monsters", "HOOD_BOSSES"), func(b): return b.id == id)


static func _specials(m: Dictionary) -> Array:
	var def = boss_def(m.defId)
	return J.arr(def, "specials") if def != null else []


## Zu Beginn des Bosszugs: Phase prüfen, angekündigten Angriff auslösen oder
## einen neuen ankündigen. true = der Zug ist damit verbraucht.
static func turn(s: Dictionary, m: Dictionary) -> bool:
	if not is_boss(m):
		return false
	_check_phase(s, m)
	if m.get("telegraph") != null:
		_resolve(s, m)
		return true
	m.specialCd = int(J.num(m, "specialCd")) - 1
	var list := _specials(m)
	if list.is_empty() or m.specialCd > 0 or not m.aware:
		return false
	var p: Dictionary = s.player
	var d := J.cheb(m.pos, p.pos)
	if d > 6 or not Fov.has_line_of_sight(s.map, m.pos, p.pos):
		return false
	# Nahe dran lieber normal zuschlagen, sonst Spezialangriff
	if d <= 1 and not R.chance(s, 0.45):
		return false
	var options: Array = list.filter(func(id): return _fits(special_def(id), d))
	if options.is_empty():
		return false
	_announce(s, m, R.pick(s, options))
	return true


static func _fits(sp: Dictionary, d: int) -> bool:
	match sp.form:
		"kreis":
			return d <= int(sp.radius) + 1
		"ring":
			return d >= 1 and d <= int(sp.radius) + 1
		"linie":
			return d >= 2
	return true


# ================================================================ Phasen

static func phase(m: Dictionary) -> int:
	return int(J.num(m, "phase"))


static func _check_phase(s: Dictionary, m: Dictionary) -> void:
	var ratio: float = float(m.hp) / maxf(1.0, m.maxHp)
	var want := 0
	for i in PHASE_AT.size():
		if ratio <= PHASE_AT[i]:
			want = i + 1
	if want <= phase(m):
		return
	m.phase = want
	m.specialCd = mini(int(J.num(m, "specialCd")), 1)
	var def = boss_def(m.defId)
	var lines: Array = J.arr(def, "phaseLines") if def != null else []
	var line: String = lines[want - 1] if lines.size() >= want else ("%s schnaubt und wird schneller." if want == 1 else "%s blutet aus allen Ritzen und kämpft jetzt um alles.")
	if line.contains("%s"):
		line = line % Identify.name_of_cap(s, m)
	Log.add(s, line, "gefahr")
	Fx.float_text(s, m.pos, "Phase %d" % (want + 1), "#ff7a4a")
	# Rufer holen in jeder neuen Phase sofort Verstärkung
	if Abilities.has(m, "rufer"):
		m.summoned = 0
		Abilities._summon(s, m)
	Events.emit(s, {"type": "bossPhase", "phase": want + 1, "source": m.name})


# ================================================================ Angriffe

## Felder, die ein Angriff trifft, von der Lage beim Ankündigen aus.
static func target_tiles(s: Dictionary, m: Dictionary, sp: Dictionary) -> Array:
	var p: Dictionary = s.player.pos
	var out := []
	var r := int(J.nn(sp, "radius", 1))
	match sp.form:
		"kreis":
			# Rund um den Boss
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx != 0 or dy != 0:
						out.append(J.pos(m.pos.x + dx, m.pos.y + dy))
		"ring":
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) == r:
						out.append(J.pos(m.pos.x + dx, m.pos.y + dy))
		"flaeche":
			# Rund um den Crawler
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					out.append(J.pos(p.x + dx, p.y + dy))
		"hagel":
			# Das Feld des Crawlers und ein paar zufällige daneben
			out.append(J.pcopy(p))
			for k in int(J.nn(sp, "count", 4)):
				out.append(J.pos(p.x + R.int_(s, -2, 2), p.y + R.int_(s, -2, 2)))
		"linie":
			# Vom Boss auf den Crawler zu und darüber hinaus
			var dx := signi(p.x - m.pos.x)
			var dy := signi(p.y - m.pos.y)
			var cur := J.pcopy(m.pos)
			for k in int(J.nn(sp, "length", 6)):
				cur = J.pos(cur.x + dx, cur.y + dy)
				if not MapGen.is_walkable(s.map, cur.x, cur.y):
					break
				out.append(cur)
	var seen := {}
	var tiles := []
	for q in out:
		var key := "%d,%d" % [q.x, q.y]
		if seen.has(key) or not MapGen.is_walkable(s.map, q.x, q.y):
			continue
		seen[key] = true
		tiles.append(q)
	return tiles


static func _announce(s: Dictionary, m: Dictionary, id: String) -> void:
	var sp := special_def(id)
	m.telegraph = {"id": id, "tiles": target_tiles(s, m, sp)}
	m.specialCd = COOLDOWN[mini(phase(m), COOLDOWN.size() - 1)]
	Log.add(s, "%s %s" % [Identify.name_of_cap(s, m), sp.warn], "gefahr")
	Events.emit(s, {"type": "bossTelegraph", "special": id, "source": m.name})


static func on_tile(m: Dictionary, p: Dictionary) -> bool:
	var tg = m.get("telegraph")
	if tg == null:
		return false
	return J.some(tg.tiles, func(q): return q.x == p.x and q.y == p.y)


## Alle angekündigten Gefahrenfelder (für Karte und Tooltip).
static func danger_tiles(s: Dictionary) -> Array:
	var out := []
	for m in s.monsters:
		if m.get("telegraph") != null:
			out.append_array(m.telegraph.tiles)
	return out


static func _resolve(s: Dictionary, m: Dictionary) -> void:
	var tg: Dictionary = m.telegraph
	m.erase("telegraph")
	var sp := special_def(tg.id)
	var who := Identify.name_of_cap(s, m)
	var p: Dictionary = s.player
	# Ansturm: Der Boss rennt die Linie entlang, bis etwas im Weg steht
	if sp.form == "linie":
		var last = null
		for q in tg.tiles:
			if Ai.occupied(s, q, m) and not (q.x == p.pos.x and q.y == p.pos.y):
				break
			if q.x == p.pos.x and q.y == p.pos.y:
				break
			last = q
		if last != null:
			m.pos = J.pcopy(last)
	var pet = p.pet if p.pet != null and p.pet.alive else null
	if pet != null and J.some(tg.tiles, func(q): return q.x == pet.pos.x and q.y == pet.pos.y):
		var pd := maxi(1, J.rnd(R.int_(s, m.dmg[0], m.dmg[1]) * float(sp.mult) * 0.6))
		pet.hp -= pd
		Log.add(s, "%s erwischt %s für %d Schaden." % [who, pet.name, pd], "gefahr")
		if pet.hp <= 0:
			pet.hp = 0
			pet.alive = false
			Log.add(s, "%s bricht bewusstlos zusammen und verschwindet in einem Transportlicht. Schlaf in einem Safe Room, dann kommt %s zurück." % [pet.name, pet.name], "gefahr")
	var hit: bool = J.some(tg.tiles, func(q): return q.x == p.pos.x and q.y == p.pos.y)
	for q in tg.tiles:
		Fx.hit(s, q, false)
	if not hit:
		s.counters.bossDodges = int(J.num(s.counters, "bossDodges")) + 1
		Log.add(s, "%s %s Du bist rechtzeitig ausgewichen." % [who, sp.miss], "kampf")
		Events.emit(s, {"type": "bossDodged", "special": tg.id, "source": m.name})
		return
	var b := Player.total_bonuses(s)
	var raw := J.rnd(R.int_(s, m.dmg[0], m.dmg[1]) * float(sp.mult))
	var dmg := maxi(1, raw - floori(J.num(b, "ruestung") / 2.0))
	if Mounts.mount_absorbs(s, dmg, who):
		return
	p.hp -= dmg
	s.counters.damageTaken += dmg
	Fx.float_text(s, p.pos, "-%d" % dmg, Fx.COLORS.gegenSpieler)
	Fx.hit(s, p.pos, true)
	Log.add(s, "%s %s %d Schaden." % [who, sp.hit, dmg], "gefahr")
	if p.hp <= 0:
		Death.handle_lethal(s, "getötet von %s" % Identify.name_of_dat(s, m))
		return
	Events.emit(s, {"type": "damageTaken", "amount": dmg, "source": m.name, "facets": ["z:boss", "t:spezial"]})
	var cond = sp.get("cond")
	if cond != null:
		Conditions.inflict_player(s, cond, int(J.nn(sp, "condTurns", 3)), 1 + floori(m.level / 4.0), who)
