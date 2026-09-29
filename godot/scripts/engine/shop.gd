class_name Shop
extends RefCounted
## Läden in Safe Rooms und Wanderhändler mit eigenem Sortiment.

const KEEPERS := [
	"Pimbo, ein Gnom mit Monokel", "Frau Krätzig, eine Echsendame mit Lesebrille", "Oskar, ein sehr kleiner Oger",
	"Madame Zunder, eine Feuerfee", "Herr Kolbe, ein Pilzmensch mit Krawatte", "Brakka, eine Kobold-Kauffrau",
]
const SELL_FACTOR := 0.4
const MAX_DISCOUNT := 0.25


static func _base_price(it: Dictionary) -> int:
	var w = it.get("wert")
	return maxi(2, J.rnd((w if w else 3) * 2.2))


static func ensure_shop(s: Dictionary, room: Dictionary) -> Dictionary:
	if room.get("shop") != null:
		return room.shop
	if room.get("feature") == "markt":
		return _ensure_wander(s, room)
	var offers := [
		Items.create_item(s, "kleiner_heiltrank", 2),
		Items.create_item(s, "heiltrank"),
		Items.create_item(s, "kleiner_manatrank", 2),
		Items.create_item(s, "gegengift"),
		Items.create_item(s, "rubbellos", 3),
		Items.create_item(s, R.pick(s, ["stein", "ziegel", "dartpfeil", "bowlingkugel"]), 5),
		Items.generate_equipment(s, "ungewoehnlich"),
		Items.generate_equipment(s, "selten" if R.chance(s, 0.3) else "ungewoehnlich"),
	]
	if R.chance(s, 0.4):
		offers.append(Magic.random_tome(s, "selten" if s.floor >= 2 else "ungewoehnlich"))
	if R.chance(s, 0.15):
		offers.append(Items.create_item(s, R.pick(s, ["tattoo_kobold", "tattoo_ratte", "talisman_flug", "talisman_insekt"])))
	if R.chance(s, 0.08):
		offers.append(Items.create_item(s, "ei_raptor"))
	if R.chance(s, 0.12 + s.floor * 0.04):
		offers.append(Items.create_item(s, R.pick(s, ["zuendschluessel_wagen", "pfeife_pony", "zuendschluessel_bobbycar", "pfeife_schnecke"])))
	if R.chance(s, 0.5):
		offers.append(Items.create_item(s, "benzinkanister", 2))
	room.shop = {
		"keeper": R.pick(s, KEEPERS),
		"offers": offers.map(func(item): return {"item": item, "price": _base_price(item)}),
		"mood": 100,
	}
	return room.shop


## Wanderhändler: Waffen, Apotheke, Schrott oder Kuriositäten (data/world.json, WANDER_SHOPS).
static func _ensure_wander(s: Dictionary, room: Dictionary) -> Dictionary:
	var shops: Array = Db.world("WANDER_SHOPS")
	var fixed = room.get("shopType")
	var def: Dictionary = J.find(shops, func(x): return x.id == fixed) if fixed != null else R.pick(s, shops)
	var offers := []
	for entry in R.shuffle(s, def.items.duplicate()).slice(0, int(def.pick)):
		offers.append(Items.create_item(s, entry[0], int(entry[1])))
	var eq: Dictionary = def.equipment
	for i in eq.rarities.size():
		var slot = [eq.slots[i]] if i < eq.slots.size() else null
		offers.append(Items.generate_equipment(s, eq.rarities[i], slot))
	if R.chance(s, float(def.tomeChance)):
		offers.append(Magic.random_tome(s, "selten" if s.floor >= 2 else "ungewoehnlich"))
	room.shop = {
		"keeper": R.pick(s, def.keepers),
		"type": def.id,
		"title": def.title,
		"greeting": def.greeting,
		# Wanderhändler sind etwas teurer: Sie tragen alles selbst
		"offers": offers.map(func(item): return {"item": item, "price": J.rnd(_base_price(item) * 1.15)}),
		"mood": 100,
	}
	return room.shop


static func _buy_factor(s: Variant) -> float:
	if s == null:
		return 1.0
	return (0.85 if Abilities.has_special(s, "haendler") else 1.0) * (0.9 if Abilities.has_special(s, "systemkenntnis") else 1.0)


