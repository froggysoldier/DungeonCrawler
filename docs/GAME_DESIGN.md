# Der Große Abstieg – Game Design Dokument (v0.4)

> Inspiriert von der Buchreihe *Dungeon Crawler Carl* von Matt Dinniman.
> **Spoiler-Regel:** Dieses Dokument enthält nur Buch-Details bis einschließlich
> Buch 1 (Etagen 1–2). Alles ab Etage 3 ist unser eigenes Design.

---

## 1. Vision

Ein **textbasierter, rundenbasierter Dungeon-Crawler** im Browser. Der Spieler
bewegt sich als Punkt über eine **klickbare Karte**, alles andere wird über
Text erzählt – von einer zynischen Systemstimme. Ziel ist Tiefe: 18 Etagen,
Hunderte Achievements, Lootboxen, ein Kampfsystem, das erkennt, *wie* man
kämpft.

## 2. Getroffene Entscheidungen

| Frage | Entscheidung |
|---|---|
| Plattform | Browser-Spiel, TypeScript + Vite. Engine strikt getrennt von der UI. |
| Zeitmodell | Rundenbasiert. 1 Zug = 3 Minuten Spielzeit. |
| Sprache | Deutsch |
| Tod | Alle vier Konzepte (siehe Abschnitt 6) |
| Namen | Eigene Namen (Show, Guide, Bosse …), damit eine spätere Veröffentlichung möglich bleibt |
| Etagen | Themen dürfen sich am Buch orientieren, aber keine Spoiler |
| Oberfläche | Klickbare Karte, Spieler = leuchtender Punkt, daneben Panels + Textlog |
| Erster Meilenstein | Etage 1 komplett spielbar |
| Zweiter Meilenstein | Mehr Inhalte, Web-Link, Etage 2 (Publikum) und 3 (Rassen/Klassen) |

Oberfläche und Texte: **keine Emojis**, nur klare Schrift und Wörter.

Eigene Namen: Die Show heißt **„Der Große Abstieg“**, der Erzähler
**„die Systemstimme“**, der Standard-Guide **Barnabas**.

## 3. Systeme im aktuellen Stand

### 3.1 Spielstart: Das Vorher-Interview
Fünf Fragen (Beruf, Fitness, Haustier, Kleidung beim Weltuntergang,
Konfliktverhalten) bestimmen Start-Stats, Start-Skills (z. B. Pflege →
*Erste Hilfe*, Gamer → *Spielerfahrung*), Startkleidung, ein mögliches
Haustier (Katze/Hund) und versteckte Flags für die spätere Klassenwahl.

### 3.2 Welt & Karte
- Etage = 72×52 Kacheln, vier **Viertel** (Nachbarschaften) + zentrales Gewölbe.
- Räume mit Namen und Beschreibungen (Heizungskeller, Partykeller, Luftschutzbunker …).
- Sichtfeld (Fog of War). **Vor dem Tutorial keine Karte** – man sieht nur, was gerade in Sicht ist.
- **Einsturz-Timer**: 5 Tage (2400 Züge). Warnungen bei 24 h, 6 h, 1 h.
- Treppenhäuser: eins hinter dem Borough-Boss, zwei in abgelegenen Räumen.
- Boss-Kammern und Arena sind **Sackgassen mit genau einem Zugang**.

### 3.3 Freischaltungen
| Wann | Was | Status |
|---|---|---|
| Start | Nichts. Fäuste, Füße, ein Gegenstand in der Hand. | |
| Tutorial-Gilde gefunden | Inventar, Werte, Skills-Übersicht, Kartengedächtnis, 2 Heiltränke | |
| Etage 2 | Publikum: Zuschauer, Follower, Hype, Fan-Boxen, Geschenke | |
| Etage 3 | Rassen- & Klassenwahl, Klassenfähigkeiten | |
| Etage 9+ | NPC-Verträge | Engine-Hook vorhanden |

### 3.4 Kampf: Technik = Körperteil × Ausführung
- **Körperteil/Mittel:** Faust, Tritt, Knie, Ellbogen, Kopfstoß, Waffe, Wurf
- **Ausführung:** Normal, Sprung (+50 % Schaden, −10 % Treffer), Stampfen
  (nur auf liegende/winzige Gegner, ×1,8), Anlauf (nur nach Bewegung auf das Ziel zu, ×1,4)
- **Ausdauer** begrenzt starke Techniken.
- Tritte, Sprünge und Anlauf können Gegner **umwerfen** → Stampfen möglich.
- **Hinterhalt:** ahnungslose Gegner sind leichter zu treffen.
- Wurfobjekte (Steine, Ziegel, Dosen) landen nach dem Wurf am Boden und
  können wieder aufgehoben werden, Flaschen zerbrechen.
