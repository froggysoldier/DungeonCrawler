# Der Große Abstieg – Game Design Dokument (v0.10)

> Inspiriert von der Buchreihe *Dungeon Crawler Carl* von Matt Dinniman.
> **Spoiler-Regel:** Aus den Büchern werden nur Spielmechaniken und die
> Komplexität der Systeme übernommen (Achievements, Skills, Stufen, Klassen,
> Rassen, Boxen, Sponsoren, Aufträge, Haustiere, Reittiere) – keine Handlung,
> Figuren, Orte oder Wendungen. Alle Namen und Texte sind eigene. Fokus: Etage 1–3.

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
| Plattform | Godot 4.7.2 (GDScript), Export für Windows, Linux und Web. Engine strikt getrennt von der UI. |
| Zeitmodell | Rundenbasiert. 1 Zug = 3 Minuten Spielzeit. |
| Sprache | Deutsch |
| Tod | Alle vier Konzepte (siehe Abschnitt 6) |
| Namen | Eigene Namen (Show, Guide, Bosse …), damit eine spätere Veröffentlichung möglich bleibt |
| Etagen | Themen dürfen sich am Buch orientieren, aber keine Spoiler |
| Oberfläche | Klickbare Karte in Pixel-Grafik (16 × 16 je Kachel), daneben Panels + Textlog; Gegenstände, Ausrüstungsplätze, Gegner und Haustier auch dort als Pixel-Bilder |
| Erster Meilenstein | Etage 1 komplett spielbar |
| Zweiter Meilenstein | Mehr Inhalte, Web-Link, Etage 2 (Publikum) und 3 (Rassen/Klassen) |

Oberfläche und Texte: **keine Emojis**, nur klare Schrift und Wörter.

Eigene Namen: Die Show heißt **„Der Große Abstieg“**, der Erzähler
**„die Systemstimme“**, der Standard-Guide **Barnabas**.

## 3. Systeme im aktuellen Stand

### 3.1 Spielstart: Das Vorher-Interview
Ein verzweigtes Interview (je nach Antworten rund 20–25 Fragen):
- **Beruf:** 19 Bereiche mit genauen Unterfragen – Handwerk, Büro, Gesundheit,
  Sicherheit, Gastronomie, Profisport, Bildung, IT und Internet (inkl. Social
  Media, Webdesign, IT-Sicherheit, Daten und KI), Kunst, Natur, Handel,
  Medien und Social Media, Transport und Logistik, Recht und Finanzen,
  Soziales und Erziehung, Technik und Labor, Dienstleistung, Schule und
  Studium, ohne Arbeit.
- **Körper und Alltag:** Alter, Fitness, Freizeitsport und Kampfsport,
  Sehkraft, Schlaf, Haustier, Ort und Gegenstand in der Hand beim Weltuntergang.
- **Kleidung einzeln:** Oberteil (14 Möglichkeiten), Hose, Unterwäsche,
  Schuhe (inkl. barfuß) und Accessoire – alles wird angezogen.
- **Charakter:** Konfliktverhalten, Selbstbild, Sozialverhalten, größte Angst,
  „Worauf konntest du im Alltag nur schwer verzichten?“, Glück.

Daraus ergeben sich Werte, Start-Skills, Ausrüstung, der Gegenstand in der
Hand, versteckte Flags für die Klassenwahl und **Eigenschaften**:
- Ängste (Krabbeltiere, Ratten, Dunkelheit, Höhe, Enge) wirken als Malus und
  lassen sich im Dungeon überwinden – dann werden sie zu Stärken.
- Laster, Eigenarten und Berufserfahrung (z. B. Schädlingsbekämpfer: +15 %
  gegen Ratten und Krabbeltiere; Klempner: gegen Schleime und Wasserwesen).
- Antwort-Kombinationen verstärken sich (z. B. Boxen als Beruf und Hobby →
  Profi-Schläger).

