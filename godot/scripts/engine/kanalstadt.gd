class_name Kanalstadt
extends RefCounted
## Etage 3, die Kanalstadt:
##   Kanäle     tiefe Wasserläufe quer über die Karte (nicht begehbar, aber
##              durchsichtig); wo ein Gang kreuzt, liegt eine Brücke, in
##              normalen Räumen wird der Kanal zu seichtem Wasser
##   Siedlung   drei Räume nahe der Mitte: Märkte mit verschiedenen Händlern
##              und Bewohner, die dort bleiben; Monster gehen nicht hinein

const CANAL := "kanal"
const BRIDGE := "bruecke"
const FLOOR_NO := 3

const MARKET_TYPES := ["apotheke", "waffen", "schrott", "kurio"]
const MARKET_NAMES := {
	"apotheke": ["Pumpwerk-Apotheke", "In einem stillgelegten Pumpwerk riecht es nach Kräutern und Desinfektionsmittel. Zwischen den Kolben hängen getrocknete Pilze."],
	"waffen": ["Waffenmarkt am Wehr", "Auf Paletten liegen Klingen, Keulen und Dinge, die mal Werkzeug waren. Das Wasser des Wehrs rauscht so laut, dass man flüstern kann, ohne dass es jemand hört."],
	"schrott": ["Schrottplatz unter der Brücke", "Berge aus Rohren, Kabeln und Blech. Jemand hat Ordnung hineingebracht, aber nur er versteht sie."],
	"kurio": ["Kuriositätenkabinett", "Ein Raum voller Vitrinen aus Einmachgläsern. In manchen schwimmt etwas. In manchen bewegt sich etwas."],
}
const RESIDENTS := [
	["Tante Pütz", "Flickschneiderin"], ["Hektor Schlamm", "Fährmann"], ["Nelli Rostig", "Rohrflickerin"],
	["Opa Gluck", "Laternenanzünder"], ["Mira Moosbach", "Pilzsammlerin"], ["Bert Kiesel", "Brückenwärter"],
]


static func is_canal(t: String) -> bool:
	return t == CANAL


# ================================================================ Erzeugen

## Felder, die Kanäle nicht anrühren: besondere Räume samt Rand, Treppen, Türen.
static func _protected(m: Dictionary) -> Dictionary:
	var out := {}
	for r in m.rooms:
		var special: bool = r.kind != "normal" or r.get("sealed") or r.get("antechamberOf") != null or r.get("feature") != null
		if not special:
			continue
		for y in range(r.y - 2, r.y + r.h + 2):
			for x in range(r.x - 2, r.x + r.w + 2):
				if MapGen.in_bounds(m, x, y):
					out[MapGen.idx(m, x, y)] = true
	for i in m.tiles.size():
		if m.tiles[i] == "stairs" or m.tiles[i] == "door" or m.tiles[i] == "dooropen":
			out[i] = true
	return out


static func _carve(m: Dictionary, i: int, protected: Dictionary) -> void:
	if protected.has(i):
		return
	var t: String = m.tiles[i]
	var r: int = m.roomAt[i]
	if t == "wall":
		m.tiles[i] = CANAL
	elif r == -1 and (t == "floor" or t == Dungeon.MUD):
		m.tiles[i] = BRIDGE
	elif r >= 0 and (t == "floor" or t == Dungeon.MUD):
		m.tiles[i] = Dungeon.WATER


## Nach Dungeon.shape: Kanäle ziehen (nur Etage 3).
static func shape(s: Dictionary, m: Dictionary) -> void:
	var protected := _protected(m)
	var w: int = m.width
	var h: int = m.height
	# Zwei waagerechte und ein senkrechter Kanal, je zwei Felder breit
	var rows := [R.int_(s, 9, 17), R.int_(s, 33, 41)]
	var col := R.int_(s, 20, 50)
	for y0 in rows:
		for y in [y0, y0 + 1]:
			for x in range(1, w - 1):
				_carve(m, y * w + x, protected)
	for x in [col, col + 1]:
		for y in range(1, h - 1):
			_carve(m, y * w + x, protected)
	m.canals = {"rows": rows, "col": col}


## Nach den Bewohnern: Siedlung einrichten (Märkte, Bewohner, keine Monster).
static func populate(s: Dictionary, m: Dictionary, monsters: Array, occupied: Dictionary) -> void:
	var mid := J.pos(int(m.width / 2), int(m.height / 2))
	var cands: Array = m.rooms.filter(func(r):
		if r.kind != "normal" or r.get("feature") != null or r.get("sealed") or r.get("antechamberOf") != null or r.w * r.h < 16:
			return false
		for y in range(r.y, r.y + r.h):
			for x in range(r.x, r.x + r.w):
				if m.tiles[MapGen.idx(m, x, y)] == "stairs":
					return false
		return true)
	if cands.is_empty():
		return
	J.sort(cands, func(a, b): return MapGen.dist(MapGen.center(a), mid) - MapGen.dist(MapGen.center(b), mid))
	var core: Dictionary = cands[0]
	J.sort(cands, func(a, b): return MapGen.dist(MapGen.center(a), MapGen.center(core)) - MapGen.dist(MapGen.center(b), MapGen.center(core)))
	var town: Array = cands.slice(0, 3)
	var types: Array = R.shuffle(s, MARKET_TYPES.duplicate())
	m.residents = []
	var people: Array = R.shuffle(s, RESIDENTS.duplicate())
	for i in town.size():
		var r: Dictionary = town[i]
		var kind: String = types[i]
		r.siedlung = true
		r.feature = "markt"
		r.shopType = kind
		r.name = MARKET_NAMES[kind][0]
		r.description = MARKET_NAMES[kind][1] + " Hier leben Leute. Monster trauen sich nicht herein."
		var spot = Dungeon._free_spot(s, m, r, occupied)
		if spot != null:
			r.furniture = [{"kind": "haendler", "pos": spot}]
		for k in 2 if i == 0 else 1:
			var p = MapGen._random_floor_in(s, m, r, occupied)
			if p != null and not people.is_empty():
				var who: Array = people.pop_front()
				m.residents.append({"pos": p, "name": who[0], "background": who[1], "room": r.id})
	# In der Siedlung wohnen keine Monster
	monsters.assign(monsters.filter(func(mo):
		var ro = MapGen.room_of(m, mo.pos)
		return ro == null or not ro.get("siedlung")))


## Beim Betreten der Etage: die Bewohner der Siedlung als Crawler hinzufügen.
static func add_residents(s: Dictionary) -> void:
	for rd in J.arr(s.map, "residents"):
		var c := Crawlers.make_crawler(s, rd.pos, "freundlich")
		c.name = rd.name
		c.background = rd.background
		c.resident = true
		c.home = rd.room
		c.level = maxi(c.level, 8)
		Crawlers.crawlers(s).append(c)


static func is_town(s: Dictionary, p: Dictionary) -> bool:
	var r = MapGen.room_of(s.map, p)
	return r != null and r.get("siedlung", false)
