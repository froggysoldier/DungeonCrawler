import { describe, expect, it } from 'vitest';
import { monsterTurn } from '../src/engine/ai';
import { addBladder } from '../src/engine/bladder';
import { cast, moveStep, newGame, toilet, useItem, wait } from '../src/engine/game';
import { createItem } from '../src/engine/items';
import { createTome, learnSpell, maxMp } from '../src/engine/magic';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import type { GameState } from '../src/engine/types';

const make = () => newGame({ name: 'Test', answers: { beruf: 1 }, seed: 1500, meta: emptyMeta() });

function tutorial(s: GameState) {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
}

function besideMe(s: GameState, id: string) {
  const p = s.player.pos;
  const spot = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => ({ x: p.x + dx, y: p.y + dy })).find((q) => isWalkable(s.map, q.x, q.y))!;
  const m = spawnMonster(s, monsterDefById(id)!, 2, spot, 0);
  m.aware = true;
  s.monsters.push(m);
  return m;
}

describe('Magie', () => {
  it('das Tutorial schenkt den Heilzauber und Mana', () => {
    const s = make();
    tutorial(s);
    expect(s.player.spells?.map((k) => k.id)).toContain('heilen');
    expect(s.player.mp).toBe(maxMp(s));
  });

  it('Heilen kostet Mana und heilt', () => {
    const s = make();
    tutorial(s);
    s.player.hp = 3;
    const mp = s.player.mp!;
    expect(cast(s, 'heilen').ok).toBe(true);
    expect(s.player.hp).toBeGreaterThan(3);
    expect(s.player.mp).toBe(mp - 2);
    expect(cast(s, 'heilen').ok).toBe(false); // Abklingzeit
  });

  it('Zauberbücher lehren Zauber und verschwinden', () => {
    const s = make();
    tutorial(s);
    const book = createTome(s, 'geschoss');
    s.player.inventory.push(book);
    expect(useItem(s, book.uid).ok).toBe(true);
    expect(s.player.spells?.some((k) => k.id === 'geschoss')).toBe(true);
    expect(s.player.inventory.some((i) => i.uid === book.uid)).toBe(false);
  });

  it('Magisches Geschoss: mehr Mana, mehr Schaden', () => {
    const s = make();
    tutorial(s);
    learnSpell(s, 'geschoss', true);
    s.player.stats.int = 20;
    s.player.mp = 20;
    const a = besideMe(s, 'moorleiche');
    a.maxHp = a.hp = 500;
    cast(s, 'geschoss', { targetUid: a.uid, mana: 3 });
    const low = 500 - a.hp;
    s.player.spellCooldowns = {};
    a.hp = 500;
    cast(s, 'geschoss', { targetUid: a.uid, mana: 6 });
    const high = 500 - a.hp;
    expect(high).toBeGreaterThan(low);
    expect(cast(s, 'geschoss', { mana: 3 }).ok).toBe(false); // ohne Ziel
  });

  it('Irrlichtrüstung fängt Schaden ab', () => {
    const s = make();
    tutorial(s);
    learnSpell(s, 'irrlichtruestung', true);
    s.player.mp = 10;
    cast(s, 'irrlichtruestung');
    const m = besideMe(s, 'kobold');
    m.treffer = 999;
    m.dmg = [3, 3];
    const hp = s.player.hp;
    monsterTurn(s, m);
    expect(s.player.hp).toBe(hp);
  });
});

describe('Tränke', () => {
  it('Heiltränke heilen die Hälfte, danach Abklingzeit', () => {
    const s = make();
    tutorial(s);
    s.player.hp = 1;
    const a = createItem(s, 'heiltrank', 2);
    s.player.inventory.push(a);
    expect(useItem(s, a.uid).ok).toBe(true);
    expect(s.player.hp).toBeGreaterThanOrEqual(1 + Math.floor(0.5 * 20));
    expect(useItem(s, a.uid).ok).toBe(false);
  });
});

describe('Toiletten-Regel', () => {
  it('ein Unfall ruft ein Wutelementar herbei', () => {
    const s = make();
    tutorial(s);
    s.monsters = [];
    addBladder(s, 100);
    expect(s.monsters.some((m) => m.defId === 'wutelementar')).toBe(true);
    expect(s.player.blase).toBe(0);
  });

  it('die Toilette gibt es nur im Safe Room', () => {
    const s = make();
    tutorial(s);
    s.player.blase = 70;
    expect(toilet(s).ok).toBe(false);
    const safe = s.map.rooms.find((r) => r.kind === 'safe')!;
    s.player.pos = { x: safe.x + 1, y: safe.y + 1 };
    moveStep(s, { x: safe.x + 2, y: safe.y + 1 });
    expect(toilet(s).ok).toBe(true);
    expect(s.player.blase).toBeLessThan(1);
  });

  it('die Blase füllt sich mit der Zeit', () => {
    const s = make();
    tutorial(s);
    s.monsters = [];
    const before = s.player.blase ?? 0;
    for (let i = 0; i < 60; i++) wait(s);
    expect(s.player.blase).toBeGreaterThan(before + 8);
  });
});
