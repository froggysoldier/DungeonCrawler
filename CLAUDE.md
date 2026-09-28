# Projektregeln

- Spiel „Der Große Abstieg“: Godot 4.7.2 (GDScript), Projekt in `godot/`. Es wird nur noch in Godot entwickelt. Aufbau, Werkzeuge und Export stehen in `docs/GODOT_PORT.md`.
- Spiellogik in `godot/scripts/engine` (ohne Nodes), Oberfläche in `godot/scripts/ui`, Inhalte in `godot/data/*.json`. Bedingungen, die nicht in JSON passen (Achievements, Klassen, Rassen, Interview …), stehen in `godot/scripts/engine/data_checks.gd` und `rules.gd`.
- Die alte Web-Version (TypeScript: `src/`, `tests/`, `scripts/`, `package.json`) ist eingefroren: nicht mehr ändern, nichts mehr daraus exportieren.
- Sprache im Spiel: Deutsch.
- **Keine Emojis** in Oberfläche, Spieltexten oder Logs. Nur klare Schrift, Text und Wörter.
- Monster und Gegenstände werden über `godot/scripts/engine/identify.gd` angezeigt: Namen und Werte nie direkt ausgeben, sondern `name_of`/`describe_monster`/`item_name`/`describe_item` verwenden.
- Spoiler-Regel: Aus Buch 1–3 dürfen nur Spielmechaniken und die Komplexität der Systeme übernommen werden (Achievements, Skills, Stufen, Klassen, Rassen, Boxen, Sponsoren, Quests, Haustiere, Reittiere …) – keine Handlung, Figuren, Orte oder Wendungen. Der Nutzer hört Buch 2 noch (Stand: beim Magistrat); in Antworten nichts aus späteren Kapiteln erwähnen. Fokus: Etage 1–3. Immer eigene Namen statt Figuren aus den Büchern.
- Vor dem Committen: `./test.sh` (alle Godot-Tests headless, Godot-Pfad per `GODOT=…`). Laufzeitfehler zählen als Fehlschlag.
- Ändern sich Inhalte oder Regeln absichtlich, weichen die Replay-Tests ab. Dann die Aufnahmen mit `godot --headless --path godot -s res://tools/record_fixtures.gd` erneuern, die Abweichung prüfen und die neuen Fixtures mit einchecken. Neue Spielbausteine bekommen eigene Tests in `godot/tests`.
