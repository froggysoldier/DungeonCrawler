# Der Große Abstieg

Ein textbasierter, rundenbasierter Dungeon-Crawler im Browser – inspiriert von
*Dungeon Crawler Carl*. Du bewegst dich als leuchtender Punkt über eine
klickbare Karte, kämpfst mit Fäusten, Füßen, Knien und Steinen, und eine
zynische Systemstimme kommentiert alles.

## Starten

```bash
npm install
npm run dev      # Entwicklungsserver, dann http://localhost:5173 öffnen
```

Weitere Befehle:

```bash
npm test         # Engine-Tests
npm run build    # Typecheck + Produktions-Build nach dist/
npm run build:artifact   # eine einzige HTML-Datei für den Web-Link
SIM=1 npx vitest run tests/balance.sim.test.ts --silent=false   # Balance-Simulation (30 Bot-Runs)
```

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
