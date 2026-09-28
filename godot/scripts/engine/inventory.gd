class_name Inventory
extends RefCounted
## Inventar.


static func add_to_inventory(s: Dictionary, item: Dictionary) -> void:
	if Items.is_stackable(item.kind):
		var same = J.find(s.player.inventory, func(i): return i.baseId == item.baseId and i.rarity == item.rarity and i.name == item.name)
		if same != null:
			same.menge = int(J.nn(same, "menge", 1)) + int(J.nn(item, "menge", 1))
			return
	s.player.inventory.append(item)


static func gain_gold(s: Dictionary, amount: int) -> void:
	var bonus := J.rnd(amount * 0.5) if Abilities.has_special(s, "goldmagnet") else 0
	s.player.gold += amount + bonus
	s.counters.goldEarned += amount + bonus
	if bonus:
		Log.add(s, "Der Goldmagnet zieht %d Extra-Gold an." % bonus, "loot")
	Events.emit(s, {"type": "goldGained", "amount": amount + bonus})


## Gibt dem Crawler ein Item: Inventar, oder vor dem Tutorial in die Hand.
static func give_item(s: Dictionary, item: Dictionary) -> void:
	var p: Dictionary = s.player
	if item.kind == "gold":
		gain_gold(s, int(J.nn(item, "menge", 0)))
		return
	if item.kind == "box":
		p.boxes.append(item)
		return
	if s.unlocks.has("inventar"):
		add_to_inventory(s, item)
		return
	if p.hand == null:
		p.hand = item
		return
	s.items.append({"pos": J.pcopy(p.pos), "item": item})
	Log.add(s, "Deine Hände sind voll. %s fällt zu Boden." % item.name, "info")
