class_name Achievements
extends RefCounted
## Prüft alle Achievements gegen ein Ereignis.
## Wer ein Achievement zum ersten Mal (über alle eigenen Staffeln) erreicht,
## hat ab Etage 2 eine doppelt so hohe Chance, dass aus Silber Gold wird.


static func check(s: Dictionary, e: Dictionary) -> void:
	if s.status != "playing" and e.type != "start":
		return
	var have := {}
	for id in s.achievements:
		have[id] = true
	for row in DataChecks.achievements():
		var a: Dictionary = row[0]
		if have.has(a.id):
			continue
		var types: Array = row[1]
		if not types.is_empty() and not types.has(e.type):
			continue
		if not row[2].call(e, s):
			continue
		# Ein verschachteltes Ereignis (z. B. Follower) kann es schon vergeben haben
		if s.achievements.has(a.id):
			have[a.id] = true
			continue
		s.achievements.append(a.id)
		have[a.id] = true
		Log.add(s, "NEUES ACHIEVEMENT: %s – %s" % [a.name, a.description], "achievement")
		Log.add(s, "%s" % a.comment, "achievement")
		if a.get("box") == null:
			# Kleine Erfolge: keine Box, nur etwas Aufmerksamkeit beim Publikum
			Fx.sound(s, {"kind": "achievement", "tier": "bronze"})
			Log.add(s, "Belohnung: Das Publikum nimmt Notiz von dir.", "loot")
			Viewers.add_spectacle(s, 2, "achievement")
			Log.toast(s, "Achievement: %s" % a.name, a.description, "achievement")
			continue
		var first: bool = not s.firstEver.has(a.id)
		var meister: bool = a.get("meister", false)
		var bx := Items.create_box(s, a.box, a.tier, meister, first)
		s.player.boxes.append(bx)
		var tier: String = bx.box.tier
		Fx.sound(s, {"kind": "achievement", "tier": tier})
		var tiers: Array = Db.world("BOX_TIERS")
		var first_note := " ERSTMALIG IN DEINER KARRIERE – Box-Stufe erhöht!" if first and tiers.find(tier) > tiers.find(a.tier) else ""
		if meister:
			first_note += " MEISTERLEISTUNG!"
		var tier_name: String = Db.world("BOX_TIER_NAMES")[tier]
		var box_name: String = Db.world("BOX_TYPE_NAMES")[a.box]
		Log.add(s, "Belohnung: %s %s.%s" % [tier_name, box_name, first_note], "loot")
		Viewers.add_spectacle(s, 4 + Db.world("BOX_TIERS").find(tier) * 4, "achievement")
		Log.toast(s, "Achievement: %s" % a.name, "%s Belohnung: %s %s" % [a.description, tier_name, box_name], "achievement")
