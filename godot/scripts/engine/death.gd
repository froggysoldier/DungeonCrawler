class_name Death
extends RefCounted
## Tod – außer die Zweite-Chance-Klausel greift (Port von src/engine/death.ts).


static func handle_lethal(s: Dictionary, cause: String) -> void:
	var p: Dictionary = s.player
	var slot = null
	for k in p.equipment:
		var it = p.equipment[k]
		if it != null and it.get("special") == "zweite_chance":
			slot = k
			break
	if slot != null:
		p.equipment.erase(slot)
		if not p.curses.has("Kleingedrucktes"):
			p.curses.append("Kleingedrucktes")
		p.hp = ceili(Player.max_hp(s) / 2.0)
		Log.add(s, "Die Welt wird schwarz… und dann wieder hell. Die Zweite-Chance-Klausel zerfällt zu Staub. Das Kleingedruckte: dauerhaft −5 max. HP und −1 Charisma.", "system")
		Events.emit(s, {"type": "revived"})
		return
	p.hp = 0
	s.status = "dead"
	s.deathCause = cause
	if s.contractSigned:
		s.deathCause = "%s – doch der Vertrag greift: in den Dienst der Show übernommen" % cause
		Log.add(s, "Kurz bevor alles schwarz wird, leuchtet dein Vertrag auf. Du stirbst nicht. Du wirst… Personal.", "system")
	Log.add(s, "Du bist gestorben (%s)." % cause, "gefahr")