### 3.2 Welt & Karte
- Etage = 72×52 Kacheln, vier **Viertel** (Nachbarschaften) + zentrales Gewölbe.
- Räume mit Namen und Beschreibungen (Heizungskeller, Partykeller, Luftschutzbunker …).
- Sichtfeld (Fog of War). **Vor dem Tutorial keine Karte** – man sieht nur, was gerade in Sicht ist.
- **Einsturz-Timer**: 5 Tage (2400 Züge). Warnungen bei 24 h, 6 h, 1 h.
- Treppenhäuser: eins hinter dem Borough-Boss, zwei in abgelegenen Räumen.
- Boss-Kammern und Arena sind **Sackgassen mit genau einem Zugang**.
- **Boss-Kammern** haben rote Eisentüren (pulsierendes Glühen, Hinweis im
  Tooltip) und einen **Vorraum** mit 2–3 normalen Wachen: Man läuft nie
  unvermittelt hinein. Beim Betreten verriegelt sich die Tür, bis der Boss
  fällt; ein **Versus-Bildschirm** zeigt Crawler gegen Boss.
- **Bodenfunde:** In normalen Räumen liegt nur Handwerksmaterial (Schrott,
  Steine, Flaschen …). Echte Beute liegt nur im Vorraum der Boss-Kammern.
- **Gilden und Safe Rooms** haben Mauern und **Türen**. Geschlossene Türen
  versperren Weg und Sicht und müssen erst geöffnet werden (ein Zug, nie
  schräg); man kann sie wieder schließen. Monster öffnen sie nicht.
- **Darstellung:** Mauern mit Vorderseite und Schattenwurf, Böden je nach Raum
  (Dielen, Fliesen, Beton, Ziegel, Teppich im Safe Room, Marmor in der Gilde,
  Pflaster in Gängen), Einrichtung, Türen, Fallen- und Beutesymbole, weicher
  flackernder Lichtkegel.
- **Bewegung:** Figuren gleiten von Feld zu Feld, die Kamera folgt weich.
  Solange kein Gegner hinter dir her ist, läuft man mit gehaltener
  Richtungstaste flüssig weiter; Klick-Reisen öffnen Türen unterwegs.
- **Untersuchen ohne Hinlaufen:** Ein Klick auf Gegenstände, Möbel, Fallen
  oder die Treppe zeigt eine Info-Karte; erst der zweite Klick läuft hin.
- **Kampfmodus:** Sobald ein wacher Gegner dich bemerkt, erscheint ein
  Banner, die Karte bekommt einen roten Rahmen, ein Klang ertönt und jeder
  Zug zählt einzeln (kein automatisches Weiterlaufen). Am Ende zeigt ein
  Banner die Bilanz (Züge, Besiegte, Erfahrung, verlorene Lebenspunkte).
- **Figuren:** Crawler und Monster sind gezeichnete Kreaturen (Ratte,
  Spinne, Kobold, Schleim …); unbekannte Monster zeigen ihre Gestalt mit
  einer Fragezeichen-Marke.
- **Sichtbare Geschosse:** Würfe (im Bogen), Pfeile, Schleim, Zauber und
  Haustier-Magie fliegen sichtbar; Schaden, Heilung und Fehlschläge steigen
  als Zahlen auf.

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
- **Trefferzonen:** Kopf (−15 % Treffer, +50 % Schaden, kann benommen machen
  – leichter bei liegenden Gegnern, schwer bei Riesen), Körper (sicher),
  Arme (schwächen die Angriffe des Gegners), Beine (Gegner humpelt, fällt
  leichter um).
- **Deckung:** bis zum nächsten Zug +20 % Ausweichen, +2 Rüstung.
- **Zustände:** Blutung, Brennen, Gift, Furcht und Blindheit (siehe 3.24).
- **Stufen-Abstand:** Gegner weit über dir sind schwerer zu treffen und treffen
  dich leichter (bis zu 20 Prozentpunkte), bei viel schwächeren ist es umgekehrt.
- **Kampfsequenz:** Sobald ein Gegner, der dich bemerkt hat, in Sicht ist,
  wird die Aktionsleiste zum Kampfpanel: 1. womit (Körperteil, Waffe,
  bestimmtes Wurfobjekt, Zauber, Deckung, Trank, Klassenfähigkeit), 2. wie,
  3. wohin, 4. wen – jeder sichtbare Gegner mit Entfernung, Zustand und der
  Trefferchance für genau diese Kombination.

### 3.4a Erfahrung und Stufen
- Erfahrung hängt vom **Stufen-Abstand** ab: Ein gleich starker Gegner gibt
  volle Erfahrung, einer fünf Stufen darunter nur noch 10 %, einer fünf Stufen
  darüber fast das Doppelte.
- Jeder Gegner trägt eine farbige **Herausforderung**: harmlos, leicht,
  ebenbürtig, fordernd, gefährlich, tödlich (Markierung auf der Karte, im
  Tooltip und in der Zielliste).
