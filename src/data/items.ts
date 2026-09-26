import type { Bonuses, ConsumableEffect, ItemKind, Rarity, Slot, SpecialEffect, TrapKind } from '../engine/types';

export interface BaseItem {
  id: string;
  name: string;
  kind: ItemKind;
  slot?: Slot;
  bonuses?: Bonuses;
  waffenSchaden?: number;
  wurfSchaden?: number;
  effekt?: ConsumableEffect;
  flavor: string;
  wert: number;
  /** Pass/Talisman: diese Gegnerart greift nicht an. */
  passFacet?: string;
  /** Erlaubt das Auftauchen als Bodenfund. */
  ground?: number;
  /** Wurfobjekt explodiert beim Aufprall (Schaden im Umkreis). */
  explosion?: number;
  /** Eigene Falle zum Aufstellen. */
  trapKind?: TrapKind;
  /** Halsband: Bonus für das Haustier. */
  petBonus?: { hp?: number; dmg?: number };
}

export const RARITY_ORDER: Rarity[] = ['gewoehnlich', 'ungewoehnlich', 'selten', 'episch', 'legendaer', 'himmlisch'];

export const RARITY_NAMES: Record<Rarity, string> = {
  gewoehnlich: 'Gewöhnlich',
  ungewoehnlich: 'Ungewöhnlich',
  selten: 'Selten',
  episch: 'Episch',
  legendaer: 'Legendär',
  himmlisch: 'Himmlisch',
};

export const RARITY_COLORS: Record<Rarity, string> = {
  gewoehnlich: '#c8c8c8',
  ungewoehnlich: '#5fd35f',
  selten: '#4a9eff',
  episch: '#b366ff',
  legendaer: '#ff9d2e',
  himmlisch: '#7ff5ff',
};

export const SLOT_NAMES: Record<Slot, string> = {
  kopf: 'Kopf', gesicht: 'Gesicht', hals: 'Hals', schultern: 'Schultern', brust: 'Brust',
  ruecken: 'Rücken', arme: 'Arme', haende: 'Hände', ring: 'Ring', guertel: 'Gürtel',
  beine: 'Beine', fuesse: 'Füße', fussring: 'Fußring', unterwaesche: 'Unterwäsche', waffe: 'Waffe',
};

