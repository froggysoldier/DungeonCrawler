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
  assets/tinyswords/     Teile aus dem Tiny-Swords-Pack (Pixel Frog): Oberfläche, Wände, Wasser, Effekte
  assets/fonts/          Jersey 10 und Montserrat (beide SIL Open Font License)
  tests/                 Testlauf, Tests, Replay-Bot und Aufnahmen (fixtures)
  tools/                 Werkzeuge: Bildschirmfotos, Aufnahmen, Balance-Simulation
```

### Oberfläche (`scripts/ui`)

| Datei | Inhalt |
|---|---|
| `pixel_art.gd` | Pixel-Bögen laden, Monsterfarben tönen, ganzzahlig vergrößert zeichnen |
| `pixel_box.gd` | Einfache Pixel-Rahmen (Leisten, Tastenkappen, Fokus); Knöpfe und Karten nutzen die 9-Slices aus `assets/tinyswords/ui` |
| `tiles.gd` | Bodenmaterial je Raum, Mauerfarben je Etage, fester Zufall je Kachel |
| `map_view.gd` | Karte: statische Ebene (nur bei Änderungen neu), belebte Ebene, Nebel und Licht mit Dithering (Shader), Figuren, Effekte |
| `sprites.gd` | Welche Figur zu welcher Monsterart gehört, große Porträts |
| `animator.gd` | Gleiten, Kamera, Geschosse, aufsteigende Zahlen |
| `game_view.gd` | Spielansicht (Kopfzeile mit Reitern, Karte mit ausklappbarer Reiter-Tafel, rechts Werte, „Hier“ und Chat, unten Aktionsleiste), Eingabe, Laufen, Kampfmodus, Chat |
| `context_menu.gd` | Rechtsklick-Menü auf der Karte (Aktionen je Feld, hinlaufen und handeln) |
| `game_vitals.gd`, `game_here.gd`, `game_tabs.gd`, `game_combat.gd`, `game_dialogs.gd` | Feste Lebensanzeige, Seitenleiste, Reiter, Kampfsequenz, Tooltip, Versus, Talkshow, Hilfe, Menü |
| `selection.gd`, `screens.gd` | Rassen- und Klassenwahl, Titel, Interview, Ende |
| `modals.gd`, `typing.gd` | Dialoge mit Warteschlange, Schreibmaschinen-Effekt |
| `sound.gd` | Klänge und Musik im Spiel erzeugt, ohne Audiodateien: Brummen je Etage als nahtlose Schleife, zufällige Geräusche, Kampfschleife mit Überblenden |
| `ui_theme.gd`, `kit.gd`, `click_panel.gd` | Designsystem (Farben, Knöpfe, Karten) und Bausteine |

## Pixel-Grafik

Alles ist Pixel-Grafik im einheitlichen Raster von 32 × 32 Pixeln: Kacheln,
Monster, Bosse, Spielfiguren, Gegenstände, Einrichtung und Fallen. Die Karte
vergrößert ganzzahlig (1×, 2× oder 3×, also 32, 64 oder 96 Bildschirmpixel je
Kachel; Mausrad oder + und −) und zeichnet ohne Filter, damit jeder Pixel scharf
bleibt. Die Kamera rastet auf Kunstpixel ein.
Nebel, Lichtkegel und Vignette werden von Shadern in Kunstpixeln gerastert und
mit einem Bayer-Muster gedithert, statt weich zu verlaufen.

Die Bilder liegen in `assets/pixel` als PNG-Bögen:

| Bogen | Inhalt |
|---|---|
| `kreaturen.png` | Kreaturen (mit zweiten Bildern), Spielfigur (alte Einzelfigur), Haustier-Arten, Reittiere, Krone, Fragezeichen, Schlaf, Schatten, Ringe, Leuchten |
| `bosse.png` | Eigene Figuren der 15 Bosse |
| `kacheln.png` | Böden (9 Materialien × 4 Varianten), Türen, Treppe |
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

**Raster:** Die Vorlagen in `tools/pixel_defs.gd` sind im groben Raster
gezeichnet (16 × 16, Bosse 24 × 24, Spielfiguren und ihre Ausrüstung 20 × 20).
Der Generator verdoppelt sie mit Scale2x, das Schrägen glättet statt Blöcke zu
bilden, verkleinert Größeres spiegelgleich auf 32 × 32 und legt erst dann
Schattierung und Umriss an. Die Schattierung hat an der Schattenseite eine
gerasterte Reihe Halbschatten; bei Lebewesen bekommen kleine, fast quadratische
Augenflecken (schwarz, rot, gelb, cyan) einen weißen Glanzpunkt. Böden, Wände, Türen, Treppe, Flecken, Schatten,
Ringe und Geschosse entstehen direkt in 32 × 32.

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

**Spielfigur, Rassen und Ausrüstung:** Jede Rasse hat eine eigene Figur
(`held/<id>`) mit einem von vier Körperbauten
(normal; klein für Gnom, Halbling, Kobold, Fee; groß für Halbork, Troll, Oger,
Minotaurus, Golem; breit für Zwerg und Wasserspeier), eigenem Kopf und
Anbauten wie Schwänzen und Flügeln. `Sprites.RACE_LOOKS` nennt Hautfarbe und
Körperbau; `#` und die Stufen 1 – 5 in der Figur nehmen die Hautfarbe an. Die
Ausrüstung gibt es je Körperbau (`ausruestung/<bau>/<platz>`), getönt in der
Seltenheitsfarbe. `Sprites.hero_name(player)` setzt zusammen: Umhang, Figur,
Körperausrüstung, darüber noch einmal der Kopf (`held/<id>_kopf`: Bärte, Haare
und Kragen liegen über der Weste), dann Brille, Helm und Waffe; das Laufbild
entsteht, indem die Füße einen Schritt nach außen machen. Das Ergebnis bekommt
einen Umriss und wird mit `PixelArt.register` unter eigenem Namen abgelegt.
Karte, Crawler-Reiter, Versus-Bildschirm und Rassenwahl zeigen diese Figur.
Die Vorlagen stehen in `tools/pixel_defs.gd` (`HEROES`, `GEAR`).

