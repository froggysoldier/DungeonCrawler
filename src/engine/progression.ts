import type { GameState, Monster } from './types';

/**
 * Fortschritt: Wie viel Erfahrung ein Kill bringt und wie viel man für die
 * nächste Stufe braucht.
 *
 * Grundidee: Erfahrung hängt vom Stufenabstand ab. Wer auf viel schwächere
 * Gegner einprügelt, lernt kaum noch etwas; wer sich an Stärkere wagt, lernt
 * schnell. Auf den ersten Etagen gibt es fast nur schwache Gegner – man
 * steigt langsam auf. Tiefer unten sind die Gegner stärker und die Stufen
 * kommen schneller, obwohl die Kurve steiler wird.
 *
 * Zielwerte für gründliche Crawler: Ende Etage 1 etwa Stufe 5,
 * Ende Etage 2 etwa Stufe 7–8, Ende Etage 3 etwa Stufe 10–12.
 */

export const XP_BASE = 60;
export const XP_EXPONENT = 1.75;

/** Erfahrung, die für den Aufstieg von `level` auf `level + 1` nötig ist. */
export function xpToNext(level: number): number {
  return Math.round(XP_BASE * Math.pow(level, XP_EXPONENT));
}

/** Gesamterfahrung, die man bis zum Erreichen einer Stufe gesammelt hat. */
export function totalXpFor(level: number): number {
  let sum = 0;
  for (let l = 1; l < level; l++) sum += xpToNext(l);
  return sum;
}

export type Challenge = 'trivial' | 'leicht' | 'passend' | 'fordernd' | 'gefaehrlich' | 'toedlich';

export const CHALLENGES: Record<Challenge, { name: string; color: string; hint: string }> = {
  trivial: { name: 'harmlos', color: '#8f8a82', hint: 'kaum Erfahrung' },
  leicht: { name: 'leicht', color: '#6ee07a', hint: 'wenig Erfahrung' },
  passend: { name: 'ebenbürtig', color: '#f0e2a8', hint: 'normale Erfahrung' },
  fordernd: { name: 'fordernd', color: '#ffb04a', hint: 'viel Erfahrung' },
  gefaehrlich: { name: 'gefährlich', color: '#ff5a4a', hint: 'sehr viel Erfahrung' },
  toedlich: { name: 'tödlich', color: '#d070ff', hint: 'enorm viel Erfahrung' },
};

export function challengeOf(diff: number): Challenge {
  if (diff <= -5) return 'trivial';
  if (diff <= -2) return 'leicht';
  if (diff <= 1) return 'passend';
  if (diff <= 3) return 'fordernd';
  if (diff <= 5) return 'gefaehrlich';
  return 'toedlich';
}

/** Erfahrungsfaktor je Stufenabstand (Gegnerstufe minus eigene Stufe). */
export function levelDiffFactor(diff: number): number {
  const table: Record<number, number> = {
    [-5]: 0.1, [-4]: 0.2, [-3]: 0.35, [-2]: 0.55, [-1]: 0.8, 0: 1, 1: 1.15, 2: 1.3, 3: 1.5, 4: 1.7, 5: 1.85,
  };
  if (diff <= -6) return 0.05;
  if (diff >= 6) return 2;
  return table[diff];
}

/** Erfahrung für einen Kill (vor Boni wie Rasse oder Eigenschaften). */
export function killXp(s: GameState, m: Monster): { xp: number; diff: number; challenge: Challenge } {
  const diff = m.level - s.player.level;
  return { xp: Math.max(1, Math.round(m.xp * levelDiffFactor(diff))), diff, challenge: challengeOf(diff) };
}

/**
 * Trefferanpassung durch den Stufenabstand (in Prozentpunkten), aus Sicht
 * des Angreifers: Viel stärkere Gegner sind schwerer zu treffen.
 */
export function levelGapHit(attackerLevel: number, defenderLevel: number): number {
  const d = defenderLevel - attackerLevel;
  if (d > 2) return -Math.min(20, (d - 2) * 3);
  if (d < -2) return Math.min(10, (-d - 2) * 2);
  return 0;
}
