# Godot-Projekt

Das ganze Spiel läuft in Godot 4.7.2: Spiellogik, Karte, Figuren, Oberfläche,
Dialoge, Klänge und Speichern. Es wird nur noch hier entwickelt.

Die frühere Web-Version (TypeScript) ist entfernt. Ihr letzter Stand liegt im
Git-Verlauf bei Commit `8b139bb` („Port remaining Vitest suites …“), etwa mit
`git checkout 8b139bb -- src`. Bis dahin rechneten beide Versionen bitgenau
gleich; die Replay-Aufnahmen in `tests/fixtures` stammen ursprünglich aus der
Web-Version und werden jetzt in Godot selbst erzeugt (siehe unten).

Starten: `godot/project.godot` im Godot-Editor 4.7.2 öffnen und F5 drücken.
Die Hauptszene ist `scenes/main.tscn`.

## Aufbau

```
godot/
  project.godot          Godot 4.7, GL Compatibility (läuft auch im Browser)
  export_presets.cfg     Vorlagen für den Export: Web, Windows, Linux
  data/*.json            Inhalte (Monster, Gegenstände, Skills, Achievements …)
  scripts/core/          Zufall, Sichtfeld, Wegfindung, Datenzugriff, JS-Hilfen
  scripts/engine/        Spiellogik, ohne Grafik
  scripts/ui/            Oberfläche
  scenes/main.*          Einstieg: Titel, Interview, Spiel, Endbildschirm
  assets/pixel/          Pixel-Bögen (PNG) und index.json mit der Lage jedes Bildes
  assets/fonts/          Montserrat und Pixelify Sans (beide SIL Open Font License)
  tests/                 Testlauf, Tests, Replay-Bot und Aufnahmen (fixtures)
  tools/                 Werkzeuge: Bildschirmfotos, Aufnahmen, Balance-Simulation
```

### Oberfläche (`scripts/ui`)

| Datei | Inhalt |
|---|---|
| `pixel_art.gd` | Pixel-Bögen laden, Monsterfarben tönen, ganzzahlig vergrößert zeichnen |
| `pixel_box.gd` | Rahmen im Pixel-Stil für alle Flächen und Knöpfe (abgestufte Ecken, harter Schatten) |
| `tiles.gd` | Bodenmaterial je Raum, Mauerfarben je Etage, fester Zufall je Kachel |
| `map_view.gd` | Karte: statische Ebene (nur bei Änderungen neu), belebte Ebene, Nebel und Licht mit Dithering (Shader), Figuren, Effekte |
| `sprites.gd` | Welche Figur zu welcher Monsterart gehört, große Porträts |
| `animator.gd` | Gleiten, Kamera, Geschosse, aufsteigende Zahlen |
| `game_view.gd` | Spielansicht, Eingabe, Kampfmodus, Log |
| `game_here.gd`, `game_tabs.gd`, `game_combat.gd`, `game_dialogs.gd` | Seitenleiste, Reiter, Kampfsequenz, Tooltip, Versus, Talkshow, Hilfe |
| `selection.gd`, `screens.gd` | Rassen- und Klassenwahl, Titel, Interview, Ende |
| `modals.gd`, `typing.gd` | Dialoge mit Warteschlange, Schreibmaschinen-Effekt |
| `sound.gd` | Klänge im Spiel erzeugt, ohne Audiodateien |
| `ui_theme.gd`, `kit.gd`, `click_panel.gd` | Designsystem (Farben, Knöpfe, Karten) und Bausteine |

## Pixel-Grafik

Alles auf der Karte ist Pixel-Grafik mit 16 × 16 Pixeln je Kachel. Die Karte
vergrößert ganzzahlig (2× bis 5×, Mausrad oder + und −) und zeichnet ohne
Filter, damit jeder Pixel scharf bleibt. Die Kamera rastet auf Kunstpixel ein.
Nebel, Lichtkegel und Vignette werden von Shadern in Kunstpixeln gerastert und
mit einem Bayer-Muster gedithert, statt weich zu verlaufen.

Die Bilder liegen in `assets/pixel` als PNG-Bögen:

| Bogen | Inhalt |
|---|---|
| `kreaturen.png` | Kreaturen (mit zweiten Bildern), Spielfigur, Ausrüstungs-Aufsätze der Spielfigur (`ausruestung/…`), Haustier-Arten, Reittiere, Krone, Fragezeichen, Schlaf, Schatten, Ringe, Leuchten |
| `bosse.png` | Eigene Figuren der 15 Bosse, 24 × 24 Pixel; sie stehen auf ihrer Kachel und ragen darüber hinaus |
| `kacheln.png` | Böden (9 Materialien × 4 Varianten), Wände (3 Etagen × 4 Varianten, Krone und Vorderseite), Türen, Treppe |
| `dinge.png` | Gegenstände am Boden, Symbole der 15 Ausrüstungsplätze (`slot_…`), Fallen, Geschosse |
| `einrichtung.png` | Automat, Bett, Toilette, Theke, Kisten, Fässer, Regale, Gerümpel, Eimer, Flecken |

