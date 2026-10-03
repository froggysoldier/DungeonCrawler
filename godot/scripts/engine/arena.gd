class_name Arena
extends RefCounted
## Gladiatorenkampf „Die Grube“ (data/show.json FORMATS.gladiator): Der
## Crawler wird in eine kleine runde Arena gebeamt und kämpft dort ganz
## normal gegen einen Elite-Gegner seiner Etage. Die Etage wartet so lange:
## Gegner, Crawler, Gegenstände, Fallen und Haustier bleiben, wo sie sind.
## Verlieren heißt hier nicht sterben – bei null Lebenspunkten ist der Kampf
## vorbei, die Sanitäter schleifen einen hinaus.

const W := 15
const H := 11


static func active(s: Dictionary) -> bool:
	return s.get("arena") != null


static func _fmt() -> Dictionary:
	return Db.t("show", "FORMATS").gladiator


static func _map() -> Dictionary:
	var tiles := []
	var room_at := []
	var explored := []
	for y in H:
		for x in W:
			var inside := x >= 2 and y >= 2 and x < W - 2 and y < H - 2
			tiles.append("floor" if inside else "wall")
			room_at.append(0 if inside else -1)
			explored.append(true)
	var room := {
		"id": 0, "x": 2, "y": 2, "w": W - 4, "h": H - 4, "kind": "arena", "hood": -1, "visited": true,
		"name": "Die Grube",
		"description": "Eine runde Arena aus festgetretenem Sand. Ringsum Ränge bis unter die Decke, voll mit Zuschauern aller Arten.",
	}
	return {"width": W, "height": H, "tiles": tiles, "roomAt": room_at, "rooms": [room], "hoods": [], "explored": explored, "locks": {}}


## Kampf beginnen: Etage beiseitelegen, Arena aufbauen, Gegner hinstellen.
static func start(s: Dictionary) -> Dictionary:
	var p: Dictionary = s.player
	var lvl := int(p.level) + 1
	var def := Monsters.pick_monster_def(s, int(s.floor), lvl)
	s.arena = {
		"stash": {
			"map": s.map, "monsters": s.monsters, "items": s.items, "traps": J.arr(s, "traps"),
			"crawlers": J.arr(s, "crawlers"), "pos": J.pcopy(p.pos), "pet": p.pet, "currentRoom": s.currentRoom,
		},
		"start": s.turn,
	}
	s.map = _map()
	s.items = []
	s.traps = []
	s.crawlers = []
	p.pet = null
	p.riding = false
	p.pos = J.pos(4, H / 2)
	var m := Monsters.spawn_monster(s, def, Monsters.clamp_level(def, lvl), J.pos(W - 5, H / 2), -1, true)
	m.aware = true
	s.monsters = [m]
	s.arena.opponent = m.uid
	s.arena.name = Identify.name_of(s, m, "akk")
	s.currentRoom = 0
	Game.after_move(s)
	var f := _fmt()
	Log.add(s, "DIE GRUBE: Gladiatorenkampf gegen %s! Wer liegen bleibt, verliert – sterben musst du hier nicht." % s.arena.name, "gefahr")
	return {"title": f.name, "speaker": f.host, "pages": [String(f.intro).replace("{name}", p.name).replace("{gegner}", s.arena.name)]}


## Statt zu sterben: k. o. (Death.handle_lethal fragt hier zuerst nach).
static func knockout(s: Dictionary) -> void:
	s.player.hp = 1
	s.arena.knockedOut = true


## Am Ende jedes Zuges: Ist der Kampf entschieden?
static func check(s: Dictionary) -> void:
	if not active(s) or s.status != "playing":
		return
	var a: Dictionary = s.arena
	if not J.some(s.monsters, func(m): return m.uid == a.opponent):
		_finish(s, "sieg")
	elif a.get("knockedOut", false):
		_finish(s, "niederlage")
	elif int(s.turn) - int(a.start) >= int(_fmt().maxTurns):
		_finish(s, "unentschieden")


static func _finish(s: Dictionary, result: String) -> void:
	var a: Dictionary = s.arena
	var st: Dictionary = a.stash
	var p: Dictionary = s.player
	s.erase("arena")
	s.map = st.map
	s.monsters = st.monsters
	s.items = st.items
	s.traps = st.traps
	s.crawlers = st.crawlers
	p.pos = st.pos
	p.pet = st.pet
	s.currentRoom = st.currentRoom
	var f := _fmt()
	var pages := []
	var score := 0.0
	match result:
		"sieg":
			var gold := 40 * int(s.floor)
			p.gold += gold
			s.counters.goldEarned += gold
			p.boxes.append(Items.create_box(s, "brawler", "gold"))
			pages = [f.win, "Preisgeld: %d Gold und eine Schläger-Box." % gold]
			score = 60.0
		"niederlage":
			p.hp = maxi(p.hp, J.rnd(Player.max_hp(s) * 0.25))
			pages = [f.loss]
			score = 25.0
		_:
			p.hp = maxi(p.hp, 1)
			pages = [f.draw]
			score = 12.0
	var outcome: String = {"sieg": "Und gewinnt!", "niederlage": "Und verliert – aber mit Stil.", "unentschieden": "Unentschieden. Die Ränge buhen."}[result]
	Highlights.note(s, score, "arena", {"gegner": a.name, "ausgang": outcome})
	Viewers.add_spectacle(s, score, "boss" if result == "sieg" else "drama")
	Log.add(s, "DIE GRUBE: %s Du bist zurück, wo du warst." % outcome, "system")
	Game.after_move(s)
	Events.emit(s, {"type": "arena", "result": result})
	s.pendingDialogs.append({"title": f.name, "speaker": f.host, "pages": pages})
