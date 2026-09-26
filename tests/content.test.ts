import { describe, expect, it } from 'vitest';
import { ACHIEVEMENTS } from '../src/data/achievements';
import { BASE_ITEMS, UNIQUE_ITEMS } from '../src/data/items';
import { HOOD_BOSSES, MONSTERS } from '../src/data/monsters';
import { SKILLS } from '../src/data/skills';
import { monsterTurn } from '../src/engine/ai';
import { attack, endTurn, newGame, useItem } from '../src/engine/game';
import { baseExists, createItem } from '../src/engine/items';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import type { GameState, Monster } from '../src/engine/types';

const make = (seed = 500) => newGame({ name: 'Test', answers: [0, 0, 3, 0, 0], seed, meta: emptyMeta() });

function besideMe(s: GameState, id: string, level = 2): Monster {
  s.monsters = [];
  const p = s.player.pos;
  const spot = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, -1]].map(([dx, dy]) => ({ x: p.x + dx, y: p.y + dy })).find((q) => isWalkable(s.map, q.x, q.y))!;
  const m = spawnMonster(s, monsterDefById(id)!, level, spot, 0);
  m.aware = true;
  s.monsters.push(m);
  return m;
}

describe('Inhalte sind konsistent', () => {
  it('eindeutige IDs', () => {
    for (const list of [MONSTERS.map((m) => m.id), HOOD_BOSSES.map((b) => b.id), ACHIEVEMENTS.map((a) => a.id), SKILLS.map((k) => k.id), [...BASE_ITEMS, ...UNIQUE_ITEMS].map((i) => i.id)]) {
      expect(new Set(list).size).toBe(list.length);
    }
  });

  it('jede Boss-Beute existiert als Item', () => {
    for (const b of HOOD_BOSSES) for (const id of b.loot) expect(baseExists(id), id).toBe(true);
  });

  it('jede Etage 1–3 hat Monster und Bosse', () => {
    for (const f of [1, 2, 3]) {
      expect(MONSTERS.filter((m) => m.floors.includes(f)).length).toBeGreaterThanOrEqual(8);
      expect(HOOD_BOSSES.filter((b) => b.rank === 'boroughboss' && b.floors.includes(f)).length).toBe(1);
      expect(HOOD_BOSSES.filter((b) => b.rank === 'nachbarschaftsboss' && b.floors.includes(f)).length).toBeGreaterThanOrEqual(4);
    }
  });

  it('Umfang: viele Monster, Items und Achievements', () => {
    expect(MONSTERS.length).toBeGreaterThanOrEqual(40);
    expect(BASE_ITEMS.length + UNIQUE_ITEMS.length).toBeGreaterThanOrEqual(150);
    expect(ACHIEVEMENTS.length).toBeGreaterThanOrEqual(120);
  });
});

describe('Monster-Fähigkeiten', () => {
  it('Gift schadet jeden Zug und Gegengift heilt es', () => {
    const s = make();
    const spider = besideMe(s, 'kellerspinne');
    spider.treffer = 999;
    for (let i = 0; i < 20 && !s.player.buffs.some((b) => b.name === 'Vergiftet'); i++) {
      s.player.hp = 100;
      monsterTurn(s, spider);
    }
    expect(s.player.buffs.some((b) => b.name === 'Vergiftet')).toBe(true);
    expect(s.achievements).toContain('vergiftet');
    s.monsters = [];
    const hp = s.player.hp;
    endTurn(s);
    expect(s.player.hp).toBeLessThan(hp + 1);
    s.unlocks.push('inventar');
    const antidote = createItem(s, 'gegengift');
    s.player.inventory.push(antidote);
    useItem(s, antidote.uid);
    expect(s.player.buffs.some((b) => b.name === 'Vergiftet')).toBe(false);
  });

  it('Blähkröten explodieren beim Tod und treffen dich', () => {
    const s = make(501);
    const toad = besideMe(s, 'blaehkroete');
    toad.hp = 1;
    toad.ausweichen = -500;
    const hp = s.player.hp;
    attack(s, toad.uid, { part: 'faust', move: 'normal' });
    expect(s.monsters).not.toContain(toad);
    expect(s.player.hp).toBeLessThan(hp);
    expect(s.log.some((l) => l.text.includes('explodiert'))).toBe(true);
  });

  it('Diebe klauen Gold und lassen es beim Tod fallen', () => {
    const s = make(502);
    s.player.gold = 50;
    const thief = besideMe(s, 'elster_goblin');
    thief.treffer = 999;
    for (let i = 0; i < 30 && !thief.stolenGold; i++) {
      s.player.hp = 100;
      if (Math.max(Math.abs(thief.pos.x - s.player.pos.x), Math.abs(thief.pos.y - s.player.pos.y)) > 1) break;
      monsterTurn(s, thief);
    }
    expect(thief.stolenGold).toBeGreaterThan(0);
    expect(s.player.gold).toBeLessThan(50);
    expect(thief.fleeing).toBe(true);
  });

  it('Rufer holen Verstärkung', () => {
    const s = make(503);
    const shaman = besideMe(s, 'rattenschamane', 3);
    shaman.pos = { ...shaman.pos };
    for (let i = 0; i < 80 && s.monsters.length === 1; i++) {
      s.player.hp = 100;
      monsterTurn(s, shaman);
    }
    expect(s.monsters.length).toBeGreaterThan(1);
  });

  it('Fliegende Gegner kann man nicht stampfen, gepanzerte halbieren Faustschaden', async () => {
    const { techniqueBlocker } = await import('../src/engine/combat');
    const s = make(504);
    const bat = besideMe(s, 'fledermaus');
    expect(techniqueBlocker(s, bat, { part: 'tritt', move: 'stampfen' })).toMatch(/fliegt/);
  });
});
