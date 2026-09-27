# Umbau auf Godot 4.7.2

Das ganze Spiel läuft jetzt auch in Godot: Spiellogik, Karte, Figuren,
Oberfläche, Dialoge, Klänge und Speichern. Die Web-Version bleibt als
**Referenz** bestehen. Beide Versionen rechnen bitgenau gleich; das prüfen die
Vergleichstests bei jedem Testlauf.

Starten: `godot/project.godot` im Godot-Editor 4.7.2 öffnen und F5 drücken.
Die Hauptszene ist `scenes/main.tscn`.

## Aufbau

```
godot/
  project.godot          Godot 4.7, GL Compatibility (läuft auch im Browser)
  export_presets.cfg     Vorlagen für den Export: Web, Windows, Linux
  data/*.json            Inhalte, erzeugt aus src/data (nicht von Hand ändern)
  scripts/core/          Zufall, Sichtfeld, Wegfindung, Datenzugriff, JS-Hilfen
  scripts/engine/        Spiellogik (Port von src/engine), ohne Grafik
  scripts/ui/            Oberfläche (Port von src/ui)
  scenes/main.*          Einstieg: Titel, Interview, Spiel, Endbildschirm
  assets/fonts/          Montserrat (SIL Open Font License, siehe OFL.txt)
  tests/                 Testlauf, Tests und Vergleichswerte (fixtures)
  tools/                 Entwicklerwerkzeuge für Bildschirmfotos
```

### Oberfläche (`scripts/ui`)

| Datei | Inhalt | Vorbild |
|---|---|---|
| `pen.gd` | Nachbau der Canvas-2D-Schnittstelle (Pfade, Kurven, Verläufe, Text) | Browser-Canvas |
| `tiles.gd` | Böden, Mauern, Türen und Schatten als Texturen, einmal erzeugt | `render.ts` |
| `map_view.gd` | Karte: statische Ebene (nur bei Änderungen neu), bewegte Ebene, Licht, Effekte | `render.ts` |
| `sprites.gd` | Kreaturen und Spielfigur | `sprites.ts` |
| `animator.gd` | Gleiten, Kamera, Geschosse, aufsteigende Zahlen | `animator.ts` |
| `game_view.gd` | Spielansicht, Eingabe, Kampfmodus, Log | `gameview.ts` |
| `game_here.gd`, `game_tabs.gd`, `game_combat.gd`, `game_dialogs.gd` | Seitenleiste, Reiter, Kampfsequenz, Tooltip, Versus, Talkshow, Hilfe | `gameview.ts` |
| `selection.gd`, `screens.gd` | Rassen- und Klassenwahl, Titel, Interview, Ende | `selection.ts`, `screens.ts` |
| `modals.gd`, `typing.gd` | Dialoge mit Warteschlange, Schreibmaschinen-Effekt | `modal.ts`, `typewriter.ts` |
| `sound.gd` | Klänge im Spiel erzeugt, ohne Audiodateien | `sound.ts` |
| `ui_theme.gd`, `kit.gd`, `click_panel.gd` | Designsystem (Farben, Knöpfe, Karten) und Bausteine | `style.css` |

Die Zeichnungen sind Zeile für Zeile aus der Web-Version übertragen. `Pen`
bildet dafür die Canvas-Befehle nach. Verläufe werden wie im Browser
vormultipliziert gemischt. Kanten werden weich gezeichnet, weil der
Kompatibilitäts-Renderer kein 2D-MSAA kennt.

## Werkzeuge

| Befehl | Zweck |
|---|---|
| `npm run export:godot` | Inhalte aus `src/data` nach `godot/data` und Vergleichswerte nach `godot/tests/fixtures` schreiben |
| `npm run test:godot` | Godot-Tests headless ausführen (Godot-Pfad per `GODOT=…`, sonst `godot` im PATH). Laufzeitfehler (SCRIPT ERROR) zählen als Fehlschlag. |
| `UI_SMOKE_ALL=1 npm run test:godot -- ui_smoke` | Alle aufgezeichneten Partien (bis Etage 3) durch die Oberfläche spielen, dauert einige Minuten |
| `xvfb-run godot --path godot -s res://tools/shot_ui.gd -- ordner modus` | Bildschirmfoto: `title`, `interview`, `game`, `dialog`, `walk`, `tabs`, `select`, `versus`, `talkshow`, `safe`, `floor3` (mit `PERF=1` auch Zeichenzeit der Karte) |
| `xvfb-run godot --path godot -s res://tools/shot_sprites.gd -- bild.png` | Alle Kreaturen als Bogen, zum Vergleich mit der Web-Version |

## Tests

| Test | Prüft |
|---|---|
| `test_rng`, `test_map`, `test_data` | Zufall, Sichtfeld, Wegfindung, Daten |
| `test_replay` | Drei aufgezeichnete Partien (bis Etage 3): jeder Zug identisch zur TypeScript-Version |
| `test_ui_parity` | Anzeige-Helfer (Uhrzeit, nächste Ziele, Bodenmaterial, Zufall je Kachel, Beschreibungen) identisch zur TypeScript-Version |
| `test_ui_smoke` | Eine Partie komplett über die Spielansicht gespielt: keine Laufzeitfehler, Spielverlauf unverändert |
| `test_sound` | Klänge hörbar und nicht übersteuert |

## Grundsätze

- **Eine Quelle für Inhalte:** Inhalte werden nur in `src/data` geändert und
  mit `npm run export:godot` exportiert.
- **Bitgenau gleiche Logik:** Jeder portierte Baustein hat einen Vergleichstest
  gegen die TypeScript-Version (gleicher Seed, gleiches Ergebnis).
- **Spielstand als JSON:** Der Zustand ist ein Dictionary im selben Format wie
  in TypeScript; Spielstände liegen in `user://run.json` und `user://meta.json`.
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
