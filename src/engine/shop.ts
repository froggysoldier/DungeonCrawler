import { emit } from './events';
import { itemName } from './identify';
import { giveItem } from './inventory';
import { createItem, generateEquipment, isStackable } from './items';
import { log } from './log';
import { randomTome } from './magic';
import { effectiveStats } from './player';
import * as R from './rng';
import type { GameState, Item, Room, Shop } from './types';

/**
 * Läden in Safe Rooms. Die Ladenbesitzer bekommen einen Richtpreis vor-
 * gegeben, dürfen bis zu 25 % nachlassen, verdienen aber mehr, wenn sie es
 * nicht tun. Man kann pro Angebot einmal verhandeln – mit Charisma.
 */
const KEEPERS = [
  'Pimbo, ein Gnom mit Monokel', 'Frau Krätzig, eine Echsendame mit Lesebrille', 'Oskar, ein sehr kleiner Oger',
  'Madame Zunder, eine Feuerfee', 'Herr Kolbe, ein Pilzmensch mit Krawatte', 'Brakka, eine Kobold-Kauffrau',
];

export const SELL_FACTOR = 0.4;
export const MAX_DISCOUNT = 0.25;

function basePrice(it: Item): number {
  return Math.max(2, Math.round((it.wert || 3) * 2.2));
}

export function ensureShop(s: GameState, room: Room): Shop {
  if (room.shop) return room.shop;
  const offers: Item[] = [
    createItem(s, 'kleiner_heiltrank', 2),
    createItem(s, 'heiltrank'),
    createItem(s, 'kleiner_manatrank', 2),
    createItem(s, 'gegengift'),
    createItem(s, 'rubbellos', 3),
    createItem(s, R.pick(s, ['stein', 'ziegel', 'dartpfeil', 'bowlingkugel']), 5),
    generateEquipment(s, 'ungewoehnlich'),
    generateEquipment(s, R.chance(s, 0.3) ? 'selten' : 'ungewoehnlich'),
  ];
  if (R.chance(s, 0.4)) offers.push(randomTome(s, s.floor >= 2 ? 'selten' : 'ungewoehnlich'));
  if (R.chance(s, 0.15)) offers.push(createItem(s, R.pick(s, ['tattoo_kobold', 'tattoo_ratte', 'talisman_flug', 'talisman_insekt'])));
  if (R.chance(s, 0.08)) offers.push(createItem(s, 'ei_raptor'));
  room.shop = {
    keeper: R.pick(s, KEEPERS),
    offers: offers.map((item) => ({ item, price: basePrice(item) * (isStackable(item.kind) ? 1 : 1) })),
    mood: 100,
  };
  return room.shop;
}

/** Preis für einen Stapel: Stückpreis × Menge. */
export function offerPrice(price: number, it: Item): number {
  return price * (isStackable(it.kind) ? (it.menge ?? 1) : 1);
}

export function sellPrice(it: Item): number {
  const each = Math.max(1, Math.round((it.wert || 1) * SELL_FACTOR));
  return each * (isStackable(it.kind) ? (it.menge ?? 1) : 1);
}

export function buy(s: GameState, room: Room, index: number): { ok: boolean; message?: string } {
  const shop = ensureShop(s, room);
  const offer = shop.offers[index];
  if (!offer) return { ok: false, message: 'Dieses Angebot gibt es nicht mehr.' };
  const total = offerPrice(offer.price, offer.item);
  if (s.player.gold < total) return { ok: false, message: `Zu teuer. Das kostet ${total} Gold, du hast ${s.player.gold}.` };
  s.player.gold -= total;
  shop.offers.splice(index, 1);
  giveItem(s, offer.item);
  log(s, `Gekauft: ${itemName(s, offer.item)} für ${total} Gold.`, 'loot');
  emit(s, { type: 'bought', item: offer.item, price: total, haggled: !!offer.haggled });
  return { ok: true };
}

export function sell(s: GameState, uid: string): { ok: boolean; message?: string } {
  const p = s.player;
  const it = p.inventory.find((i) => i.uid === uid);
  if (!it) return { ok: false, message: 'Das hast du nicht.' };
  if (it.kind === 'box') return { ok: false, message: 'Lootboxen kann man nicht verkaufen.' };
  if (it.questId) return { ok: false, message: 'Das gehört jemandem, der darauf wartet.' };
  const price = sellPrice(it);
  p.inventory = p.inventory.filter((i) => i.uid !== uid);
  p.gold += price;
  s.counters.goldEarned += price;
  log(s, `Verkauft: ${itemName(s, it)} für ${price} Gold.`, 'loot');
  emit(s, { type: 'sold', item: it, price });
  return { ok: true };
}

/**
 * Verhandeln: Erfolgschance steigt mit Charisma und sinkt, wenn die Laune
 * der Ladenbesitzerin schon schlecht ist. Erfolg: 5–25 % Rabatt.
 * Misserfolg: Preis steigt um 10 %, die Laune sinkt.
 */
export function haggle(s: GameState, room: Room, index: number): { ok: boolean; message?: string } {
  const shop = ensureShop(s, room);
  const offer = shop.offers[index];
  if (!offer) return { ok: false, message: 'Dieses Angebot gibt es nicht mehr.' };
  if (offer.haggled) return { ok: false, message: 'Über diesen Preis wurde schon verhandelt.' };
  offer.haggled = true;
  const cha = effectiveStats(s).cha;
  const chance = Math.max(0.1, Math.min(0.9, 0.3 + (cha - 5) * 0.05 + (shop.mood - 100) / 200));
  const base = basePrice(offer.item);
  if (R.next(s) < chance) {
    const pct = Math.round(5 + R.next(s) * 20 * Math.min(1.5, cha / 10));
    const discount = Math.min(MAX_DISCOUNT * 100, pct);
    offer.price = Math.max(1, Math.round(base * (1 - discount / 100)));
    log(s, `Du verhandelst geschickt. ${shop.keeper} seufzt und gibt ${discount} % Rabatt.`, 'dialog');
    emit(s, { type: 'haggle', success: true, percent: discount });
  } else {
    offer.price = Math.round(base * 1.1);
    shop.mood = Math.max(0, shop.mood - 15);
    log(s, `${shop.keeper} ist beleidigt. „Jetzt kostet es eben mehr.“ (+10 %)`, 'dialog');
    emit(s, { type: 'haggle', success: false, percent: 0 });
  }
  return { ok: true };
}
