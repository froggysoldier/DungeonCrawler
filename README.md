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
| Laufen | Klick auf ein bekanntes Feld | Pfeiltasten / Numpad |
| Angreifen | Klick auf Gegner | In Gegner hineinlaufen |
| Körperteil wählen | Aktionsleiste | 1–7 (Faust, Tritt, Knie, Ellbogen, Kopfstoß, Waffe, Wurf) |
| Ausführung wählen | Aktionsleiste | Q Normal · W Sprung · E Stampfen · R Anlauf |
| Warten | Klick auf dich selbst | Leertaste |
| Aufheben | Klick auf dich selbst / Button | G |
| Treppe nehmen | Button | Enter |
| Klassenfähigkeit (ab Etage 3) | Button | F |
| Mit Crawlern reden | Klick auf den Crawler | – |
| Falle entschärfen / aufstellen | Button im Seitenbereich / im Inventar | – |
| Handwerk | Tab „Handwerk“ | – |
| Untersuchen | Rechtsklick | – |

## Dokumentation

Das Spielkonzept steht in [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).
