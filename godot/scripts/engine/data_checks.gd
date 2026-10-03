class_name DataChecks
extends RefCounted
## Bedingungen, die sich nicht als JSON ausdrücken lassen: Achievements,
## Rassen- und Klassenvoraussetzungen, Klassenbewertung, Überwinden von
## Ängsten, Talkshow-Fragen. Die Einträge in data/*.json verweisen per id
## hierher: Wer ein neues Achievement (oder eine Klasse, Rasse …) anlegt,
## trägt hier die Bedingung ein.

const UNDEAD := ["ghul", "moorleiche", "knochenratte", "kellermeister", "ghulhund"]
const FLYERS := ["fledermaus", "poltergeist", "irrlicht", "grey_drohne", "nachtmahr", "mottenmann", "taubenschwarm"]
const MIMICS := ["muellsack_mimic", "toaster_mimic", "waschmaschine_mimic"]
const UNARMED := ["faust", "tritt", "knie", "ellbogen", "kopf"]
const RATS := ["kellerratte", "rattenmensch", "rattenschamane", "knochenratte"]

const BOSS_ACH := {
	"b_sammlerin": "die_sammlerin", "b_hausmeister": "der_hausmeister", "b_rattenkoenig": "koenig_kanalratte",
	"b_mixer": "muttis_mixer", "b_kammerjaeger": "kammerjaeger", "b_motten": "mottenmutter", "b_pfand": "pfandbaron",
	"b_heizung": "heizungsbestie", "b_verwalter": "hausverwalter", "b_kanalkoenigin": "kanalkoenigin",
	"b_schlamm": "kommandant_schlamm", "b_oger": "schwarzmarkt_oger", "b_nixe": "nixe", "b_rattenkaiser": "rattenkaiser",
}

## Achievement-ID -> [Ereignistypen (leer = alle), Callable(e, s) -> bool]
static var _table := {}
## Reihenfolge wie ACHIEVEMENTS: Liste von [def, typen, prüfung]
static var _ordered := []


# ================================================================ Hilfen

static func _st(s: Dictionary, key: String) -> float:
	return Stats.stat(s, key)


static func _killed(s: Dictionary, ids: Array) -> float:
	var sum := 0.0
	for id in ids:
		sum += J.num(s.counters.killsByDef, id)
	return sum


static func _kill(e: Dictionary) -> Variant:
	return e.monster if e.type == "kill" else null


## Ganz allein: keine Party, kein Haustier auf den Beinen, nicht beritten,
## und der letzte Treffer kam von dir.
static func _alone(s: Dictionary, e: Dictionary) -> bool:
	var pet = s.player.get("pet")
	return Crawlers.party(s).is_empty() and (pet == null or not pet.alive) and not s.player.get("riding", false) and not e.get("byPet") and not e.get("byAlly")


## Nichts angelegt außer Unterwäsche, keine Waffe in der Hand.
static func _naked(s: Dictionary) -> bool:
	for slot in s.player.equipment:
		if slot != "unterwaesche" and s.player.equipment[slot] != null:
			return false
	return Player.current_weapon(s) == null


## Etage nach mindestens drei Vierteln der Zeit verlassen, ohne Trank und ohne Schlaf.
static func _no_safety_net(s: Dictionary) -> bool:
	var st = s.get("floorStart")
	if st == null:
		return false
	var dur := float(Db.floor_def0(int(s.floor)).duration)
	return s.turn - s.floorStartTurn >= dur * 0.75 and s.counters.potionsDrunk == int(st.potions) and s.counters.sleeps == int(st.sleeps)


## Alle Nachbarschaftsbosse der Etage tot, bevor ein Drittel der Zeit um ist.
static func _all_hood_bosses_fast(s: Dictionary) -> bool:
	var dur := float(Db.floor_def0(int(s.floor)).duration)
	return s.turn - s.floorStartTurn <= dur / 3.0 and J.every(s.map.hoods, func(h): return not h.bossAlive)


static func _kill_of(e: Dictionary, id: String) -> bool:
	var m = _kill(e)
	return m != null and m.defId == id


static func _part_kills(s: Dictionary, part: String) -> float:
	var sum := 0.0
	for k in s.player.techniqueKills:
		if String(k).begins_with(part + "+"):
			sum += s.player.techniqueKills[k]
	return sum


static func _move_kills(s: Dictionary, move: String) -> float:
	var sum := 0.0
	for k in s.player.techniqueKills:
		if String(k).ends_with("+" + move):
			sum += s.player.techniqueKills[k]
	return sum


static func _equipped(s: Dictionary) -> Array:
	return s.player.equipment.values().filter(func(i): return i != null)


static func _wears(s: Dictionary, base_id: String) -> bool:
	return J.some(_equipped(s), func(i): return i.baseId == base_id)


