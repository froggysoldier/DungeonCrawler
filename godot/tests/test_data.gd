extends RefCounted
## Alle Inhalte kommen vollständig in Godot an.

var data


func setup(d) -> void:
	data = d


func test_tables_loaded(t) -> void:
	for pair in [["items", "BASE_ITEMS"], ["monsters", "MONSTERS"], ["classes", "CLASSES"], ["races", "RACES"], ["skills", "SKILLS"], ["achievements", "ACHIEVEMENTS"], ["spells", "SPELLS"], ["world", "FLOORS"]]:
		var v = data.get_table(pair[0], pair[1])
		t.ok(v != null and v.size() > 0, "%s.%s fehlt oder ist leer" % pair)
	t.ok(data.get_table("classes", "CLASSES").size() >= 45, "mindestens 45 Klassen")
	t.ok(data.get_table("races", "RACES").size() >= 24, "mindestens 24 Rassen")


func test_lookup_by_id(t) -> void:
	t.eq(data.by_id("items", "BASE_ITEMS", "heiltrank").get("id"), "heiltrank", "Heiltrank per ID")
	t.eq(data.by_id("monsters", "MONSTERS", "kellerratte").get("id"), "kellerratte", "Kellerratte per ID")
	t.eq(data.by_id("items", "BASE_ITEMS", "gibtsnicht"), {}, "unbekannte ID")
