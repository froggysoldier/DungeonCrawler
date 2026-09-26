import type { Bonuses, GameState, SpecialEffect } from '../engine/types';

export interface RaceDef {
  id: string;
  name: string;
  description: string;
  bonuses: Bonuses;
  special?: SpecialEffect;
  /** Freischaltbedingung – ohne Bedingung immer verfügbar. */
  requirement?: { text: string; check: (s: GameState) => boolean };
  comment: string;
}

const uses = (s: GameState, ...keys: string[]) =>
  Object.entries(s.player.techniqueUses)
    .filter(([k]) => keys.some((key) => k.startsWith(key) || k.endsWith(key)))
    .reduce((a, [, v]) => a + v, 0);

// Eigene Rassen. Einige sind frei wählbar, andere schaltet man durch sein
// Verhalten auf den ersten beiden Etagen frei.
export const RACES: RaceDef[] = [
  {
    id: 'mensch', name: 'Mensch (bleiben, wie du bist)',
    description: 'Keine Veränderung. Dafür +4 freie Stat-Punkte und +10 % XP.',
    bonuses: { xpBonus: 10 },
    comment: 'Die meisten bleiben, was sie sind. Das ist mutig. Oder fantasielos.',
  },
  {
    id: 'halbork', name: 'Halbork',
    description: 'Groß, grün, grob. +3 Stärke, +2 Konstitution, −2 Intelligenz, −1 Charisma.',
    bonuses: { stats: { str: 3, kon: 2, int: -2, cha: -1 } },
    comment: 'Hauer stehen dir. Die Zahnärzte der Galaxis danken.',
  },
  {
    id: 'elf', name: 'Kellerelf',
    description: 'Spitze Ohren, blasse Haut, sieht im Dunkeln. +3 Geschick, +1 Intelligenz, −1 Konstitution, +1 Sichtweite.',
    bonuses: { stats: { ges: 3, int: 1, kon: -1 }, lichtradius: 1 },
    comment: 'Elfen aus dem Wald sind arrogant. Elfen aus dem Keller sind arrogant und blass.',
  },
  {
    id: 'zwerg', name: 'Zwerg',
    description: 'Klein, breit, stur. +3 Konstitution, +1 Stärke, −1 Geschick, +2 Rüstung.',
    bonuses: { stats: { kon: 3, str: 1, ges: -1 }, ruestung: 2 },
    comment: 'Du bist jetzt kürzer. Deine Gegner müssen sich bücken, um dich zu treffen. Sie tun es trotzdem.',
  },
  {
    id: 'gnom', name: 'Gnom',
    description: 'Winzig und clever. +3 Intelligenz, +2 Geschick, −2 Stärke, +6 % Ausweichen.',
    bonuses: { stats: { int: 3, ges: 2, str: -2 }, ausweichen: 6 },
    comment: 'Klein genug, um übersehen zu werden. Laut genug, um es zu bereuen.',
  },
  {
    id: 'halbling', name: 'Halbling',
    description: 'Flink, charmant, hungrig. +2 Geschick, +2 Charisma, −2 Stärke, +8 % Ausweichen.',
    bonuses: { stats: { ges: 2, cha: 2, str: -2 }, ausweichen: 8 },
    comment: 'Zweites Frühstück ist jetzt ein Grundrecht.',
  },
  {
    id: 'echsenmensch', name: 'Echsenmensch',
    description: 'Schuppig und zäh. +2 Konstitution, +2 Rüstung, +1 HP-Regeneration.',
    bonuses: { stats: { kon: 2 }, ruestung: 2, hpRegen: 1 },
    comment: 'Kaltblütig. Im wörtlichen Sinn. Bitte halte dich von Klimaanlagen fern.',
  },
  {
    id: 'katzenmensch', name: 'Katzenmensch',
    description: 'Geschmeidig und gemein. +2 Geschick, +1 Charisma, +6 % Krit, +4 % Ausweichen.',
    bonuses: { stats: { ges: 2, cha: 1 }, krit: 6, ausweichen: 4 },
    requirement: { text: 'Mit einer Katze in den Dungeon gegangen', check: (s) => s.player.pet?.species === 'Katze' },
    comment: 'Deine Katze sieht dich jetzt als Gleichgestellte. Das ist ein Rückschritt für sie.',
  },
  {
    id: 'troll', name: 'Höhlentroll',
    description: 'Riesig, dumm, regenerierend. +4 Stärke, +3 Konstitution, −3 Intelligenz, −3 Charisma, +2 HP-Regeneration.',
    bonuses: { stats: { str: 4, kon: 3, int: -3, cha: -3 }, hpRegen: 2 },
    requirement: { text: '15 Gegner zu Boden geworfen', check: (s) => s.counters.knockdowns >= 15 },
    comment: 'Du bist jetzt zwei Meter fünfzig. Türen sind dein neuer Feind.',
  },
  {
    id: 'minotaurus', name: 'Minotaurus',
    description: 'Stierkopf, Stiermut. +3 Stärke, +2 Konstitution, +50 % Kopfstoßschaden.',
    bonuses: { stats: { str: 3, kon: 2 }, schaden: { kopf: 50 } },
    requirement: { text: '25 Kopfstöße oder Sturmangriffe', check: (s) => uses(s, 'kopf+', '+anlauf') >= 25 },
    comment: 'Du hast jetzt Hörner. Und ein Labyrinth. Na ja, du hattest das Labyrinth schon vorher.',
  },
  {
    id: 'golem', name: 'Lehmgolem',
    description: 'Wandelnde Mauer. +2 Stärke, +4 Rüstung, +10 max. HP, −6 % Ausweichen.',
    bonuses: { stats: { str: 2 }, ruestung: 4, maxHp: 10, ausweichen: -6 },
    requirement: { text: 'Insgesamt 150 Schaden eingesteckt', check: (s) => s.counters.damageTaken >= 150 },
    comment: 'Du bestehst jetzt aus Lehm. Regen ist ab sofort ein Problem.',
  },
  {
    id: 'pilzling', name: 'Pilzling',
    description: 'Ein wandelnder Pilz. Immun gegen Gift, +2 Konstitution, +1 HP-Regeneration, −2 Charisma.',
    bonuses: { stats: { kon: 2, cha: -2 }, hpRegen: 1 },
    special: 'giftimmun',
    requirement: { text: 'Insgesamt 20 Giftschaden erlitten', check: (s) => s.counters.poisonDamage >= 20 },
    comment: 'Du bist jetzt essbar. Theoretisch. Bitte teste das nicht.',
  },
  {
    id: 'vampir', name: 'Kellervampir',
    description: 'Blass und durstig. 15 % Lebensraub im Nahkampf, +2 Charisma, +1 Geschick, −5 max. HP.',
    bonuses: { stats: { cha: 2, ges: 1 }, maxHp: -5 },
    special: 'vampir',
    requirement: { text: '10 kritische Treffer gelandet', check: (s) => s.counters.crits >= 10 },
    comment: 'Knoblauch ist ab sofort ein Kriegsverbrechen.',
  },
  {
    id: 'kobold', name: 'Kobold',
    description: 'Klein, gierig, treffsicher. +2 Geschick, +1 Intelligenz, −1 Stärke, +30 % Wurfschaden.',
    bonuses: { stats: { ges: 2, int: 1, str: -1 }, schaden: { wurf: 30 } },
    requirement: { text: '20 Gegenstände geworfen', check: (s) => s.counters.throws >= 20 },
    comment: 'Du hast so viele Kobolde getötet, dass du jetzt einer bist. Ironie ist ein Gericht, das man kalt serviert.',
  },
];

export const RACE_BY_ID: Record<string, RaceDef> = Object.fromEntries(RACES.map((r) => [r.id, r]));