- Die Stufenkurve ist steil (60 × Stufe^1,75). Auf den ersten Etagen steigt man
  deshalb langsam; wer später stärkere Gegner besiegt, steigt schneller.
  Simulation: gründliche Spieler erreichen etwa Stufe 5 / 8 / 10 am Ende der
  Etagen 1 / 2 / 3, vorsichtige etwa 3 / 5 / 7.

### 3.5 Passive Skills und der Beobachter
**Der Beobachter** zeichnet jede Aktion mit vollem Kontext auf: Technik,
Ausführung, Gegnerart, Größe, Fähigkeiten, Rang, Level-Abstand, ob der Gegner
liegt, flieht oder ahnungslos ist, dein Zustand (vergiftet, fast tot, barfuß,
fast nackt, im Bademantel, umzingelt, angetrunken, erschöpft, mit Haustier,
letzte Stunde) und der Raum. Er zählt alle Kombinationen.

- **Dynamische Skills:** Wiederholte Muster werden zu maßgeschneiderten Skills,
  z. B. „Tritte gegen Flieger“ (+Schaden und +Treffer nur in genau dieser
  Situation), „Barfuß: Tritte“, „Ausweichen gegen Fernkämpfer“,
  „Abgehärtet gegen Giftige“. Sie leveln mit Nutzung (max. Stufe 10).
- **Grundskills:** 30 Skills in sieben Gruppen (Kampf, Verteidigung,
  Bewegung, Überleben, Handwerk, Sozial, Magie). Sie entstehen aus dem, was
  man tut: Faustkampf aus Faustschlägen, Schleichen aus unentdecktem
  Anschleichen, Abwehr aus Angriffen in Deckung, Konter aus Ausweichen,
  Schmerzresistenz aus schweren Treffern, Feilschen aus Preisverhandlungen,
  Reiten aus Ritten, Arkane Kunde aus Zaubern und so weiter.
- Jede Stufe kostet mehr (25 + 20 × Stufe Skill-Erfahrung). An viel
  schwächeren Gegnern lernt man kaum etwas (Lernfaktor nach Stufen-Abstand).
- Jeder Skill beschreibt seine Wirkung pro Stufe („Jetzt“ und „Nächste Stufe“).
- **Klassenskills** und die Begabung der Rasse wachsen 50 % schneller.

### 3.6 Gegner
- 49 Mob-Typen auf Etage 1–3 (Kellerratte, Kobolde, Wolpertinger,
  Tatzelwurm, Grauer Späher, Blähkröte, Chupacabra, Kanal-Krokodil,
  Mottenmann …) mit Verhalten: Nahkampf, Fernkampf, feige, stationär (Mimics).
- **Fähigkeiten:** giftig (Gift-Schaden pro Zug, Gegengift hilft),
  explodiert beim Tod, klaut Gold und flieht, ruft Verstärkung,
  regeneriert, schnell (2 Schritte), fliegend (nicht umwerfbar, kein
  Stampfen), gepanzert (halber Faustschaden).
- Normale Monster betreten keine Boss-Kammern.
- **Verhalten:** Wer dich sieht, greift an. Geflohen wird nur, wenn es zur
  Art passt (feige Gnome und Heinzelmännchen, Diebe mit Beute, kleine
  verletzte Tiere). Ein Teil schläft und wacht durch Lärm auf; Kampflärm,
  Explosionen und Stolperdrähte locken andere an die Stelle. Entdeckte
  Monster warnen Artgenossen, suchen dich an der letzten bekannten Stelle,
  Fernkämpfer halten Abstand, Elite und Bosse geraten bei wenig Leben in
  Raserei.
- Was andere Crawler oder weit entfernte Monster tun, erfährst du nur, wenn
  du es siehst.
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
- **Eingerichtet:** Jeder Safe Room hat einen **Gratis-Automaten** (1 Gegenstand
  pro Crawler; meist nützlich, manchmal ein Scherzartikel), einen Händler,
  ein Bett und eine Toilette. **Restaurants** haben zusätzlich einen Wirt mit
  Buff-Essen und Zimmer. Möbel benutzt man, indem man hineinläuft.