static func offer_price(price: float, it: Dictionary, s: Variant = null) -> int:
	return maxi(1, J.rnd(price * _buy_factor(s))) * (int(J.nn(it, "menge", 1)) if Items.is_stackable(it.kind) else 1)


static func sell_price(it: Dictionary, s: Variant = null) -> int:
	var bonus := 1.0
	if s != null:
		bonus = (1 + Player.skill_level(s, "feilschen") * 0.02) * (1.2 if Abilities.has_special(s, "haendler") else 1.0)
	var w = it.get("wert")
	var each := maxi(1, J.rnd((w if w else 1) * SELL_FACTOR * bonus))
	return each * (int(J.nn(it, "menge", 1)) if Items.is_stackable(it.kind) else 1)


static func buy(s: Dictionary, room: Dictionary, index: int) -> Dictionary:
	var shop := ensure_shop(s, room)
	if index < 0 or index >= shop.offers.size():
		return {"ok": false, "message": "Dieses Angebot gibt es nicht mehr."}
	var offer: Dictionary = shop.offers[index]
	var total := offer_price(offer.price, offer.item, s)
	if s.player.gold < total:
		return {"ok": false, "message": "Zu teuer. Das kostet %d Gold, du hast %d." % [total, s.player.gold]}
	s.player.gold -= total
	shop.offers.remove_at(index)
	Inventory.give_item(s, offer.item)
	Log.add(s, "Gekauft: %s für %d Gold." % [Identify.item_name(s, offer.item), total], "loot")
	Events.emit(s, {"type": "bought", "item": offer.item, "price": total, "haggled": not not offer.get("haggled")})
	return {"ok": true}


static func sell(s: Dictionary, uid: String) -> Dictionary:
	var p: Dictionary = s.player
	var it = J.find(p.inventory, func(i): return i.uid == uid)
	if it == null:
		return {"ok": false, "message": "Das hast du nicht."}
	if it.kind == "box":
		return {"ok": false, "message": "Lootboxen kann man nicht verkaufen."}
	if it.get("questId"):
		return {"ok": false, "message": "Das gehört jemandem, der darauf wartet."}
	var price := sell_price(it, s)
	p.inventory = p.inventory.filter(func(i): return i.uid != uid)
	p.gold += price
	s.counters.goldEarned += price
	Log.add(s, "Verkauft: %s für %d Gold." % [Identify.item_name(s, it), price], "loot")
	Events.emit(s, {"type": "sold", "item": it, "price": price})
	return {"ok": true}


static func haggle(s: Dictionary, room: Dictionary, index: int) -> Dictionary:
	var shop := ensure_shop(s, room)
	if index < 0 or index >= shop.offers.size():
		return {"ok": false, "message": "Dieses Angebot gibt es nicht mehr."}
	var offer: Dictionary = shop.offers[index]
	if offer.get("haggled"):
		return {"ok": false, "message": "Über diesen Preis wurde schon verhandelt."}
	offer.haggled = true
	var cha: float = Player.effective_stats(s).cha
	var haggler := Player.skill_level(s, "feilschen")
	var chance := maxf(0.1, minf(0.92, 0.3 + (cha - 5) * 0.05 + (shop.mood - 100) / 200.0 + haggler * 0.04))
	var base := _base_price(offer.item)
	if R.next(s) < chance:
		var pct := J.rnd(5 + R.next(s) * 20 * minf(1.5, cha / 10.0))
		var discount: int = mini(int(MAX_DISCOUNT * 100) + haggler, pct + floori(haggler / 2.0))
		offer.price = maxi(1, J.rnd(base * (1 - discount / 100.0)))
		Log.add(s, "Du verhandelst geschickt. %s seufzt und gibt %d %% Rabatt." % [shop.keeper, discount], "dialog")
		Events.emit(s, {"type": "haggle", "success": true, "percent": discount})
	else:
		offer.price = J.rnd(base * 1.1)
		shop.mood = maxi(0, shop.mood - 15)
		Log.add(s, "%s ist beleidigt. „Jetzt kostet es eben mehr.“ (+10 %%)" % shop.keeper, "dialog")
		Events.emit(s, {"type": "haggle", "success": false, "percent": 0})
	return {"ok": true}