`index.json` hält fest, wo jedes Bild im Bogen liegt (Name → Bogen, x, y,
Breite, Höhe).

**Bearbeiten:** Die PNGs lassen sich in jedem Pixel-Editor ändern (Aseprite,
LibreSprite, Piskel, GIMP). Die Lage der Bilder im Bogen muss dabei gleich
bleiben. Stellen, die die Farbe des Monsters (bzw. der Seltenheit oder Box)
annehmen sollen, werden mit fünf Magenta-Stufen gemalt: `#400040` Schatten,
`#800080` dunkel, `#c000c0` Grundfarbe, `#ff00ff` hell, `#ff80ff` Glanz. Beim
Zeichnen ersetzt `PixelArt` sie durch eine Farbrampe aus der Monsterfarbe
(Schatten kühler, Licht wärmer). Alle anderen Farben bleiben, wie sie sind.

**Neu erzeugen:** Die Bögen wurden mit `tools/make_pixel_art.gd` aus den
Textvorlagen in `tools/pixel_defs.gd` und aus prozeduralen Mustern (Böden,
Wände, Türen) erzeugt. Der Generator legt Umriss und Schattierung automatisch
an. Er überschreibt vorhandene Bögen nur mit `--force`, damit Änderungen aus
einem Pixel-Editor nicht verloren gehen. Neue Monsterarten brauchen einen
Eintrag in `Sprites.BY_DEF`, neue Bosse eine eigene Figur (`boss/<id>`);
`test_pixel_art` prüft, dass es zu jedem Monster,
jeder Falle, jedem Reittier, jedem Möbelstück, jedem Gegenstand und jedem
Ausrüstungsplatz ein Bild gibt.

**Bewegung:** Fledermäuse, Motten, Tauben und Drohnen flattern, Irrlichter
flackern, Geister wabern, Schleime quellen, jeweils mit einem zweiten Bild
(Name mit `_2`). Spielfigur und Menschen haben ein Laufbild. Die Engine meldet
Angriffe (`Fx.strike`), Treffer (`Fx.hit`), Tode (`Fx.death`) und
Stufenaufstiege (`Fx.level_up`); der Animator zeigt daraus Ausfallschritt,
weißes Aufblitzen, Pixelzerfall, Beben bei schweren Treffern und goldene
Funken. Wandfackeln in gewöhnlichen Räumen, Boss-Kammern, Arenen und Gilden
flackern und hellen die Dunkelheit um sich auf. Haustiere erscheinen als ihre
Art (Katze, Hund, Kellerraptor, Minidrache …).

**Oberfläche:** Dieselben Bilder stehen auch neben dem Text.
`Sprites.item_sprite(it)` und `Sprites.monster_sprite(m)` liefern Bildname und
Farbe (Ausrüstung zeigt das Symbol ihres Platzes in Seltenheitsfarbe).
`Kit.icon` setzt ein Bild als Control ein (Gegenstandskarten, „Hier liegt“,
Ausrüstungsraster mit abgeblendeten leeren Plätzen, Zielkarten im Kampf),
`Kit.img` bettet es als `[img]` in BBCode ein (Tooltips auf der Karte). Der
Crawler-Reiter zeigt Spielfigur und Haustier.

**Ausrüstung an der Figur:** Für jeden sichtbaren Platz (Kopf, Gesicht, Hals,
Schultern, Brust, Rücken, Arme, Hände, Gürtel, Beine, Füße, Waffe) gibt es einen
Aufsatz im Raster der Spielfigur, ohne eigenen Umriss und in der
Seltenheitsfarbe getönt. `Sprites.hero_name(player)` legt die Aufsätze der
angelegten Teile über die Figur (der Rücken liegt dahinter), zieht einen Umriss
um das Ganze und stellt das Ergebnis samt Laufbild mit `PixelArt.register`
unter einem eigenen Namen bereit. Karte, Crawler-Reiter und Versus-Bildschirm
zeichnen diese Figur.

**Lootboxen öffnen:** Beim Öffnen wackelt eine Truhe in der Farbe der
Box-Stufe, springt auf (`ding/truhe_offen`, mit dem Box-Klang), strahlt und
sprüht Funken; danach erscheinen die Gegenstände (`GameDialogs.Chest`). Beim
Öffnen mehrerer Boxen zeigt die Truhe die beste Stufe.

**Schriften:** Fließtext in Montserrat, Überschriften, Knöpfe, Reiter und die
Karte in Pixelify Sans. Pixelify ist bei Größen in Zehnerschritten ganz
scharf (ein Schriftpixel = 1/10 der Größe).

## Werkzeuge

