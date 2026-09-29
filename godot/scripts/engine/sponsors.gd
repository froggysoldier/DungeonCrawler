class_name Sponsors
extends RefCounted
## Sponsoren.

const TIERS := ["silber", "silber", "gold", "gold", "platin"]


static func _fresh(id: String) -> Dictionary:
	return {"id": id, "interest": 0, "status": "none", "favor": 50, "wish": 0, "progress": 0, "completed": 0}


static func states(s: Dictionary) -> Array:
	var defs: Array = Db.t("sponsors", "SPONSORS")
	if s.get("sponsors") == null:
		s.sponsors = defs.map(func(d): return _fresh(d.id))
	for d in defs:
		if not J.some(s.sponsors, func(x): return x.id == d.id):
			s.sponsors.append(_fresh(d.id))
	return s.sponsors


static func active_sponsors(s: Dictionary) -> Array:
	return states(s).filter(func(x): return x.status == "active")


## Übersetzt ein Spielereignis in Signale, die Sponsoren interessieren.
static func signals_of(e: Dictionary) -> Array:
	match e.type:
		"kill":
			var out := ["kill"]
			if e.get("byPet"):
				out.append("kill|pet")
			else:
				for f in J.arr(e, "facets"):
					out.append("kill|%s" % f)
			return out
		"attack":
			return ["crit"] if e.crit else []
		"crafted":
			return ["crafted", "crafted|%s" % e.recipe]
		"trapTriggered":
			return ["trap|self" if e.onPlayer else "trap|monster"]
		"trapDisarmed":
			return ["trap|disarmed"] if e.success else []
		"haggle":
			return ["haggle|ok" if e.success else "haggle|fail"]
		"bought":
			return ["bought|haggled" if e.haggled else "bought|full"]
		"petGained":
			return ["petGained"]
		"petLevel":
			return ["pet|level"]
		"petEvolved":
			return ["pet|evolve"]
		"talkShow":
			return ["talk|%s" % e.tone]
		"sleep":
			return ["sleep"]
		"eat":
			return ["eat"]
		"spellCast":
			return ["spell", "spell|%s" % e.spell]
		"dodged":
			return ["dodge"]
		"bossDodged":
			return ["dodge", "boss|dodge"]
		"crateSmashed":
			return ["crate"]
		"secretFound":
			return ["secret"]
		"lockPicked":
			return ["lockpick"]
		"treasureFound":
			return ["treasure"]
		"nestCleared":
			return ["nest"]
		"prayed":
			return ["prayed"]
		"questDone":
			return ["quest", "quest|%s" % e.kind]
		"questFailed":
			return ["quest|fail"]
		"chainDone":
			return ["chain"]
	return []


static func _give_reward(s: Dictionary, def: Dictionary, st: Dictionary) -> void:
	var tier: String = TIERS[mini(TIERS.size() - 1, st.completed)]
	s.player.boxes.append(Items.create_box(s, def.box, tier))
	st.completed += 1
	st.favor = mini(100, st.favor + 15)
	var tier_name: String = Db.world("BOX_TIER_NAMES")[tier]
	var box_name: String = Db.world("BOX_TYPE_NAMES")[def.box]
	Log.add(s, "SPONSOR: %s ist zufrieden. Du erhältst eine %s %s als Sponsorengeschenk." % [def.name, tier_name, box_name], "loot")
	Log.toast(s, "Sponsorengeschenk: %s" % def.name, "%s %s" % [tier_name, box_name], "loot")
	st.wish = (st.wish + 1) % def.wishes.size()
	st.progress = 0
	Log.add(s, "%s wünscht sich als Nächstes: %s" % [def.name, def.wishes[st.wish].text], "system")
	Events.emit(s, {"type": "sponsorWish", "id": def.id, "completed": st.completed})


static func on_event(s: Dictionary, e: Dictionary) -> void:
	if not s.unlocks.has("zuschauer") or s.status != "playing":
		return
	var signals := signals_of(e)
	if signals.is_empty():
		return
	for st in states(s):
		var def = Db.sponsor(st.id)
		if def == null:
			continue
		if st.status == "none":
			var gain := 0.0
			for sig in signals:
				gain += J.num(def.likes, sig)
			if not gain:
				continue
			st.interest = minf(100, st.interest + gain * (0.6 + s.viewers.hype / 100.0))
			if st.interest >= 100 and s.viewers.follower >= def.minFollower and active_sponsors(s).size() < Db.t("sponsors", "MAX_SPONSORS"):
				st.status = "offer"
				Log.add(s, "SPONSORENANGEBOT von %s: %s (Annehmen oder ablehnen im Crawler-Tab.)" % [def.name, def.offer], "system")
				Log.toast(s, "Sponsorenangebot", def.name, "loot")
			continue
		if st.status != "active":
			continue
		if signals.has(def.dislike.signal):
			st.favor -= 15
			Log.add(s, "%s ist verstimmt: %s (Gunst %s)" % [def.name, def.dislike.text, J.s(maxf(0, st.favor))], "gefahr")
			if st.favor <= 0:
				st.status = "dropped"
				Log.add(s, "%s beendet das Sponsoring. Die Pressemitteilung ist kurz und gemein." % def.name, "gefahr")
				Events.emit(s, {"type": "sponsorDropped", "id": def.id})
				continue
		var wish: Dictionary = def.wishes[st.wish]
		var hits := signals.filter(func(sig): return wish.signals.has(sig)).size()
		if not hits:
			continue
		st.progress += hits
		if st.progress >= wish.count:
			_give_reward(s, def, st)


static func accept(s: Dictionary, id: String) -> Dictionary:
	var st = J.find(states(s), func(x): return x.id == id)
	var def = Db.sponsor(id)
	if st == null or def == null or st.status != "offer":
		return {"ok": false, "message": "Dieses Angebot gibt es nicht."}
	var max_s: int = Db.t("sponsors", "MAX_SPONSORS")
	if active_sponsors(s).size() >= max_s:
		return {"ok": false, "message": "Mehr als %d Sponsoren erlaubt der Vertrag nicht." % max_s}
	st.status = "active"
	st.favor = 50
	st.progress = 0
	Log.add(s, "Du unterschreibst bei %s. Ihr Logo erscheint klein in der Ecke jeder Übertragung. Erster Wunsch: %s" % [def.name, def.wishes[st.wish].text], "system")
	Events.emit(s, {"type": "sponsorJoined", "id": id, "count": active_sponsors(s).size()})
	return {"ok": true}


static func decline(s: Dictionary, id: String) -> Dictionary:
	var st = J.find(states(s), func(x): return x.id == id)
	var def = Db.sponsor(id)
	if st == null or def == null or st.status != "offer":
		return {"ok": false, "message": "Dieses Angebot gibt es nicht."}
	st.status = "none"
	st.interest = 40
	Log.add(s, "Du lehnst %s ab. Vielleicht fragen sie später noch einmal." % def.name, "info")
	return {"ok": true}