**Lootboxen öffnen:** Beim Öffnen wackelt eine Truhe in der Farbe der
Box-Stufe, springt auf (`ding/truhe_offen`, mit dem Box-Klang), strahlt und
sprüht Funken; danach erscheinen die Gegenstände (`GameDialogs.Chest`). Beim
Öffnen mehrerer Boxen zeigt die Truhe die beste Stufe.

## Stil: Tiny Swords

Grafik und Oberfläche folgen dem Asset-Pack **Tiny Swords** von Pixel Frog
(Rohdateien in `asset-pack/`). Kennzeichen des Stils, an die sich alles hält:

- Kontur in Nachtblau `#161c2e` statt Schwarz, Schatten laufen zum Nachtblau,
  Licht zu warmem Creme (`PixelArt.ramp`). Gedämpfte, leicht entsättigte
  Farben: Schiefer, Sand, Gold, Teal (`PixelArt.PALETTE`).
- Wände sind die Klippen des Tilesets: oben die Felsfläche mit gewelltem Rand,
  zum Raum hin die Felswand aus Steinblöcken. Je Etage umgefärbt (Etage 1
  Erdbraun und Teal, Etage 2 Betongrau, Etage 3 Moos).
  `MapView.wall_cell` wählt das Feld im Klippen-Block (4 Spalten × 6 Reihen).
- Wasser und Kanäle: flaches Teal mit animierter Gischt an jedem Ufer.
- Effekte aus dem Pack: Staubwolke beim Besiegen, Explosion bei Bomben,
  Feuer bei Feuergeschossen (`MapView.FX`).
