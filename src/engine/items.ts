import {
  AFFIXES, BASE_ITEMS, ITEM_QUIPS, RARITY_AFFIXES, RARITY_ORDER, UNIQUE_ITEMS, type BaseItem,
} from '../data/items';
import { HOOD_BOSSES } from '../data/monsters';
import { BOX_CONTENTS, BOX_TIERS, BOX_TIER_NAMES, BOX_TYPE_NAMES, HOOD_NAMES } from '../data/world';
import { addBonuses } from './bonuses';
import { randomTome } from './magic';
import * as R from './rng';
import type { Bonuses, BoxTier, BoxType, GameState, Item, Rarity, Slot } from './types';

const BASE_BY_ID: Record<string, BaseItem> = Object.fromEntries(
  [...BASE_ITEMS, ...UNIQUE_ITEMS].map((b) => [b.id, b]),
);

const BOSS_LOOT = new Set(HOOD_BOSSES.flatMap((b) => b.loot));
const START_ONLY = new Set(['bademantel', 'schlafanzug', 'anzug', 'arbeitsjacke', 'sportshirt', 'hausschuhe']);

export function uid(s: GameState): string {
  s.uidCounter += 1;
  return `i${s.uidCounter}`;
}

const RARITY_VALUE: Record<Rarity, number> = {
  gewoehnlich: 1, ungewoehnlich: 2, selten: 4, episch: 8, legendaer: 20, himmlisch: 60,
};

/** Erzeugt ein Item exakt nach Basisdefinition (ohne Verzauberung). */
export function createItem(s: GameState, baseId: string, menge = 1): Item {
  const base = BASE_BY_ID[baseId];
  if (!base) throw new Error(`Unbekanntes Item: ${baseId}`);
  const unique = UNIQUE_ITEMS.find((u) => u.id === baseId);
  return {
    uid: uid(s),
    baseId,
    name: base.name,
    kind: base.kind,
    rarity: unique?.rarity ?? 'gewoehnlich',
    slot: base.slot,
    bonuses: base.bonuses ? structuredClone(base.bonuses) : undefined,
    waffenSchaden: base.waffenSchaden,
    wurfSchaden: base.wurfSchaden,
    effekt: base.effekt,
    menge: isStackable(base.kind) ? menge : undefined,
    flavor: base.flavor,
    special: unique?.special,
    wert: base.wert,
  };
}

export function isStackable(kind: Item['kind']): boolean {
  return kind === 'wurf' || kind === 'verbrauch';
}

export function createBox(s: GameState, type: BoxType, tier: BoxTier): Item {
  return {
    uid: uid(s),
    baseId: `box_${type}_${tier}`,
    name: `${BOX_TIER_NAMES[tier]} ${BOX_TYPE_NAMES[type]}`,
    kind: 'box',
    rarity: tierToRarity(tier),
    box: { type, tier },
    flavor: 'Kann nur in einem Safe Room geöffnet werden.',
    wert: 0,
  };
}

export function createAreaMap(s: GameState, hood: number): Item {
  return {
    uid: uid(s),
    baseId: 'gebietskarte',
    name: `Gebietskarte: ${HOOD_NAMES[hood]}`,
    kind: 'karte',
    rarity: 'selten',
    hood,
    flavor: 'Zeigt den kompletten Grundriss dieses Viertels. Beim Aufheben wird die Karte sofort eingetragen.',
    wert: 0,
  };
}

export function createGold(s: GameState, amount: number): Item {
  return {
    uid: uid(s), baseId: 'gold', name: `${amount} Gold`, kind: 'gold', rarity: 'gewoehnlich',
    menge: amount, flavor: 'Die Währung des Dungeons. Riecht nach Münzen und Blut.', wert: amount,
  };
}

function tierToRarity(tier: BoxTier): Rarity {
  return RARITY_ORDER[BOX_TIERS.indexOf(tier)];
}

const BOX_SLOTS: Partial<Record<BoxType, Slot[]>> = {
  waffen: ['waffe', 'haende'],
  schuh: ['fuesse', 'fussring'],
  kleidung: ['kopf', 'gesicht', 'brust', 'schultern', 'arme', 'beine', 'unterwaesche', 'guertel', 'ruecken'],
  schmuck: ['ring', 'hals', 'fussring'],
  brawler: ['haende', 'arme', 'fuesse', 'kopf'],
  wurf: ['arme', 'haende', 'schultern'],
};

/** Erzeugt ein Ausrüstungsteil mit zufälliger Verzauberung. */
export function generateEquipment(s: GameState, rarity: Rarity, slots?: Slot[]): Item {
  const pool = BASE_ITEMS.filter(
    (b) => b.kind === 'ausruestung' && !BOSS_LOOT.has(b.id) && !START_ONLY.has(b.id) && (!slots || (b.slot && slots.includes(b.slot))),
  );
  const base = R.pick(s, pool.length ? pool : BASE_ITEMS.filter((b) => b.kind === 'ausruestung'));
  const item = createItem(s, base.id);
  item.rarity = rarity;
  const cfg = RARITY_AFFIXES[rarity];
  const count = R.int(s, cfg.count[0], cfg.count[1]);
  const affixPool = AFFIXES.filter((a) => !a.slots || (base.slot && a.slots.includes(base.slot)));
  const chosen = R.shuffle(s, [...affixPool]).slice(0, count);
  const bonuses: Bonuses = item.bonuses ?? {};
  for (const a of chosen) addBonuses(bonuses, a.bonuses(R.int(s, cfg.power[0], cfg.power[1])));
  item.bonuses = bonuses;
  if (item.waffenSchaden) item.waffenSchaden += RARITY_ORDER.indexOf(rarity) * 2;
  if (chosen.length) {
    item.name = `${base.name} ${chosen[0].prefix}`;
    if (chosen.length > 1) item.name += ` (+${chosen.length - 1})`;
    item.flavor = `${base.flavor} ${R.pick(s, ITEM_QUIPS)}`;
  }
  item.wert = Math.round((base.wert + 2) * RARITY_VALUE[rarity]);
  return item;
}

