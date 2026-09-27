import { hasSpecial, poison } from './abilities';
import { isInSafeRoom, killMonster } from './combat';
import { handleLethal } from './death';
import { emit } from './events';
import { chebyshev } from './fov';
import { makeNoise } from './ai';
import { playerSees } from './sight';
import { NameOf, nameOf } from './identify';
import { addToInventory } from './inventory';
import { createItem } from './items';
import { log } from './log';
import { idx, tileAt } from './mapgen';
import { selfFacets, targetFacets } from './observer';
import { effectiveStats, skillLevel } from './player';
import { trainSkill } from './skills';
import * as R from './rng';
import { track } from './stats';
import { inflict, inflictPlayer } from './conditions';
import type { GameState, Item, Monster, Pos, ThrowCondition, Trap, TrapKind } from './types';

/**
 * Fallen. Der Dungeon ist voll davon: Druckplatten, Gruben, Gasdüsen,
 * Stolperdrähte, Bärenfallen. Wer aufmerksam ist (Intelligenz, Fallenkunde),
 * sieht sie rechtzeitig. Entschärfen braucht Geschick und liefert Fallenteile,
 * aus denen man eigene Fallen für Monster baut.
 */
export interface TrapDef {
  name: string;
  /** Wie schwer zu entdecken (Abzug in Prozentpunkten). */
  hide: number;
  /** Wie schwer zu entschärfen (Abzug in Prozentpunkten). */
  fiddly: number;
  minFloor: number;
  weight: number;
}

export const TRAP_DEFS: Record<TrapKind, TrapDef> = {
  pfeilplatte: { name: 'Pfeil-Druckplatte', hide: 0, fiddly: 0, minFloor: 1, weight: 4 },
  stolperdraht: { name: 'Stolperdraht mit Blechdosen', hide: 5, fiddly: -10, minFloor: 1, weight: 3 },
  fallgrube: { name: 'Fallgrube', hide: 10, fiddly: 5, minFloor: 1, weight: 3 },
  giftgas: { name: 'Giftgasdüse', hide: 10, fiddly: 10, minFloor: 2, weight: 3 },
  baerenfalle: { name: 'Bärenfalle', hide: 5, fiddly: 10, minFloor: 2, weight: 2 },
  stachelfalle: { name: 'Stachelfalle', hide: 0, fiddly: -20, minFloor: 99, weight: 0 },
  sprengfalle: { name: 'Sprengfalle', hide: 0, fiddly: -10, minFloor: 99, weight: 0 },
  schlingfalle: { name: 'Schlingfalle', hide: 0, fiddly: -20, minFloor: 99, weight: 0 },
};

export const OWN_TRAP_ITEM: Partial<Record<TrapKind, string>> = {
  stachelfalle: 'stachelfalle', sprengfalle: 'sprengfalle', schlingfalle: 'schlingfalle',
};

export function trapName(kind: TrapKind): string {
  return TRAP_DEFS[kind].name;
}

function traps(s: GameState): Trap[] {
  s.traps ??= [];
  return s.traps;
}

export function trapAt(s: GameState, p: Pos): Trap | undefined {
  return (s.traps ?? []).find((t) => t.pos.x === p.x && t.pos.y === p.y);
}

/** Bekannte Falle (sichtbar für den Crawler) an dieser Stelle? */
export function knownTrapAt(s: GameState, p: Pos): Trap | undefined {
  const t = trapAt(s, p);
  return t && !t.hidden ? t : undefined;
}

function removeTrap(s: GameState, t: Trap) {
  s.traps = traps(s).filter((x) => x !== t);
}

// ================================================================ Platzieren

/** Verteilt Dungeon-Fallen über die Etage: in Gängen und normalen Räumen. */
export function placeTraps(s: GameState, start: Pos) {
  s.traps = [];
  const m = s.map;
  const count = 6 + s.floor * 4;
  const pool = (Object.entries(TRAP_DEFS) as [TrapKind, TrapDef][])
    .filter(([, d]) => d.minFloor <= s.floor && d.weight > 0)
    .map(([k, d]) => [k, d.weight] as [TrapKind, number]);
  let tries = 0;
  while (s.traps.length < count && tries++ < count * 60) {
    const x = R.int(s, 1, m.width - 2);
    const y = R.int(s, 1, m.height - 2);
    const p = { x, y };
    if (tileAt(m, x, y) !== 'floor') continue;
    if (chebyshev(p, start) < 8) continue;
    const r = m.roomAt[idx(m, x, y)];
    if (r >= 0 && m.rooms[r].kind !== 'normal') continue;
    if (trapAt(s, p) || s.monsters.some((mo) => mo.pos.x === x && mo.pos.y === y)) continue;
    if (s.items.some((e) => e.pos.x === x && e.pos.y === y)) continue;
    s.traps.push({ uid: `t${s.floor}_${s.traps.length}`, pos: p, kind: R.weighted(s, pool), hidden: true, owner: 'dungeon' });
  }
}