static func _weapon_id(s: Dictionary) -> Variant:
	var w = s.player.equipment.get("waffe")
	if w != null:
		return w.baseId
	var h = s.player.hand
	if h != null and h.get("slot") == "waffe":
		return h.baseId
	return null


static func _is_boss(m: Dictionary) -> bool:
	return m.rank == "nachbarschaftsboss" or m.rank == "boroughboss"


static func _weapon_kill(e: Dictionary, s: Dictionary, id: String) -> bool:
	return e.type == "kill" and _tech(e, "part") == "waffe" and _weapon_id(s) == id


static func _got_item(e: Dictionary, rarities: Array) -> bool:
	if e.type == "boxOpened":
		return J.some(e.contents, func(c): return rarities.has(c.rarity))
	if e.type == "pickup":
		return rarities.has(e.item.rarity)
	return false


## e.technique?.feld (null, wenn es keine Technik gibt)
static func _tech(e: Dictionary, field: String) -> Variant:
	var t = e.get("technique")
	return t.get(field) if t != null else null


static func _has_equipped(s: Dictionary) -> int:
	return s.player.equipment.size()


static func _flag(s: Dictionary, f: String) -> int:
	return 1 if s.player.flags.has(f) else 0


static func _trait(s: Dictionary, t: String) -> int:
	return 1 if J.arr(s.player, "traits").has(t) else 0


static func _stat_v(s: Dictionary, k: String) -> float:
	return float(s.player.stats[k])


static func _trig(s: Dictionary, t: String) -> float:
	return J.num(s.player.techniqueUses, "_" + t)


static func _uses(s: Dictionary, pred: Callable) -> float:
	var sum := 0.0
	for k in s.player.techniqueUses:
		var key := String(k)
		if not key.begins_with("_") and pred.call(key):
			sum += s.player.techniqueUses[k]
	return sum


static func _part_uses(s: Dictionary, p: String) -> float:
	return _uses(s, func(k): return k.begins_with(p + "+"))


static func _move_uses(s: Dictionary, m: String) -> float:
	return _uses(s, func(k): return k.ends_with("+" + m))


static func _spells(s: Dictionary) -> int:
	return J.arr(s.player, "spells").size()


# ================================================================ Achievements

static func _add(id: String, types: Array, fn: Callable) -> void:
	_table[id] = [types, fn]


