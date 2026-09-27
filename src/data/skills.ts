import type { AttackMove, AttackPart, Bonuses } from '../engine/types';

/**
 * Skills wachsen durch Tun. Jeder Skill hat einen Auslöser (was man tun
 * muss), eine Freischaltschwelle, bis zu 15 Stufen und eine klar benannte
 * Wirkung pro Stufe. Kampf-Skills lernen nur wenig an viel schwächeren
 * Gegnern – Rattenklatschen macht niemanden zum Meister.
 */
export type SkillTrigger =
  | 'technique' | 'dodge' | 'hurt' | 'ambush' | 'rest' | 'eat' | 'kill' | 'trap' | 'craft'
  | 'sneak' | 'perceive' | 'zone' | 'block' | 'counter' | 'haggle' | 'pet' | 'ride' | 'poison'
  | 'bighit' | 'stamina' | 'cast' | 'heal' | 'explode' | 'struggle' | 'show';

export type SkillCategory = 'kampf' | 'verteidigung' | 'bewegung' | 'ueberleben' | 'handwerk' | 'sozial' | 'magie';

export const SKILL_CATEGORY_NAMES: Record<SkillCategory, string> = {
  kampf: 'Kampf', verteidigung: 'Verteidigung', bewegung: 'Bewegung und Heimlichkeit', ueberleben: 'Überleben',
  handwerk: 'Handwerk', sozial: 'Umgang und Show', magie: 'Magie',
};

export interface SkillDef {
  id: string;
  name: string;
  category: SkillCategory;
  description: string;
  trigger: SkillTrigger;
  /** Für trigger 'technique': welche Angriffe zählen. */
  parts?: AttackPart[];
  moves?: AttackMove[];
  /** Anzahl passender Aktionen, bis der Skill freigeschaltet wird. */
  unlockAt: number;
  maxLevel: number;
  /** Boni pro Skill-Level (werden mit dem Level multipliziert). */
  perLevel: Bonuses;
  /** Zusätzlicher Schadensbonus in % pro Level, gilt nur für passende Angriffe. */
  matchDamage?: number;
  /** Zusätzlicher Trefferbonus pro Level für passende Angriffe. */
  matchTreffer?: number;
  /** Chance (in %) pro Level, das Ziel umzuwerfen. */
  knockdown?: number;
  /** Wirkung auf einer bestimmten Stufe, als Klartext (für die Anzeige). */
  effect?: (level: number) => string;
  unlockText: string;
}

const UNARMED: AttackPart[] = ['faust', 'tritt', 'knie', 'ellbogen', 'kopf'];
const pct = (n: number) => `${Math.round(n * 10) / 10} %`.replace('.', ',');

