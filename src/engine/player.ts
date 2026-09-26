import { CLASS_BY_ID } from '../data/classes';
import { RACE_BY_ID } from '../data/races';
import { SKILL_BY_ID } from '../data/skills';
import { LEVEL_UP_QUIPS } from '../data/world';
import { addBonuses } from './bonuses';
import { traitBonuses } from './traits';
import { emit } from './events';
import { log, toast } from './log';
import * as R from './rng';
import type { Bonuses, GameState, Item, Stats, StatKey } from './types';

export const CURSE_EFFECTS: Record<string, Bonuses> = {
  'Kleingedrucktes': { maxHp: -5, stats: { cha: -1 } },
};

/** Summe aller Boni aus Ausrüstung, Buffs, Skills und Flüchen. */
export function totalBonuses(s: GameState): Bonuses {
  const b: Bonuses = {};
  for (const item of Object.values(s.player.equipment)) if (item) addBonuses(b, item.bonuses);
  for (const buff of s.player.buffs) addBonuses(b, buff.bonuses);
  for (const sk of s.player.skills) addBonuses(b, SKILL_BY_ID[sk.id]?.perLevel, sk.level);
  for (const c of s.player.curses) addBonuses(b, CURSE_EFFECTS[c]);
  if (s.player.race) addBonuses(b, RACE_BY_ID[s.player.race]?.bonuses);
  if (s.player.klass) addBonuses(b, CLASS_BY_ID[s.player.klass]?.bonuses);
  addBonuses(b, traitBonuses(s));
  return b;
}

export function effectiveStats(s: GameState, b = totalBonuses(s)): Stats {
  const out = { ...s.player.stats };
  if (b.stats) for (const [k, v] of Object.entries(b.stats) as [StatKey, number][]) out[k] = Math.max(1, out[k] + v);
  return out;
}

export function maxHp(s: GameState, b = totalBonuses(s)): number {
  const st = effectiveStats(s, b);
  return Math.max(5, s.player.maxHpBase + st.kon * 2 + (s.player.level - 1) * 4 + (b.maxHp ?? 0));
}

export function maxAusdauer(s: GameState, b = totalBonuses(s)): number {
  const st = effectiveStats(s, b);
  return Math.max(4, s.player.maxAusdauerBase + st.ges + Math.floor(st.kon / 2) + (b.maxAusdauer ?? 0));
}

export function ausweichen(s: GameState, b = totalBonuses(s)): number {
  const st = effectiveStats(s, b);
  return Math.max(0, (st.ges - 5) * 1.5 + 5 + (b.ausweichen ?? 0));
}

export function lichtradius(s: GameState, b = totalBonuses(s)): number {
  return 6 + (b.lichtradius ?? 0);
}

export function xpToNext(level: number): number {
  return Math.round(40 * Math.pow(level, 1.5));
}

export function gainXp(s: GameState, amount: number) {
  const b = totalBonuses(s);
  const gained = Math.round(amount * (1 + (b.xpBonus ?? 0) / 100));
  const p = s.player;
  p.xp += gained;
  while (p.xp >= xpToNext(p.level)) {
    p.xp -= xpToNext(p.level);
    p.level += 1;
    p.statPoints += 3;
    p.hp = Math.min(maxHp(s), p.hp + Math.ceil(maxHp(s) / 2));
    log(s, `LEVEL ${p.level}! ${R.pick(s, LEVEL_UP_QUIPS)} (+3 Stat-Punkte)`, 'system');
    toast(s, `Level ${p.level}!`, '+3 Stat-Punkte zum Verteilen.', 'level');
    emit(s, { type: 'levelUp', level: p.level });
  }
  return gained;
}

export function clampVitals(s: GameState) {
  const b = totalBonuses(s);
  s.player.hp = Math.min(s.player.hp, maxHp(s, b));
  s.player.ausdauer = Math.min(s.player.ausdauer, maxAusdauer(s, b));
}

export function skillLevel(s: GameState, id: string): number {
  return s.player.skills.find((k) => k.id === id)?.level ?? 0;
}

export function currentWeapon(s: GameState): Item | null {
  const w = s.player.equipment.waffe;
  if (w) return w;
  if (s.player.hand?.slot === 'waffe') return s.player.hand;
  return null;
}

export function throwables(s: GameState): Item[] {
  const out: Item[] = [];
  if (s.player.hand?.kind === 'wurf') out.push(s.player.hand);
  for (const it of s.player.inventory) if (it.kind === 'wurf') out.push(it);
  // Gewähltes Wurfobjekt zuerst, Sprengsätze sonst zuletzt (damit sie nicht aus Versehen verbraucht werden)
  const pick = s.player.wurfWahl;
  const rank = (i: Item) => (pick && i.baseId === pick ? 0 : i.explosion ? 2 : 1);
  return out.sort((a, b) => rank(a) - rank(b));
}
