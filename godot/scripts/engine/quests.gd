class_name Quests
extends RefCounted
## Aufträge.

const REWARD_BASE := {"jagd": 25, "finden": 30, "liefern": 20, "retten": 45, "boss": 80, "nest": 40, "schatz": 35}


static func quests(s: Dictionary) -> Array:
	if s.get("quests") == null:
		s.quests = []
	return s.quests


static func active_quests(s: Dictionary) -> Array:
	return quests(s).filter(func(q): return q.status == "aktiv")


static func quest_of(s: Dictionary, giver_ref: String) -> Variant:
	return J.find(quests(s), func(q): return q.giver.ref == giver_ref and (q.status == "angebot" or q.status == "aktiv"))


static func _uid(s: Dictionary, prefix: String) -> String:
	s.uidCounter += 1
	return "%s%d" % [prefix, s.uidCounter]


static func _reward(s: Dictionary, kind: String) -> Dictionary:
	var f: int = s.floor
	var base: int = REWARD_BASE[kind]
	return {"gold": J.rnd((base + R.int_(s, 0, 20)) * f), "xp": J.rnd(base * 1.5 * f), "box": kind == "boss" or kind == "retten" or R.chance(s, 0.3)}


## Ein Raum weit weg vom Crawler.
static func _far_room(s: Dictionary) -> Variant:
	var rooms: Array = s.map.rooms.filter(func(r): return r.kind == "normal" and not r.get("sealed"))
	var here: Dictionary = s.player.pos
	var far := rooms.filter(func(r): return J.cheb({"x": r.x, "y": r.y}, here) >= 18)
	var list := far if not far.is_empty() else rooms
	return R.pick(s, list) if not list.is_empty() else MapGen._pick_empty(s)


static func _free_spot(s: Dictionary, r: Dictionary) -> Variant:
	for i in 40:
		var p := J.pos(R.int_(s, r.x, r.x + r.w - 1), R.int_(s, r.y, r.y + r.h - 1))
		if MapGen.tile_at(s.map, p.x, p.y) != "floor":
			continue
		if J.some(s.monsters, func(m): return m.pos.x == p.x and m.pos.y == p.y) or J.some(Crawlers.crawlers(s), func(c): return c.pos.x == p.x and c.pos.y == p.y):
			continue
		return p
	return null


static func _hunt_facets(s: Dictionary) -> Array:
	var tags := []
	var facets: Dictionary = Db.t("facets", "TARGET_FACETS")
	for m in Db.t("monsters", "MONSTERS"):
		if m.floors.has(s.floor) and m.weight > 0:
			for t in J.arr(m, "tags"):
				if facets.has(t) and not tags.has(t):
					tags.append(t)
	return tags


## Erzeugt ein Auftragsangebot für einen Crawler oder einen Laden. Crawler
## beginnen manchmal eine Auftragskette (mehrere Teile, steigende Belohnung).
static func offer_quest(s: Dictionary, giver: Dictionary) -> Variant:
	if giver.kind == "crawler" and R.chance(s, float(Db.t("quests", "CHAIN_CHANCE"))):
		var chains: Array = Db.t("quests", "QUEST_CHAINS").filter(func(c): return not J.arr(s, "chainsDone").has(c.id) and _feasible(s, c.steps[0].kind))
		if not chains.is_empty():
			var chain: Dictionary = R.pick(s, chains)
			var q = _make(s, giver, chain.steps[0].kind, {"id": chain.id, "name": chain.name, "step": 0, "total": chain.steps.size()})
			if q != null:
				return q
	var kinds := ["jagd", "boss", "liefern", "nest"] if giver.kind == "laden" else ["jagd", "finden", "liefern", "retten", "finden", "nest", "schatz"]
	var kind: String = R.pick(s, kinds.filter(func(k): return _feasible(s, k)))
	return _make(s, giver, kind, null)


## Lässt sich eine Auftragsart auf dieser Etage gerade stellen?
static func _feasible(s: Dictionary, kind: String) -> bool:
	match kind:
		"boss":
			return J.some(s.map.hoods, func(h): return h.bossAlive)
		"nest":
			return _nest_room(s) != null
		"schatz":
			return _treasure_room(s) != null
	return true


static func _nest_room(s: Dictionary) -> Variant:
	return J.find(s.map.rooms, func(r): return r.get("feature") == "nest" and J.some(J.arr(r, "furniture"), func(f): return f.kind == "nest"))


