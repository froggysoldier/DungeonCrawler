import { MOUNT_ITEMS, MOUNTS } from '../data/mounts';
import { emit } from './events';
import { addToInventory } from './inventory';
import { createItem } from './items';
import { log, toast } from './log';
import { roomOf } from './mapgen';
import * as R from './rng';
import { skillLevel } from './player';
import { trainSkill } from './skills';
import { hasSpecial } from './abilities';
import type { GameState, Item } from './types';

/**
 * Reittiere und Fahrzeuge: schneller unterwegs, Rammen mit Anlauf,
 * ein Teil der Treffer geht auf das Reittier. Fahrzeuge brauchen Benzin.
 * Im Safe Room steigt man ab; das System verwahrt das Reittier, solange
 * man nicht reitet.
 */

type Res = { ok: boolean; message?: string };

export const mountDef = (s: GameState) => (s.player.mount ? MOUNTS[s.player.mount.id] : undefined);
export const isRiding = (s: GameState) => !!s.player.riding && !!s.player.mount && !s.player.mount.down;

export function isMountItem(it: Item) {
  return !!MOUNT_ITEMS[it.baseId];
}

/** Zündschlüssel oder Pfeife benutzen: das Reittier gehört jetzt dir. */
export function gainMount(s: GameState, it: Item): Res {
  const id = MOUNT_ITEMS[it.baseId];
  const def = MOUNTS[id];
  if (!def) return { ok: false, message: 'Das ist kein Reittier.' };
  const p = s.player;
  if (p.mount) log(s, `${p.mount.name} verabschiedet sich. Man kann nur ein Reittier gleichzeitig haben.`, 'info');
  p.mount = { id, name: def.name, hp: def.hp, maxHp: def.hp, fuel: def.fuel };
  p.riding = false;
  p.mountSteps = 0;
  log(s, `${def.name} gehört jetzt dir! ${def.flavor} (Aufsitzen im Crawler-Tab oder mit M.)`, 'system');
  toast(s, 'Neues Reittier', def.name, 'loot');
  emit(s, { type: 'mountGained', id });
  return { ok: true };
}

export function toggleRide(s: GameState): Res {
  const p = s.player;
  const m = p.mount;
  if (!m) return { ok: false, message: 'Du hast kein Reittier.' };
  if (p.riding) {
    p.riding = false;
    log(s, `Du steigst von ${m.name} ab. Das System verwahrt es für dich.`, 'info');
    return { ok: true };
  }
  if (m.down) return { ok: false, message: `${m.name} muss sich erst erholen. Schlaf in einem Safe Room.` };
  if (roomOf(s.map, p.pos)?.kind === 'safe') return { ok: false, message: 'Im Safe Room wird nicht geritten. Der Türsteher war da sehr deutlich.' };
  if (m.fuel !== undefined && m.fuel <= 0) return { ok: false, message: 'Der Tank ist leer. Du brauchst einen Benzinkanister.' };
  p.riding = true;
  p.mountSteps = 0;
  log(s, `Du steigst auf ${m.name}. Los geht’s!`, 'info');
  return { ok: true };
}

export function refuel(s: GameState): Res {
  const p = s.player;
  const m = p.mount;
  const def = mountDef(s);
  if (!m || !def || def.kind !== 'fahrzeug') return { ok: false, message: 'Du hast kein Fahrzeug.' };
  const can = p.inventory.find((i) => i.baseId === 'benzinkanister');
  if (!can) return { ok: false, message: 'Du hast keinen Benzinkanister.' };
  if ((can.menge ?? 1) > 1) can.menge = (can.menge ?? 1) - 1;
  else p.inventory = p.inventory.filter((i) => i !== can);
  m.fuel = Math.min(def.fuel ?? 0, (m.fuel ?? 0) + 90);
  log(s, `Du tankst ${m.name}. Tank: ${m.fuel} von ${def.fuel}.`, 'info');
  return { ok: true };
}

/**
 * Nach einem Schritt: verbraucht Benzin, zählt Schritte.
 * Gibt zurück, ob der Zug endet (bei Tempo 2 nur jeden zweiten Schritt).
 */
export function mountStep(s: GameState): boolean {
  if (!isRiding(s)) return true;
  const p = s.player;
  const m = p.mount!;
  const def = mountDef(s)!;
  trainSkill(s, 'ride', 0.3);
  if (m.fuel !== undefined) {
    // Wer gut reitet, fährt sparsamer
    const saving = Math.min(0.75, skillLevel(s, 'reiten') * 0.05) + (hasSpecial(s, 'schrauber') ? 0.5 : 0);
    if (!R.chance(s, Math.min(0.9, saving))) m.fuel -= 1;
    if (m.fuel <= 0) {
      m.fuel = 0;
      p.riding = false;
      log(s, `${m.name} stottert und bleibt stehen. Tank leer. Du steigst ab.`, 'gefahr');
      return true;
    }
    if (m.fuel === 20) log(s, `${m.name}: Der Tank ist fast leer.`, 'gefahr');
  }
  p.mountSteps = (p.mountSteps ?? 0) + 1;
  return p.mountSteps % Math.max(1, def.speed) === 0;
}

/** Beim Betreten eines Safe Rooms automatisch absteigen. */
export function dismountForSafeRoom(s: GameState) {
  if (!isRiding(s)) return;
  s.player.riding = false;
  log(s, `Du steigst von ${s.player.mount!.name} ab. Reittiere müssen draußen bleiben – das System verwahrt es.`, 'info');
}

/** Ein Teil der Treffer landet beim Reittier. Gibt true zurück, wenn es den Schaden nimmt. */
export function mountAbsorbs(s: GameState, dmg: number, source: string): boolean {
  if (!isRiding(s) || !R.chance(s, 0.35)) return false;
  const p = s.player;
  const m = p.mount!;
  const def = mountDef(s)!;
  const armor = (hasSpecial(s, 'schrauber') ? 0.3 : 0) + (hasSpecial(s, 'sattelfest') ? 0.25 : 0);
  dmg = Math.max(1, Math.round(dmg * (1 - Math.min(0.6, skillLevel(s, 'reiten') * 0.04)) * (1 - armor)));
  m.hp -= dmg;
  log(s, `${source} trifft ${m.name} für ${dmg} Schaden.`, 'kampf');
  if (m.hp > 0) return true;
  p.riding = false;
  if (def.kind === 'fahrzeug') {
    p.mount = undefined;
    addToInventory(s, createItem(s, 'schraubenmutter', 4));
    log(s, `${m.name} fällt auseinander. Totalschaden. Du rettest ein paar Schraubenmuttern.`, 'gefahr');
  } else {
    m.hp = 0;
    m.down = true;
    log(s, `${m.name} bricht zusammen und wird vom System weggebeamt. Nach dem Schlafen ist es wieder da.`, 'gefahr');
  }
  emit(s, { type: 'mountLost', id: def.id });
  return true;
}

/** Nach dem Schlafen: Tiere erholen sich, Fahrzeuge werden geflickt. */
export function restMount(s: GameState) {
  const m = s.player.mount;
  if (!m) return;
  m.down = false;
  m.hp = m.maxHp;
}

/** Tankgröße des aktuellen Fahrzeugs. */
export function mountFuelMax(s: GameState): number {
  return mountDef(s)?.fuel ?? 0;
}

export function ramBonus(s: GameState): number {
  return isRiding(s) ? mountDef(s)?.ram ?? 0 : 0;
}