- Nur hier: **Lootboxen öffnen** und **schlafen** (8 h, heilt, Haustier kehrt zurück).
- **Toilette:** Erleichtern darf man sich nur hier (siehe Blase).
- **Laden** mit wechselnder Besitzerin oder wechselndem Besitzer: kaufen,
  verkaufen (40 % des Werts) und **feilschen** – einmal pro Angebot, Chance
  mit Charisma und Laune; Erfolg bis 25 % Rabatt, Misserfolg +10 % und
  schlechtere Laune.
- Zählt als Werkbank fürs Handwerk.
- 1 h vor Einsturz wird man hinausgeworfen.

### 3.8 Items
Rund 170 Gegenstände. 17 Ausrüstungsplätze inkl. 2 Ringe, **2 Fußringe** und Unterwäsche.
Seltenheiten Gewöhnlich → Ungewöhnlich → Selten → Episch → Legendär → Himmlisch,
zufällige Verzauberungen („Stahlkappenstiefel des Esels“), Unikate mit
Spezialeffekten (Zweite-Chance-Klausel, Stiefel des ungebremsten Stampfens,
Der Ziegel …), Verbrauchsgüter, Haustier-Leckerli.

### 3.9 Achievements & Lootboxen
Für gefühlt alles, was ein Achievement wert ist, gibt es eines – insgesamt
über 600 feste Achievements plus die dynamischen Muster.
- **Statistik:** Der Dungeon zählt alles mit (Kills nach Art, Angriffsart,
  Ausführung, Trefferzone und Umständen, Schaden, Serien, Räume, Türen,
  Handel, Fallen, Handwerk, Zauber, Crawler, Show). Sichtbar im Erfolge-Tab
  unter „Statistik“.
- **Achievement-Familien:** Aus der Statistik entstehen gestufte Ziele mit
  eigenen Namen (zum Beispiel Killserien, Kills ohne erlittenen Treffer,
  schlafende, fliehende oder liegende Gegner, jede Angriffsart, Blutungen,
  Brände, erkundete Fläche, geöffnete Türen, Feilschen, Tränke, Fallen).
- **Bestiarium je Monsterart:** Neu im Bestiarium, Routine (10), Plage
  beseitigt (30) – aber erst, wenn man die Art auch erkennen konnte.
- **Besondere Momente:** über 60 einmalige Situationen, zum Beispiel ein Boss
  bei vollen Lebenspunkten, drei Gegner mit einer Explosion, ein Treffer, der
  mehr Schaden macht als der Gegner Leben hat, Rettung durch Haustier oder
  Party, ein Safe Room direkt vor dem Verfolger, Kills während man brennt oder
  geblendet ist, Doppelaufstieg, Jackpot, einen Laden leer kaufen.
- **Entdeckte Muster (dynamisch):** Der Beobachter vergibt Achievements für
  Kombinationen, die tatsächlich passieren, in Stufen I–V (1, 5, 15, 40, 100).
- Kleine Erfolge bringen keine Box, nur Aufmerksamkeit beim Publikum.
- Der Erfolge-Tab ist nach 13 Kategorien geordnet, zeigt den Fortschritt je
  Kategorie und die nächsten erreichbaren Ziele.
- Boxen in 6 Stufen (Bronze → Himmlisch) und 11 Themen.
- **Wer ein Achievement zum ersten Mal in seiner Karriere schafft, bekommt eine Box-Stufe mehr.**

### 3.10 Publikum (ab Etage 2)
- Spektakel (Stampf-Kills, Sprungtritte, Bosse, Achievements, knappe
  Rettungen, Explosionen …) erhöht **Hype** und bringt **Follower**.
- Charisma und Hype multiplizieren den Zuwachs, Hype kühlt mit der Zeit ab.
- Fan-Boxen bei 100 / 250 / 500 / 1.000 / 2.500 / 5.000 / 10.000 … Followern.
- Große Momente bringen manchmal Geschenke aus dem Publikum.
- Zuschauer-Kommentare im Log (Zuschauer xX_Glorbnak_Xx: „DRAUFGESTAMPFT HAHAHA“).

### 3.11 Rassen & Klassen (ab Etage 3)
- Man wird in die Gilde geholt und wählt **Rasse** und **Klasse**. Der
  Auswahlbildschirm zeigt alle Boni, Fähigkeit, Klassenskills, Startzauber,
  Startausrüstung, Sondereigenschaften und eine Vorschau der Grundwerte.
