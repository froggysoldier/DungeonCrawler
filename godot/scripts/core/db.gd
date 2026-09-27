class_name Db
extends RefCounted
## Alle Spielinhalte aus res://data/*.json (erzeugt aus src/data). Wird beim
## ersten Zugriff geladen. Zahlen sind normalisiert (ganze Zahlen als int).

const DATA_DIR := "res://data"

static var _tables := {}
static var _index := {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("Datenordner fehlt: %s" % DATA_DIR)
		return
	for file in dir.get_files():
		# Exportierte Builds benennen Dateien um (.json.remap o. Ä.)
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".json"):
			continue
		_tables[name.get_basename()] = J.load_json("%s/%s" % [DATA_DIR, name])


## Ein Export aus einer Datendatei, z. B. Db.t("items", "BASE_ITEMS").
static func t(file: String, export_name: String) -> Variant:
	_ensure()
	return _tables.get(file, {}).get(export_name)


## Eintrag einer Liste über sein Feld "id" (oder null).
static func by_id(file: String, export_name: String, id: Variant) -> Variant:
	var key := "%s/%s" % [file, export_name]
	if not _index.has(key):
		var map := {}
		var list = t(file, export_name)
		if list is Array:
			for entry in list:
				if entry is Dictionary and entry.has("id"):
					map[entry.id] = entry
		_index[key] = map
	return _index[key].get(id)


# ---------------------------------------------------------------- Kurzwege

static func world(name: String) -> Variant:
	return t("world", name)


static func base_item(id: String) -> Variant:
	# Basis- und Unikat-Gegenstände teilen sich einen Namensraum
	var key := "items/ALL"
	if not _index.has(key):
		var map := {}
		for b in t("items", "BASE_ITEMS"):
			map[b.id] = b
		for b in t("items", "UNIQUE_ITEMS"):
			map[b.id] = b
		_index[key] = map
	return _index[key].get(id)


static func unique_item(id: String) -> Variant:
	return by_id("items", "UNIQUE_ITEMS", id)


static func monster(id: String) -> Variant:
	return by_id("monsters", "MONSTERS", id)


static func hood_boss(id: String) -> Variant:
	return by_id("monsters", "HOOD_BOSSES", id)


static func skill(id: String) -> Variant:
	return by_id("skills", "SKILLS", id)


static func spell(id: String) -> Variant:
	return by_id("spells", "SPELLS", id)


static func klass(id: String) -> Variant:
	return by_id("classes", "CLASSES", id)


static func race(id: String) -> Variant:
	return by_id("races", "RACES", id)


static func trait_def(id: String) -> Variant:
	return by_id("traits", "TRAITS", id)


static func sponsor(id: String) -> Variant:
	return by_id("sponsors", "SPONSORS", id)


static func recipe(id: String) -> Variant:
	return by_id("crafting", "RECIPES", id)


static func achievement(id: String) -> Variant:
	return by_id("achievements", "ACHIEVEMENTS", id)


static func floor_def(floor: int) -> Dictionary:
	var floors: Array = world("FLOORS")
	for f in floors:
		if f.floor == floor:
			return f
	return floors[floors.size() - 1]


## Etagen-Definition mit Rückfall auf die erste Etage (FLOORS[0]).
static func floor_def0(floor: int) -> Dictionary:
	var floors: Array = world("FLOORS")
	for f in floors:
		if f.floor == floor:
			return f
	return floors[0]