- Oberfläche: Knöpfe sind die 9-Slice-Knöpfe des Packs, für helle Schrift
  dunkel umgefärbt (Schiefer normal, gelber Rand bei Hover und Auswahl, Gold
  für Hauptaktionen, Rot für Gefahr, Grau für deaktiviert). Karten, Dialoge,
  Hinweise und Meldungen sind das Schieferpapier mit Goldecken, Schilder
  (Kopfzeile, Reiter) geschnitztes Holz, Abschnittsüberschriften gelbe Bänder.
  Balken haben einen Holzrahmen mit Rinne wie die Balken des Packs.

- Figuren aus dem Pack, mit ihren Animationen (Ruhebilder `Name`, `Name_2` …,
  Laufbilder `Name_lauf1` …; Bogen `einheiten.png`, 128 × 128, zwei Bildpixel
  je Kunstpixel):
  - Spielfigur: der blaue Arbeiter. Darüber liegt die sichtbare Ausrüstung
    (`GearLook`): je Platz einige Formen (Helm, Mütze, Kappe, Hut, Spitzhut,
    Krone, Stirnband; Brille, Schutzbrille, Maske, Nase; Jacke, Shirt, Mantel,
    Weste; Umhang, Rucksack; Schläger, Werkzeug, Messer, Pfanne, Tasche;
    Handschuhe, Armschienen, Hose, Stiefel, Gürtel, Kette, Schal, Polster),
    die Form nach dem Gegenstand (`GearLook.VARIANT_OF`), die Farbe nach der
    Seltenheit. Jedes Teil hängt an einem Ankerpunkt (Kopf, Körper, Hände,
    Füße), der für jedes Ruhe- und Laufbild aus der Figur bestimmt wird
    (`assets/tinyswords/anker.json`, von `tools/make_pixel_art.gd`).
    Vorschau: `godot --headless --path godot -s res://tools/shot_gear.gd -- ordner`.
  - Crawler, Menschen und menschliche Bosse: rote Einheiten (Arbeiter mit
    Werkzeug, Krieger, Bogenschütze, Mönch), Teamfarbe in der Farbe der Art;
    Untote mit fahler Haut.
  - Kobolde, Gnome, Trolle, Fischmenschen: die Goblins des Packs (Fackel,
    Dynamit) mit abgewandelter Hautfarbe; Mimiks sind der Fass-Goblin.
  - Wolpertinger: das Schaf.
  - Aus dem Tiny RPG Character Pack (`asset-pack/Assets/Tiny RPG …`, drei-
    oder vierfach vergrößert auf eine Bildfläche von 192, Namen `rpg_…`): Schleime
    (umgefärbt), Fledermaus, Skelette (Ghul, Moorleiche, Kellermeister,
    Schleusenwärter), Orks (Troll-Lehrling, Morlock, Schwarzmarkt-Oger),
    Werbär (Brückentroll), Werwolf (Hunde), Totenbeschwörer (Nachtmahr),
    Zauberer (Kanalhexe), Axtkämpfer (Abtrünniger Crawler), Ork-Reiter (Schmuggler-Kobold). Die anderen
    Crawler sind Ritter, Templer, Soldat, Schwertkämpfer, Bogenschützin,
    Lanzenreiter, Priester, Magier oder Arbeiter, je Crawler fest (`Sprites.crawler_sprite`).
  - Royal Mage (`asset-pack/Assets/Royal Mage Sprite Sheet.png`, dreifach
    vergrößert, Name `magier`): einer der anderen Crawler. Seine Zauberkugel
    (`fx/zauber_flug`, acht Bilder, in Flugrichtung gedreht) ist das Geschoss
    aller magischen Angriffe, `fx/zauber_treffer` der Aufschlag.
- Angriffe: Jede Pack-Figur hat Angriffsbilder (`Name_angriff1 …`): Schlag,
  Wurf, Schuss, Zauber. Die Spielfigur schlägt mit dem Arbeiter-Angriff des
  Packs, aus dem das Messer entfernt ist (`_without_knife`): sie kämpft mit
  dem, was sie trägt. Die Ausrüstung sitzt auch dabei (Anker je Bild, die
  Hand ist im Angriff die äußerste Hautstelle). Angriffsbilder liegen auf
  einer größeren Fläche (192 statt 128, Tiny RPG 256 statt 192), die Füße
  gleich weit über dem unteren Rand; `map_view._figure` gleicht das aus. Der
  Animator merkt sich Beginn und Richtung jedes Angriffs (`attack_frame`,
  `attack_dir`), 70 ms je Bild. Selbst gebaute Kreaturen und Bosse bekommen
  vier Angriffsbilder aus ihrer eigenen Figur (`make_pixel_art._lean`:
  ausholen, nach vorn schnellen, zurückfedern, Füße fest).
