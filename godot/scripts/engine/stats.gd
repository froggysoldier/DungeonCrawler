class_name Stats
extends RefCounted
## Statistik: Der Dungeon zählt alles mit.


static func stat(s: Dictionary, key: String) -> float:
	var st = s.get("stats")
	if st == null:
		return 0.0
	var v = st.get(key)
	return 0.0 if v == null else float(v)


static func track(s: Dictionary, key: String, amount: float = 1) -> void:
	if s.get("stats") == null:
		s.stats = {}
	s.stats[key] = J.num(s.stats, key) + amount


static func track_max(s: Dictionary, key: String, value: float) -> void:
	if s.get("stats") == null:
		s.stats = {}
	if value > J.num(s.stats, key):
		s.stats[key] = value


static func _setv(s: Dictionary, key: String, value: float) -> void:
	if s.get("stats") == null:
		s.stats = {}
	s.stats[key] = value


## Womit ein Kill erzielt wurde – für die Technik-Familien.
static func _kill_part(e: Dictionary) -> String:
	if e.get("byAlly"):
		return "party"
	if e.get("byPet"):
		return "haustier"
	for f in J.arr(e, "facets"):
		if String(f).begins_with("t:"):
			return String(f).substr(2)
	var t = e.get("technique")
	return t.part if t != null else "sonstiges"


static func _on_kill(s: Dictionary, e: Dictionary) -> void:
	var m: Dictionary = e.monster
	var p: Dictionary = s.player
	var t = e.get("technique")
	track(s, "kills")
	track(s, "kills.art.%s" % m.defId)
	if stat(s, "kills.art.%s" % m.defId) == 1:
		track(s, "bestiarium.arten")
	track(s, "kills.teil.%s" % _kill_part(e))
	if t != null and not e.get("byPet"):
		if t.move != "normal":
			track(s, "kills.bewegung.%s" % t.move)
		if t.get("zone") and t.zone != "koerper":
			track(s, "kills.zone.%s" % t.zone)
	if m.rank == "elite":
		track(s, "kills.elite")
	if m.rank == "nachbarschaftsboss" or m.rank == "boroughboss":
		track(s, "kills.boss")
	if m.get("asleep"):
		track(s, "kills.schlafend")
	if m.get("fleeing"):
		track(s, "kills.fliehend")
	if m.downed > 0:
		track(s, "kills.liegend")
	if m.get("stunned"):
		track(s, "kills.benommen")
	var diff: int = m.level - p.level
	if diff >= 3:
		track(s, "kills.staerker")
	if diff <= -5:
		track(s, "kills.harmlos")
	if p.hp > 0 and p.hp < Player.max_hp(s) * 0.2:
		track(s, "kills.fasttot")
	if m.defId == "abtruenniger_crawler":
		track(s, "kills.crawler")
	if stat(s, "_konter"):
		track(s, "kills.konter")
	# Art erkannt? Erst dann darf ihr Name in Achievements auftauchen.
	if Identify.monster_insight(s, m) <= 2:
		_setv(s, "bekannt.%s" % m.defId, 1)
	else:
		track(s, "kills.unbekannt")
	if t != null and not e.get("byPet") and not stat(s, "_konter") and stat(s, "_letzterSchaden") >= m.maxHp:
		track(s, "kills.einschlag")
	if MapGen.tile_at(s.map, m.pos.x, m.pos.y) == "dooropen":
		track(s, "kills.tuer")
	if m.size == "riesig":
		track(s, "kills.riesig")
	if t != null and t.part == "wurf" and J.cheb(p.pos, m.pos) >= 5:
		track(s, "kills.weitwurf")
	var facets := J.arr(e, "facets")
	if facets.has("t:bombe") or facets.has("t:falle"):
		_setv(s, "_explosionKills", stat(s, "_explosionKills") + 1 if stat(s, "_explosionZug") == s.turn else 1)
		_setv(s, "_explosionZug", s.turn)
		track_max(s, "max.explosionkills", stat(s, "_explosionKills"))
	var last := stat(s, "_letzterKill")
	_setv(s, "_killserie", stat(s, "_killserie") + 1 if s.turn - last <= 2 and last > 0 else 1)
	_setv(s, "_letzterKill", s.turn)
	track_max(s, "max.killserie", stat(s, "_killserie"))
	_setv(s, "_sauber", stat(s, "_sauber") + 1)
	track_max(s, "max.sauber", stat(s, "_sauber"))
	if e.get("byPet") and not e.get("byAlly"):
		track(s, "haustier.kills")
	_on_kill_moments(s, e, diff)