| Befehl | Zweck |
|---|---|
| `./test.sh [filter]` | Alle Tests headless ausführen (Godot-Pfad per `GODOT=…`, sonst `godot` im PATH). Laufzeitfehler (SCRIPT ERROR, push_error) zählen als Fehlschlag. Ohne Skript: `godot --headless --path godot -s res://tests/run_tests.gd [-- filter]` |
| `UI_SMOKE_ALL=1 ./test.sh ui_smoke` | Alle aufgezeichneten Partien (bis Etage 3) durch die Oberfläche spielen, dauert einige Minuten |
| `godot --headless --path godot -s res://tools/record_fixtures.gd` | Aufnahmen für die Replay-Tests neu erzeugen (Karten, Replays, Anzeige-Helfer), nach absichtlichen Änderungen an Inhalten oder Regeln |
| `godot --headless --path godot -s res://tools/balance_sim.gd [-- anzahl]` | Ein Bot spielt Partien bis Etage 3 und gibt eine Tabelle aus (Stufe, Kills, Todesursache …) |
| `xvfb-run godot --path godot -s res://tools/shot_ui.gd -- ordner modus` | Bildschirmfoto: `title`, `interview`, `game`, `dialog`, `walk`, `tabs`, `combat`, `ausruestung` (Inventar, Crawler-Reiter und Tooltip mit Ausrüstung und Haustier), `truhe` (Box öffnen in vier Bildern, Stufe mit `TIER=…`), `select`, `versus`, `talkshow`, `safe`, `floor3` (mit `PERF=1` auch Zeichenzeit der Karte), `fx` (Angriff in sechs Bildern, mit `BOSS=id` gegen einen Boss), `fackeln` |
| `xvfb-run godot --path godot -s res://tools/shot_sprites.gd -- bild.png [vergrößerung]` | Alle Monster in ihrer echten Farbe, dazu Spielfigur, Reittiere, Gegenstände, Fallen |
| `godot --headless --path godot -s res://tools/make_pixel_art.gd -- --force [--preview ordner]` | Pixel-Bögen aus den Vorlagen neu erzeugen (überschreibt Änderungen aus Pixel-Editoren) |

## Tests

| Test | Prüft |
|---|---|
| `test_rng`, `test_map`, `test_data` | Zufall, Sichtfeld, Wegfindung, Daten |
| `test_replay` | Drei aufgezeichnete Partien (bis Etage 3): jeder Zug identisch zur Aufnahme |
| `test_ui_helpers` | Anzeige-Helfer (Uhrzeit, nächste Ziele, Bodenmaterial, Zufall je Kachel, Beschreibungen) identisch zur Aufnahme |
| `test_engine`, `test_combat_zones`, `test_ai`, `test_skills` … | Spielregeln einzeln: Kampf, Gegner, Skills, Klassen, Magie, Fallen, Handwerk, Haustiere, Reittiere, Sponsoren, Talkshow, Achievements |
| `test_ui_smoke` | Eine Partie komplett über die Spielansicht gespielt: keine Laufzeitfehler, Spielverlauf unverändert |
| `test_sound` | Klänge hörbar und nicht übersteuert |
| `test_pixel_art` | Zu allem, was gezeichnet wird, gibt es ein Bild; Tönen ersetzt alle Magenta-Stufen; Haustier-Arten und zweite Bilder |
| `test_effects` | Engine meldet Angriff, Treffer, Tod und Aufstieg; Animator macht daraus Ausfallschritt, Aufblitzen, Zerfall, Beben, Funken |

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
| 7 – Pixel-Stil | Pixel-Bögen mit Generator, Karte ganzzahlig und gedithert, Pixel-Rahmen und Pixel-Schrift in der Oberfläche | erledigt |

## Export

In `export_presets.cfg` stehen Vorlagen für Web, Windows und Linux. Der Editor
braucht dafür die Export-Vorlagen von Godot 4.7.2 (Editor → Export-Vorlagen
verwalten). Auf der Kommandozeile:

```bash
godot --headless --path godot --export-release Web ../build/godot-web/index.html
godot --headless --path godot --export-release Linux ../build/godot-linux/DerGrosseAbstieg.x86_64
godot --headless --path godot --export-release Windows ../build/godot-windows/DerGrosseAbstieg.exe
```

Geprüft: Die Linux-Version startet fehlerfrei. Der Web-Export läuft in
Chromium mit Titel, Interview, Karte, Kampf und Tastatur. Die Web-Vorlage kommt
ohne Threads aus und läuft deshalb auf jedem einfachen Webserver (etwa
`python3 -m http.server` im Ausgabeordner). Die Klänge werden dort
nacheinander erzeugt, ein Klang pro Bild. Die Ausgabe landet in `build/`, das
nicht eingecheckt wird.

### Web-Link

`./web-link.sh` baut eine Fassung für einen claude.ai-Artifact-Link nach
`build/web-link`. Der Dienst liefert nur Dateien bis 15 MB und nur bestimmte
Dateitypen aus. Deshalb liegt die Engine gzip-gepackt als `engine.wasm` bei
(10 statt 39 MB) und die Spieldaten als `daten.wasm`. Die Seite
`godot/tools/web_link/index.html` leitet Godots Anfragen nach `index.wasm` und
`index.pck` darauf um und entpackt die Engine im Browser mit
`DecompressionStream`. Die Seite zeigt beim Laden Titel, Fortschritt und die
wichtigsten Tasten.

Entwicklerschalter: `--schnellstart` startet direkt eine Partie (Seed 1, ohne
Interview). Im Web geht das über `"args":["--schnellstart"]` in der
erzeugten `index.html`.
