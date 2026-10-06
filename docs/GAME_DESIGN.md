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
| Oberfläche | Klickbare Karte in Pixel-Grafik (einheitlich 32 × 32 je Kachel und Figur), daneben Panels + Textlog; Gegenstände, Ausrüstungsplätze, Gegner und Haustier auch dort als Pixel-Bilder; die Spielfigur trägt ihre Ausrüstung sichtbar (Farbe = Seltenheit); jede Rasse hat eigenen Körperbau, Kopf und Anbauten. Stil nach dem Asset-Pack Tiny Swords (Pixel Frog): Nachtblau-Konturen, gedämpfte Palette, Klippenwände, Wasser mit Gischt, Knöpfe, Papier und Bänder aus dem Pack |
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
- Etage = 84×60 Kacheln, vier **Viertel** (Nachbarschaften) + zentrales Gewölbe.
- **Haupt- und Nebengänge:** Zwei Felder breite Hauptgänge bilden einen Ring
  um das Gewölbe und zwei Achsen, die die Etage in die vier Viertel teilen;
  jedes Viertel hat zusätzlich ein eigenes Gangkreuz. Schmale Nebengänge
  führen von jedem Raum zum nächsten Hauptgang, viele Räume haben einen
  zweiten Zugang zu einem Nachbarraum. So gibt es Schleifen und mehrere Wege
  statt eines einzigen Tunnels. Räume sind mindestens 5 × 4 Felder groß, es
  gibt keine Mini-Nischen mehr; Nebengänge laufen möglichst gerade durchs
  Gestein statt an anderen Gängen entlang.
- **Safe Rooms:** nur drei je Etage, je einer in den drei anderen Vierteln,
  nie im Start-Viertel.
- **Reviere:** Je Viertel zwei (ab Etage 2 drei) Räume, in denen eine einzige
  Monsterart lebt, 3–5 Tiere (nahe am Start 2–3 der untersten Stufe). Nur
  dort kommt Nachschub, und zwar immer dieselbe Art. Die übrigen Räume sind
  meist leer, ab und zu streift ein Einzelgänger herum (auf Etage 1 öfter).
- **Toiletten** stehen nicht nur in Safe Rooms, sondern auch in manchen
  normalen Räumen. Man benutzt sie, wenn man direkt daneben steht.
- **Andere Crawler:** zwei auf Etage 1, vier auf Etage 2, sechs auf Etage 3,
  keiner im Umkreis von 25 Feldern um den Start.
- Räume mit Namen und Beschreibungen (Heizungskeller, Partykeller, Luftschutzbunker …).
- Sichtfeld (Fog of War). Die Karte (mit kleiner Übersichtskarte) merkt sich von Anfang an, wo man war.
- **Gegenstände aus der Entfernung:** Bis zwei Felder weit erkennt man, was
  am Boden liegt. Weiter weg zeigt der Tooltip nur „Da liegt etwas. Zu weit
  weg, um es zu erkennen.“ Steht man nah dran und kennt den Gegenstand nicht
  (Stufe zu niedrig), steht dort, dass man ihn nicht kennt.
- **Einsturz-Timer**: 5 Tage (2400 Züge). Warnungen bei 24 h, 6 h, 1 h.
- Treppenhäuser: eins hinter dem Borough-Boss, zwei in abgelegenen Räumen.
- Boss-Kammern und Arena sind **Sackgassen mit genau einem Zugang**. Jedes
  Viertel bekommt zuerst einen großen Raum (10–11 × 8), der zur Boss-Kammer
  wird: nach dem Ummauern mindestens 8 × 6 Felder.
- **Boss-Kammern** haben rote Eisentüren (pulsierendes Glühen, Hinweis im
  Tooltip) und einen **Vorraum** mit 2–3 normalen Wachen: Man läuft nie
  unvermittelt hinein. Wer die Tür durchschreitet, steht sofort drin (in der
  Tür stehen bleiben geht nicht), die Tür fällt zu und verriegelt sich, bis
  der Boss fällt; ein **Versus-Bildschirm** zeigt Crawler gegen Boss.
- **Ruhiger Start:** Im Umkreis von etwa 22 Feldern um den Startraum gibt es
  keine Reviere, nur Einzelgänger. Elite-Gegner tauchen auf Etage 1 erst weit
  vom Start auf (auf den tieferen Etagen etwas früher). Fernkämpfer auf
  Etage 1 (Irrlicht, Grauer Späher) machen etwas weniger Schaden.
- **Bodenfunde:** Gegenstände liegen nicht einfach herum. Beute gibt es im
  Vorraum der Boss-Kammern, in Schatz- und Geheimkammern, in Kisten und bei
  Monstern.
- **Waffe in der Hand:** Vor der Gilde hat man nur eine Hand frei; Kleinkram
  nimmt einem die Waffe nicht mehr weg. In der Gilde wird eine Waffe aus der
  Hand angelegt statt eingepackt.
- **Wertepunkte:** Bis zur Klassen- und Rassenwahl auf Etage 3 verteilen
  sich die drei Punkte pro Stufe von selbst gleichmäßig; danach verteilt man
  sie frei.
- **Gilden und Safe Rooms** haben Mauern und **Türen**. Geschlossene Türen
  versperren Weg und Sicht und müssen erst geöffnet werden (ein Zug, nie
  schräg); man kann sie wieder schließen. Monster öffnen sie nicht.
- **Darstellung:** Mauern mit Vorderseite und Schattenwurf, Böden je nach Raum
  (Dielen, Fliesen, Beton, Ziegel, Teppich im Safe Room, Marmor in der Gilde,
  Pflaster in Gängen), Einrichtung, Türen, Fallen- und Beutesymbole, weicher
  flackernder Lichtkegel. Böden sind große, nahtlose Flächen über 4 × 4
  Felder: Keine Fuge liegt auf einer Feldgrenze, man sieht kein Raster.