function rollUnique(s: GameState, maxRarity: Rarity): Item | null {
  const maxIdx = RARITY_ORDER.indexOf(maxRarity);
  const pool = UNIQUE_ITEMS.filter((u) => RARITY_ORDER.indexOf(u.rarity) <= maxIdx);
  if (!pool.length) return null;
  return createItem(s, R.pick(s, pool).id);
}

/** Öffnet eine Box und erzeugt ihren Inhalt. */
export function rollBoxContents(s: GameState, type: BoxType, tier: BoxTier): Item[] {
  const cfg = BOX_CONTENTS[tier];
  const out: Item[] = [];
  const count = R.int(s, cfg.items[0], cfg.items[1]);
  const maxRarity = cfg.rarities[cfg.rarities.length - 1][0];
  for (let i = 0; i < count; i++) {
    if (R.chance(s, cfg.uniqueChance)) {
      const u = rollUnique(s, maxRarity);
      if (u) {
        out.push(u);
        continue;
      }
    }
    const rarity = R.weighted(s, cfg.rarities);
    out.push(rollThemedItem(s, type, rarity));
  }
  // Jede Box enthält zusätzlich etwas Gold und je nach Thema Verbrauchsgüter.
  out.push(createGold(s, R.int(s, cfg.gold[0], cfg.gold[1])));
  const tierIdx = BOX_TIERS.indexOf(tier);
  if (type === 'ueberlebens' || type === 'abenteurer') {
    out.push(createItem(s, tierIdx >= 1 ? 'heiltrank' : 'kleiner_heiltrank', 1 + Math.floor(tierIdx / 2)));
  }
  if (type === 'wurf') out.push(createItem(s, tierIdx >= 2 ? 'ziegel' : 'stein', 5 + tierIdx * 3));
  if (type === 'ueberlebens') out.push(createItem(s, 'gegengift', 1 + Math.floor(tierIdx / 2)));
  // Zauberbücher: selten in einfachen Boxen, häufiger in guten
  if ((type === 'abenteurer' || type === 'fan' || type === 'boss') && R.chance(s, 0.12 + tierIdx * 0.1)) {
    out.push(randomTome(s, RARITY_ORDER[Math.min(4, tierIdx + 1)]));
  }
  if (tierIdx >= 1 && R.chance(s, 0.3)) out.push(createItem(s, 'kleiner_manatrank', 1 + Math.floor(tierIdx / 2)));
  if (type === 'brawler') out.push(createItem(s, 'energydrink', 1 + Math.floor(tierIdx / 2)));
  return out;
}

function rollThemedItem(s: GameState, type: BoxType, rarity: Rarity): Item {
  if (type === 'haustier') {
    return R.chance(s, 0.6) ? createItem(s, 'leckerli', RARITY_ORDER.indexOf(rarity) + 1) : generateEquipment(s, rarity, ['hals']);
  }
  if (type === 'ueberlebens' && R.chance(s, 0.4)) {
    return createItem(s, 'heiltrank', 1 + RARITY_ORDER.indexOf(rarity));
  }
  return generateEquipment(s, rarity, BOX_SLOTS[type]);
}

/** Zufälliger Bodenfund (Steine, Flaschen, Kleinkram). */
export function rollGroundItem(s: GameState): Item {
  const pool = BASE_ITEMS.filter((b) => b.ground).map((b) => [b.id, b.ground!] as [string, number]);
  const id = R.weighted(s, pool);
  const base = BASE_BY_ID[id];
  if (base.kind === 'ausruestung' && R.chance(s, 0.15)) return generateEquipment(s, 'ungewoehnlich', base.slot ? [base.slot] : undefined);
  return createItem(s, id);
}

/** Mob-Drops: meist nichts, manchmal Gold oder Kleinkram. */
export function rollMobDrop(s: GameState, level: number, elite: boolean): Item[] {
  const out: Item[] = [];
  if (R.chance(s, elite ? 1 : 0.35)) out.push(createGold(s, R.int(s, 1, 3 + level * 2) * (elite ? 3 : 1)));
  if (R.chance(s, elite ? 0.6 : 0.12)) out.push(elite ? generateEquipment(s, R.chance(s, 0.3) ? 'selten' : 'ungewoehnlich') : rollGroundItem(s));
  if (R.chance(s, 0.05)) out.push(createItem(s, 'kleiner_heiltrank'));
  if (R.chance(s, 0.03)) out.push(createItem(s, 'gegengift'));
  return out;
}

export function baseExists(id: string): boolean {
  return !!BASE_BY_ID[id];
}
