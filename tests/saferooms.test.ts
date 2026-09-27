import { describe, expect, it } from 'vitest';
import { BASE_ITEMS } from '../src/data/items';
import { descend, lockedLair, moveStep, newGame, useFurniture } from '../src/engine/game';
import { furnitureAt, roomOf, tileAt } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { findPath } from '../src/engine/path';
import type { GameState, Room } from '../src/engine/types';

const make = (seed: number) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function floors(seed: number): GameState[] {
  const out: GameState[] = [];
  const s = make(seed);
  out.push(structuredClone(s));
  while (s.floor < 3) {
    const i = s.map.tiles.indexOf('stairs');
    s.player.pos = { x: i % s.map.width, y: Math.floor(i / s.map.width) };
    descend(s, { ghosts: [] });
    out.push(structuredClone(s));
  }
  return out;
}

const isLair = (r: Room) => r.kind === 'boss' || r.kind === 'arena';
const MATERIAL_IDS = new Set(BASE_ITEMS.filter((b) => b.kind === 'schrott' || ['stein', 'ziegel', 'flasche', 'dose', 'schraubenmutter'].includes(b.id)).map((b) => b.id));

describe('Safe Rooms', () => {
  it('jeder Safe Room hat einen erreichbaren Gratis-Automaten, Restaurants einen Wirt', () => {
    for (const seed of [21, 22, 23]) {
      for (const s of floors(seed)) {
        for (const r of s.map.rooms.filter((x) => x.kind === 'safe')) {
          const kinds = (r.furniture ?? []).map((f) => f.kind);
          expect(kinds, `${seed}/${s.floor}/${r.name}`).toContain('automat');
          if (r.safeVariant === 'restaurant') expect(kinds).toContain('wirt');
          for (const f of r.furniture ?? []) {
            expect(furnitureAt(s.map, f.pos)).toBe(f);
            const reach = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
              const p = { x: f.pos.x + dx, y: f.pos.y + dy };
              return roomOf(s.map, p)?.id === r.id && !furnitureAt(s.map, p) && tileAt(s.map, p.x, p.y) === 'floor';
            });
            expect(reach, `${f.kind} erreichbar`).toBe(true);
          }
        }
      }
    }
  });

  it('der Automat gibt genau einen Gegenstand pro Safe Room', () => {
    const s = make(24);
    const room = s.map.rooms.find((r) => r.kind === 'safe' && r.furniture?.some((f) => f.kind === 'automat'))!;
    const auto = room.furniture!.find((f) => f.kind === 'automat')!;
    s.player.pos = { x: room.x + Math.floor(room.w / 2), y: room.y + Math.floor(room.h / 2) };
    s.currentRoom = room.id;
    expect(useFurniture(s, auto).ok).toBe(true);
    expect(s.pendingReveal?.items.length).toBe(1);
    expect(useFurniture(s, auto).ok).toBe(false);
  });
});

describe('Bodenfunde und Boss-Kammern', () => {
  it('außerhalb der Vorräume liegt nur Handwerksmaterial', () => {
    for (const seed of [31, 32, 33]) {
      for (const s of floors(seed)) {
        for (const e of s.items) {
          const r = roomOf(s.map, e.pos);
          if (r?.antechamberOf !== undefined) continue;
          expect(MATERIAL_IDS.has(e.item.baseId ?? ''), `${seed}/${s.floor}: ${e.item.baseId}`).toBe(true);
        }
      }
    }
  });

  it('jede Boss-Kammer hat Türen und einen Vorraum mit Wachen', () => {
    let lairs = 0;
    for (const seed of [41, 42, 43]) {
      for (const s of floors(seed)) {
        for (const lair of s.map.rooms.filter(isLair)) {
          lairs += 1;
          const ante = s.map.rooms.find((r) => r.antechamberOf === lair.id);
          expect(ante, `${seed}/${s.floor}`).toBeDefined();
          const c = { x: lair.x + Math.floor(lair.w / 2), y: lair.y + Math.floor(lair.h / 2) };
          expect(findPath(s.map, s.player.pos, c, () => true, 20000, false)).toBeNull();
          expect(findPath(s.map, s.player.pos, c, () => true, 20000, true)).not.toBeNull();
        }
      }
    }
    expect(lairs).toBeGreaterThan(0);
  });

  it('wer die Kammer betritt, bleibt drin, bis der Boss fällt', () => {
    for (const seed of [51, 52, 53, 54]) {
      for (const s of floors(seed)) {
        const lair = s.map.rooms.find((r) => isLair(r) && s.monsters.some((m) => m.homeRoom === r.id && (m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss')));
        if (!lair) continue;
        // Innen neben einer Tür aufstellen
        let door: { x: number; y: number } | null = null;
        let inside: { x: number; y: number } | null = null;
        for (let y = lair.y - 1; y <= lair.y + lair.h && !door; y++) for (let x = lair.x - 1; x <= lair.x + lair.w && !door; x++) {
          const t = tileAt(s.map, x, y);
          if (t !== 'door' && t !== 'dooropen') continue;
          for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
            const p = { x: x + dx, y: y + dy };
            if (roomOf(s.map, p)?.id === lair.id && tileAt(s.map, p.x, p.y) === 'floor') {
              door = { x, y };
              inside = p;
            }
          }
        }
        if (!door || !inside) continue;
        s.monsters = s.monsters.filter((m) => m.homeRoom === lair.id);
        s.player.pos = inside;
        s.currentRoom = lair.id;
        expect(lockedLair(s)?.id).toBe(lair.id);
        const res = moveStep(s, door);
        expect(res.ok).toBe(false);
        s.monsters = [];
        expect(lockedLair(s)).toBeNull();
        return;
      }
    }
    throw new Error('keine Boss-Kammer gefunden');
  });
});