// ================================================================ Entdecken

export function detectChance(s: GameState, t: Trap, dist: number): number {
  const int = effectiveStats(s).int;
  const base = 12 + (int - 5) * 4 + skillLevel(s, 'fallenkunde') * 6 + skillLevel(s, 'wahrnehmung') * 3 - TRAP_DEFS[t.kind].hide - (dist - 1) * 6;
  return Math.max(3, Math.min(90, base)) / 100;
}

/** Nach jeder Bewegung: nahe, sichtbare Fallen können auffallen. */
export function detectTraps(s: GameState, vis: Set<number>) {
  const p = s.player.pos;
  for (const t of traps(s)) {
    if (!t.hidden) continue;
    const d = chebyshev(t.pos, p);
    if (d > 2 || d === 0 || !vis.has(idx(s.map, t.pos.x, t.pos.y))) continue;
    if (!R.chance(s, detectChance(s, t, d))) continue;
    t.hidden = false;
    s.counters.trapsFound += 1;
    log(s, `Du bemerkst eine ${trapName(t.kind)} im Boden. Das war knapp.`, 'gefahr');
    emit(s, { type: 'trapDetected', kind: t.kind });
  }
}

// ================================================================ Auslösen

function hurtPlayer(s: GameState, dmg: number, cause: string): boolean {
  s.player.hp -= dmg;
  s.counters.damageTaken += dmg;
  if (s.player.hp <= 0) {
    handleLethal(s, cause);
    return s.status !== 'playing';
  }
  return false;
}

/**
 * Der Crawler betritt ein Feld. Versteckte Dungeon-Fallen lösen aus; bekannte
 * kann man vorsichtig überqueren (Geschick). Eigene Fallen sind harmlos für dich.
 */
export function onPlayerStep(s: GameState) {
  const t = trapAt(s, s.player.pos);
  if (!t || t.owner === 'crawler') return;
  if (!t.hidden) {
    const ges = effectiveStats(s).ges;
    const safe = Math.min(0.95, 0.6 + (ges - 5) * 0.04 + skillLevel(s, 'fallenkunde') * 0.04);
    if (R.chance(s, safe)) {
      log(s, `Du steigst vorsichtig über die ${trapName(t.kind)}.`, 'info');
      return;
    }
    log(s, `Du steigst über die ${trapName(t.kind)} – und rutschst ab.`, 'gefahr');
  }
  springOnPlayer(s, t);
}

export function springOnPlayer(s: GameState, t: Trap) {
  const p = s.player;
  const f = s.floor;
  t.hidden = false;
  removeTrap(s, t);
  s.counters.trapsTriggered += 1;
  emit(s, { type: 'trapTriggered', kind: t.kind, onPlayer: true });
  switch (t.kind) {
    case 'pfeilplatte': {
      const dmg = R.int(s, 3, 6) + f * 2;
      log(s, `KLICK. Aus der Wand schießen Pfeile. ${dmg} Schaden.`, 'gefahr');
      hurtPlayer(s, dmg, 'von einer Pfeilfalle durchlöchert');
      break;
    }
    case 'fallgrube': {
      const dmg = R.int(s, 2, 5) + f;
      log(s, `Der Boden gibt nach! Du fällst in eine Grube. ${dmg} Schaden, und herausklettern dauert.`, 'gefahr');
      p.immobile = Math.max(p.immobile ?? 0, 2);
      hurtPlayer(s, dmg, 'in einer Fallgrube gestorben');
      break;
    }
    case 'giftgas':
      log(s, 'Zischen. Grünes Gas steigt aus einer Düse im Boden.', 'gefahr');
      poison(s, 'Giftgasfalle', 1 + Math.floor(f / 2));
      break;
    case 'stolperdraht': {
      log(s, 'Du bleibst an einem Draht hängen. Dutzende Blechdosen scheppern durch den Gang. Alles in der Nähe weiß jetzt, wo du bist.', 'gefahr');
      makeNoise(s, p.pos, 12);
      hurtPlayer(s, 1, 'über einen Stolperdraht gefallen');
      break;
    }
    case 'baerenfalle': {
      const dmg = R.int(s, 4, 8) + f;
      log(s, `KLACK! Eine Bärenfalle schnappt um dein Bein zu. ${dmg} Schaden. Du steckst fest.`, 'gefahr');
      p.immobile = Math.max(p.immobile ?? 0, 3);
      hurtPlayer(s, dmg, 'in einer Bärenfalle verblutet');
      break;
    }
    default:
      break;
  }
}