- **24 Rassen:** 8 frei wählbar (Mensch mit 4 freien Stat-Punkten und mehr
  Erfahrung, Halbork, Kellerelf, Zwerg, Gnom, Halbling, Echsenmensch,
  Hobgoblin), 16 **durch Verhalten freigeschaltet** (zum Beispiel
  Katzenmensch mit Krallen, Höhlentroll, Minotaurus, Lehmgolem, Pilzling,
  Kellervampir, Kobold, Salamanderblut, Rattling, Kelleroger, Schattenwesen,
  Wasserspeier, Kellerfee, Ghulblut, Blechmensch, Drachenblut).
  Jede Rasse hat eine **Begabung** (ein Skill, der schneller wächst) und oft
  Sondereigenschaften (feuerfest, blutlos, furchtlos, giftimmun …).
- **49 Klassen in 10 Gruppen:** Nahkampf, Fernkampf, Magie, Heimlichkeit,
  Verteidigung, Heilung und Versorgung, Show und Handel, Handwerk und
  Technik, Tiere und Reittiere, Sonderklassen.
- Die **persönliche Klassenliste** bewertet jede Klasse nach Kampfstil,
  Statistik und Interview: die 10 passendsten gewöhnlichen Klassen, dazu alle
  **seltenen und legendären Klassen**, deren Bedingung erfüllt ist (zum
  Beispiel Todesverächter nach zehn knappen Überlebenden, Bestiarius nach 20
  Monsterarten, Apokalypsen-Nudist nach zehn Kills ohne Ausrüstung). Die drei
  passendsten werden empfohlen.
- Jede Klasse hat **Klassenskills** (wachsen 50 % schneller, der erste startet
  zwei Stufen höher), eine **aktive Fähigkeit** mit Abklingzeit (Taste F) und
  oft Startzauber, Startausrüstung und Sondereigenschaften.
- 25 Fähigkeiten: Wutanfall, Wirbelwind, Erdbeben, Kampfschrei, Bollwerk,
  Schattenschritt, Steinhagel, Bombe, Zweite Luft, Showtime, Blutrausch,
  Gnadenstoß, Giftwolke, Brandsatz, Blitzlicht, Meditation, Rudelruf,
  Zeitlupe, Rauchbombe, Langfinger, Notreparatur, Motivationsrede, Arkaner
  Schild, Manaflut, Totstellen.

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

### 3.13 Haustiere
- Katze oder Hund aus dem Interview: folgt, kämpft mit, levelt, wird bei 0 HP
  bewusstlos und kehrt nach dem Schlafen zurück.
- **Eier** (Kellerraptor, Minidrache) schlüpfen nach 160 Zügen im Inventar,
  wenn man noch kein Haustier hat.
- **Zähmen:** geschwächte Tiere (unter 40 % HP) mit einem Leckerli füttern,
  Chance mit Charisma.
- **Superkeks:** das Haustier erwacht, spricht und wirkt Magische Geschosse.
- **Entwicklung:** Auf Stufe 4 wählt man einen von zwei Wegen je Art, auf
  Stufe 8 folgt die Endform. Jede Form bringt HP, Schaden und eine Fähigkeit:
  Einschüchtern, Pflegen, Giftbiss, Feueratem, Doppelschlag, Umreißen,
  Netzfalle, Beschützer (+2 Rüstung für dich), Späher (+1 Sichtweite).
- **Halsbänder** aus Haustier-Boxen geben dem Haustier HP und Schaden.

### 3.14 Magie
- Mana = Intelligenz (plus Boni), regeneriert langsam. Zauber lernt man aus
  **Zauberbüchern** (Boxen, Läden) und verbessert sie durch Benutzen.
- Heilen, Magisches Geschoss (Mana frei wählbar 3–6), Fackel, Irrlichtrüstung
  (Schild), Pfützensprung (Teleport), Feuerball, Schutzhülle, Schattenmantel,
  Entgiften.

### 3.15 Tränke und Blase
- **Trank-Abklingzeit:** nach jedem Trank 20 Züge Pause.
- **Blase:** Getränke und Tränke füllen sie, die Zeit auch. Erleichtern nur in
  Safe-Room-Toiletten. Wer es nicht schafft, beschwört einen Wutelementar.

### 3.16 Pässe und Talismane
- Tätowierungen (Kobold, Ratte) und Talismane (Flieger, Untote, Insekten):
  diese Gegnerart greift nicht an – bis man sie selbst angreift.
- **Rubbellose:** Niete, Gold, Gegenstände, Boxen, Zauberbücher, selten ein Jackpot.