- Kopfstoß tut auch dir weh – außer du bist geübt.

### 3.5 Passives Skillsystem
Jede Aktion wird mitgezählt (z. B. `tritt+stampfen`). Ab einer Schwelle
entsteht ein Skill, Nutzung levelt ihn (max. Stufe 15):
Faustkampf, Treten, Stampfer, Sprungangriff, Sturmangriff,
Ellbogengesellschaft, Kniestoß, Kopfnuss, Werfen, Improvisierte Waffen,
Wuchtschlag (alle unbewaffneten), Meteor-Stampfer (Sprung-Tritt),
Hinterhalt, Ausweichen (durch Ausweichen), Zähigkeit (durch Einstecken).
Im Skills-Tab sieht man den Fortschritt („Du spürst Fortschritt …“) und
die Verteilung des eigenen Kampfstils.

### 3.6 Gegner
- 49 Mob-Typen auf Etage 1–3 (Kellerratte, Kobolde, Wolpertinger,
  Tatzelwurm, Grauer Späher, Blähkröte, Chupacabra, Kanal-Krokodil,
  Mottenmann …) mit Verhalten: Nahkampf, Fernkampf, feige, stationär (Mimics).
- **Fähigkeiten:** giftig (Gift-Schaden pro Zug, Gegengift hilft),
  explodiert beim Tod, klaut Gold und flieht, ruft Verstärkung,
  regeneriert, schnell (2 Schritte), fliegend (nicht umwerfbar, kein
  Stampfen), gepanzert (halber Faustschaden).
- Normale Monster betreten keine Boss-Kammern.
- **Elite-Mobs** (stärkere Varianten, bessere Beute).
- **15 Bosse**, jede Etage zieht aus ihrem eigenen Pool (Etage 1: Die Sammlerin,
  Der Hausmeister, König der Kanalratten, Muttis Mega-Mixer, Kammerjäger,
  Mutter aller Motten, Pfandflaschen-Baron, Heizungsbestie; Etage 3:
  Kanalkönigin, Kommandant Klärschlamm, Schwarzmarkt-Oger, Nixe vom Überlauf).
  Nachbarschafts-Bosse verlassen ihre Kammer nicht, solange
  sie leben spawnen im Viertel Mobs nach, droppen **Gebietskarte** (muss
  aufgehoben werden → deckt das Viertel auf) + Boss-Box + Unikat.
- **Borough-Bosse** je Etage: Oma Gulasch (1), Der Hausverwalter (2),
  Der Rattenkaiser (3) – die Treppe liegt direkt dahinter.
- Mobs fliehen bei wenig Leben, verlieren das Interesse, wenn man weit weg ist.

### 3.7 Safe Rooms
- Keine Gewalt; Mobs, die angreifen, werden weggebeamt.
- Zufällig **Gratis-Automat** (1 Gegenstand pro Crawler) oder **Restaurant**
  mit NPC-Wirt und Buff-Essen.
- Nur hier: **Lootboxen öffnen** und **schlafen** (8 h, heilt, Haustier kehrt zurück).
- 1 h vor Einsturz wird man hinausgeworfen.

### 3.8 Items
Rund 170 Gegenstände. 17 Ausrüstungsplätze inkl. 2 Ringe, **2 Fußringe** und Unterwäsche.
Seltenheiten Gewöhnlich → Ungewöhnlich → Selten → Episch → Legendär → Himmlisch,
zufällige Verzauberungen („Stahlkappenstiefel des Esels“), Unikate mit
Spezialeffekten (Zweite-Chance-Klausel, Stiefel des ungebremsten Stampfens,
Der Ziegel …), Verbrauchsgüter, Haustier-Leckerli.

### 3.9 Achievements & Lootboxen
- 143 Achievements mit sarkastischem Kommentar (z. B. *Komische Katzenlady*,
  *Barfuß-Rambo*, *Podophilie*, *Steinzeit*, *Pazifist (vorläufig)*).
- Boxen in 6 Stufen (Bronze → Himmlisch) und 11 Themen (Schuh-, Wurf-,
  Schläger-, Haustier-, Boss-Box …). Inhalt passt zum Thema.
- **Wer ein Achievement zum ersten Mal in seiner Karriere schafft, bekommt eine Box-Stufe mehr.**

### 3.10 Publikum (ab Etage 2)
- Spektakel (Stampf-Kills, Sprungtritte, Bosse, Achievements, knappe
  Rettungen, Explosionen …) erhöht **Hype** und bringt **Follower**.
- Charisma und Hype multiplizieren den Zuwachs, Hype kühlt mit der Zeit ab.
- Fan-Boxen bei 100 / 250 / 500 / 1.000 / 2.500 / 5.000 / 10.000 … Followern.
- Große Momente bringen manchmal Geschenke aus dem Publikum.
- Zuschauer-Kommentare im Log (Zuschauer xX_Glorbnak_Xx: „DRAUFGESTAMPFT HAHAHA“).