static func _treasure_room(s: Dictionary) -> Variant:
	return J.find(s.map.rooms, func(r): return r.get("feature") == "schatz" and not r.get("visited"))


static func _hood_name(s: Dictionary, hood: int) -> String:
	var h = s.map.hoods[hood] if hood >= 0 and hood < s.map.hoods.size() else null
	return h.name if h != null else "Nachbarviertel"


## Baut einen Auftrag. chain (oder null): {id, name, step, total, person?}.
static func _make(s: Dictionary, giver: Dictionary, kind: String, chain: Variant) -> Variant:
	var step = Db.t("quests", "QUEST_CHAINS").filter(func(c): return c.id == chain.id)[0].steps[chain.step] if chain != null else {}
	var room = _far_room(s)
	var hood_name := _hood_name(s, room.hood) if room != null else "Nachbarviertel"
	var q := {
		"id": _uid(s, "q"), "kind": kind, "floor": s.floor, "giver": giver, "title": "", "text": "", "status": "angebot", "count": 1, "progress": 0, "reward": _reward(s, kind),
	}
	match kind:
		"jagd":
			var tags := _hunt_facets(s)
			if tags.is_empty():
				return null
			var tag: String = R.pick(s, tags)
			q.facet = "z:%s" % tag
			q.count = int(step.count) if step.has("count") else R.int_(s, 3, 6)
			var label: String = Db.t("facets", "TARGET_FACETS")[tag].label
			q.title = "Jagd: %d %s" % [q.count, label]
			q.text = (step.text if step.has("text") else R.pick(s, Db.t("quests", "HUNT_TEXTS"))).replace("{n}", str(q.count)).replace("{was}", label)
		"finden":
			if room == null:
				return null
			var f: Dictionary = {"name": step.item, "text": step.text} if step.has("item") else R.pick(s, Db.t("quests", "FETCH_ITEMS"))
			q.hood = room.hood
			q.title = "Finden: %s" % f.name
			q.text = J.replace1(f.text, "{viertel}", hood_name)
			q.itemIds = [f.name]
		"liefern":
			var w: Dictionary = step.want if step.has("want") else R.pick(s, Db.t("quests", "DELIVER_WANTS"))
			q.itemIds = w.ids.duplicate()
			q.count = w.n
			q.title = "Liefern: %sx %s" % [J.s(w.n), w.label]
			q.text = step.text if step.has("text") else w.text
		"retten":
			if room == null:
				return null
			q.hood = room.hood
			var person := Crawlers.make_crawler(s, J.pos(0, 0), "verzweifelt")
			q.title = "Retten: %s" % person.name
			q.text = (step.text if step.has("text") else R.pick(s, Db.t("quests", "RESCUE_TEXTS"))).replace("{person}", person.name).replace("{viertel}", hood_name)
			q.itemIds = [person.name]
			if chain != null:
				chain.person = person.name
		"boss":
			var alive: Array = s.map.hoods.filter(func(h): return h.bossAlive)
			if alive.is_empty():
				return null
			var h: Dictionary = R.pick(s, alive)
			q.hood = h.id
			q.title = "Boss: %s" % h.name
			q.text = J.replace1(step.text if step.has("text") else R.pick(s, Db.t("quests", "BOSS_TEXTS")), "{viertel}", h.name)
		"nest", "schatz":
			var target = _nest_room(s) if kind == "nest" else _treasure_room(s)
			if target == null:
				return null
			q.hood = target.hood
			q.roomId = target.id
			var name := _hood_name(s, target.hood)
			q.title = ("Nest ausräumen: %s" if kind == "nest" else "Schatzkammer öffnen: %s") % name
			q.text = J.replace1(step.text if step.has("text") else R.pick(s, Db.t("quests", "NEST_TEXTS" if kind == "nest" else "SCHATZ_TEXTS")), "{viertel}", name)
	if chain != null:
		q.chain = chain
		q.title = "%s (%d/%d): %s" % [chain.name, chain.step + 1, chain.total, q.title]
		if chain.get("person") != null:
			q.text = q.text.replace("{person}", chain.person)
		# Spätere Teile einer Kette zahlen mehr
		q.reward.gold = J.rnd(q.reward.gold * (1 + 0.4 * chain.step))
		q.reward.xp = J.rnd(q.reward.xp * (1 + 0.4 * chain.step))
		if chain.step == chain.total - 1:
			q.reward.box = true
	quests(s).append(q)
	return q


