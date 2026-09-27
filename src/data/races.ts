import type { Bonuses, GameState, SpecialEffect } from '../engine/types';

export type RaceKind = 'grund' | 'freigeschaltet';

export interface RaceDef {
  id: string;
  name: string;
  /** Kurzer Text, wie man danach aussieht und lebt (Boni werden getrennt aufgelistet). */
  description: string;
  bonuses: Bonuses;
  specials?: SpecialEffect[];
  /** Begabung: dieser Skill wird gelernt und wächst 50 % schneller. */
  talent?: string;
  /** Freischaltbedingung – ohne Bedingung immer verfügbar. */
  requirement?: { text: string; check: (s: GameState) => boolean };
  comment: string;
}

const uses = (s: GameState, ...keys: string[]) =>
  Object.entries(s.player.techniqueUses)
    .filter(([k]) => keys.some((key) => k.startsWith(key) || k.endsWith(key)))
    .reduce((a, [, v]) => a + v, 0);
const st = (s: GameState, key: string) => s.stats?.[key] ?? 0;
const kills = (s: GameState, ids: string[]) => ids.reduce((a, id) => a + (s.counters.killsByDef[id] ?? 0), 0);

// Eigene Rassen. Einige sind frei wählbar, andere schaltet man durch sein
// Verhalten auf den ersten beiden Etagen frei.
export const RACES: RaceDef[] = [
  {
    id: 'mensch', name: 'Mensch (bleiben, wie du bist)',
    description: 'Keine Veränderung. Dafür 4 freie Stat-Punkte und schnelleres Lernen.',
    bonuses: { xpBonus: 10 },
    comment: 'Die meisten bleiben, was sie sind. Das ist mutig. Oder fantasielos.',
  },
  {
    id: 'halbork', name: 'Halbork', talent: 'faustkampf',
    description: 'Groß, grün, grob.',
    bonuses: { stats: { str: 3, kon: 2, int: -2, cha: -1 } },
    comment: 'Hauer stehen dir. Die Zahnärzte der Galaxis danken.',
  },
  {
    id: 'elf', name: 'Kellerelf', talent: 'wahrnehmung',
    description: 'Spitze Ohren, blasse Haut, sieht im Dunkeln.',
    bonuses: { stats: { ges: 3, int: 1, kon: -1 }, lichtradius: 1 },
    comment: 'Elfen aus dem Wald sind arrogant. Elfen aus dem Keller sind arrogant und blass.',
  },
  {
    id: 'zwerg', name: 'Zwerg', talent: 'zaehigkeit', specials: ['furchtlos'],
    description: 'Klein, breit, stur. Hat vor nichts Angst, außer vor Wasser.',
    bonuses: { stats: { kon: 3, str: 1, ges: -1 }, ruestung: 2 },
    comment: 'Du bist jetzt kürzer. Deine Gegner müssen sich bücken, um dich zu treffen. Sie tun es trotzdem.',
  },
  {
    id: 'gnom', name: 'Gnom', talent: 'handwerk',
    description: 'Winzig und clever.',
    bonuses: { stats: { int: 3, ges: 2, str: -2 }, ausweichen: 6 },
    comment: 'Klein genug, um übersehen zu werden. Laut genug, um es zu bereuen.',
  },
  {
    id: 'halbling', name: 'Halbling', talent: 'kochen',
    description: 'Flink, charmant, hungrig.',
    bonuses: { stats: { ges: 2, cha: 2, str: -2 }, ausweichen: 8 },
    comment: 'Zweites Frühstück ist jetzt ein Grundrecht.',
  },
  {
    id: 'echsenmensch', name: 'Echsenmensch', talent: 'zaehigkeit',
    description: 'Schuppig und zäh.',
    bonuses: { stats: { kon: 2 }, ruestung: 2, hpRegen: 1 },
    comment: 'Kaltblütig. Im wörtlichen Sinn. Bitte halte dich von Klimaanlagen fern.',
  },
  {
    id: 'hobgoblin', name: 'Hobgoblin', talent: 'improvisation',
    description: 'Größer als ein Kobold, klüger als ein Ork, hässlicher als beide.',
    bonuses: { stats: { str: 2, ges: 2, cha: -1 }, krit: 3 },
    comment: 'Die Kobolde sehen zu dir auf. Buchstäblich.',
  },
  // ------------------------------------------------------------ Freischaltbar
  {
    id: 'katzenmensch', name: 'Katzenmensch', talent: 'schleichen', specials: ['krallen'],
    description: 'Geschmeidig und gemein. Die Krallen reißen blutende Wunden.',
    bonuses: { stats: { ges: 2, cha: 1 }, krit: 6, ausweichen: 4 },
    requirement: { text: 'Mit einer Katze in den Dungeon gegangen', check: (s) => s.player.pet?.species === 'Katze' },
    comment: 'Deine Katze sieht dich jetzt als Gleichgestellte. Das ist ein Rückschritt für sie.',
  },
  {
    id: 'troll', name: 'Höhlentroll', talent: 'schmerzresistenz',
    description: 'Riesig, dumm, regenerierend.',
    bonuses: { stats: { str: 4, kon: 3, int: -3, cha: -3 }, hpRegen: 2 },
    requirement: { text: '15 Gegner zu Boden geworfen', check: (s) => s.counters.knockdowns >= 15 },
    comment: 'Du bist jetzt zwei Meter fünfzig. Türen sind dein neuer Feind.',
  },
  {
    id: 'minotaurus', name: 'Minotaurus', talent: 'sturmangriff', specials: ['furchtlos'],
    description: 'Stierkopf, Stiermut.',
    bonuses: { stats: { str: 3, kon: 2 }, schaden: { kopf: 50 } },
    requirement: { text: '25 Kopfstöße oder Sturmangriffe', check: (s) => uses(s, 'kopf+', '+anlauf') >= 25 },
    comment: 'Du hast jetzt Hörner. Und ein Labyrinth. Na ja, du hattest das Labyrinth schon vorher.',
  },
  {
    id: 'golem', name: 'Lehmgolem', talent: 'abwehr', specials: ['blutlos'],
    description: 'Wandelnde Mauer. Lehm blutet nicht.',
    bonuses: { stats: { str: 2 }, ruestung: 4, maxHp: 10, ausweichen: -6 },
    requirement: { text: 'Insgesamt 150 Schaden eingesteckt', check: (s) => s.counters.damageTaken >= 150 },
    comment: 'Du bestehst jetzt aus Lehm. Regen ist ab sofort ein Problem.',
  },
  {
    id: 'pilzling', name: 'Pilzling', talent: 'giftfestigkeit', specials: ['giftimmun'],
    description: 'Ein wandelnder Pilz. Immun gegen Gift.',
    bonuses: { stats: { kon: 2, cha: -2 }, hpRegen: 1 },
    requirement: { text: 'Insgesamt 20 Giftschaden erlitten', check: (s) => s.counters.poisonDamage >= 20 },
    comment: 'Du bist jetzt essbar. Theoretisch. Bitte teste das nicht.',
  },
  {
    id: 'vampir', name: 'Kellervampir', talent: 'hinterhalt', specials: ['vampir'],
    description: 'Blass und durstig. Ein Teil des Nahkampfschadens heilt dich.',
    bonuses: { stats: { cha: 2, ges: 1 }, maxHp: -5 },
    requirement: { text: '10 kritische Treffer gelandet', check: (s) => s.counters.crits >= 10 },
    comment: 'Knoblauch ist ab sofort ein Kriegsverbrechen.',
  },
  {
    id: 'kobold', name: 'Kobold', talent: 'werfen',
    description: 'Klein, gierig, treffsicher.',
    bonuses: { stats: { ges: 2, int: 1, str: -1 }, schaden: { wurf: 30 } },
    requirement: { text: '20 Gegenstände geworfen', check: (s) => s.counters.throws >= 20 },
    comment: 'Du hast so viele Kobolde getötet, dass du jetzt einer bist. Ironie ist ein Gericht, das man kalt serviert.',
  },
  {
    id: 'salamander', name: 'Salamanderblut', talent: 'kondition', specials: ['feuerfest'],
    description: 'Warme, rote Schuppen. Feuer kitzelt nur.',
    bonuses: { stats: { ges: 2, kon: 1, int: -1 } },
    requirement: { text: '5 Gegner in Brand gesetzt oder selbst gebrannt', check: (s) => st(s, 'zustand.brennen') + st(s, 'zustand.erlitten.brennen') >= 5 },
    comment: 'Du bist jetzt feuerfest. Grillabende werden nie wieder dieselben sein.',
  },
  {
    id: 'rattling', name: 'Rattling', talent: 'schleichen', specials: ['rattenfreund'],
    description: 'Schnurrhaare, Schwanz, gute Nase. Ratten halten dich für Familie.',
    bonuses: { stats: { ges: 2, int: 1, cha: -1 }, lichtradius: 1 },
    requirement: { text: '25 Ratten besiegt', check: (s) => kills(s, ['kellerratte', 'rattenmensch', 'rattenschamane', 'knochenratte']) >= 25 },
    comment: 'Die Ratten verzeihen dir die 25 Verwandten. Sie haben viele Verwandte.',
  },
  {
    id: 'kelleroger', name: 'Kelleroger', talent: 'schmerzresistenz',
    description: 'Ein Berg aus Muskeln und schlechten Entscheidungen. Lernt langsam.',
    bonuses: { stats: { str: 4, kon: 3, ges: -2, int: -2 }, maxHp: 10, ruestung: 1, xpBonus: -10 },
    requirement: { text: '5 Gegner besiegt, die mindestens drei Stufen über dir standen', check: (s) => st(s, 'kills.staerker') >= 5 },
    comment: 'Du denkst jetzt langsamer. Aber du schlägst schneller, als andere denken.',
  },
  {
    id: 'schattenwesen', name: 'Schattenwesen', talent: 'hinterhalt', specials: ['scharfsichtig'],
    description: 'Halb da, halb nicht. Licht blendet dich nicht mehr, es geht einfach durch.',
    bonuses: { stats: { ges: 3, int: 1, kon: -2 }, ausweichen: 6 },
    requirement: { text: '15 Angriffe auf ahnungslose Gegner', check: (s) => (s.player.techniqueUses['_ambush'] ?? 0) >= 15 },
    comment: 'Man sieht dich nur noch, wenn du es willst. Die Kamera hat trotzdem ihre Mittel.',
  },
  {
    id: 'wasserspeier', name: 'Wasserspeier', talent: 'abwehr', specials: ['blutlos'],
    description: 'Eine lebende Steinfigur mit Flügelstummeln. Stein blutet nicht.',
    bonuses: { stats: { kon: 3, str: 1 }, ruestung: 3, ausweichen: -4 },
    requirement: { text: '20-mal in Deckung angegriffen worden', check: (s) => (s.player.techniqueUses['_block'] ?? 0) >= 20 },
    comment: 'Du bist jetzt Architektur. Tauben lieben dich.',
  },
  {
    id: 'kellerfee', name: 'Kellerfee', talent: 'arkane_kunde',
    description: 'Winzig, leuchtend, voller Magie. Zerbrechlich wie ein Weinglas.',
    bonuses: { stats: { int: 3, cha: 2, str: -3 }, maxMp: 6, ausweichen: 8, lichtradius: 1, maxHp: -5 },
    requirement: { text: '3 Zauber beherrscht', check: (s) => (s.player.spells?.length ?? 0) >= 3 },
    comment: 'Du glitzerst. Das lässt sich nicht abstellen. Die Monster sehen dich schon von Weitem.',
  },
  {
    id: 'ghulblut', name: 'Ghulblut', talent: 'kochen', specials: ['aasfresser'],
    description: 'Isst, was andere liegen lassen. Essen heilt dich doppelt.',
    bonuses: { stats: { kon: 2, str: 1, cha: -2 }, hpRegen: 1 },
    requirement: { text: '10 Untote besiegt', check: (s) => kills(s, ['ghul', 'moorleiche', 'knochenratte', 'kellermeister', 'ghulhund']) >= 10 },
    comment: 'Dein Atem ist eine Waffe. Leider auch in Gesprächen.',
  },
  {
    id: 'blechmensch', name: 'Blechmensch', talent: 'handwerk', specials: ['blutlos', 'giftimmun'],
    description: 'Bolzen, Bleche, ein tickendes Herz. Kein Blut, kein Gift, keine Gefühle. Fast.',
    bonuses: { stats: { kon: 3, cha: -2 }, ruestung: 3, hpRegen: -1 },
    requirement: { text: '10 Dinge hergestellt', check: (s) => s.counters.crafted >= 10 },
    comment: 'Du quietschst beim Gehen. Öl steht ab sofort auf deiner Einkaufsliste.',
  },
  {
    id: 'drachenblut', name: 'Drachenblut', talent: 'rampenlicht', specials: ['feuerfest', 'furchtlos'],
    description: 'Ein Hauch von Drache: goldene Augen, heißer Atem, großes Ego.',
    bonuses: { stats: { str: 2, kon: 2, cha: 2 } },
    requirement: { text: '3 Bosse besiegt', check: (s) => s.counters.bossKills >= 3 },
    comment: 'Legenden erzählen von Drachen. Jetzt erzählen sie von dir. Etwas kleiner.',
  },
];

export const RACE_BY_ID: Record<string, RaceDef> = Object.fromEntries(RACES.map((r) => [r.id, r]));
