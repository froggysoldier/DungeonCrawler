# Dungeon Crawler – Game Design Dokument (Entwurf v0.1)

> Inspiriert von der Buchreihe *Dungeon Crawler Carl* von Matt Dinniman.
> Status: Konzeptphase. Offene Fragen stehen am Ende des Dokuments.

---

## 1. Vision

Ein **textbasierter Dungeon-Crawler** mit Maus-Steuerung, der die Tiefe und den
schwarzen Humor der Buchreihe abbildet: 18 Etagen, eine zynische System-KI als
Erzähler, absurde Achievements, Lootboxen und ein Kampfsystem, das erkennt,
*wie* der Spieler kämpft, und ihn dafür belohnt.

- **Phase 1:** Singleplayer, textbasiert, Fokus auf Systemtiefe.
- **Später:** Grafische Oberfläche, Multiplayer (geteilte Hardcore-Instanz).
- **Architektur-Grundsatz:** Spiellogik (Engine) strikt getrennt von der
  Darstellung (UI), damit Text-UI später durch Grafik ersetzt und Multiplayer
  ergänzt werden kann.

---

## 2. Was die Bücher vorgeben (Recherche Bücher 1–3)

| Mechanik | Im Buch |
|---|---|
| Aufbau | 18 Etagen. Jede Etage hat einen **Einsturz-Timer** – wer bei Ablauf nicht im Treppenhaus ist, stirbt. |
| Treppenhäuser | Auf Etage 1 unbegrenzt betretbar; auf Etage 1 haben alle Borough- und City-Bosse ein Treppenhaus in ihrer Arena. |
| Tutorial-Gilde | Gildenhalle mit einem **Game Guide** (Mordecai). Erklärt Minimap, Stats, Sozialmenü. Auf Etage 3 kehrt man dorthin zurück für Rassen-/Klassenwahl. |
| Rasse & Klasse | Ab Etage 3. ~400 Rassen zur Wahl, ~80 % behalten ihre Rasse. Die KI erstellt **30+ individuelle Klassen** basierend auf Stats, Rasse, Gegenständen und *bisherigem Verhalten*, und empfiehlt 3. Spezialisierung auf Etage 6, 9, 12. |
| Bosse | Nachbarschafts-Bosse (Etage 1: Lvl 7–9, 4 pro Gebiet) → Borough-Bosse → City-/Länder-Bosse. Nach dem Tod eines Nachbarschafts-Bosses **spawnen dort keine Mobs mehr**. Etage-1-Bosse verlassen ihre Kammer nicht. Mobs Etage 1: Lvl 1–5. |
| Safe Rooms | Keine Gewalt, kein Diebstahl. Mobs, die angreifen, werden **zufällig im Umkreis von ~1,5 km weg-teleportiert**. Wer 1 h vor Einsturz noch drin ist, wird rausgeworfen. Ab Etage 2: Briefkasten. |
| Lootboxen | Dutzende Typen (Waffen-, Schuh-, Pet-, Boss-, Abenteurer-, Brawler-Box, „Lucky Bastard Box“ …) in **6 Stufen: Bronze → Silber → Gold → Platin → Legendär → Himmlisch (Celestial)**. Quellen: Achievements, Bosse (Boss-Boxen), Quests, Zuschauer (Fan-Boxen), Sponsoren. |
| Achievements | Absurd und zahlreich, von der KI sarkastisch kommentiert (z. B. *Podophilia!* → Goldene Schuh-Box). |
| Skills | Entstehen durch Nutzung: *Bare Knuckle/Pugilism* (+25 % Faustschaden/Stufe), *Powerful Strike* (Multiplikator unbewaffnet), *Iron Punch* (+10 % mit Panzerhandschuh), *Kicking* (+10 % Tritt/Stufe). |
| Zuschauer | Das Ganze ist eine Galaxis-weite Gameshow. Ab Etage 2: Follower, Favoriten, Ratings. Ab Etage 3: Sponsoren, Bestenliste, Kopfgelder auf die Top 10. |
| Pets | Selten (Donut, Mongo). Eigene Pet-Boxen, Pet-Belohnungsräume. |
| NPC-Verträge | Überlebende ab Etage 9 können Verträge annehmen: als NPC/Gildenmeister für mehrere Staffeln dienen, um „frei“ zu werden (Mordecai). Nachteil: Verlust von Kontrolle (z. B. über die eigene Gestalt). |
| Desperado Club | Exklusiver Club mit Casino, Markt usw.; Ebenen öffnen auf Etage 3, 6 und 9. |
| Etagen-Themen | E1–2: zerstörte Erd-Oberfläche/Keller-Labyrinth · E3: *Over City* (Tag/Nacht-Zyklus, Zirkus, Quests) · E4: *Iron Tangle* (verknotetes U-Bahn-Netz) · E5: Wasser … |

