import { describe, expect, it } from 'vitest';
import { closeDoor, moveStep, newGame } from '../src/engine/game';
import { idx, tileAt } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { findPath } from '../src/engine/path';
import type { GameState, Pos } from '../src/engine/types';

const make = (seed: number) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function doorsOf(s: GameState, kind: 'guild' | 'safe'): Pos[] {
  const out: Pos[] = [];
  for (const r of s.map.rooms.filter((x) => x.kind === kind)) {
    for (let y = r.y - 1; y <= r.y + r.h; y++) for (let x = r.x - 1; x <= r.x + r.w; x++) {
      if (tileAt(s.map, x, y) === 'door') out.push({ x, y });
    }
  }
  return out;
}

describe('Türen', () => {
  it('jede Gilde und jeder Safe Room hat Türen und ist durch sie erreichbar', () => {
    for (const seed of [11, 12, 13, 14, 15, 16]) {
      const s = make(seed);
      for (const r of s.map.rooms.filter((x) => x.kind === 'guild' || x.kind === 'safe')) {
        const c = { x: r.x + Math.floor(r.w / 2), y: r.y + Math.floor(r.h / 2) };
        expect(findPath(s.map, s.player.pos, c, () => true, 20000, false), `ohne Türen zu (${seed})`).toBeNull();
        expect(findPath(s.map, s.player.pos, c, () => true, 20000, true), `durch Türen erreichbar (${seed})`).not.toBeNull();
      }
      expect(doorsOf(s, 'safe').length).toBeGreaterThanOrEqual(1);
      expect(doorsOf(s, 'guild').length).toBeGreaterThanOrEqual(1);
    }
  });

  it('eine Tür muss erst geöffnet werden, bevor man hindurchgeht, und lässt sich wieder schließen', () => {
    const s = make(21);
    const door = doorsOf(s, 'guild')[0];
    const front = [[1, 0], [-1, 0], [0, 1], [0, -1]]
      .map(([dx, dy]) => ({ x: door.x + dx, y: door.y + dy }))
      .find((q) => tileAt(s.map, q.x, q.y) === 'floor' && s.map.roomAt[idx(s.map, q.x, q.y)] === -1)!;
    s.player.pos = front;
    s.monsters = [];
    const turn = s.turn;
    expect(moveStep(s, door).ok).toBe(true);
    expect(s.player.pos).toEqual(front);
    expect(tileAt(s.map, door.x, door.y)).toBe('dooropen');
    expect(s.turn).toBe(turn + 1);
    expect(moveStep(s, door).ok).toBe(true);
    expect(s.player.pos).toEqual(door);
    moveStep(s, front);
    s.monsters = [];
    expect(closeDoor(s, door).ok).toBe(true);
    expect(tileAt(s.map, door.x, door.y)).toBe('door');
  });
});