export const BASE_ITEMS: BaseItem[] = [
  // ---- Wurfobjekte
  { id: 'stein', name: 'Stein', kind: 'wurf', wurfSchaden: 3, flavor: 'Ein Stein. Die älteste Waffe der Menschheit, und immer noch im Rennen.', wert: 0, ground: 12 },
  { id: 'ziegel', name: 'Ziegelstein', kind: 'wurf', wurfSchaden: 5, flavor: 'Schwer, eckig, zuverlässig.', wert: 1, ground: 5 },
  { id: 'flasche', name: 'Leere Bierflasche', kind: 'wurf', wurfSchaden: 4, flavor: 'Leer. Leider.', wert: 0, ground: 6 },
  { id: 'dose', name: 'Ravioli-Dose', kind: 'wurf', wurfSchaden: 3, flavor: 'Mindestens haltbar bis zum Ende der Welt. Gratulation, geschafft.', wert: 1, ground: 4 },

  // ---- Improvisierte Waffen
  { id: 'rohr', name: 'Rostiges Rohr', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 4, flavor: 'Tetanus inklusive.', wert: 3, ground: 3 },
  { id: 'stuhlbein', name: 'Stuhlbein', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 3, flavor: 'Der Rest des Stuhls hat es nicht geschafft.', wert: 2, ground: 3 },
  { id: 'bratpfanne', name: 'Bratpfanne', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 4, bonuses: { ruestung: 1 }, flavor: 'Klassiker. *Bonk.*', wert: 4, ground: 2 },
  { id: 'nudelholz', name: 'Nudelholz', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 3, bonuses: { krit: 5 }, flavor: 'Omas Lieblingswaffe.', wert: 3, ground: 2 },
  { id: 'hockeyschlaeger', name: 'Hockeyschläger', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 5, flavor: 'Kanadische Diplomatie.', wert: 6 },
  { id: 'brecheisen', name: 'Brecheisen', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 6, flavor: 'Öffnet Türen und Schädel.', wert: 8 },
  { id: 'schlagring', name: 'Schlagring', kind: 'ausruestung', slot: 'haende', bonuses: { schaden: { faust: 20 } }, flavor: 'Erhöht Faustschaden, ohne als Waffe zu zählen.', wert: 8 },

  // ---- Kleidung
  { id: 'wollmuetze', name: 'Wollmütze', kind: 'ausruestung', slot: 'kopf', bonuses: { ruestung: 1 }, flavor: 'Selbstgestrickt. Kratzt.', wert: 2, ground: 2 },
  { id: 'bauhelm', name: 'Bauhelm', kind: 'ausruestung', slot: 'kopf', bonuses: { ruestung: 2 }, flavor: 'Gelb. Sicherheit geht vor.', wert: 5, ground: 1 },
  { id: 'kochtopf', name: 'Kochtopf', kind: 'ausruestung', slot: 'kopf', bonuses: { ruestung: 2, stats: { cha: -1 } }, flavor: 'Du siehst lächerlich aus. Aber lebendig.', wert: 2, ground: 2 },
  { id: 'sonnenbrille', name: 'Sonnenbrille', kind: 'ausruestung', slot: 'gesicht', bonuses: { stats: { cha: 1 } }, flavor: 'Im Keller. Mutig.', wert: 3, ground: 1 },
  { id: 'taucherbrille', name: 'Taucherbrille', kind: 'ausruestung', slot: 'gesicht', bonuses: { treffer: 2 }, flavor: 'Schützt vor Schleimspritzern.', wert: 3 },
  { id: 'schal', name: 'Fußballschal', kind: 'ausruestung', slot: 'hals', bonuses: { maxHp: 2 }, flavor: 'Der Verein ist tot. Der Schal lebt.', wert: 2, ground: 1 },
  { id: 'kette', name: 'Goldkettchen', kind: 'ausruestung', slot: 'hals', bonuses: { stats: { cha: 1 } }, flavor: 'Protzig. Vermutlich nicht mal echt.', wert: 6 },
  { id: 'schulterpolster', name: 'Schulterpolster', kind: 'ausruestung', slot: 'schultern', bonuses: { ruestung: 1 }, flavor: 'Aus einem 80er-Jahre-Blazer geschnitten.', wert: 3 },
  { id: 'lederjacke', name: 'Lederjacke', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 2, stats: { cha: 1 } }, flavor: 'Cool. Wirklich cool.', wert: 8 },
  { id: 'warnweste', name: 'Warnweste', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 1 }, flavor: 'Du bist jetzt offiziell sichtbar. Für alle Monster.', wert: 3, ground: 1 },
  { id: 'rucksack', name: 'Schulranzen', kind: 'ausruestung', slot: 'ruecken', bonuses: { maxAusdauer: 2 }, flavor: 'Mit Einhorn-Motiv.', wert: 3, ground: 1 },
  { id: 'armschoner', name: 'Schienbeinschoner (für die Arme)', kind: 'ausruestung', slot: 'arme', bonuses: { ruestung: 1 }, flavor: 'Zweckentfremdet, aber funktional.', wert: 3 },
  { id: 'gartenhandschuhe', name: 'Gartenhandschuhe', kind: 'ausruestung', slot: 'haende', bonuses: { schaden: { faust: 5 } }, flavor: 'Blumenmuster.', wert: 2, ground: 1 },
  { id: 'boxhandschuhe', name: 'Boxhandschuhe', kind: 'ausruestung', slot: 'haende', bonuses: { schaden: { faust: 15 }, treffer: -3 }, flavor: 'Rot. Gepolstert. Gemein.', wert: 8 },
  { id: 'guertel', name: 'Werkzeuggürtel', kind: 'ausruestung', slot: 'guertel', bonuses: { stats: { str: 1 } }, flavor: 'Ohne Werkzeug. Mit Hoffnung.', wert: 4 },
  { id: 'jogginghose', name: 'Jogginghose', kind: 'ausruestung', slot: 'beine', bonuses: { ausweichen: 2 }, flavor: 'Wer Jogginghose trägt, hat die Kontrolle über sein Leben verloren. Passt ja.', wert: 2, ground: 1 },
  { id: 'cargohose', name: 'Cargohose', kind: 'ausruestung', slot: 'beine', bonuses: { ruestung: 1 }, flavor: 'So viele Taschen. Alle leer.', wert: 4 },
  { id: 'flipflops', name: 'Flip-Flops', kind: 'ausruestung', slot: 'fuesse', bonuses: { ausweichen: -2 }, flavor: 'Die schlechtestmögliche Wahl. Die Zuschauer lieben es.', wert: 1, ground: 1 },
  { id: 'turnschuhe', name: 'Turnschuhe', kind: 'ausruestung', slot: 'fuesse', bonuses: { ausweichen: 2, schaden: { tritt: 5 } }, flavor: 'Leuchten beim Auftreten.', wert: 5 },
  { id: 'arbeitsstiefel', name: 'Stahlkappenstiefel', kind: 'ausruestung', slot: 'fuesse', bonuses: { ruestung: 1, schaden: { tritt: 15 } }, flavor: 'Für Tritte mit Nachdruck.', wert: 9 },
  { id: 'ring_plastik', name: 'Plastikring aus dem Kaugummiautomat', kind: 'ausruestung', slot: 'ring', bonuses: { stats: { cha: 1 } }, flavor: 'Mit Glitzerstein.', wert: 1, ground: 1 },
  { id: 'ring_ehe', name: 'Fremder Ehering', kind: 'ausruestung', slot: 'ring', bonuses: { maxHp: 2 }, flavor: 'Wem der wohl gehörte? Besser nicht drüber nachdenken.', wert: 5 },
  { id: 'fussring_gummi', name: 'Gummiband-Fußring', kind: 'ausruestung', slot: 'fussring', bonuses: { ausweichen: 1 }, flavor: 'Schneidet leicht ein.', wert: 1 },
  { id: 'fussring_gold', name: 'Goldener Fußreif', kind: 'ausruestung', slot: 'fussring', bonuses: { schaden: { tritt: 5 } }, flavor: 'Klimpert beim Treten.', wert: 6 },
  { id: 'boxershorts', name: 'Boxershorts mit Herzchen', kind: 'ausruestung', slot: 'unterwaesche', bonuses: { stats: { cha: 1 } }, flavor: 'Die Zuschauer haben abgestimmt: süß.', wert: 2 },
  { id: 'feinripp', name: 'Feinripp-Unterhemd', kind: 'ausruestung', slot: 'unterwaesche', bonuses: { maxHp: 1 }, flavor: 'Deutsches Kulturgut.', wert: 2 },

  // ---- Startkleidung (Interview)
  { id: 'brille', name: 'Deine Brille', kind: 'ausruestung', slot: 'gesicht', bonuses: { treffer: 3 }, flavor: 'Ohne sie ist die Welt verschwommen. Mit ihr leider auch nicht schöner.', wert: 2 },
  { id: 'rohrzange', name: 'Rohrzange', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 5, flavor: 'Aus deinem Werkzeugkoffer. Hat schon viele Rohre gesehen. Jetzt sieht sie Schädel.', wert: 5 },
  { id: 'handy', name: 'Handy ohne Netz', kind: 'wurf', wurfSchaden: 2, flavor: 'Kein Netz. Kein Akku bald. Aber es fliegt ganz gut.', wert: 0 },
  { id: 'fernbedienung', name: 'Fernbedienung', kind: 'wurf', wurfSchaden: 2, flavor: 'Hat noch nie funktioniert, wenn man sie brauchte. Jetzt auch nicht.', wert: 0 },
  { id: 'schluesselbund', name: 'Schlüsselbund', kind: 'wurf', wurfSchaden: 3, flavor: 'Schlüssel für ein Haus, das es nicht mehr gibt.', wert: 0 },
  { id: 'kochmesser', name: 'Kochmesser', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 5, bonuses: { krit: 5 }, flavor: 'Scharf. Sehr scharf. Du hast damit Zwiebeln geschnitten. Früher.', wert: 6 },
  { id: 'trillerpfeife', name: 'Trillerpfeife', kind: 'ausruestung', slot: 'hals', bonuses: { stats: { cha: 1 } }, flavor: 'Vom Sportunterricht. Pfeifen hilft nicht gegen Monster. Aber es fühlt sich gut an.', wert: 1 },
  { id: 'bademantel', name: 'Bademantel', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 0, stats: { cha: 1 } }, flavor: 'Flauschig. Offen. Leider.', wert: 1 },
  { id: 'schlafanzug', name: 'Dino-Schlafanzug', kind: 'ausruestung', slot: 'brust', bonuses: { maxHp: 1 }, flavor: 'Mit Kapuze. Die Kapuze hat Zähne.', wert: 1 },
  { id: 'anzug', name: 'Zerknitterter Anzug', kind: 'ausruestung', slot: 'brust', bonuses: { stats: { cha: 2 } }, flavor: 'Du warst auf dem Weg zu einem Meeting. Das Meeting wurde abgesagt. Die Erde auch.', wert: 3 },
  { id: 'arbeitsjacke', name: 'Arbeitsjacke', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 1 }, flavor: 'Mit Firmenlogo einer Firma, die es nicht mehr gibt.', wert: 3 },
  { id: 'sportshirt', name: 'Funktionsshirt', kind: 'ausruestung', slot: 'brust', bonuses: { maxAusdauer: 2 }, flavor: 'Atmungsaktiv. Immerhin einer von euch.', wert: 3 },
  { id: 'hausschuhe', name: 'Plüsch-Hausschuhe', kind: 'ausruestung', slot: 'fuesse', bonuses: { ausweichen: 1 }, flavor: 'Hasenohren. Leise.', wert: 1 },

  // ---- Verbrauchsgüter
  { id: 'heiltrank', name: 'Heiltrank', kind: 'verbrauch', effekt: { healPct: 50, blase: 5 }, flavor: 'Heilt die Hälfte deiner HP. Hilft nicht gegen Gift. Schmeckt nach Kirsche und Verzweiflung.', wert: 10 },
  { id: 'manatrank', name: 'Manatrank', kind: 'verbrauch', effekt: { manaPct: 100, blase: 5 }, flavor: 'Blau, sprudelnd, riecht nach Gewitter. Füllt dein Mana komplett.', wert: 15 },
  { id: 'kleiner_manatrank', name: 'Kleiner Manatrank', kind: 'verbrauch', effekt: { mana: 4, blase: 3 }, flavor: 'Ein Schluck Konzentration.', wert: 6, ground: 1 },
  { id: 'manatoast', name: 'Manatoast', kind: 'verbrauch', effekt: { mana: 3, heal: 2 }, flavor: 'Toast mit leuchtender Butter. Warum leuchtet die Butter?', wert: 3, ground: 1 },
  { id: 'kleiner_heiltrank', name: 'Kleiner Heiltrank', kind: 'verbrauch', effekt: { healPct: 25, blase: 3 }, flavor: 'Heilt ein Viertel deiner HP. Ein Schluck Hoffnung.', wert: 5, ground: 3 },
  { id: 'energydrink', name: 'Energydrink', kind: 'verbrauch', effekt: { ausdauer: 10, blase: 15, buff: { name: 'Koffeinschock', turns: 30, bonuses: { treffer: 5 } } }, flavor: 'Herzrasen ist ein Feature.', wert: 5, ground: 2 },
  { id: 'schokoriegel', name: 'Schokoriegel', kind: 'verbrauch', effekt: { heal: 4, ausdauer: 4 }, flavor: 'Du bist nicht du, wenn du hungrig bist.', wert: 2, ground: 3 },
  { id: 'leckerli', name: 'Verzaubertes Haustier-Leckerli', kind: 'verbrauch', effekt: {}, flavor: 'Lässt dein Haustier eine Stufe aufsteigen. Ohne Haustier: schmeckt nach Fisch und Reue.', wert: 20 },
  { id: 'dosenbrot', name: 'Dosenbrot', kind: 'verbrauch', effekt: { heal: 6 }, flavor: 'Brot. Aus der Dose. Warum?', wert: 2, ground: 2 },

  // ---- Pässe (Tätowierungen) und Talismane: eine Gegnerart greift dich nicht an, solange du sie nicht angreifst
  { id: 'tattoo_kobold', name: 'Kobold-Pass (Tätowierung)', kind: 'verbrauch', effekt: {}, flavor: 'Ein Tattoo auf dem Unterarm: ein grinsender Kobold. Kobolde halten dich für einen von ihnen – bis du zuschlägst.', wert: 60 },
  { id: 'tattoo_ratte', name: 'Rattenkönig-Siegel (Tätowierung)', kind: 'verbrauch', effekt: {}, flavor: 'Sieben verknotete Schwänze auf deinem Handrücken. Ratten weichen dir aus.', wert: 50 },
  { id: 'talisman_flug', name: 'Talisman der Flatterer', kind: 'ausruestung', slot: 'hals', passFacet: 'z:fliegend', flavor: 'Eine Feder an einem Lederband. Fliegende Wesen lassen dich in Ruhe, solange du sie in Ruhe lässt.', wert: 70 },
  { id: 'talisman_untot', name: 'Grabstein-Anhänger', kind: 'ausruestung', slot: 'hals', passFacet: 'z:untot', flavor: 'Ein winziger Grabstein mit deinem Namen. Untote halten dich für einen Kollegen.', wert: 90 },
  { id: 'talisman_insekt', name: 'Bernstein-Talisman', kind: 'ausruestung', slot: 'hals', passFacet: 'z:insekt', flavor: 'Eine Spinne in Bernstein. Krabbeltiere respektieren das.', wert: 60 },
  // ---- Haustiere
  { id: 'ei_raptor', name: 'Warmes, gesprenkeltes Ei', kind: 'verbrauch', effekt: {}, flavor: 'Es ist warm. Es bewegt sich. Trag es eine Weile mit dir herum.', wert: 120 },
  { id: 'ei_drache', name: 'Schuppiges Ei', kind: 'verbrauch', effekt: {}, flavor: 'Es riecht nach Rauch. Manchmal hörst du ein Fauchen von drinnen.', wert: 200 },
  { id: 'superkeks', name: 'Verzauberter Superkeks', kind: 'verbrauch', effekt: {}, flavor: 'Ein Haustierkeks, der leise summt. Wer ihn frisst, ist danach nicht mehr dasselbe Tier.', wert: 300 },
  // ---- Glücksspiel
  { id: 'rubbellos', name: 'Rubbellos „Goldrausch im Keller“', kind: 'verbrauch', effekt: {}, flavor: 'Drei Felder zum Freirubbeln. Die Gewinnchancen stehen klein gedruckt auf der Rückseite. Sehr klein.', wert: 5, ground: 1 },
  // ---- Boss-Beute (Etage 1)
  { id: 'handtasche_der_sammlerin', name: 'Handtasche der Sammlerin', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 7, bonuses: { stats: { cha: 1 } }, flavor: 'Enthält: drei Lippenstifte, 40 Kassenbons und das Gewicht eines Backsteins.', wert: 25 },
  { id: 'wischmopp', name: 'Wischmopp des Hausmeisters', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 8, bonuses: { ausweichen: 3 }, flavor: 'Nass. Immer nass. Egal was man tut.', wert: 25 },
  { id: 'kronkorkenkrone', name: 'Kronkorkenkrone', kind: 'ausruestung', slot: 'kopf', bonuses: { ruestung: 2, stats: { cha: 2 } }, flavor: 'Die sieben Ratten haben sie selbst gebastelt.', wert: 25 },
  { id: 'ruehrbesen', name: 'Rührbesen-Schlagring', kind: 'ausruestung', slot: 'haende', bonuses: { schaden: { faust: 30 } }, flavor: 'Du schlägst jetzt Sahne. Und Gesichter.', wert: 25 },

  // ================= Erweiterung: Wurfobjekte
  { id: 'dartpfeil', name: 'Dartpfeil', kind: 'wurf', wurfSchaden: 3, flavor: 'Aus der Kellerbar. Trifft selten die Scheibe, dafür oft Gesichter.', wert: 1, ground: 3 },
  { id: 'blumentopf', name: 'Blumentopf', kind: 'wurf', wurfSchaden: 5, flavor: 'Die Geranie darin ist schon lange tot. Bald nicht mehr allein.', wert: 1, ground: 2 },
  { id: 'porzellanpuppe', name: 'Porzellanpuppe', kind: 'wurf', wurfSchaden: 4, flavor: 'Ihre Augen folgen dir. Wirf sie weg. Schnell.', wert: 2, ground: 2 },
  { id: 'bowlingkugel', name: 'Bowlingkugel', kind: 'wurf', wurfSchaden: 8, flavor: 'Strike!', wert: 4, ground: 1 },
  { id: 'kaffeetasse', name: 'Kaffeetasse „Bester Chef der Welt“', kind: 'wurf', wurfSchaden: 3, flavor: 'Zerbricht beim Aufprall. Wie der Chef.', wert: 1, ground: 3 },
  { id: 'bierkrug', name: 'Maßkrug', kind: 'wurf', wurfSchaden: 5, flavor: 'Ein Liter Glas. Oktoberfest-erprobt.', wert: 3, ground: 1 },
  { id: 'schraubenmutter', name: 'Schraubenmutter', kind: 'wurf', wurfSchaden: 2, flavor: 'Klein, schwer, überall.', wert: 0, ground: 4 },
  { id: 'wurfstern', name: 'Wurfstern aus dem Souvenirshop', kind: 'wurf', wurfSchaden: 6, flavor: 'Made in irgendwo. Erstaunlich scharf.', wert: 6 },

  // ================= Erweiterung: Waffen
  { id: 'baseballschlaeger', name: 'Baseballschläger', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 6, flavor: 'Home Run.', wert: 7, ground: 1 },
  { id: 'schraubenschluessel', name: 'Schraubenschlüssel', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 5, bonuses: { krit: 3 }, flavor: 'Größe 24. Passt auf jeden Schädel.', wert: 5, ground: 2 },
  { id: 'golfschlaeger', name: 'Golfschläger', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 5, bonuses: { treffer: 3 }, flavor: 'Ein Eisen 7. Fore!', wert: 6 },
  { id: 'klobuerste', name: 'Klobürste', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 3, bonuses: { krit: 8, stats: { cha: -1 } }, flavor: 'Benutzt. Die Gegner wissen das.', wert: 1, ground: 2 },
  { id: 'regenschirm', name: 'Regenschirm', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 3, bonuses: { ausweichen: 3 }, flavor: 'Spannt sich im falschen Moment auf.', wert: 2, ground: 2 },
  { id: 'hammer', name: 'Zimmermannshammer', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 5, flavor: 'Für Nägel. Und Köpfe wie Nägel.', wert: 5, ground: 2 },
  { id: 'spaten', name: 'Spaten', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 6, bonuses: { ruestung: 1 }, flavor: 'Gräbt auch Gräber. Praktisch.', wert: 6, ground: 1 },
  { id: 'kettensaege', name: 'Kettensäge (ohne Benzin)', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 4, bonuses: { stats: { cha: 2 } }, flavor: 'Macht nur Brumm-Geräusche, wenn du sie selbst machst.', wert: 5 },
  { id: 'tischtennis', name: 'Tischtennisschläger', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 2, bonuses: { treffer: 8 }, flavor: 'Schnell, präzise, lächerlich.', wert: 2, ground: 1 },
  { id: 'selfiestick', name: 'Selfie-Stick', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 2, bonuses: { stats: { cha: 3 } }, flavor: 'Die Zuschauer lieben den Winkel.', wert: 3, ground: 1 },
  { id: 'fleischklopfer', name: 'Fleischklopfer', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 5, bonuses: { krit: 4 }, flavor: 'Für Schnitzel. Du bist jetzt das Schnitzel-Problem.', wert: 4, ground: 1 },
  { id: 'baguette', name: 'Versteinertes Baguette', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 4, flavor: 'Drei Wochen alt. Härter als Stahl.', wert: 2, ground: 2 },
  { id: 'dachlatte', name: 'Dachlatte', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 5, flavor: 'Mit rostigem Nagel. Natürlich mit rostigem Nagel.', wert: 3, ground: 2 },
  { id: 'eishockeyschlaeger', name: 'Eishockeyschläger', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 6, bonuses: { schaden: { waffe: 5 } }, flavor: 'Kanada hat angerufen. Es will ihn nicht zurück.', wert: 8 },

  // ================= Erweiterung: Kleidung
  { id: 'fahrradhelm', name: 'Fahrradhelm', kind: 'ausruestung', slot: 'kopf', bonuses: { ruestung: 2 }, flavor: 'Sicherheit zuerst. Auch in der Apokalypse.', wert: 4, ground: 1 },
  { id: 'aluhut', name: 'Aluhut', kind: 'ausruestung', slot: 'kopf', bonuses: { ausweichen: 3, stats: { int: -1 } }, flavor: 'Schützt vor Gedankenkontrolle. Und vor Würde.', wert: 1, ground: 1 },
  { id: 'cowboyhut', name: 'Cowboyhut', kind: 'ausruestung', slot: 'kopf', bonuses: { stats: { cha: 2 } }, flavor: 'Yeehaw. Leider ohne Pferd.', wert: 4 },
  { id: 'feuerwehrhelm', name: 'Feuerwehrhelm', kind: 'ausruestung', slot: 'kopf', bonuses: { ruestung: 3 }, flavor: 'Schwer, aber zuverlässig.', wert: 8 },
  { id: 'partyhut', name: 'Partyhut', kind: 'ausruestung', slot: 'kopf', bonuses: { stats: { cha: 1 } }, flavor: 'Aus Uwes Partykeller. Uwe braucht ihn nicht mehr.', wert: 1, ground: 1 },
  { id: 'skibrille', name: 'Skibrille', kind: 'ausruestung', slot: 'gesicht', bonuses: { treffer: 3 }, flavor: 'Verspiegelt. Du siehst aus wie ein Insekt.', wert: 3 },
  { id: 'clownsnase', name: 'Clownsnase', kind: 'ausruestung', slot: 'gesicht', bonuses: { stats: { cha: 2 }, ausweichen: -1 }, flavor: 'Hup.', wert: 1, ground: 1 },
  { id: 'sturmhaube', name: 'Sturmhaube', kind: 'ausruestung', slot: 'gesicht', bonuses: { ausweichen: 2 }, flavor: 'Ob Bankräuber oder Skifahrer – egal.', wert: 3 },
  { id: 'monokel', name: 'Monokel', kind: 'ausruestung', slot: 'gesicht', bonuses: { krit: 3, stats: { int: 1 } }, flavor: 'Sehr distinguiert. Fällt ständig raus.', wert: 5 },
  { id: 'hundehalsband', name: 'Hundehalsband mit Nieten', kind: 'ausruestung', slot: 'hals', bonuses: { ruestung: 1, stats: { cha: -1 } }, flavor: 'Auf der Marke steht „Rex“. Du heißt jetzt Rex.', wert: 2, ground: 1 },
  { id: 'perlenkette', name: 'Perlenkette', kind: 'ausruestung', slot: 'hals', bonuses: { stats: { cha: 2 } }, flavor: 'Echte Perlen. Von echten Muscheln. Die jetzt tot sind.', wert: 6 },
  { id: 'knoblauchkette', name: 'Knoblauchkette', kind: 'ausruestung', slot: 'hals', bonuses: { hpRegen: 1, stats: { cha: -1 } }, flavor: 'Hält Vampire fern. Und alle anderen auch.', wert: 3, ground: 1 },
  { id: 'schluesselband', name: 'Schlüsselband einer Firma', kind: 'ausruestung', slot: 'hals', bonuses: { stats: { int: 1 } }, flavor: '„Hallo, ich bin Jens aus dem Vertrieb.“', wert: 1, ground: 1 },
  { id: 'muelltonnendeckel_schulter', name: 'Schulterpanzer aus Mülltonnendeckeln', kind: 'ausruestung', slot: 'schultern', bonuses: { ruestung: 2, ausweichen: -1 }, flavor: 'Laut. Scheppernd. Wirkungsvoll.', wert: 4 },
  { id: 'epauletten', name: 'Goldene Epauletten', kind: 'ausruestung', slot: 'schultern', bonuses: { stats: { cha: 2 } }, flavor: 'Von einer Kapitänsuniform. Der Kapitän ist mit der Welt untergegangen.', wert: 5 },
  { id: 'hawaiihemd', name: 'Hawaiihemd', kind: 'ausruestung', slot: 'brust', bonuses: { stats: { cha: 2 } }, flavor: 'Urlaubsfeeling im Untergang.', wert: 3, ground: 1 },
  { id: 'kronkorkenhemd', name: 'Kettenhemd aus Kronkorken', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 3, ausweichen: -2 }, flavor: 'Tausend Bierflaschen sind dafür gestorben.', wert: 9 },
  { id: 'regenjacke', name: 'Regenjacke', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 1 }, flavor: 'Wasserdicht. Blutdicht? Wird sich zeigen.', wert: 3, ground: 1 },
  { id: 'hoodie', name: 'Hoodie', kind: 'ausruestung', slot: 'brust', bonuses: { maxHp: 3 }, flavor: 'Kapuze auf, Welt aus.', wert: 3, ground: 1 },
  { id: 'motorradjacke', name: 'Motorradjacke', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 3 }, flavor: 'Mit Protektoren. Ohne Motorrad.', wert: 12 },
  { id: 'kochschuerze', name: 'Kochschürze „Kiss the Cook“', kind: 'ausruestung', slot: 'brust', bonuses: { maxHp: 2, stats: { kon: 1 } }, flavor: 'Niemand wird den Koch küssen.', wert: 2, ground: 1 },
  { id: 'superheldenumhang', name: 'Superhelden-Umhang', kind: 'ausruestung', slot: 'ruecken', bonuses: { stats: { cha: 2 }, ausweichen: 1 }, flavor: 'Keine Umhänge in Rolltreppen. Es gibt keine Rolltreppen mehr. Passt.', wert: 4 },
  { id: 'wanderrucksack', name: 'Wanderrucksack', kind: 'ausruestung', slot: 'ruecken', bonuses: { maxAusdauer: 4 }, flavor: 'Mit Brustgurt. Profis wissen das zu schätzen.', wert: 5 },
  { id: 'gitarrenkoffer', name: 'Gitarrenkoffer', kind: 'ausruestung', slot: 'ruecken', bonuses: { ruestung: 1, stats: { cha: 1 } }, flavor: 'Die Gitarre darin ist verstimmt. Für immer.', wert: 4 },
  { id: 'armstulpen', name: 'Armstulpen', kind: 'ausruestung', slot: 'arme', bonuses: { ausweichen: 1 }, flavor: 'Aerobic-Style, 1985.', wert: 2, ground: 1 },
  { id: 'unterarmschiene', name: 'Unterarmschiene', kind: 'ausruestung', slot: 'arme', bonuses: { ruestung: 1, schaden: { faust: 5 } }, flavor: 'Aus einem Ofenrohr.', wert: 5 },
  { id: 'schweissbaender', name: 'Schweißbänder', kind: 'ausruestung', slot: 'arme', bonuses: { maxAusdauer: 2, treffer: 1 }, flavor: 'Frottee. Mit Tennis-Logo.', wert: 2, ground: 1 },
  { id: 'arbeitshandschuhe', name: 'Arbeitshandschuhe', kind: 'ausruestung', slot: 'haende', bonuses: { ruestung: 1, schaden: { faust: 10 } }, flavor: 'Leder. Steif. Gut.', wert: 4 },
  { id: 'topflappen', name: 'Topflappen', kind: 'ausruestung', slot: 'haende', bonuses: { schaden: { faust: 5 }, stats: { cha: -1 } }, flavor: 'Mit Hühnchen-Motiv.', wert: 1, ground: 1 },
  { id: 'fingerlos', name: 'Fingerlose Handschuhe', kind: 'ausruestung', slot: 'haende', bonuses: { treffer: 3 }, flavor: 'Für Radfahrer, Punks und dich.', wert: 3 },
  { id: 'karateguertel', name: 'Karategürtel (gelb)', kind: 'ausruestung', slot: 'guertel', bonuses: { schaden: { faust: 5, tritt: 5 } }, flavor: 'Gelbgurt. Immerhin nicht weiß.', wert: 4 },
  { id: 'patronengurt', name: 'Patronengurt (leer)', kind: 'ausruestung', slot: 'guertel', bonuses: { schaden: { wurf: 10 } }, flavor: 'Perfekt für Steine.', wert: 4 },
  { id: 'bauchweg', name: 'Bauchweggürtel', kind: 'ausruestung', slot: 'guertel', bonuses: { maxHp: 3 }, flavor: 'Aus dem Teleshopping. Funktioniert überraschend.', wert: 3 },
  { id: 'lederhose', name: 'Lederhose', kind: 'ausruestung', slot: 'beine', bonuses: { ruestung: 2, stats: { cha: 1 } }, flavor: 'Bayrische Rüstung.', wert: 8 },
  { id: 'leggings', name: 'Leggings', kind: 'ausruestung', slot: 'beine', bonuses: { ausweichen: 3 }, flavor: 'Dehnbar. Sehr dehnbar.', wert: 3, ground: 1 },
  { id: 'knieschoner', name: 'Knieschoner', kind: 'ausruestung', slot: 'beine', bonuses: { ruestung: 1, schaden: { knie: 15 } }, flavor: 'Vom Inlineskaten. Jetzt zum Knien. Auf Gegnern.', wert: 4 },
  { id: 'skihose', name: 'Skihose', kind: 'ausruestung', slot: 'beine', bonuses: { ruestung: 2, ausweichen: -1 }, flavor: 'Wattiert und warm.', wert: 5 },
  { id: 'radlerhose', name: 'Radlerhose', kind: 'ausruestung', slot: 'beine', bonuses: { maxAusdauer: 3 }, flavor: 'Mit Sitzpolster.', wert: 3, ground: 1 },
  { id: 'gummistiefel', name: 'Gummistiefel', kind: 'ausruestung', slot: 'fuesse', bonuses: { ruestung: 1 }, flavor: 'Wasserdicht. Für die überfluteten Gänge.', wert: 3, ground: 1 },
  { id: 'ballettschuhe', name: 'Ballettschuhe', kind: 'ausruestung', slot: 'fuesse', bonuses: { ausweichen: 4, schaden: { tritt: 5 } }, flavor: 'Anmutig tödlich.', wert: 5 },
  { id: 'crocs', name: 'Crocs', kind: 'ausruestung', slot: 'fuesse', bonuses: { ausweichen: 1, stats: { cha: -2 } }, flavor: 'Die Galaxis hat entschieden: nein.', wert: 1, ground: 1 },
  { id: 'springerstiefel', name: 'Springerstiefel', kind: 'ausruestung', slot: 'fuesse', bonuses: { schaden: { tritt: 20 } }, flavor: 'Zehn Löcher, Stahlkappe, Attitüde.', wert: 10 },
  { id: 'stoeckelschuhe', name: 'Stöckelschuhe', kind: 'ausruestung', slot: 'fuesse', bonuses: { schaden: { tritt: 25 }, ausweichen: -3 }, flavor: 'Der Absatz ist eine Waffe. Das Laufen ist eine Qual.', wert: 6 },
  { id: 'skischuhe', name: 'Skischuhe', kind: 'ausruestung', slot: 'fuesse', bonuses: { ruestung: 2, schaden: { tritt: 15 }, ausweichen: -4 }, flavor: 'Du läufst wie ein Roboter. Du trittst wie ein Pferd.', wert: 6 },
  { id: 'socken_sandalen', name: 'Socken in Sandalen', kind: 'ausruestung', slot: 'fuesse', bonuses: { ausweichen: 2, stats: { cha: -3 } }, flavor: 'Deutsches Kulturgut, Teil 2.', wert: 1, ground: 1 },
  { id: 'siegelring', name: 'Siegelring', kind: 'ausruestung', slot: 'ring', bonuses: { stats: { str: 1 } }, flavor: 'Mit Familienwappen einer ausgestorbenen Familie.', wert: 6 },
  { id: 'stimmungsring', name: 'Stimmungsring', kind: 'ausruestung', slot: 'ring', bonuses: { stats: { cha: 1 } }, flavor: 'Zeigt immer „schwarz“. Passt.', wert: 2, ground: 1 },
  { id: 'totenkopfring', name: 'Totenkopfring', kind: 'ausruestung', slot: 'ring', bonuses: { krit: 3 }, flavor: 'Von einem Rocker. Der Rocker ist jetzt selbst ein Totenkopf.', wert: 5 },
  { id: 'muschelkette', name: 'Muschel-Fußkettchen', kind: 'ausruestung', slot: 'fussring', bonuses: { ausweichen: 2 }, flavor: 'Strandurlaub-Erinnerung.', wert: 2, ground: 1 },
  { id: 'gloeckchen', name: 'Glöckchen-Fußkettchen', kind: 'ausruestung', slot: 'fussring', bonuses: { stats: { cha: 1 }, ausweichen: -1 }, flavor: 'Klingelt bei jedem Schritt. Schleichen ist vorbei.', wert: 2 },
  { id: 'fussfessel', name: 'Elektronische Fußfessel', kind: 'ausruestung', slot: 'fussring', bonuses: { maxHp: 3, ausweichen: -2 }, flavor: 'Der Bewährungshelfer ist tot. Das Ding piept trotzdem.', wert: 2, ground: 1 },
  { id: 'liebestoeter', name: 'Liebestöter', kind: 'ausruestung', slot: 'unterwaesche', bonuses: { maxHp: 2 }, flavor: 'Lang, warm, unsexy.', wert: 2, ground: 1 },
  { id: 'sport_bh', name: 'Sport-BH', kind: 'ausruestung', slot: 'unterwaesche', bonuses: { maxAusdauer: 2 }, flavor: 'Stützt. Hilft.', wert: 2, ground: 1 },
  { id: 'tanga', name: 'Tanga', kind: 'ausruestung', slot: 'unterwaesche', bonuses: { stats: { cha: 2 }, ausweichen: 1 }, flavor: 'Die Zuschauer: *pfeifen*.', wert: 2 },
  { id: 'thermowaesche', name: 'Thermounterwäsche', kind: 'ausruestung', slot: 'unterwaesche', bonuses: { ruestung: 1, maxHp: 1 }, flavor: 'Kratzt, wärmt, schützt.', wert: 3 },

  // ================= Erweiterung: Verbrauchsgüter
  { id: 'gegengift', name: 'Gegengift', kind: 'verbrauch', effekt: { cure: true, heal: 3 }, flavor: 'Schmeckt nach Kreide. Rettet Leben.', wert: 8, ground: 2 },
  { id: 'pflaster', name: 'Pflaster', kind: 'verbrauch', effekt: { heal: 5 }, flavor: 'Mit Dinos drauf.', wert: 1, ground: 3 },
  { id: 'ausdauertrank', name: 'Ausdauertrank', kind: 'verbrauch', effekt: { ausdauer: 20, blase: 10 }, flavor: 'Grün und sprudelnd. Wie ein Energydrink, nur legal.', wert: 6 },
  { id: 'grosser_heiltrank', name: 'Großer Heiltrank', kind: 'verbrauch', effekt: { healPct: 100, blase: 5 }, flavor: 'Eine ganze Flasche Hoffnung.', wert: 25 },
  { id: 'mettbroetchen', name: 'Mettbrötchen', kind: 'verbrauch', effekt: { heal: 8 }, flavor: 'Mit Zwiebeln. Wie lange lag das hier? Egal.', wert: 2, ground: 1 },
  { id: 'apfel', name: 'Apfel', kind: 'verbrauch', effekt: { heal: 3 }, flavor: 'Ein Apfel am Tag hält das Monster nicht fern.', wert: 1, ground: 3 },
  { id: 'dosenbier', name: 'Warmes Dosenbier', kind: 'verbrauch', effekt: { heal: 3, blase: 20, buff: { name: 'Mut angetrunken', turns: 40, bonuses: { stats: { str: 1 }, treffer: -3 } } }, flavor: 'Warm. Aber Bier.', wert: 1, ground: 2 },
  { id: 'traubenzucker', name: 'Traubenzucker', kind: 'verbrauch', effekt: { ausdauer: 6 }, flavor: 'Für die schnelle Energie.', wert: 1, ground: 2 },
  { id: 'wutpille', name: 'Rote Wutpille', kind: 'verbrauch', effekt: { buff: { name: 'Rasende Wut', turns: 30, bonuses: { schaden: { alle: 25 }, ausweichen: -5 } } }, flavor: 'Nebenwirkungen: Wut.', wert: 15 },

  // ================= Haustier-Halsbänder
  { id: 'halsband_leder', name: 'Lederhalsband', kind: 'schrott', petBonus: { hp: 6 }, flavor: 'Mit Namensschild. Du kannst den Namen eingravieren. Mit einem Nagel.', wert: 4, ground: 1 },
  { id: 'halsband_nieten', name: 'Nietenhalsband', kind: 'schrott', petBonus: { dmg: 1, hp: 3 }, flavor: 'Macht jedes Haustier ein bisschen gefährlicher. Und viel cooler.', wert: 8 },
  { id: 'halsband_glocke', name: 'Halsband mit Goldglöckchen', kind: 'schrott', petBonus: { hp: 10 }, flavor: 'Bimmelt. Die Zuschauer finden es süß, die Monster finden das Haustier sofort.', wert: 10 },
  { id: 'halsband_stachel', name: 'Stachelhalsband des Wachhundes', kind: 'schrott', petBonus: { dmg: 3, hp: 8 }, flavor: 'Wer da reinbeißt, bereut es.', wert: 25 },

  // ================= Reittiere und Fahrzeuge
  { id: 'zuendschluessel_wagen', name: 'Zündschlüssel (Einkaufswagen)', kind: 'verbrauch', flavor: 'Am Schlüsselbund hängt ein Chip für den Einkaufswagen. Benutzen, und er steht bereit.', wert: 30 },
  { id: 'zuendschluessel_traktor', name: 'Zündschlüssel (Aufsitzrasenmäher)', kind: 'verbrauch', flavor: 'Mit Anhänger: „Papas Heiligtum“.', wert: 60 },
  { id: 'zuendschluessel_bobbycar', name: 'Zündschnur (Raketen-Bobbycar)', kind: 'verbrauch', flavor: 'Eine Zündschnur und ein Zettel: „Nicht für Kinder unter 3 Jahren. Oder über 3 Jahren.“', wert: 40 },
  { id: 'pfeife_pony', name: 'Pfeife des Kellerponys', kind: 'verbrauch', flavor: 'Einmal pfeifen, und irgendwo wiehert es.', wert: 35 },
  { id: 'pfeife_schnecke', name: 'Schneckenhorn', kind: 'verbrauch', flavor: 'Ein Horn aus einem Schneckenhaus. Die Antwort kommt. Langsam.', wert: 45 },
  { id: 'pfeife_eber', name: 'Eberhorn', kind: 'verbrauch', flavor: 'Klingt wie ein wütendes Schwein. Genau das kommt dann auch.', wert: 70 },
  { id: 'benzinkanister', name: 'Benzinkanister', kind: 'schrott', flavor: 'Halb voll. Riecht nach Abenteuer und Kopfschmerzen.', wert: 5, ground: 1 },

  // ================= Aufträge
  { id: 'andenken', name: 'Andenken', kind: 'schrott', flavor: 'Jemandem ist das sehr wichtig.', wert: 0 },

  // ================= Handwerk: Materialien
  { id: 'lappen', name: 'Schmutziger Lappen', kind: 'schrott', flavor: 'Riecht nach Frittierfett. Brennt bestimmt gut.', wert: 0, ground: 5 },
  { id: 'naegel', name: 'Handvoll Nägel', kind: 'schrott', flavor: 'Krumm, rostig, spitz. Genau richtig.', wert: 1, ground: 4 },
  { id: 'schwarzpulver', name: 'Tütchen Schwarzpulver', kind: 'schrott', flavor: 'Aus aufgeschnittenen Silvesterböllern gekratzt. Nicht rauchen.', wert: 4, ground: 1 },
  { id: 'fallenteile', name: 'Fallenteile', kind: 'schrott', flavor: 'Federn, Zahnräder, ein Auslöser. Aus einer entschärften Falle geborgen.', wert: 3 },
  { id: 'klebeband', name: 'Rolle Panzertape', kind: 'schrott', flavor: 'Hält alles zusammen. Auch Waffen, die es nicht sollten.', wert: 2, ground: 2 },
  { id: 'hochprozentiges', name: 'Flasche Hochprozentiges', kind: 'verbrauch', effekt: { heal: 2, blase: 15, buff: { name: 'Mut angetrunken', turns: 30, bonuses: { stats: { str: 1, cha: 1 }, treffer: -5 } } }, flavor: 'Selbstgebrannt, laut Etikett „nur für Reinigungszwecke“. Man kann es trinken. Oder anzünden.', wert: 3, ground: 2 },
  { id: 'klappwerkbank', name: 'Klappwerkbank', kind: 'schrott', flavor: 'Zusammengeklappt passt sie in jedes Inventar. Aufgeklappt wird jeder Ort zur Werkstatt.', wert: 20 },

  // ================= Handwerk: Erzeugnisse
  { id: 'brandflasche', name: 'Brandflasche', kind: 'wurf', wurfSchaden: 3, explosion: 7, flavor: 'Eine Flasche, ein Lappen, viel schlechter Schnaps. Zerplatzt in einer Feuerwolke.', wert: 6 },
  { id: 'nagelbombe', name: 'Nagelbombe', kind: 'wurf', wurfSchaden: 2, explosion: 11, flavor: 'Eine Ravioli-Dose voller Nägel und Pulver. Die Systemstimme ist entzückt.', wert: 10 },
  { id: 'verband', name: 'Verband', kind: 'verbrauch', effekt: { heal: 10 }, flavor: 'Aus zwei Lappen gerissen. Nicht steril. Aber besser als nichts.', wert: 2 },
  { id: 'stachelfalle', name: 'Stachelfalle (zum Aufstellen)', kind: 'schrott', trapKind: 'stachelfalle', flavor: 'Wer drauftritt, bereut es. Du trittst natürlich nicht drauf.', wert: 6 },
  { id: 'sprengfalle', name: 'Sprengfalle (zum Aufstellen)', kind: 'schrott', trapKind: 'sprengfalle', flavor: 'Ein Stolperdraht an einem Tütchen Pulver. Abstand halten.', wert: 10 },
  { id: 'schlingfalle', name: 'Schlingfalle (zum Aufstellen)', kind: 'schrott', trapKind: 'schlingfalle', flavor: 'Hält einen Gegner fest, bis du Zeit für ihn hast.', wert: 5 },

  // ================= Boss-Beute (Erweiterung)
  { id: 'mottenfluegel_umhang', name: 'Mottenflügel-Umhang', kind: 'ausruestung', slot: 'ruecken', bonuses: { ausweichen: 6, stats: { cha: 1 } }, flavor: 'Staubt bei jeder Bewegung. Flattert beeindruckend.', wert: 30 },
  { id: 'pfandkrone', name: 'Krone des Pfandflaschen-Barons', kind: 'ausruestung', slot: 'kopf', bonuses: { stats: { cha: 3 }, schaden: { wurf: 20 } }, flavor: '25 Cent Pfand. Pro Zacke.', wert: 30 },
  { id: 'thermostat_amulett', name: 'Thermostat-Amulett', kind: 'ausruestung', slot: 'hals', bonuses: { hpRegen: 2, maxHp: 5 }, flavor: 'Immer auf Stufe 3. Wohlig warm.', wert: 30 },
  { id: 'generalschluessel', name: 'Generalschlüssel am Ring', kind: 'ausruestung', slot: 'ring', bonuses: { stats: { int: 2 }, krit: 5 }, flavor: 'Öffnet jede Tür. Theoretisch.', wert: 60 },
  { id: 'verwalter_stempel', name: 'Stempel des Hausverwalters', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 12, bonuses: { krit: 10 }, flavor: '„ABGELEHNT“. Auf der Stirn deiner Gegner.', wert: 60 },
  { id: 'gullydeckel_schild', name: 'Gullydeckel-Schild', kind: 'ausruestung', slot: 'arme', bonuses: { ruestung: 5, ausweichen: -3 }, flavor: 'Schwer wie Sünde. Hält alles ab.', wert: 80 },
  { id: 'offiziersmuetze', name: 'Offiziersmütze aus Schlamm', kind: 'ausruestung', slot: 'kopf', bonuses: { stats: { cha: 3, str: 2 }, ruestung: 2 }, flavor: 'Getrocknet. Meistens.', wert: 80 },
  { id: 'muschelhorn', name: 'Muschelhorn der Nixe', kind: 'ausruestung', slot: 'hals', bonuses: { maxAusdauer: 5, stats: { cha: 2 } }, flavor: 'Man hört das Meer. Und Schreie.', wert: 80 },
  { id: 'kaiserzepter', name: 'Zepter des Rattenkaisers', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 16, bonuses: { stats: { str: 3 } }, flavor: 'Ein Fahrradlenker mit eingeschmolzenen Kronkorken. Majestätisch.', wert: 150 },
  { id: 'duschvorhang_mantel', name: 'Königsmantel aus Duschvorhängen', kind: 'ausruestung', slot: 'ruecken', bonuses: { ruestung: 3, maxHp: 15 }, flavor: 'Mit Entchenmuster. Königlich.', wert: 150 },
  { id: 'schoepfkelle', name: 'Omas Schöpfkelle', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 10, bonuses: { krit: 10 }, flavor: 'Es gibt noch Nachschlag.', wert: 60 },
  { id: 'omas_schuerze', name: 'Omas Kittelschürze', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 3, maxHp: 10 }, flavor: 'Blümchenmuster. Unzerstörbar.', wert: 60 },
];

