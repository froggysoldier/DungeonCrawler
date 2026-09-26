# Projektregeln

- Spiel „Der Große Abstieg“: TypeScript + Vite, Spiellogik in `src/engine`, Inhalte in `src/data`, Oberfläche in `src/ui`.
- Sprache im Spiel: Deutsch.
- **Keine Emojis** in Oberfläche, Spieltexten oder Logs. Nur klare Schrift, Text und Wörter.
- Monster und Gegenstände werden über `src/engine/identify.ts` angezeigt: Namen und Werte nie direkt ausgeben, sondern `nameOf`/`describeMonster`/`itemName`/`describeItem` verwenden.
- Spoiler-Regel: Buch 1 ist erlaubt. Aus Buch 2 nur allgemeine Spielmechaniken (Sponsoren, Quests, Haustier-Entwicklung, Reittiere), keine Handlung, Figuren, Orte oder Wendungen – der Nutzer hört Buch 2 noch (Stand: beim Magistrat). Ab Buch 3 nichts. Immer eigene Namen statt Figuren aus den Büchern.
- Vor dem Committen: `npm test` und `npm run build`. Web-Link: `npm run build:artifact`.
