import type { Behavior, MonsterSize } from '../engine/types';

export interface MonsterDef {
  id: string;
  name: string;
  glyph: string;
  color: string;
  /** Level-Spanne, in der der Mob auftritt. */
  levels: [number, number];
  floors: number[];
  hp: number;
  hpPerLevel: number;
  dmg: [number, number];
  dmgPerLevel: number;
  treffer: number;
  ruestung: number;
  ausweichen: number;
  size: MonsterSize;
  behavior: Behavior;
  range?: number;
  xp: number;
  weight: number;
  /** Tritt in Gruppen auf. */
  pack?: [number, number];
  flavor: string;
  tags?: string[];
}

// Etage 1 und 2: Kellerlabyrinth unter der zerstörten Stadt. Eine bunte
// Mischung aus Folklore, Mythologie, Aliens und schlichtem Ungeziefer.
export const MONSTERS: MonsterDef[] = [
  {
    id: 'kellerratte', name: 'Kellerratte', glyph: 'r', color: '#b08a6a',
    levels: [1, 2], floors: [1, 2], hp: 6, hpPerLevel: 3, dmg: [1, 2], dmgPerLevel: 1,
    treffer: 70, ruestung: 0, ausweichen: 10, size: 'winzig', behavior: 'melee', xp: 6, weight: 10, pack: [1, 3],
    flavor: 'Eine Ratte, so groß wie ein Dackel. Die Systemstimme nennt sie „Grundnahrungsmittel mit Zähnen“.',
    tags: ['ratte'],
  },
  {
    id: 'riesenkakerlake', name: 'Riesenkakerlake', glyph: 'k', color: '#8a5a2b',
    levels: [1, 3], floors: [1, 2], hp: 8, hpPerLevel: 3, dmg: [1, 3], dmgPerLevel: 1,
    treffer: 65, ruestung: 1, ausweichen: 15, size: 'klein', behavior: 'melee', xp: 8, weight: 8,
    flavor: 'Überlebte die Dinosaurier, überlebte die Menschheit und wird vermutlich auch dich überleben.',
    tags: ['insekt'],
  },
  {
    id: 'kobold', name: 'Kobold-Plünderer', glyph: 'g', color: '#6fbf4a',
    levels: [1, 4], floors: [1, 2], hp: 10, hpPerLevel: 4, dmg: [2, 4], dmgPerLevel: 1,
    treffer: 70, ruestung: 1, ausweichen: 10, size: 'klein', behavior: 'melee', xp: 12, weight: 8, pack: [1, 2],
    flavor: 'Trägt einen Topf als Helm und eine Gabel als Schwert. Ist trotzdem gefährlicher als du.',
    tags: ['kobold'],
  },
  {
    id: 'kobold_schleuder', name: 'Kobold-Schleuderer', glyph: 'g', color: '#a8d86a',
    levels: [2, 4], floors: [1, 2], hp: 8, hpPerLevel: 3, dmg: [1, 3], dmgPerLevel: 1,
    treffer: 60, ruestung: 0, ausweichen: 15, size: 'klein', behavior: 'ranged', range: 5, xp: 14, weight: 5,
    flavor: 'Wirft mit Kieselsteinen und Beleidigungen. Beides trifft erstaunlich oft.',
    tags: ['kobold'],
  },
  {
    id: 'schleim', name: 'Kellerschleim', glyph: 's', color: '#4ad8b0',
    levels: [1, 3], floors: [1, 2], hp: 14, hpPerLevel: 5, dmg: [1, 2], dmgPerLevel: 1,
    treffer: 60, ruestung: 0, ausweichen: 0, size: 'mittel', behavior: 'melee', xp: 10, weight: 6,
    flavor: 'Eine wabbelnde Masse aus Kellerfeuchtigkeit und Bosheit. Faustschläge bleiben kurz stecken.',
    tags: ['schleim'],
  },
  {
    id: 'wolpertinger', name: 'Wolpertinger', glyph: 'w', color: '#d8b04a',
    levels: [2, 4], floors: [1, 2], hp: 12, hpPerLevel: 4, dmg: [2, 4], dmgPerLevel: 1,
    treffer: 75, ruestung: 0, ausweichen: 25, size: 'klein', behavior: 'melee', xp: 16, weight: 4,
    flavor: 'Hase, Geweih, Entenflügel, Wut. Ein bayerisches Fabelwesen mit Aggressionsproblem.',
    tags: ['folklore'],
  },
  {
    id: 'poltergeist', name: 'Poltergeist', glyph: 'p', color: '#c8c8f0',
    levels: [3, 5], floors: [1, 2], hp: 9, hpPerLevel: 3, dmg: [2, 4], dmgPerLevel: 1,
    treffer: 70, ruestung: 0, ausweichen: 20, size: 'mittel', behavior: 'ranged', range: 4, xp: 18, weight: 3,
    flavor: 'Wirft Geschirr. Wo kommt das ganze Geschirr her? Niemand weiß es.',
    tags: ['geist'],
  },
  {
    id: 'grauer_spaeher', name: 'Grauer Späher', glyph: 'a', color: '#9aa8b8',
    levels: [3, 5], floors: [1, 2], hp: 14, hpPerLevel: 4, dmg: [3, 5], dmgPerLevel: 1,
    treffer: 75, ruestung: 1, ausweichen: 15, size: 'klein', behavior: 'ranged', range: 5, xp: 22, weight: 3,
    flavor: 'Großer Kopf, große Augen, kleiner Strahler. Ein Alien, das eigentlich nur Proben nehmen wollte.',
    tags: ['alien'],
  },
  {
    id: 'muellsack_mimic', name: 'Hungriger Müllsack', glyph: 'm', color: '#5a5a5a',
    levels: [2, 4], floors: [1, 2], hp: 16, hpPerLevel: 5, dmg: [2, 5], dmgPerLevel: 1,
    treffer: 70, ruestung: 2, ausweichen: 0, size: 'mittel', behavior: 'stationary', xp: 18, weight: 3,
    flavor: 'Ein Müllsack mit Zähnen. Er wartet. Er hat Zeit. Er riecht.',
    tags: ['mimic'],
  },
  {
    id: 'tatzelwurm', name: 'Tatzelwurm', glyph: 'T', color: '#c86a3a',
    levels: [3, 5], floors: [1, 2], hp: 20, hpPerLevel: 6, dmg: [3, 6], dmgPerLevel: 1,
    treffer: 70, ruestung: 2, ausweichen: 5, size: 'mittel', behavior: 'melee', xp: 26, weight: 2,
    flavor: 'Alpenländischer Katzenkopf-Lindwurm. Faucht, beißt und ist beleidigt, wenn man ihn für eine Eidechse hält.',
    tags: ['folklore'],
  },
  {
    id: 'ghul', name: 'Kellerghul', glyph: 'G', color: '#8ab870',
    levels: [3, 5], floors: [1, 2], hp: 22, hpPerLevel: 6, dmg: [3, 6], dmgPerLevel: 1,
    treffer: 70, ruestung: 1, ausweichen: 5, size: 'mittel', behavior: 'melee', xp: 28, weight: 2,
    flavor: 'Isst gerne Verstorbene. Ist bereit, bei dir eine Ausnahme zu machen.',
    tags: ['untot'],
  },
  {
    id: 'gnom_buerokrat', name: 'Gnom-Bürokrat', glyph: 'b', color: '#e0e070',
    levels: [1, 3], floors: [1, 2], hp: 7, hpPerLevel: 3, dmg: [1, 2], dmgPerLevel: 1,
    treffer: 60, ruestung: 0, ausweichen: 10, size: 'winzig', behavior: 'coward', xp: 10, weight: 4,
    flavor: 'Verlangt ein Formular in dreifacher Ausfertigung. Flieht, wenn man keins hat.',
    tags: ['gnom'],
  },
  {
    id: 'rattenmensch', name: 'Rattenmensch', glyph: 'R', color: '#a07050',
    levels: [3, 5], floors: [1, 2], hp: 18, hpPerLevel: 5, dmg: [2, 5], dmgPerLevel: 1,
    treffer: 75, ruestung: 1, ausweichen: 15, size: 'mittel', behavior: 'melee', xp: 24, weight: 3,
    flavor: 'Halb Ratte, halb Mensch, ganz schlechte Laune.',
    tags: ['ratte'],
  },
  {
    id: 'toaster_mimic', name: 'Rauchender Toaster', glyph: 't', color: '#d05030',
    levels: [2, 4], floors: [1, 2], hp: 10, hpPerLevel: 3, dmg: [3, 5], dmgPerLevel: 1,
    treffer: 60, ruestung: 3, ausweichen: 0, size: 'winzig', behavior: 'ranged', range: 3, xp: 16, weight: 2,
    flavor: 'Schießt glühende Toastscheiben. Das ist die Zukunft, vor der dich deine Mutter gewarnt hat.',
    tags: ['mimic'],
  },
];

