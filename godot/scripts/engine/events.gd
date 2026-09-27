class_name Events
extends RefCounted
## Zentrale Stelle für Spielereignisse (Port von src/engine/events.ts).


static func emit(s: Dictionary, e: Dictionary) -> void:
	Stats.on_event(s, e)
	if e.type == "levelUp":
		Fx.sound(s, {"kind": "levelup"})
	if e.type == "boxOpened":
		var box = e.item.get("box")
		Fx.sound(s, Items.compact({"kind": "box", "tier": box.tier if box != null else null}))
	if e.type == "skillLearned":
		Fx.sound(s, {"kind": "skill"})
	Skills.on_event(s, e)
	Achievements.check(s, e)
	Viewers.on_event(s, e)
	Observer.observe(s, e)
	Traits.on_event(s, e)
	Sponsors.on_event(s, e)
	Quests.on_event(s, e)