static func _build() -> void:
	if not _table.is_empty():
		return
	var K := ["kill"]
	# ------------------------------------------------ data/achievements.json
	_add("willkommen", ["start"], func(e, s): return true)
	_add("katzenlady", ["start"], func(e, s): return s.player.pet != null and s.player.pet.species == "Katze")
	_add("hundemensch", ["start"], func(e, s): return s.player.pet != null and s.player.pet.species == "Hund")
	_add("bademantel", ["start"], func(e, s): return s.player.equipment.get("brust") != null and s.player.equipment.brust.baseId == "bademantel")
	_add("erstes_blut", K, func(e, s): return s.counters.kills == 1)
	_add("zehn_kills", K, func(e, s): return s.counters.kills == 10)
	_add("fuenfzig_kills", K, func(e, s): return s.counters.kills == 50)
	_add("rattenfaenger", K, func(e, s): return J.num(s.counters.killsByDef, "kellerratte") + J.num(s.counters.killsByDef, "rattenmensch") == 20)
	_add("david", K, func(e, s): return e.monster.level >= s.player.level + 3)
	_add("multitasker", K, func(e, s): return J.uniq(J.arr(e.monster, "hitBy")).size() >= 4)
	_add("ruepel", K, func(e, s): return not not e.monster.get("fleeing"))
	_add("hinterhalt", K, func(e, s): return not e.monster.aware and J.arr(e.monster, "hitBy").size() <= 1)
	_add("knapp_daneben", ["attack"], func(e, s): return not e.hit and s.counters.missStreak == 5)
	_add("sandsack", ["damageTaken"], func(e, s): return s.counters.hitTakenStreak == 8)
	_add("haaresbreite", ["damageTaken"], func(e, s): return s.player.hp > 0 and s.player.hp <= 2)
	_add("crit", ["attack"], func(e, s): return e.crit)
	_add("overkill", ["attack"], func(e, s): return e.damage >= 25)
	_add("faust10", K, func(e, s): return _part_kills(s, "faust") == 10)
	_add("tritt10", K, func(e, s): return _part_kills(s, "tritt") == 10)
	_add("stampf1", K, func(e, s): return _tech(e, "move") == "stampfen")
	_add("stampf15", K, func(e, s): return _move_kills(s, "stampfen") == 15)
	_add("kopf1", K, func(e, s): return _tech(e, "part") == "kopf")
	_add("stein1", K, func(e, s): return _tech(e, "part") == "wurf")
	_add("wurf25", ["attack"], func(e, s): return e.technique.part == "wurf" and s.counters.throws == 25)
	_add("sprung5", K, func(e, s): return _move_kills(s, "sprung") == 5)
	_add("meteor", K, func(e, s): return _tech(e, "part") == "tritt" and e.technique.move == "sprung")
	_add("ellbogen10", K, func(e, s): return _part_kills(s, "ellbogen") == 10)
	_add("knie10", K, func(e, s): return _part_kills(s, "knie") == 10)
	_add("waffe1", K, func(e, s): return _tech(e, "part") == "waffe")
	_add("anlauf1", K, func(e, s): return _tech(e, "move") == "anlauf")
	_add("nackter_boss", K, func(e, s): return e.monster.rank != "normal" and e.monster.rank != "elite" and _has_equipped(s) == 0)
	_add("elite1", K, func(e, s): return e.monster.rank == "elite")
	_add("hoodboss1", K, func(e, s): return e.monster.rank == "nachbarschaftsboss")
	_add("hoodboss4", K, func(e, s): return e.monster.rank == "nachbarschaftsboss" and J.every(s.map.hoods, func(h): return not h.bossAlive))
	_add("boroughboss", K, func(e, s): return e.monster.rank == "boroughboss")
	_add("lebensmuede", K, func(e, s): return e.monster.rank != "normal" and e.monster.rank != "elite" and e.monster.level >= s.player.level + 5)
	_add("kartograph", ["mapPicked"], func(e, s): return true)
	_add("treppe", ["stairsFound"], func(e, s): return true)
	_add("safe1", ["enterRoom"], func(e, s): return e.room.kind == "safe")
	_add("gilde", ["tutorialDone"], func(e, s): return true)
	_add("pazifist", ["tutorialDone"], func(e, s): return s.counters.kills == 0)
	_add("wanderer", ["moved"], func(e, s): return s.counters.steps == 1000)
	_add("klepto", ["pickup"], func(e, s): return s.counters.itemsPicked == 20)
	_add("unboxing", ["boxOpened"], func(e, s): return s.counters.boxesOpened == 1)
	_add("unboxing10", ["boxOpened"], func(e, s): return s.counters.boxesOpened == 10)
	_add("modeopfer", ["equip"], func(e, s): return _has_equipped(s) == 8)
	_add("feinschmecker", ["eat"], func(e, s): return String(e.item.baseId).begins_with("menue_"))
	_add("schlafmuetze", ["sleep"], func(e, s): return true)
	_add("level5", ["levelUp"], func(e, s): return e.level == 5)
	_add("skill1", ["skillLearned"], func(e, s): return true)
	_add("skill5", ["skillUp"], func(e, s): return e.level == 5)
	_add("haustier_kill", K, func(e, s): return not not e.get("byPet"))
	_add("zweite_chance", ["revived"], func(e, s): return true)
	_add("geist", K, func(e, s): return e.monster.rank == "geist")
	_add("fruehaufsteher", ["descend"], func(e, s): return s.turn - s.floorStartTurn <= 480)
	_add("last_minute", ["descend"], func(e, s): return s.collapseAt - s.turn <= 20)
	_add("absteiger", ["descend"], func(e, s): return true)
	# ------------------------------------------------ Meisterleistungen (Box über der Etagengrenze)
	_add("meister_einzelkaempfer", K, func(e, s): return e.monster.rank == "boroughboss" and _alone(s, e))
	_add("meister_faustrecht", K, func(e, s): return e.monster.rank == "boroughboss" and not e.get("byPet") and not e.get("byAlly") and J.arr(e.monster, "hitBy") == ["faust"])
	_add("meister_gewaltfrei", ["descend"], func(e, s): return int(e.floor) == 2 and s.counters.kills == 0)
	_add("meister_ohne_netz", ["descend"], func(e, s): return _no_safety_net(s))
	_add("meister_unberuehrbar", K, func(e, s): return e.monster.rank == "nachbarschaftsboss" and not e.monster.get("hitPlayer", false))
	_add("meister_adamskostuem", K, func(e, s): return (e.monster.rank == "nachbarschaftsboss" or e.monster.rank == "boroughboss") and _naked(s))
	_add("meister_blitzsaeuberung", K, func(e, s): return e.monster.rank == "nachbarschaftsboss" and _all_hood_bosses_fast(s))
	# ------------------------------------------------ Bestiarium, Bosse, Technik, Beute, Fortschritt
	_add("spinnen", K, func(e, s): return _kill_of(e, "kellerspinne") and _killed(s, ["kellerspinne"]) == 5)
	_add("fledermaus", K, func(e, s): return FLYERS.has(e.monster.defId) and _killed(s, FLYERS) == 10)
	_add("kroete_fern", K, func(e, s): return _kill_of(e, "blaehkroete") and _tech(e, "part") == "wurf")
	_add("knall", ["explosion"], func(e, s): return true)
	_add("bestohlen", ["robbed"], func(e, s): return true)
	_add("rache", K, func(e, s): return not not e.monster.get("stolenGold"))
	_add("pleite", ["robbed"], func(e, s): return s.player.gold == 0)
	_add("vergiftet", ["poisoned"], func(e, s): return true)
	_add("geheilt", ["cured"], func(e, s): return true)
	_add("giftschlucker", ["damageTaken"], func(e, s): return s.counters.poisonDamage >= 30)
	_add("zwerge", K, func(e, s): return _kill_of(e, "gartenzwerg") and _killed(s, ["gartenzwerg"]) == 5)
	_add("heinzel", K, func(e, s): return _kill_of(e, "heinzelmann"))
	_add("kryptozoologe", K, func(e, s): return J.every(["wolpertinger", "tatzelwurm", "chupacabra"], func(id): return J.num(s.counters.killsByDef, id) > 0))
	_add("erstkontakt", K, func(e, s): return _kill_of(e, "grauer_spaeher") or _kill_of(e, "grey_drohne"))
	_add("mimic", K, func(e, s): return MIMICS.has(e.monster.defId))
	_add("toaster", K, func(e, s): return _kill_of(e, "toaster_mimic"))
	_add("friedhof", K, func(e, s): return UNDEAD.has(e.monster.defId) and _killed(s, UNDEAD) == 10)
	_add("verstaerkung", K, func(e, s): return J.num(e.monster, "summoned") > 0)
	_add("dosenoeffner", K, func(e, s): return J.arr(e.monster, "abilities").has("gepanzert") and _tech(e, "part") == "tritt")
	_add("elite5", K, func(e, s): return e.monster.rank == "elite" and s.counters.eliteKills == 5)
	_add("hundert", K, func(e, s): return s.counters.kills == 100)
	for aid in BOSS_ACH:
		var boss_id: String = BOSS_ACH[aid]
		_add(aid, K, func(e, s): return _kill_of(e, boss_id))
	_add("boss_haende", K, func(e, s): return _is_boss(e.monster) and e.get("technique") != null and UNARMED.has(e.technique.part))
	_add("boss_stein", K, func(e, s): return _is_boss(e.monster) and _tech(e, "part") == "wurf")
	_add("boss_stampf", K, func(e, s): return _is_boss(e.monster) and _tech(e, "move") == "stampfen")
	_add("weltkarte", ["mapPicked"], func(e, s): return J.every(s.map.hoods, func(h): return h.mapFound))
	_add("kopf10", K, func(e, s): return _tech(e, "part") == "kopf" and _part_kills(s, "kopf") == 10)
	_add("waffe10", K, func(e, s): return _tech(e, "part") == "waffe" and _part_kills(s, "waffe") == 10)
	_add("wurf10", K, func(e, s): return _tech(e, "part") == "wurf" and _part_kills(s, "wurf") == 10)
	_add("anlauf10", K, func(e, s): return _tech(e, "move") == "anlauf" and _move_kills(s, "anlauf") == 10)
	_add("tritt50", K, func(e, s): return _tech(e, "part") == "tritt" and _part_kills(s, "tritt") == 50)
	_add("faust50", K, func(e, s): return _tech(e, "part") == "faust" and _part_kills(s, "faust") == 50)
	_add("allrounder", K, func(e, s): return J.every(["faust", "tritt", "knie", "ellbogen", "kopf", "waffe", "wurf"], func(p): return _part_kills(s, p) > 0))
	_add("krit25", ["attack"], func(e, s): return e.crit and s.counters.crits == 25)
	_add("umgehauen", ["attack"], func(e, s): return s.counters.knockdowns == 15)
	_add("pulverisiert", ["attack"], func(e, s): return e.damage >= 50)
	_add("letzte_kraft", K, func(e, s): return s.player.hp <= 5 and J.some(s.player.buffs, func(b): return b.name == "Vergiftet"))
	_add("klobuerste", K, func(e, s): return _weapon_kill(e, s, "klobuerste"))
	_add("selfie", K, func(e, s): return _weapon_kill(e, s, "selfiestick"))
	_add("baguette", K, func(e, s): return _weapon_kill(e, s, "baguette"))
	_add("bowling", ["attack"], func(e, s): return e.hit and e.get("thrown") != null and e.thrown.baseId == "bowlingkugel")
	_add("fussringe", ["equip"], func(e, s): return s.player.equipment.get("fussring1") != null and s.player.equipment.get("fussring2") != null)
	_add("vierfach", ["equip"], func(e, s): return J.every(["ring1", "ring2", "fussring1", "fussring2"], func(k): return s.player.equipment.get(k) != null))
	_add("komplett", ["equip"], func(e, s): return _equipped(s).size() >= 17)
	_add("crocs", ["equip"], func(e, s): return _wears(s, "crocs"))
	_add("aluhut", ["equip"], func(e, s): return _wears(s, "aluhut"))
	_add("zirkus", ["equip"], func(e, s): return _wears(s, "clownsnase") and _wears(s, "partyhut"))
	_add("stoeckel", K, func(e, s): return _tech(e, "part") == "tritt" and _wears(s, "stoeckelschuhe"))
	_add("legendaer", ["boxOpened", "pickup"], func(e, s): return _got_item(e, ["legendaer", "himmlisch"]))
	_add("himmlisch", ["boxOpened", "pickup"], func(e, s): return _got_item(e, ["himmlisch"]))
	_add("gold100", ["goldGained"], func(e, s): return s.player.gold >= 100)
	_add("gold500", ["goldGained"], func(e, s): return s.counters.goldEarned >= 500)
	_add("drei_gaenge", ["eat"], func(e, s): return s.counters.mealsEaten == 3)
	_add("winterschlaf", ["sleep"], func(e, s): return s.counters.sleeps == 5)
	_add("trankjunkie", [], func(e, s): return e.type != "moved" and s.counters.potionsDrunk == 10)
	_add("boxen25", ["boxOpened"], func(e, s): return s.counters.boxesOpened == 25)
	_add("haustier5", K, func(e, s): return s.player.pet != null and s.player.pet.level >= 5)
	_add("level10", ["levelUp"], func(e, s): return e.level == 10)
	_add("level15", ["levelUp"], func(e, s): return e.level == 15)
	_add("skill10", ["skillUp"], func(e, s): return e.level == 10)
	_add("vielseitig", ["skillLearned"], func(e, s): return s.player.skills.filter(func(k): return not ["erste_hilfe", "kochen", "spielerfahrung"].has(k.id)).size() == 5)
	_add("streber", ["tutorialDone"], func(e, s): return s.turn <= 20)
	_add("anleitung", ["tutorialDone"], func(e, s): return s.player.level >= 4)
	_add("etage3", ["descend"], func(e, s): return e.floor == 3)
	_add("follower100", ["followers"], func(e, s): return e.follower >= 100)
	_add("follower1000", ["followers"], func(e, s): return e.follower >= 1000)
	_add("follower10000", ["followers"], func(e, s): return e.follower >= 10000)
	_add("hype100", ["followers"], func(e, s): return s.viewers.hype >= 100)
	_add("klasse", ["classChosen"], func(e, s): return true)
	_add("mensch", ["classChosen"], func(e, s): return e.race == "mensch")
	_add("exot", ["classChosen"], func(e, s):
		var r = Db.race(e.race)
		return r != null and r.get("requirement") != null)
	_add("faehigkeit", ["abilityUsed"], func(e, s): return true)
	_add("showtime", ["abilityUsed"], func(e, s): return e.ability == "showtime")
	# ------------------------------------------------ Fallen, Handwerk, Soziales, Show, Haustiere, Reittiere
	_add("adlerauge", ["trapDetected"], func(e, s): return true)
	_add("reingetreten", ["trapTriggered"], func(e, s): return e.onPlayer)
	_add("entschaerfer", ["trapDisarmed"], func(e, s): return e.success)
	_add("fallensteller", ["trapTriggered"], func(e, s): return not e.onPlayer)
	_add("bastler", ["crafted"], func(e, s): return true)
	_add("brandstifter", ["crafted"], func(e, s): return e.recipe == "brandflasche" or e.recipe == "nagelbombe")
	_add("bombig", K, func(e, s): return J.arr(e, "facets").has("t:bombe"))
	_add("hallo_nachbar", ["crawlerMet"], func(e, s): return true)
	_add("gemeinsam", ["partyJoined"], func(e, s): return true)
	_add("volles_haus", ["partyJoined"], func(e, s): return e.size >= 4)
	_add("trauer", ["crawlerDied"], func(e, s): return e.party)
	_add("crawler_gegen_crawler", K, func(e, s): return e.monster.defId == "abtruenniger_crawler")
	_add("primetime", ["talkShow"], func(e, s): return true)
	_add("publikumsliebling", ["talkShow"], func(e, s): return e.delta >= 500)
	_add("shitstorm", ["talkShow"], func(e, s): return e.delta < 0)
	_add("sponsor_erster", ["sponsorJoined"], func(e, s): return true)
	_add("sponsor_drei", ["sponsorJoined"], func(e, s): return e.count >= 3)
	_add("sponsor_wunsch", ["sponsorWish"], func(e, s): return true)
	_add("sponsor_weg", ["sponsorDropped"], func(e, s): return true)
	_add("auftrag_erster", ["questDone"], func(e, s): return true)
	_add("auftrag_fuenf", ["questDone"], func(e, s): return e.done >= 5)
	_add("retter", ["questDone"], func(e, s): return e.kind == "retten")
	_add("evolution", ["petEvolved"], func(e, s): return true)
	_add("endform", ["petEvolved"], func(e, s): return e.stage >= 2)
	_add("fahrzeughalter", ["mountGained"], func(e, s): return true)
	_add("ueberrollt", ["rammed"], func(e, s): return e.kill)
	_add("totalschaden", ["mountLost"], func(e, s): return true)
	# ------------------------------------------------ data/achievements_moments.json
	for row in Db.t("achievements_moments", "momentTable"):
		if row.stat != null:
			var key: String = row.stat
			var n: float = row.n
			_add(row.id, [], func(e, s): return _st(s, key) >= n)
	_add("mo_boxen_horten", [], func(e, s): return s.player.boxes.size() >= 10)
	_add("mo_kettenzauber", ["spellCast"], func(e, s): return e.kills >= 3)
	_add("mo_etage2_frueh", ["descend"], func(e, s): return e.floor == 2 and s.player.level <= 3)
	_add("mo_etage3_frueh", ["descend"], func(e, s): return e.floor == 3 and s.player.level <= 6)
	# ------------------------------------------------ data/achievement_families.json
	for fam in Db.t("achievement_families", "familyTable"):
		var value := _family_value(fam)
		for n in fam.stages:
			var limit: float = n
			_add("fam_%s_%s" % [fam.id, J.s(n)], [], func(e, s): return float(value.call(s)) >= limit)
	for m in Db.t("monsters", "MONSTERS"):
		if m.floors.is_empty() or m.weight <= 0:
			continue
		var def_id: String = m.id
		for i in 3:
			var need: int = [1, 10, 30][i]
			_add("art_%s_%d" % [def_id, i + 1], [], func(e, s): return _st(s, "kills.art." + def_id) >= need and _st(s, "bekannt." + def_id) != 0)
	# Reihenfolge wie ACHIEVEMENTS
	for a in Db.t("achievements", "ACHIEVEMENTS"):
		var row = _table.get(a.id)
		if row == null:
			push_error("Achievement ohne Bedingung: %s" % a.id)
			continue
		_ordered.append([a, row[0], row[1]])


