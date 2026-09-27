class_name Viewers
extends RefCounted
## Zuschauer-System ab Etage 2 (Port von src/engine/viewers.ts).


static func active(s: Dictionary) -> bool:
	return s.unlocks.has("zuschauer")


static func live_viewers(s: Dictionary) -> int:
	var v: Dictionary = s.viewers
	return J.rnd(v.follower * (0.15 + v.hype / 120.0) + v.hype * 3)


static func add_spectacle(s: Dictionary, points: float, kind: String) -> void:
	if not active(s) or points <= 0:
		return
	var v: Dictionary = s.viewers
	var cha: float = Player.effective_stats(s).cha
	var stage := 1 + Player.skill_level(s, "rampenlicht") * 0.05
	var mult: float = maxf(0.3, 1 + (cha - 5) * 0.08) * (0.5 + v.hype / 50.0) * (2.0 if Abilities.has_special(s, "reichweite") else 1.0) * Traits.trait_follower_mult(s) * stage
	if points >= 4:
		Skills.train_skill(s, "show", 1)
	v.hype = minf(100, v.hype + points * 1.5)
	v.lastSpectacle = s.turn
	var gained := maxi(1, J.rnd(points * 3 * mult))
	v.follower += gained

	var comments = Db.t("viewers", "VIEWER_COMMENTS").get(kind)
	if comments != null and points >= 4 and R.chance(s, 0.35):
		Log.add(s, "Zuschauer %s: „%s“" % [R.pick(s, Db.t("viewers", "VIEWER_NAMES")), R.pick(s, comments)], "dialog")
	# Große Momente: Geschenk aus dem Publikum
	if points >= 15 and R.chance(s, minf(0.6, 0.15 + (cha - 5) * 0.03)):
		fan_gift(s)

	var thresholds: Array = Db.t("viewers", "FAN_THRESHOLDS")
	while v.nextFanBox < thresholds.size() and v.follower >= thresholds[v.nextFanBox][0]:
		var threshold = thresholds[v.nextFanBox][0]
		var tier: String = thresholds[v.nextFanBox][1]
		v.nextFanBox += 1
		s.player.boxes.append(Items.create_box(s, "fan", tier))
		var tier_name: String = Db.world("BOX_TIER_NAMES")[tier]
		Log.add(s, "%s Follower! Die Fans schicken dir eine %s Fan-Box." % [J.s(threshold), tier_name], "loot")
		Log.toast(s, "%s Follower!" % J.s(threshold), "%s Fan-Box erhalten" % tier_name, "loot")
	Events.emit(s, {"type": "followers", "follower": v.follower})


static func fan_gift(s: Dictionary) -> void:
	var item := Items.create_item(s, R.pick(s, Db.t("viewers", "FAN_GIFTS")))
	Inventory.give_item(s, item)
	Stats.track(s, "fangeschenke")
	Log.add(s, "Zuschauer %s schickt dir ein Geschenk: %s!" % [R.pick(s, Db.t("viewers", "VIEWER_NAMES")), Identify.item_name(s, item)], "loot")


## Zeit vergeht: Hype kühlt ab, bei Langeweile murrt das Publikum.
static func tick(s: Dictionary, turns: int) -> void:
	if not active(s):
		return
	var v: Dictionary = s.viewers
	v.hype = maxf(0, v.hype - turns * 0.4)
	if turns == 1 and s.turn - v.lastSpectacle > 80 and R.chance(s, 0.02):
		Log.add(s, "Zuschauer %s: „%s“" % [R.pick(s, Db.t("viewers", "VIEWER_NAMES")), R.pick(s, Db.t("viewers", "VIEWER_COMMENTS").boring)], "dialog")


static func on_event(s: Dictionary, e: Dictionary) -> void:
	if not active(s):
		return
	match e.type:
		"kill":
			var m: Dictionary = e.monster
			var pts := 2 + floori(m.level / 2.0)
			var kind := "kill"
			var t = e.get("technique")
			if t != null and t.move == "stampfen":
				pts += 6
				kind = "stomp"
			if t != null and t.move == "sprung":
				pts += 5
				kind = "jump"
			if t != null and t.move == "anlauf":
				pts += 3
			if t != null and t.part == "kopf":
				pts += 3
			if m.rank == "elite":
				pts += 8
			if m.rank == "nachbarschaftsboss":
				pts += 40
				kind = "boss"
			if m.rank == "boroughboss":
				pts += 100
				kind = "boss"
			if m.rank == "geist":
				pts += 40
			if e.get("byPet"):
				pts += 6
				kind = "pet"
			if m.get("fleeing"):
				pts += 3
			var f := J.arr(e, "facets")
			if f.has("t:falle"):
				pts += 5
				kind = "trap"
			if f.has("t:bombe"):
				pts += 4
				kind = "bomb"
			add_spectacle(s, pts, kind)
		"trapTriggered":
			add_spectacle(s, 4 if e.onPlayer else 3, "trap")
		"crawlerDied":
			if e.party:
				add_spectacle(s, 10, "drama")
		"rammed":
			add_spectacle(s, 7 if e.kill else 4, "stomp")
		"partyJoined":
			add_spectacle(s, 3, "party")
		"attack":
			if e.crit:
				add_spectacle(s, 3, "crit")
			if e.damage >= 25:
				add_spectacle(s, 4, "crit")
		"damageTaken":
			var last = s.viewers.get("lastCloseCall")
			if s.player.hp <= Player.max_hp(s) * 0.2 and s.turn - (-999 if last == null else int(last)) > 20:
				s.viewers.lastCloseCall = s.turn
				add_spectacle(s, 8, "closecall")
		"explosion":
			add_spectacle(s, 5, "closecall")
		"robbed":
			add_spectacle(s, 4, "kill")
		"levelUp":
			add_spectacle(s, 10, "achievement")
		"boxOpened":
			add_spectacle(s, 3, "item")
