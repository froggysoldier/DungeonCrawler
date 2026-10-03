class_name TalkShow
extends RefCounted
## Rückblick beim Abstieg und die Gesprächsformate der Show: Talkshow,
## Fragerunde und Diskussionsrunde (Texte in data/talkshow.json und data/show.json).

const COUNTER_KEYS := ["kills", "steps", "itemsPicked", "boxesOpened", "missStreak", "hitTakenStreak", "throws", "bossKills", "damageDealt", "damageTaken", "goldEarned", "goldStolen", "poisonDamage", "mealsEaten", "potionsDrunk", "sleeps", "crits", "knockdowns", "eliteKills", "trapsFound", "trapsTriggered", "trapsDisarmed", "trapKills", "crafted"]


static func snapshot_floor(s: Dictionary) -> void:
	var counters := {}
	for k in s.counters:
		if k != "killsByDef":
			counters[k] = s.counters[k]
	s.floorSnapshot = {
		"turn": s.turn,
		"counters": counters,
		"achievements": s.achievements.size(),
		"patterns": J.arr(s, "dynAchievements").size(),
		"follower": s.viewers.follower,
		"fallen": J.arr(s, "fallen").size(),
		"level": s.player.level,
	}


static func _fmt(n: float) -> String:
	return J.de(J.rnd(n))


static func _favorite_part(s: Dictionary) -> Variant:
	var by_part := {}
	for k in s.player.techniqueKills:
		var part := String(k).split("+")[0]
		by_part[part] = J.num(by_part, part) + s.player.techniqueKills[k]
	var entries := []
	for k in by_part:
		entries.append([k, by_part[k]])
	J.sort(entries, func(a, b): return b[1] - a[1])
	return entries[0][0] if not entries.is_empty() else null


static func floor_recap(s: Dictionary) -> Dictionary:
	var snap = s.get("floorSnapshot")
	var c: Dictionary = s.counters
	var d := func(k: String) -> float:
		return float(c[k]) - (J.num(snap.counters, k) if snap != null else 0.0)
	var def = null
	for f in Db.world("FLOORS"):
		if f.floor == s.floor:
			def = f
	var turns: int = s.turn - (snap.turn if snap != null else s.floorStartTurn)
	var new_ach := []
	for id in s.achievements.slice(snap.achievements if snap != null else 0):
		var a = Db.achievement(id)
		if a != null and a.name:
			new_ach.append(a.name)
	var new_patterns: Array = J.arr(s, "dynAchievements").slice(snap.patterns if snap != null else 0).map(func(a): return a.name)
	var fallen: Array = J.arr(s, "fallen").slice(snap.fallen if snap != null else 0)
	var pages := []

	var boss_n: float = d.call("bossKills")
	var fight := [
		"Kampf: %s Gegner besiegt%s%s." % [J.s(d.call("kills")), (", davon %s Elite" % J.s(d.call("eliteKills"))) if d.call("eliteKills") else "", (", %s Boss%s" % [J.s(boss_n), "e" if boss_n > 1 else ""]) if boss_n else ""],
		"Schaden ausgeteilt: %s. Schaden eingesteckt: %s. Kritische Treffer: %s. Gegner umgeworfen: %s." % [_fmt(d.call("damageDealt")), _fmt(d.call("damageTaken")), J.s(d.call("crits")), J.s(d.call("knockdowns"))],
	]
	var fav = _favorite_part(s)
	if fav != null:
		fight.append("Liebste Angriffsart bisher: %s." % Bonuses.PART_NAMES[fav])
	var lvl_note := ""
	if snap != null and s.player.level > snap.level:
		lvl_note = " (%d Level aufgestiegen)" % (s.player.level - snap.level)
	pages.append("RÜCKBLICK: ETAGE %d%s\n\nDu hast %s Züge auf dieser Etage verbracht und bist mit Level %d abgestiegen%s.\n\n%s" % [s.floor, (" – %s" % def.name) if def != null else "", _fmt(turns), s.player.level, lvl_note, " ".join(fight)])

	var misc := []
	misc.append("Gegenstände aufgehoben: %s. Lootboxen geöffnet: %s. Gold verdient: %s." % [J.s(d.call("itemsPicked")), J.s(d.call("boxesOpened")), _fmt(d.call("goldEarned"))])
	if d.call("trapsFound") or d.call("trapsTriggered") or d.call("trapsDisarmed"):
		misc.append("Fallen: %s entdeckt, %s entschärft, %s selbst ausgelöst." % [J.s(d.call("trapsFound")), J.s(d.call("trapsDisarmed")), J.s(d.call("trapsTriggered"))])
	if d.call("crafted") or d.call("trapKills"):
		misc.append("Handwerk: %s Dinge gebaut, %s Gegner durch Fallen und Sprengsätze erledigt." % [J.s(d.call("crafted")), J.s(d.call("trapKills"))])
	if d.call("potionsDrunk") or d.call("mealsEaten"):
		misc.append("Tränke getrunken: %s. Mahlzeiten: %s." % [J.s(d.call("potionsDrunk")), J.s(d.call("mealsEaten"))])
	pages.append("\n\n".join(misc))

	var social := []
	if not new_ach.is_empty():
		social.append("Neue Achievements (%d): %s." % [new_ach.size(), ", ".join(new_ach)])
	if not new_patterns.is_empty():
		social.append("Die Systemstimme hat Muster erkannt: %s." % ", ".join(new_patterns))
	if s.unlocks.has("zuschauer") and snap != null:
		var gained: int = s.viewers.follower - snap.follower
		social.append("Follower: %s (%s%s auf dieser Etage)." % [_fmt(s.viewers.follower), "+" if gained >= 0 else "", _fmt(gained)])
	var members: Array = J.arr(s, "crawlers").filter(func(x): return x.alive and x.party)
	if not members.is_empty():
		social.append("Deine Party: %s." % ", ".join(members.map(func(m): return "%s (Level %d, %d Kills)" % [m.name, m.level, m.kills])))
	if not fallen.is_empty():
		social.append("Gefallen: %s. Die Systemstimme vermerkt es. Du wirst es nicht so schnell vergessen." % ", ".join(fallen))
	social.append("Laut letzter Zählung leben noch %s Crawler." % _fmt(Crawlers.population(s).alive))
	pages.append("\n\n".join(social))
	return {"title": "Rückblick: Etage %d" % s.floor, "speaker": Db.world("SYSTEM_NAME"), "pages": pages}