static func _family_value(fam: Dictionary) -> Callable:
	if fam.stat != null:
		var key: String = fam.stat
		return func(s): return _st(s, key)
	match fam.id:
		"umwerfen": return func(s): return s.counters.knockdowns
		"schritte": return func(s): return s.counters.steps
		"gold_verdient": return func(s): return s.counters.goldEarned
		"traenke": return func(s): return s.counters.potionsDrunk
		"mahlzeiten": return func(s): return s.counters.mealsEaten
		"fallen_gefunden": return func(s): return s.counters.trapsFound
		"fallen_entschaerft": return func(s): return s.counters.trapsDisarmed
		"fallen_ausgeloest": return func(s): return s.counters.trapsTriggered
		"zauber_gelernt": return func(s): return _spells(s)
		"gebaut": return func(s): return s.counters.crafted
		"haustier_stufe": return func(s): return s.player.pet.level if s.player.pet != null else 0
		"follower": return func(s): return s.viewers.follower
		"stufe": return func(s): return s.player.level
		"skills_gelernt": return func(s): return s.player.skills.size()
		"skill_stufe": return func(s):
			var best := 0
			for k in s.player.skills:
				best = maxi(best, k.level)
			return best
		"entdeckte_skills": return func(s): return J.arr(s.player, "dynSkills").size()
		"wert": return func(s): return s.player.stats.values().max()
	push_error("Unbekannte Achievement-Familie: %s" % fam.id)
	return func(_s): return 0


