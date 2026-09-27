extends Control
## Platzhalter-Startbildschirm während des Umbaus: zeigt, dass Projekt und
## Daten geladen sind. Wird durch Titelbildschirm und Interview ersetzt.

@onready var _info: Label = %Info


func _ready() -> void:
	var counts := [
		["Gegenstände", GameData.get_table("items", "BASE_ITEMS")],
		["Monster", GameData.get_table("monsters", "MONSTERS")],
		["Klassen", GameData.get_table("classes", "CLASSES")],
		["Rassen", GameData.get_table("races", "RACES")],
		["Skills", GameData.get_table("skills", "SKILLS")],
		["Achievements", GameData.get_table("achievements", "ACHIEVEMENTS")],
	]
	var lines := PackedStringArray()
	for c in counts:
		lines.append("%s: %d" % [c[0], (c[1] as Array).size() if c[1] is Array else 0])
	_info.text = "\n".join(lines)
