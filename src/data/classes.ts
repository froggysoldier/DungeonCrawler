import type { Bonuses, GameState, SpecialEffect } from '../engine/types';

export type ClassAbility =
  | 'wutanfall' | 'wirbelwind' | 'erdbeben' | 'kampfschrei' | 'bollwerk' | 'schattenschritt'
  | 'steinhagel' | 'bombe' | 'heilung' | 'showtime'
  | 'blutrausch' | 'gnadenstoss' | 'giftwolke' | 'brandsatz' | 'blitzlicht' | 'meditation' | 'rudelruf'
  | 'zeitlupe' | 'rauchbombe' | 'langfinger' | 'notreparatur' | 'motivationsrede' | 'arkanschild' | 'manaflut' | 'totstellen';

export interface AbilityDef {
  name: string;
  description: string;
  cooldown: number;
  /** Braucht ein Ziel (Klick auf Gegner/Feld nach Aktivierung). */
  targeted?: boolean;
  /** Darf auch im Safe Room benutzt werden. */
  peaceful?: boolean;
}

export const ABILITIES: Record<ClassAbility, AbilityDef> = {
  wutanfall: { name: 'Wutanfall', description: '+50 % Schaden, −10 % Ausweichen für 8 Züge.', cooldown: 40 },
  wirbelwind: { name: 'Wirbelwind', description: 'Greift alle angrenzenden Gegner mit deiner gewählten Technik an.', cooldown: 25 },
  erdbeben: { name: 'Erdbeben', description: 'Stampft auf den Boden: alle Gegner im Umkreis von 2 Feldern nehmen Schaden und fallen um.', cooldown: 35 },
  kampfschrei: { name: 'Kampfschrei', description: 'Alle Gegner in Sichtweite geraten in Furcht (Bosse nicht), du erhältst +20 % Schaden für 10 Züge.', cooldown: 45 },
  bollwerk: { name: 'Bollwerk', description: '+6 Rüstung für 10 Züge.', cooldown: 40, peaceful: true },
  schattenschritt: { name: 'Schattenschritt', description: 'Alle Gegner verlieren dich aus den Augen, dein nächster Angriff ist ein Hinterhalt (+50 % Schaden, 5 Züge).', cooldown: 40 },
  steinhagel: { name: 'Steinhagel', description: 'Magische Steine treffen bis zu 4 sichtbare Gegner in Wurfreichweite.', cooldown: 30 },
  bombe: { name: 'Selbstgebaute Bombe', description: 'Explodiert beim nächsten sichtbaren Gegner und trifft alles im Umkreis.', cooldown: 35 },
  heilung: { name: 'Zweite Luft', description: 'Heilt 40 % deiner max. HP und dein Haustier vollständig.', cooldown: 60, peaceful: true },
  showtime: { name: 'Showtime!', description: 'Eine spektakuläre Pose: viele neue Follower und ein Geschenk aus dem Publikum.', cooldown: 80, peaceful: true },
  blutrausch: { name: 'Blutrausch', description: '8 Züge lang lässt jeder Treffer bluten, dazu +15 % Schaden.', cooldown: 40 },
  gnadenstoss: { name: 'Gnadenstoß', description: '3 Züge lang: Treffer gegen Gegner unter 35 % Lebenspunkten richten dreifachen Schaden an.', cooldown: 30 },
  giftwolke: { name: 'Giftwolke', description: 'Eine grüne Wolke um den nächsten sichtbaren Gegner vergiftet alles im Umkreis von 2 Feldern.', cooldown: 35 },
  brandsatz: { name: 'Brandsatz', description: 'Setzt alle Gegner im Umkreis von 2 Feldern in Brand.', cooldown: 40 },
  blitzlicht: { name: 'Blitzlicht', description: 'Ein greller Blitz blendet alle sichtbaren Gegner im Umkreis von 4 Feldern.', cooldown: 35 },
  meditation: { name: 'Meditation', description: 'Volle Ausdauer, die Hälfte des Manas zurück und +10 % Ausweichen für 6 Züge.', cooldown: 50, peaceful: true },
  rudelruf: { name: 'Rudelruf', description: 'Dein Haustier ist sofort wieder da, voll geheilt und richtet 10 Züge lang doppelten Schaden an.', cooldown: 45, peaceful: true },
  zeitlupe: { name: 'Zeitlupe', description: 'Alle sichtbaren Gegner bewegen sich 6 Züge lang wie in Sirup.', cooldown: 45 },
  rauchbombe: { name: 'Rauchbombe', description: 'Blendet alle angrenzenden Gegner, alle anderen verlieren dich aus den Augen.', cooldown: 40 },
  langfinger: { name: 'Langfinger', description: 'Klaut einem angrenzenden Gegner Gold und manchmal einen Gegenstand.', cooldown: 25 },
  notreparatur: { name: 'Notreparatur', description: 'Dein Reittier ist sofort wieder einsatzbereit und voll repariert, dazu +4 Rüstung für 10 Züge.', cooldown: 60, peaceful: true },
  motivationsrede: { name: 'Motivationsrede', description: 'Party und Haustier heilen 30 %, alle (du auch) richten 10 Züge lang +15 % Schaden an.', cooldown: 60, peaceful: true },
  arkanschild: { name: 'Arkaner Schild', description: 'Ein Schild aus Mana fängt 10 + 2 pro Intelligenz + Stufe Schaden ab (30 Züge).', cooldown: 45, peaceful: true },
  manaflut: { name: 'Manaflut', description: 'Füllt dein Mana vollständig, Zauber wirken 10 Züge lang 30 % stärker.', cooldown: 70, peaceful: true },
  totstellen: { name: 'Totstellen', description: 'Alle Gegner verlieren das Interesse an dir, du erholst dich um 15 % deiner Lebenspunkte.', cooldown: 60 },
};

