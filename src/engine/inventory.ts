import { hasSpecial } from './abilities';
import { emit } from './events';
import { isStackable } from './items';
import { log } from './log';
import type { GameState, Item } from './types';

export function addToInventory(s: GameState, item: Item) {
  if (isStackable(item.kind)) {
    const same = s.player.inventory.find((i) => i.baseId === item.baseId && i.rarity === item.rarity && i.name === item.name);
    if (same) {
      same.menge = (same.menge ?? 1) + (item.menge ?? 1);
      return;
    }
  }
  s.player.inventory.push(item);
}

export function gainGold(s: GameState, amount: number) {
  const bonus = hasSpecial(s, 'goldmagnet') ? Math.round(amount * 0.5) : 0;
  s.player.gold += amount + bonus;
  s.counters.goldEarned += amount + bonus;
  if (bonus) log(s, `Der Goldmagnet zieht ${bonus} Extra-Gold an.`, 'loot');
  emit(s, { type: 'goldGained', amount: amount + bonus });
}

/** Gibt dem Crawler ein Item: Inventar, oder vor dem Tutorial in die Hand. */
export function giveItem(s: GameState, item: Item) {
  const p = s.player;
  if (item.kind === 'gold') {
    gainGold(s, item.menge ?? 0);
    return;
  }
  if (item.kind === 'box') {
    p.boxes.push(item);
    return;
  }
  if (s.unlocks.includes('inventar')) {
    addToInventory(s, item);
    return;
  }
  if (!p.hand) {
    p.hand = item;
    return;
  }
  s.items.push({ pos: { ...p.pos }, item });
  log(s, `Deine Hände sind voll. ${item.name} fällt zu Boden.`, 'info');
}