- **Freie Bewegung (wie Baldur's Gate, `free_move.gd`):** Die Spielfigur hat
  eine stufenlose Position und läuft auf geraden Linien. Ein Klick läuft
  genau zur geklickten Stelle; der Weg wird aus dem Feldweg zu wenigen geraden
  Stücken geglättet (mit Abstand zu Ecken, Türen gerade hindurch). Gedrückte
  linke Maustaste folgt der Maus, Pfeiltasten laufen frei (zwei zugleich
  schräg), an Wänden gleitet man entlang. Im Hintergrund rechnet das Spiel in
  Feldern: Betritt die Figur ein neues Feld, ist das ein Schritt. Die
  Vorschau ist eine gepunktete Linie mit Länge in Metern (ein Feld = 1,5 m);
  über einem Gegner zeigt sie den Weg bis neben ihn mit Trefferchance
  („Angriff · 6 m · 72 %“); steht er schon daneben, steht die Chance (oder
  was fehlt) über ihm. Bleibt man im Schlamm stecken, läuft der Klick-Weg
  außerhalb des Kampfes weiter, sobald man sich befreit hat.
  Klick-Reisen öffnen Türen unterwegs. Gegner, Haustier und Gruppe, die in
  einer Kampfrunde mehrere Felder laufen, gleiten den echten Weg entlang
  (geglättet, um Ecken statt durch Wände). Andere Figuren stehen je etwas
  versetzt statt genau in der Feldmitte, damit sie sich nicht im Raster
  aufreihen.
- **Untersuchen ohne Hinlaufen:** Ein Klick auf Gegenstände, Möbel, Fallen
  oder die Treppe zeigt eine Info-Karte; erst der zweite Klick läuft hin.
- **Kampfmodus in Runden (wie Baldur's Gate):** Sobald ein wacher Gegner
  dich sieht, erscheint ein Banner, die Karte bekommt einen roten Rahmen, ein
  Klang ertönt, und der Kampf läuft in Runden (`rounds.gd`). Pro Runde hast du
  einen Bewegungsvorrat (9 m = 6 Felder, Geschick ±, Reittier +3 m,
  festgehalten 1,5 m) und eine Aktion (Angriff, Zauber, Gegenstand, Deckung,
  Warten). Die Weglinie ist grün, soweit die Bewegung reicht, danach rot.
  Ein Klick läuft am Stück hin; ein
  Klick auf einen Gegner läuft hin und greift an, wenn die Bewegung reicht.
  **Spurt** (S) macht aus der Aktion Bewegung: noch einmal der volle Vorrat,
  kostet 2 Ausdauer. Schritte kosten keine Spielzeit, die Gegner warten. Auch nach der Aktion
  darf man mit der übrigen Bewegung weiterlaufen (zuschlagen und zurückweichen).
  Die Runde endet mit der Leertaste („Runde beenden“), von selbst, wenn Aktion
  und Bewegung verbraucht sind, oder wenn man eine zweite Aktion wählt (die
  zählt dann schon zur nächsten Runde): dann laufen die Gegner bis zu ihrer Reichweite
  heran (4 Felder, klein 5, riesig 3, schnell +2, fliegend +1; Fernkämpfer nur,
  bis sie schießen können) und greifen an. Haustier und Gruppenmitglieder
  laufen ebenfalls bis zu 5 Felder zum bedrohlichsten Gegner oder dir hinterher.
  Eine Runde ist ein Zug (3 Minuten).
  Darunter wird weiter in Feldern gerechnet. Am Ende zeigt ein Banner die
  Bilanz (Züge, Besiegte, Erfahrung, verlorene Lebenspunkte).
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
| Etage 3 | Rassen- & Klassenwahl, Klassenfähigkeiten, **Handel** (Läden in den Safe Rooms, Märkte der Siedlung) und **Aufträge** | |
| Etage 9+ | NPC-Verträge | Engine-Hook vorhanden |

Die Etagen stehen in `world.json` unter `UNLOCK_FLOORS`. Auf Etage 1 und 2
gibt es also weder Läden noch Wanderhändler noch Aufträge; Gold sammelt man
für den Wirt im Restaurant und für Etage 3.

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
- **Rüstung und Ausweichen:** Rüstung wirkt mit abnehmendem Ertrag
  (Schaden = roh² / (roh + Rüstung)): wenig Rüstung zieht fast so viel ab wie
  ihr Wert, viel Rüstung macht Treffer klein, aber nie wirkungslos. Gegen
  angekündigte Boss-Angriffe zählt sie nur halb. Ausweichen ist auf 50 %
  begrenzt.
- **Zustände:** Blutung, Brennen, Gift, Furcht und Blindheit (siehe 3.24).
- **Stufen-Abstand:** Gegner weit über dir sind schwerer zu treffen und treffen
  dich leichter (bis zu 20 Prozentpunkte), bei viel schwächeren ist es umgekehrt.
- **Kampfleiste (Hotbar):** Sobald ein Gegner, der dich bemerkt hat, in Sicht
  ist, wird die Aktionsleiste zu einer schmalen Hotbar wie in Baldur's Gate,
  damit das Spielfeld groß bleibt. Oben: Runde, Bewegungsbalken (Meter),
  Aktion bereit oder verbraucht, das gewählte Ziel mit Trefferchance und
  „Angreifen“ (Enter), „Runde beenden“ (Leertaste). Darunter in einer Reihe
  kleine Knöpfe mit Tastenkappen: Womit (1–7), Wie (Q–R), Wohin (Y–V),
  Zauber, Sonstiges (Deckung, Spurt, Trank, Fähigkeit, Warten). Was eine Wahl
  kostet und bewirkt, steht im Tooltip. Gegner wählt man auf dem Boden (Klick
  greift an, Tab wechselt das Ziel); das Ziel trägt einen goldenen Ring, über
  dem Gegner unter der Maus steht die Trefferchance. Läuft man im Kampf, wird
  nur der Bewegungsbalken nachgezogen.

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
  Monster schlagen Alarm: Artgenossen im Umkreis von sechs Feldern und andere
  Arten direkt daneben (drei Felder, gleicher Raum) werden aufmerksam. Sie
  suchen dich an der letzten bekannten Stelle,
  Fernkämpfer halten Abstand, Elite und Bosse geraten bei wenig Leben in
  Raserei.
- Was andere Crawler oder weit entfernte Monster tun, erfährst du nur, wenn
  du es siehst. Tötet ein fremder Crawler (nicht in deiner Party) ein Monster,
  bekommst du dafür weder Erfahrung noch Zähler, Kopfgeld oder Boss-Box.
  Friedliche Crawler lassen dich vorbei: Läufst du in sie hinein, tauscht ihr
  die Plätze.
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
- Mobs fliehen selten: kleine Tiere bei wenig Leben, Feiglinge erst ab 40 % Verlust, Diebe mit Beute, alle unter Furcht. Wer in die Ecke gedrängt ist, wehrt sich. Fernkämpfer weichen ab und zu (30 %) einen Schritt zurück. Mobs verlieren das Interesse, wenn man weit weg ist.

### 3.7 Safe Rooms
- Keine Gewalt; Mobs, die angreifen, werden weggebeamt. Monster betreten
  Safe Rooms nie, auch nicht auf der Flucht oder Verfolgung.
- **Eingerichtet:** Jeder Safe Room hat einen **Gratis-Automaten** (1 Gegenstand
  pro Crawler; meist nützlich, manchmal ein Scherzartikel), ab Etage 3
  einen Händler, ein Bett und eine Toilette. **Restaurants** haben zusätzlich einen Wirt mit
  Buff-Essen und Zimmer. Möbel benutzt man, indem man hineinläuft.
- Hier (und in der Gilde) **Lootboxen öffnen**; nur hier **schlafen** (8 h, heilt, Haustier kehrt zurück).
- **Toilette:** Erleichtern darf man sich nur hier (siehe Blase).
- **Laden** (ab Etage 3) mit wechselnder Besitzerin oder wechselndem Besitzer: kaufen,
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
- **Box-Stufe je Etage:** Achievements, Muster, Sponsoren, Fans, Aufträge,
  Talkshow und Bosse geben auf Etage 1 höchstens Silber, ab Etage 2
  höchstens Gold. Aus einer Silberbox wird auf Etage 2 mit 10 %, auf Etage 3
  mit 25 % eine Goldbox (`FLOORS[].goldChance`), beim ersten Mal in der
  Karriere doppelt so oft. Platin gibt es auf Etage 1 bis 3 nur über
  Meisterleistungen. Nur **Meisterleistungen** gehen eine Stufe darüber (Etage 1
  Gold, ab Etage 2 Platin) und enthalten auch eine Seltenheitsstufe mehr:
  Einzelkämpfer (Bezirksboss ganz allein), Nur die Knöchel (Bezirksboss nur
  mit Fäusten), Gewaltfreier Abstieg (Etage 2 ohne einen Kill erreichen),
  Ohne Netz (Etage nach drei Vierteln der Zeit ohne Trank und Schlaf
  verlassen), Geisterhaft (Nachbarschaftsboss besiegen, ohne von ihm
  getroffen zu werden), Adamskostüm (Boss ohne Ausrüstung und Waffe) und
  Blitzsäuberung (alle vier Nachbarschaftsbosse im ersten Drittel der Zeit).
- **Boxen gibt es ab Silber.** Bronze-Erfolge – darunter die erste Stufe
  jeder Achievement-Familie, „Neu im Bestiarium“ und „Routine“ sowie Muster
  mit niedriger Wertung – bringen nur Aufmerksamkeit beim Publikum. Seltene
  Kunststücke (hohe Musterwertung) bringen schon auf Stufe I eine Box.
  Heiltränke, Gegengift und Manatränke liegen nur noch mit einer gewissen
  Wahrscheinlichkeit als Zugabe bei. Sind beide Ring- oder Fußringplätze
  belegt, ersetzt ein neuer Ring den schwächeren.
- Der Erfolge-Tab ist nach 13 Kategorien geordnet, zeigt den Fortschritt je
  Kategorie und die nächsten erreichbaren Ziele.
- Boxen in 6 Stufen (Bronze → Himmlisch) und 11 Themen. **Der Inhalt passt
  zum Thema** (`world.json` `BOX_THEMES`):

  | Box | Inhalt |
  |---|---|
  | Waffen | Waffen und Handschuhe |
  | Schuh | Schuhe und Fußringe |
  | Kleidung | Kopf, Gesicht, Brust, Schultern, Arme, Beine, Unterwäsche, Gürtel, Rücken |
  | Schmuck | Ringe, Ketten, Fußringe |
  | Schläger | Handschuhe, Arm-, Bein-, Fuß- und Kopfschutz; dazu Energydrinks, Wutpillen, Ausdauertränke |
  | Wurf | zur Hälfte Wurfsterne, Dartpfeile, Bowlingkugeln, Brandflaschen, Nagelbomben; sonst Handschuhe, Arme, Schultern, Gürtel; dazu Steine oder Ziegel |
  | Überlebens | zur Hälfte Heiltränke, Gegengift, Verband, Kühlpack, Augentropfen; sonst Kopf, Gesicht, Brust, Gürtel, Rücken |
  | Haustier | Leckerli, Halsbänder, Eier, Superkekse |
  | Fan | beliebige Ausrüstung, Rubbellose, Glückskekse |
  | Abenteurer, Boss | beliebige Ausrüstung, Zauberbücher, manchmal Reittiere |

- **Ab Gold liegt immer ein magischer Gegenstand bei:** ein Unikat mit
  Sonderwirkung aus der Liste des Boxtyps (etwa Faust der Gerechtigkeit in
  der Waffen-Box, Stampfstiefel in der Schuh-Box, Gasmaske in der
  Überlebens-Box) oder – bei Abenteurer-, Boss- und Fan-Boxen – ein
  Zauberbuch. Auch er hält die Seltenheitsgrenze der Etage ein.
- Gold-, Feilsch- und Verkaufserfolge sowie das Finden epischer und
  legendärer Gegenstände bringen Schmuck-Boxen.
- **Mob-Drops:** Normale Monster lassen mit 5 % ein Ausrüstungsteil fallen
  (meist gewöhnlich oder ungewöhnlich, höchstens die Etagengrenze), Elite-
  Monster mit 60 %.

### 3.10 Publikum (ab Etage 2)
- Spektakel (Stampf-Kills, Sprungtritte, Bosse, Achievements, knappe
  Rettungen, Explosionen …) erhöht **Hype** und bringt **Follower**.
- Charisma und Hype multiplizieren den Zuwachs, Hype kühlt mit der Zeit ab.
- Fan-Boxen bei 100 / 250 / 500 / 1.000 / 2.500 / 5.000 / 10.000 … Followern.
- Große Momente bringen manchmal Geschenke aus dem Publikum.
- Zuschauer-Kommentare im Log (Zuschauer xX_Glorbnak_Xx: „DRAUFGESTAMPFT HAHAHA“).
- Highlight-Sendung jeden Abend um 21 Uhr und Einladungen zu Shows: siehe 3.19.

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
- Dazu 17 Zauber insgesamt: Frostnadel (verlangsamt), Kettenblitz (springt auf
  bis zu zwei weitere Gegner über), Donnerschlag (Schaden ringsum, benommen),
  Grelles Licht (blendet), Schreckgestalt (Furcht im Umkreis, nicht bei
  Bossen), Regeneration, Steinhaut (+Rüstung) und Säurespritzer (zersetzt
  dauerhaft 2 Rüstung).

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
  Schlingfalle, Sprengfalle, Waffe benageln (+2 Schaden, bis zu dreimal),
  Heiltränke zusammenkippen, Großer Heiltrank, Manatoast, Ausdauertrank,
  Wurfsterne, Staubbombe, Fallenteile, Schwarzpulver sowie **Kleidung
  polstern** und **Stahlkappen** (+1 Rüstung am Brust- bzw. Fußteil, je bis
  zu zweimal).
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

### 3.19 Rückblick, Highlights und Shows
- Beim Abstieg zeigt die Systemstimme einen **Rückblick** auf die Etage:
  Kämpfe, Fallen, Handwerk, Achievements, erkannte Muster, Party, Gefallene,
  Follower und verbleibende Crawler.
- **Uhrzeit:** Der Dungeon hat jetzt eine Uhr (Spielbeginn Tag 1, 8 Uhr; ein
  Zug sind 3 Minuten). Sie steht oben in der Leiste, das Log zeigt Uhrzeiten.
- **Highlight-Sendung „Abgrund am Abend“** (ab Etage 2, `scripts/engine/highlights.gd`,
  Texte in `data/show.json`): Den Tag über merkt sich die Redaktion die
  spektakulärsten Szenen – besondere Kills (Stampfen, Sprung, Falle, Bombe,
  Haustier, Elite), Bosse, knappe Rettungen, Meisterleistungen, gefallene
  Party-Mitglieder und ab 20 Kills am Tag das „Schlachtfest“. Jeden Abend um
  **21 Uhr** läuft die Sendung bis Mitternacht auf dem **Bildschirm in jedem
  Safe Room**: Szenen anderer Crawler, die eigenen besten Szenen (ab einer
  Wertung von 15), manchmal die Szene des Tages, das Gedenken an die
  Gestorbenen und ein **Tipp der Redaktion**, der einen unbekannten
  besonderen Raum (Schatzkammer, Schrein, Nest, Geheimkammer) auf die Karte
  zeichnet. Wer um 21 Uhr in einem Safe Room ist, sieht sie sofort; sonst
  bis Mitternacht am Bildschirm. Wer vorkommt, gewinnt Follower und Hype –
  auch wenn er selbst nicht zuschaut.
- **Einladungen** (`scripts/engine/invitations.gd`): Nach einer Sendung, in
  der man vorkam, lädt eine Show mit 75 % ein (sonst mit 20 %), wenn man
  bekannt genug ist. Angenommen oder abgesagt wird am Bildschirm im Safe
  Room; eine Einladung gilt 24 Stunden.

  | Format | ab Followern | Ablauf |
  |---|---|---|
  | Frag den Crawler (Fragerunde) | 250 | drei Zuschauerfragen, kleinere Wirkung |
  | Glanz und Gloria (Talkshow) | 1.200 | Fragen nach dem Run, wie bisher |
  | Streitfall Abgrund (Diskussionsrunde) | 3.000 | Thema, zwei Gäste (andere Crawler oder Studiogäste), drei Runden, größere Wirkung |
  | Die Grube (Gladiatorenkampf) | 6.000 und Stufe 5, selten (15 %) | echter Kampf in einer eigenen Arena gegen einen Elite-Gegner der Etage (Stufe +1) |

- Alle Gesprächsformate: Antworten haben einen Ton (ehrlich, witzig, frech,
  bescheiden, dramatisch); riskante Antworten hängen von Charisma und Hype
  ab und können Follower kosten. Eine gute Sendung bringt eine Fan-Box
  (Silber, sehr gut Gold).
- **Die Grube:** Die Etage wartet währenddessen (Gegner, Crawler, Fallen,
  Haustier bleiben, wo sie sind; keine Blase, keine Einlagen, keine
  Aufträge). Sterben kann man dort nicht: Bei null Lebenspunkten ist man
  k. o. und wird mit mindestens einem Viertel der Lebenspunkte
  hinausgeschleift. Sieg: Preisgeld (40 Gold je Etage), eine Schläger-Box
  und viele Follower. Nach 60 Zügen ertönt der Gong (unentschieden).
- **Zwischen den Etagen** gibt es nur noch für Bekannte eine Show: ab 1.200
  Followern die Talkshow, ab 250 die Fragerunde, sonst nur den Rückblick.
- Neue Achievements: Zur besten Sendezeit, Stammgast im Abendprogramm,
  Szene des Tages, Couchkartoffel, Ich bin im Fernsehen!, Frag mich was,
  Streitkultur, Brot und Spiele, Ehrenvoll im Sand, Kein Kommentar.

### 3.20 Sponsoren
- Elf erfundene Sponsoren (Kristallhaus Vornex, Brennstoffwerke Pyrrax,
  Gräfin Oolu vom Nebelmond, Konsortium Grimmzahn, Die Schleimbrüder GmbH,
  Galaktische Mode AG, Orbitalakademie Arkanum, Tiefgrabe & Söhne, Ballsaal
  Zirr, Kirche des Siebten Mondes, Sternfracht Logistik) mit eigenem
  Geschmack: Stil, Explosionen, Haustiere, Mut, schmutzige Tricks, absurde
  Mode, Zauberei, Schatzsuche, Ausweichen, Gebete und gute Taten, Aufträge.
- Passende Aktionen wecken Interesse (mehr Hype = schneller). Ab 100 Interesse
  und genug Followern kommt ein Angebot; bis zu drei Sponsoren gleichzeitig.
- Aktive Sponsoren haben Wünsche; jeder erfüllte Wunsch bringt eine
  Sponsorenbox (mit steigender Stufe). Wer tut, was sie nicht mögen, verliert
  Gunst – bei 0 ist das Sponsoring vorbei.

### 3.21 Aufträge
- **Ab Etage 3.** Andere Crawler (manchmal beim ersten Gespräch) und jeder
  Laden bieten Aufträge an: **Jagd** (Gegner einer Art), **Finden** (verlorenes Andenken
  in einem anderen Viertel), **Liefern** (Tränke, Essen, Lappen …),
  **Retten** (eingeschlossener Crawler, von Monstern bewacht), **Boss**,
  **Nest ausräumen** und **Schatzkammer öffnen**.
- **Auftragsketten:** Manche Crawler erzählen eine kleine Geschichte in drei
  Teilen (sechs Ketten, etwa „Die letzte Probe“ oder „Der Tresor“). Jeder
  Teil zahlt mehr, der letzte immer mit Box und einem seltenen Gegenstand.
- Belohnung: Gold, XP, oft eine Lootbox; Ladenbesitzer geben danach 15 %
  Freundschaftsrabatt. Aufträge scheitern, wenn der Auftraggeber stirbt oder
  die Etage verlassen wird. Bis zu fünf offene Aufträge.

- **Wanderhändler** (Sonderraum, erst ab der Etage mit Handel; in der
  Kanalstadt übernehmen das die Märkte der Siedlung) haben ein eigenes Sortiment: Waffenhändler,
  Wanderapotheke (mit Zauberbüchern), Schrotthändler (Handwerksmaterial,
  Klappwerkbank) oder Kuriositätenhändler (Tattoos, Talismane, Eier). Sie
  sind etwas teurer als die Läden in den Safe Rooms; auch Feilschen rechnet
  mit diesem höheren Grundpreis.
- Neue Achievement-Familien: Kisten, Geheimtüren, Schlösser, Schatzkammern,
  Nester, Gebete, Hinterhalte, Boss-Angriffen ausweichen, Auftragsketten.

### 3.22 Reittiere und Fahrzeuge
- Motorisierter Einkaufswagen, Aufsitzrasenmäher, Raketen-Bobbycar (Fahrzeuge,
  brauchen Benzin) sowie Kellerpony, Sattelschnecke und Kampfeber (Tiere).
  Man bekommt sie über Zündschlüssel und Pfeifen aus Läden und guten Boxen.
- Beritten: 2–3 Schritte pro Zug (Schnecke: 1, dafür +3 Rüstung),
  **Anlauf rammt** mit Zusatzschaden und Umwerf-Chance, ohne vorher laufen zu
  müssen. Ein Teil der Treffer geht auf das Reittier; Fahrzeuge können
  zerstört werden, Tiere erholen sich beim Schlafen. Im Safe Room steigt man ab.
  Taste M zum Auf- und Absteigen.

### 3.23 Klänge und Musik
Im Spiel erzeugt (keine Audiodateien): Lootbox (Knarzen und Glitzern, je
nach Stufe länger), Level-Aufstieg (Fanfare), Achievement (Glockenschlag),
neuer Skill, Kampfbeginn und -ende, Versus-Bildschirm, Tippgeräusch.
Musik: Jede Etage hat eine Klangkulisse aus tiefem, schwebendem Brummen
(Keller: Luftzug; Kanalstadt: fließendes Wasser) und zufälligen Geräuschen
(Tropfen, Knarzen, Ketten, fernes Grollen, Blubbern). Im Kampf blendet eine
Chiptune-Schleife in a-Moll ein (Bass, Arpeggio, Melodie, Schlagzeug), bei
Bossen schneller und höher; danach blendet sie wieder aus. Schalter „Ton“,
„Tippen“ und „Musik“ in der oberen Leiste.

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

### 3.25 Gelände und besondere Räume
Jede Etage bekommt Gelände und Sonderräume (`scripts/engine/dungeon.gd`):

| Baustein | Wirkung |
|---|---|
| Seichtes Wasser | begehbar, löscht Brand bei Crawler und Monstern |
| Schlamm | wer hineintritt, verliert den nächsten Zug (Crawler und Monster) |
| Kisten und Fässer | versperren den Weg; hineinlaufen zerschlägt sie: meist leer oder Material, manchmal Gold oder Vorräte, selten ein Mimic |
| Schatzkammer | ummauert, Türen verschlossen; der rostige Schlüssel liegt im selben Viertel. Alternativ Schloss knacken (Geschick, Fallenkunde), Fehlschläge können Schläfer wecken |
| Geheimkammer | hinter einer Wand; Geheimtüren fallen in bis zu 2 Feldern Abstand auf (Intelligenz, Wahrnehmung), Warten sucht mit |
| Monsternest | Rudel eines schwachen Monsters; ist das Nest leer, liegen Gold und Beute darin |
| Schrein | einmal beten: Segen (80 Züge), volle Heilung, nichts oder ein Fluch (40 Züge); Charisma hilft |
| Wanderhändler | Laden außerhalb der Safe Rooms: kaufen, feilschen, verkaufen |
| Hinterhalt | leerer Raum, mindestens 20 Felder vom Start; beim Betreten treten wache Gegner der mittleren Etagenstufe aus den Zugängen (Etage 1: zwei, danach zwei bis vier) |

Ummauerte Kammern entstehen nur, wenn danach noch alle anderen Räume und
Treppen erreichbar sind; Auftragsziele liegen nie darin.

### 3.26 Bosskämpfe: Phasen und Spezialangriffe
Bosse kämpfen in drei Phasen (`scripts/engine/boss_fight.gd`):

- **Phasenwechsel** bei 66 % und 33 % Lebenspunkten: eigener Satz je Boss,
  Rufer holen sofort Verstärkung, die Pause zwischen Spezialangriffen wird
  kürzer (5, 4, 3 Züge). Unter 30 % gerät der Boss zusätzlich in Raserei.
- **Spezialangriffe werden angekündigt:** Der Boss holt aus, die betroffenen
  Felder leuchten rot und pulsieren (Tooltip: Gefahrenzone). Im nächsten Zug
  schlägt der Angriff ein. Wer dann nicht mehr auf einem roten Feld steht,
  weicht aus (gezählt als `bossDodges`); Rüstung zählt nur halb.
- **Formen:** Stampfen (rund um den Boss), Schockwelle (Ring in zwei Feldern
  Abstand), Ansturm (gerade Bahn, der Boss rennt mit), Trümmerhagel (Feld
  des Crawlers und zufällige daneben), Flammenteppich, Giftwolke,
  Staubwolke (Kreuz um den Crawler, mit Brand, Gift oder Blindheit),
  Markerschütternder Schrei (Furcht direkt um den Boss). Jeder Angriff lässt
  sich mit einem passenden Schritt verlassen.
- **Balance (Duell-Simulation, typische Ausrüstung, zwei Heiltränke):**
  Nachbarschaftsbosse auf Etage 1 gewinnt ein Crawler der Stufe 5 zu 45 bis
  100 %, auf Etage 3 mit Stufe 11 zu 35 bis 90 %. Die Endbosse der Etagen
  (Kesselkönigin, Hausverwalter, Rattenkaiser) sind allein kaum zu schaffen
  und brauchen Zauber, Haustier oder Party. Boss-Regeneration 1,5 % pro Zug,
  Diener fünf Stufen unter dem Boss, höchstens drei Rufe.
- **Stufen der Gegner:** Sie steigen mit dem Abstand zum Start (Abstand hoch
  1,3, also nahe am Start langsam). Nachzügler – Nachspawns, Mimics in Kisten,
  Wächter bei Rettungsaufträgen – liegen höchstens zwei Stufen über dem
  Crawler (innerhalb des Bereichs der Etage).
- **Erfahrung nach Gefahr:** Schwere Arten (Ghul, Tatzelwurm, Waschmaschine,
  Troll-Lehrling, Reifenstapel, Kanalkroko, Rohrgolem, Brückentroll …) geben
  mehr Erfahrung, damit sich das Risiko lohnt (Faustregel: Erfahrung im
  Verhältnis zu Lebenspunkten mal Schaden nicht unter drei Viertel des
  Etagenmittels). Arten von höheren Etagen kommen tiefer unten nur halb so oft
  vor, damit jede Etage ihre eigenen Bewohner zeigt.
- Welche Angriffe ein Boss kann und seine Phasensätze stehen in
  `data/monsters.json` (`BOSS_SPECIALS`, `HOOD_BOSSES[].specials`,
  `phaseLines`).

### 3.27 Etage 3: Die Kanalstadt
Etage 3 hat eine eigene Gestalt (`scripts/engine/kanalstadt.gd`):

- **Kanäle:** Zwei waagerechte und ein senkrechter Kanal, je zwei Felder
  breit, ziehen quer über die Karte. Tiefes Wasser ist nicht begehbar, aber
  durchsichtig: Man sieht über den Kanal hinweg, und Fernkämpfer schießen
  hinüber. Wo ein Gang kreuzt, liegt eine **Brücke**; durchquert ein Kanal
  einen normalen Raum, wird er dort zu seichtem Wasser. Besondere Räume,
  Türen und Treppen bleiben unberührt, alles bleibt erreichbar.
- **Siedlung:** Drei Räume nahe der Kartenmitte bilden die Siedlung der
  Kanalstadt, jeder mit eigenem Händler (Pumpwerk-Apotheke, Waffenmarkt am
  Wehr, Schrottplatz unter der Brücke oder Kuriositätenkabinett). Dort
  wohnen feste **Bewohner** mit eigenen Sätzen; sie bieten Aufträge an,
  gehen aber nicht mit auf Reisen. Monster betreten die Siedlung nicht und
  wachsen dort auch nicht nach.
- **Zwölf neue Monster:** Schlickkrebs, Stromaal, Riesenblutegel,
  Gullyqualle, Lumpensammler, Rohrgolem, Schimmelteppich, Kloakenhund,
  Verlorener Schleusenwärter, Faulgasblase, Treibgut-Haufen und Brückentroll,
  dazu vier neue Figuren (Krebs, Aal, Egel, Qualle). Zusammen mit den zehn
  bisherigen hat Etage 3 jetzt 22 eigene Monster.

### 3.28 Etage 2: Die Tiefgaragen
Etage 2 hat ein eigenes Thema (`scripts/engine/tiefgarage.gd`): die zu einem
Labyrinth verschmolzenen Tiefgaragen der Stadt, mit eigenen Raumnamen
(Parkdeck, Rampe, Kassenhäuschen, Waschstraße, Reifenlager …).

- **Parkdecks:** Bis zu vier große Räume werden Parkdecks mit weißen
  Stellplatzlinien und Reihen von **Autowracks** an den Längsseiten; die
  Mitte bleibt als Fahrspur frei. Wracks versperren den Weg, aber nicht die
  Sicht. Hineinlaufen durchsucht ein Wrack einmal: Kram, Vorräte, Gold,
  manchmal Ausrüstung oder Werkzeug. In jedem fünften Wrack springt die
  **Alarmanlage** an und weckt alles im Umkreis von neun Feldern.
- **Öl:** Ölpfützen auf den Decks und in Gängen. Wer hineintritt, rutscht
  oft aus und verliert den nächsten Zug (Monster auch). Wer brennend
  hineintritt, setzt die Pfütze in Brand.
- **Eigene Bosse:** Der Parkwächter (ruft Verstärkung, Ansturm und
  Trümmerhagel), Die Rostkönigin (gepanzert, Stampfen und Schockwelle), Der
  Ölschlick (Gift, Flammenteppich, Giftwolke) und Der Abschleppwurm (schnell,
  Ansturm und Stampfen), jeder mit eigener Figur, Phasensätzen und Beute
  (Parkscheiben-Schild, Strafzettelblock, Rostkrone, Ölkanister-Rucksack,
  Abschlepphaken). Die Bosse von Etage 1 tauchen hier nicht mehr auf.
- **Sechs neue Monster:** Rostkäfer, Ölschleim, Abgasgeist, Wütender
  Parkautomat, Verwilderte Garagenkatze und Reifenstapel (ein Mimic).
- Neue Achievement-Familien: Autowracks durchsuchen, Alarmanlagen auslösen.

### 3.29 Einlagen der Show
Nach dem Tutorial ruft die Regie etwa alle 220–340 Züge eine Einlage aus (die erste rund 120 Züge nach dem Tutorial, nie im Safe Room). Sie gilt nur auf der aktuellen Etage und läuft 30–120 Züge. Oben in der Kopfzeile und im Reiter „Ziele“ steht, welche Einlage läuft und wie lange noch.

| Einlage | Wirkung |
|---|---|
| Doppelte Erfahrung | +100 % Erfahrung |
| Goldrausch | Monster lassen dreimal so viel Gold fallen |
| Licht aus! | Sichtweite −2, dafür +50 % Erfahrung |
| Schnäppchenstunde | Händlerpreise −30 % (nur ab Etage 3, wenn es Händler gibt) |
| Erste Hilfe | +2 HP-Regeneration |
| Kritische Stunde | +15 % Krit-Chance |
| Kopfgeld | Der stärkste Nicht-Boss der Etage wird markiert (auf der Karte „Kopfgeld“). Wer ihn erledigt, erhält 40 × Etage + 10 × Stufe Gold. Erledigt ihn jemand anderes oder läuft die Zeit ab, verfällt es. |

Dazu: Achievement-Familien „Einlagen“ (1/5/12) und „Kopfgelder“ (1/3/8), Sponsor „Kopfjäger Wettbüro“ (mag Kopfgelder, Einlagen und Elite-Kills, hasst verfallene Kopfgelder) und neue Verbrauchsgegenstände: Kühlpack (löscht Brennen), Augentropfen (gegen Blindheit), Baldriantropfen (gegen Furcht), Glückskeks (+8 % Krit), Blaue Fokuspille (+10 Treffer, −3 Ausweichen), Dose Unterbodenschutz (+2 Rüstung) und Thermoskanne Kaffee (+1 Sichtweite). Sie liegen am Boden, in Autowracks und bei den Wanderhändlern.

### 3.30 Aufbau der Oberfläche
Schrift überall: Jersey 10 (Pixelschrift im Stil von Tiny Swords).
- **Kopfzeile:** links Etage, Uhrzeit, Einsturz-Zeit, laufende Einlage, Zuschauer (Details im Tooltip), Gold, Lootboxen (nur wenn vorhanden) und „Menü“ (Esc); rechts die **Reiter** Crawler (P), Ziele (Z), Inventar (I), Ausrüstung (A), Handwerk (B), Skills (L), Erfolge (O). Ein Klick oder die Taste klappt den Reiter als Tafel oben rechts über der Karte auf, derselbe Klick, „Schließen“, Esc oder ein Klick daneben klappt ihn zu; das zuletzt geöffnete Fenster liegt oben, Dialoge immer über allem; Tab blättert außerhalb des Kampfes. Ein goldener Punkt zeigt, wo etwas wartet (freie Punkte, Angebote, Abgaben, Kopfgeld). Das **Inventar** ist eine schlichte Liste (Symbol, Name, Art); ein Klick klappt Werte und Aktionen auf. Die **Ausrüstung** hat eine eigene Seite: was am Körper ist, ebenso aufklappbar (Ausziehen), darunter die freien Plätze.
- **Rechts, oben immer sichtbar:** Name, Stufe, Klasse, Balken für HP, Ausdauer, Mana, Blase und Erfahrung, dazu Zustände, Haustier, Reittier und Party. Freie Wertepunkte erscheinen als Knopf.
- **„Hier“** darunter: nur wenn es am Standort etwas zu tun gibt (Safe Room, Gilde mit Lootboxen, Händler, Crawler, Fallen); einklappbar (N), höchstens 40 % der Höhe.
- **Chat** rechts darunter, über die ganze restliche Höhe und in größerer Schrift: Filter Alles, Kampf, Funde, Gespräche und ein Knopf „Überspringen“; nur drei Farben (Text, Gold für Funde und Erfolge, Rot für Gefahr); gleiche Zeilen hintereinander werden zusammengefasst („(9×)“).
- **Aktionsleiste unten** außerhalb des Kampfes: eine schmale Zeile mit dem gewählten Angriff, Fähigkeit, Warten, Aufheben, Reittier und Zaubern; im Kampf die Hotbar (siehe 3.4).
- **Rechtsklick auf die Karte:** Menü mit allem, was auf dem Feld geht (aufheben, angreifen, ansprechen, benutzen, Tür öffnen, Kiste zerschlagen, Wrack durchsuchen, entschärfen, hinabsteigen, hierher gehen, untersuchen). Liegt das Ziel weiter weg, läuft die Figur erst hin.
- **Laufen:** Außerhalb des Kampfes läuft die Figur ohne Halt bis ans Ziel (Klick) oder solange die Taste gedrückt ist, in festem Takt und gleichmäßig. Anhalten nur bei Gefahr: Kampf beginnt, Schaden, neu entdeckte Falle. Gespeichert und alles neu aufgebaut wird, sobald sie steht.
- **Start:** Nach der Begrüßung erklärt „So spielst du“ in fünf Seiten Laufen, Handeln (Rechtsklick), Kämpfen, Bildschirm und das erste Ziel. Die Gilde der Einweisung ist von Anfang an aufgedeckt, auf der Karte beschriftet und auf der Übersichtskarte umrahmt, bis das Inventar freigeschaltet ist.
- **Interaktives Tutorial (`guide.gd`):** Statt Texttafeln zeigt ein goldener Pfeil auf ein Teil der Oberfläche, das Teil blinkt, ein Kasten daneben sagt, was es ist und was man jetzt tun soll. Weiter geht es erst, wenn man es ausprobiert hat. Jeder Bereich kommt einzeln dran (26 Schritte): auf den Boden klicken, Maus gedrückt halten, Pfeiltasten, Rechtsklick, Karte oben links (groß und klein), Ortsname, Zoom, Etage, Uhrzeit, Einsturz, Gold, Lootboxen, Werte (Lebenspunkte, Ausdauer, Mana, Blase), „Hier“, Chat mit Filtern, jeder Reiter einzeln (Crawler, Ziele, Inventar, Ausrüstung, Handwerk, Skills, Erfolge), Zuklappen per Klick daneben, Aktionsleiste („Warten“), Menü und zum Schluss der Weg zur Gilde der Einweisung. Die Texte sagen „Boden“ für das Spielfeld und „Karte“ nur für die Karte oben links. Beim ersten Kampf folgt die Kampfleiste Teil für Teil (8 Schritte): Runde und Bewegung, Womit (etwas anderes wählen), Wie, Wohin (eine Zone wählen), Sonstiges mit Spurt, Ziel, einen Gegner anklicken, Runde beenden; endet der Kampf vorher, geht es beim nächsten an derselben Stelle weiter. „Tutorial beenden“ lässt alles aus; im Menü lässt es sich wiederholen. Der Fortschritt steht in den Metadaten (meta.guide). Der Guide in der Gilde erklärt nur noch Regeln (Timer, Bosse, Safe Rooms, Mana, Toiletten), nicht mehr den Bildschirm.
- **Texte überspringen:** Solange ein Dialogtext getippt wird, steht unten „Text überspringen“; mehrseitige Dialoge haben „Alles überspringen“.
- **Linke Maustaste halten:** Nach einem kurzen Moment folgt die Figur der Maus, bis man loslässt oder ein Kampf beginnt.
- **Anziehen vom Boden:** Ausrüstung am Boden lässt sich direkt anziehen (Rechtsklick oder „Hier“); was vorher an dem Platz war, bleibt liegen. Geht auch ohne Inventar, nur Waffen nimmt man dann in die Hand.

### 3.31 Zeit nutzen: Schwierigkeit der nächsten Etage
Jede Etage ist so ausgelegt, dass man sie gut schafft, wenn man die vorige
Etage weitgehend ausgenutzt hat – und nicht, wenn man zu früh hinuntergeht.

- **Stärkefaktor je Etage** (`world.json` FLOORS[].mobScale, bossScale):
  | Etage | normale Monster (HP / Schaden / XP) | Bosse (HP / Schaden / XP) | höchste Box-Seltenheit |
  |---|---|---|---|
  | 1 | 1 / 1 / 1 | 1 / 1 / 1 | selten |
  | 2 | 4,5 / 4 / 3 | 2,6 / 2,6 / 2,5 | episch |
  | 3 | 5 / 4,5 / 3,5 | 5 / 5 / 4 | legendär |
  Elite-Gegner bekommen auf Etage 2 und 3 nur einen kleineren Aufschlag
  (1,4-fache HP, 1,15-facher Schaden) zusätzlich zum Etagenfaktor.
- **Beute wächst mit dem Abstieg:** Box-Inhalte sind auf die Seltenheit der
  Etage begrenzt, auf der die Box verdient wurde (Boss-Boxen eine Stufe
  mehr). Auf Etage 1 gibt es also keine legendären Waffen.
- **Endspurt:** Ab der Hälfte der Etagenzeit gibt jeder Kill mehr Erfahrung,
  bis zum Einsturz fast doppelt so viel (bei 75 % +50 %, bei 95 % +90 %).
  Oben in der Kopfzeile steht „Endspurt +x % XP“, im Log hinter der
  Erfahrung. Wer bleibt, steigt so spürbar weiter auf.
- **Der Dungeon bleibt in Bewegung:** Nachschub kommt auch in Vierteln ohne
  Boss (halb so oft), und je näher der Einsturz, desto höher die Stufe der
  Nachzügler (gegen Ende bis zur Obergrenze der Etage, höchstens eine Stufe
  über dem Crawler). Wer bleibt und kämpft, steigt weiter auf.
- **Eichung** (Werkzeug `tools/calib_sim.gd` mit Schnappschüssen des Bots bei
  der Ankunft): verlorene HP pro Kampf gegen normale Gegner der neuen Etage,
  ohne Tränke, am Etagenanfang und in der Mitte:
  | genutzte Zeit der vorigen Etage | Etage 2 | Etage 3 |
  |---|---|---|
  | 95 % | 7 % / 10 % | 6 % / 12 % |
  | 70 % | 9 % / 13 % | 12 % / 22 % |
  | 50 % | 14 % / 21 % | (zu wenige Messungen) |
  Ein Dreierpack oder eine Kette von Kämpfen ist damit gut vorbereitet
  machbar und zu früh hinabgestiegen gefährlich; Fähigkeiten der Gegner
  (Gift, Brand, Fernkampf, Rudel) machen es zusätzlich fordernd.
  Nachbarschaftsbosse gewinnt ein gut vorbereiteter Crawler in etwa 55 bis
  95 % der Fälle, wer nach der halben Zeit kommt, in etwa der Hälfte.
  Die Messung stammt aus Schnappschüssen vor Einführung des Endspurts; wer
  die Zeit nutzt, kommt inzwischen noch etwas stärker an.
- Wer die Treppe nimmt, solange noch mehr als 30 % der Etagenzeit übrig sind,
  bekommt im Treppendialog einen Hinweis.

## 4. Tod & Hardcore (alle vier Konzepte)

1. **Permadeath + Staffeln:** Tod beendet den Run endgültig. Erhalten bleiben
   Hall of Fame, Karriere-Achievements, Bestiarium.
2. **Der Tote wird zum Mob:** Der gestorbene Crawler spukt in späteren Staffeln
   als Geist auf seiner Todesetage – mit seiner Ausrüstung als Beute. Der Geist
   ist so stark wie ein Elite-Gegner der Etage (Stufe höchstens 2 + 2 × Etage,
   Etagenfaktor), nicht wie der Crawler auf seinem Höhepunkt, und schwebt durch
   Wände, statt an Ecken hängen zu bleiben.
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
  assets/tinyswords/ Teile aus dem Tiny-Swords-Pack (Oberfläche, Wände, Wasser, Effekte)
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