/** Essbares (profitiert vom Skill „Kochen“). */
export const FOOD_IDS = new Set(['schokoriegel', 'dosenbrot', 'mettbroetchen', 'apfel', 'dosenbier']);

export interface UniqueItem extends BaseItem {
  rarity: Rarity;
  special?: SpecialEffect;
}

// Handgemachte Unikate, die nur aus hochwertigen Boxen kommen.
export const UNIQUE_ITEMS: UniqueItem[] = [
  {
    id: 'zweite_chance', name: 'Zweite-Chance-Klausel', kind: 'ausruestung', slot: 'hals', rarity: 'legendaer',
    special: 'zweite_chance', bonuses: { maxHp: 5 },
    flavor: 'Ein laminiertes Stück Vertrag an einer Kette. Rettet dich einmal vor dem Tod. Das Kleingedruckte nimmt dir dafür etwas anderes.',
    wert: 500,
  },
  {
    id: 'stampfstiefel', name: 'Stiefel des ungebremsten Stampfens', kind: 'ausruestung', slot: 'fuesse', rarity: 'episch',
    special: 'stampf_beben', bonuses: { schaden: { tritt: 40 }, ruestung: 2 },
    flavor: 'Jeder Stampfer erschüttert auch alle Gegner neben dem Ziel.',
    wert: 150,
  },
  {
    id: 'katzenglocke', name: 'Glöckchen der verrückten Katzenperson', kind: 'ausruestung', slot: 'hals', rarity: 'episch',
    special: 'katzenfreund', bonuses: { stats: { cha: 3 } },
    flavor: 'Dein Haustier teilt 50 % mehr Schaden aus. Katzen im Umkreis finden dich… akzeptabel.',
    wert: 150,
  },
  {
    id: 'glueckspilz', name: 'Fußring des Glückspilzes', kind: 'ausruestung', slot: 'fussring', rarity: 'legendaer',
    special: 'glueckspilz', bonuses: { krit: 10, ausweichen: 5 },
    flavor: 'Ein Pilz. Am Fuß. Er hat Glück, also hast du Glück. So funktioniert das.',
    wert: 400,
  },
  {
    id: 'faust_der_gerechtigkeit', name: 'Handschuhe der mäßigen Gerechtigkeit', kind: 'ausruestung', slot: 'haende', rarity: 'episch',
    bonuses: { schaden: { faust: 50, ellbogen: 20 }, stats: { str: 2 } },
    flavor: 'Gerecht ist relativ. Die Handschuhe sind es nicht.',
    wert: 180,
  },
  {
    id: 'unterhose_des_mutes', name: 'Unterhose des unangebrachten Mutes', kind: 'ausruestung', slot: 'unterwaesche', rarity: 'legendaer',
    bonuses: { maxHp: 15, stats: { kon: 3, cha: 3 }, ruestung: 2 },
    flavor: 'Leopardenmuster. Du fühlst dich unbesiegbar. Du bist es nicht.',
    wert: 450,
  },
  {
    id: 'gasmaske', name: 'Gasmaske des Kammerjägers', kind: 'ausruestung', slot: 'gesicht', rarity: 'episch',
    special: 'giftimmun', bonuses: { ruestung: 1 },
    flavor: 'Macht dich immun gegen Gift. Und gegen Gerüche. Hier unten ein Segen.',
    wert: 150,
  },
  {
    id: 'bauchtasche', name: 'Bauchtasche des Schwarzmarkts', kind: 'ausruestung', slot: 'guertel', rarity: 'episch',
    special: 'goldmagnet', bonuses: { stats: { cha: 1 } },
    flavor: '+50 % Gold bei jedem Fund. Der Oger hat sie nicht ganz legal erworben.',
    wert: 200,
  },
  {
    id: 'blutegelring', name: 'Blutegel-Ring', kind: 'ausruestung', slot: 'ring', rarity: 'episch',
    special: 'vampir', bonuses: { stats: { kon: 1 } },
    flavor: 'Ein lebender Blutegel, zum Ring gebogen. 15 % deines Nahkampfschadens heilen dich.',
    wert: 220,
  },
  {
    id: 'kamikazeweste', name: 'Entschärfte Sprengstoffweste', kind: 'ausruestung', slot: 'brust', rarity: 'selten',
    special: 'explosionsschutz', bonuses: { ruestung: 3 },
    flavor: 'Entschärft. Sagt der Verkäufer. Halbiert Explosionsschaden.',
    wert: 80,
  },
  {
    id: 'knoblauchhalskette', name: 'Halskette des Misstrauens', kind: 'ausruestung', slot: 'hals', rarity: 'selten',
    special: 'giftimmun', bonuses: { maxHp: 3 },
    flavor: 'Aus getrockneten Gegengift-Kapseln. Du bist gegen Gift immun.',
    wert: 90,
  },
  {
    id: 'bumerang', name: 'Echter australischer Bumerang', kind: 'wurf', rarity: 'episch',
    special: 'bumerang', wurfSchaden: 9,
    flavor: 'Kommt immer zurück. Anders als deine Ex.',
    wert: 160,
  },
  {
    id: 'goldzahn', name: 'Goldzahn des Gierigen', kind: 'ausruestung', slot: 'gesicht', rarity: 'selten',
    special: 'goldmagnet', bonuses: { stats: { cha: -1 } },
    flavor: 'Du trägst jemandes Goldzahn im Gesicht. +50 % Gold. Moral: optional.',
    wert: 100,
  },
  {
    id: 'stirnband', name: 'Stirnband des ewigen Workouts', kind: 'ausruestung', slot: 'kopf', rarity: 'episch',
    bonuses: { maxAusdauer: 8, stats: { kon: 2 }, hpRegen: 1 },
    flavor: 'Frottee, neon, motivierend. Man hört leise 80er-Aerobic-Musik.',
    wert: 170,
  },
  {
    id: 'fussring_horde', name: 'Fußring der stampfenden Horde', kind: 'ausruestung', slot: 'fussring', rarity: 'legendaer',
    bonuses: { schaden: { tritt: 60 }, stats: { str: 2 } },
    flavor: 'Tausend Füße haben ihn getragen. Nun trägt er dich.',
    wert: 450,
  },
  {
    id: 'ellbogenschoner', name: 'Ellbogenschoner des Drängelns', kind: 'ausruestung', slot: 'arme', rarity: 'episch',
    bonuses: { schaden: { ellbogen: 60 }, ruestung: 1 },
    flavor: 'Von der Schlange an der Supermarktkasse inspiriert.',
    wert: 160,
  },
  {
    id: 'knieschoner_demut', name: 'Knieschoner der Demut', kind: 'ausruestung', slot: 'beine', rarity: 'episch',
    bonuses: { schaden: { knie: 60 }, ruestung: 2 },
    flavor: 'Du kniest vor niemandem. Du kniest in jemanden.',
    wert: 160,
  },
  {
    id: 'widderhelm', name: 'Stahlkopfhelm des Widders', kind: 'ausruestung', slot: 'kopf', rarity: 'legendaer',
    bonuses: { schaden: { kopf: 80 }, ruestung: 3 },
    flavor: 'Mit Hörnern. Kopfstöße tun jetzt vor allem den anderen weh.',
    wert: 420,
  },
  {
    id: 'schleuderhandschuh', name: 'Schleuderhandschuh', kind: 'ausruestung', slot: 'haende', rarity: 'episch',
    bonuses: { schaden: { wurf: 50 }, treffer: 5 },
    flavor: 'Mit eingebauter Gummischlaufe. Steine fliegen jetzt wie Geschosse.',
    wert: 180,
  },
  {
    id: 'kittel', name: 'Kittel des verrückten Wissenschaftlers', kind: 'ausruestung', slot: 'brust', rarity: 'legendaer',
    bonuses: { stats: { int: 4 }, xpBonus: 15, ruestung: 2 },
    flavor: 'Brandlöcher, Säureflecken, ein Kugelschreiber, der leise tickt.',
    wert: 400,
  },
  {
    id: 'boxershorts_weltuntergang', name: 'Boxershorts des Weltuntergangs', kind: 'ausruestung', slot: 'unterwaesche', rarity: 'himmlisch',
    bonuses: { maxHp: 30, stats: { str: 4, kon: 4, cha: 6 }, ruestung: 4, ausweichen: 5 },
    flavor: 'Mit kleinen explodierenden Planeten drauf. Die Galaxis hat für diese Shorts abgestimmt.',
    wert: 3500,
  },
  {
    id: 'himmelsziegel', name: 'Der Ziegel', kind: 'wurf', rarity: 'himmlisch',
    special: 'bumerang', wurfSchaden: 40,
    flavor: 'Es ist ein Ziegel. Aber es ist DER Ziegel. Er kommt immer zurück.',
    wert: 2000,
  },
  {
    id: 'krone_des_crawlers', name: 'Blechkrone des Publikumslieblings', kind: 'ausruestung', slot: 'kopf', rarity: 'himmlisch',
    bonuses: { stats: { str: 3, ges: 3, kon: 3, int: 3, cha: 5 }, xpBonus: 25, ruestung: 3 },
    flavor: 'Die Galaxis schaut zu. Und sie mag dich. Vorerst.',
    wert: 3000,
  },
];