export const SKILLS: SkillDef[] = [
  // ------------------------------------------------------------ Kampf
  {
    id: 'faustkampf', name: 'Faustkampf', category: 'kampf', trigger: 'technique', parts: ['faust'], unlockAt: 15, maxLevel: 15,
    description: '+10 % Faustschaden pro Stufe.', perLevel: {}, matchDamage: 10,
    unlockText: 'Du haust gerne Dinge. Die Systemstimme respektiert das.',
  },
  {
    id: 'treten', name: 'Treten', category: 'kampf', trigger: 'technique', parts: ['tritt'], unlockAt: 15, maxLevel: 15,
    description: '+10 % Trittschaden und +2 % Umwerf-Chance pro Stufe.', perLevel: {}, matchDamage: 10, knockdown: 2,
    unlockText: 'Dein Fuß und das Gesicht deiner Feinde sind jetzt enge Freunde.',
  },
  {
    id: 'stampfen', name: 'Stampfer', category: 'kampf', trigger: 'technique', moves: ['stampfen'], unlockAt: 5, maxLevel: 15,
    description: '+15 % Stampfschaden pro Stufe.', perLevel: {}, matchDamage: 15,
    unlockText: 'Wer am Boden liegt, liegt dort nicht lange. Zumindest nicht lebendig.',
  },
  {
    id: 'sprungangriff', name: 'Sprungangriff', category: 'kampf', trigger: 'technique', moves: ['sprung'], unlockAt: 8, maxLevel: 15,
    description: '+10 % Schaden und +2 % Treffer bei Sprungangriffen pro Stufe.', perLevel: {}, matchDamage: 10, matchTreffer: 2,
    unlockText: 'Die Schwerkraft ist dein Verbündeter. Bis zur Landung.',
  },
  {
    id: 'sturmangriff', name: 'Sturmangriff', category: 'kampf', trigger: 'technique', moves: ['anlauf'], unlockAt: 8, maxLevel: 15,
    description: '+12 % Schaden bei Angriffen mit Anlauf pro Stufe, +2 % Umwerf-Chance.', perLevel: {}, matchDamage: 12, knockdown: 2,
    unlockText: 'Du rennst auf Dinge zu, die dich töten wollen. Mutig. Oder dumm.',
  },
  {
    id: 'ellbogen', name: 'Ellbogengesellschaft', category: 'kampf', trigger: 'technique', parts: ['ellbogen'], unlockAt: 10, maxLevel: 15,
    description: '+12 % Ellbogenschaden und +1 % Krit pro Stufe.', perLevel: { krit: 1 }, matchDamage: 12,
    unlockText: 'Spitz, hart und sozial akzeptiert. Zumindest hier unten.',
  },
  {
    id: 'knie', name: 'Kniestoß', category: 'kampf', trigger: 'technique', parts: ['knie'], unlockAt: 10, maxLevel: 15,
    description: '+12 % Knieschaden pro Stufe.', perLevel: {}, matchDamage: 12,
    unlockText: 'Das Knie: das unterschätzteste Körperteil. Bis heute.',
  },
  {
    id: 'kopfnuss', name: 'Kopfnuss', category: 'kampf', trigger: 'technique', parts: ['kopf'], unlockAt: 8, maxLevel: 15,
    description: '+15 % Kopfstoßschaden pro Stufe, weniger Selbstverletzung.', perLevel: {}, matchDamage: 15,
    unlockText: 'Du benutzt deinen Kopf. Nur nicht so, wie deine Lehrer es meinten.',
  },
  {
    id: 'werfen', name: 'Werfen', category: 'kampf', trigger: 'technique', parts: ['wurf'], unlockAt: 10, maxLevel: 15,
    description: '+10 % Wurfschaden und +3 % Treffer pro Stufe.', perLevel: {}, matchDamage: 10, matchTreffer: 3,
    unlockText: 'Steine. Flaschen. Dosen. Alles ist ein Geschoss, wenn man fest genug glaubt.',
  },
  {
    id: 'improvisation', name: 'Improvisierte Waffen', category: 'kampf', trigger: 'technique', parts: ['waffe'], unlockAt: 12, maxLevel: 15,
    description: '+10 % Waffenschaden pro Stufe.', perLevel: {}, matchDamage: 10,
    unlockText: 'Ein Stuhlbein ist ein Stuhlbein, bis es ein Knüppel ist.',
  },
  {
    id: 'wuchtschlag', name: 'Wuchtschlag', category: 'kampf', trigger: 'technique', parts: UNARMED, unlockAt: 60, maxLevel: 15,
    description: '+20 % Schaden für alle unbewaffneten Angriffe pro Stufe.', perLevel: {}, matchDamage: 20,
    unlockText: 'Dein ganzer Körper ist jetzt eine Waffe. Das ist weniger sexy, als es klingt.',
  },
  {
    id: 'meteorstampfer', name: 'Meteor-Stampfer', category: 'kampf', trigger: 'technique', moves: ['sprung'], parts: ['tritt'], unlockAt: 3, maxLevel: 10,
    description: 'Sprungtritte: +20 % Schaden und +3 % Umwerf-Chance pro Stufe.', perLevel: {}, matchDamage: 20, knockdown: 3,
    unlockText: 'Du springst. Du trittst. Du landest auf jemandem. Die Physik weint.',
  },
  {
    id: 'hinterhalt', name: 'Hinterhalt', category: 'kampf', trigger: 'ambush', unlockAt: 5, maxLevel: 15,
    description: '+25 % Schaden gegen Gegner, die dich nicht bemerkt haben, pro Stufe.', perLevel: {},
    effect: (l) => `+${25 * l} % Schaden gegen ahnungslose Gegner`,
    unlockText: 'Ehrlich kämpfen ist was für Leute mit Respawn.',
  },
  {
    id: 'anatomie', name: 'Anatomie', category: 'kampf', trigger: 'zone', unlockAt: 12, maxLevel: 15,
    description: 'Gezielte Treffer: pro Stufe +2 % Treffer auf Kopf, Arme und Beine und +2 % Chance auf ihre Wirkung (benommen, geschwächt, humpelt).', perLevel: {},
    effect: (l) => `+${2 * l} % Treffer auf Kopf, Arme, Beine · +${2 * l} % Zonenwirkung`,
    unlockText: 'Du weißt jetzt, wo es wehtut. Genau da, wo du hinhaust.',
  },
  {
    id: 'sprengmeister', name: 'Sprengmeister', category: 'kampf', trigger: 'explode', unlockAt: 5, maxLevel: 15,
    description: 'Explosionen: +8 % Schaden pro Stufe, eigener Explosionsschaden −5 % pro Stufe.', perLevel: {},
    effect: (l) => `+${8 * l} % Explosionsschaden · −${Math.min(75, 5 * l)} % Schaden an dir selbst`,
    unlockText: 'Du hast aufgehört, dich beim Knall zu ducken. Das ist entweder Erfahrung oder Taubheit.',
  },
  // ------------------------------------------------------------ Verteidigung
  {
    id: 'ausweichen', name: 'Ausweichen', category: 'verteidigung', trigger: 'dodge', unlockAt: 10, maxLevel: 15,
    description: '+1,5 % Ausweichen pro Stufe.', perLevel: { ausweichen: 1.5 },
    unlockText: 'Nicht getroffen werden ist auch eine Kampftechnik.',
  },
  {
    id: 'abwehr', name: 'Abwehr', category: 'verteidigung', trigger: 'block', unlockAt: 6, maxLevel: 15,
    description: 'Deckung wird besser: pro Stufe +2 % Ausweichen in Deckung, alle drei Stufen +1 Rüstung in Deckung.', perLevel: {},
    effect: (l) => `Deckung: +${20 + 2 * l} % Ausweichen, +${2 + Math.floor(l / 3)} Rüstung`,
    unlockText: 'Arme hoch, Kinn runter. Die Grundlagen, endlich.',
  },
  {
    id: 'konter', name: 'Konter', category: 'verteidigung', trigger: 'counter', unlockAt: 20, maxLevel: 15,
    description: 'Nach einem ausgewichenen Nahkampfangriff +3 % Chance pro Stufe auf einen sofortigen Gegenschlag.', perLevel: {},
    effect: (l) => `${3 * l} % Chance auf einen Gegenschlag nach dem Ausweichen`,
    unlockText: 'Er verfehlt. Du nicht. So einfach ist das.',
  },
  {
    id: 'zaehigkeit', name: 'Zähigkeit', category: 'verteidigung', trigger: 'hurt', unlockAt: 25, maxLevel: 15,
    description: '+3 max. HP pro Stufe.', perLevel: { maxHp: 3 },
    unlockText: 'Du wurdest so oft verprügelt, dass dein Körper beschlossen hat, sich daran zu gewöhnen.',
  },
  {
    id: 'schmerzresistenz', name: 'Schmerzresistenz', category: 'verteidigung', trigger: 'bighit', unlockAt: 8, maxLevel: 15,
    description: 'Nach schweren Treffern gelernt: −1,5 % Schaden durch Monster pro Stufe.', perLevel: {},
    effect: (l) => `−${pct(1.5 * l)} Schaden durch Monsterangriffe`,
    unlockText: 'Der Schmerz ist noch da. Er ist dir nur egal geworden.',
  },
  {
    id: 'giftfestigkeit', name: 'Giftfestigkeit', category: 'verteidigung', trigger: 'poison', unlockAt: 15, maxLevel: 15,
    description: '−6 % Giftschaden pro Stufe.', perLevel: {},
    effect: (l) => `−${Math.min(90, 6 * l)} % Giftschaden`,
    unlockText: 'Dein Körper hat so viel Gift gesehen, dass er es inzwischen höflich ignoriert.',
  },
  // ------------------------------------------------------------ Bewegung und Heimlichkeit
  {
    id: 'schleichen', name: 'Schleichen', category: 'bewegung', trigger: 'sneak', unlockAt: 8, maxLevel: 15,
    description: 'Monster bemerken dich später: Pro Stufe −4 % Entdeckungschance, alle vier Stufen −1 Sichtweite der Monster; Schlafende wachen seltener auf.', perLevel: {},
    effect: (l) => `−${4 * l} % Entdeckungschance · −${Math.floor(l / 4)} Sichtweite der Monster`,
    unlockText: 'Leise Sohlen, flacher Atem. Die Monster merken nichts. Die Zuschauer schon.',
  },
  {
    id: 'wahrnehmung', name: 'Wahrnehmung', category: 'bewegung', trigger: 'perceive', unlockAt: 10, maxLevel: 15,
    description: 'Pro Stufe +3 % Fallen entdecken; alle fünf Stufen +1 Sichtweite; ab Stufe 8 erkennst du Monster besser.', perLevel: { lichtradius: 0.2 },
    effect: (l) => `+${3 * l} % Fallen entdecken · +${Math.floor(l / 5)} Sichtweite${l >= 8 ? ' · bessere Einschätzung von Monstern' : ''}`,
    unlockText: 'Du siehst Dinge. Nicht auf die gruselige Art. Meistens.',
  },
  {
    id: 'kondition', name: 'Kondition', category: 'bewegung', trigger: 'stamina', unlockAt: 25, maxLevel: 15,
    description: '+1 max. Ausdauer pro Stufe; ab Stufe 5 und 10 erholt sich die Ausdauer schneller.', perLevel: { maxAusdauer: 1 },
    effect: (l) => `+${l} max. Ausdauer${l >= 5 ? ` · +${Math.floor(l / 5)} Ausdauer pro Zug` : ''}`,
    unlockText: 'Du schnaufst nicht mehr nach drei Schlägen. Erst nach fünf.',
  },
  {
    id: 'reiten', name: 'Reiten', category: 'bewegung', trigger: 'ride', unlockAt: 60, maxLevel: 15,
    description: 'Pro Stufe: Reittier nimmt −4 % Schaden, Rammen +8 % Schaden, 5 % Chance, kein Benzin zu verbrauchen.', perLevel: {},
    effect: (l) => `Reittier −${Math.min(60, 4 * l)} % Schaden · Rammen +${8 * l} % · ${5 * l} % Benzin gespart`,
    unlockText: 'Du sitzt nicht mehr drauf wie ein Sack Kartoffeln. Eher wie ein Sack Kartoffeln mit Selbstvertrauen.',
  },
  {
    id: 'entfesseln', name: 'Entfesseln', category: 'bewegung', trigger: 'struggle', unlockAt: 4, maxLevel: 10,
    description: '+8 % Chance pro Stufe, dich aus Fallen und Griffen zu befreien.', perLevel: {},
    effect: (l) => `+${8 * l} % Chance, dich loszureißen`,
    unlockText: 'Bärenfallen, Gruben, Schlingen. Du kennst sie alle von innen.',
  },
  // ------------------------------------------------------------ Überleben
  {
    id: 'erste_hilfe', name: 'Erste Hilfe', category: 'ueberleben', trigger: 'heal', unlockAt: 8, maxLevel: 15,
    description: 'Heilgegenstände wirken +8 % stärker pro Stufe, Schlafen heilt +10 % mehr pro Stufe.', perLevel: {},
    effect: (l) => `Heilgegenstände +${8 * l} % · Schlaf +${10 * l} %`,
    unlockText: 'Du weißt jetzt, wo das Pflaster hin muss. Meistens da, wo es blutet.',
  },
  {
    id: 'kochen', name: 'Kochen', category: 'ueberleben', trigger: 'eat', unlockAt: 12, maxLevel: 15,
    description: 'Essen heilt 15 % mehr pro Stufe.', perLevel: {},
    effect: (l) => `Essen heilt +${15 * l} %`,
    unlockText: 'Du isst so oft Dosenfutter, dass du jetzt weißt, wie man es gut macht.',
  },
  {
    id: 'fallenkunde', name: 'Fallenkunde', category: 'ueberleben', trigger: 'trap', unlockAt: 3, maxLevel: 15,
    description: 'Fallen leichter entdecken (+6 % pro Stufe), sicherer entschärfen (+8 % pro Stufe), eigene Fallen richten mehr Schaden an.', perLevel: {},
    effect: (l) => `+${6 * l} % Entdecken · +${8 * l} % Entschärfen · +${2 * l} Fallenschaden`,
    unlockText: 'Du schaust jetzt auf jede Bodenplatte, als hätte sie dich persönlich beleidigt.',
  },
  {
    id: 'spielerfahrung', name: 'Spielerfahrung', category: 'ueberleben', trigger: 'kill', unlockAt: 9999, maxLevel: 15,
    description: '+5 % XP pro Stufe.', perLevel: { xpBonus: 5 },
    unlockText: 'Tausende Stunden vor dem Bildschirm. Endlich zahlt es sich aus.',
  },
  // ------------------------------------------------------------ Handwerk
  {
    id: 'handwerk', name: 'Handwerk', category: 'handwerk', trigger: 'craft', unlockAt: 3, maxLevel: 15,
    description: 'Hergestellte Sprengsätze richten +10 % Schaden pro Stufe an; ab Stufe 3 gelingt manchmal ein Stück extra.', perLevel: {},
    effect: (l) => `Sprengsätze +${10 * l} %${l >= 3 ? ` · ${10 + 2 * l} % Chance auf ein Stück extra` : ''}`,
    unlockText: 'Klebeband, Nägel, schlechte Ideen. Du hast deine Berufung gefunden.',
  },
  // ------------------------------------------------------------ Umgang und Show
  {
    id: 'feilschen', name: 'Feilschen', category: 'sozial', trigger: 'haggle', unlockAt: 3, maxLevel: 15,
    description: 'Pro Stufe +4 % Chance beim Verhandeln, +1 % möglicher Rabatt, +2 % Verkaufspreis.', perLevel: {},
    effect: (l) => `+${4 * l} % Verhandlungschance · bis ${25 + l} % Rabatt · +${2 * l} % beim Verkaufen`,
    unlockText: 'Du hast gelernt, dass „Das ist mein letztes Angebot“ nie das letzte Angebot ist.',
  },
  {
    id: 'tierkunde', name: 'Tierkunde', category: 'sozial', trigger: 'pet', unlockAt: 8, maxLevel: 15,
    description: 'Pro Stufe: Haustier +6 % Schaden, +3 % Chance beim Zähmen.', perLevel: {},
    effect: (l) => `Haustier +${6 * l} % Schaden · +${3 * l} % Zähmen`,
    unlockText: 'Du verstehst Tiere. Sie verstehen dich. Keiner von euch versteht die Monster.',
  },
  {
    id: 'rampenlicht', name: 'Rampenlicht', category: 'sozial', trigger: 'show', unlockAt: 15, maxLevel: 15,
    description: '+5 % Follower-Zuwachs pro Stufe.', perLevel: {},
    effect: (l) => `+${5 * l} % Follower`,
    unlockText: 'Du spürst, wo die Kamera ist. Immer. Es ist ein bisschen unheimlich.',
  },
  // ------------------------------------------------------------ Magie
  {
    id: 'arkane_kunde', name: 'Arkane Kunde', category: 'magie', trigger: 'cast', unlockAt: 10, maxLevel: 15,
    description: 'Pro Stufe +1 max. Mana und +4 % Zauberwirkung; ab Stufe 5 und 10 regeneriert Mana schneller.', perLevel: { maxMp: 1 },
    effect: (l) => `+${l} max. Mana · +${4 * l} % Zauberwirkung${l >= 5 ? ` · schnellere Mana-Erholung` : ''}`,
    unlockText: 'Die Magie kribbelt nicht mehr in den Fingern. Sie gehorcht.',
  },
];

export const SKILL_BY_ID: Record<string, SkillDef> = Object.fromEntries(SKILLS.map((s) => [s.id, s]));

/**
 * XP, die für die nächste Skill-Stufe benötigt werden. Steigt linear, damit
 * die ersten Stufen schnell kommen und Meisterschaft Zeit braucht.
 */
export function skillXpNeeded(level: number): number {
  return 25 + level * 20;
}