## Besondere Umstände eines Kills – Grundlage der Moment-Achievements.
static func _on_kill_moments(s: Dictionary, e: Dictionary, diff: int) -> void:
	var m: Dictionary = e.monster
	var p: Dictionary = s.player
	var mh := Player.max_hp(s)
	var own: bool = not e.get("byPet") and not e.get("byAlly")
	var f := J.arr(e, "facets")
	var t = e.get("technique")
	if diff >= 6:
		track(s, "kills.toedlich")
	if m.rank == "elite" and diff >= 3:
		track(s, "kills.elite.staerker")
	if J.arr(m, "zonesHit").filter(func(z): return z != "koerper").size() >= 3:
		track(s, "kills.anatomie")
	if own and t != null and p.ausdauer <= 0:
		track(s, "kills.erschoepft")
	if own and not J.some(p.equipment.values(), func(v): return v != null):
		track(s, "kills.nackt")
	if own and f.has("i:barfuss"):
		track(s, "kills.barfuss")
	if own and f.has("i:bademantel"):
		track(s, "kills.bademantel")
	if own and f.has("i:umzingelt"):
		track(s, "kills.umzingelt")
	if own and f.has("i:angetrunken"):
		track(s, "kills.angetrunken")
	if own and f.has("i:brennend"):
		track(s, "kills.selbstbrennend")
	if own and f.has("i:geblendet"):
		track(s, "kills.geblendet")
	if own and f.has("i:veraengstigt"):
		track(s, "kills.veraengstigt")
	if own and t != null and t.part == "waffe":
		var w = Player.current_weapon(s)
		if w != null:
			track(s, "kills.waffe.%s" % w.baseId)
	if p.hp > 0 and p.hp < mh * 0.2:
		if e.get("byAlly"):
			track(s, "rettung.party")
		elif e.get("byPet"):
			track(s, "rettung.haustier")
	if m.rank != "nachbarschaftsboss" and m.rank != "boroughboss":
		return
	if p.hp >= mh:
		track(s, "boss.makellos")
	if f.has("t:zauber"):
		track(s, "boss.zauber")
	if f.has("t:falle") or f.has("t:bombe"):
		track(s, "boss.falle")
	if e.get("byAlly"):
		track(s, "boss.party")
	elif e.get("byPet"):
		track(s, "boss.haustier")
	if own and t != null and t.move == "sprung":
		track(s, "boss.sprung")
	if own and t != null and t.get("zone") == "kopf":
		track(s, "boss.kopf")
	if own and t != null and t.move == "anlauf" and p.get("riding"):
		track(s, "boss.gerammt")
	if stat(s, "_konter"):
		track(s, "boss.konter")
	if m.get("asleep"):
		track(s, "boss.schlafend")


static func _threats_near(s: Dictionary, range: int) -> int:
	return s.monsters.filter(func(m): return m.aware and not m.get("fleeing") and m.hp > 0 and J.cheb(m.pos, s.player.pos) <= range).size()