static func _fill(s: Dictionary, text: String, vars: Dictionary = {}) -> String:
	var pet = s.player.pet
	var fav = _favorite_part(s)
	var fallen := J.arr(s, "fallen")
	var out := text \
		.replace("{name}", s.player.name) \
		.replace("{background}", s.player.background) \
		.replace("{haustier}", pet.name if pet != null else "dein Haustier") \
		.replace("{gefallen}", fallen[fallen.size() - 1] if not fallen.is_empty() else "Jemand") \
		.replace("{kills}", _fmt(s.counters.kills)) \
		.replace("{lieblingsangriff}", ("%s-Angriffen" % Bonuses.PART_NAMES[fav]) if fav != null else "bloßen Händen") \
		.replace("{achievements}", str(s.achievements.size()))
	for k in vars:
		out = out.replace("{%s}" % k, String(vars[k]))
	return out


static func _pick_questions(s: Dictionary) -> Array:
	var all: Array = Db.t("talkshow", "SHOW_QUESTIONS")
	var pool := all.filter(func(q): return q.id != "plan" and DataChecks.talkshow_when(q.id, s))
	var ranked := pool.map(func(q): return {"q": q, "r": q.priority + R.next(s) * 0.9})
	J.sort(ranked, func(a, b): return b.r - a.r)
	var plan = J.find(all, func(q): return q.id == "plan")
	var out := ranked.slice(0, 2).map(func(x): return x.q)
	out.append(plan)
	return out


## Show zwischen den Etagen: Talkshow für Bekannte, Fragerunde für
## Aufsteiger, für Unbekannte gar nichts (null).
static func start(s: Dictionary) -> Variant:
	var f: Dictionary = Invitations.formats()
	if int(s.viewers.follower) >= int(f.talkshow.minFollower):
		return start_format(s, "talkshow")
	if int(s.viewers.follower) >= int(f.fragerunde.minFollower):
		return start_format(s, "fragerunde")
	return null


## Zwei Gäste für die Diskussionsrunde: andere Crawler der Etage, sonst
## Studiogäste.
static func _guests(s: Dictionary) -> Array:
	var names: Array = Crawlers.crawlers(s).filter(func(c): return c.alive and not c.party).map(func(c): return c.name)
	var extras: Array = R.shuffle(s, (Db.t("show", "GUEST_EXTRAS") as Array).duplicate())
	var out := []
	for i in 2:
		if not names.is_empty():
			var nm: String = R.pick(s, names)
			names.erase(nm)
			out.append(nm)
		else:
			out.append(J.cap(extras[i]))
	return out


