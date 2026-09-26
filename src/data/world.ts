import type { BoxTier, BoxType, ConsumableEffect, Rarity } from '../engine/types';

// ------------------------------------------------------------------ Show

export const SHOW_NAME = 'Der Große Abstieg';
export const SYSTEM_NAME = 'Die Systemstimme';

export const HOOD_NAMES = ['Nordwestviertel', 'Nordostviertel', 'Südostviertel', 'Südwestviertel'];

// ------------------------------------------------------------------ Etagen

export interface FloorDef {
  floor: number;
  name: string;
  intro: string;
  /** Dauer bis zum Einsturz in Zügen (1 Zug = 3 Minuten). */
  duration: number;
  mobLevel: [number, number];
  levelBonus: number;
}

export const MINUTES_PER_TURN = 3;

export const FLOORS: FloorDef[] = [
  {
    floor: 1, name: 'Die Kellergewölbe',
    intro: 'Unter den Trümmern deiner Stadt hat der Dungeon die Keller aller Häuser zu einem einzigen, endlosen Labyrinth verbunden. Es riecht nach Moder, Heizöl und etwas Totem. Irgendwo tropft es. Irgendwo knurrt es.',
    duration: 2400, mobLevel: [1, 5], levelBonus: 0,
  },
  {
    floor: 2, name: 'Die tieferen Keller',
    intro: 'Die zweite Etage sieht aus wie die erste – nur dunkler, feuchter und mit mehr Zähnen. Die Systemstimme verspricht „spannende neue Features“. Das klingt nicht gut.',
    duration: 2400, mobLevel: [3, 7], levelBonus: 2,
  },
];

export const LAST_PLAYABLE_FLOOR = 2;

// ------------------------------------------------------------------ Räume

export interface RoomFlavor {
  name: string;
  description: string;
}

export const ROOM_FLAVORS: RoomFlavor[] = [
  { name: 'Heizungskeller', description: 'Ein verrosteter Öltank gluckert vor sich hin. Die Rohre an der Decke sind warm und schwitzen.' },
  { name: 'Waschküche', description: 'Drei Waschmaschinen stehen offen, in einer dreht sich noch etwas. Es ist hoffentlich Wäsche.' },
  { name: 'Weinkeller', description: 'Zerbrochene Flaschen, der Boden klebt. Es riecht nach Rotwein und schlechten Entscheidungen.' },
  { name: 'Abstellkammer', description: 'Kartons mit der Aufschrift „Weihnachten“, „Oma“ und „NICHT ÖFFNEN“. Einer davon bewegt sich.' },
  { name: 'Fahrradkeller', description: 'Verbogene Fahrräder hängen wie Skelette an Wandhaken. Ein Kinderrad hat noch eine Klingel.' },
  { name: 'Partykeller', description: 'Eine Discokugel dreht sich, obwohl es keinen Strom gibt. An der Wand: „Happy 50, Uwe!“' },
  { name: 'Hobbyraum', description: 'Eine halbfertige Modelleisenbahn. Die kleinen Figuren wurden alle geköpft.' },
  { name: 'Vorratskeller', description: 'Regale mit Einmachgläsern. Das meiste ist verdorben. Etwas im Gurkenglas blinzelt.' },
  { name: 'Tiefgaragen-Ausläufer', description: 'Betonpfeiler, Ölflecken, ein ausgebranntes Auto. Die Parkuhr zeigt „ABGELAUFEN“. Passt.' },
  { name: 'Luftschutzbunker', description: 'Dicke Stahltür, alte Feldbetten, ein Schild: „Ruhe bewahren“. Ha.' },
  { name: 'Kohlenkeller', description: 'Schwarzer Staub auf allem. Deine Füße hinterlassen Abdrücke, die sehr gut zu verfolgen sind.' },
  { name: 'Werkstatt', description: 'Eine Werkbank voller Werkzeug, das jemand fest verschraubt hat. Wie gemein.' },
  { name: 'Archivraum', description: 'Aktenordner bis zur Decke. „Nebenkostenabrechnung 1987–2019“. Die Hölle hat eine Registratur.' },
  { name: 'Hausmeisterkammer', description: 'Eimer, Besen, ein Kalender mit Katzenbildern von vor fünf Jahren.' },
  { name: 'Sauna', description: 'Holzbänke, ein kalter Ofen, ein Handtuch mit der Aufschrift „Gast“. Die Temperatur ist merkwürdig angenehm.' },
  { name: 'Kellerbar', description: 'Ein Tresen aus Europaletten, eine Dartscheibe mit einem Messer darin. Nicht mit einem Pfeil. Mit einem Messer.' },
  { name: 'Hobbyschmiede', description: 'Ein Amboss steht mitten im Raum. Wer hat im Keller einen Amboss? Und warum?' },
  { name: 'Kinderzimmer im Keller', description: 'Ein Hochbett, Poster von Bands, die es nicht mehr gibt. Eine Spieluhr spielt von selbst.' },
  { name: 'Überfluteter Gang', description: 'Knöcheltiefes, schwarzes Wasser. Etwas schwimmt vorbei. Du entscheidest dich, nicht hinzusehen.' },
  { name: 'Gemeinschaftskeller', description: 'Nummerierte Holzverschläge, hinter jedem das Leben einer Familie in Kisten.' },
];

