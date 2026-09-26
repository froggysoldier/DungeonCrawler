import { TRAIT_BY_ID } from '../data/traits';
import { addBonuses } from './bonuses';
import { log, toast } from './log';
import type { Bonuses, GameEvent, GameState } from './types';

/** Eigenschaften aus dem Vorleben: dauerhafte Boni. */
export function traitBonuses(s: GameState): Bonuses {
  const b: Bonuses = {};
  for (const id of s.player.traits ?? []) addBonuses(b, TRAIT_BY_ID[id]?.bonuses);
  return b;
}

/** Situative Boni (Ängste, Erfahrung) für einen konkreten Angriff. */
export function traitAttackBonus(s: GameState, facets: string[]): { hit: number; dmg: number } {
  let hit = 0;
  let dmg = 0;
  for (const id of s.player.traits ?? []) {
    for (const v of TRAIT_BY_ID[id]?.vs ?? []) {
      if (!facets.includes(v.facet)) continue;
      hit += v.hit ?? 0;
      dmg += v.dmg ?? 0;
    }
  }
  return { hit, dmg };
}

export function traitSpecial(s: GameState, special: string): boolean {
  return (s.player.traits ?? []).some((id) => TRAIT_BY_ID[id]?.special === special);
}

export function traitFollowerMult(s: GameState): number {
  return (s.player.traits ?? []).reduce((m, id) => m * (TRAIT_BY_ID[id]?.followerMult ?? 1), 1);
}

/** Prüft nach Kämpfen, ob eine Angst überwunden wurde. */
export function traitsOnEvent(s: GameState, e: GameEvent) {
  if (e.type !== 'kill' && e.type !== 'attack') return;
  const p = s.player;
  for (const id of [...(p.traits ?? [])]) {
    const t = TRAIT_BY_ID[id];
    if (!t?.overcome || !t.overcome.check(s)) continue;
    const next = TRAIT_BY_ID[t.overcome.becomes];
    p.traits = (p.traits ?? []).filter((x) => x !== id).concat(next.id);
    log(s, `ÜBERWUNDEN: ${t.name}. Neue Eigenschaft: ${next.name}. ${t.overcome.text}`, 'system');
    toast(s, `Überwunden: ${t.name}`, `Neu: ${next.name}`, 'skill');
  }
}
