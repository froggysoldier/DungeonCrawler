import type { AttackMove, AttackPart, Bonuses } from '../engine/types';

export type SkillTrigger = 'technique' | 'dodge' | 'hurt' | 'ambush' | 'rest' | 'eat' | 'kill' | 'trap' | 'craft';

export interface SkillDef {
  id: string;
  name: string;
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
  unlockText: string;
}

const UNARMED: AttackPart[] = ['faust', 'tritt', 'knie', 'ellbogen', 'kopf'];

export const SKILLS: SkillDef[] = [
  {
    id: 'faustkampf', name: 'Faustkampf', trigger: 'technique', parts: ['faust'], unlockAt: 15, maxLevel: 15,
    description: '+10 % Faustschaden pro Stufe.', perLevel: {}, matchDamage: 10,
    unlockText: 'Du haust gerne Dinge. Die Systemstimme respektiert das.',
  },
  {
    id: 'treten', name: 'Treten', trigger: 'technique', parts: ['tritt'], unlockAt: 15, maxLevel: 15,
    description: '+10 % Trittschaden und +2 % Umwerf-Chance pro Stufe.', perLevel: {}, matchDamage: 10, knockdown: 2,
    unlockText: 'Dein Fuß und das Gesicht deiner Feinde sind jetzt enge Freunde.',
  },
  {
    id: 'stampfen', name: 'Stampfer', trigger: 'technique', moves: ['stampfen'], unlockAt: 5, maxLevel: 15,
    description: '+15 % Stampfschaden pro Stufe.', perLevel: {}, matchDamage: 15,
    unlockText: 'Wer am Boden liegt, liegt dort nicht lange. Zumindest nicht lebendig.',
  },
  {
    id: 'sprungangriff', name: 'Sprungangriff', trigger: 'technique', moves: ['sprung'], unlockAt: 8, maxLevel: 15,
    description: '+10 % Schaden und +2 % Treffer bei Sprungangriffen pro Stufe.', perLevel: {}, matchDamage: 10, matchTreffer: 2,
    unlockText: 'Die Schwerkraft ist dein Verbündeter. Bis zur Landung.',
  },
  {
    id: 'sturmangriff', name: 'Sturmangriff', trigger: 'technique', moves: ['anlauf'], unlockAt: 8, maxLevel: 15,
    description: '+12 % Schaden bei Angriffen mit Anlauf pro Stufe, +2 % Umwerf-Chance.', perLevel: {}, matchDamage: 12, knockdown: 2,
    unlockText: 'Du rennst auf Dinge zu, die dich töten wollen. Mutig. Oder dumm.',
  },
  {
    id: 'ellbogen', name: 'Ellbogengesellschaft', trigger: 'technique', parts: ['ellbogen'], unlockAt: 10, maxLevel: 15,
    description: '+12 % Ellbogenschaden und +1 % Krit pro Stufe.', perLevel: { krit: 1 }, matchDamage: 12,
    unlockText: 'Spitz, hart und sozial akzeptiert. Zumindest hier unten.',
  },
  {
    id: 'knie', name: 'Kniestoß', trigger: 'technique', parts: ['knie'], unlockAt: 10, maxLevel: 15,
    description: '+12 % Knieschaden pro Stufe.', perLevel: {}, matchDamage: 12,
    unlockText: 'Das Knie: das unterschätzteste Körperteil. Bis heute.',
  },
  {
    id: 'kopfnuss', name: 'Kopfnuss', trigger: 'technique', parts: ['kopf'], unlockAt: 8, maxLevel: 15,
    description: '+15 % Kopfstoßschaden pro Stufe, weniger Selbstverletzung.', perLevel: {}, matchDamage: 15,
    unlockText: 'Du benutzt deinen Kopf. Nur nicht so, wie deine Lehrer es meinten.',
  },
  {
    id: 'werfen', name: 'Werfen', trigger: 'technique', parts: ['wurf'], unlockAt: 10, maxLevel: 15,
    description: '+10 % Wurfschaden und +3 % Treffer pro Stufe.', perLevel: {}, matchDamage: 10, matchTreffer: 3,
    unlockText: 'Steine. Flaschen. Dosen. Alles ist ein Geschoss, wenn man fest genug glaubt.',
  },
  {
    id: 'improvisation', name: 'Improvisierte Waffen', trigger: 'technique', parts: ['waffe'], unlockAt: 12, maxLevel: 15,
    description: '+10 % Waffenschaden pro Stufe.', perLevel: {}, matchDamage: 10,
    unlockText: 'Ein Stuhlbein ist ein Stuhlbein, bis es ein Knüppel ist.',
  },
  {
    id: 'wuchtschlag', name: 'Wuchtschlag', trigger: 'technique', parts: UNARMED, unlockAt: 60, maxLevel: 15,
    description: '+20 % Schaden für alle unbewaffneten Angriffe pro Stufe.', perLevel: {}, matchDamage: 20,
    unlockText: 'Dein ganzer Körper ist jetzt eine Waffe. Das ist weniger sexy, als es klingt.',
  },
  {
    id: 'meteorstampfer', name: 'Meteor-Stampfer', trigger: 'technique', moves: ['sprung'], parts: ['tritt'], unlockAt: 3, maxLevel: 10,
    description: 'Sprungtritte: +20 % Schaden und +3 % Umwerf-Chance pro Stufe.', perLevel: {}, matchDamage: 20, knockdown: 3,
    unlockText: 'Du springst. Du trittst. Du landest auf jemandem. Die Physik weint.',
  },
  {
    id: 'hinterhalt', name: 'Hinterhalt', trigger: 'ambush', unlockAt: 5, maxLevel: 15,
    description: '+25 % Schaden gegen Gegner, die dich nicht bemerkt haben, pro Stufe.', perLevel: {},
    unlockText: 'Ehrlich kämpfen ist was für Leute mit Respawn.',
  },
  {
    id: 'ausweichen', name: 'Ausweichen', trigger: 'dodge', unlockAt: 10, maxLevel: 15,
    description: '+1,5 % Ausweichen pro Stufe.', perLevel: { ausweichen: 1.5 },
    unlockText: 'Nicht getroffen werden ist auch eine Kampftechnik.',
  },
  {
    id: 'zaehigkeit', name: 'Zähigkeit', trigger: 'hurt', unlockAt: 25, maxLevel: 15,
    description: '+3 max. HP pro Stufe.', perLevel: { maxHp: 3 },
    unlockText: 'Du wurdest so oft verprügelt, dass dein Körper beschlossen hat, sich daran zu gewöhnen.',
  },
  {
    id: 'fallenkunde', name: 'Fallenkunde', trigger: 'trap', unlockAt: 3, maxLevel: 15,
    description: 'Fallen leichter entdecken (+6 % pro Stufe), sicherer entschärfen (+8 % pro Stufe), eigene Fallen richten mehr Schaden an.', perLevel: {},
    unlockText: 'Du schaust jetzt auf jede Bodenplatte, als hätte sie dich persönlich beleidigt.',
  },
  {
    id: 'handwerk', name: 'Handwerk', trigger: 'craft', unlockAt: 3, maxLevel: 15,
    description: 'Hergestellte Sprengsätze richten +10 % Schaden pro Stufe an; ab Stufe 3 gelingt manchmal ein Stück extra.', perLevel: {},
    unlockText: 'Klebeband, Nägel, schlechte Ideen. Du hast deine Berufung gefunden.',
  },
  {
    id: 'erste_hilfe', name: 'Erste Hilfe', trigger: 'rest', unlockAt: 9999, maxLevel: 15,
    description: 'Ausruhen heilt 10 % mehr pro Stufe.', perLevel: {},
    unlockText: 'Aus dem alten Leben mitgebracht.',
  },
  {
    id: 'kochen', name: 'Kochen', trigger: 'eat', unlockAt: 9999, maxLevel: 15,
    description: 'Essen heilt 15 % mehr pro Stufe.', perLevel: {},
    unlockText: 'Aus dem alten Leben mitgebracht.',
  },
  {
    id: 'spielerfahrung', name: 'Spielerfahrung', trigger: 'kill', unlockAt: 9999, maxLevel: 15,
    description: '+5 % XP pro Stufe.', perLevel: { xpBonus: 5 },
    unlockText: 'Tausende Stunden vor dem Bildschirm. Endlich zahlt es sich aus.',
  },
];

export const SKILL_BY_ID: Record<string, SkillDef> = Object.fromEntries(SKILLS.map((s) => [s.id, s]));

/** XP, die für die nächste Skill-Stufe benötigt werden. */
export function skillXpNeeded(level: number): number {
  return 6 + level * 6;
}
