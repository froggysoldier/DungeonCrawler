import { EGG_SPECIES, HATCH_TURNS, PET_SPECIES, TAMEABLE } from '../data/pets';
import { emit } from './events';
import { chebyshev, hasLineOfSight } from './fov';
import { itemName, nameOf } from './identify';
import { giveItem } from './inventory';
import { createBox, createGold, generateEquipment } from './items';
import { log, toast } from './log';
import { randomTome } from './magic';
import { checkEvolve } from './petevo';
import { targetFacets } from './observer';
import { effectiveStats } from './player';
import * as R from './rng';
import type { GameState, Item, Monster, Pet, Pos } from './types';

// ================================================================ Pässe und Talismane

/** Facetten, die der Crawler durch Tätowierungen und Talismane „mitführt“. */
export function activePasses(s: GameState): string[] {
  const out = [...(s.player.passes ?? [])];
  for (const it of Object.values(s.player.equipment)) if (it?.passFacet) out.push(it.passFacet);
  return out;
}

/** Ein Monster ignoriert den Crawler, solange ein passender Pass gilt und es nicht angegriffen wurde. */
export function passProtects(s: GameState, m: Monster): boolean {
  if (m.provoked || m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss') return false;
  const passes = activePasses(s);
  if (!passes.length) return false;
  const facets = targetFacets(s, m);
  return passes.some((p) => facets.includes(p));
}

const TATTOOS: Record<string, { facet: string; text: string }> = {
  tattoo_kobold: { facet: 'z:kobold', text: 'Ein Kobold grinst jetzt von deinem Unterarm. Kobolde halten dich für einen der ihren.' },
  tattoo_ratte: { facet: 'z:ratte', text: 'Sieben verknotete Schwänze zieren jetzt deine Hand. Ratten weichen dir aus.' },
};

export const TALISMAN_FACETS: Record<string, string> = {
  talisman_flug: 'z:fliegend',
  talisman_untot: 'z:untot',
  talisman_insekt: 'z:insekt',
};

// ================================================================ Haustiere

export function makePetOf(species: string, name: string): Pet {
  const sp = PET_SPECIES[species] ?? PET_SPECIES.Katze;
  return { name, species: sp.id, level: 1, xp: 0, hp: sp.hp, maxHp: sp.hp, dmg: [...sp.dmg] as [number, number], pos: { x: 0, y: 0 }, alive: true };
}

function freeNeighbor(s: GameState, p: Pos): Pos {
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const q = { x: p.x + dx, y: p.y + dy };
      if ((dx || dy) && s.map.tiles[q.y * s.map.width + q.x] !== 'wall' && !s.monsters.some((m) => m.pos.x === q.x && m.pos.y === q.y)) return q;
    }
  }
  return { ...p };
}

/** Eier im Inventar schlüpfen nach einiger Zeit. */
export function eggTick(s: GameState) {
  const p = s.player;
  for (const it of p.inventory) prepareEgg(s, it);
  for (const it of [...p.inventory]) {
    if (!it.hatchAt || s.turn < it.hatchAt) continue;
    if (p.pet) {
      if (it.hatchAt === s.turn || s.turn - it.hatchAt === 1) log(s, `${itemName(s, it)} wackelt – aber du hast schon ein Haustier. Es wartet.`, 'info');
      continue;
    }
    const species = it.petSpecies ?? 'Kellerraptor';
    p.inventory = p.inventory.filter((x) => x.uid !== it.uid);
    p.pet = makePetOf(species, PET_SPECIES[species].name);
    p.pet.pos = freeNeighbor(s, p.pos);
    log(s, `Das Ei knackt! Ein ${PET_SPECIES[species].name} schlüpft, sieht dich und entscheidet: Du bist jetzt die Familie. ${PET_SPECIES[species].flavor}`, 'system');
    toast(s, 'Ein Ei ist geschlüpft', PET_SPECIES[species].name, 'loot');
    emit(s, { type: 'petGained', species, how: 'ei' });
  }
}

/** Beim Aufheben eines Eis: Brutzeit setzen. */
export function prepareEgg(s: GameState, it: Item) {
  if (EGG_SPECIES[it.baseId] && !it.hatchAt) {
    it.hatchAt = s.turn + HATCH_TURNS;
    it.petSpecies = EGG_SPECIES[it.baseId];
  }
}

/** Zähmen: Leckerli an ein geschwächtes, zähmbares Tier neben dir verfüttern. */
export function tryTame(s: GameState): { handled: boolean } {
  const p = s.player;
  if (p.pet) return { handled: false };
  const cand = s.monsters.find(
    (m) => chebyshev(m.pos, p.pos) <= 1 && TAMEABLE[m.defId] && m.rank === 'normal' && m.hp <= m.maxHp * 0.4,
  );
  if (!cand) return { handled: false };
  const chance = Math.min(0.9, 0.35 + (effectiveStats(s).cha - 5) * 0.04);
  if (R.next(s) < chance) {
    const species = TAMEABLE[cand.defId];
    s.monsters = s.monsters.filter((m) => m !== cand);
    p.pet = makePetOf(species, PET_SPECIES[species].name);
    p.pet.pos = { ...cand.pos };
    log(s, `${nameOf(s, cand)} schnuppert am Leckerli, frisst es – und folgt dir ab jetzt. Du hast ein neues Haustier!`, 'system');
    emit(s, { type: 'petGained', species, how: 'zaehmen' });
  } else {
    cand.aware = true;
    log(s, `${nameOf(s, cand)} frisst das Leckerli und beißt dir zum Dank in die Hand. Zähmen fehlgeschlagen.`, 'kampf');
  }
  return { handled: true };
}

