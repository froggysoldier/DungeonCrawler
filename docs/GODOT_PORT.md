# Umbau auf Godot 4.7.2

Ziel: dasselbe Spiel in Godot, mit echter Grafik (Sprites, Licht, Animationen)
und Export für Desktop und Web. Die Web-Version bleibt als **Referenz**
bestehen, bis die Godot-Version alles kann; erst dann wird sie entfernt.

## Aufbau

```
godot/
  project.godot          Godot 4.7, GL Compatibility (läuft auch im Browser)
  data/*.json            Inhalte, erzeugt aus src/data (nicht von Hand ändern)
  scripts/autoload/      GameData: lädt alle JSON-Tabellen
  scripts/core/          Spiellogik ohne Grafik (Port von src/engine)
  scenes/                Szenen und Oberfläche
  assets/                Sprites, Schriften, Klänge
  tests/                 Testlauf, Tests und Vergleichswerte (fixtures)
```

## Werkzeuge

| Befehl | Zweck |
|---|---|
| `npm run export:godot` | Inhalte aus `src/data` nach `godot/data` und Vergleichswerte nach `godot/tests/fixtures` schreiben |
| `npm run test:godot` | Godot-Tests headless ausführen (Godot-Pfad per `GODOT=…`, sonst `godot` im PATH) |

`godot/data/EXPORT_REPORT.md` listet, welche Regeln nur als Funktion
existieren (Achievement-Bedingungen, Skill-Effekte …) und in GDScript
nachgebaut werden müssen.

## Grundsätze

- **Eine Quelle für Inhalte:** Während des Umbaus werden Inhalte nur in
  `src/data` geändert und exportiert. Danach wandern sie ganz nach Godot.
- **Bitgenau gleiche Logik:** Jeder portierte Baustein bekommt einen Test,
  der ihn mit der TypeScript-Version vergleicht (gleicher Seed, gleiches
  Ergebnis). So fällt jeder Übertragungsfehler sofort auf.
- **Spielstand als JSON:** Der Zustand bleibt ein einfaches Dictionary im
  selben Format wie in TypeScript. Dadurch lassen sich Zustände direkt
  vergleichen, und Spielstände bleiben übertragbar.
- **Logik und Darstellung getrennt:** `scripts/core` kennt keine Nodes und
  keine Grafik; Szenen lesen den Zustand und zeigen ihn an.
- **GDScript statt C#:** C# lässt sich in Godot 4 nicht für das Web exportieren.
- Projektregeln aus `CLAUDE.md` gelten weiter (Deutsch, keine Emojis,
  Anzeige über die Identify-Funktionen, Spoiler-Regel).

## Fahrplan

| Phase | Inhalt | Prüfung |
|---|---|---|
| 0 – Fundament (erledigt) | Projekt, Datenexport, Zufall, Sichtfeld, Wegfindung, Testlauf | Zufall, Sichtfeld und Wege identisch zu TypeScript |
| 1 – Welt | Spielstand, Kartengenerator, Monster und Gegenstände erzeugen, Identifizieren | Gleicher Seed ergibt gleiche Etage |
| 2 – Spielschleife | Bewegung, Züge, Kampf, KI, Zustände, Türen, Fallen | Aufgezeichnete Zugfolgen ergeben in beiden Versionen denselben Zustand |
| 3 – Systeme | Skills, Stufen, Achievements, Statistik, Klassen, Rassen, Boxen, Sponsoren, Quests, Haustiere, Reittiere, Magie, Handwerk, Laden, Crawler, Talkshow, Zuschauer | wie Phase 2, dazu die bestehenden Vitest-Fälle als GDScript-Tests |
| 4 – Darstellung | TileMap mit Tileset, animierte Kreaturen-Sprites, Kamera, Licht und Nebel, Oberfläche mit eigenem Theme, Log mit Schreibmaschinen-Effekt, Klänge, Versus-Bildschirm, Kampfbanner | Durchspielen und Screenshots |
| 5 – Abschluss | Interview und Titelbildschirm, Speichern und Laden, Export (Web, Windows, Linux, macOS) | Komplettes Durchspielen von Etage 1–3 |

## Offene Entscheidungen

- **Grafikstil:** Pixel-Art (z. B. freie CC0-Pakete oder eigene Sprites) oder
  gezeichneter Stil. Davon hängen Tile-Größe und Kamera ab.
- **Zielplattformen:** Nur Desktop oder auch Web und Mobil.
