import { describe, expect, it } from 'vitest';
import { makeNoise, monsterTurn } from '../src/engine/ai';
import { moveStep, newGame } from '../src/engine/game';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import type { GameState, Pos } from '../src/engine/types';

const make = (seed = 9100) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function arena(s: GameState): { me: Pos; at: (dx: number) => Pos } {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
  s.player.pet = null;
  s.crawlers = [];
  s.traps = [];
  const room = s.map.rooms.find((r) => r.kind === 'normal' && r.w >= 9)!;
  const me = { x: room.x, y: room.y + 1 };
  s.player.pos = me;
  return { me, at: (dx) => ({ x: room.x + dx, y: room.y + 1 }) };
}

describe('Gegnerverhalten', () => {
  it('wer dich sieht, kommt auf dich zu und greift an', () => {
    const s = make();
    const { at } = arena(s);
    const ghul = spawnMonster(s, monsterDefById('ghul')!, 2, at(4), 0);
    s.monsters = [ghul];
    monsterTurn(s, ghul);
    expect(ghul.aware).toBe(true);
    expect(ghul.pos.x).toBeLessThan(at(4).x);
  });

  it('normale Gegner fliehen nicht, nur weil sie verletzt sind', () => {
    const s = make();
    const { at } = arena(s);
    const ghul = spawnMonster(s, monsterDefById('ghul')!, 2, at(3), 0);
    ghul.hp = 1;
    s.monsters = [ghul];
    for (let i = 0; i < 6; i++) monsterTurn(s, ghul);
    expect(ghul.fleeing).toBeFalsy();
  });

  it('Feiglinge laut Beschreibung halten Abstand', () => {
    const s = make();
    const { at } = arena(s);
    const gnom = spawnMonster(s, monsterDefById('gnom_buerokrat')!, 1, at(2), 0);
    s.monsters = [gnom];
    monsterTurn(s, gnom);
    monsterTurn(s, gnom);
    expect(gnom.fleeing).toBe(true);
  });

  it('Schlafende wachen erst durch Lärm auf und gehen ihm nach', () => {
    const s = make();
    const { at } = arena(s);
    const ghul = spawnMonster(s, monsterDefById('ghul')!, 2, at(5), 0);
    ghul.asleep = true;
    s.monsters = [ghul];
    for (let i = 0; i < 4; i++) monsterTurn(s, ghul);
    expect(ghul.asleep).toBe(true);
    expect(ghul.pos).toEqual(at(5));
    makeNoise(s, at(6), 6);
    expect(ghul.asleep).toBe(false);
  });

  it('entdeckte Gegner warnen ihre Artgenossen', () => {
    const s = make();
    const { at } = arena(s);
    const a = spawnMonster(s, monsterDefById('ghul')!, 2, at(3), 0);
    const b = spawnMonster(s, monsterDefById('ghul')!, 2, at(8), 0);
    s.monsters = [a, b];
    monsterTurn(s, a);
    expect(a.aware).toBe(true);
    expect(b.aware || !isWalkable(s.map, at(8).x, at(8).y)).toBe(true);
  });
});