## Achievements in der Reihenfolge von ACHIEVEMENTS: [def, typen, prüfung]
static func achievements() -> Array:
	_build()
	return _ordered


# ================================================================ Rassen, Klassen, Eigenschaften

static func race_requirement(id: String, s: Dictionary) -> bool:
	var k: Dictionary = s.counters
	match id:
		"katzenmensch": return s.player.pet != null and s.player.pet.species == "Katze"
		"troll": return k.knockdowns >= 15
		"minotaurus":
			var sum := 0.0
			for key in s.player.techniqueUses:
				var t := String(key)
				if t.begins_with("kopf+") or t.ends_with("kopf+") or t.begins_with("+anlauf") or t.ends_with("+anlauf"):
					sum += s.player.techniqueUses[key]
			return sum >= 25
		"golem": return k.damageTaken >= 150
		"pilzling": return k.poisonDamage >= 20
		"vampir": return k.crits >= 10
		"kobold": return k.throws >= 20
		"salamander": return _st(s, "zustand.brennen") + _st(s, "zustand.erlitten.brennen") >= 5
		"rattling": return _killed(s, RATS) >= 25
		"kelleroger": return _st(s, "kills.staerker") >= 5
		"schattenwesen": return _trig(s, "ambush") >= 15
		"wasserspeier": return _trig(s, "block") >= 20
		"kellerfee": return _spells(s) >= 3
		"ghulblut": return _killed(s, UNDEAD) >= 10
		"blechmensch": return k.crafted >= 10
		"drachenblut": return k.bossKills >= 3
	return true


