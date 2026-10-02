class_name ShowEvents
extends RefCounted
## Einlagen der Show: Ab und zu ruft die Regie eine zeitlich begrenzte Einlage
## aus (Doppelte Erfahrung, Goldrausch, Licht aus, Schnäppchenstunde,
## Erste Hilfe, Kritische Stunde, Kopfgeld). Erst nach dem Tutorial.
## Die Definitionen stehen in world.json (SHOW_EVENTS).
##
## Zustand: s.showEvent = {id, left, [bountyUid]} oder fehlt;
##          s.nextShowEvent = Zug, ab dem die nächste Einlage kommen darf.

const FIRST_DELAY := 120
const GAP := [220, 340]


static func defs() -> Array:
	return Db.world("SHOW_EVENTS")


static func def_of(id: String) -> Variant:
	return J.find(defs(), func(d): return d.id == id)


static func active(s: Dictionary) -> Variant:
	return s.get("showEvent")


static func active_def(s: Dictionary) -> Variant:
	var e = active(s)
	return def_of(e.id) if e != null else null


## Boni der laufenden Einlage (für Player.total_bonuses).
static func bonuses(s: Dictionary) -> Variant:
	var d = active_def(s)
	return d.get("bonuses") if d != null else null


static func gold_factor(s: Dictionary) -> float:
	var d = active_def(s)
	return float(d.get("gold", 1)) if d != null else 1.0


static func price_factor(s: Dictionary) -> float:
	var d = active_def(s)
	return float(d.get("price", 1.0)) if d != null else 1.0


## Jeden Zug: laufende Einlage herunterzählen oder eine neue starten.
static func tick(s: Dictionary, turns: int) -> void:
	if not Game.has_unlock(s, "stats") or s.status != "playing":
		return
	var e = active(s)
	if e != null:
		if e.get("bountyUid") != null and not J.some(s.monsters, func(x): return x.uid == e.bountyUid):
			# Ziel von jemand anderem erledigt
			s.erase("showEvent")
			s.nextShowEvent = s.turn + R.int_(s, GAP[0], GAP[1])
			Log.add(s, "Jemand anderes hat dein Kopfgeld-Ziel erledigt. Die Show zahlt nicht an Unbeteiligte.", "info")
			return
		e.left -= turns
		if e.left <= 0:
			_end(s)
		return
	if s.get("nextShowEvent") == null:
		s.nextShowEvent = s.turn + FIRST_DELAY
		return
	if s.turn < int(s.nextShowEvent) or Combat.is_in_safe_room(s, s.player.pos):
		return
	start(s, R.pick(s, defs()).id)


## Eine Einlage starten (auch für Tests).
static func start(s: Dictionary, id: String) -> bool:
	var d = def_of(id)
	if d == null:
		return false
	var e := {"id": id, "left": R.int_(s, d.turns[0], d.turns[1])}
	if d.get("bounty", false):
		var target = _bounty_target(s)
		if target == null:
			s.nextShowEvent = s.turn + 30
			return false
		var reward: int = 40 * int(s.floor) + 10 * int(target.level)
		target.bounty = reward
		e.bountyUid = target.uid
		var hi := MapGen.hood_of(s.map, target.pos)
		var where := (" im %s" % s.map.hoods[hi].name) if hi < s.map.hoods.size() else ""
		Log.add(s, "EINLAGE: %s! %s Ziel: %s%s. Belohnung: %d Gold." % [d.name, d.text, Identify.name_of(s, target, "nom"), where, reward], "system")
	else:
		Log.add(s, "EINLAGE: %s! %s" % [d.name, d.text], "system")
	s.showEvent = e
	Log.toast(s, "Einlage: %s" % d.name, d.text, "info")
	Events.emit(s, {"type": "showEvent", "id": id})
	return true


static func _end(s: Dictionary) -> void:
	var e = active(s)
	if e == null:
		return
	var d = def_of(e.id)
	if e.get("bountyUid") != null:
		var m = J.find(s.monsters, func(x): return x.uid == e.bountyUid)
		if m != null:
			m.erase("bounty")
			Log.add(s, "Das Kopfgeld ist verfallen. Das Ziel lebt weiter und weiß nichts von seinem Glück.", "info")
			Events.emit(s, {"type": "bountyLost"})
	s.erase("showEvent")
	s.nextShowEvent = s.turn + R.int_(s, GAP[0], GAP[1])
	if d != null and e.get("bountyUid") == null:
		Log.add(s, Db.world("SHOW_EVENT_END") % d.name, "info")


## Ziel fürs Kopfgeld: der stärkste Nicht-Boss außerhalb von Safe Rooms und Siedlung.
static func _bounty_target(s: Dictionary) -> Variant:
	var best = null
	for m in s.monsters:
		if m.rank == "nachbarschaftsboss" or m.rank == "etagenboss" or m.get("homeRoom") != null or m.get("bounty"):
			continue
		if Combat.is_in_safe_room(s, m.pos) or Kanalstadt.is_town(s, m.pos):
			continue
		var score: float = m.level * 10 + (25 if m.rank == "elite" else 0) - J.cheb(m.pos, s.player.pos) * 0.1
		if best == null or score > best[0]:
			best = [score, m]
	return best[1] if best != null else null


## Beim Tod eines Monsters: Kopfgeld auszahlen.
static func on_kill(s: Dictionary, m: Dictionary) -> void:
	if not m.get("bounty"):
		return
	var gold := int(m.bounty)
	s.player.gold += gold
	s.counters.goldEarned += gold
	Log.add(s, "KOPFGELD KASSIERT: %d Gold. Das Publikum tobt." % gold, "loot")
	Events.emit(s, {"type": "bountyClaimed", "gold": gold})
	Events.emit(s, {"type": "goldGained", "amount": gold})
	var e = active(s)
	if e != null and e.get("bountyUid") == m.uid:
		s.erase("showEvent")
		s.nextShowEvent = s.turn + R.int_(s, GAP[0], GAP[1])


## Für die Anzeige: Name und restliche Züge, oder "".
static func label(s: Dictionary) -> String:
	var e = active(s)
	var d = active_def(s)
	if e == null or d == null:
		return ""
	return "%s (%d)" % [d.name, int(e.left)]