## Eine Sendung im gewünschten Format beginnen (Fragerunde, Talkshow,
## Diskussionsrunde). Gibt den Dialog für die Oberfläche zurück.
static func start_format(s: Dictionary, format: String) -> Dictionary:
	var fdef: Dictionary = Invitations.formats()[format]
	var vars := {}
	var raw: Array
	var title: String
	var host: String
	var intro: Array
	match format:
		"talkshow":
			raw = _pick_questions(s)
			title = Db.t("talkshow", "SHOW_TITLE")
			host = Db.t("talkshow", "SHOW_HOST")
			intro = Db.t("talkshow", "SHOW_INTRO")
		"fragerunde":
			var pool: Array = Db.t("show", "FRAGERUNDE_QUESTIONS").filter(func(q): return q.get("when") == null or DataChecks.talkshow_when(q.when, s))
			raw = R.shuffle(s, pool.duplicate()).slice(0, int(fdef.count))
			title = fdef.name
			host = fdef.host
			intro = fdef.intro
		_:
			var topic: Dictionary = R.pick(s, Db.t("show", "DISKUSSION_TOPICS"))
			var guests := _guests(s)
			vars = {"gast1": guests[0], "gast2": guests[1], "thema": topic.thema}
			raw = topic.rounds
			title = fdef.name
			host = fdef.host
			intro = fdef.intro
	var viewer_names: Array = Db.t("viewers", "VIEWER_NAMES")
	var questions := []
	for q in raw:
		var qv := vars.duplicate()
		qv.zuschauer = R.pick(s, viewer_names)
		var answers := []
		for a in q.answers:
			var e: Dictionary = a.duplicate()
			e.label = _fill(s, a.label, vars)
			e.reaction = _fill(s, a.reaction, vars)
			if a.get("failReaction") != null:
				e.failReaction = _fill(s, a.failReaction, vars)
			answers.append(e)
		questions.append({"id": J.nn(q, "id", ""), "text": _fill(s, q.text, qv), "answers": answers})
	s.talkShow = {"format": format, "host": host, "title": title, "roundLabel": fdef.roundLabel, "vars": vars, "questions": questions, "index": 0, "followerDelta": 0, "done": false}
	return {"kind": "talkshow", "title": title, "speaker": host, "pages": intro.map(func(p): return _fill(s, p, vars))}


static func answer(s: Dictionary, answer_index: int) -> Dictionary:
	var show = s.get("talkShow")
	if show == null or show.done:
		return {"ok": false}
	var q = show.questions[show.index] if show.index < show.questions.size() else null
	var a = q.answers[answer_index] if q != null and answer_index >= 0 and answer_index < q.answers.size() else null
	if a == null:
		return {"ok": false}
	var format: String = J.nn(show, "format", "talkshow")
	var fdef: Dictionary = Invitations.formats()[format]
	var cha: float = Player.effective_stats(s).cha
	var v: Dictionary = s.viewers
	var scale := minf(60, 3 + v.follower * 0.04) * float(fdef.scale)
	var cha_mult := maxf(0.4, 1 + (cha - 5) * 0.08)
	var delta: int
	var reaction: String = a.reaction
	if a.get("risky"):
		var chance := maxf(0.1, minf(0.9, 0.35 + (cha - 5) * 0.06 + v.hype / 300.0))
		if R.chance(s, chance):
			delta = J.rnd(absf(a.base) * scale * cha_mult * 1.3)
		else:
			delta = -J.rnd(absf(a.base) * scale * 0.6)
			reaction = a.get("failReaction") if a.get("failReaction") != null else reaction
	else:
		delta = J.rnd(a.base * scale * (cha_mult if a.base > 0 else 1.0))
	v.follower = maxi(0, v.follower + delta)
	v.hype = maxf(0, minf(100, v.hype + (8 if delta > 0 else -10)))
	show.followerDelta += delta
	show.index += 1
	Log.add(s, "%s – %s: %s (%s%s Follower)" % [show.title, a.label, reaction, "+" if delta >= 0 else "", _fmt(delta)], "dialog")
	var tone: String = a.tone
	if show.index < show.questions.size():
		return {"ok": true, "reaction": reaction, "delta": delta}
	show.done = true
	var total: int = show.followerDelta
	var reward: Array = fdef.reward
	var outro: String
	if format == "talkshow":
		outro = Db.t("talkshow", "SHOW_OUTRO_GOOD") if total >= int(reward[0]) else (Db.t("talkshow", "SHOW_OUTRO_OK") if total >= 0 else Db.t("talkshow", "SHOW_OUTRO_BAD"))
	else:
		outro = fdef.outro_good if total >= int(reward[0]) else (fdef.outro_ok if total >= 0 else fdef.outro_bad)
	outro = _fill(s, outro, show.vars)
	Log.add(s, "%s vorbei. %s Bilanz: %s%s Follower." % [show.title, outro, "+" if total >= 0 else "", _fmt(total)], "system")
	if total >= int(reward[0]):
		s.player.boxes.append(Items.create_box(s, "fan", "gold" if total >= int(reward[1]) else "silber"))
	Events.emit(s, {"type": "talkShow", "delta": total, "tone": tone, "format": format, "won": total >= int(reward[0])})
	return {"ok": true, "reaction": reaction, "delta": delta, "finished": true, "outro": outro}
