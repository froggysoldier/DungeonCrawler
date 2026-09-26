import { describe, expect, it } from 'vitest';
import { CLASSES } from '../src/data/classes';
import { emit } from '../src/engine/events';
import { chooseRaceAndClass, classOptions, raceOptions, useAbility } from '../src/engine/classes';
import { descend, moveStep, newGame } from '../src/engine/game';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta, migrate } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import type { GameState } from '../src/engine/types';

const make = (seed = 700) => newGame({ name: 'Test', answers: [0, 0, 0, 0, 0], seed, meta: emptyMeta() });

function toStairs(s: GameState) {
  const i = s.map.tiles.indexOf('stairs');
  s.player.pos = { x: i % s.map.width, y: Math.floor(i / s.map.width) };
}

function toFloor(s: GameState, floor: number) {
  while (s.floor < floor) {
    toStairs(s);
    descend(s, { ghosts: [] });
  }
}

describe('Etage 2: Publikum', () => {
  it('schaltet Zuschauer frei und Spektakel bringt Follower', () => {
    const s = make();
    toFloor(s, 2);
    expect(s.unlocks).toContain('zuschauer');
    expect(s.pendingDialogs.some((d) => d.pages.some((p) => p.includes('PUBLIKUM')))).toBe(true);
    const m = spawnMonster(s, monsterDefById('kellerratte')!, 2, s.player.pos, 0);
    const before = s.viewers.follower;
    emit(s, { type: 'kill', monster: m, technique: { part: 'tritt', move: 'stampfen' } });
    expect(s.viewers.follower).toBeGreaterThan(before);
    expect(s.viewers.hype).toBeGreaterThan(0);
  });

  it('Follower-Meilensteine bringen Fan-Boxen', () => {
    const s = make(701);
    toFloor(s, 2);
    const boxes = s.player.boxes.length;
    s.viewers.follower = 99;
    const m = spawnMonster(s, monsterDefById('kellerratte')!, 2, s.player.pos, 0);
    emit(s, { type: 'kill', monster: m, technique: { part: 'faust', move: 'normal' } });
    expect(s.player.boxes.length).toBeGreaterThan(boxes);
    expect(s.player.boxes.some((b) => b.box?.type === 'fan')).toBe(true);
  });
});

describe('Etage 3: Rassen- und Klassenwahl', () => {
  it('verlangt eine Wahl, bevor es weitergeht', () => {
    const s = make(702);
    toFloor(s, 3);
    expect(s.pendingSelection).toBe(true);
    const p = s.player.pos;
    const next = [{ x: p.x + 1, y: p.y }, { x: p.x - 1, y: p.y }, { x: p.x, y: p.y + 1 }, { x: p.x, y: p.y - 1 }].find((q) => isWalkable(s.map, q.x, q.y))!;
    expect(moveStep(s, next).ok).toBe(false);
  });

  it('empfiehlt Klassen passend zum Kampfstil', () => {
    const s = make(703);
    s.player.techniqueUses = { 'tritt+normal': 80, 'faust+normal': 5 };
    const opts = classOptions(s);
    expect(opts[0].klass.id).toBe('kickboxer');
    expect(opts.filter((o) => o.recommended)).toHaveLength(3);
    s.player.techniqueUses = { 'wurf+normal': 60 };
    s.counters.throws = 60;
    expect(classOptions(s)[0].klass.id).toBe('steinschleuderer');
  });

  it('sperrt besondere Rassen, bis die Bedingung erfüllt ist', () => {
    const s = make(704);
    expect(raceOptions(s).find((r) => r.race.id === 'troll')!.available).toBe(false);
    s.counters.knockdowns = 20;
    expect(raceOptions(s).find((r) => r.race.id === 'troll')!.available).toBe(true);
  });

  it('Wahl wendet Boni an und schaltet die Fähigkeit frei', () => {
    const s = make(705);
    toFloor(s, 3);
    const opt = classOptions(s)[0];
    const str = s.player.stats.str;
    expect(chooseRaceAndClass(s, 'halbork', opt.klass.id).ok).toBe(true);
    expect(s.pendingSelection).toBe(false);
    expect(s.player.race).toBe('halbork');
    expect(s.achievements).toContain('klasse');
    expect(s.player.stats.str).toBe(str); // Basiswerte bleiben, Boni kommen oben drauf
  });

  it('jede Klassenfähigkeit lässt sich einsetzen', () => {
    for (const c of CLASSES) {
      const s = make(706);
      toFloor(s, 3);
      s.pendingSelection = false;
      s.player.klass = c.id;
      s.player.abilityCooldown = 0;
      s.monsters = s.monsters.filter((m) => Math.abs(m.pos.x - s.player.pos.x) > 3 || Math.abs(m.pos.y - s.player.pos.y) > 3);
      const p = s.player.pos;
      const spot = [{ x: p.x + 1, y: p.y }, { x: p.x - 1, y: p.y }, { x: p.x, y: p.y + 1 }, { x: p.x, y: p.y - 1 }].find((q) => isWalkable(s.map, q.x, q.y))!;
      const m = spawnMonster(s, monsterDefById('fischmensch')!, 7, spot, 0);
      s.monsters.push(m);
      const res = useAbility(s, { part: 'tritt', move: 'normal' });
      expect(res.ok, `${c.id}: ${res.message}`).toBe(true);
      expect(s.player.abilityCooldown).toBeGreaterThan(0);
      expect(useAbility(s, { part: 'tritt', move: 'normal' }).ok).toBe(false);
    }
  });
});

describe('Alte Spielstände', () => {
  it('werden ergänzt', () => {
    const s = make(707) as unknown as Record<string, unknown>;
    delete s.viewers;
    delete s.pendingSelection;
    const m = migrate(s as unknown as GameState);
    expect(m.viewers.follower).toBe(0);
    expect(m.pendingSelection).toBe(false);
  });
});
