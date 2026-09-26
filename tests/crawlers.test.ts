import { describe, expect, it } from 'vitest';
import { askCrawlerTip, descend, dismissCrawler, healCrawler, inviteCrawler, moveStep, newGame, talkCrawler, wait } from '../src/engine/game';
import { crawlers, party, population } from '../src/engine/crawlers';
import { createItem } from '../src/engine/items';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import type { GameState, NpcCrawler, Personality, Pos } from '../src/engine/types';

const make = (seed = 3100) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function tutorial(s: GameState) {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
  s.traps = [];
}

function openSpot(s: GameState): Pos {
  const room = s.map.rooms.find((r) => r.kind === 'normal' && r.w >= 5)!;
  return { x: room.x + 2, y: room.y + 2 };
}

/** Stellt einen Crawler mit gewünschter Persönlichkeit direkt neben den Spieler. */
function neighbor(s: GameState, personality: Personality): NpcCrawler {
  const p = s.player.pos;
  const spot = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => ({ x: p.x + dx, y: p.y + dy })).find((q) => isWalkable(s.map, q.x, q.y))!;
  const c: NpcCrawler = {
    uid: `npc${crawlers(s).length}`, name: 'Heike Brandt', background: 'Imkerin', personality, level: 1, xp: 0,
    hp: 20, maxHp: 24, dmg: [3, 5], pos: spot, alive: true, met: false, party: false, trust: 40, kills: 0,
  };
  s.crawlers = [c];
  return c;
}

describe('Andere Crawler', () => {
  it('jede Etage hat andere Crawler, und die Bevölkerung sinkt mit der Zeit', () => {
    const s = make();
    expect(crawlers(s).length).toBeGreaterThanOrEqual(4);
    const start = population(s).alive;
    tutorial(s);
    for (let i = 0; i < 300; i++) {
      s.monsters = [];
      s.player.hp = 100;
      wait(s);
    }
    expect(population(s).alive).toBeLessThan(start);
    expect(s.log.some((l) => l.text.startsWith('SYSTEMMELDUNG: Es verbleiben'))).toBe(true);
  });

  it('freundliche Crawler schließen sich an und folgen auf die nächste Etage', () => {
    let joined = false;
    for (let seed = 0; seed < 10 && !joined; seed++) {
      const s = make(3200 + seed);
      tutorial(s);
      s.player.pos = openSpot(s);
      s.player.stats.cha = 12;
      const c = neighbor(s, 'freundlich');
      talkCrawler(s, c.uid);
      inviteCrawler(s, c.uid);
      if (!c.party) continue;
      joined = true;
      expect(party(s)).toHaveLength(1);
      const stairs = s.map.tiles.findIndex((t) => t === 'stairs');
      s.player.pos = { x: stairs % s.map.width, y: Math.floor(stairs / s.map.width) };
      const before = population(s).alive;
      expect(descend(s, { ghosts: [] }).ok).toBe(true);
      expect(party(s).map((x) => x.name)).toContain('Heike Brandt');
      expect(population(s).alive).toBeLessThan(before);
      expect(dismissCrawler(s, c.uid).ok).toBe(true);
      expect(party(s)).toHaveLength(0);
    }
    expect(joined).toBe(true);
  });

  it('Eigenbrötler geben Tipps, aber kommen nicht mit', () => {
    const s = make();
    tutorial(s);
    s.player.pos = openSpot(s);
    const c = neighbor(s, 'eigenbroetler');
    const explored = s.map.explored.filter(Boolean).length;
    expect(askCrawlerTip(s, c.uid).ok).toBe(true);
    expect(askCrawlerTip(s, c.uid).ok).toBe(false);
    inviteCrawler(s, c.uid);
    expect(c.party).toBe(false);
    const trapsKnown = (s.traps ?? []).some((t) => !t.hidden);
    const tipLogged = s.log.some((l) => l.text.startsWith('Heike Brandt: „') && /Treppenhaus|Safe Room|Fallen/.test(l.text));
    expect(tipLogged).toBe(true);
    expect(s.map.explored.filter(Boolean).length >= explored || trapsKnown).toBe(true);
  });

  it('verzweifelte Crawler werden nach einer Heilung freundlich', () => {
    const s = make();
    tutorial(s);
    s.player.pos = openSpot(s);
    const c = neighbor(s, 'verzweifelt');
    c.hp = 3;
    const potion = createItem(s, 'heiltrank');
    s.player.inventory.push(potion);
    expect(healCrawler(s, c.uid, potion.uid).ok).toBe(true);
    expect(c.hp).toBeGreaterThan(3);
    expect(c.personality).toBe('freundlich');
    expect(s.player.inventory.some((i) => i.uid === potion.uid)).toBe(false);
  });

  it('feindselige Crawler werden zu Gegnern', () => {
    const s = make();
    tutorial(s);
    s.player.pos = openSpot(s);
    const c = neighbor(s, 'feindselig');
    talkCrawler(s, c.uid);
    expect(crawlers(s)).toHaveLength(0);
    const m = s.monsters.find((x) => x.defId === 'abtruenniger_crawler');
    expect(m?.name).toBe('Heike Brandt');
  });

  it('Party-Mitglieder kämpfen mit', () => {
    const s = make();
    tutorial(s);
    s.player.pos = openSpot(s);
    const c = neighbor(s, 'freundlich');
    c.party = true;
    const spot = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => ({ x: c.pos.x + dx, y: c.pos.y + dy }))
      .find((q) => isWalkable(s.map, q.x, q.y) && !(q.x === s.player.pos.x && q.y === s.player.pos.y))!;
    const rat = spawnMonster(s, monsterDefById('kellerratte')!, 1, spot, 0);
    rat.hp = rat.maxHp = 60;
    s.monsters = [rat];
    for (let i = 0; i < 10; i++) wait(s);
    expect(rat.hp < 60 || !s.monsters.includes(rat)).toBe(true);
  });
});
