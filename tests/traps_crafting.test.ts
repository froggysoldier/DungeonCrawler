import { describe, expect, it } from 'vitest';
import { attack, craftItem, disarmTrap, moveStep, newGame, placeTrap, wait } from '../src/engine/game';
import { createItem } from '../src/engine/items';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { onMonsterStep, springOnPlayer, trapAt } from '../src/engine/traps';
import type { GameState, Pos } from '../src/engine/types';

const make = (seed = 2100) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function tutorial(s: GameState) {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
  s.traps = [];
}

function freeNeighbor(s: GameState, p: Pos): Pos {
  return [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1]]
    .map(([dx, dy]) => ({ x: p.x + dx, y: p.y + dy }))
    .find((q) => isWalkable(s.map, q.x, q.y) && !s.monsters.some((m) => m.pos.x === q.x && m.pos.y === q.y))!;
}

/** Ein normales Feld außerhalb von Safe Rooms und Gilde. */
function openSpot(s: GameState): Pos {
  const room = s.map.rooms.find((r) => r.kind === 'normal' && !/werkstatt|schmiede/i.test(r.name))!;
  return { x: room.x + 1, y: room.y + 1 };
}

describe('Fallen im Dungeon', () => {
  it('jede Etage hat versteckte Fallen, abseits von Start und Safe Rooms', () => {
    const s = make();
    expect(s.traps!.length).toBeGreaterThanOrEqual(8);
    for (const t of s.traps!) {
      expect(t.hidden).toBe(true);
      const r = s.map.roomAt[t.pos.y * s.map.width + t.pos.x];
      if (r >= 0) expect(s.map.rooms[r].kind).toBe('normal');
    }
  });

  it('eine versteckte Falle löst beim Betreten aus', () => {
    const s = make();
    tutorial(s);
    const spot = openSpot(s);
    s.player.pos = spot;
    const target = freeNeighbor(s, spot);
    s.traps = [{ uid: 'x', pos: target, kind: 'baerenfalle', hidden: true, owner: 'dungeon' }];
    const hp = s.player.hp;
    s.player.stats.str = 1; // kaum Chance, sich loszureißen
    expect(moveStep(s, target).ok).toBe(true);
    expect(s.player.hp).toBeLessThan(hp);
    expect(s.player.immobile).toBeGreaterThan(0);
    expect(trapAt(s, target)).toBeUndefined();
    // festgehalten: der nächste Schritt bleibt stehen
    const back = spot;
    s.monsters = [];
    moveStep(s, back);
    expect(s.player.pos).toEqual(target);
  });

  it('bekannte Fallen kann man entschärfen und bekommt Fallenteile', () => {
    let success = false;
    for (let seed = 0; seed < 10 && !success; seed++) {
      const s = make(2200 + seed);
      tutorial(s);
      s.player.stats.ges = 12;
      const spot = openSpot(s);
      s.player.pos = spot;
      const tp = freeNeighbor(s, spot);
      s.traps = [{ uid: 'y', pos: tp, kind: 'stolperdraht', hidden: false, owner: 'dungeon' }];
      expect(disarmTrap(s, 'y').ok).toBe(true);
      success = s.player.inventory.some((i) => i.baseId === 'fallenteile');
    }
    expect(success).toBe(true);
  });

  it('Giftgas vergiftet', () => {
    const s = make();
    tutorial(s);
    springOnPlayer(s, { uid: 'g', pos: { ...s.player.pos }, kind: 'giftgas', hidden: true, owner: 'dungeon' });
    expect(s.player.buffs.some((b) => b.name === 'Vergiftet')).toBe(true);
  });
});

describe('Handwerk', () => {
  it('aus zwei Lappen wird ein Verband', () => {
    const s = make();
    tutorial(s);
    s.player.inventory.push(createItem(s, 'lappen', 2));
    expect(craftItem(s, 'verband').ok).toBe(true);
    expect(s.player.inventory.some((i) => i.baseId === 'verband')).toBe(true);
    expect(s.player.inventory.some((i) => i.baseId === 'lappen')).toBe(false);
  });

  it('ohne Zutaten klappt nichts, und die Nagelbombe braucht eine Werkbank', () => {
    const s = make();
    tutorial(s);
    s.player.pos = openSpot(s);
    expect(craftItem(s, 'brandflasche').ok).toBe(false);
    s.player.inventory.push(createItem(s, 'dose'), createItem(s, 'naegel', 2), createItem(s, 'schwarzpulver'));
    const res = craftItem(s, 'nagelbombe');
    expect(res.ok).toBe(false);
    expect(res.message).toContain('Werkbank');
    s.player.inventory.push(createItem(s, 'klappwerkbank'));
    expect(craftItem(s, 'nagelbombe').ok).toBe(true);
    expect(s.player.inventory.find((i) => i.baseId === 'nagelbombe')?.menge).toBeGreaterThanOrEqual(2);
  });

  it('eine geworfene Brandflasche trifft mehrere Gegner', () => {
    const s = make();
    tutorial(s);
    const spot = openSpot(s);
    s.player.pos = spot;
    const far = { x: spot.x + 3, y: spot.y };
    s.player.inventory.push(createItem(s, 'brandflasche', 1));
    s.player.wurfWahl = 'brandflasche';
    const a = spawnMonster(s, monsterDefById('kellerratte')!, 1, far, 0);
    const bPos = freeNeighbor(s, far);
    const b = spawnMonster(s, monsterDefById('kellerratte')!, 1, bPos, 0);
    a.hp = a.maxHp = 200;
    b.hp = b.maxHp = 200;
    s.monsters = [a, b];
    for (let i = 0; i < 5 && s.player.inventory.some((x) => x.baseId === 'brandflasche'); i++) {
      attack(s, a.uid, { part: 'wurf', move: 'normal' });
    }
    expect(b.hp).toBeLessThan(200);
    expect(a.hp).toBeLessThan(200);
  });

  it('eigene Fallen treffen Monster, nicht den Crawler', () => {
    const s = make();
    tutorial(s);
    const spot = openSpot(s);
    s.player.pos = spot;
    const trap = createItem(s, 'stachelfalle');
    s.player.inventory.push(trap);
    expect(placeTrap(s, trap.uid).ok).toBe(true);
    expect(trapAt(s, spot)?.owner).toBe('crawler');
    const hp = s.player.hp;
    const next = freeNeighbor(s, spot);
    moveStep(s, next);
    moveStep(s, spot);
    expect(s.player.hp).toBeGreaterThanOrEqual(hp - 5); // keine Fallenwirkung (höchstens Monster)
    expect(trapAt(s, spot)).toBeDefined();
    moveStep(s, next);
    const rat = spawnMonster(s, monsterDefById('kellerratte')!, 1, spot, 0);
    s.monsters = [rat];
    const ratHp = rat.hp;
    onMonsterStep(s, rat);
    expect(rat.hp < ratHp || !s.monsters.includes(rat)).toBe(true);
    expect(trapAt(s, spot)).toBeUndefined();
    wait(s);
  });
});
