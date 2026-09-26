import { EVOLVE_LEVELS, PET_ABILITIES, PET_FORMS, PET_PATHS, PET_SPECIES, type PetAbility, type PetForm } from '../data/pets';
import { emit } from './events';
import { chebyshev } from './fov';
import { itemName, nameOf } from './identify';
import { addToInventory } from './inventory';
import { log, toast } from './log';
import { maxHp } from './player';
import * as R from './rng';
import type { GameState, Monster, Pet } from './types';

/**
 * Haustier-Entwicklung: zwei Stufen (4 und 8), Wege mit eigenen Fähigkeiten,
 * dazu ein Halsband als Ausrüstung.
 */

export function evolveStage(pet: Pet): number {
  if (!pet.form) return 0;
  return PET_FORMS[pet.form]?.next ? 1 : 2;
}

/** Welche Formen gerade zur Wahl stehen. */
export function evolveOptions(pet: Pet): PetForm[] {
  const stage = evolveStage(pet);
  if (stage === 0) return (PET_PATHS[pet.species] ?? PET_PATHS.Katze).map((id) => PET_FORMS[id]);
  if (stage === 1) return [PET_FORMS[PET_FORMS[pet.form!].next!]];
  return [];
}

/** Prüft nach einem Stufenaufstieg, ob eine Entwicklung möglich ist. */
export function checkEvolve(s: GameState) {
  const pet = s.player.pet;
  if (!pet || pet.evolveReady) return;
  const stage = evolveStage(pet);
  if (stage >= 2 || pet.level < EVOLVE_LEVELS[stage]) return;
  pet.evolveReady = true;
  log(s, `${pet.name} glüht und zittert. Eine ENTWICKLUNG ist möglich! (Crawler-Tab)`, 'system');
  toast(s, `${pet.name} kann sich entwickeln`, 'Wähle im Crawler-Tab.', 'skill');
}

export function evolvePet(s: GameState, formId: string): { ok: boolean; message?: string } {
  const pet = s.player.pet;
  if (!pet) return { ok: false, message: 'Du hast kein Haustier.' };
  if (!pet.evolveReady) return { ok: false, message: `${pet.name} ist noch nicht so weit.` };
  const form = evolveOptions(pet).find((f) => f.id === formId);
  if (!form) return { ok: false, message: 'Diese Entwicklung passt nicht.' };
  pet.form = form.id;
  pet.evolveReady = false;
  pet.maxHp += form.hp;
  pet.hp = pet.maxHp;
  pet.dmg = [pet.dmg[0] + form.dmg[0], pet.dmg[1] + form.dmg[1]];
  pet.abilities = [...new Set([...(pet.abilities ?? []), form.ability])];
  const stage = evolveStage(pet);
  log(s, `${pet.name} entwickelt sich zu: ${form.name}! ${form.flavor} Neue Fähigkeit: ${PET_ABILITIES[form.ability].name}.`, 'system');
  toast(s, `${pet.name}: ${form.name}`, PET_ABILITIES[form.ability].text, 'skill');
  emit(s, { type: 'petEvolved', form: form.id, stage });
  // Direkt die nächste Stufe prüfen (z. B. nach dem Superkeks)
  checkEvolve(s);
  return { ok: true };
}

export function petFormName(pet: Pet): string {
  const species = PET_SPECIES[pet.species]?.name ?? pet.species;
  return pet.form ? `${PET_FORMS[pet.form]?.name ?? species} (${species})` : species;
}

export function petHas(s: GameState, a: PetAbility): boolean {
  const pet = s.player.pet;
  return !!pet?.alive && !!pet.abilities?.includes(a);
}

// ================================================================ Halsband