---

## 3. Kernsysteme (Wunsch des Spielers + Ergänzungen)

### 3.1 Spielstart: „Das Vorher-Interview“
Beim Start führt die System-KI ein Interview über das frühere Leben
(Beruf, Hobbys, Fitness, Haustiere, Charakterzüge). Daraus ergeben sich:
- Start-Stats (STR, DEX, CON, INT, CHA)
- 1–2 Start-Talente (z. B. Koch → *Kochen* Lvl 1, Soldat → *Erste Hilfe*)
- Startgegenstand (z. B. Bademantel und Boxershorts wie Carl)
- Versteckte Flags, die später die Klassenliste auf Etage 3 beeinflussen.

### 3.2 Welt & Bewegung
- Etagen = prozedurale Karten aus Gebieten (Nachbarschaften → Boroughs).
- Darstellung: Karte/Raster, per **Maus** klickbar (Bewegung, Interaktion),
  plus Textlog als Erzählebene.
- **Einsturz-Timer** pro Etage als zentraler Druckfaktor.
- Treppen finden → Etage wechseln. Jede Etage schwerer, schaltet neue Systeme frei.

### 3.3 Freischaltungen (Progression der Systeme)
| Etage | Freischaltung |
|---|---|
| 1 (Start) | Nichts. Nur Fäuste, Füße, Umgebung. |
| 1 (Tutorial-Gilde gefunden) | Tutorial abgeschlossen → **Inventar**, Minimap, Stats. |
| 2 | Zuschauer/Follower, Briefkasten, Fan-Boxen |
| 3 | **Rassen- & Klassenwahl**, Sponsoren, Bestenliste, Desperado Club |
| 6 / 9 / 12 | Klassen-Spezialisierung |
| 9+ | **NPC-Verträge** |

### 3.4 Kampf & passives Skillsystem („Kampfstil-Erkennung“)
Jede Aktion wird als Kombination aus **Körperteil/Waffe × Ausführung × Kontext** erfasst:

- *Körperteil/Waffe:* Faust, Fuß, Knie, Ellbogen, Kopf, Wurfobjekt (Stein, Flasche…), improvisierte Waffe, echte Waffe
- *Ausführung:* normal, Sprung, Stampfen, Anlauf, Schleichangriff, Konter, Wurf
- *Kontext:* Gegner liegt / fliegt / ist größer, Umgebung (Wasser, Höhe), Gruppe

Das System zählt die Nutzungen mit und vergibt/steigert **Skills automatisch**:
- Schwellenwerte → Skill erscheint (z. B. 20 Stampfangriffe → *Stomp* Lvl 1)
- Nutzung → Skill-XP → Levelaufstieg
- Kombinationen → seltene Skills (z. B. Sprung + Stampfen → *Meteor-Stampfer*)
- Der dominante Kampfstil beeinflusst die Klassenvorschläge auf Etage 3.

### 3.5 Gegner
- Normale Mobs · Elite-Mobs („Mini-Bosse“) · Nachbarschafts-/Gebietsbosse · Borough-Bosse · Etagenbosse
- **Gebietsbosse:** droppen Loot + **Gebietskarte** (muss aufgehoben werden) → deckt Karte auf.
- Riesiger Bestiarium-Katalog: Mythologie, Folklore, Aliens, Popkultur-Parodien – alles datengetrieben (JSON).

### 3.6 Safe Rooms
- Keine Gewalt; angreifende Mobs werden rausteleportiert.
- Zufällige Variante: **Gratis-Gegenstand** *oder* **Restaurant** (NPC-geführt, Buff-Essen).
- Einziger Ort, an dem **Lootboxen geöffnet** werden können.
- Rauswurf kurz vor Etagen-Einsturz.

### 3.7 Items
- Slots: Kopf, Gesicht, Hals, Schultern, Brust, Rücken, Arme, Hände, Ringe (×2+), Gürtel, Beine, Füße, **Fußringe**, Unterwäsche (!), Waffen, Pet-Ausrüstung.
- Seltenheiten angelehnt an Box-Stufen (Gewöhnlich → Himmlisch).
- Verzauberungen, Set-Boni, verfluchte Items, Items mit Humor-Beschreibungstext.

