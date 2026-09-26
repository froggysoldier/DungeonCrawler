import { describe, expect, it } from 'vitest';
import { attack, moveStep, newGame, refuelMount, rideToggle, useItem } from '../src/engine/game';
import { createItem } from '../src/engine/items';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import type { GameState, Pos } from '../src/engine/types';

const make = () => newGame({ name: 'Test', answers: { beruf: 1 }, seed: 8100, meta: emptyMeta() });

function tutorial(s: GameState) {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
  s.traps = [];
  s.crawlers = [];
}

function openRoom(s: GameState) {
  return s.map.rooms.find((r) => r.kind === 'normal' && r.w >= 7 && r.h >= 4)!;
}

describe('Reittiere und Fahrzeuge', () => {
  it('beritten legt man zwei Schritte pro Zug zurück und verbraucht Benzin', () => {
    const s = make();
    tutorial(s);
    const key = createItem(s, 'zuendschluessel_wagen');
    s.player.inventory.push(key);
    expect(useItem(s, key.uid).ok).toBe(true);
    const room = openRoom(s);
    s.player.pos = { x: room.x, y: room.y + 1 };
    expect(rideToggle(s).ok).toBe(true);
    const turn = s.turn;
    const fuel = s.player.mount!.fuel!;
    for (let i = 1; i <= 4; i++) {
      s.monsters = [];
      moveStep(s, { x: room.x + i, y: room.y + 1 });
    }
    expect(s.turn - turn).toBe(2);
    expect(s.player.mount!.fuel).toBe(fuel - 4);
    s.player.inventory.push(createItem(s, 'benzinkanister'));
    expect(refuelMount(s).ok).toBe(true);
    expect(s.player.mount!.fuel).toBeGreaterThan(fuel - 4);
  });

  it('beritten rammt Anlauf mit Zusatzschaden, auch ohne Schritt davor', () => {
    const s = make();
    tutorial(s);
    const whistle = createItem(s, 'pfeife_eber');
    s.player.inventory.push(whistle);
    useItem(s, whistle.uid);
    const room = openRoom(s);
    s.player.pos = { x: room.x + 1, y: room.y + 1 };
    const spot: Pos = { x: room.x + 2, y: room.y + 1 };
    expect(isWalkable(s.map, spot.x, spot.y)).toBe(true);
    const m = spawnMonster(s, monsterDefById('ghul')!, 3, spot, 0);
    m.hp = m.maxHp = 999;
    m.ausweichen = -200;
    s.monsters = [m];
    const t = { part: 'faust' as const, move: 'anlauf' as const };
    expect(attack(s, m.uid, t).ok).toBe(false); // zu Fuß ohne Anlauf nicht möglich
    rideToggle(s);
    expect(attack(s, m.uid, t).ok).toBe(true);
    expect(m.hp).toBeLessThan(999 - 10);
    expect(s.log.some((l) => l.text.includes('rammt'))).toBe(true);
  });

  it('im Safe Room steigt man automatisch ab', () => {
    const s = make();
    tutorial(s);
    const whistle = createItem(s, 'pfeife_pony');
    s.player.inventory.push(whistle);
    useItem(s, whistle.uid);
    const safe = s.map.rooms.find((r) => r.kind === 'safe')!;
    s.player.pos = { x: safe.x + 1, y: safe.y + 1 };
    expect(rideToggle(s).ok).toBe(false);
  });
});
