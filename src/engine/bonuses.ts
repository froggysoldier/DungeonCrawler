import type { Bonuses, StatKey } from './types';

/** Addiert Bonus b in Bonus a (mutiert a) und gibt a zurück. */
export function addBonuses(a: Bonuses, b: Bonuses | undefined, factor = 1): Bonuses {
  if (!b) return a;
  if (b.stats) {
    a.stats ??= {};
    for (const [k, v] of Object.entries(b.stats) as [StatKey, number][]) {
      a.stats[k] = (a.stats[k] ?? 0) + v * factor;
    }
  }
  if (b.schaden) {
    a.schaden ??= {};
    for (const [k, v] of Object.entries(b.schaden) as [keyof NonNullable<Bonuses['schaden']>, number][]) {
      a.schaden[k] = (a.schaden[k] ?? 0) + v * factor;
    }
  }
  const scalar = ['maxHp', 'maxMp', 'maxAusdauer', 'ruestung', 'ausweichen', 'treffer', 'krit', 'hpRegen', 'xpBonus', 'dornen', 'lichtradius'] as const;
  for (const key of scalar) {
    const v = b[key];
    if (v) a[key] = (a[key] ?? 0) + v * factor;
  }
  return a;
}

const LABELS: Record<string, string> = {
  maxHp: 'max. HP', maxMp: 'max. Mana', maxAusdauer: 'max. Ausdauer', ruestung: 'Rüstung', ausweichen: '% Ausweichen',
  treffer: '% Treffer', krit: '% Krit', hpRegen: 'HP-Regeneration', xpBonus: '% XP', dornen: 'Dornenschaden',
  lichtradius: 'Sichtweite',
};

export const STAT_NAMES: Record<StatKey, string> = {
  str: 'Stärke', ges: 'Geschick', kon: 'Konstitution', int: 'Intelligenz', cha: 'Charisma',
};

export const PART_NAMES: Record<string, string> = {
  faust: 'Faust', tritt: 'Tritt', knie: 'Knie', ellbogen: 'Ellbogen', kopf: 'Kopfstoß', waffe: 'Waffe', wurf: 'Wurf', alle: 'alle Angriffe',
};

const sign = (v: number) => (v >= 0 ? `+${round(v)}` : `${round(v)}`);
const round = (v: number) => Math.round(v * 10) / 10;

export function describeBonuses(b: Bonuses | undefined): string[] {
  if (!b) return [];
  const out: string[] = [];
  if (b.stats) for (const [k, v] of Object.entries(b.stats) as [StatKey, number][]) if (v) out.push(`${sign(v)} ${STAT_NAMES[k]}`);
  if (b.schaden) for (const [k, v] of Object.entries(b.schaden)) if (v) out.push(`${sign(v)} % Schaden (${PART_NAMES[k] ?? k})`);
  for (const [k, label] of Object.entries(LABELS)) {
    const v = (b as Record<string, number | undefined>)[k];
    if (v) out.push(`${sign(v)} ${label}`);
  }
  return out;
}