export interface Affix {
  id: string;
  prefix: string;
  bonuses: (power: number) => Bonuses;
  /** Nur für bestimmte Slots. */
  slots?: Slot[];
}

// Verzauberungen: power steigt mit der Seltenheit.
export const AFFIXES: Affix[] = [
  { id: 'staerke', prefix: 'des Bären', bonuses: (p) => ({ stats: { str: p } }) },
  { id: 'geschick', prefix: 'des Wiesels', bonuses: (p) => ({ stats: { ges: p } }) },
  { id: 'konst', prefix: 'des Ochsen', bonuses: (p) => ({ stats: { kon: p } }) },
  { id: 'int', prefix: 'der Eule', bonuses: (p) => ({ stats: { int: p } }) },
  { id: 'cha', prefix: 'des Showmasters', bonuses: (p) => ({ stats: { cha: p } }) },
  { id: 'leben', prefix: 'der Zähigkeit', bonuses: (p) => ({ maxHp: p * 4 }) },
  { id: 'ruestung', prefix: 'der Panzerung', bonuses: (p) => ({ ruestung: Math.ceil(p / 2) }) },
  { id: 'ausweichen', prefix: 'des Aals', bonuses: (p) => ({ ausweichen: p * 2 }) },
  { id: 'krit', prefix: 'der Gemeinheit', bonuses: (p) => ({ krit: p * 2 }) },
  { id: 'regen', prefix: 'der Heilung', bonuses: (p) => ({ hpRegen: Math.ceil(p / 2) }) },
  { id: 'xp', prefix: 'des Streberns', bonuses: (p) => ({ xpBonus: p * 3 }) },
  { id: 'dornen', prefix: 'des Kaktus', bonuses: (p) => ({ dornen: p }) },
  { id: 'tritt', prefix: 'des Esels', bonuses: (p) => ({ schaden: { tritt: p * 8 } }), slots: ['fuesse', 'fussring', 'beine'] },
  { id: 'faust', prefix: 'des Boxers', bonuses: (p) => ({ schaden: { faust: p * 8 } }), slots: ['haende', 'arme', 'ring'] },
  { id: 'kopf', prefix: 'des Widders', bonuses: (p) => ({ schaden: { kopf: p * 10 } }), slots: ['kopf', 'gesicht'] },
  { id: 'wurf', prefix: 'des Werfers', bonuses: (p) => ({ schaden: { wurf: p * 8 } }), slots: ['arme', 'haende', 'schultern', 'ring'] },
  { id: 'waffe', prefix: 'des Schlägers', bonuses: (p) => ({ schaden: { waffe: p * 8 } }), slots: ['waffe', 'haende', 'guertel'] },
  { id: 'knie', prefix: 'des Knies', bonuses: (p) => ({ schaden: { knie: p * 10 } }), slots: ['beine', 'fussring'] },
  { id: 'ellbogen', prefix: 'des Drängelns', bonuses: (p) => ({ schaden: { ellbogen: p * 10 } }), slots: ['arme', 'schultern'] },
  { id: 'elefant', prefix: 'des Elefanten', bonuses: (p) => ({ maxHp: p * 2, ruestung: Math.ceil(p / 3) }) },
  { id: 'katze', prefix: 'der Katze', bonuses: (p) => ({ ausweichen: p, krit: p }) },
  { id: 'faultier', prefix: 'des Faultiers', bonuses: (p) => ({ maxAusdauer: p * 2 }) },
  { id: 'gluecksritter', prefix: 'des Glücksritters', bonuses: (p) => ({ xpBonus: p * 2, krit: p }) },
  { id: 'licht', prefix: 'der Fackel', bonuses: () => ({ lichtradius: 1 }), slots: ['kopf', 'gesicht', 'hals'] },
];

