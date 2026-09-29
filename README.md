# Der Große Abstieg

Ein rundenbasierter Dungeon-Crawler in Pixel-Grafik, gebaut mit Godot 4.7.2 –
inspiriert von *Dungeon Crawler Carl*. Du bewegst dich über eine klickbare
Karte, kämpfst mit Fäusten, Füßen, Knien und Steinen, und eine zynische
Systemstimme kommentiert alles.

## Starten

`godot/project.godot` im Godot-Editor 4.7.2 öffnen und F5 drücken.

```bash
./test.sh                                                   # alle Tests (GODOT=/pfad/zu/godot, falls nicht im PATH)
godot --headless --path godot -s res://tools/balance_sim.gd # Balance-Simulation (30 Bot-Partien)
godot --headless --path godot -s res://tools/record_fixtures.gd  # Replay-Aufnahmen erneuern
```

Inhalte (Monster, Gegenstände, Skills, Achievements …) stehen in
`godot/data/*.json`, die Pixel-Grafik als bearbeitbare PNG-Bögen in
`godot/assets/pixel`. Aufbau, Werkzeuge und Export (Web, Windows, Linux) stehen
in [`docs/GODOT_PORT.md`](docs/GODOT_PORT.md).

Die frühere Web-Version (TypeScript) ist entfernt; ihr letzter Stand liegt im
Git-Verlauf bei Commit `8b139bb`.

## Steuerung

| Aktion | Maus | Tastatur |
|---|---|---|
| Laufen | Klick auf ein bekanntes Feld | Pfeiltasten / Numpad (gedrückt halten = weiterlaufen) |
| Angreifen | Klick auf Gegner | In Gegner hineinlaufen |
| Körperteil wählen | Aktionsleiste | 1–7 (Faust, Tritt, Knie, Ellbogen, Kopfstoß, Waffe, Wurf) |
| Ausführung wählen | Aktionsleiste | Q Normal · W Sprung · E Stampfen · R Anlauf |
| Trefferzone wählen (Kampf) | Kampfpanel | Y Kopf · X Körper · C Arme · V Beine |
| Ziel wechseln / angreifen (Kampf) | Kampfpanel | Tab / Enter |
| Tür öffnen | In die Tür hineinlaufen | Pfeiltaste |
| Warten | Klick auf dich selbst | Leertaste |
| Aufheben | Klick auf dich selbst / Button | G |
| Treppe nehmen | Button | Enter |
| Klassenfähigkeit (ab Etage 3) | Button | F |
| Mit Crawlern reden | Klick auf den Crawler | – |
| Falle entschärfen / aufstellen | Button im Seitenbereich / im Inventar | – |
| Handwerk | Tab „Handwerk“ | – |
| Reittier auf- / absteigen | Button im Crawler-Tab | M |
| Untersuchen | Klick auf Gegenstand, Möbel, Falle oder Treppe (zweiter Klick läuft hin) / Rechtsklick | – |
| Safe-Room-Möbel benutzen | Hineinlaufen (Automat, Wirt, Händler, Bett, Toilette) | Pfeiltaste |
| Zoom | Mausrad / Knöpfe unten rechts | + / - |
| Übersichtskarte vergrößern | Klick auf die kleine Karte | K |
| Hilfe (alle Tasten) | Knopf „Hilfe“ | H |

## Umfang (Etage 1–3)

- über 600 Achievements (Familien, Bestiarium, besondere Momente) plus dynamische Muster
- 30 Skills in sieben Gruppen, dazu selbst entdeckte Skills
- 49 Klassen und 24 Rassen mit Begabungen, Sondereigenschaften und 25 Fähigkeiten
- Zustände im Kampf: Blutung, Brennen, Gift, Furcht, Blindheit
- Statistik über alles, was du im Dungeon tust
- Eingerichtete Safe Rooms: Gratis-Automat in jedem, Wirt im Restaurant, Händler, Bett und Toilette
- Boss-Kammern mit Vorraum und roter Eisentür: drinnen verriegelt, Versus-Bildschirm zum Auftakt
- Kampfmodus mit Banner, rotem Rahmen und Bilanz am Ende
- Am Boden liegt nur Handwerksmaterial; echte Beute gibt es im Vorraum der Boss-Kammern

## Dokumentation

Das Spielkonzept steht in [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).
