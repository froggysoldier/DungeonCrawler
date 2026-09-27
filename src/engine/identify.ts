import { RARITY_NAMES, SLOT_NAMES } from '../data/items';
import { ABILITY_NAMES, hasSpecial } from './abilities';
import { describeBonuses } from './bonuses';
import { effectiveStats, maxHp } from './player';
import { CHALLENGES, challengeOf } from './progression';
import type { GameState, Item, Monster, MonsterSize, Rarity } from './types';

/**
 * Identifikation: Was man über ein Monster oder einen Gegenstand erfährt,
 * hängt davon ab, wie weit es über dem eigenen Level liegt. Intelligenz und
 * Erfahrung mit einem Monstertyp verschieben die Grenze nach oben.
 *
 * Erkenntnisstufen: 0 = alles, 1 = gut, 2 = grob, 3 = kaum, 4 = nichts.
 */
export type Insight = 0 | 1 | 2 | 3 | 4;

export const INSIGHT_NAMES: Record<Insight, string> = {
  0: 'Vollständig identifiziert',
  1: 'Gut eingeschätzt',
  2: 'Grob eingeschätzt',
  3: 'Kaum einzuschätzen',
  4: 'Nicht einzuschätzen',
};

/** Bonus durch Intelligenz: je 3 Punkte über 5 eine Stufe mehr. */
export function intelligenceBonus(s: GameState): number {
  // Wahrnehmung ab Stufe 8 hilft zusätzlich beim Einschätzen
  const perception = (s.player.skills.find((k) => k.id === 'wahrnehmung')?.level ?? 0) >= 8 ? 1 : 0;
  const system = hasSpecial(s, 'systemkenntnis') ? 2 : 0;
  return Math.max(0, Math.floor((effectiveStats(s).int - 5) / 3)) + perception + system;
}

/** Bonus durch Erfahrung: je 3 besiegte Exemplare dieses Typs eine Stufe (max. 2). */
export function experienceBonus(s: GameState, defId: string): number {
  return Math.min(2, Math.floor((s.counters.killsByDef[defId] ?? 0) / 3));
}

function insightFromGap(gap: number): Insight {
  if (gap <= 0) return 0;
  if (gap <= 2) return 1;
  if (gap <= 4) return 2;
  if (gap <= 7) return 3;
  return 4;
}

export function monsterInsight(s: GameState, m: Monster): Insight {
  const gap = m.level - s.player.level - intelligenceBonus(s) - experienceBonus(s, m.defId);
  return insightFromGap(gap);
}

const SIZE_WORDS: Record<MonsterSize, string> = {
  winzig: 'winziges', klein: 'kleines', mittel: 'mittelgroßes', gross: 'großes', riesig: 'riesiges',
};

/** Der Name, den der Crawler für dieses Monster kennt. */
export function nameOf(s: GameState, m: Monster): string {
  const insight = monsterInsight(s, m);
  if (insight <= 2) return m.name;
  if (insight === 4) return 'etwas sehr Gefährliches';
  const boss = m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss';
  return boss ? `ein unbekannter Boss` : `ein unbekanntes ${SIZE_WORDS[m.size]} Wesen`;
}

const SIZE_DAT: Record<MonsterSize, string> = {
  winzig: 'winzigen', klein: 'kleinen', mittel: 'mittelgroßen', gross: 'großen', riesig: 'riesigen',
};

/** Name im Dativ, z. B. nach „von“: „einem unbekannten großen Wesen“. */
export function nameOfDat(s: GameState, m: Monster): string {
  const insight = monsterInsight(s, m);
  if (insight <= 2) return m.name;
  if (insight === 4) return 'etwas sehr Gefährlichem';
  const boss = m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss';
  return boss ? 'einem unbekannten Boss' : `einem unbekannten ${SIZE_DAT[m.size]} Wesen`;
}

/** Name am Satzanfang (großgeschrieben). */
export function NameOf(s: GameState, m: Monster): string {
  const n = nameOf(s, m);
  return n.charAt(0).toUpperCase() + n.slice(1);
}

export function conditionWord(hp: number, max: number): string {
  const r = hp / max;
  if (r >= 1) return 'unverletzt';
  if (r > 0.75) return 'leicht verletzt';
  if (r > 0.45) return 'verletzt';
  if (r > 0.2) return 'schwer verletzt';
  return 'fast tot';
}

function threatWord(s: GameState, m: Monster): string {
  const avg = (m.dmg[0] + m.dmg[1]) / 2;
  const r = avg / maxHp(s);
  if (r < 0.08) return 'gering';
  if (r < 0.15) return 'mittel';
  if (r < 0.25) return 'hoch';
  return 'sehr hoch';
}