static func accept(s: Dictionary, id: String) -> Dictionary:
	var q = J.find(quests(s), func(x): return x.id == id)
	if q == null or q.status != "angebot":
		return {"ok": false, "message": "Diesen Auftrag gibt es nicht."}
	var max_q: int = Db.t("quests", "MAX_ACTIVE_QUESTS")
	if active_quests(s).size() >= max_q:
		return {"ok": false, "message": "Du hast schon %d offene Aufträge." % max_q}
	if q.kind == "finden" or q.kind == "retten":
		var rooms: Array = s.map.rooms.filter(func(r): return r.kind == "normal" and r.hood == q.get("hood"))
		var room = R.pick(s, rooms) if not rooms.is_empty() else _far_room(s)
		var spot = _free_spot(s, room) if room != null else null
		if room == null or spot == null:
			return {"ok": false, "message": "Der Auftrag lässt sich gerade nicht annehmen."}
		if q.kind == "finden":
			var it := Items.create_item(s, "andenken")
			it.name = q.itemIds[0]
			it.flavor = "Gehört jemandem, der darauf wartet: %s." % q.giver.name
			it.questId = q.id
			s.items.append({"pos": spot, "item": it})
			q.targetUid = it.uid
		else:
			var c := Crawlers.make_crawler(s, spot, "verzweifelt")
			c.name = q.itemIds[0]
			Crawlers.crawlers(s).append(c)
			q.targetUid = c.uid
			# Ein paar Monster halten die Person in Schach
			var def := Db.floor_def0(s.floor)
			var pool: Array = Db.t("monsters", "MONSTERS").filter(func(m): return m.floors.has(s.floor) and m.weight > 0 and m.behavior != "stationary")
			var i := 0
			while i < 2 and not pool.is_empty():
				var near = null
				for d in [[2, 0], [-2, 0], [0, 2], [0, -2], [2, 2], [-2, -2]]:
					var p := J.pos(spot.x + d[0], spot.y + d[1])
					var r = MapGen.room_of(s.map, p)
					if MapGen.is_walkable(s.map, p.x, p.y) and r != null and r.kind == "normal" and not J.some(s.monsters, func(m): return m.pos.x == p.x and m.pos.y == p.y):
						near = p
						break
				var md = Monsters.def_by_id(R.pick(s, pool).id)
				if near != null and md != null:
					s.monsters.append(Monsters.spawn_monster(s, md, R.int_(s, def.mobLevel[0], def.mobLevel[1]), near, room.hood))
				i += 1
	q.status = "aktiv"
	Log.add(s, "AUFTRAG ANGENOMMEN: %s. %s" % [q.title, hint(s, q)], "system")
	Events.emit(s, {"type": "questAccepted", "kind": q.kind})
	return {"ok": true}


static func decline(s: Dictionary, id: String) -> Dictionary:
	var q = J.find(quests(s), func(x): return x.id == id)
	if q == null or q.status != "angebot":
		return {"ok": false, "message": "Diesen Auftrag gibt es nicht."}
	s.quests = J.without(quests(s), q)
	return {"ok": true}


## Kurzer Hinweis, was als Nächstes zu tun ist.
static func hint(s: Dictionary, q: Dictionary) -> String:
	var hood := ""
	if q.get("hood") != null:
		var h = s.map.hoods[q.hood] if q.hood >= 0 and q.hood < s.map.hoods.size() else null
		hood = h.name if h != null else "undefined"
	match q.kind:
		"jagd":
			var def = Db.t("facets", "TARGET_FACETS").get(String(q.facet).substr(2))
			return "Noch %d %s." % [maxi(0, q.count - q.progress), def.label if def != null else "Gegner"]
		"finden":
			return ("Bring es zu %s." % q.giver.name) if _has_quest_item(s, q) else ("Such im %s." % hood)
		"liefern":
			return "Bring die Sachen zu %s." % q.giver.name
		"retten":
			return "Such im %s und sprich die Person an." % hood
		"boss":
			return "Besiege den Boss im %s." % hood
		"nest":
			return "Räum das Monsternest im %s aus." % hood
		"schatz":
			return "Finde die Schatzkammer im %s und öffne sie (Schlüssel oder Schloss knacken)." % hood
	return ""