/** Festgehalten: Bewegungsversuch. Gibt true zurück, wenn man frei ist. */
export function struggle(s: GameState): boolean {
  const p = s.player;
  if (!p.immobile) return true;
  const str = effectiveStats(s).str;
  trainSkill(s, 'struggle', 1);
  if (R.chance(s, Math.min(0.9, 0.1 + (str - 5) * 0.05 + skillLevel(s, 'entfesseln') * 0.08))) {
    p.immobile = 0;
    track(s, 'befreit');
    if (s.monsters.some((m) => m.aware && chebyshev(m.pos, p.pos) <= 2)) track(s, 'befreit.kampf');
    log(s, 'Mit aller Kraft reißt du dich los.', 'info');
    return true;
  }
  log(s, 'Du zerrst und ziehst, kommst aber nicht frei.', 'info');
  return false;
}

// ================================================================ Entschärfen

export function disarmChance(s: GameState, t: Trap): number {
  const ges = effectiveStats(s).ges;
  const base = 40 + (ges - 5) * 3 + skillLevel(s, 'fallenkunde') * 8 - TRAP_DEFS[t.kind].fiddly;
  return Math.max(10, Math.min(95, base)) / 100;
}

/** Bekannte Fallen neben dem Crawler (oder unter ihm). */
export function disarmableTraps(s: GameState): Trap[] {
  return traps(s).filter((t) => !t.hidden && chebyshev(t.pos, s.player.pos) <= 1);
}

export function disarm(s: GameState, uid: string): { ok: boolean; message?: string } {
  const t = traps(s).find((x) => x.uid === uid);
  if (!t || t.hidden) return { ok: false, message: 'Hier ist keine bekannte Falle.' };
  if (chebyshev(t.pos, s.player.pos) > 1) return { ok: false, message: 'Dafür musst du direkt daneben stehen.' };
  if (t.owner === 'crawler') {
    removeTrap(s, t);
    const id = OWN_TRAP_ITEM[t.kind];
    if (id) addToInventory(s, createItem(s, id));
    log(s, `Du baust deine ${trapName(t.kind)} wieder ab und steckst sie ein.`, 'info');
    return { ok: true };
  }
  if (R.chance(s, disarmChance(s, t))) {
    removeTrap(s, t);
    const parts = createItem(s, 'fallenteile');
    addToInventory(s, parts);
    s.counters.trapsDisarmed += 1;
    log(s, `Vorsichtig löst du die ${trapName(t.kind)}. Geschafft! Du nimmst die Fallenteile mit.`, 'loot');
    emit(s, { type: 'trapDisarmed', kind: t.kind, success: true });
    return { ok: true };
  }
  emit(s, { type: 'trapDisarmed', kind: t.kind, success: false });
  if (R.chance(s, 0.5)) {
    log(s, `Deine Finger rutschen ab. Die ${trapName(t.kind)} löst aus!`, 'gefahr');
    springOnPlayer(s, t);
  } else {
    log(s, `Etwas klickt bedrohlich. Du ziehst die Hand zurück. Die ${trapName(t.kind)} ist noch scharf.`, 'info');
  }
  return { ok: true };
}

// ================================================================ Eigene Fallen

export function placeOwnTrap(s: GameState, item: Item): { ok: boolean; message?: string } {
  const p = s.player;
  if (!item.trapKind) return { ok: false, message: 'Das ist keine Falle.' };
  if (isInSafeRoom(s, p.pos)) return { ok: false, message: 'Im Safe Room sind Fallen verboten.' };
  if (tileAt(s.map, p.pos.x, p.pos.y) === 'stairs') return { ok: false, message: 'Nicht auf der Treppe.' };
  if (trapAt(s, p.pos)) return { ok: false, message: 'Hier ist schon eine Falle.' };
  traps(s).push({ uid: `c${s.turn}_${traps(s).length}`, pos: { ...p.pos }, kind: item.trapKind, hidden: false, owner: 'crawler' });
  log(s, `Du stellst eine ${trapName(item.trapKind)} auf. Jetzt nur noch jemanden hierher locken.`, 'info');
  emit(s, { type: 'trapPlaced', kind: item.trapKind });
  return { ok: true };
}

function trapFacets(s: GameState, m: Monster, part: 'falle' | 'bombe'): string[] {
  return [`t:${part}`, ...targetFacets(s, m), ...selfFacets(s)];
}