- Treffer und Tod: Tiny-RPG-Figuren und der Magier haben eigene Treffer-
  (`_treffer1 …`) und Todesbilder (`_tod1 …`); die Tiny-Swords-Figuren werden
  beim Tod zum Schädel des Packs (`Factions/Knights/Troops/Dead`). Alle
  anderen Figuren, auch die Spielfigur, weichen bei Treffern zurück
  (`make_pixel_art._add_flinch`); selbst gebaute Kreaturen zerfallen beim Tod
  weiter in Pixel und Staub. Der Animator spielt Treffer mit 80 ms, Tod mit
  90 ms je Bild (`hurt_frame`, Bursts mit Todesbildern dauern länger).
- Tod der Spielfigur: Sie kippt mit ihrer Ausrüstung nach hinten um
  (gedreht um die Füße), es staubt und bebt beim Aufprall, ihr Geist steigt
  auf und verblasst (`Animator.player_death`, `map_view._draw_player_death`,
  1,8 s). Erst danach öffnet `game_view` das Fenster „Tot.“.
- Größen: Tiny-RPG-Menschen und der Magier dreifach, kleine Skelette, Orks
  und Werbär vierfach vergrößert, damit sie neben der Spielfigur stimmen.
- Übrige Kreaturen und Bosse (Tiere, Schleime, Geräte wie Toaster, Waschmaschine, Parkautomat und Rohrgolem …) gibt es im Pack
  nicht. Sie sind aus Formen gebaut (`tools/ts_figures.gd`) und werden von
  `TsRender` wie die Pack-Figuren schattiert: dicker Nachtblau-Umriss, feine
  Linien zwischen den Teilen, schmale Lichtkante oben links, Schattenband
  unten rechts. Vorschau: `godot --headless --path godot -s res://tools/shot_ts.gd -- bild.png [namen]`.
- Gold wird beim Drüberlaufen eingesammelt, die Kamera folgt dem Crawler ohne
  Verzögerung, die Übersichtskarte liegt oben links.

`tools/import_tinyswords.gd` holt die Teile aus `asset-pack/`, setzt die
Bögen mit Lücken zu 9-Slices zusammen, färbt um und verkleinert Knöpfe auf
halbe Größe (Umrisse bleiben erhalten). Was das Pack nicht hat (Gegenstände,
Möbel, Böden), zeichnen die eigenen Vorlagen im selben Stil:
Nachtblau-Kontur, Rampe zu Creme, Palette des Packs.

**Lizenz:** Tiny Swords von Pixel Frog (pixelfrog-assets.itch.io). Nutzung
in eigenen Spielen erlaubt; das Pack selbst darf nicht weiterverteilt oder
verkauft werden. Siehe `assets/tinyswords/LIZENZ.md`.

**Schrift:** Jersey 10 überall (Titel, Knöpfe, Reiter, Werte, Chat, Texte,
Karte), ohne Kantenglättung. Sie wirkt bei gleicher Punktzahl kleiner als
eine normale Schrift; `UiFonts.px()` rechnet alle Größen der Oberfläche um
(Faktor 1,45). Montserrat liefert nur noch Zeichen, die Jersey fehlen.

## Werkzeuge

