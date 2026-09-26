import { describe, expect, it } from 'vitest';
import { monsterTurn, petTurn } from '../src/engine/ai';
import { buyOffer, haggleOffer, moveStep, newGame, sellItem, useItem, wait } from '../src/engine/game';
import { createItem } from '../src/engine/items';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import type { GameState } from '../src/engine/types';

const make = (seed = 1600) => newGame({ name: 'Test', answers: { beruf: 1, haustier: 3 }, seed, meta: emptyMeta() });

function tutorial(s: GameState) {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
}

function enterSafe(s: GameState) {
  const safe = s.map.rooms.find((r) => r.kind === 'safe')!;
  s.player.pos = { x: safe.x + 1, y: safe.y + 1 };
  s.monsters = [];
  moveStep(s, { x: safe.x + 2, y: safe.y + 1 });
  return safe;
}

function besideMe(s: GameState, id: string) {
  const p = s.player.pos;
  const spot = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1]].map(([dx, dy]) => ({ x: p.x + dx, y: p.y + dy })).find((q) => isWalkable(s.map, q.x, q.y) && !s.monsters.some((m) => m.pos.x === q.x && m.pos.y === q.y))!;
  const m = spawnMonster(s, monsterDefById(id)!, 2, spot, 0);
  s.monsters.push(m);
  return m;
}

describe('Laden', () => {
  it('Safe Rooms haben einen Laden: kaufen, verkaufen, feilschen', () => {
    const s = make();
    tutorial(s);
    const room = enterSafe(s);
    expect(room.shop?.offers.length).toBeGreaterThan(5);
    s.player.gold = 1000;
    const count = room.shop!.offers.length;
    expect(buyOffer(s, 0).ok).toBe(true);
    expect(room.shop!.offers.length).toBe(count - 1);
    expect(s.player.gold).toBeLessThan(1000);
    expect(haggleOffer(s, 0).ok).toBe(true);
    expect(haggleOffer(s, 0).ok).toBe(false); // nur einmal
    const junk = createItem(s, 'bauhelm');
    s.player.inventory.push(junk);
    const gold = s.player.gold;
    expect(sellItem(s, junk.uid).ok).toBe(true);
    expect(s.player.gold).toBeGreaterThan(gold);
  });

  it('außerhalb des Safe Rooms kann man nicht verkaufen', () => {
    const s = make();
    tutorial(s);
    const junk = createItem(s, 'bauhelm');
    s.player.inventory.push(junk);
    expect(sellItem(s, junk.uid).ok).toBe(false);
  });
});

describe('Pässe und Talismane', () => {
  it('ein Kobold-Tattoo schützt vor Kobolden, bis man sie angreift', () => {
    const s = make();
    tutorial(s);
    const tattoo = createItem(s, 'tattoo_kobold');
    s.player.inventory.push(tattoo);
    expect(useItem(s, tattoo.uid).ok).toBe(true);
    const k = besideMe(s, 'kobold');
    k.aware = true;
    k.treffer = 999;
    const hp = s.player.hp;
    for (let i = 0; i < 5; i++) monsterTurn(s, k);
    expect(s.player.hp).toBe(hp);
    k.provoked = true;
    k.aware = true;
    for (let i = 0; i < 5 && s.player.hp === hp; i++) {
      k.pos = besideMe(s, 'kellerratte').pos;
      s.monsters = s.monsters.filter((m) => m.defId !== 'kellerratte');
      monsterTurn(s, k);
    }
    expect(s.player.hp).toBeLessThan(hp);
  });
});

describe('Haustiere', () => {
  it('ein Ei schlüpft nach einiger Zeit im Inventar', () => {
    const s = make();
    tutorial(s);
    s.monsters = [];
    s.player.inventory.push(createItem(s, 'ei_raptor'));
    for (let i = 0; i < 170 && !s.player.pet; i++) {
      s.monsters = [];
      s.player.hp = 100;
      wait(s);
    }
    expect(s.player.pet?.species).toBe('Kellerraptor');
    expect(s.achievements.length).toBeGreaterThan(0);
  });

  it('geschwächte Tiere lassen sich mit einem Leckerli zähmen', () => {
    let tamed = false;
    for (let seed = 1; seed < 20 && !tamed; seed++) {
      const s = make(1700 + seed);
      tutorial(s);
      const w = besideMe(s, 'wolpertinger');
      w.hp = 1;
      const treat = createItem(s, 'leckerli');
      s.player.inventory.push(treat);
      useItem(s, treat.uid);
      tamed = s.player.pet?.species === 'Wolpertinger';
    }
    expect(tamed).toBe(true);
  });

  it('der Superkeks lässt das Haustier zaubern', () => {
    const s = newGame({ name: 'Test', answers: { beruf: 1, haustier: 0 }, seed: 1800, meta: emptyMeta() });
    tutorial(s);
    const keks = createItem(s, 'superkeks');
    s.player.inventory.push(keks);
    useItem(s, keks.uid);
    expect(s.player.pet?.caster).toBe(true);
    const pp = s.player.pet!.pos;
    const spot = [[2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [-1, -1], [1, -1], [-1, 1]]
      .map(([dx, dy]) => ({ x: pp.x + dx, y: pp.y + dy }))
      .find((q) => isWalkable(s.map, q.x, q.y))!;
    const target = spawnMonster(s, monsterDefById('ghul')!, 3, spot, 0);
    target.aware = true;
    s.monsters = [target];
    const hp = target.hp;
    for (let i = 0; i < 30 && target.hp === hp; i++) petTurn(s);
    expect(target.hp).toBeLessThan(hp);
  });
});

describe('Rubbellose', () => {
  it('liefern verschiedene Ergebnisse', () => {
    const outcomes = new Set<string>();
    const s = make();
    tutorial(s);
    for (let i = 0; i < 60; i++) {
      const lot = createItem(s, 'rubbellos');
      s.player.inventory.push(lot);
      const before = s.log.length;
      useItem(s, lot.uid);
      const text = s.log.slice(before).map((l) => l.text).join(' ');
      if (text.includes('NICHT GEWONNEN')) outcomes.add('niete');
      else if (text.includes('Gold')) outcomes.add('gold');
      else outcomes.add('anders');
      s.monsters = [];
    }
    expect(outcomes.size).toBeGreaterThanOrEqual(3);
  });
});