/** Ein Monster betritt ein Feld: eigene Fallen des Crawlers lösen aus. */
export function onMonsterStep(s: GameState, m: Monster) {
  const t = trapAt(s, m.pos);
  if (!t || t.owner !== 'crawler' || !s.monsters.includes(m)) return;
  removeTrap(s, t);
  const skill = skillLevel(s, 'fallenkunde');
  const facets = trapFacets(s, m, 'falle');
  const seen = playerSees(s, m.pos);
  const who = NameOf(s, m);
  emit(s, { type: 'trapTriggered', kind: t.kind, onPlayer: false });
  switch (t.kind) {
    case 'stachelfalle': {
      const dmg = Math.max(1, R.int(s, 6, 10) + s.floor * 2 + skill * 2 - Math.floor(m.ruestung / 2));
      m.hp -= dmg;
      log(s, seen ? `${who} tritt in deine Stachelfalle. ${dmg} Schaden.` : 'Irgendwo schnappt deine Stachelfalle zu. Ein Schrei hallt durch die Gänge.', 'kampf');
      if (m.hp <= 0) killMonster(s, m, null, false, facets);
      break;
    }
    case 'schlingfalle': {
      m.downed = Math.max(m.downed, 4);
      m.hp -= 2;
      log(s, seen ? `${who} verfängt sich in deiner Schlingfalle und stürzt zu Boden.` : 'In der Ferne zieht sich deine Schlingfalle zu.', 'kampf');
      if (m.hp <= 0) killMonster(s, m, null, false, facets);
      break;
    }
    case 'sprengfalle':
      log(s, seen ? `${who} löst deine Sprengfalle aus. BUMM!` : 'Irgendwo geht deine Sprengfalle hoch. BUMM!', 'kampf');
      blast(s, m.pos, R.int(s, 10, 15) + s.floor * 2 + skill * 2, 'falle', 'von der eigenen Sprengfalle zerlegt');
      break;
    default:
      break;
  }
}

/**
 * Explosion im Umkreis von einem Feld (Sprengsätze, Sprengfallen).
 * Trifft Monster, das Haustier und den Crawler.
 */
export function blast(s: GameState, at: Pos, dmg: number, part: 'falle' | 'bombe', selfCause: string, cond?: ThrowCondition) {
  makeNoise(s, at, 10);
  for (const o of [...s.monsters]) {
    if (chebyshev(o.pos, at) > 1) continue;
    const hit = Math.max(1, dmg - Math.floor(o.ruestung / 2));
    const facets = trapFacets(s, o, part);
    o.hp -= hit;
    o.aware = true;
    o.provoked = true;
    if (playerSees(s, o.pos)) log(s, `Die Explosion trifft ${nameOf(s, o)} für ${hit} Schaden.`, 'kampf');
    if (o.hp <= 0) killMonster(s, o, null, false, facets);
    // Feuer und Splitter wirken nach
    else if (cond) inflict(s, o, cond.id, cond.turns, cond.power + Math.floor(s.player.level / 4));
  }
  const pet = s.player.pet;
  if (pet?.alive && chebyshev(pet.pos, at) <= 1) {
    pet.hp -= Math.ceil(dmg / 2);
    if (pet.hp <= 0) {
      pet.hp = 0;
      pet.alive = false;
      log(s, `${pet.name} wird von der Explosion umgeworfen und verschwindet bewusstlos in einem Transportlicht.`, 'gefahr');
    }
  }
  if (s.status === 'playing' && chebyshev(s.player.pos, at) <= 1) {
    const raw = Math.max(1, Math.round(dmg * 0.6 * (1 - Math.min(0.75, skillLevel(s, 'sprengmeister') * 0.05))));
    const taken = hasSpecial(s, 'explosionsschutz') ? Math.ceil(raw / 2) : raw;
    log(s, `Du stehst zu nah dran. Die Druckwelle erwischt dich für ${taken} Schaden.`, 'gefahr');
    if (!hurtPlayer(s, taken, selfCause)) {
      emit(s, { type: 'explosion', damage: taken, source: 'eigener Sprengsatz' });
      if (cond && s.status === 'playing') inflictPlayer(s, cond.id, Math.max(1, cond.turns - 1), cond.power, 'Die Druckwelle');
    }
  }
}

/** Monster sehen ihre eigenen Dungeon-Fallen – bekannte Fallen meidet der Klick-Pfad. */
export function avoidTile(s: GameState, x: number, y: number): boolean {
  const t = trapAt(s, { x, y });
  return !!t && !t.hidden && t.owner === 'dungeon';
}