export const RARITY_AFFIXES: Record<Rarity, { count: [number, number]; power: [number, number] }> = {
  gewoehnlich: { count: [0, 0], power: [0, 0] },
  ungewoehnlich: { count: [1, 1], power: [1, 2] },
  selten: { count: [1, 2], power: [2, 3] },
  episch: { count: [2, 3], power: [3, 5] },
  legendaer: { count: [3, 4], power: [5, 7] },
  himmlisch: { count: [4, 5], power: [7, 10] },
};

// Satirische Kommentare der Systemstimme für generierte Items.
export const ITEM_QUIPS = [
  'Die Systemstimme hält das für eine Verbesserung. Die Systemstimme hat dich gesehen.',
  'Handwäsche empfohlen. Blut geht bei 60 Grad raus.',
  'Früherer Besitzer: tot. Kein Zusammenhang. Wahrscheinlich.',
  'Riecht leicht nach Keller.',
  'Wurde von einem Kobold abgeleckt. Nur einmal.',
  'Die Zuschauer finden, es steht dir.',
  'Hergestellt in einer Welt, die es nicht mehr gibt.',
  'Garantie erloschen. Mit dem Planeten.',
  'Ein Sammlerstück. Sammler gibt es aber keine mehr.',
  'Achtung: kann Spuren von Magie enthalten.',
];
