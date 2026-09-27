extends Node
## Lädt alle Spielinhalte aus res://data/*.json (erzeugt von
## `npm run export:godot` aus src/data) und baut Nachschlage-Tabellen auf.
##
## Zugriff: GameData.get_table("items", "BASE_ITEMS")
##          GameData.by_id("items", "BASE_ITEMS", "heiltrank")

const DATA_DIR := "res://data"

## Dateiname (ohne .json) -> { Exportname -> Wert }
var tables: Dictionary = {}
var _index: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	tables.clear()
	_index.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_error("Datenordner fehlt: %s" % DATA_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var text := FileAccess.get_file_as_string("%s/%s" % [DATA_DIR, file])
		var parsed = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Ungültige Datendatei: %s" % file)
			continue
		tables[file.get_basename()] = parsed


func get_table(file: String, export_name: String) -> Variant:
	return tables.get(file, {}).get(export_name)


## Eintrag einer Liste über sein Feld "id" finden.
func by_id(file: String, export_name: String, id: String) -> Dictionary:
	var key := "%s/%s" % [file, export_name]
	if not _index.has(key):
		var map := {}
		var list = get_table(file, export_name)
		if list is Array:
			for entry in list:
				if entry is Dictionary and entry.has("id"):
					map[entry.id] = entry
		_index[key] = map
	return _index[key].get(id, {})