export type ClassArchetype = 'nahkampf' | 'fernkampf' | 'magie' | 'heimlich' | 'verteidigung' | 'heilung' | 'show' | 'handwerk' | 'tiere' | 'exotisch';

export const ARCHETYPE_NAMES: Record<ClassArchetype, string> = {
  nahkampf: 'Nahkampf', fernkampf: 'Fernkampf', magie: 'Magie', heimlich: 'Heimlichkeit', verteidigung: 'Verteidigung',
  heilung: 'Heilung und Versorgung', show: 'Show und Handel', handwerk: 'Handwerk und Technik', tiere: 'Tiere und Reittiere', exotisch: 'Sonderklasse',
};

export type ClassRarity = 'normal' | 'selten' | 'legendaer';
export const CLASS_RARITY_NAMES: Record<ClassRarity, string> = { normal: 'Gewöhnlich', selten: 'Selten', legendaer: 'Legendär' };

export interface ClassDef {
  id: string;
  name: string;
  archetype: ClassArchetype;
  rarity: ClassRarity;
  /** Kurzer Text, worum es geht (Boni werden getrennt aufgelistet). */
  description: string;
  bonuses: Bonuses;
  ability: ClassAbility;
  /** Besondere Eigenschaften (siehe data/specials.ts). */
  specials?: SpecialEffect[];
  /**
   * Klassenskills: wachsen 50 % schneller. Der erste bekommt beim Wählen zwei
   * Stufen (oder wird auf Stufe 2 gelernt), die anderen werden gelernt.
   */
  skills: string[];
  /** Zauber, die man mit der Klasse sofort beherrscht. */
  spells?: string[];
  /** Startausrüstung: [Gegenstand, Menge]. */
  gear?: [string, number][];
  /** Freischaltbedingung: ohne sie taucht die Klasse nicht auf der Liste auf. */
  requirement?: { text: string; check: (s: GameState) => boolean };
  /** Wie gut passt die Klasse zum bisherigen Verhalten? Höher = besser. */
  score: (s: GameState) => number;
  comment: string;
}

const u = (s: GameState, pred: (k: string) => boolean) =>
  Object.entries(s.player.techniqueUses).filter(([k]) => !k.startsWith('_') && pred(k)).reduce((a, [, v]) => a + v, 0);
const part = (s: GameState, p: string) => u(s, (k) => k.startsWith(p + '+'));
const move = (s: GameState, m: string) => u(s, (k) => k.endsWith('+' + m));
const flag = (s: GameState, f: string) => (s.player.flags.includes(f) ? 1 : 0);
const trait = (s: GameState, t: string) => (s.player.traits?.includes(t) ? 1 : 0);
const stat = (s: GameState, k: 'str' | 'ges' | 'kon' | 'int' | 'cha') => s.player.stats[k];
const st = (s: GameState, key: string) => s.stats?.[key] ?? 0;
const trig = (s: GameState, t: string) => s.player.techniqueUses[`_${t}`] ?? 0;
const tagKills = (s: GameState, ids: string[]) => ids.reduce((a, id) => a + (s.counters.killsByDef[id] ?? 0), 0);

const RATS = ['kellerratte', 'rattenmensch', 'rattenschamane', 'knochenratte'];