### 3.8 Achievements & Lootboxen
- Hunderte Achievements, jeweils mit sarkastischem KI-Kommentar.
- Schwierigkeit/Seltenheit → Box-Stufe (Bronze … Himmlisch).
- „Erster“-Achievements (z. B. *Komische Katzenlady*: als Erster mit einer Katze den Dungeon betreten). Im Singleplayer: „erster in diesem Spielstand/allen eigenen Runs“ bzw. später global.
- Box-Typ hängt vom Achievement-Thema ab (Tritt-Achievement → Schuh-Box).

### 3.9 Party, Reittiere, Pets
- Party-System (zunächst mit NPC-Begleitern, später Spieler).
- Reittiere und Pets **sehr selten**; Pets leveln mit, eigene Pet-Boxen.

### 3.10 Zuschauer & Sponsoren (Vorschlag)
Ersetzt im Singleplayer die „Welt“: spektakuläre, lustige oder brutale Aktionen
erzeugen Zuschauer → Follower → Fan-Boxen & Sponsor-Angebote.
Belohnt kreatives Spielen statt reines Grinden.

---

## 4. Tod & Hardcore – Vorschläge

Ziel: Tod muss wehtun, aber das Spiel soll sich trotzdem lohnen.

1. **Permadeath + Staffel-System (Empfehlung):** Jeder Run ist eine „Staffel“.
   Tod beendet die Staffel endgültig. Erhalten bleiben: Achievement-Liste,
   Bestiarium-Wissen, freigeschaltete Start-Hintergründe („Hall of Fame“).
2. **Der Tote wird zum Mob:** Dein gestorbener Crawler taucht in späteren Runs
   als Boss/Geist auf der Etage auf, auf der er starb – mit seiner Ausrüstung.
   Besiegst du ihn, bekommst du Teile davon zurück.
3. **Vertrag als Rettung:** Wer vor dem Tod Etage 9+ erreicht hat und einen
   NPC-Vertrag unterschrieben hatte, wird statt zu sterben zum NPC
   (Gildenmeister/Game Guide) – und begleitet den **nächsten** Crawler als
   Guide mit eigenen Boni. Das macht die Verträge zum Meta-Ziel.
4. **Seltene Wiederbelebung:** Extrem seltene Items (Himmlisch) oder
   Sponsor-Deals mit hohem Preis (z. B. dauerhafte Stat-Strafe, Fluch,
   Sponsor-Pflichtquests).
5. **Optionaler Modus „Normal“:** Rücksetzung zum letzten Treppenhaus mit
   Verlust von Inventar – für Spieler, die kein Hardcore wollen.

---

## 5. Technischer Vorschlag (zur Diskussion)

- **Plattform:** Browser-Spiel (TypeScript), läuft überall, später leicht
  grafisch erweiterbar (Canvas/Phaser) und multiplayerfähig (Server mit
  derselben Engine).
- **Engine:** Deterministische, UI-unabhängige Spiellogik (Event-basiert).
- **Inhalte datengetrieben:** Monster, Items, Achievements, Skills, Etagen als
  JSON/YAML → Inhalte wachsen ohne Code-Änderungen.
- **Speichern:** lokal (IndexedDB), später Server.
- **Tests:** Unit-Tests für Kampf, Skill-Erkennung, Loot-Tabellen.

## 6. Vorgeschlagener erster Meilenstein („Vertical Slice“)
Etage 1 komplett spielbar: Interview-Start, prozedurale Karte mit
Mausbewegung, Nahkampf mit Stil-Erkennung, 10–15 Mob-Typen, Elite-Mobs,
2 Nachbarschafts-Bosse + 1 Borough-Boss, Tutorial-Gilde → Inventar,
Safe Rooms (beide Varianten), ~30 Achievements, Bronze/Silber-Boxen,
Einsturz-Timer, Treppe nach Etage 2.

---

## 7. Offene Fragen
Siehe Unterhaltung / werden hier nach Klärung ergänzt.

## 8. Rechtliches
*Dungeon Crawler Carl* ist geistiges Eigentum von Matt Dinniman. Für ein
privates Projekt unproblematisch; für eine Veröffentlichung sollten Namen,
Figuren (Carl, Donut, Mordecai, Borant …) und Texte durch eigene ersetzt
werden. Mechaniken selbst sind nicht geschützt.