export const START_ROOM: RoomFlavor = {
  name: 'Dein eigener Keller',
  description: 'Hier bist du hinuntergerannt, als der Himmel aufriss. Die Treppe nach oben ist verschwunden – an ihrer Stelle nur Beton. Es gibt nur einen Weg: weiter.',
};

export const GUILD_ROOM: RoomFlavor = {
  name: 'Gilde der Einweisung',
  description: 'Ein holzvertäfelter Saal voller Pokale, ausgestopfter Monsterköpfe und eines Kamins, der kein Holz braucht. Hinter einem Tresen wartet jemand auf dich.',
};

export const SAFE_ROOM_FREEBIE: RoomFlavor = {
  name: 'Safe Room – Die Gratis-Kammer',
  description: 'Ein schimmerndes Feld an der Tür. Drinnen: ein bequemes Sofa, ein Waschbecken und ein Podest mit einem glänzenden Automaten. „EIN GRATIS-GEGENSTAND PRO CRAWLER!“ steht darauf.',
};

export const SAFE_ROOM_RESTAURANT: RoomFlavor = {
  name: 'Safe Room – Restaurant',
  description: 'Ein schimmerndes Feld an der Tür. Drinnen: warme Luft, Holztische und der Geruch von Bratkartoffeln. Hinter der Theke steht ein NPC und poliert ein Glas.',
};

export const RESTAURANT_HOSTS = [
  { name: 'Brunhilde', race: 'Halbtroll', greeting: '„Setz dich hin, du siehst aus wie ausgekotzt. Was darf’s sein?“' },
  { name: 'Gustav', race: 'Gnom', greeting: '„Willkommen, willkommen! Heute im Angebot: alles, was noch nicht weggelaufen ist!“' },
  { name: 'Zorla', race: 'Echsenfrau', greeting: '„Frischfleisch! Ah, nein, ich meine: ein Gast. Ein Gast! Hunger?“' },
  { name: 'Herr Pütz', race: 'Mensch (?)', greeting: '„Wir nehmen nur Bargeld. Und Seelen. Scherz! Nur Bargeld.“' },
];

export interface MenuItem {
  id: string;
  name: string;
  price: number;
  effekt: ConsumableEffect;
  flavor: string;
}