export const CLASSES: ClassDef[] = [
  // ============================================================ Nahkampf
  {
    id: 'strassenkaempfer', name: 'Straßenkämpfer', archetype: 'nahkampf', rarity: 'normal', ability: 'wutanfall',
    skills: ['faustkampf', 'ellbogen'],
    description: 'Fäuste, Dreck, keine Regeln.',
    bonuses: { stats: { str: 2 }, schaden: { faust: 25 } },
    score: (s) => part(s, 'faust') * 2 + flag(s, 'schlaeger') * 15 + trait(s, 'profischlaeger') * 20,
    comment: 'Du boxt wie jemand, der nie einen Boxkurs besucht hat. Das ist ein Kompliment.',
  },
  {
    id: 'kickboxer', name: 'Kellerkickboxer', archetype: 'nahkampf', rarity: 'normal', ability: 'wirbelwind',
    skills: ['treten', 'ausweichen'],
    description: 'Tritte aus allen Winkeln.',
    bonuses: { stats: { ges: 2 }, schaden: { tritt: 25 } },
    score: (s) => part(s, 'tritt') * 2 + flag(s, 'kampfsport') * 15 + trait(s, 'fussballer') * 15,
    comment: 'Beine sind länger als Arme. Das ist die ganze Philosophie.',
  },
  {
    id: 'stampfbarbar', name: 'Stampf-Barbar', archetype: 'nahkampf', rarity: 'normal', ability: 'erdbeben',
    skills: ['stampfen', 'zaehigkeit'],
    description: 'Wer liegt, wird plattgemacht.',
    bonuses: { stats: { str: 2, kon: 1 }, schaden: { tritt: 20 } },
    score: (s) => move(s, 'stampfen') * 5 + s.counters.knockdowns * 2,
    comment: 'Du hast ein Verhältnis zum Boden entwickelt. Und zu allem, was darauf liegt.',
  },
  {
    id: 'luchador', name: 'Luchador', archetype: 'nahkampf', rarity: 'normal', ability: 'erdbeben',
    skills: ['sprungangriff', 'rampenlicht'],
    description: 'Fliegender Tod aus der Höhe, mit Maske und Umhang.',
    bonuses: { stats: { ges: 2, cha: 1 }, schaden: { alle: 15 } },
    score: (s) => move(s, 'sprung') * 4 + trait(s, 'rampensau') * 10,
    comment: 'Maske auf, Seil hoch, Gegner runter. Die Zuschauer drehen durch.',
  },
  {
    id: 'sturmbrecher', name: 'Sturmbrecher', archetype: 'nahkampf', rarity: 'normal', ability: 'kampfschrei',
    skills: ['sturmangriff', 'kondition'],
    description: 'Anlauf nehmen, durchbrechen.',
    bonuses: { stats: { str: 2, kon: 2 }, maxHp: 5 },
    score: (s) => move(s, 'anlauf') * 4 + trait(s, 'rugby') * 20,
    comment: 'Du hältst Türen für eine Empfehlung.',
  },
  {
    id: 'ellbogenanwalt', name: 'Ellbogen-Anwalt', archetype: 'nahkampf', rarity: 'normal', ability: 'kampfschrei',
    skills: ['ellbogen', 'feilschen'],
    description: 'Setzt sich durch. In jeder Warteschlange und in jedem Kampf.',
    bonuses: { stats: { str: 1, cha: 2 }, schaden: { ellbogen: 35 } },
    score: (s) => part(s, 'ellbogen') * 4 + flag(s, 'buero') * 10 + trait(s, 'verhandler') * 10,
    comment: 'Einspruch abgelehnt. Mit dem Ellbogen.',
  },
  {
    id: 'knieninja', name: 'Knie-Ninja', archetype: 'nahkampf', rarity: 'normal', ability: 'schattenschritt',
    skills: ['knie', 'schleichen'],
    description: 'Lautlos und knochig.',
    bonuses: { stats: { ges: 2 }, schaden: { knie: 35 }, ausweichen: 5 },
    score: (s) => part(s, 'knie') * 4,
    comment: 'Niemand rechnet mit dem Knie. Genau darum geht es.',
  },
  {
    id: 'heimwerker', name: 'Heimwerker-Berserker', archetype: 'nahkampf', rarity: 'normal', ability: 'wutanfall',
    skills: ['improvisation', 'handwerk'],
    description: 'Jedes Werkzeug ist eine Waffe.',
    bonuses: { stats: { str: 2 }, schaden: { waffe: 30 } },
    score: (s) => part(s, 'waffe') * 3 + flag(s, 'handwerk') * 15,
    comment: 'Baumarkt-Kundenkarte: Platin. Kills: auch.',
  },
  {
    id: 'klingenvirtuose', name: 'Küchenklingen-Virtuose', archetype: 'nahkampf', rarity: 'normal', ability: 'blutrausch',
    skills: ['improvisation', 'anatomie'], specials: ['klingenmeister'],
    description: 'Schneidet schneller, als andere denken. Jede Waffe wird in deiner Hand zur Klinge.',
    bonuses: { stats: { ges: 2 }, schaden: { waffe: 15 }, krit: 5 },
    gear: [['verband', 2]],
    score: (s) => part(s, 'waffe') * 2 + st(s, 'zustand.blutung') * 4 + flag(s, 'gastro') * 10 + flag(s, 'koch') * 10,
    comment: 'Julienne, Brunoise, Kobold. Du kennst alle Schnitttechniken.',
  },
  {
    id: 'scharfrichter', name: 'Scharfrichter', archetype: 'nahkampf', rarity: 'normal', ability: 'gnadenstoss',
    skills: ['anatomie', 'schmerzresistenz'],
    description: 'Beendet, was andere angefangen haben. Gezielt und ohne Zögern.',
    bonuses: { stats: { str: 2, kon: 1 }, krit: 5 },
    score: (s) => st(s, 'kills.zone.kopf') * 4 + st(s, 'kills.liegend') * 2 + st(s, 'kills.fasttot') * 2,
    comment: 'Die Systemstimme nennt es Effizienz. Die Monster nennen es anders.',
  },
  {
    id: 'tuersteher', name: 'Türsteher', archetype: 'nahkampf', rarity: 'normal', ability: 'kampfschrei',
    skills: ['abwehr', 'zaehigkeit'], specials: ['furchtlos'],
    description: 'Du kommst hier nicht rein. Niemand kommt hier rein.',
    bonuses: { stats: { str: 2, kon: 2 }, ruestung: 1 },
    score: (s) => trait(s, 'tuersteher') * 35 + flag(s, 'polizei') * 15 + s.counters.knockdowns + trig(s, 'block') * 2,
    comment: 'Heute nur mit Einladung. Und die Einladung ist deine Faust.',
  },
  {
    id: 'kneipenschlaeger', name: 'Kneipenschläger', archetype: 'nahkampf', rarity: 'normal', ability: 'wutanfall',
    skills: ['faustkampf', 'improvisation'],
    description: 'Hat schon in Kneipen gekämpft, die schlimmer waren als dieser Keller.',
    bonuses: { stats: { str: 2, cha: 1 }, schaden: { faust: 15, ellbogen: 15, kopf: 15 } },
    gear: [['dosenbier', 2]],
    score: (s) => st(s, 'kills.angetrunken') * 8 + flag(s, 'gastro') * 10 + trait(s, 'barkeeper') * 15 + part(s, 'kopf'),
    comment: 'Der Barhocker ist die ehrlichste Waffe der Welt.',
  },
  // ============================================================ Fernkampf
  {
    id: 'steinschleuderer', name: 'Steinschleuderer', archetype: 'fernkampf', rarity: 'normal', ability: 'steinhagel',
    skills: ['werfen', 'wahrnehmung'],
    description: 'Fernkampf mit allem, was herumliegt.',
    bonuses: { stats: { ges: 2 }, schaden: { wurf: 30 }, treffer: 5 },
    gear: [['stein', 8]],
    score: (s) => part(s, 'wurf') * 3 + s.counters.throws,
    comment: 'Ein biblischer Held hätte dich eingestellt.',
  },
  {
    id: 'dartprofi', name: 'Dartprofi', archetype: 'fernkampf', rarity: 'normal', ability: 'steinhagel',
    skills: ['werfen', 'anatomie'],
    description: 'Triple Twenty. Auch wenn die Zwanzig ein Auge ist.',
    bonuses: { stats: { ges: 3 }, schaden: { wurf: 20 }, treffer: 10 },
    gear: [['dartpfeil', 10]],
    score: (s) => part(s, 'wurf') * 2 + st(s, 'kills.weitwurf') * 10 + trait(s, 'barkeeper') * 15 + trait(s, 'adleraugen') * 15,
    comment: 'Hundertachtzig! Die Zuschauer brüllen es mit.',
  },
  {
    id: 'kellerartillerist', name: 'Kellerartillerist', archetype: 'fernkampf', rarity: 'selten', ability: 'bombe',
    skills: ['sprengmeister', 'werfen'], specials: ['explosionsschutz'],
    description: 'Wirft Dinge, die explodieren. Weit. Und oft.',
    bonuses: { stats: { int: 2, ges: 1 }, schaden: { wurf: 25 } },
    gear: [['nagelbombe', 2]],
    requirement: { text: '8 Gegner mit Sprengsätzen besiegt', check: (s) => st(s, 'kills.teil.bombe') >= 8 },
    score: (s) => st(s, 'kills.teil.bombe') * 6 + 30,
    comment: 'Die Druckwelle ist deine Muttersprache.',
  },
  // ============================================================ Magie
  {
    id: 'kellermagier', name: 'Kellermagier', archetype: 'magie', rarity: 'normal', ability: 'arkanschild',
    skills: ['arkane_kunde', 'wahrnehmung'], spells: ['geschoss', 'fackel'],
    description: 'Hat das Zaubern aus alten Büchern gelernt. Die Bücher waren feucht.',
    bonuses: { stats: { int: 3 }, maxMp: 6 },
    gear: [['kleiner_manatrank', 2]],
    score: (s) => stat(s, 'int') * 2 + (s.player.spells?.length ?? 0) * 10 + st(s, 'zauber.gewirkt') * 2 + flag(s, 'student') * 10 + flag(s, 'it') * 5,
    comment: 'Ein Hut fehlt noch. Die Systemstimme arbeitet daran.',
  },
  {
    id: 'pyromane', name: 'Pyromane', archetype: 'magie', rarity: 'normal', ability: 'brandsatz',
    skills: ['sprengmeister', 'arkane_kunde'], spells: ['fackel'], specials: ['brandstifter', 'feuerfest'],
    description: 'Liebt Feuer. Feuer liebt ihn nicht zurück, aber es verbrennt ihn auch nicht mehr.',
    bonuses: { stats: { int: 2, ges: 1 } },
    gear: [['brandflasche', 2]],
    score: (s) => st(s, 'zustand.brennen') * 5 + st(s, 'kills.teil.feuer') * 6 + st(s, 'hergestellt.brandflasche') * 5 + trait(s, 'feuerwehr') * 15,
    comment: 'Die Feuerwehr hat dich früher gesucht. Jetzt sucht sie dich nicht mehr, weil es keine Feuerwehr mehr gibt.',
  },
  {
    id: 'giftmischer', name: 'Giftmischer', archetype: 'magie', rarity: 'normal', ability: 'giftwolke',
    skills: ['giftfestigkeit', 'handwerk'], spells: ['entgiften'], specials: ['giftklinge', 'giftimmun'],
    description: 'Kennt jedes Gift im Keller und hat die meisten schon probiert.',
    bonuses: { stats: { int: 2, ges: 1 } },
    gear: [['rattengift', 2]],
    score: (s) => st(s, 'zustand.gift') * 5 + Math.floor(s.counters.poisonDamage / 2) + trait(s, 'kammerjaeger_gift') * 25 + trait(s, 'schaedlingsbekaempfer') * 25,
    comment: 'Du riechst leicht nach Mandeln. Das ist kein gutes Zeichen. Für die anderen.',
  },
  {
    id: 'heckenmagier', name: 'Heckenmagier', archetype: 'magie', rarity: 'normal', ability: 'manaflut',
    skills: ['arkane_kunde', 'tierkunde'], spells: ['fackel', 'irrlichtruestung'],
    description: 'Zaubert mit dem, was wächst. Hier unten wächst hauptsächlich Schimmel.',
    bonuses: { stats: { int: 2, cha: 1 }, maxMp: 4 },
    score: (s) => st(s, 'zauber.gewirkt') * 3 + trait(s, 'foerster') * 15 + trait(s, 'gaertner') * 15 + flag(s, 'natur') * 15,
    comment: 'Die Pilze an der Wand flüstern dir Dinge zu. Du hörst zu. Das ist neu.',
  },
  {
    id: 'schattenweber', name: 'Schattenweber', archetype: 'magie', rarity: 'selten', ability: 'rauchbombe',
    skills: ['schleichen', 'arkane_kunde'], spells: ['schattenmantel'],
    description: 'Webt aus Dunkelheit Umhänge und aus Umhängen Hinterhalte.',
    bonuses: { stats: { int: 2, ges: 2 }, ausweichen: 4 },
    requirement: { text: '20 Angriffe auf ahnungslose Gegner', check: (s) => trig(s, 'ambush') >= 20 },
    score: (s) => trig(s, 'ambush') * 2 + 30,
    comment: 'Du bist jetzt offiziell unheimlich. Die Zuschauer finden das großartig.',
  },
  {
    id: 'zeitdieb', name: 'Zeitdieb', archetype: 'magie', rarity: 'selten', ability: 'zeitlupe',
    skills: ['arkane_kunde', 'ausweichen'], spells: ['pfuetzensprung'],
    description: 'Klaut Sekunden. Von Gegnern, die sie ohnehin nicht mehr brauchen werden.',
    bonuses: { stats: { int: 2, ges: 2 }, maxMp: 4 },
    requirement: { text: 'Mindestens 3 Zauber beherrscht', check: (s) => (s.player.spells?.length ?? 0) >= 3 },
    score: (s) => (s.player.spells?.length ?? 0) * 12 + 20,
    comment: 'Die Uhr tickt. Nur für die anderen.',
  },
  // ============================================================ Heimlichkeit
  {
    id: 'assassine', name: 'Kellerassassine', archetype: 'heimlich', rarity: 'normal', ability: 'schattenschritt',
    skills: ['hinterhalt', 'schleichen'],
    description: 'Tötet, bevor man ihn bemerkt.',
    bonuses: { stats: { ges: 3 }, krit: 10 },
    score: (s) => trig(s, 'ambush') * 4 + flag(s, 'feigling') * 10,
    comment: 'Leise, tödlich und etwas zu stolz darauf.',
  },
  {
    id: 'langfinger', name: 'Langfinger', archetype: 'heimlich', rarity: 'normal', ability: 'langfinger',
    skills: ['feilschen', 'schleichen'], specials: ['goldmagnet'],
    description: 'Was nicht festgenagelt ist, gehört dir. Was festgenagelt ist, nach einer Weile auch.',
    bonuses: { stats: { ges: 3, cha: 1 } },
    score: (s) => tagKills(s, ['elster_goblin', 'heinzelmann', 'wechselbalg', 'schmuggler']) * 6 + flag(s, 'handel') * 10 + trait(s, 'zocker') * 10 + Math.floor(s.counters.goldEarned / 60),
    comment: 'Die Systemstimme hat ihre Brieftasche vorsichtshalber weggeschlossen.',
  },
  {
    id: 'fallenbauer', name: 'Fallenbauer', archetype: 'heimlich', rarity: 'normal', ability: 'rauchbombe',
    skills: ['fallenkunde', 'handwerk'], specials: ['fallenmeister'],
    description: 'Lässt den Keller für sich arbeiten. Jeder Gang ist eine Falle, wenn man lange genug nachdenkt.',
    bonuses: { stats: { int: 2, ges: 1 } },
    gear: [['naegel', 3]],
    score: (s) => st(s, 'fallen.aufgestellt') * 6 + s.counters.trapsDisarmed * 4 + s.counters.trapKills * 8 + flag(s, 'planer') * 10,
    comment: 'Wer anderen eine Grube gräbt, ist hier unten einfach gut vorbereitet.',
  },
  {
    id: 'spaeher', name: 'Späher', archetype: 'heimlich', rarity: 'normal', ability: 'schattenschritt',
    skills: ['wahrnehmung', 'schleichen'], specials: ['scharfsichtig'],
    description: 'Sieht alles, bevor es ihn sieht.',
    bonuses: { stats: { ges: 2, int: 1 }, lichtradius: 2 },
    score: (s) => Math.floor(st(s, 'raeume.entdeckt') / 2) + Math.floor(st(s, 'max.erkundet') / 4) + s.counters.trapsFound * 4 + trait(s, 'adleraugen') * 15 + flag(s, 'laeufer') * 10,
    comment: 'Du hast die Karte im Kopf. Und die Fluchtwege auch.',
  },
  // ============================================================ Verteidigung
  {
    id: 'panzerkoloss', name: 'Panzerkoloss', archetype: 'verteidigung', rarity: 'normal', ability: 'bollwerk',
    skills: ['zaehigkeit', 'abwehr'],
    description: 'Steckt alles ein.',
    bonuses: { stats: { kon: 3 }, ruestung: 3, maxHp: 10, ausweichen: -3 },
    score: (s) => Math.floor(s.counters.damageTaken / 10) + flag(s, 'gemuetlich') * 10 + trait(s, 'lastentraeger') * 15,
    comment: 'Du bist keine Person mehr. Du bist eine Wand mit Meinungen.',
  },
  {
    id: 'schaedelmoench', name: 'Schädelmönch', archetype: 'verteidigung', rarity: 'normal', ability: 'meditation',
    skills: ['kopfnuss', 'schmerzresistenz'],
    description: 'Meditiert. Und stößt mit dem Kopf zu.',
    bonuses: { stats: { kon: 2, int: 1 }, schaden: { kopf: 40 } },
    score: (s) => part(s, 'kopf') * 4 + trait(s, 'dickkopf') * 15,
    comment: 'Innere Ruhe, äußere Beule.',
  },
  {
    id: 'kellertaenzer', name: 'Kellertänzer', archetype: 'verteidigung', rarity: 'normal', ability: 'schattenschritt',
    skills: ['ausweichen', 'konter'],
    description: 'Tanzt um jeden Schlag herum.',
    bonuses: { stats: { ges: 3 }, ausweichen: 10 },
    score: (s) => trig(s, 'dodge') * 2 + flag(s, 'laeufer') * 10 + flag(s, 'sportler') * 10,
    comment: 'Cha-cha-cha, Kopfnuss, cha-cha-cha.',
  },
  {
    id: 'konterboxer', name: 'Konterboxer', archetype: 'verteidigung', rarity: 'normal', ability: 'meditation',
    skills: ['konter', 'ausweichen'], specials: ['konterprofi'],
    description: 'Wartet auf den Fehler des Gegners. Der Gegner macht ihn immer.',
    bonuses: { stats: { ges: 2, str: 1 }, ausweichen: 5 },
    score: (s) => st(s, 'kills.konter') * 12 + Math.floor(st(s, 'ausgewichen') / 2) + flag(s, 'kampfsport') * 20,
    comment: 'Du schlägst nie zuerst. Du schlägst nur als Letzter.',
  },
  {
    id: 'muelltonnenritter', name: 'Mülltonnen-Ritter', archetype: 'verteidigung', rarity: 'normal', ability: 'bollwerk',
    skills: ['abwehr', 'zaehigkeit'],
    description: 'Ein Deckel als Schild, eine Tonne als Rüstung, Ehre als Nebensache.',
    bonuses: { stats: { kon: 3, str: 1 }, ruestung: 4, ausweichen: -5 },
    score: (s) => trig(s, 'block') * 3 + Math.floor(st(s, 'schaden.erlitten') / 25),
    comment: 'Scheppernd, stinkend, unaufhaltsam.',
  },
  // ============================================================ Heilung und Versorgung
  {
    id: 'feldsanitaeter', name: 'Feldsanitäter', archetype: 'heilung', rarity: 'normal', ability: 'heilung',
    skills: ['erste_hilfe', 'giftfestigkeit'], spells: ['heilen'],
    description: 'Flickt sich selbst zusammen. Und andere, wenn sie nett fragen.',
    bonuses: { stats: { int: 2, kon: 1 }, hpRegen: 1 },
    gear: [['verband', 3]],
    score: (s) => flag(s, 'heiler') * 25 + s.counters.potionsDrunk * 3 + stat(s, 'int'),
    comment: 'Ein Pflaster für jede Wunde. Du brauchst viele Pflaster.',
  },
  {
    id: 'kampfkoch', name: 'Kampfkoch', archetype: 'heilung', rarity: 'normal', ability: 'heilung',
    skills: ['kochen', 'zaehigkeit'],
    description: 'Kocht, isst, prügelt.',
    bonuses: { stats: { kon: 2, str: 1 }, maxHp: 10 },
    score: (s) => flag(s, 'koch') * 25 + s.counters.mealsEaten * 6 + flag(s, 'gastro') * 10,
    comment: 'Das Monster-Gulasch schmeckt besser, wenn man das Monster selbst erlegt hat.',
  },
  {
    id: 'seelsorger', name: 'Seelsorger', archetype: 'heilung', rarity: 'normal', ability: 'motivationsrede',
    skills: ['erste_hilfe', 'rampenlicht'], spells: ['heilen'],
    description: 'Hält die Truppe zusammen, mit Worten, Tee und gelegentlich einem Tritt.',
    bonuses: { stats: { cha: 3, int: 1 } },
    score: (s) => st(s, 'crawler.geheilt') * 15 + st(s, 'party.beigetreten') * 10 + flag(s, 'sozial') * 20 + trait(s, 'paedagoge') * 15 + trait(s, 'teamplayer') * 10,
    comment: 'Du glaubst an alle hier unten. Die Statistik nicht, aber du schon.',
  },
  {
    id: 'hausapotheker', name: 'Hausapotheker', archetype: 'heilung', rarity: 'normal', ability: 'heilung',
    skills: ['erste_hilfe', 'giftfestigkeit'], specials: ['trankkunde'],
    description: 'Weiß genau, was in welcher Flasche ist. Und wie viel davon man verträgt.',
    bonuses: { stats: { int: 2, kon: 1 } },
    gear: [['kleiner_heiltrank', 2]],
    score: (s) => s.counters.potionsDrunk * 3 + st(s, 'traenke.knapp') * 10 + flag(s, 'heiler') * 15,
    comment: 'Deine Taschen klimpern. Die Monster wissen nicht, ob sie Angst haben sollen.',
  },
  // ============================================================ Show und Handel
  {
    id: 'showstar', name: 'Showstar', archetype: 'show', rarity: 'normal', ability: 'showtime',
    skills: ['rampenlicht', 'feilschen'], specials: ['reichweite'],
    description: 'Lebt für das Publikum.',
    bonuses: { stats: { cha: 3 } },
    score: (s) => stat(s, 'cha') * 2 + flag(s, 'kuenstler') * 20 + Math.floor(s.viewers.follower / 50),
    comment: 'Die Kamera liebt dich. Die Kamera ist das Einzige, was hier unten noch jemanden liebt.',
  },
  {
    id: 'influencer', name: 'Influencer', archetype: 'show', rarity: 'normal', ability: 'blitzlicht',
    skills: ['rampenlicht', 'wahrnehmung'], specials: ['reichweite'],
    description: 'Filmt alles. Auch das, was ihn gerade fressen will.',
    bonuses: { stats: { cha: 3, ges: 1 } },
    score: (s) => trait(s, 'social_media') * 35 + trait(s, 'streamer') * 25 + trait(s, 'handysuechtig') * 15 + flag(s, 'medien') * 15 + Math.floor(s.viewers.follower / 100),
    comment: 'Vergiss nicht, den Kanal zu abonnieren. Die Galaxis tut es schon.',
  },
  {
    id: 'stuntdouble', name: 'Stuntdouble', archetype: 'show', rarity: 'normal', ability: 'erdbeben',
    skills: ['sprungangriff', 'schmerzresistenz'], specials: ['explosionsschutz'],
    description: 'Springt aus Fenstern, die es nicht gibt, und landet auf Gegnern, die es bald nicht mehr gibt.',
    bonuses: { stats: { ges: 2, kon: 2 }, schaden: { alle: 5 } },
    score: (s) => move(s, 'sprung') * 3 + st(s, 'explosion.selbst') * 15 + st(s, 'knapp.ueberlebt') * 5,
    comment: 'Die Versicherung hat abgelehnt. Die Zuschauer haben zugestimmt.',
  },
  {
    id: 'marktschreier', name: 'Marktschreier', archetype: 'show', rarity: 'normal', ability: 'kampfschrei',
    skills: ['feilschen', 'rampenlicht'], specials: ['haendler'],
    description: 'Verkauft Sand in der Wüste und Nägel im Keller.',
    bonuses: { stats: { cha: 2, str: 1 } },
    score: (s) => st(s, 'feilschen.gewonnen') * 6 + st(s, 'gekauft') * 2 + st(s, 'verkauft') + flag(s, 'handel') * 15 + trait(s, 'verhandler') * 20,
    comment: 'Heute im Angebot: dein Überleben. Nur solange der Vorrat reicht.',
  },
  // ============================================================ Handwerk und Technik
  {
    id: 'bombenbastler', name: 'Bombenbastler', archetype: 'handwerk', rarity: 'normal', ability: 'bombe',
    skills: ['sprengmeister', 'handwerk'], specials: ['explosionsschutz'],
    description: 'Wenn es nicht knallt, ist es kein Plan.',
    bonuses: { stats: { int: 3, ges: 1 } },
    gear: [['schwarzpulver', 2]],
    score: (s) => stat(s, 'int') * 2 + flag(s, 'planer') * 20 + (s.counters.killsByDef['blaehkroete'] ?? 0) * 3 + st(s, 'kills.teil.bombe') * 4,
    comment: 'Die Systemstimme bittet darum, nicht im Safe Room zu basteln.',
  },
  {
    id: 'schrottmechaniker', name: 'Schrottmechaniker', archetype: 'handwerk', rarity: 'normal', ability: 'notreparatur',
    skills: ['handwerk', 'reiten'], specials: ['schrauber'],
    description: 'Repariert alles mit Klebeband. Auch Dinge, die vorher gar nicht kaputt waren.',
    bonuses: { stats: { int: 2, str: 1 }, ruestung: 1 },
    gear: [['klebeband', 2], ['benzinkanister', 1]],
    score: (s) => trait(s, 'berufsfahrer') * 20 + Math.floor(st(s, 'reittier.schritte') / 10) + s.counters.crafted * 3 + flag(s, 'technik') * 15,
    comment: 'Wenn es sich bewegt und nicht soll: Klebeband. Wenn es sich nicht bewegt und soll: mehr Klebeband.',
  },
  {
    id: 'systemhacker', name: 'Systemhacker', archetype: 'handwerk', rarity: 'normal', ability: 'zeitlupe',
    skills: ['fallenkunde', 'wahrnehmung'], specials: ['systemkenntnis'],
    description: 'Versteht, wie der Dungeon denkt. Der Dungeon mag das gar nicht.',
    bonuses: { stats: { int: 3 } },
    score: (s) => trait(s, 'hacker') * 35 + flag(s, 'it') * 20 + flag(s, 'gamer') * 15 + stat(s, 'int'),
    comment: 'Du hast den Quellcode nicht gesehen. Aber du ahnst ihn.',
  },
  // ============================================================ Tiere und Reittiere
  {
    id: 'tierfluesterer', name: 'Tierflüsterer', archetype: 'tiere', rarity: 'normal', ability: 'rudelruf',
    skills: ['tierkunde', 'erste_hilfe'],
    description: 'Dein Haustier wird zur Bestie. Haustier +3 Stufen.',
    bonuses: { stats: { cha: 2 } },
    score: (s) => (s.player.pet ? 30 + s.player.pet.level * 5 + trait(s, 'tierarzt') * 15 : -100),
    comment: 'Du sprichst mit Tieren. Die Tiere antworten. Meistens mit „Futter?“.',
  },
  {
    id: 'kellerreiter', name: 'Kellerreiter', archetype: 'tiere', rarity: 'normal', ability: 'erdbeben',
    skills: ['reiten', 'kondition'], specials: ['sattelfest'],
    description: 'Verwachsen mit dem Sattel. Oder dem Einkaufswagen.',
    bonuses: { stats: { ges: 1, cha: 1, kon: 1 } },
    gear: [['benzinkanister', 1]],
    score: (s) => (s.player.mount ? 30 : -100) + Math.floor(st(s, 'reittier.schritte') / 5) + st(s, 'reittier.kills') * 10,
    comment: 'Der Einkaufswagen und du, ihr seid jetzt eins. Die Physik hat Einwände.',
  },
  {
    id: 'schaedlingsbaendiger', name: 'Schädlingsbändiger', archetype: 'tiere', rarity: 'selten', ability: 'kampfschrei',
    skills: ['tierkunde', 'giftfestigkeit'], specials: ['rattenfreund'],
    description: 'Die Ratten kennen dich. Sie haben beschlossen, dich in Ruhe zu lassen.',
    bonuses: { stats: { cha: 2, int: 1 } },
    requirement: { text: '30 Ratten besiegt', check: (s) => tagKills(s, RATS) >= 30 },
    score: (s) => tagKills(s, RATS) * 2 + trait(s, 'schaedlingsbekaempfer') * 25,
    comment: 'Frieden mit den Ratten. Die Ratten haben einen Vertrag aufgesetzt. Er ist sehr lang.',
  },
  // ============================================================ Sonderklassen
  {
    id: 'bestiarius', name: 'Bestiarius', archetype: 'exotisch', rarity: 'selten', ability: 'gnadenstoss',
    skills: ['anatomie', 'wahrnehmung'], specials: ['jaeger'],
    description: 'Kennt jede Art und weiß, wo es wehtut.',
    bonuses: { stats: { str: 1, ges: 1, int: 1 } },
    requirement: { text: '20 verschiedene Monsterarten besiegt', check: (s) => st(s, 'bestiarium.arten') >= 20 },
    score: (s) => st(s, 'bestiarium.arten') * 3 + 20,
    comment: 'Du führst ein Notizbuch über Monster. Die Monster führen eines über dich.',
  },
  {
    id: 'gluecksritter', name: 'Glücksritter', archetype: 'exotisch', rarity: 'selten', ability: 'langfinger',
    skills: ['feilschen', 'ausweichen'], specials: ['goldmagnet'],
    description: 'Setzt immer auf Rot. Auch wenn es kein Rot gibt.',
    bonuses: { stats: { cha: 2, ges: 1 }, krit: 8 },
    gear: [['rubbellos', 3]],
    requirement: {
      text: 'Den Jackpot geknackt, 25 Rubbellose versucht oder als Glückspilz gestartet',
      check: (s) => st(s, 'lose.jackpot') > 0 || st(s, 'lose') >= 25 || trait(s, 'glueckspilz') > 0,
    },
    score: (s) => st(s, 'lose') * 2 + st(s, 'lose.jackpot') * 30 + trait(s, 'glueckspilz') * 20 + 10,
    comment: 'Das Glück ist mit den Tüchtigen. Und mit dir, aus Versehen.',
  },
  {
    id: 'todesveraechter', name: 'Todesverächter', archetype: 'exotisch', rarity: 'legendaer', ability: 'totstellen',
    skills: ['schmerzresistenz', 'zaehigkeit'], specials: ['zaeh'],
    description: 'Der Tod hat es oft versucht. Er hat aufgegeben.',
    bonuses: { stats: { kon: 2, str: 2 }, hpRegen: 1 },
    requirement: { text: '10-mal mit weniger als 10 % Lebenspunkten überlebt', check: (s) => st(s, 'knapp.ueberlebt') >= 10 },
    score: (s) => st(s, 'knapp.ueberlebt') * 4 + 40,
    comment: 'Knapp daneben ist auch vorbei. Das ist jetzt dein Lebensmotto.',
  },
  {
    id: 'apokalypsennudist', name: 'Apokalypsen-Nudist', archetype: 'exotisch', rarity: 'legendaer', ability: 'showtime',
    skills: ['zaehigkeit', 'rampenlicht'], specials: ['nudist', 'reichweite'],
    description: 'Braucht keine Rüstung. Die Rüstung braucht ihn.',
    bonuses: { stats: { ges: 2, kon: 2, cha: 2 } },
    requirement: { text: '10 Gegner ohne jede Ausrüstung besiegt', check: (s) => st(s, 'kills.nackt') >= 10 },
    score: (s) => st(s, 'kills.nackt') * 4 + 40,
    comment: 'Die Zensurabteilung hat gekündigt. Die Einschaltquote hat sich verdreifacht.',
  },
  {
    id: 'wiedergaenger', name: 'Wiedergänger', archetype: 'exotisch', rarity: 'legendaer', ability: 'totstellen',
    skills: ['zaehigkeit', 'giftfestigkeit'], specials: ['blutlos', 'giftimmun'],
    description: 'Einmal gestorben, einmal zurückgekommen. Seitdem ist alles ein bisschen anders.',
    bonuses: { stats: { kon: 3, str: 1 }, maxHp: 5 },
    requirement: { text: 'Die Zweite-Chance-Klausel genutzt', check: (s) => s.achievements.includes('zweite_chance') },
    score: () => 60,
    comment: 'Das Kleingedruckte hat dich gerettet. Jetzt bist du das Kleingedruckte.',
  },
];

export const CLASS_BY_ID: Record<string, ClassDef> = Object.fromEntries(CLASSES.map((c) => [c.id, c]));