### 3.17 Fallen und Handwerk
- Jede Etage hat **versteckte Fallen** (6 + 4 je Etage) in Gängen und normalen
  Räumen: Pfeil-Druckplatte, Stolperdraht (weckt alles in der Nähe),
  Fallgrube (festgehalten), Giftgasdüse, Bärenfalle (festgehalten).
- **Entdecken:** in bis zu zwei Feldern Abstand, Chance mit Intelligenz und
  Fallenkunde. Bekannte Fallen werden gezeichnet, der Klick-Pfad umgeht sie;
  wer trotzdem drüberläuft, kommt meist mit Geschick heil hinüber.
- **Entschärfen:** direkt daneben, Chance mit Geschick und Fallenkunde.
  Erfolg bringt Fallenteile, Misserfolg löst die Falle manchmal aus.
- **Handwerk** (eigener Tab): Verband, Brandflasche, Nagelbombe, Stachelfalle,
  Schlingfalle, Sprengfalle, Waffe benageln (+2 Schaden, bis zu dreimal).
  Aufwendige Rezepte brauchen eine Werkbank (Werkstätten, Schmieden, Safe
  Rooms oder Klappwerkbank im Rucksack).
- **Sprengsätze** treffen alles im Umkreis von einem Feld, auch dich.
  **Eigene Fallen** stellt man auf das eigene Feld; nur Monster lösen sie aus.
- Neue Skills: **Fallenkunde** und **Handwerk**. Der Beobachter erkennt
  Fallen- und Bomben-Kills als eigene Muster.

### 3.18 Andere Crawler, Party und Bevölkerung
- Auf jeder Etage leben andere Crawler (3 + Etage), jeweils mit Namen,
  früherem Beruf und Charakter: **freundlich**, **vorsichtig**,
  **eigenbrötlerisch** (nur Tipps), **verzweifelt** (verletzt; nach einer
  Heilung dankbar und freundlich) oder **feindselig** (will dein Zeug und wird
  zum Gegner).
- Ansprechen, **in die Party einladen** (Chance mit Charisma, Level-Abstand,
  Followern und Vertrauen), **nach Tipps fragen** (Treppe, Safe Room oder
  Fallen in der Nähe), heilende Gegenstände verschenken, Mitglieder entlassen.
- **Party bis zu vier Crawler:** Mitglieder folgen, kämpfen, leveln, steigen
  mit ab – und können sterben.
- **Bevölkerung:** Die Systemstimme zählt regelmäßig durch, wie viele Crawler
  noch leben. Die Zahl sinkt im Lauf jeder Etage und beim Einsturz.

### 3.19 Rückblick und Talkshow
- Beim Abstieg zeigt die Systemstimme einen **Rückblick** auf die Etage:
  Kämpfe, Fallen, Handwerk, Achievements, erkannte Muster, Party, Gefallene,
  Follower und verbleibende Crawler.
- Sobald das Publikum zuschaut, ist man danach Gast in der **Talkshow**
  „Glanz und Gloria“. Die Fragen richten sich nach dem Run (Haustier, Party,
  gefallene Mitglieder, Kampfstil, Bomben …). Antworten haben einen Ton
  (ehrlich, witzig, frech, bescheiden, dramatisch). Riskante Antworten hängen
  vom Charisma ab und können Follower kosten. Eine gute Sendung bringt eine
  Fan-Box.

### 3.20 Sponsoren
- Sechs erfundene Sponsoren (Kristallhaus Vornex, Brennstoffwerke Pyrrax,
  Gräfin Oolu vom Nebelmond, Konsortium Grimmzahn, Die Schleimbrüder GmbH,
  Galaktische Mode AG) mit eigenem Geschmack: Stil, Explosionen, Haustiere,
  Mut, schmutzige Tricks, absurde Mode.
- Passende Aktionen wecken Interesse (mehr Hype = schneller). Ab 100 Interesse
  und genug Followern kommt ein Angebot; bis zu drei Sponsoren gleichzeitig.
- Aktive Sponsoren haben Wünsche; jeder erfüllte Wunsch bringt eine
  Sponsorenbox (mit steigender Stufe). Wer tut, was sie nicht mögen, verliert
  Gunst – bei 0 ist das Sponsoring vorbei.

