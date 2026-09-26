import type { Bonuses, GameState, SpecialEffect } from '../engine/types';

export type ClassAbility =
  | 'wutanfall' | 'wirbelwind' | 'erdbeben' | 'kampfschrei' | 'bollwerk' | 'schattenschritt'
  | 'steinhagel' | 'bombe' | 'heilung' | 'showtime';

export interface AbilityDef {
  name: string;
  description: string;
  cooldown: number;
  /** Braucht ein Ziel (Klick auf Gegner/Feld nach Aktivierung). */
  targeted?: boolean;
}

export const ABILITIES: Record<ClassAbility, AbilityDef> = {
  wutanfall: { name: 'Wutanfall', description: '+50 % Schaden, −10 % Ausweichen für 8 Züge.', cooldown: 40 },
  wirbelwind: { name: 'Wirbelwind', description: 'Greift alle angrenzenden Gegner mit deiner gewählten Technik an.', cooldown: 25 },
  erdbeben: { name: 'Erdbeben', description: 'Stampft auf den Boden: alle Gegner im Umkreis von 2 Feldern nehmen Schaden und fallen um.', cooldown: 35 },
  kampfschrei: { name: 'Kampfschrei', description: 'Alle Gegner in Sichtweite fliehen, du erhältst +20 % Schaden für 10 Züge.', cooldown: 45 },
  bollwerk: { name: 'Bollwerk', description: '+6 Rüstung für 10 Züge.', cooldown: 40 },
  schattenschritt: { name: 'Schattenschritt', description: 'Alle Gegner verlieren dich aus den Augen, dein nächster Angriff ist ein Hinterhalt (+50 % Schaden, 5 Züge).', cooldown: 40 },
  steinhagel: { name: 'Steinhagel', description: 'Magische Steine treffen bis zu 4 sichtbare Gegner in Wurfreichweite.', cooldown: 30 },
  bombe: { name: 'Selbstgebaute Bombe', description: 'Explodiert beim nächsten sichtbaren Gegner und trifft alles im Umkreis.', cooldown: 35 },
  heilung: { name: 'Zweite Luft', description: 'Heilt 40 % deiner max. HP und dein Haustier vollständig.', cooldown: 60 },
  showtime: { name: 'Showtime!', description: 'Eine spektakuläre Pose: viele neue Follower und ein Geschenk aus dem Publikum.', cooldown: 80 },
};

export interface ClassDef {
  id: string;
  name: string;
  description: string;
  bonuses: Bonuses;
  ability: ClassAbility;
  special?: SpecialEffect;
  /** Skill, der beim Wählen 2 Stufen erhält (oder neu gelernt wird). */
  skill?: string;
  /** Wie gut passt die Klasse zum bisherigen Verhalten? Höher = besser. */
  score: (s: GameState) => number;
  comment: string;
}

const u = (s: GameState, pred: (k: string) => boolean) =>
  Object.entries(s.player.techniqueUses).filter(([k]) => !k.startsWith('_') && pred(k)).reduce((a, [, v]) => a + v, 0);
const part = (s: GameState, p: string) => u(s, (k) => k.startsWith(p + '+'));
const move = (s: GameState, m: string) => u(s, (k) => k.endsWith('+' + m));
const flag = (s: GameState, f: string) => (s.player.flags.includes(f) ? 1 : 0);
const stat = (s: GameState, k: 'str' | 'ges' | 'kon' | 'int' | 'cha') => s.player.stats[k];

