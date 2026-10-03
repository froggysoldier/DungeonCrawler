class_name Meta
extends RefCounted
## Meta-Fortschritt und Speichern.
## Gespeichert wird in user:// als JSON.

const META_PATH := "user://meta.json"
const RUN_PATH := "user://run.json"


static func empty_meta() -> Dictionary:
	return {"season": 0, "achievementsEver": [], "bestiary": {}, "hallOfFame": [], "ghosts": [], "guides": []}


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return J.parse(FileAccess.get_file_as_string(path))


static func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "", false, true))


static func load_meta() -> Dictionary:
	var raw = _read(META_PATH)
	var m := empty_meta()
	if raw is Dictionary:
		m.merge(raw, true)
	return m


static func save_meta(meta: Dictionary) -> void:
	_write(META_PATH, meta)


## Spielstand speichern (ohne Effekte und Klänge, die nur die Oberfläche braucht).
static func save_run(s: Dictionary) -> void:
	_write(RUN_PATH, s)


static func load_run() -> Variant:
	var raw = _read(RUN_PATH)
	if not raw is Dictionary:
		return null
	var s := migrate(raw)
	return s if s.status == "playing" else null


static func delete_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(RUN_PATH)


static func migrate(s: Dictionary) -> Dictionary:
	if s.get("viewers") == null:
		s.viewers = {"follower": 0, "hype": 0, "nextFanBox": 0, "lastSpectacle": 0}
	if s.get("pendingSelection") == null:
		s.pendingSelection = false
	if s.player.get("traits") == null:
		s.player.traits = []
	for k in ["goldEarned", "goldStolen", "poisonDamage", "mealsEaten", "potionsDrunk", "sleeps", "crits", "knockdowns", "eliteKills", "trapsFound", "trapsTriggered", "trapsDisarmed", "trapKills", "crafted"]:
		if s.counters.get(k) == null:
			s.counters[k] = 0
	if s.floor >= Game.unlock_floor("zuschauer") and not s.unlocks.has("zuschauer"):
		s.unlocks.append("zuschauer")
	Game.unlock_floor_systems(s, int(s.floor))
	if s.player.get("klass") and s.player.get("classSkills") == null:
		s.player.classSkills = Classes.class_skills_of(s.player.get("race"), s.player.klass)
	if s.get("stats") == null:
		s.stats = {}
	for k in ["toasts", "pendingDialogs"]:
		if s.get(k) == null:
			s[k] = []
	return s


static func sync_meta(meta: Dictionary, s: Dictionary) -> void:
	meta.achievementsEver = J.uniq(meta.achievementsEver + s.achievements)


static func _best_items(s: Dictionary) -> Array:
	var items: Array = s.player.equipment.values().filter(func(i): return i != null)
	J.sort(items, func(a, b): return b.wert - a.wert)
	return items.slice(0, 3).map(func(i): return i.duplicate(true))


## Ende einer Staffel: Ruhmeshalle, Bestiarium, Geist oder Guide.
static func record_run_end(meta: Dictionary, s: Dictionary) -> Dictionary:
	sync_meta(meta, s)
	meta.season = maxi(meta.season, s.season)
	for k in s.counters.killsByDef:
		meta.bestiary[k] = int(J.num(meta.bestiary, k)) + s.counters.killsByDef[k]
	var outcome := "ueberlebt" if s.status == "victory" else ("vertrag" if s.contractSigned else "tot")
	meta.hallOfFame.append({
		"season": s.season,
		"name": s.player.name,
		"background": s.player.background,
		"level": s.player.level,
		"floor": s.floor,
		"kills": s.counters.kills,
		"achievements": s.achievements.size(),
		"cause": ("Etage %d überlebt" % s.floor) if s.status == "victory" else J.nn(s, "deathCause", "unbekannt"),
		"outcome": outcome,
	})
	meta.ghosts = meta.ghosts.filter(func(g): return not s.ghostsDefeated.has(g.name))
	if outcome == "tot":
		meta.ghosts.append({"name": s.player.name, "floor": s.floor, "level": s.player.level, "season": s.season, "items": _best_items(s)})
		meta.ghosts = meta.ghosts.slice(maxi(0, meta.ghosts.size() - 10))
	if outcome == "vertrag":
		meta.guides.append({"name": s.player.name, "season": s.season, "level": s.player.level})
	delete_run()
	save_meta(meta)
	return meta