export function equipPetGear(s: GameState, uid: string): { ok: boolean; message?: string } {
  const p = s.player;
  const pet = p.pet;
  if (!pet) return { ok: false, message: 'Du hast kein Haustier.' };
  const it = p.inventory.find((i) => i.uid === uid);
  if (!it?.petBonus) return { ok: false, message: 'Das ist kein Halsband.' };
  // Aus dem Stapel genau eines nehmen
  let gear = it;
  if ((it.menge ?? 1) > 1) {
    it.menge = (it.menge ?? 1) - 1;
    s.uidCounter += 1;
    gear = { ...it, uid: `i${s.uidCounter}`, menge: 1 };
  } else p.inventory = p.inventory.filter((i) => i !== it);
  if (pet.gear) removePetGear(s);
  pet.gear = gear;
  pet.maxHp += gear.petBonus?.hp ?? 0;
  pet.hp += gear.petBonus?.hp ?? 0;
  log(s, `${pet.name} trägt jetzt: ${itemName(s, gear)}. Es sieht sehr zufrieden aus.`, 'info');
  return { ok: true };
}

export function removePetGear(s: GameState): { ok: boolean; message?: string } {
  const pet = s.player.pet;
  if (!pet?.gear) return { ok: false, message: 'Das Haustier trägt nichts.' };
  const gear = pet.gear;
  pet.gear = undefined;
  pet.maxHp -= gear.petBonus?.hp ?? 0;
  pet.hp = Math.max(1, Math.min(pet.hp, pet.maxHp));
  addToInventory(s, gear);
  return { ok: true };
}

export function petBiteBonus(s: GameState): number {
  const pet = s.player.pet;
  if (!pet) return 0;
  let bonus = pet.gear?.petBonus?.dmg ?? 0;
  if (pet.abilities?.includes('giftbiss')) bonus += 2 + Math.floor(pet.level / 3);
  return bonus;
}

// ================================================================ Fähigkeiten im Kampf

/** Sonderfähigkeiten vor dem normalen Zug. Gibt true zurück, wenn der Zug verbraucht ist. */
export function petAbilityTurn(s: GameState, pet: Pet, killFn: (m: Monster) => void): boolean {
  const ab = pet.abilities ?? [];
  if (!ab.length) return false;
  const p = s.player;
  const adjacent = s.monsters.filter((m) => chebyshev(m.pos, pet.pos) <= 1);

  if (ab.includes('lecken') && p.hp < maxHp(s) && chebyshev(pet.pos, p.pos) <= 2 && s.turn - (pet.lastHeal ?? -99) >= 12) {
    pet.lastHeal = s.turn;
    const heal = 2 + Math.floor(pet.level / 2);
    p.hp = Math.min(maxHp(s), p.hp + heal);
    log(s, `${pet.name} kümmert sich um deine Wunden. +${heal} HP.`, 'info');
    return true;
  }
  if (ab.includes('feuerodem') && R.chance(s, 0.25)) {
    const targets = s.monsters.filter((m) => chebyshev(m.pos, pet.pos) <= 2 && m.aware);
    if (targets.length) {
      const dmg = pet.level + 3;
      log(s, `${pet.name} speit Feuer!`, 'kampf');
      for (const m of targets) {
        m.hp -= Math.max(1, dmg - Math.floor(m.ruestung / 2));
        log(s, `Die Flammen treffen ${nameOf(s, m)}.`, 'kampf');
        if (m.hp <= 0) killFn(m);
      }
      return true;
    }
  }
  const foe = adjacent.find((m) => m.rank === 'normal' || m.rank === 'elite');
  if (foe && ab.includes('fauchen') && foe.rank === 'normal' && !foe.fleeing && R.chance(s, 0.2)) {
    foe.fleeing = true;
    log(s, `${pet.name} faucht ${nameOf(s, foe)} an. Der Gegner ergreift die Flucht.`, 'kampf');
    return true;
  }
  if (foe && (ab.includes('bellen') || ab.includes('netz')) && foe.downed <= 0 && foe.size !== 'riesig' && !foe.abilities?.includes('fliegend') && R.chance(s, 0.2)) {
    foe.downed = 2;
    log(s, ab.includes('netz') ? `${pet.name} spinnt ${nameOf(s, foe)} in ein Netz. Der Gegner liegt am Boden.` : `${pet.name} springt ${nameOf(s, foe)} an und reißt ihn um!`, 'kampf');
    return true;
  }
  return false;
}