export interface BossDef {
  id: string;
  name: string;
  glyph: string;
  color: string;
  level: number;
  hp: number;
  dmg: [number, number];
  treffer: number;
  ruestung: number;
  ausweichen: number;
  size: MonsterSize;
  range?: number;
  xp: number;
  rank: 'nachbarschaftsboss' | 'boroughboss';
  intro: string;
  flavor: string;
  loot: string[];
}

// Nachbarschafts-Bosse bewachen je ein Viertel. Solange sie leben,
// spawnen dort neue Mobs nach. Sie verlassen ihre Kammer nicht.
export const HOOD_BOSSES: BossDef[] = [
  {
    id: 'die_sammlerin', name: 'Die Sammlerin', glyph: 'S', color: '#e070e0', level: 7,
    hp: 70, dmg: [4, 7], treffer: 75, ruestung: 2, ausweichen: 5, size: 'gross', xp: 120,
    rank: 'nachbarschaftsboss',
    intro: 'Zwischen Türmen aus Zeitungen, Katzenfutterdosen und Porzellanpuppen erhebt sich etwas. Es hat zu viele Arme – und in jedem eine Handtasche.',
    flavor: 'Hat noch nie etwas weggeworfen. Wird auch dich nicht wegwerfen. Sie wird dich *behalten*.',
    loot: ['handtasche_der_sammlerin'],
  },
  {
    id: 'der_hausmeister', name: 'Der Hausmeister', glyph: 'H', color: '#70a0e0', level: 7,
    hp: 80, dmg: [4, 8], treffer: 70, ruestung: 3, ausweichen: 0, size: 'gross', xp: 130,
    rank: 'nachbarschaftsboss',
    intro: 'Ein drei Meter großer Mann im grauen Kittel dreht sich um. Sein Wischmopp tropft. „Hier wird nicht gelaufen!“',
    flavor: 'Seit 40 Jahren im Dienst. Hat jeden einzelnen Tag gehasst.',
    loot: ['wischmopp'],
  },
  {
    id: 'koenig_kanalratte', name: 'König der Kanalratten', glyph: 'K', color: '#c0a060', level: 8,
    hp: 75, dmg: [5, 8], treffer: 75, ruestung: 1, ausweichen: 15, size: 'gross', xp: 140,
    rank: 'nachbarschaftsboss',
    intro: 'Ein Knoten aus sieben Ratten, deren Schwänze verwachsen sind, trägt eine Krone aus Kronkorken. Er quiekt in sieben Stimmen.',
    flavor: 'Ein Rattenkönig im wörtlichsten Sinne. Die sieben Köpfe sind sich selten einig.',
    loot: ['kronkorkenkrone'],
  },
  {
    id: 'muttis_mixer', name: 'Muttis Mega-Mixer', glyph: 'M', color: '#e0e0e0', level: 8,
    hp: 65, dmg: [5, 9], treffer: 70, ruestung: 4, ausweichen: 0, size: 'gross', xp: 140,
    rank: 'nachbarschaftsboss',
    intro: 'Ein Küchengerät von der Größe eines Kleinwagens erwacht brummend. Die Rührbesen drehen sich. Es riecht nach Rührkuchen und Tod.',
    flavor: 'Stufe 1: Sahne. Stufe 2: Eischnee. Stufe 3: dich.',
    loot: ['ruehrbesen'],
  },
  {
    id: 'kesselkoenigin', name: 'Oma Gulasch, die Kesselkönigin', glyph: 'O', color: '#ff8040', level: 10,
    hp: 160, dmg: [6, 11], treffer: 75, ruestung: 3, ausweichen: 5, size: 'riesig', range: 4, xp: 400,
    rank: 'boroughboss',
    intro: 'In der Mitte des Gewölbes steht ein Kessel, groß wie ein Pool. Eine riesige alte Frau rührt darin und dreht sich langsam um. „Du bist aber dünn geworden. Komm, iss was.“',
    flavor: 'Wirft kochendes Gulasch. Die Treppe nach unten ist direkt hinter ihr.',
    loot: ['schoepfkelle', 'omas_schuerze'],
  },
];

export const GHOST_DEF = {
  glyph: '@',
  color: '#b0f0ff',
};
