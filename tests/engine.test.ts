import { describe, expect, it } from 'vitest';
import { monsterTurn } from '../src/engine/ai';
import { techniqueBlocker } from '../src/engine/combat';
import { emit } from '../src/engine/events';
import {
  attack, descend, endTurn, moveStep, newGame, openBox, pickup, planPath, sleep, useItem, wait,
} from '../src/engine/game';
import { idx, isWalkable } from '../src/engine/mapgen';
import { emptyMeta, recordRunEnd } from '../src/engine/meta';
import { spawnMonster } from '../src/engine/monsters';
import { MONSTERS } from '../src/data/monsters';
import type { GameState, Pos } from '../src/engine/types';

const make = (seed = 1234, answers = [0, 0, 0, 0, 0]) =>
  newGame({ name: 'Test', answers, seed, meta: emptyMeta() });

function reachable(s: GameState, from: Pos): Set<number> {
  const seen = new Set<number>([idx(s.map, from.x, from.y)]);
  const q = [from];
  while (q.length) {
    const c = q.shift()!;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const n = { x: c.x + dx, y: c.y + dy };
      const i = idx(s.map, n.x, n.y);
      if (!isWalkable(s.map, n.x, n.y) || seen.has(i)) continue;
      seen.add(i);
      q.push(n);
    }
  }
  return seen;
}

function teleport(s: GameState, p: Pos) {
  s.player.pos = { ...p };
}

describe('Neues Spiel', () => {
  it('erzeugt einen spielbaren Startzustand', () => {
    const s = make();
    expect(s.status).toBe('playing');
    expect(isWalkable(s.map, s.player.pos.x, s.player.pos.y)).toBe(true);
    expect(s.player.hp).toBeGreaterThan(0);
    expect(s.achievements).toContain('willkommen');
    expect(s.player.boxes.length).toBeGreaterThan(0);
    expect(s.unlocks).not.toContain('inventar');
  });

  it('wendet Interview-Antworten an (Katze + Bademantel)', () => {
    const s = make(5, [3, 0, 0, 0, 1]);
    expect(s.player.pet?.species).toBe('Katze');
    expect(s.player.equipment.brust?.baseId).toBe('bademantel');
    expect(s.achievements).toContain('katzenlady');
    expect(s.achievements).toContain('bademantel');
    expect(s.player.skills.map((k) => k.id)).toContain('faustkampf');
  });

  it('erzeugt zusammenhängende Karten mit allen wichtigen Räumen', () => {
    for (const seed of [1, 2, 3, 42, 999, 31337]) {
      const s = make(seed);
      const reach = reachable(s, s.player.pos);
      for (let i = 0; i < s.map.tiles.length; i++) {
        if (s.map.tiles[i] !== 'wall') expect(reach.has(i)).toBe(true);
      }
      const kinds = s.map.rooms.map((r) => r.kind);
      expect(kinds.filter((k) => k === 'guild').length).toBeGreaterThanOrEqual(1);
      expect(kinds.filter((k) => k === 'safe').length).toBeGreaterThanOrEqual(4);
      expect(kinds.filter((k) => k === 'boss').length).toBe(4);
      expect(s.map.tiles.filter((t) => t === 'stairs').length).toBeGreaterThanOrEqual(2);
      expect(s.monsters.filter((m) => m.rank === 'nachbarschaftsboss').length).toBe(4);
      expect(s.monsters.filter((m) => m.rank === 'boroughboss').length).toBe(1);
    }
  });
});

