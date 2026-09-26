import { it } from 'vitest';
import { attack, descend, equip, moveStep, newGame, openBox, pickup, sleep, useItem, wait } from '../src/engine/game';
import { findPath } from '../src/engine/path';
import { maxHp } from '../src/engine/player';
import { emptyMeta } from '../src/engine/meta';
import type { GameState, Pos } from '../src/engine/types';
import { isInSafeRoom, techniqueBlocker } from '../src/engine/combat';
import { chooseRaceAndClass, classOptions, useAbility } from '../src/engine/classes';

const cheb = (a: Pos, b: Pos) => Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));
const center = (r: { x: number; y: number; w: number; h: number }) => ({ x: r.x + Math.floor(r.w / 2), y: r.y + Math.floor(r.h / 2) });

function goTo(s: GameState, target: Pos): boolean {
  const lairs = new Set(s.monsters.filter((m) => m.homeRoom !== undefined).map((m) => m.homeRoom!));
  const targetRoom = s.map.roomAt[target.y * s.map.width + target.x];
  const path = findPath(s.map, s.player.pos, target, (x, y) => {
    const r = s.map.roomAt[y * s.map.width + x];
    if (r >= 0 && lairs.has(r) && r !== targetRoom) return false;
    return !s.monsters.some((m) => m.pos.x === x && m.pos.y === y);
  }, 8000);
  if (!path?.length) return false;
  return moveStep(s, path[0]).ok;
}

function fight(s: GameState): boolean {
  const adj = s.monsters.filter((m) => cheb(m.pos, s.player.pos) <= 1).sort((a, b) => a.hp - b.hp)[0];
  if (!adj) return false;
  const options = [
    { part: 'tritt', move: 'stampfen' },
    { part: 'tritt', move: 'normal' },
    { part: 'faust', move: 'normal' },
  ] as const;
  for (const t of options) {
    if (!techniqueBlocker(s, adj, t)) {
      attack(s, adj.uid, t);
      return true;
    }
  }
  wait(s);
  return true;
}

function runBot(seed: number, maxFloor = 3) {
  const s = newGame({ name: 'Bot', answers: [seed % 9, seed % 4, 3, seed % 5, seed % 4], seed, meta: emptyMeta() });
  s.pendingDialogs = [];
  let phase: 'guild' | 'clear' | 'stairs' = 'guild';
  let guard = 0;
  let floor = 1;
  while (s.status === 'playing' && guard++ < 18000) {
    const p = s.player;
    if (s.floor > maxFloor) break;
    if (s.floor !== floor) {
      floor = s.floor;
      phase = 'clear';
      s.pendingDialogs = [];
    }
    if (s.pendingSelection) {
      chooseRaceAndClass(s, 'mensch', classOptions(s)[0].klass.id);
      continue;
    }
    if (p.klass && !p.abilityCooldown && s.monsters.some((m) => cheb(m.pos, p.pos) <= 1)) {
      if (useAbility(s, { part: 'tritt', move: 'normal' }).ok) continue;
    }
    // Heilen
    if (p.hp < maxHp(s) * 0.35) {
      const pot = p.inventory.find((i) => i.kind === 'verbrauch' && i.effekt?.heal);
      if (pot) {
        useItem(s, pot.uid);
        continue;
      }
      const safe = s.map.rooms.filter((r) => r.kind === 'safe').sort((a, b) => cheb(center(a), p.pos) - cheb(center(b), p.pos))[0];
      if (safe && !isInSafeRoom(s, p.pos)) {
        if (fight(s)) continue;
        goTo(s, center(safe));
        continue;
      }
      if (safe) {
        for (const b of [...p.boxes]) openBox(s, b.uid);
        for (const it of [...p.inventory]) if (it.kind === 'ausruestung') equip(s, it.uid);
        if (!sleep(s).ok) wait(s);
        continue;
      }
    }
    if (fight(s)) continue;
    if (s.items.some((e) => e.pos.x === p.pos.x && e.pos.y === p.pos.y && e.item.kind !== 'wurf')) pickup(s);
    if (phase === 'guild') {
      if (s.unlocks.includes('inventar')) {
        phase = 'clear';
        continue;
      }
      const g = s.map.rooms.filter((r) => r.kind === 'guild').sort((a, b) => cheb(center(a), p.pos) - cheb(center(b), p.pos))[0];
      if (!goTo(s, center(g))) wait(s);
      continue;
    }
    if (phase === 'clear') {
      // Normale Mobs in der Nähe jagen, bis Level 4, dann Bosse
      const targets = s.monsters
        .filter((m) => (p.level < 5 ? m.rank === 'normal' || m.rank === 'elite' : m.rank === 'nachbarschaftsboss') && m.level <= p.level + 3)
        .sort((a, b) => cheb(a.pos, p.pos) - cheb(b.pos, p.pos));
      const t = targets[0];
      if (!t || s.turn - s.floorStartTurn > 1700) {
        phase = 'stairs';
        continue;
      }
      if (!goTo(s, t.pos)) wait(s);
      continue;
    }
    // Treppe: die nächste außerhalb der Arena bevorzugen
    const stairs: Pos[] = [];
    s.map.tiles.forEach((tile, i) => tile === 'stairs' && stairs.push({ x: i % s.map.width, y: Math.floor(i / s.map.width) }));
    stairs.sort((a, b) => cheb(a, p.pos) - cheb(b, p.pos));
    if (stairs.some((q) => q.x === p.pos.x && q.y === p.pos.y)) {
      descend(s, { ghosts: [] });
      continue;
    }
    if (!goTo(s, stairs[0])) wait(s);
  }
  return s;
}

// Nur auf Wunsch: SIM=1 npx vitest run tests/balance.sim.test.ts
const enabled = !!(globalThis as { process?: { env?: Record<string, string> } }).process?.env?.SIM;

it.runIf(enabled)('Balance-Simulation Etage 1', () => {
  const results = [];
  for (let seed = 1; seed <= 30; seed++) {
    const s = runBot(seed);
    results.push({
      seed,
      status: s.status === 'victory' ? 'SIEG' : `E${s.floor} ${s.status}`,
      level: s.player.level,
      kills: s.counters.kills,
      turn: s.turn,
      klasse: s.player.klass ?? '-',
      follower: s.viewers.follower,
      ach: s.achievements.length,
      bosses: s.counters.bossKills,
      cause: s.deathCause ?? '',
    });
  }
  console.table(results);
  for (const f of [2, 3]) console.log(`Etage ${f} erreicht: ${results.filter((r) => r.status === 'SIEG' || Number(r.status[1]) >= f).length}/30`);
  console.log(`Etage 3 überlebt: ${results.filter((r) => r.status === 'SIEG').length}/30`);
}, 120_000);
