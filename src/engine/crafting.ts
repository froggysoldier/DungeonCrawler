import { RECIPE_BY_ID, RECIPES, type Recipe } from '../data/crafting';
import { emit } from './events';
import { itemName } from './identify';
import { addToInventory } from './inventory';
import { createItem } from './items';
import { log } from './log';
import { roomOf } from './mapgen';
import { skillLevel } from './player';
import * as R from './rng';
import type { GameState, Item } from './types';

const WORKBENCH_ROOMS = /werkstatt|schmiede/i;
export const MAX_WEAPON_UPGRADES = 3;

/** Steht eine Werkbank zur Verfügung? */
export function hasWorkbench(s: GameState): boolean {
  if (s.player.inventory.some((i) => i.baseId === 'klappwerkbank')) return true;
  const room = roomOf(s.map, s.player.pos);
  return !!room && (WORKBENCH_ROOMS.test(room.name) || room.kind === 'safe');
}

function countOf(s: GameState, ids: string[]): number {
  let n = 0;
  for (const it of s.player.inventory) if (ids.includes(it.baseId)) n += it.menge ?? 1;
  return n;
}

/** Entfernt `n` Stück aus dem Inventar (nicht die ausgerüstete Waffe). */
function consume(s: GameState, ids: string[], n: number) {
  const p = s.player;
  for (const it of [...p.inventory]) {
    if (n <= 0) break;
    if (!ids.includes(it.baseId)) continue;
    const have = it.menge ?? 1;
    const take = Math.min(have, n);
    n -= take;
    if (have - take > 0) it.menge = have - take;
    else p.inventory = p.inventory.filter((x) => x !== it);
  }
}

export interface RecipeStatus {
  recipe: Recipe;
  /** Was fehlt, als Klartext; leer = herstellbar. */
  missing: string[];
}

export function recipeStatus(s: GameState, r: Recipe): RecipeStatus {
  const missing: string[] = [];
  for (const ing of r.ingredients) {
    const have = countOf(s, ing.ids);
    if (have < ing.n) missing.push(`${ing.n - have}x ${ing.label}`);
  }
  if (r.workbench && !hasWorkbench(s)) missing.push('eine Werkbank');
  if (r.upgradeWeapon) {
    const w = s.player.equipment.waffe;
    if (!w) missing.push('eine ausgerüstete Waffe');
    else if ((w.upgrades ?? 0) >= MAX_WEAPON_UPGRADES) missing.push('eine Waffe, die noch nicht voller Nägel steckt');
  }
  return { recipe: r, missing };
}

export function allRecipes(s: GameState): RecipeStatus[] {
  return RECIPES.map((r) => recipeStatus(s, r));
}

export function craft(s: GameState, recipeId: string): { ok: boolean; message?: string; item?: Item } {
  const r = RECIPE_BY_ID[recipeId];
  if (!r) return { ok: false, message: 'Dieses Rezept kennst du nicht.' };
  const st = recipeStatus(s, r);
  if (st.missing.length) return { ok: false, message: `Dir fehlt: ${st.missing.join(', ')}.` };
  for (const ing of r.ingredients) consume(s, ing.ids, ing.n);
  s.counters.crafted += 1;

  if (r.upgradeWeapon) {
    const w = s.player.equipment.waffe!;
    w.upgrades = (w.upgrades ?? 0) + 1;
    w.waffenSchaden = (w.waffenSchaden ?? 2) + 2;
    if (w.upgrades === 1) w.name = `${w.name} (benagelt)`;
    log(s, `Du hämmerst Nägel in ${itemName(s, w)} und wickelst Panzertape drumherum. Waffenschaden jetzt ${w.waffenSchaden}.`, 'loot');
    emit(s, { type: 'crafted', recipe: r.id });
    return { ok: true, item: w };
  }

  const res = r.result!;
  let n = res.n;
  if (r.explosive && skillLevel(s, 'handwerk') >= 3 && R.chance(s, 0.1 + skillLevel(s, 'handwerk') * 0.02)) n += 1;
  const item = createItem(s, res.id, n);
  addToInventory(s, item);
  const extra = n > res.n ? ' Es reicht sogar für ein Stück mehr.' : '';
  log(s, `Hergestellt: ${n > 1 ? `${n}x ` : ''}${itemName(s, item)}.${extra}`, 'loot');
  emit(s, { type: 'crafted', recipe: r.id });
  return { ok: true, item };
}