export const RESTAURANT_MENU: MenuItem[] = [
  { id: 'menue_suppe', name: 'Tagessuppe', price: 3, effekt: { heal: 12 }, flavor: 'Undefinierbar, aber heiß.' },
  { id: 'menue_schnitzel', name: 'Schnitzel mit Pommes', price: 8, effekt: { heal: 25, buff: { name: 'Satt & zufrieden', turns: 120, bonuses: { maxHp: 5, stats: { str: 1 } } } }, flavor: 'Paniert. Das Tier dahinter: unbekannt.' },
  { id: 'menue_kaffee', name: 'Starker Kaffee', price: 2, effekt: { ausdauer: 15, buff: { name: 'Wach', turns: 80, bonuses: { treffer: 5 } } }, flavor: 'Schwarz wie deine Zukunft.' },
  { id: 'menue_salat', name: 'Kellerpilz-Salat', price: 5, effekt: { heal: 10, buff: { name: 'Pilzkraft', turns: 120, bonuses: { ausweichen: 5, stats: { ges: 1 } } } }, flavor: 'Die Pilze leuchten leicht. Das ist normal. Sagt der Koch.' },
  { id: 'menue_gulasch', name: 'Monster-Gulasch', price: 10, effekt: { heal: 30, buff: { name: 'Monsterkraft', turns: 150, bonuses: { schaden: { alle: 15 } } } }, flavor: 'Aus Zutaten, die du heute selbst erschlagen hast. Vielleicht.' },
];

// ------------------------------------------------------------------ Boxen

export const BOX_TIER_NAMES: Record<BoxTier, string> = {
  bronze: 'Bronze', silber: 'Silber', gold: 'Gold', platin: 'Platin', legendaer: 'Legendäre', himmlisch: 'Himmlische',
};

export const BOX_TIER_COLORS: Record<BoxTier, string> = {
  bronze: '#cd7f32', silber: '#c0c0c0', gold: '#ffd700', platin: '#9fe8ff', legendaer: '#ff9d2e', himmlisch: '#e0b0ff',
};

export const BOX_TIERS: BoxTier[] = ['bronze', 'silber', 'gold', 'platin', 'legendaer', 'himmlisch'];

export const BOX_TYPE_NAMES: Record<BoxType, string> = {
  abenteurer: 'Abenteurer-Box', waffen: 'Waffen-Box', schuh: 'Schuh-Box', kleidung: 'Kleidungs-Box',
  schmuck: 'Schmuck-Box', haustier: 'Haustier-Box', boss: 'Boss-Box', brawler: 'Schläger-Box',
  wurf: 'Wurf-Box', ueberlebens: 'Überlebens-Box', fan: 'Fan-Box',
};

/** Wie viele Items und welche Seltenheiten eine Box je Stufe liefert. */
export const BOX_CONTENTS: Record<BoxTier, { items: [number, number]; rarities: [Rarity, number][]; gold: [number, number]; uniqueChance: number }> = {
  bronze: { items: [1, 1], rarities: [['gewoehnlich', 60], ['ungewoehnlich', 35], ['selten', 5]], gold: [2, 8], uniqueChance: 0 },
  silber: { items: [1, 2], rarities: [['gewoehnlich', 25], ['ungewoehnlich', 50], ['selten', 22], ['episch', 3]], gold: [5, 15], uniqueChance: 0.01 },
  gold: { items: [2, 2], rarities: [['ungewoehnlich', 35], ['selten', 45], ['episch', 18], ['legendaer', 2]], gold: [15, 40], uniqueChance: 0.04 },
  platin: { items: [2, 3], rarities: [['selten', 45], ['episch', 43], ['legendaer', 12]], gold: [40, 100], uniqueChance: 0.1 },
  legendaer: { items: [3, 3], rarities: [['episch', 55], ['legendaer', 40], ['himmlisch', 5]], gold: [100, 250], uniqueChance: 0.3 },
  himmlisch: { items: [3, 4], rarities: [['legendaer', 60], ['himmlisch', 40]], gold: [300, 800], uniqueChance: 0.6 },
};

// ------------------------------------------------------------------ Guide

export const DEFAULT_GUIDE = {
  name: 'Barnabas',
  description: 'ein hageres Wesen, halb Reiher, halb Buchhalter, mit einer Lesebrille auf dem Schnabel',
};