// ================================================================ Besondere Gegenstände

/** Behandelt Gegenstände mit Sonderwirkung. `null` = kein Sonderfall. */
export function useSpecial(s: GameState, it: Item): { ok: boolean; message?: string } | null {
  const p = s.player;
  const tattoo = TATTOOS[it.baseId];
  if (tattoo) {
    p.passes ??= [];
    if (p.passes.includes(tattoo.facet)) return { ok: false, message: 'Dieses Tattoo hast du schon.' };
    p.passes.push(tattoo.facet);
    log(s, tattoo.text, 'system');
    return { ok: true };
  }
  if (it.baseId === 'superkeks') {
    if (!p.pet) {
      log(s, 'Du isst den Superkeks. Er summt in deinem Magen. Nichts passiert, außer dass die Zuschauer schreien.', 'info');
      return { ok: true };
    }
    const pet = p.pet;
    pet.caster = true;
    pet.alive = true;
    for (let i = 0; i < 3; i++) {
      pet.level += 1;
      pet.maxHp += 6;
      pet.dmg = [pet.dmg[0] + 1, pet.dmg[1] + 2];
    }
    pet.hp = pet.maxHp;
    checkEvolve(s);
    log(s, `${pet.name} frisst den Superkeks. Die Augen leuchten auf. ${pet.name} schaut dich an – und SPRICHT: „Na endlich. Ich dachte schon, du fragst nie.“ ${pet.name} kann jetzt zaubern.`, 'system');
    toast(s, `${pet.name} ist erwacht`, 'Das Haustier spricht und wirkt Magische Geschosse.', 'skill');
    return { ok: true };
  }
  if (it.baseId === 'rubbellos') {
    scratch(s);
    return { ok: true };
  }
  if (EGG_SPECIES[it.baseId]) {
    prepareEgg(s, it);
    return { ok: false, message: `Das Ei ist noch nicht so weit. Noch etwa ${Math.max(0, (it.hatchAt ?? 0) - s.turn)} Züge.` };
  }
  return null;
}

function scratch(s: GameState) {
  const roll = R.next(s);
  let outcome: string;
  if (roll < 0.5) {
    outcome = 'niete';
    log(s, 'Du rubbelst … „LEIDER NICHT GEWONNEN. Versuch es noch einmal!“ Die Systemstimme kichert.', 'info');
  } else if (roll < 0.75) {
    const amount = R.int(s, 10, 40);
    giveItem(s, createGold(s, amount));
    outcome = 'gold';
    log(s, `Du rubbelst … drei Münzen! Gewinn: ${amount} Gold.`, 'loot');
  } else if (roll < 0.87) {
    const item = generateEquipment(s, R.chance(s, 0.3) ? 'selten' : 'ungewoehnlich');
    giveItem(s, item);
    outcome = 'gegenstand';
    log(s, `Du rubbelst … drei Schwerter! Gewinn: ${itemName(s, item)}.`, 'loot');
  } else if (roll < 0.95) {
    s.player.boxes.push(createBox(s, 'abenteurer', R.chance(s, 0.3) ? 'silber' : 'bronze'));
    outcome = 'box';
    log(s, 'Du rubbelst … drei Kisten! Gewinn: eine Lootbox.', 'loot');
  } else if (roll < 0.99) {
    const tome = randomTome(s, 'selten');
    giveItem(s, tome);
    outcome = 'buch';
    log(s, `Du rubbelst … drei Bücher! Gewinn: ${itemName(s, tome)}.`, 'loot');
  } else {
    giveItem(s, createGold(s, 500));
    outcome = 'jackpot';
    log(s, 'JACKPOT! Drei goldene Kronen! 500 Gold! Die Zuschauer drehen durch.', 'loot');
    toast(s, 'Jackpot!', '500 Gold aus einem Rubbellos', 'loot');
  }
  emit(s, { type: 'lottery', outcome });
}

/** Das Haustier wirkt Magische Geschosse, wenn es zaubern kann. */
export function petCast(s: GameState, pet: Pet): Monster | null {
  if (!pet.caster || !R.chance(s, 0.35)) return null;
  const target = s.monsters
    .filter((m) => chebyshev(m.pos, pet.pos) <= 5 && m.aware && hasLineOfSight(s.map, pet.pos, m.pos))
    .sort((a, b) => chebyshev(a.pos, pet.pos) - chebyshev(b.pos, pet.pos))[0];
  return target ?? null;
}