describe('Kampf und Skills', () => {
  function withRat(s: GameState) {
    s.monsters = [];
    const p = s.player.pos;
    const spot = [{ x: p.x + 1, y: p.y }, { x: p.x - 1, y: p.y }, { x: p.x, y: p.y + 1 }, { x: p.x, y: p.y - 1 }].find((q) =>
      isWalkable(s.map, q.x, q.y),
    )!;
    const rat = spawnMonster(s, MONSTERS.find((m) => m.id === 'kellerratte')!, 1, spot, 0);
    s.monsters.push(rat);
    return rat;
  }

  it('Faustschläge können töten und geben XP', () => {
    const s = make(77);
    const rat = withRat(s);
    rat.hp = 1;
    rat.ausweichen = -200;
    const res = attack(s, rat.uid, { part: 'faust', move: 'normal' });
    expect(res.ok).toBe(true);
    expect(s.monsters).not.toContain(rat);
    expect(s.counters.kills).toBe(1);
    expect(s.achievements).toContain('erstes_blut');
    expect(s.player.techniqueKills['faust+normal']).toBe(1);
  });

  it('Stampfen geht nur auf liegende oder winzige Gegner', () => {
    const s = make(78);
    const rat = withRat(s);
    rat.size = 'klein';
    expect(techniqueBlocker(s, rat, { part: 'tritt', move: 'stampfen' })).toMatch(/Boden/);
    rat.downed = 2;
    expect(techniqueBlocker(s, rat, { part: 'tritt', move: 'stampfen' })).toBeNull();
  });

  it('Wiederholte Tritte schalten den Skill „Treten“ frei', () => {
    const s = make(79, [1, 0, 3, 0, 0]);
    const rat = withRat(s);
    for (let i = 0; i < 15; i++) {
      emit(s, { type: 'attack', technique: { part: 'tritt', move: 'normal' }, hit: false, crit: false, damage: 0, target: rat });
    }
    expect(s.player.skills.map((k) => k.id)).toContain('treten');
    expect(s.achievements).toContain('skill1');
  });

  it('Werfen ohne Wurfobjekt ist nicht möglich', () => {
    const s = make(80);
    const rat = withRat(s);
    s.items = [];
    expect(techniqueBlocker(s, rat, { part: 'wurf', move: 'normal' })).toMatch(/nichts zum Werfen/);
  });
});

describe('Safe Rooms und Boxen', () => {
  it('Boxen lassen sich nur im Safe Room öffnen', () => {
    const s = make(90);
    s.unlocks.push('inventar');
    const box = s.player.boxes[0];
    expect(openBox(s, box.uid).ok).toBe(false);
    const safe = s.map.rooms.find((r) => r.kind === 'safe')!;
    teleport(s, { x: safe.x + 1, y: safe.y + 1 });
    const res = openBox(s, box.uid);
    expect(res.ok).toBe(true);
    expect(res.contents!.length).toBeGreaterThan(0);
    expect(s.achievements).toContain('unboxing');
  });

  it('Mobs, die im Safe Room angreifen, werden weggebeamt', () => {
    const s = make(91);
    const safe = s.map.rooms.find((r) => r.kind === 'safe')!;
    teleport(s, { x: safe.x + 1, y: safe.y + 1 });
    s.monsters = [];
    const m = spawnMonster(s, MONSTERS[2], 2, { x: safe.x + 2, y: safe.y + 1 }, 0);
    m.aware = true;
    s.monsters.push(m);
    const hp = s.player.hp;
    monsterTurn(s, m);
    expect(s.player.hp).toBe(hp);
    expect(Math.max(Math.abs(m.pos.x - s.player.pos.x), Math.abs(m.pos.y - s.player.pos.y))).toBeGreaterThan(1);
  });

  it('Schlafen heilt und lässt Zeit vergehen', () => {
    const s = make(92);
    const safe = s.map.rooms.find((r) => r.kind === 'safe')!;
    teleport(s, { x: safe.x + 1, y: safe.y + 1 });
    s.player.hp = 1;
    const t = s.turn;
    expect(sleep(s).ok).toBe(true);
    expect(s.turn).toBeGreaterThan(t + 100);
    expect(s.player.hp).toBeGreaterThan(1);
  });
});

