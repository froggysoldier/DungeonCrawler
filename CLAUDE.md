# Projektregeln

- Spiel „Der Große Abstieg“: TypeScript + Vite, Spiellogik in `src/engine`, Inhalte in `src/data`, Oberfläche in `src/ui`.
- Sprache im Spiel: Deutsch.
- **Keine Emojis** in Oberfläche, Spieltexten oder Logs. Nur klare Schrift, Text und Wörter.
- Monster und Gegenstände werden über `src/engine/identify.ts` angezeigt: Namen und Werte nie direkt ausgeben, sondern `nameOf`/`describeMonster`/`itemName`/`describeItem` verwenden.
- Keine Spoiler aus den Büchern nach Buch 1; eigene Namen statt Figuren aus den Büchern.
- Vor dem Committen: `npm test` und `npm run build`. Web-Link: `npm run build:artifact`.