| Befehl | Zweck |
|---|---|
| `./test.sh [filter]` | Alle Tests headless ausführen (Godot-Pfad per `GODOT=…`, sonst `godot` im PATH). Laufzeitfehler (SCRIPT ERROR, push_error) zählen als Fehlschlag. Ohne Skript: `godot --headless --path godot -s res://tests/run_tests.gd [-- filter]` |
| `UI_SMOKE_ALL=1 ./test.sh ui_smoke` | Alle aufgezeichneten Partien (bis Etage 3) durch die Oberfläche spielen, dauert einige Minuten |
| `godot --headless --path godot -s res://tools/record_fixtures.gd` | Aufnahmen für die Replay-Tests neu erzeugen (Karten, Replays, Anzeige-Helfer), nach absichtlichen Änderungen an Inhalten oder Regeln |
| `godot --headless --path godot -s res://tools/balance_sim.gd [-- anzahl]` | Ein Bot spielt Partien bis Etage 3 und gibt eine Tabelle aus (Stufe, Kills, Todesursache …). Er verteilt Wertepunkte, legt bessere Ausrüstung an, liest Zauberbücher, heilt mit Zauber und Tränken, verbindet Blutungen, löscht Brand, geht rechtzeitig zur Toilette, schläft im Safe Room und greift Monster an, die den einzigen Weg versperren. `SEED=n` spielt nur diese Partie und zeigt das Ende des Protokolls, `FROM=n` beginnt bei Seed n (für parallele Läufe), `BOXES=1` zeigt, woher Achievements und Boxen kamen, und zählt die Boxen je Etage und Stufe (`BOXES=2` auch je Boxtyp), `LEAVE=0.7` steigt erst nach 70 % der Etagenzeit ab, `ARRIVALS=1` zeigt Stufe und Werte bei jeder Ankunft, `SNAPDIR=pfad` speichert den Crawler bei Ankunft, `STOPAT=3` hört nach der Ankunft auf Etage 3 auf |
| `godot --headless --path godot -s res://tools/calib_sim.gd -- <snapdir> [duelle]` | Lässt die gespeicherten Crawler gegen jede normale Monsterart ihrer neuen Etage antreten (ohne Tränke): Siegquote und verlorene HP am Etagenanfang und in der Mitte, je Abgangszeitpunkt. `BOSSES=1` auch gegen die Bosse, `SCALE2/3=hp,dmg` und `BOSSSCALE2/3=hp,dmg` probieren andere Faktoren, `ONLY=E2` eine Etage |
| `godot --headless --path godot -s res://tools/duel_sim.gd [-- etage stufe duelle]` | Duelle Crawler gegen jedes Monster und jeden Boss einer Etage: Siegquote, verlorene Lebenspunkte, Züge. `KIT=1` gibt typische Ausrüstung und zwei Heiltränke, `MLVL=n` setzt die Monsterstufe, `BOSSONLY=1` nur Bosse, `NOSPECIAL=1` ohne Spezialangriffe |
| `xvfb-run godot --path godot -s res://tools/shot_ui.gd -- ordner modus` | Bildschirmfoto: `title`, `interview`, `game`, `dialog`, `walk`, `tabs`, `combat`, `ausruestung` (Inventar, Crawler-Reiter und Tooltip mit Ausrüstung und Haustier), `truhe` (Box öffnen in vier Bildern, Stufe mit `TIER=…`), `select`, `versus`, `talkshow`, `safe`, `floor3` (mit `PERF=1` auch Zeichenzeit der Karte), `bildschirm` (Highlights im Safe Room mit Einladung), `grube` (Gladiatorenkampf), `fx` (Angriff in sechs Bildern, mit `BOSS=id` gegen einen Boss), `fackeln` |
| `xvfb-run godot --path godot -s res://tools/shot_sprites.gd -- bild.png [vergrößerung]` | Alle Monster in ihrer echten Farbe, dazu Spielfigur, Reittiere, Gegenstände, Fallen |
| `godot --headless --path godot -s res://tools/make_pixel_art.gd -- --force [--preview ordner]` | Pixel-Bögen aus den Vorlagen neu erzeugen (überschreibt Änderungen aus Pixel-Editoren) |
| `godot --headless --path godot -s res://tools/import_tinyswords.gd` | Teile aus dem Tiny-Swords-Pack (`asset-pack/`) nach `assets/tinyswords` holen, zusammensetzen und umfärben |
| `xvfb-run godot --path godot -s res://tools/shot_map.gd -- bild.png [seed] [zoom] [etage] [alles]` | Nur die Karte; `alles` deckt die ganze Karte ohne Nebel und Dunkelheit auf (zum Begutachten der Grafik) |