describe('Tutorial, Etagen und Tod', () => {
  it('Die Gilde schaltet das Inventar frei und legt den Handgegenstand ab', () => {
    const s = make(100);
    pickup(s); // Stein im Startraum liegt evtl. nicht genau hier – Hand manuell füllen
    s.player.hand = s.items[0]?.item ?? null;
    const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
    const inside = { x: guild.x + 1, y: guild.y + 1 };
    const next = { x: guild.x + 2, y: guild.y + 1 };
    teleport(s, inside);
    s.monsters = [];
    moveStep(s, next);
    expect(s.unlocks).toContain('inventar');
    expect(s.player.hand).toBeNull();
    expect(s.pendingDialogs.some((d) => d.title === 'Gilde der Einweisung')).toBe(true);
    expect(s.player.inventory.some((i) => i.baseId === 'kleiner_heiltrank')).toBe(true);
    const potion = s.player.inventory.find((i) => i.baseId === 'kleiner_heiltrank')!;
    s.player.hp = 1;
    expect(useItem(s, potion.uid).ok).toBe(true);
    expect(s.player.hp).toBeGreaterThan(1);
  });

  it('Die Etage stürzt ein, wenn die Zeit abläuft', () => {
    const s = make(101);
    s.monsters = [];
    s.collapseAt = s.turn + 2;
    wait(s);
    wait(s);
    expect(s.status).toBe('dead');
    expect(s.deathCause).toMatch(/einstürzenden/);
  });

  it('Treppen führen bis Etage 3, danach ist die Demo geschafft', () => {
    const s = make(102);
    const stairsIdx = s.map.tiles.indexOf('stairs');
    teleport(s, { x: stairsIdx % s.map.width, y: Math.floor(stairsIdx / s.map.width) });
    expect(descend(s, { ghosts: [] }).ok).toBe(true);
    expect(s.floor).toBe(2);
    expect(s.achievements).toContain('absteiger');
    for (const floor of [3, 4]) {
      const i2 = s.map.tiles.indexOf('stairs');
      teleport(s, { x: i2 % s.map.width, y: Math.floor(i2 / s.map.width) });
      s.pendingSelection = false;
      descend(s, { ghosts: [] });
      if (floor === 3) expect(s.floor).toBe(3);
    }
    expect(s.status).toBe('victory');
  });

  it('Der Tod hinterlässt einen Geist, der in der nächsten Staffel spawnt', () => {
    const meta = emptyMeta();
    const s = newGame({ name: 'Erna', answers: [0, 0, 0, 0, 0], seed: 5, meta });
    s.status = 'dead';
    s.deathCause = 'Test';
    recordRunEnd(meta, s);
    expect(meta.season).toBe(1);
    expect(meta.ghosts[0].name).toBe('Erna');
    expect(meta.hallOfFame).toHaveLength(1);
    const s2 = newGame({ name: 'Nachfolger', answers: [0, 0, 0, 0, 0], seed: 6, meta });
    expect(s2.season).toBe(2);
    expect(s2.monsters.some((m) => m.rank === 'geist' && m.ghostOf === 'Erna')).toBe(true);
    // Das Willkommen-Achievement ist jetzt nicht mehr „erstmalig“
    expect(s2.player.boxes[0].box?.tier).toBe('bronze');
  });

  it('Mit Vertrag wird man zum Guide der nächsten Staffel', () => {
    const meta = emptyMeta();
    const s = newGame({ name: 'Mira', answers: [0, 0, 0, 0, 0], seed: 7, meta });
    s.contractSigned = true;
    s.status = 'dead';
    recordRunEnd(meta, s);
    expect(meta.guides[0].name).toBe('Mira');
    expect(meta.ghosts).toHaveLength(0);
    const s2 = newGame({ name: 'Neu', answers: [0, 0, 0, 0, 0], seed: 8, meta });
    expect(s2.guideName).toBe('Mira');
  });

  it('Klick-Pfade laufen nur über bekannte Felder', () => {
    const s = make(103);
    const far = { x: s.map.width - 2, y: s.map.height - 2 };
    expect(planPath(s, far)).toBeNull();
  });
});

describe('Robustheit', () => {
  it('überlebt tausende zufällige Aktionen ohne Absturz', () => {
    for (const seed of [11, 12, 13]) {
      const s = make(seed, [seed % 9, 1, seed % 4, 2, 3]);
      let rng = seed;
      const rand = () => {
        rng = (rng * 1103515245 + 12345) & 0x7fffffff;
        return rng / 0x7fffffff;
      };
      for (let i = 0; i < 3000 && s.status === 'playing'; i++) {
        const adj = s.monsters.find((m) => Math.max(Math.abs(m.pos.x - s.player.pos.x), Math.abs(m.pos.y - s.player.pos.y)) <= 1);
        if (adj && rand() < 0.8) {
          const parts = ['faust', 'tritt', 'knie', 'ellbogen', 'kopf'] as const;
          const r = attack(s, adj.uid, { part: parts[Math.floor(rand() * parts.length)], move: rand() < 0.2 ? 'sprung' : 'normal' });
          if (!r.ok) wait(s);
          continue;
        }
        const dx = Math.floor(rand() * 3) - 1;
        const dy = Math.floor(rand() * 3) - 1;
        const r = moveStep(s, { x: s.player.pos.x + dx, y: s.player.pos.y + dy });
        if (!r.ok) endTurn(s);
        if (rand() < 0.05) pickup(s);
      }
      expect(['playing', 'dead']).toContain(s.status);
      expect(JSON.parse(JSON.stringify(s)).floor).toBe(s.floor);
    }
  });
});