export function tutorialPages(guideName: string, guideDescription: string, formerCrawler: boolean): string[] {
  const intro = formerCrawler
    ? `Hinter dem Tresen steht ${guideName}. Du kennst das Gesicht – es ist ein früherer Crawler aus einer vergangenen Staffel. Einer von *deinen*. Mit einem unterschriebenen Vertrag dient ${guideName} jetzt der Show. „Hätte nicht gedacht, dass wir uns so wiedersehen“, sagt er. „Ich gebe dir alles mit, was ich weiß.“`
    : `Hinter dem Tresen steht ${guideDescription}. „Ah. Ein Neuer. Ich bin ${guideName}, dein Guide. Ich war mal wie du – ein Crawler. Dann habe ich einen Vertrag unterschrieben. Jetzt sitze ich hier und erkläre Leuten, wie sie nicht sterben. Die meisten hören nicht zu.“`;
  return [
    intro,
    '„Also, die Grundlagen. Du bist in einer Gameshow. Die ganze Galaxis schaut zu. Jede Etage hat einen Timer – wenn er abläuft, stürzt die Etage ein. Bist du dann nicht im Treppenhaus, bist du tot. Punkt.“',
    '„Ab jetzt hast du ein Inventar. Du kannst also mehr tragen als das, was du in der Hand hältst. Glückwunsch. Außerdem siehst du jetzt deine Werte, und deine Karte merkt sich, wo du schon warst.“',
    '„Kämpfen: Die Systemstimme beobachtet, WIE du kämpfst. Tritt viel, und du wirst besser im Treten. Wirf Steine, und du wirst besser im Werfen. Probier Dinge aus. Wer immer dasselbe macht, wird darin gut – aber auch vorhersehbar.“',
    '„Bosse: Jedes Viertel hat einen Nachbarschafts-Boss. Solange er lebt, spawnen dort neue Monster nach. Er verlässt seine Kammer nicht. Wenn du ihn tötest, lässt er eine Gebietskarte fallen – heb sie auf. Und in der Mitte der Etage haust etwas Größeres. Die Treppe liegt direkt hinter ihm.“',
    '„Safe Rooms erkennst du am grünen Schimmern. Dort darf niemand Gewalt anwenden. Monster, die dich dort angreifen, werden weggebeamt. Nur dort kannst du Lootboxen öffnen. Und schlafen. Schlaf ist wichtig. Tot sein ist schlimmer.“',
    '„Achievements bekommst du für… alles Mögliche. Je verrückter oder schwieriger, desto besser die Box. Die Systemstimme hat einen, äh, speziellen Humor. Gewöhn dich dran.“',
    '„Letzte Sache. Wenn du stirbst, ist es vorbei. Keine zweite Runde für dich. Aber… die Show merkt sich alles. Und wer weiß, vielleicht begegnest du dir irgendwann selbst wieder. Viel Glück. Du wirst es brauchen.“',
  ];
}

// ------------------------------------------------------------------ Systemstimme

export const LEVEL_UP_QUIPS = [
  'Du bist jetzt stärker! Relativ gesehen. Absolut gesehen bist du immer noch Futter.',
  'Level up! Die Zuschauer klatschen. Einige davon haben keine Hände, aber sie versuchen es.',
  'Aufgestiegen! Die Systemstimme hat Wetten auf deinen Tod laufen. Sie ist leicht verunsichert.',
  'Neues Level. Neue Möglichkeiten. Neue Arten zu sterben.',
];

export const DEATH_QUIPS = [
  'Und das war es dann. Die Galaxis hat kurz hingesehen, gelacht und umgeschaltet.',
  'Ein weiterer Crawler, der es nicht geschafft hat. Die Systemstimme vermerkt es. Mit einem Smiley.',
  'Du wirst nicht vergessen werden. Zumindest nicht, bis die Werbepause vorbei ist.',
  'Deine Einschaltquote im Moment deines Todes: beachtlich. Glückwunsch, posthum.',
];

export const COLLAPSE_WARNINGS: [number, string][] = [
  [480, 'Noch 24 Stunden bis zum Einsturz der Etage. Kein Grund zur Panik. Noch nicht.'],
  [120, 'Noch 6 Stunden bis zum Einsturz! Die Treppenhäuser freuen sich auf deinen Besuch.'],
  [20, 'NOCH EINE STUNDE! Safe Rooms werden geräumt. Lauf, Crawler, lauf!'],
  [5, 'Die Decke bröckelt. Das ist kein Scherz. Die Systemstimme scherzt nie. Na gut, oft. Aber jetzt nicht.'],
];
