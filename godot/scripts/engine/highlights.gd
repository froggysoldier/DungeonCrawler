class_name Highlights
extends RefCounted
## Die Highlight-Sendung „Abgrund am Abend“ (data/show.json): Ab Etage 2
## sammelt die Redaktion den Tag über spektakuläre Szenen – besondere Kills,
## viele Kills, Bosse, Meisterleistungen. Jeden Abend um 21 Uhr läuft die
## Sendung bis Mitternacht auf den Bildschirmen der Safe Rooms. Wer gut genug
## war, kommt selbst vor; danach kommen Einladungen (siehe Invitations).


static func _d(k: String) -> Variant:
	return Db.t("show", k)


# ================================================================ Uhrzeit

## Minuten seit Mitternacht des ersten Tages (Spielbeginn um CLOCK_START).
static func clock_minutes(s: Dictionary, turn: int = -1) -> int:
	return int(_d("CLOCK_START")) + (int(s.turn) if turn < 0 else turn) * int(Db.world("MINUTES_PER_TURN"))


static func day(s: Dictionary) -> int:
	return clock_minutes(s) / 1440 + 1


## Uhrzeit in Minuten seit Mitternacht.
static func time_of_day(s: Dictionary) -> int:
	return clock_minutes(s) % 1440


static func clock_text(s: Dictionary) -> String:
	var t := time_of_day(s)
	return "Tag %d, %02d:%02d" % [day(s), t / 60, t % 60]


## Nummer der Sendung: wechselt jeden Abend um 21 Uhr.
static func _episode_no(s: Dictionary) -> int:
	return floori((clock_minutes(s) - int(_d("AIR_MINUTE"))) / 1440.0)


# ================================================================ Zustand

static func state(s: Dictionary) -> Dictionary:
	if s.get("highlights") == null:
		s.highlights = {"scenes": [], "kills": 0, "aired": _episode_no(s), "featured": 0, "top": 0, "watched": 0, "current": null, "alive": Crawlers.population(s).alive}
	return s.highlights


## Läuft gerade eine Sendung (zwischen 21 Uhr und Mitternacht)?
static func on_air(s: Dictionary) -> bool:
	var cur = J.nn(state(s), "current", null)
	return cur != null and int(s.turn) < int(cur.until)


# ================================================================ Szenen sammeln

static func _fill(s: Dictionary, text: String, vars: Dictionary) -> String:
	var pet = s.player.pet
	var out := text.replace("{name}", s.player.name).replace("{haustier}", pet.name if pet != null else "dein Haustier")
	for k in vars:
		out = out.replace("{%s}" % k, J.s(vars[k]))
	return out


## Eine Szene für die Sendung vormerken (nur die besten bleiben im Rennen).
static func note(s: Dictionary, score: float, kind: String, vars: Dictionary = {}) -> void:
	if not Viewers.active(s):
		return
	var tpl = J.nn(_d("PLAYER_SCENES"), kind, null)
	if tpl == null:
		return
	var h := state(s)
	h.scenes.append({"score": score, "kind": kind, "text": _fill(s, tpl, vars)})
	J.sort(h.scenes, func(a, b): return b.score - a.score)
	if h.scenes.size() > int(_d("MAX_SCENES")):
		h.scenes = h.scenes.slice(0, int(_d("MAX_SCENES")))


## Kill: zählt für „viele Kills“, besondere Kills werden zur Szene.
static func on_kill(s: Dictionary, m: Dictionary, pts: float, kind: String) -> void:
	if not Viewers.active(s):
		return
	var h := state(s)
	h.kills += 1
	# Gewöhnliche Kills schaffen es nie in die Sendung; Elite schon eher
	if pts < 8:
		return
	note(s, pts, kind if J.nn(_d("PLAYER_SCENES"), kind, null) != null else "kill", {"gegner": Identify.name_of(s, m, "akk")})


# ================================================================ Ausstrahlung

## Jeden Zug: um 21 Uhr läuft die neue Sendung an. Wer schläft oder in der
## Grube kämpft, bekommt sie, sobald er wieder da ist.
static func tick(s: Dictionary) -> void:
	if not Viewers.active(s) or Arena.active(s) or s.status != "playing":
		return
	var h := state(s)
	var ep := _episode_no(s)
	if ep > int(h.aired):
		h.aired = ep
		_air(s)
	Invitations.tick(s)


static func _npc_names(s: Dictionary, n: int) -> Array:
	var names: Array = Crawlers.crawlers(s).filter(func(c): return c.alive and not c.party).map(func(c): return c.name)
	var out := []
	for i in n:
		if not names.is_empty() and R.chance(s, 0.6):
			var nm: String = R.pick(s, names)
			names.erase(nm)
			out.append(nm)
		else:
			out.append("%s %s" % [R.pick(s, Db.t("crawlers", "FIRST_NAMES")), R.pick(s, Db.t("crawlers", "LAST_NAMES"))])
	return out


## Ein besonderer Raum, den der Crawler noch nicht kennt (Tipp der Redaktion).
static func _tip_room(s: Dictionary) -> Variant:
	var kinds: Dictionary = _d("TIP_KINDS")
	var m: Dictionary = s.map
	var rooms: Array = m.rooms.filter(func(r):
		return kinds.has(J.nn(r, "feature", "")) and not m.explored[MapGen.idx(m, r.x + r.w / 2, r.y + r.h / 2)])
	return R.pick(s, rooms) if not rooms.is_empty() else null