### 3.11 Rassen & Klassen (ab Etage 3)
- Man wird in die Gilde geholt und wählt **Rasse** und **Klasse**.
- 14 Rassen: 7 frei wählbar (Mensch mit +4 Stat-Punkten, Halbork, Kellerelf,
  Zwerg, Gnom, Halbling, Echsenmensch), 7 **durch Verhalten freigeschaltet**
  (Katzenmensch: mit Katze gestartet · Troll: 15 Gegner umgeworfen ·
  Minotaurus: 25 Kopfstöße/Sturmangriffe · Golem: 150 Schaden eingesteckt ·
  Pilzling: 20 Giftschaden · Vampir: 10 Krits · Kobold: 20 Würfe).
- 18 Klassen, jede wird **nach deinem bisherigen Kampfstil bewertet**; 8
  stehen zur Wahl, die 3 passendsten werden empfohlen.
- Jede Klasse hat eine **aktive Fähigkeit** mit Abklingzeit (Taste F):
  Wutanfall, Wirbelwind, Erdbeben, Kampfschrei, Bollwerk, Schattenschritt,
  Steinhagel, Bombe, Zweite Luft, Showtime.

### 3.12 Identifikation
Was man über Monster und Gegenstände erfährt, hängt vom Level-Abstand ab.
Abstand = Monsterlevel − eigenes Level − Intelligenz-Bonus (je 3 INT über 5: +1)
− Erfahrung mit dem Monstertyp (je 3 Kills: +1, max. +2).

| Abstand | Was man sieht |
|---|---|
| 0 oder weniger | Alles: Name, Level, HP, Schaden, Rüstung, Ausweichen, Fähigkeiten, Beschreibung, Trefferchance |
| 1–2 | Name, Level, HP, Fähigkeiten, Gefahr nur grob (gering/mittel/hoch/sehr hoch) |
| 3–4 | Name, Level als Bereich, Zustand statt HP, nur Anzahl der Fähigkeiten |
| 5–7 | Kein Name („ein unbekanntes großes Wesen“), nur Zustand; auf der Karte ein „?“ |
| 8+ | „Etwas sehr Gefährliches“, keine Informationen |

Gegenstände: Magische Eigenschaften sind ab einem Level lesbar (Selten 3,
Episch 6, Legendär 10, Himmlisch 15). Knapp darunter sieht man, *was*
verzaubert ist, aber nicht wie stark; weit darunter nur „Unbekannte magische
Eigenschaften“. Auch der Kampflog verwendet nur die Namen, die man kennt.

### 3.13 Haustiere / Reittiere, Party (geplant)
Katze oder Hund aus dem Interview: folgt, kämpft mit, levelt, wird bei 0 HP
bewusstlos und kehrt nach dem Schlafen zurück. Reittiere und Party-System
sind noch offen.

## 4. Tod & Hardcore (alle vier Konzepte)

1. **Permadeath + Staffeln:** Tod beendet den Run endgültig. Erhalten bleiben
   Hall of Fame, Karriere-Achievements, Bestiarium.
2. **Der Tote wird zum Mob:** Der gestorbene Crawler spukt in späteren Staffeln
   als Geist auf seiner Todesetage – mit seiner Ausrüstung als Beute.
3. **Vertrag als Rettung:** Wer (ab Etage 9) einen Vertrag unterschrieben hat,
   stirbt nicht, sondern wird zum Guide der nächsten Staffel (+1 auf drei Stats).
4. **Seltene Wiederbelebung:** Die legendäre *Zweite-Chance-Klausel* rettet
   einmal vor dem Tod – mit dauerhaftem Fluch („Kleingedrucktes“).

## 5. Technik

```
src/
  engine/   Spiellogik, UI-unabhängig, deterministisch (Seed), JSON-Zustand
  data/     Inhalte: Monster, Items, Skills, Achievements, Interview, Welttexte
  ui/       Canvas-Karte, Panels, Dialoge
tests/      Vitest: Engine-Tests + optionale Balance-Simulation (SIM=1)
```

## 6. Nächste Schritte (Vorschlag)

1. Balance von Etage 2–3 durch Testspielen
2. Sponsoren, Quests und Fallen
3. Etage 4+ mit neuen Themen, Klassen-Spezialisierung (Etage 6/9/12)
4. Party-System, Reittiere
5. Sound, Grafik-Upgrade der Karte

## 7. Rechtliches
*Dungeon Crawler Carl* ist geistiges Eigentum von Matt Dinniman. Das Spiel
nutzt eigene Namen, Figuren und Texte. Mechaniken sind nicht geschützt.
