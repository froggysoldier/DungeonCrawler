# Godot-Projekt

Das ganze Spiel läuft in Godot 4.7.2: Spiellogik, Karte, Figuren, Oberfläche,
Dialoge, Klänge und Speichern. Es wird nur noch hier entwickelt.

Die frühere Web-Version (TypeScript) ist eingefroren. Ihr letzter Stand liegt im
Git-Verlauf bei Commit `8b139bb` („Port remaining Vitest suites …“). Bis dahin
rechneten beide Versionen bitgenau gleich; die Replay-Aufnahmen in
`tests/fixtures` stammen ursprünglich aus der Web-Version und werden jetzt in
Godot selbst erzeugt (siehe unten).

Starten: `godot/project.godot` im Godot-Editor 4.7.2 öffnen und F5 drücken.
Die Hauptszene ist `scenes/main.tscn`.

## Aufbau

```
godot/
  project.godot          Godot 4.7, GL Compatibility (läuft auch im Browser)
  export_presets.cfg     Vorlagen für den Export: Web, Windows, Linux
  data/*.json            Inhalte (Monster, Gegenstände, Skills, Achievements …)
  scripts/core/          Zufall, Sichtfeld, Wegfindung, Datenzugriff, JS-Hilfen
  scripts/engine/        Spiellogik (Port von src/engine), ohne Grafik
  scripts/ui/            Oberfläche (Port von src/ui)
  scenes/main.*          Einstieg: Titel, Interview, Spiel, Endbildschirm
  assets/fonts/          Montserrat (SIL Open Font License, siehe OFL.txt)
  tests/                 Testlauf, Tests, Replay-Bot und Aufnahmen (fixtures)
  tools/                 Werkzeuge: Bildschirmfotos, Aufnahmen, Balance-Simulation
```

### Oberfläche (`scripts/ui`)

| Datei | Inhalt |
|---|---|
| `pen.gd` | Nachbau der Canvas-2D-Schnittstelle (Pfade, Kurven, Verläufe, Text) |
| `tiles.gd` | Böden, Mauern, Türen und Schatten als Texturen, einmal erzeugt |
| `map_view.gd` | Karte: statische Ebene (nur bei Änderungen neu), bewegte Ebene, Licht, Effekte |
| `sprites.gd` | Kreaturen und Spielfigur |
| `animator.gd` | Gleiten, Kamera, Geschosse, aufsteigende Zahlen |
| `game_view.gd` | Spielansicht, Eingabe, Kampfmodus, Log |
| `game_here.gd`, `game_tabs.gd`, `game_combat.gd`, `game_dialogs.gd` | Seitenleiste, Reiter, Kampfsequenz, Tooltip, Versus, Talkshow, Hilfe |
| `selection.gd`, `screens.gd` | Rassen- und Klassenwahl, Titel, Interview, Ende |
| `modals.gd`, `typing.gd` | Dialoge mit Warteschlange, Schreibmaschinen-Effekt |
| `sound.gd` | Klänge im Spiel erzeugt, ohne Audiodateien |
| `ui_theme.gd`, `kit.gd`, `click_panel.gd` | Designsystem (Farben, Knöpfe, Karten) und Bausteine |

`Pen` bildet die Canvas-Befehle eines Browsers nach (Pfade, Kurven,
Verläufe). Verläufe werden vormultipliziert gemischt. Kanten werden weich
gezeichnet, weil der Kompatibilitäts-Renderer kein 2D-MSAA kennt.

## Werkzeuge

| Befehl | Zweck |
|---|---|
| `./test.sh [filter]` | Alle Tests headless ausführen (Godot-Pfad per `GODOT=…`, sonst `godot` im PATH). Laufzeitfehler (SCRIPT ERROR, push_error) zählen als Fehlschlag. Ohne Skript: `godot --headless --path godot -s res://tests/run_tests.gd [-- filter]` |
| `UI_SMOKE_ALL=1 ./test.sh ui_smoke` | Alle aufgezeichneten Partien (bis Etage 3) durch die Oberfläche spielen, dauert einige Minuten |
| `godot --headless --path godot -s res://tools/record_fixtures.gd` | Aufnahmen für die Replay-Tests neu erzeugen (Karten, Replays, Anzeige-Helfer), nach absichtlichen Änderungen an Inhalten oder Regeln |
| `godot --headless --path godot -s res://tools/balance_sim.gd [-- anzahl]` | Ein Bot spielt Partien bis Etage 3 und gibt eine Tabelle aus (Stufe, Kills, Todesursache …) |
| `xvfb-run godot --path godot -s res://tools/shot_ui.gd -- ordner modus` | Bildschirmfoto: `title`, `interview`, `game`, `dialog`, `walk`, `tabs`, `select`, `versus`, `talkshow`, `safe`, `floor3` (mit `PERF=1` auch Zeichenzeit der Karte) |
| `xvfb-run godot --path godot -s res://tools/shot_sprites.gd -- bild.png` | Alle Kreaturen als Bogen, zum Vergleich mit der Web-Version |