## Tests

| Test | Prüft |
|---|---|
| `test_rng`, `test_map`, `test_data` | Zufall, Sichtfeld, Wegfindung, Daten |
| `test_replay` | Drei aufgezeichnete Partien (bis Etage 3): jeder Zug identisch zur Aufnahme |
| `test_ui_helpers` | Anzeige-Helfer (Uhrzeit, nächste Ziele, Bodenmaterial, Zufall je Kachel, Beschreibungen) identisch zur Aufnahme |
| `test_engine`, `test_combat_zones`, `test_ai`, `test_skills` … | Spielregeln einzeln: Kampf, Gegner, Skills, Klassen, Magie, Fallen, Handwerk, Haustiere, Reittiere, Sponsoren, Talkshow, Achievements |
| `test_ui_smoke` | Eine Partie komplett über die Spielansicht gespielt: keine Laufzeitfehler, Spielverlauf unverändert |
| `test_dungeon` | Gelände und Sonderräume: entstehen, alles bleibt erreichbar, Kisten, Schlamm, Wasser, Schlüssel, Schloss knacken, Geheimtür, Schrein, Nest, Hinterhalt, Wanderhändler |
| `test_boss_fight` | Bosskämpfe: Daten vollständig, Ankündigen und Treffen, Ausweichen, Pause, Ansturm, Formen, Phasen mit Verstärkung |
| `test_kanalstadt` | Etage 3: Kanäle und Brücken, alles erreichbar, Siedlung mit drei Händlern und Bewohnern ohne Monster, neue Monster mit Bild und Bestiarium |
| `test_show_events` | Einlagen erst nach dem Tutorial, kommen und gehen, Doppelte Erfahrung, Licht aus, Goldrausch, Schnäppchen, Kopfgeld (Auszahlung und Verfall), Ende beim Abstieg, neue Verbrauchsgegenstände, Kopfgeld-Sponsor |
| `test_layout` | Kartenaufbau: Hauptgänge, drei Safe Rooms außerhalb des Start-Viertels, Reviere mit einer Art und Nachschub nur dort, keine herumliegenden Gegenstände, Toiletten außerhalb der Safe Rooms, wenige Crawler fern vom Start, Karte von Anfang an, Gegenstände aus der Entfernung, Waffe bleibt, Werte vor der Klassenwahl |
| `test_show` | Uhrzeit, Highlight-Sendung um 21 Uhr (nur mit Publikum, Auftritt durch besondere oder viele Kills, Bildschirm, Tipp der Redaktion), Einladungen (annehmen, absagen, verfallen), Fragerunde, Talkshow und Diskussionsrunde bis zum Ende, Show zwischen den Etagen nur für Bekannte, Gladiatorenkampf in der Grube (Sieg, k. o. statt Tod, Etage wartet) |
| `test_boxes` | Boxinhalt passt zum Typ, Wurf- und Überlebens-Boxen mit Verbrauchsgut, ab Gold ein magischer Gegenstand, Meister-Gold auf Etage 1, 5 % Ausrüstung von Mobs, Gold tiefer häufiger, Platin nur über Meisterleistungen |
| `test_tiefgarage` | Etage 2: Parkdecks, Wracks und Öl entstehen, alles erreichbar, Wrack durchsuchen, Alarmanlage, Ausrutschen und brennendes Öl, eigene Bosse und Monster mit Bild, Beute und Bestiarium |
| `test_sound` | Klänge hörbar und nicht übersteuert; Musik in Schleife, ohne Naht, alle Geräusche vorhanden |
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
| 8 – Tiny Swords | Palette, Knöpfe, Papier, Bänder und Balken aus dem Pack, Klippenwände je Etage, Wasser mit Gischt, Effekte | erledigt |

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