export interface MonsterInfo {
  insight: Insight;
  name: string;
  rank: string | null;
  level: string;
  health: string;
  combat: string | null;
  abilities: string | null;
  flavor: string | null;
  showHitChance: boolean;
  showHealthBar: boolean;
  /** Herausforderung im Verhältnis zur eigenen Stufe (Farbe und Erfahrungshinweis). */
  challenge: { name: string; color: string; hint: string };
}

export function describeMonster(s: GameState, m: Monster): MonsterInfo {
  const insight = monsterInsight(s, m);
  const boss = m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss';
  const rank = m.rank === 'elite' ? 'Elite' : m.rank === 'geist' ? 'Geist' : boss ? 'Boss' : null;
  const level =
    insight <= 1 ? `Level ${m.level}` : insight === 2 ? `Level ${m.level - 1} bis ${m.level + 1}` : insight === 3 ? 'Level deutlich über deinem' : 'Level weit über deinem';
  const health =
    insight <= 1 ? `HP ${Math.max(0, m.hp)} von ${m.maxHp} (${conditionWord(m.hp, m.maxHp)})` : insight <= 3 ? `Zustand: ${conditionWord(m.hp, m.maxHp)}` : 'Zustand: unbekannt';
  const combat =
    insight === 0
      ? `Schaden ${m.dmg[0]} bis ${m.dmg[1]}, Rüstung ${m.ruestung}, Ausweichen ${m.ausweichen} %`
      : insight === 1
        ? `Gefahr: ${threatWord(s, m)}`
        : null;
  const count = m.abilities?.length ?? 0;
  const abilities =
    count === 0
      ? insight <= 1 ? 'Keine besonderen Fähigkeiten' : null
      : insight <= 1
        ? `Fähigkeiten: ${m.abilities!.map((a) => ABILITY_NAMES[a]).join(', ')}`
        : insight === 2
          ? `Hat ${count === 1 ? 'eine besondere Fähigkeit' : `${count} besondere Fähigkeiten`}`
          : null;
  return {
    insight,
    name: insight <= 2 ? m.name : NameOf(s, m),
    rank: insight <= 3 ? rank : null,
    level,
    health,
    combat,
    abilities,
    flavor: insight <= 2 ? m.flavor : null,
    showHitChance: insight <= 2,
    showHealthBar: insight <= 3,
    challenge: insight <= 2
      ? CHALLENGES[challengeOf(m.level - s.player.level)]
      : { name: 'gefährlich oder schlimmer', color: CHALLENGES.gefaehrlich.color, hint: 'unbekannt viel Erfahrung' },
  };
}

// ================================================================ Gegenstände

/** Ab welchem Level man Gegenstände dieser Seltenheit vollständig versteht. */
export const RARITY_LEVEL: Record<Rarity, number> = {
  gewoehnlich: 1, ungewoehnlich: 1, selten: 3, episch: 6, legendaer: 10, himmlisch: 15,
};

export function itemInsight(s: GameState, it: Item): Insight {
  if (it.kind === 'gold' || it.kind === 'box' || it.kind === 'karte') return 0;
  const gap = RARITY_LEVEL[it.rarity] - s.player.level - intelligenceBonus(s);
  if (gap <= 0) return 0;
  if (gap <= 2) return 1;
  if (gap <= 5) return 2;
  return 4;
}

/** Name eines Gegenstands, wie der Crawler ihn kennt. */
export function itemName(s: GameState, it: Item): string {
  const insight = itemInsight(s, it);
  if (insight === 0) return it.name;
  const kind = it.slot ? SLOT_NAMES[it.slot] : it.kind === 'wurf' ? 'Wurfobjekt' : 'Gegenstand';
  if (insight === 1) return `${it.name} (nicht identifiziert)`;
  return `Unbekannter ${RARITY_NAMES[it.rarity].toLowerCase()}er Gegenstand (${kind})`;
}

export interface ItemInfo {
  insight: Insight;
  name: string;
  bonuses: string[];
  flavor: string | null;
  note: string | null;
}

export function describeItem(s: GameState, it: Item): ItemInfo {
  const insight = itemInsight(s, it);
  const lines = describeBonuses(it.bonuses);
  const need = RARITY_LEVEL[it.rarity];
  if (insight === 0) return { insight, name: it.name, bonuses: lines, flavor: it.flavor, note: null };
  if (insight === 1) {
    // Man erkennt, WAS verzaubert ist, aber nicht wie stark.
    const vague = lines.map((l) => l.replace(/^[+-]?\d+(?:[.,]\d+)?/, '?'));
    return { insight, name: itemName(s, it), bonuses: vague, flavor: it.flavor, note: `Vollständig lesbar ab Level ${need}.` };
  }
  return {
    insight,
    name: itemName(s, it),
    bonuses: lines.length ? ['Unbekannte magische Eigenschaften'] : [],
    flavor: null,
    note: `Du verstehst diesen Gegenstand noch nicht. Ab Level ${need} (oder mit mehr Intelligenz) wird er lesbar.`,
  };
}
