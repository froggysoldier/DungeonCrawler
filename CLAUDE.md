# Projektregeln

- Spiel „Der Große Abstieg“: TypeScript + Vite, Spiellogik in `src/engine`, Inhalte in `src/data`, Oberfläche in `src/ui`.
- Sprache im Spiel: Deutsch.
- **Keine Emojis** in Oberfläche, Spieltexten oder Logs. Nur klare Schrift, Text und Wörter.
- Monster und Gegenstände werden über `src/engine/identify.ts` angezeigt: Namen und Werte nie direkt ausgeben, sondern `nameOf`/`describeMonster`/`itemName`/`describeItem` verwenden.
- Spoiler-Regel: Aus Buch 1–3 dürfen nur Spielmechaniken und die Komplexität der Systeme übernommen werden (Achievements, Skills, Stufen, Klassen, Rassen, Boxen, Sponsoren, Quests, Haustiere, Reittiere …) – keine Handlung, Figuren, Orte oder Wendungen. Der Nutzer hört Buch 2 noch (Stand: beim Magistrat); in Antworten nichts aus späteren Kapiteln erwähnen. Fokus: Etage 1–3. Immer eigene Namen statt Figuren aus den Büchern.
- Vor dem Committen: `npm test` und `npm run build`. Web-Link: `npm run build:artifact`.
- Godot-Umbau (Godot 4.7.2, GDScript) liegt in `godot/`, Plan in `docs/GODOT_PORT.md`. Inhalte weiter nur in `src/data` ändern und mit `npm run export:godot` exportieren. Jeder portierte Baustein braucht einen Vergleichstest gegen die TypeScript-Version. Vor dem Committen zusätzlich `npm run test:godot`.