export const CLASSES: ClassDef[] = [
  {
    id: 'strassenkaempfer', name: 'Straßenkämpfer', ability: 'wutanfall', skill: 'faustkampf',
    description: 'Fäuste, Dreck, keine Regeln. +2 Stärke, +25 % Faustschaden.',
    bonuses: { stats: { str: 2 }, schaden: { faust: 25 } },
    score: (s) => part(s, 'faust') * 2 + flag(s, 'schlaeger') * 15,
    comment: 'Du boxt wie jemand, der nie einen Boxkurs besucht hat. Das ist ein Kompliment.',
  },
  {
    id: 'kickboxer', name: 'Kellerkickboxer', ability: 'wirbelwind', skill: 'treten',
    description: 'Tritte aus allen Winkeln. +2 Geschick, +25 % Trittschaden.',
    bonuses: { stats: { ges: 2 }, schaden: { tritt: 25 } },
    score: (s) => part(s, 'tritt') * 2,
    comment: 'Beine sind länger als Arme. Das ist die ganze Philosophie.',
  },
  {
    id: 'stampfbarbar', name: 'Stampf-Barbar', ability: 'erdbeben', skill: 'stampfen',
    description: 'Wer liegt, wird plattgemacht. +2 Stärke, +1 Konstitution, +20 % Trittschaden.',
    bonuses: { stats: { str: 2, kon: 1 }, schaden: { tritt: 20 } },
    score: (s) => move(s, 'stampfen') * 5 + s.counters.knockdowns * 2,
    comment: 'Du hast ein Verhältnis zum Boden entwickelt. Und zu allem, was darauf liegt.',
  },
  {
    id: 'luchador', name: 'Luchador', ability: 'erdbeben', skill: 'sprungangriff',
    description: 'Fliegender Tod aus der Höhe. +2 Geschick, +1 Charisma, +15 % Schaden (alle).',
    bonuses: { stats: { ges: 2, cha: 1 }, schaden: { alle: 15 } },
    score: (s) => move(s, 'sprung') * 4,
    comment: 'Maske auf, Seil hoch, Gegner runter. Die Zuschauer drehen durch.',
  },
  {
    id: 'sturmbrecher', name: 'Sturmbrecher', ability: 'kampfschrei', skill: 'sturmangriff',
    description: 'Anlauf nehmen, durchbrechen. +2 Stärke, +2 Konstitution.',
    bonuses: { stats: { str: 2, kon: 2 }, maxHp: 5 },
    score: (s) => move(s, 'anlauf') * 4,
    comment: 'Du hältst Türen für eine Empfehlung.',
  },
  {
    id: 'schaedelmoench', name: 'Schädelmönch', ability: 'bollwerk', skill: 'kopfnuss',
    description: 'Meditiert. Und stößt mit dem Kopf zu. +2 Konstitution, +1 Intelligenz, +40 % Kopfstoßschaden.',
    bonuses: { stats: { kon: 2, int: 1 }, schaden: { kopf: 40 } },
    score: (s) => part(s, 'kopf') * 4,
    comment: 'Innere Ruhe, äußere Beule.',
  },
  {
    id: 'ellbogenanwalt', name: 'Ellbogen-Anwalt', ability: 'kampfschrei', skill: 'ellbogen',
    description: 'Setzt sich durch. +1 Stärke, +2 Charisma, +35 % Ellbogenschaden.',
    bonuses: { stats: { str: 1, cha: 2 }, schaden: { ellbogen: 35 } },
    score: (s) => part(s, 'ellbogen') * 4 + flag(s, 'buero') * 10,
    comment: 'Einspruch abgelehnt. Mit dem Ellbogen.',
  },
  {
    id: 'knieninja', name: 'Knie-Ninja', ability: 'schattenschritt', skill: 'knie',
    description: 'Lautlos und knochig. +2 Geschick, +35 % Knieschaden, +5 % Ausweichen.',
    bonuses: { stats: { ges: 2 }, schaden: { knie: 35 }, ausweichen: 5 },
    score: (s) => part(s, 'knie') * 4,
    comment: 'Niemand rechnet mit dem Knie. Genau darum geht es.',
  },
  {
    id: 'steinschleuderer', name: 'Steinschleuderer', ability: 'steinhagel', skill: 'werfen',
    description: 'Fernkampf mit allem, was herumliegt. +2 Geschick, +30 % Wurfschaden, +5 % Treffer.',
    bonuses: { stats: { ges: 2 }, schaden: { wurf: 30 }, treffer: 5 },
    score: (s) => part(s, 'wurf') * 3 + s.counters.throws,
    comment: 'David hätte dich eingestellt.',
  },
  {
    id: 'heimwerker', name: 'Heimwerker-Berserker', ability: 'wutanfall', skill: 'improvisation',
    description: 'Jedes Werkzeug ist eine Waffe. +2 Stärke, +30 % Waffenschaden.',
    bonuses: { stats: { str: 2 }, schaden: { waffe: 30 } },
    score: (s) => part(s, 'waffe') * 3 + flag(s, 'handwerk') * 15,
    comment: 'Baumarkt-Kundenkarte: Platin. Kills: auch.',
  },
  {
    id: 'bombenbastler', name: 'Bombenbastler', ability: 'bombe', special: 'explosionsschutz',
    description: 'Wenn es nicht knallt, ist es kein Plan. +3 Intelligenz, +1 Geschick, halbierter Explosionsschaden.',
    bonuses: { stats: { int: 3, ges: 1 } },
    score: (s) => stat(s, 'int') * 2 + flag(s, 'planer') * 20 + (s.counters.killsByDef['blaehkroete'] ?? 0) * 3,
    comment: 'Die Systemstimme bittet darum, nicht im Safe Room zu basteln.',
  },
  {
    id: 'feldsanitaeter', name: 'Feldsanitäter', ability: 'heilung', skill: 'erste_hilfe',
    description: 'Flickt sich selbst zusammen. +2 Intelligenz, +1 Konstitution, +1 HP-Regeneration.',
    bonuses: { stats: { int: 2, kon: 1 }, hpRegen: 1 },
    score: (s) => flag(s, 'heiler') * 25 + s.counters.potionsDrunk * 3 + stat(s, 'int'),
    comment: 'Ein Pflaster für jede Wunde. Du brauchst viele Pflaster.',
  },
  {
    id: 'showstar', name: 'Showstar', ability: 'showtime',
    description: 'Lebt für das Publikum. +3 Charisma, doppelt so viele neue Follower.',
    bonuses: { stats: { cha: 3 } },
    score: (s) => stat(s, 'cha') * 2 + flag(s, 'kuenstler') * 20 + Math.floor(s.viewers.follower / 50),
    comment: 'Die Kamera liebt dich. Die Kamera ist das Einzige, was hier unten noch jemanden liebt.',
  },
  {
    id: 'tierfluesterer', name: 'Tierflüsterer', ability: 'heilung',
    description: 'Dein Haustier wird zur Bestie. +2 Charisma, Haustier +3 Stufen.',
    bonuses: { stats: { cha: 2 } },
    score: (s) => (s.player.pet ? 30 + s.player.pet.level * 5 : -100),
    comment: 'Du sprichst mit Tieren. Die Tiere antworten. Meistens mit „Futter?“.',
  },
  {
    id: 'kampfkoch', name: 'Kampfkoch', ability: 'heilung', skill: 'kochen',
    description: 'Kocht, isst, prügelt. +2 Konstitution, +1 Stärke, +10 max. HP.',
    bonuses: { stats: { kon: 2, str: 1 }, maxHp: 10 },
    score: (s) => flag(s, 'koch') * 25 + s.counters.mealsEaten * 6,
    comment: 'Das Monster-Gulasch schmeckt besser, wenn man das Monster selbst erlegt hat.',
  },
  {
    id: 'assassine', name: 'Kellerassassine', ability: 'schattenschritt', skill: 'hinterhalt',
    description: 'Tötet, bevor man ihn bemerkt. +3 Geschick, +10 % Krit.',
    bonuses: { stats: { ges: 3 }, krit: 10 },
    score: (s) => (s.player.techniqueUses['_ambush'] ?? 0) * 4 + flag(s, 'feigling') * 10,
    comment: 'Leise, tödlich und etwas zu stolz darauf.',
  },
  {
    id: 'panzerkoloss', name: 'Panzerkoloss', ability: 'bollwerk', skill: 'zaehigkeit',
    description: 'Steckt alles ein. +3 Konstitution, +3 Rüstung, +10 max. HP, −3 % Ausweichen.',
    bonuses: { stats: { kon: 3 }, ruestung: 3, maxHp: 10, ausweichen: -3 },
    score: (s) => Math.floor(s.counters.damageTaken / 10) + flag(s, 'gemuetlich') * 10,
    comment: 'Du bist keine Person mehr. Du bist eine Wand mit Meinungen.',
  },
  {
    id: 'kellertaenzer', name: 'Kellertänzer', ability: 'schattenschritt', skill: 'ausweichen',
    description: 'Tanzt um jeden Schlag herum. +3 Geschick, +10 % Ausweichen.',
    bonuses: { stats: { ges: 3 }, ausweichen: 10 },
    score: (s) => (s.player.techniqueUses['_dodge'] ?? 0) * 2 + flag(s, 'laeufer') * 10 + flag(s, 'sportler') * 10,
    comment: 'Cha-cha-cha, Kopfnuss, cha-cha-cha.',
  },
];

export const CLASS_BY_ID: Record<string, ClassDef> = Object.fromEntries(CLASSES.map((c) => [c.id, c]));