static func _air(s: Dictionary) -> void:
	var h := state(s)
	var show: Dictionary = _d("HIGHLIGHTS")
	var pages := [_fill(s, show.intro, {"tag": day(s)})]
	# Szenen anderer Crawler
	var npc_lines: Array = R.shuffle(s, (_d("NPC_SCENES") as Array).duplicate())
	var names := _npc_names(s, 2)
	var npc_text := []
	for i in names.size():
		npc_text.append(String(npc_lines[i]).replace("{name}", names[i]))
	pages.append(" ".join(npc_text))
	# Eigene Szenen: viele Kills zählen auch
	if int(h.kills) >= int(_d("RAMPAGE_KILLS")):
		note(s, minf(60, float(h.kills)), "rampage", {"kills": h.kills})
	var best: float = float(h.scenes[0].score) if not h.scenes.is_empty() else 0.0
	var featured := best >= float(_d("FEATURE_MIN"))
	var top := featured and best > R.int_(s, 25, 45)
	if featured:
		var mine: Array = h.scenes.filter(func(sc): return float(sc.score) >= float(_d("FEATURE_MIN"))).slice(0, 2)
		pages.append(_fill(s, show.featured_top if top else show.featured, {}) + "\n\n" + " ".join(mine.map(func(sc): return sc.text)))
		h.featured += 1
		if top:
			h.top += 1
	else:
		pages.append(show.not_featured)
	# Gedenken: wie viele Crawler seit gestern gestorben sind
	var alive: int = Crawlers.population(s).alive
	var dead: int = maxi(0, int(h.alive) - alive)
	h.alive = alive
	if dead > 0:
		pages.append(String(show.dead_line).replace("{anzahl}", J.de(dead)))
	var tip = _tip_room(s)
	var tod := time_of_day(s)
	var air: int = int(_d("AIR_MINUTE"))
	var mpt: int = int(Db.world("MINUTES_PER_TURN"))
	var until: int = s.turn + (ceili((int(_d("AIR_UNTIL")) - tod) / float(mpt)) if tod >= air else 0)
	h.current = {"day": day(s) - (0 if tod >= air else 1), "pages": pages, "until": until, "featured": featured, "top": top, "tipRoom": tip.id if tip != null else null, "watched": false}
	h.scenes = []
	h.kills = 0
	if featured:
		# Die ganze Galaxis hat dich gesehen – ob du selbst zuschaust oder nicht
		Viewers.add_spectacle(s, minf(50, 10 + best * (0.75 if top else 0.5)), "highlight")
		Log.add(s, "ABGRUND AM ABEND: Du bist heute in den Highlights%s! Die Follower strömen herbei." % (" – mit der Szene des Tages" if top else ""), "system")
		Log.toast(s, "In den Highlights!", "Szene des Tages" if top else "Die Galaxis hat dich gesehen", "loot")
	Events.emit(s, {"type": "highlight", "featured": featured, "top": top})
	if s.turn >= until:
		if featured:
			Log.add(s, "Die Sendung lief, während du weg warst. Die Galaxis hat dich gesehen – du selbst leider nicht.", "info")
	elif Combat.is_in_safe_room(s, s.player.pos):
		s.pendingDialogs.append(watch(s))
	else:
		Log.add(s, show.missed, "system")
	Invitations.after_episode(s, featured)


## Die laufende Sendung am Bildschirm ansehen.
static func watch(s: Dictionary) -> Dictionary:
	var h := state(s)
	var cur: Dictionary = h.current
	var show: Dictionary = _d("HIGHLIGHTS")
	var pages: Array = cur.pages.duplicate()
	if cur.get("tipRoom") != null:
		var room = J.find(s.map.rooms, func(r): return r.id == cur.tipRoom)
		if room != null:
			var kinds: Dictionary = _d("TIP_KINDS")
			var hood: String = s.map.hoods[room.hood].name if room.hood >= 0 and room.hood < s.map.hoods.size() else "Dungeon"
			pages.append(String(show.tip).replace("{viertel}", hood).replace("{was}", kinds[room.feature]))
			if not cur.watched:
				_reveal(s, room)
	pages.append(show.outro)
	if not cur.watched:
		cur.watched = true
		h.watched += 1
		Events.emit(s, {"type": "highlightWatched", "featured": cur.featured})
	return {"title": "%s – Tag %d" % [show.title, cur.day], "speaker": show.host, "pages": pages}


static func _reveal(s: Dictionary, room: Dictionary) -> void:
	var m: Dictionary = s.map
	for y in range(room.y - 1, room.y + room.h + 1):
		for x in range(room.x - 1, room.x + room.w + 1):
			if MapGen.in_bounds(m, x, y):
				m.explored[MapGen.idx(m, x, y)] = true


## Was der Bildschirm im Safe Room gerade zeigt (für Hinweise in der Oberfläche).
static func screen_text(s: Dictionary) -> String:
	var show: Dictionary = _d("HIGHLIGHTS")
	if not Viewers.active(s):
		return show.screen_early
	if on_air(s):
		return "Jetzt läuft: %s – Tag %d (bis Mitternacht)." % [show.title, state(s).current.day]
	return show.screen_off