static func _has_quest_item(s: Dictionary, q: Dictionary) -> bool:
	var hand = s.player.hand
	return J.some(s.player.inventory, func(i): return i.get("questId") == q.id) or (hand != null and hand.get("questId") == q.id)


static func _count_of(s: Dictionary, ids: Array) -> int:
	var n := 0
	for i in s.player.inventory:
		if ids.has(i.baseId):
			n += int(J.nn(i, "menge", 1))
	return n


static func _consume(s: Dictionary, ids: Array, n: int) -> void:
	for it in s.player.inventory.duplicate():
		if n <= 0:
			break
		if not ids.has(it.baseId):
			continue
		var have: int = J.nn(it, "menge", 1)
		var take := mini(have, n)
		n -= take
		if have - take > 0:
			it.menge = have - take
		else:
			s.player.inventory = J.without(s.player.inventory, it)


static func _complete(s: Dictionary, q: Dictionary, thanks: String = "") -> void:
	q.status = "erledigt"
	q.progress = q.count
	var r: Dictionary = q.reward
	Log.add(s, ("AUFTRAG ERLEDIGT: %s. %s" % [q.title, thanks]).strip_edges(), "system")
	Inventory.give_item(s, Items.create_gold(s, r.gold))
	var xp := Player.gain_xp(s, r.xp)
	Log.add(s, "Belohnung: %s Gold, %d XP%s." % [J.s(r.gold), xp, " und eine Abenteurer-Box" if r.box else ""], "loot")
	if r.box:
		s.player.boxes.append(Items.create_box(s, "abenteurer", "silber" if s.floor >= 2 else "bronze"))
	Log.toast(s, "Auftrag erledigt", q.title, "loot")
	if q.giver.kind == "laden":
		var room = s.map.rooms[int(q.giver.ref)] if int(q.giver.ref) < s.map.rooms.size() else null
		if room != null and room.get("shop") != null:
			room.shop.mood = mini(150, room.shop.mood + 40)
			for o in room.shop.offers:
				o.price = maxi(1, J.rnd(o.price * 0.85))
			Log.add(s, "%s gibt dir ab sofort 15 %% Freundschaftsrabatt." % room.shop.keeper, "dialog")
	else:
		var giver = J.find(Crawlers.crawlers(s), func(c): return c.uid == q.giver.ref)
		if giver != null:
			giver.trust = mini(100, giver.trust + 40)
	Events.emit(s, {"type": "questDone", "kind": q.kind, "done": quests(s).filter(func(x): return x.status == "erledigt").size()})
	_continue_chain(s, q)


## Nach einem Kettenteil: nächsten Teil anbieten oder die Kette abschließen.
static func _continue_chain(s: Dictionary, q: Dictionary) -> void:
	var chain = q.get("chain")
	if chain == null:
		return
	if chain.step + 1 >= chain.total:
		if s.get("chainsDone") == null:
			s.chainsDone = []
		s.chainsDone.append(chain.id)
		var prize := Items.generate_equipment(s, "selten" if s.floor < 3 else "episch")
		Inventory.give_item(s, prize)
		Log.add(s, "%s: „Das war alles. Ohne dich hätte ich das nie geschafft. Hier, das gehört jetzt dir.“ Du erhältst %s." % [q.giver.name, Identify.item_name(s, prize)], "loot")
		Events.emit(s, {"type": "chainDone", "chain": chain.id})
		return
	if q.giver.kind == "crawler" and not J.some(Crawlers.crawlers(s), func(c): return c.uid == q.giver.ref and c.alive):
		return
	var next_chain: Dictionary = chain.duplicate()
	next_chain.step += 1
	var kind: String = Db.t("quests", "QUEST_CHAINS").filter(func(c): return c.id == chain.id)[0].steps[next_chain.step].kind
	if not _feasible(s, kind):
		Log.add(s, "%s wollte noch etwas von dir, aber das hat sich erledigt." % q.giver.name, "dialog")
		return
	var nq = _make(s, q.giver, kind, next_chain)
	if nq != null:
		Log.add(s, "%s hat noch etwas für dich (Teil %d von %d): %s" % [q.giver.name, next_chain.step + 1, next_chain.total, nq.text], "dialog")