### 3.21 Aufträge
- Andere Crawler (manchmal beim ersten Gespräch) und jeder Laden bieten
  Aufträge an: **Jagd** (Gegner einer Art), **Finden** (verlorenes Andenken
  in einem anderen Viertel), **Liefern** (Tränke, Essen, Lappen …),
  **Retten** (eingeschlossener Crawler, von Monstern bewacht) und **Boss**.
- Belohnung: Gold, XP, oft eine Lootbox; Ladenbesitzer geben danach 15 %
  Freundschaftsrabatt. Aufträge scheitern, wenn der Auftraggeber stirbt oder
  die Etage verlassen wird. Bis zu fünf offene Aufträge.

### 3.22 Reittiere und Fahrzeuge
- Motorisierter Einkaufswagen, Aufsitzrasenmäher, Raketen-Bobbycar (Fahrzeuge,
  brauchen Benzin) sowie Kellerpony, Sattelschnecke und Kampfeber (Tiere).
  Man bekommt sie über Zündschlüssel und Pfeifen aus Läden und guten Boxen.
- Beritten: 2–3 Schritte pro Zug (Schnecke: 1, dafür +3 Rüstung),
  **Anlauf rammt** mit Zusatzschaden und Umwerf-Chance, ohne vorher laufen zu
  müssen. Ein Teil der Treffer geht auf das Reittier; Fahrzeuge können
  zerstört werden, Tiere erholen sich beim Schlafen. Im Safe Room steigt man ab.
  Taste M zum Auf- und Absteigen.

### 3.23 Klänge
Im Browser erzeugt (keine Audiodateien): Lootbox (Knarzen und Glitzern, je
nach Stufe länger), Level-Aufstieg (Fanfare), Achievement (Glockenschlag),
neuer Skill. Schalter „Ton an/aus“ in der oberen Leiste.

### 3.24 Zustände im Kampf
| Zustand | Wirkung | Quellen |
|---|---|---|
| Blutung | Schaden pro Zug, stapelt sich | Klingen, benagelte Waffen, Nagelbomben, Krallen, reißende Monster |
| Brennen | Schaden pro Zug, Tiere geraten in Panik | Brandflaschen, Feuerball, Brandsatz, Feuerwesen |
| Gift | Schaden pro Zug | Rattengift, Giftwolke, Giftklinge, giftige Monster |
| Furcht | flieht und greift nicht an | Kampfschrei, Schreckgestalten |
| Blindheit | trifft kaum, sieht fast nichts | Staubsaugerbeutel, Blitzlicht, Rauchbombe, blendende Monster |

- Anfälligkeit nach Art: Konstrukte, Geister, Elementare und Schleime bluten
  nicht; Untote kennen kein Gift; Insekten, Pflanzen und Untote brennen gut;
  Bosse lassen sich nicht einschüchtern; Elite-Gegner widerstehen oft.
- Beim Crawler: Verbände und starke Heiltränke stoppen Blutungen, Warten heißt
  am Boden wälzen und löscht Flammen, Charisma hilft gegen Furcht, Geschick
  gegen Blendung. Rassen und Klassen können immun sein.
- Zustände stehen auf der Karte (farbige Punkte, flackernder Rand bei Brand),
  im Tooltip, in der Zielliste und an der eigenen Lebensleiste.

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
godot/
  scripts/engine/  Spiellogik, UI-unabhängig, deterministisch (Seed), JSON-Zustand
  data/            Inhalte: Monster, Items, Skills, Achievements, Interview, Welttexte
  scripts/ui/      Pixel-Karte, Panels, Dialoge
  assets/pixel/    Pixel-Bögen (PNG), in jedem Pixel-Editor bearbeitbar
  tests/           Engine-, Replay- und Oberflächentests (./test.sh)
  tools/           Balance-Simulation, Aufnahmen, Pixel-Generator, Bildschirmfotos
```

Details in [`GODOT_PORT.md`](GODOT_PORT.md).

## 6. Nächste Schritte (Vorschlag)

1. Balance von Etage 2–3 durch Testspielen (Klassen, Zustände, Achievements)
2. Etage 4+ mit neuen Themen, Klassen-Spezialisierung (Etage 6/9/12)
3. Etage 4 und weiter: neue Themen, Kreaturen und Bosse

## 7. Rechtliches
*Dungeon Crawler Carl* ist geistiges Eigentum von Matt Dinniman. Das Spiel
nutzt eigene Namen, Figuren und Texte. Mechaniken sind nicht geschützt.