static func class_requirement(id: String, s: Dictionary) -> bool:
	match id:
		"kellerartillerist": return _st(s, "kills.teil.bombe") >= 8
		"schattenweber": return _trig(s, "ambush") >= 20
		"zeitdieb": return _spells(s) >= 3
		"schaedlingsbaendiger": return _killed(s, RATS) >= 30
		"bestiarius": return _st(s, "bestiarium.arten") >= 20
		"gluecksritter": return _st(s, "lose.jackpot") > 0 or _st(s, "lose") >= 25 or _trait(s, "glueckspilz") > 0
		"todesveraechter": return _st(s, "knapp.ueberlebt") >= 10
		"apokalypsennudist": return _st(s, "kills.nackt") >= 10
		"wiedergaenger": return s.achievements.has("zweite_chance")
	return true


static func class_score(id: String, s: Dictionary) -> float:
	var c: Dictionary = s.counters
	match id:
		"strassenkaempfer": return _part_uses(s, "faust") * 2 + _flag(s, "schlaeger") * 15 + _trait(s, "profischlaeger") * 20
		"kickboxer": return _part_uses(s, "tritt") * 2 + _flag(s, "kampfsport") * 15 + _trait(s, "fussballer") * 15
		"stampfbarbar": return _move_uses(s, "stampfen") * 5 + c.knockdowns * 2
		"luchador": return _move_uses(s, "sprung") * 4 + _trait(s, "rampensau") * 10
		"sturmbrecher": return _move_uses(s, "anlauf") * 4 + _trait(s, "rugby") * 20
		"ellbogenanwalt": return _part_uses(s, "ellbogen") * 4 + _flag(s, "buero") * 10 + _trait(s, "verhandler") * 10
		"knieninja": return _part_uses(s, "knie") * 4
		"heimwerker": return _part_uses(s, "waffe") * 3 + _flag(s, "handwerk") * 15
		"klingenvirtuose": return _part_uses(s, "waffe") * 2 + _st(s, "zustand.blutung") * 4 + _flag(s, "gastro") * 10 + _flag(s, "koch") * 10
		"scharfrichter": return _st(s, "kills.zone.kopf") * 4 + _st(s, "kills.liegend") * 2 + _st(s, "kills.fasttot") * 2
		"tuersteher": return _trait(s, "tuersteher") * 35 + _flag(s, "polizei") * 15 + c.knockdowns + _trig(s, "block") * 2
		"kneipenschlaeger": return _st(s, "kills.angetrunken") * 8 + _flag(s, "gastro") * 10 + _trait(s, "barkeeper") * 15 + _part_uses(s, "kopf")
		"steinschleuderer": return _part_uses(s, "wurf") * 3 + c.throws
		"dartprofi": return _part_uses(s, "wurf") * 2 + _st(s, "kills.weitwurf") * 10 + _trait(s, "barkeeper") * 15 + _trait(s, "adleraugen") * 15
		"kellerartillerist": return _st(s, "kills.teil.bombe") * 6 + 30
		"kellermagier": return _stat_v(s, "int") * 2 + _spells(s) * 10 + _st(s, "zauber.gewirkt") * 2 + _flag(s, "student") * 10 + _flag(s, "it") * 5
		"pyromane": return _st(s, "zustand.brennen") * 5 + _st(s, "kills.teil.feuer") * 6 + _st(s, "hergestellt.brandflasche") * 5 + _trait(s, "feuerwehr") * 15
		"giftmischer": return _st(s, "zustand.gift") * 5 + floorf(c.poisonDamage / 2.0) + _trait(s, "kammerjaeger_gift") * 25 + _trait(s, "schaedlingsbekaempfer") * 25
		"heckenmagier": return _st(s, "zauber.gewirkt") * 3 + _trait(s, "foerster") * 15 + _trait(s, "gaertner") * 15 + _flag(s, "natur") * 15
		"schattenweber": return _trig(s, "ambush") * 2 + 30
		"zeitdieb": return _spells(s) * 12 + 20
		"assassine": return _trig(s, "ambush") * 4 + _flag(s, "feigling") * 10
		"langfinger": return _killed(s, ["elster_goblin", "heinzelmann", "wechselbalg", "schmuggler"]) * 6 + _flag(s, "handel") * 10 + _trait(s, "zocker") * 10 + floorf(c.goldEarned / 60.0)
		"fallenbauer": return _st(s, "fallen.aufgestellt") * 6 + c.trapsDisarmed * 4 + c.trapKills * 8 + _flag(s, "planer") * 10
		"spaeher": return floorf(_st(s, "raeume.entdeckt") / 2.0) + floorf(_st(s, "max.erkundet") / 4.0) + c.trapsFound * 4 + _trait(s, "adleraugen") * 15 + _flag(s, "laeufer") * 10
		"panzerkoloss": return floorf(c.damageTaken / 10.0) + _flag(s, "gemuetlich") * 10 + _trait(s, "lastentraeger") * 15
		"schaedelmoench": return _part_uses(s, "kopf") * 4 + _trait(s, "dickkopf") * 15
		"kellertaenzer": return _trig(s, "dodge") * 2 + _flag(s, "laeufer") * 10 + _flag(s, "sportler") * 10
		"konterboxer": return _st(s, "kills.konter") * 12 + floorf(_st(s, "ausgewichen") / 2.0) + _flag(s, "kampfsport") * 20
		"muelltonnenritter": return _trig(s, "block") * 3 + floorf(_st(s, "schaden.erlitten") / 25.0)
		"feldsanitaeter": return _flag(s, "heiler") * 25 + c.potionsDrunk * 3 + _stat_v(s, "int")
		"kampfkoch": return _flag(s, "koch") * 25 + c.mealsEaten * 6 + _flag(s, "gastro") * 10
		"seelsorger": return _st(s, "crawler.geheilt") * 15 + _st(s, "party.beigetreten") * 10 + _flag(s, "sozial") * 20 + _trait(s, "paedagoge") * 15 + _trait(s, "teamplayer") * 10
		"hausapotheker": return c.potionsDrunk * 3 + _st(s, "traenke.knapp") * 10 + _flag(s, "heiler") * 15
		"showstar": return _stat_v(s, "cha") * 2 + _flag(s, "kuenstler") * 20 + floorf(s.viewers.follower / 50.0)
		"influencer": return _trait(s, "social_media") * 35 + _trait(s, "streamer") * 25 + _trait(s, "handysuechtig") * 15 + _flag(s, "medien") * 15 + floorf(s.viewers.follower / 100.0)
		"stuntdouble": return _move_uses(s, "sprung") * 3 + _st(s, "explosion.selbst") * 15 + _st(s, "knapp.ueberlebt") * 5
		"marktschreier": return _st(s, "feilschen.gewonnen") * 6 + _st(s, "gekauft") * 2 + _st(s, "verkauft") + _flag(s, "handel") * 15 + _trait(s, "verhandler") * 20
		"bombenbastler": return _stat_v(s, "int") * 2 + _flag(s, "planer") * 20 + J.num(c.killsByDef, "blaehkroete") * 3 + _st(s, "kills.teil.bombe") * 4
		"schrottmechaniker": return _trait(s, "berufsfahrer") * 20 + floorf(_st(s, "reittier.schritte") / 10.0) + c.crafted * 3 + _flag(s, "technik") * 15
		"systemhacker": return _trait(s, "hacker") * 35 + _flag(s, "it") * 20 + _flag(s, "gamer") * 15 + _stat_v(s, "int")
		"tierfluesterer": return (30 + s.player.pet.level * 5 + _trait(s, "tierarzt") * 15) if s.player.pet != null else -100
		"kellerreiter": return (30 if s.player.get("mount") != null else -100) + floorf(_st(s, "reittier.schritte") / 5.0) + _st(s, "reittier.kills") * 10
		"schaedlingsbaendiger": return _killed(s, RATS) * 2 + _trait(s, "schaedlingsbekaempfer") * 25
		"bestiarius": return _st(s, "bestiarium.arten") * 3 + 20
		"gluecksritter": return _st(s, "lose") * 2 + _st(s, "lose.jackpot") * 30 + _trait(s, "glueckspilz") * 20 + 10
		"todesveraechter": return _st(s, "knapp.ueberlebt") * 4 + 40
		"apokalypsennudist": return _st(s, "kills.nackt") * 4 + 40
		"wiedergaenger": return 60
	push_error("Klasse ohne Bewertung: %s" % id)
	return -100


static func trait_overcome(id: String, s: Dictionary) -> bool:
	var total := func(key: String) -> float:
		var c = s.get("chronicle")
		return J.num(c.counts, "total|" + key) if c != null else 0.0
	match id:
		"angst_krabbeltiere": return _killed(s, ["kellerspinne", "riesenkakerlake"]) >= 10
		"angst_ratten": return _killed(s, RATS) >= 15
		"angst_dunkel": return _killed(s, ["poltergeist", "irrlicht", "ghul", "moorleiche", "nachtmahr", "knochenratte", "kellermeister", "ghulhund"]) >= 8
		"hoehenangst": return total.call("hit|m:sprung") >= 15
		"platzangst": return total.call("kill|i:im_gang") >= 20
	return false


static func talkshow_when(id: String, s: Dictionary) -> bool:
	match id:
		"gefallen": return J.arr(s, "fallen").size() > 0
		"haustier": return s.player.pet != null
		"party": return J.some(J.arr(s, "crawlers"), func(c): return c.alive and c.party)
		"kampfstil": return s.counters.kills >= 10
		"bomben": return s.counters.crafted >= 2 or s.counters.trapKills >= 1
	return true