## Ereignisse in Statistik übersetzen (läuft vor den Achievements).
static func on_event(s: Dictionary, e: Dictionary) -> void:
	match e.type:
		"kill":
			_on_kill(s, e)
		"attack":
			_setv(s, "_letzterSchaden", e.damage if e.hit else 0)
			if e.hit:
				track(s, "treffer")
				track(s, "schaden.ausgeteilt", e.damage)
				track_max(s, "max.treffer", e.damage)
				if e.crit:
					track(s, "krits")
			else:
				track(s, "fehlschlaege")
			if e.get("thrown") != null:
				track(s, "wuerfe")
		"damageTaken":
			track(s, "schaden.erlitten", e.amount)
			_setv(s, "_sauber", 0)
			var hp: int = s.player.hp
			if hp > 0 and hp <= Player.max_hp(s) * 0.1:
				track(s, "knapp.ueberlebt")
			if hp == 1:
				track(s, "ueberlebt.einlp")
		"explosion":
			if e.source == "eigener Sprengsatz":
				track(s, "explosion.selbst")
		"potion":
			track(s, "traenke")
			if e.hpBefore > 0 and e.hpBefore < Player.max_hp(s) * 0.1:
				track(s, "traenke.knapp")
		"levelUp":
			_setv(s, "_aufstiege", stat(s, "_aufstiege") + 1 if stat(s, "_aufstiegZug") == s.turn else 1)
			_setv(s, "_aufstiegZug", s.turn)
			track_max(s, "max.aufstiege.zug", stat(s, "_aufstiege"))
			if s.monsters.filter(func(m): return m.hp > 0 and J.cheb(m.pos, s.player.pos) <= 1).size() >= 2:
				track(s, "aufstieg.umzingelt")
		"sleep":
			track(s, "geschlafen")
			_setv(s, "_letzterSchlaf", s.turn)
		"doorClosed":
			track(s, "tueren.geschlossen")
			if J.some(s.monsters, func(m): return m.aware and J.cheb(m.pos, e.pos) <= 3):
				track(s, "tueren.zugeschlagen")
		"dodged":
			track(s, "ausgewichen")
		"enterRoom":
			if e.get("first"):
				track(s, "raeume.entdeckt")
				if e.room.kind == "safe":
					track(s, "saferooms.entdeckt")
			if e.room.kind == "safe" and _threats_near(s, 2) > 0:
				track(s, "saferoom.knapp")
			track_max(s, "max.erkundet", explored_pct(s))
		"doorOpened":
			track(s, "tueren.geoeffnet")
		"pickup":
			track(s, "gegenstaende.aufgehoben")
			track(s, "fund.%s" % e.item.rarity)
		"boxOpened":
			track(s, "boxen.geoeffnet")
			if e.item.get("box") != null:
				track(s, "boxen.stufe.%s" % e.item.box.tier)
		"bought":
			track(s, "gekauft")
			track(s, "gold.ausgegeben", e.price)
			var pos: Dictionary = s.player.pos
			var room = J.find(s.map.rooms, func(r): return pos.x >= r.x and pos.x < r.x + r.w and pos.y >= r.y and pos.y < r.y + r.h)
			if room != null and room.get("shop") != null and room.shop.offers.is_empty():
				track(s, "laden.leergekauft")
		"sold":
			track(s, "verkauft")
		"haggle":
			if e.success:
				track(s, "feilschen.gewonnen")
				if e.percent >= 25:
					track(s, "feilschen.maximal")
				_setv(s, "_feilschpleiten", 0)
			else:
				_setv(s, "_feilschpleiten", stat(s, "_feilschpleiten") + 1)
				track_max(s, "max.feilschpleiten", stat(s, "_feilschpleiten"))
		"lottery":
			track(s, "lose")
			if e.outcome == "niete":
				track(s, "lose.nieten")
			if e.outcome == "jackpot":
				track(s, "lose.jackpot")
		"relief":
			track(s, "toilette")
			if _threats_near(s, 5) > 0:
				track(s, "toilette.imkampf")
		"accident":
			track(s, "unfall")
		"conditioned":
			track(s, "zustand.erlitten")
			track(s, "zustand.erlitten.%s" % e.condition)
		"eat":
			track(s, "gegessen")
			if _threats_near(s, 2) > 0:
				track(s, "essen.imkampf")
		"goldGained":
			track_max(s, "max.gold", s.player.gold)
		"questFailed":
			track(s, "auftraege.verpatzt")
		"trapPlaced":
			track(s, "fallen.aufgestellt")
		"crafted":
			track(s, "hergestellt.%s" % e.recipe)
		"crateSmashed":
			track(s, "kisten")
		"secretFound":
			track(s, "geheimtueren")
		"lockPicked":
			track(s, "schloesser")
		"treasureFound":
			track(s, "schatzkammern")
		"nestCleared":
			track(s, "nester")
		"prayed":
			track(s, "gebete")
		"ambush":
			track(s, "hinterhalte")
		"bossDodged":
			track(s, "boss.ausgewichen")
		"chainDone":
			track(s, "ketten")
		"spellCast":
			track(s, "zauber.gewirkt")
			track(s, "zauber.%s" % e.spell)
		"crawlerMet":
			track(s, "crawler.getroffen")
		"partyJoined":
			track(s, "party.beigetreten")
		"crawlerDied":
			if e.party:
				track(s, "party.verloren")
		"questDone":
			track(s, "auftraege.erledigt")
		"sponsorWish":
			track(s, "sponsor.wuensche")
		"rammed":
			track(s, "reittier.rammen")
			if e.kill:
				track(s, "reittier.kills")
		"talkShow":
			track(s, "talkshows")
		"moved":
			if s.player.get("riding"):
				track(s, "reittier.schritte")
			track_max(s, "max.wach", s.turn - stat(s, "_letzterSchlaf"))
		"descend":
			track_max(s, "max.erkundet", explored_pct(s))


## Wie viel Prozent der begehbaren Fläche dieser Etage schon entdeckt sind.
static func explored_pct(s: Dictionary) -> int:
	var open := 0
	var seen := 0
	var t: Array = s.map.tiles
	var ex: Array = s.map.explored
	for i in t.size():
		if t[i] == "wall":
			continue
		open += 1
		if ex[i]:
			seen += 1
	return floori((100.0 * seen) / open) if open else 0