static func _fail(s: Dictionary, q: Dictionary, why: String) -> void:
	q.status = "gescheitert"
	Log.add(s, "AUFTRAG GESCHEITERT: %s. %s" % [q.title, why], "gefahr")
	Events.emit(s, {"type": "questFailed", "kind": q.kind})


static func can_turn_in(s: Dictionary, q: Dictionary) -> bool:
	if q.status != "aktiv" or (q.kind != "finden" and q.kind != "liefern"):
		return false
	if q.kind == "finden" and not _has_quest_item(s, q):
		return false
	if q.kind == "liefern" and _count_of(s, J.arr(q, "itemIds")) < q.count:
		return false
	if q.giver.kind == "laden":
		var r = MapGen.room_of(s.map, s.player.pos)
		return r != null and r.id == int(q.giver.ref)
	var c = J.find(Crawlers.crawlers(s), func(x): return x.uid == q.giver.ref and x.alive)
	return c != null and J.cheb(c.pos, s.player.pos) <= 1


static func turn_in(s: Dictionary, id: String) -> Dictionary:
	var q = J.find(quests(s), func(x): return x.id == id)
	if q == null or not can_turn_in(s, q):
		return {"ok": false, "message": "Das kannst du hier noch nicht abgeben."}
	if q.kind == "finden":
		s.player.inventory = s.player.inventory.filter(func(i): return i.get("questId") != q.id)
		if s.player.hand != null and s.player.hand.get("questId") == q.id:
			s.player.hand = null
	else:
		_consume(s, J.arr(q, "itemIds"), q.count)
	_complete(s, q, R.pick(s, Db.t("quests", "QUEST_THANKS")))
	return {"ok": true}


static func on_event(s: Dictionary, e: Dictionary) -> void:
	if J.arr(s, "quests").is_empty():
		return
	if e.type == "nestCleared" or e.type == "treasureFound":
		var want := "nest" if e.type == "nestCleared" else "schatz"
		for q in active_quests(s):
			if q.kind == want and int(J.nn(q, "roomId", -1)) == int(e.room):
				_complete(s, q, "%s hört davon und ist beeindruckt. Die Belohnung kommt per Transportlicht." % q.giver.name)
		return
	if e.type != "kill":
		return
	for q in active_quests(s):
		if q.kind == "jagd" and q.get("facet") and Observer.target_facets(s, e.monster).has(q.facet):
			q.progress += 1
			if q.progress >= q.count:
				_complete(s, q, "Die Nachricht erreicht %s. Die Belohnung wird dir vom System gutgeschrieben." % q.giver.name)
		if q.kind == "boss" and e.monster.rank == "nachbarschaftsboss" and e.monster.hood == q.get("hood"):
			_complete(s, q, "%s hat zugesehen. Die Belohnung kommt per Transportlicht." % q.giver.name)


## Nach jedem Zug: Rettungen prüfen, verschwundene Auftraggeber erkennen.
static func tick(s: Dictionary) -> void:
	if J.arr(s, "quests").is_empty():
		return
	for q in active_quests(s):
		if q.kind == "retten":
			var c = J.find(Crawlers.crawlers(s), func(x): return x.uid == q.get("targetUid"))
			if c == null or not c.alive:
				_fail(s, q, "Die Person hat es nicht geschafft.")
				continue
			if J.cheb(c.pos, s.player.pos) <= 1:
				c.personality = "freundlich"
				c.trust = 90
				c.met = true
				Log.add(s, "%s: „Du … bist wegen mir gekommen? Danke. Ich gehe mit dir, wenn du mich lässt.“" % c.name, "dialog")
				_complete(s, q, "%s ist gerettet." % c.name)
			continue
		if (q.kind == "finden" or q.kind == "liefern") and q.giver.kind == "crawler" and not J.some(Crawlers.crawlers(s), func(c): return c.uid == q.giver.ref and c.alive):
			_fail(s, q, "%s lebt nicht mehr." % q.giver.name)


## Beim Abstieg: offene Aufträge der alten Etage scheitern.
static func on_descend(s: Dictionary) -> void:
	for q in quests(s):
		if q.status == "aktiv":
			_fail(s, q, "Die Etage ist Geschichte.")
		if q.status == "angebot":
			q.status = "gescheitert"
	s.player.inventory = s.player.inventory.filter(func(i): return not i.get("questId"))