## Tests

| Test | Prüft |
|---|---|
| `test_rng`, `test_map`, `test_data` | Zufall, Sichtfeld, Wegfindung, Daten |
| `test_replay` | Drei aufgezeichnete Partien (bis Etage 3): jeder Zug identisch zur Aufnahme |
| `test_ui_helpers` | Anzeige-Helfer (Uhrzeit, nächste Ziele, Bodenmaterial, Zufall je Kachel, Beschreibungen) identisch zur Aufnahme |
| `test_engine`, `test_combat_zones`, `test_ai`, `test_skills` … | Spielregeln einzeln: Kampf, Gegner, Skills, Klassen, Magie, Fallen, Handwerk, Haustiere, Reittiere, Sponsoren, Talkshow, Achievements |
| `test_ui_smoke` | Eine Partie komplett über die Spielansicht gespielt: keine Laufzeitfehler, Spielverlauf unverändert |
| `test_sound` | Klänge hörbar und nicht übersteuert |

## Grundsätze

- **Inhalte in `data/*.json`:** Monster, Gegenstände, Skills, Klassen,
  Achievements usw. werden dort geändert. Was sich nicht als JSON ausdrücken
  lässt (Bedingungen von Achievements, Klassen, Rassen, Interview-Fragen),
  steht per id in `scripts/engine/data_checks.gd` und `scripts/engine/rules.gd`.
- **Gleicher Seed, gleiches Spiel:** Die Spiellogik ist deterministisch. Die
  Replay-Tests merken jede Verhaltensänderung. Absichtliche Änderungen werden
  mit `tools/record_fixtures.gd` neu aufgenommen.
- **Spielstand als JSON:** Der Zustand ist ein Dictionary; Spielstände liegen
  in `user://run.json` und `user://meta.json`.
- **Logik und Darstellung getrennt:** `scripts/engine` kennt keine Nodes.
- **GDScript statt C#:** C# lässt sich in Godot 4 nicht für das Web exportieren.
- Projektregeln aus `CLAUDE.md` gelten weiter (Deutsch, keine Emojis,
  Anzeige über die Identify-Funktionen, Spoiler-Regel).

## Stand

| Phase | Inhalt | Stand |
|---|---|---|
| 0 – Fundament | Projekt, Datenexport, Zufall, Sichtfeld, Wegfindung, Testlauf | erledigt |
| 1 – Welt | Spielstand, Kartengenerator, Monster und Gegenstände, Identifizieren | erledigt |
| 2 – Spielschleife | Bewegung, Züge, Kampf, KI, Zustände, Türen, Fallen | erledigt |
| 3 – Systeme | Skills, Stufen, Achievements, Klassen, Rassen, Boxen, Sponsoren, Quests, Haustiere, Reittiere, Magie, Handwerk, Laden, Crawler, Talkshow, Zuschauer | erledigt |
| 4 – Darstellung | Karte, Kreaturen, Kamera, Licht und Nebel, Theme, Log mit Schreibmaschinen-Effekt, Klänge, Versus-Bildschirm, Kampfbanner | erledigt |
| 5 – Abschluss | Titel, Interview, Speichern und Laden, Export Web, Windows, Linux | erledigt |
| 6 – Eigenständig | Alle Tests in GDScript, Aufnahmen und Testlauf ohne Node, Godot als einzige Quelle | erledigt |

## Export

In `export_presets.cfg` stehen Vorlagen für Web, Windows und Linux. Der Editor
braucht dafür die Export-Vorlagen von Godot 4.7.2 (Editor → Export-Vorlagen
verwalten). Auf der Kommandozeile:

```bash
godot --headless --path godot --export-release Web ../build/godot-web/index.html
godot --headless --path godot --export-release Linux ../build/godot-linux/DerGrosseAbstieg.x86_64
godot --headless --path godot --export-release Windows ../build/godot-windows/DerGrosseAbstieg.exe
```

Geprüft: Die Linux-Version startet fehlerfrei. Die Web-Version läuft in
Chromium mit Titel, Interview, Karte, Kampf und Tastatur. Die Web-Vorlage kommt
ohne Threads aus und läuft deshalb auf jedem einfachen Webserver (etwa
`python3 -m http.server` im Ausgabeordner). Die Klänge werden dort
nacheinander erzeugt, ein Klang pro Bild. Die Ausgabe landet in `build/`, das
nicht eingecheckt wird.

Entwicklerschalter: `--schnellstart` startet direkt eine Partie (Seed 1, ohne
Interview). Im Web geht das über `"args":["--schnellstart"]` in der
erzeugten `index.html`.
