class_name Invitations
extends RefCounted
## Einladungen in Shows (data/show.json FORMATS): Wer bekannt genug ist und
## in den Highlights auftaucht, wird eingeladen – zur Fragerunde, in die
## Talkshow, in die Diskussionsrunde und selten zum Gladiatorenkampf in der
## Grube. Angenommen wird am Bildschirm eines Safe Rooms.


static func formats() -> Dictionary:
	return Db.t("show", "FORMATS")


static func format_name(id: String) -> String:
	if id == "talkshow":
		return Db.t("talkshow", "SHOW_TITLE")
	return formats()[id].name


## Formate, für die der Crawler bekannt genug ist.
static func eligible(s: Dictionary) -> Array:
	var out := []
	for id in formats():
		var f: Dictionary = formats()[id]
		if int(s.viewers.follower) >= int(f.minFollower) and int(s.player.level) >= int(J.nn(f, "minLevel", 0)):
			out.append(id)
	return out


static func pending(s: Dictionary) -> Variant:
	return s.get("invitation")


## Nach jeder Sendung: wer darin vorkam, wird oft eingeladen, sonst selten.
static func after_episode(s: Dictionary, featured: bool) -> void:
	if pending(s) != null:
		return
	var el := eligible(s)
	if el.is_empty():
		return
	var cfg: Dictionary = Db.t("show", "INVITATION")
	if not R.chance(s, float(cfg.chanceFeatured if featured else cfg.chanceOther)):
		return
	# Die Grube ist selten; dasselbe Format nicht zweimal hintereinander
	if el.has("gladiator") and not R.chance(s, float(formats().gladiator.chance)):
		el.erase("gladiator")
	if el.size() > 1 and el.has(s.get("lastFormat", "")):
		el.erase(s.lastFormat)
	if el.is_empty():
		return
	var id: String = R.weighted(s, el.map(func(x): return [x, float(formats()[x].weight)]))
	var until: int = s.turn + int(cfg.validTurns)
	s.invitation = {"format": id, "until": until}
	var t := Highlights.time_of_day(s) + int(cfg.validTurns) * int(Db.world("MINUTES_PER_TURN"))
	var bis := "%02d:%02d" % [(t % 1440) / 60, t % 60]
	Log.add(s, String(cfg.text).replace("{format}", format_name(id)).replace("{bis}", bis), "system")
	Log.toast(s, "Einladung", format_name(id), "loot")
	Events.emit(s, {"type": "invited", "format": id})


## Verfallene Einladungen: die Produktion ist beleidigt.
static func tick(s: Dictionary) -> void:
	var inv = pending(s)
	if inv == null or int(s.turn) <= int(inv.until):
		return
	s.erase("invitation")
	s.viewers.hype = maxf(0, s.viewers.hype - 10)
	Log.add(s, String(Db.t("show", "INVITATION").expired).replace("{format}", format_name(inv.format)), "info")


static func accept(s: Dictionary) -> Dictionary:
	var inv = pending(s)
	if inv == null:
		return {"ok": false, "message": "Du hast keine Einladung."}
	if not Combat.is_in_safe_room(s, s.player.pos):
		return {"ok": false, "message": "Teilnehmen kannst du nur am Bildschirm in einem Safe Room."}
	if Game.time_left(s) < 120:
		return {"ok": false, "message": "Zu spät – die Etage stürzt bald ein. Die Produktion sagt ab."}
	s.erase("invitation")
	s.lastFormat = inv.format
	Events.emit(s, {"type": "invitationAccepted", "format": inv.format})
	if inv.format == "gladiator":
		s.pendingDialogs.append(Arena.start(s))
	else:
		s.pendingDialogs.append(TalkShow.start_format(s, inv.format))
	return {"ok": true}


static func decline(s: Dictionary) -> Dictionary:
	var inv = pending(s)
	if inv == null:
		return {"ok": false, "message": "Du hast keine Einladung."}
	s.erase("invitation")
	s.viewers.hype = maxf(0, s.viewers.hype - 5)
	Log.add(s, String(Db.t("show", "INVITATION").declined).replace("{format}", format_name(inv.format)), "info")
	Events.emit(s, {"type": "invitationDeclined", "format": inv.format})
	return {"ok": true}
