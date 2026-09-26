import type { Bonuses, ConsumableEffect, ItemKind, Rarity, Slot, SpecialEffect } from '../engine/types';

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
  /** Erlaubt das Auftauchen als Bodenfund. */
  ground?: number;
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
  { id: 'bademantel', name: 'Bademantel', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 0, stats: { cha: 1 } }, flavor: 'Flauschig. Offen. Leider.', wert: 1 },
  { id: 'schlafanzug', name: 'Dino-Schlafanzug', kind: 'ausruestung', slot: 'brust', bonuses: { maxHp: 1 }, flavor: 'Mit Kapuze. Die Kapuze hat Zähne.', wert: 1 },
  { id: 'anzug', name: 'Zerknitterter Anzug', kind: 'ausruestung', slot: 'brust', bonuses: { stats: { cha: 2 } }, flavor: 'Du warst auf dem Weg zu einem Meeting. Das Meeting wurde abgesagt. Die Erde auch.', wert: 3 },
  { id: 'arbeitsjacke', name: 'Arbeitsjacke', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 1 }, flavor: 'Mit Firmenlogo einer Firma, die es nicht mehr gibt.', wert: 3 },
  { id: 'sportshirt', name: 'Funktionsshirt', kind: 'ausruestung', slot: 'brust', bonuses: { maxAusdauer: 2 }, flavor: 'Atmungsaktiv. Immerhin einer von euch.', wert: 3 },
  { id: 'hausschuhe', name: 'Plüsch-Hausschuhe', kind: 'ausruestung', slot: 'fuesse', bonuses: { ausweichen: 1 }, flavor: 'Hasenohren. Leise.', wert: 1 },

  // ---- Verbrauchsgüter
  { id: 'heiltrank', name: 'Heiltrank', kind: 'verbrauch', effekt: { heal: 20 }, flavor: 'Schmeckt nach Kirsche und Verzweiflung.', wert: 10 },
  { id: 'kleiner_heiltrank', name: 'Kleiner Heiltrank', kind: 'verbrauch', effekt: { heal: 10 }, flavor: 'Ein Schluck Hoffnung.', wert: 5, ground: 3 },
  { id: 'energydrink', name: 'Energydrink', kind: 'verbrauch', effekt: { ausdauer: 10, buff: { name: 'Koffeinschock', turns: 30, bonuses: { treffer: 5 } } }, flavor: 'Herzrasen ist ein Feature.', wert: 5, ground: 2 },
  { id: 'schokoriegel', name: 'Schokoriegel', kind: 'verbrauch', effekt: { heal: 4, ausdauer: 4 }, flavor: 'Du bist nicht du, wenn du hungrig bist.', wert: 2, ground: 3 },
  { id: 'leckerli', name: 'Verzaubertes Haustier-Leckerli', kind: 'verbrauch', effekt: {}, flavor: 'Lässt dein Haustier eine Stufe aufsteigen. Ohne Haustier: schmeckt nach Fisch und Reue.', wert: 20 },
  { id: 'dosenbrot', name: 'Dosenbrot', kind: 'verbrauch', effekt: { heal: 6 }, flavor: 'Brot. Aus der Dose. Warum?', wert: 2, ground: 2 },

  // ---- Boss-Beute (Etage 1)
  { id: 'handtasche_der_sammlerin', name: 'Handtasche der Sammlerin', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 7, bonuses: { stats: { cha: 1 } }, flavor: 'Enthält: drei Lippenstifte, 40 Kassenbons und das Gewicht eines Backsteins.', wert: 25 },
  { id: 'wischmopp', name: 'Wischmopp des Hausmeisters', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 8, bonuses: { ausweichen: 3 }, flavor: 'Nass. Immer nass. Egal was man tut.', wert: 25 },
  { id: 'kronkorkenkrone', name: 'Kronkorkenkrone', kind: 'ausruestung', slot: 'kopf', bonuses: { ruestung: 2, stats: { cha: 2 } }, flavor: 'Die sieben Ratten haben sie selbst gebastelt.', wert: 25 },
  { id: 'ruehrbesen', name: 'Rührbesen-Schlagring', kind: 'ausruestung', slot: 'haende', bonuses: { schaden: { faust: 30 } }, flavor: 'Du schlägst jetzt Sahne. Und Gesichter.', wert: 25 },
  { id: 'schoepfkelle', name: 'Omas Schöpfkelle', kind: 'ausruestung', slot: 'waffe', waffenSchaden: 10, bonuses: { krit: 10 }, flavor: 'Es gibt noch Nachschlag.', wert: 60 },
  { id: 'omas_schuerze', name: 'Omas Kittelschürze', kind: 'ausruestung', slot: 'brust', bonuses: { ruestung: 3, maxHp: 10 }, flavor: 'Blümchenmuster. Unzerstörbar.', wert: 60 },
];

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
    id: 'himmelsziegel', name: 'Der Ziegel', kind: 'wurf', rarity: 'himmlisch',
    wurfSchaden: 40,
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
