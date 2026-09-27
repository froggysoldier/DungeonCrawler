import { describe, expect, it } from 'vitest';
import { FLOORS } from '../src/data/world';
import { chooseRaceAndClass, classOptions } from '../src/engine/classes';
import { killMonster } from '../src/engine/combat';
import { descend, newGame } from '../src/engine/game';
import { emptyMeta } from '../src/engine/meta';
import { spawnForFloor } from '../src/engine/monsters';
import { killXp, levelDiffFactor, xpToNext } from '../src/engine/progression';
import * as R from '../src/engine/rng';
import type { GameState } from '../src/engine/types';

interface Style {
  /** Anteil der anfangs vorhandenen Mobs, die erledigt werden. */
  mobs: number;
  /** Zusätzliche Kills durch Nachspawns (Anteil der Anfangsmenge). */
  respawns: number;
  hoodBosses: number;
  borough: boolean;
}

const THOROUGH: Style = { mobs: 1, respawns: 0.8, hoodBosses: 3, borough: true };
const CASUAL: Style = { mobs: 0.6, respawns: 0.3, hoodBosses: 1, borough: false };

function toStairs(s: GameState) {
  const i = s.map.tiles.findIndex((t) => t === 'stairs');
  s.player.pos = { x: i % s.map.width, y: Math.floor(i / s.map.width) };
}

/** Spielt drei Etagen „auf dem Papier“: Kills in sinnvoller Reihenfolge, dann Abstieg. */
function run(seed: number, style: Style): number[] {
  const s = newGame({ name: 'Sim', answers: { beruf: 1 }, seed, meta: emptyMeta() });
  const levels: number[] = [];
  for (let floor = 1; floor <= 3; floor++) {
    const mobs = s.monsters.filter((m) => m.rank === 'normal' || m.rank === 'elite').sort((a, b) => a.level - b.level);
    const take = Math.round(mobs.length * style.mobs);
    for (const m of mobs.slice(0, take)) killMonster(s, m, null);
    const def = FLOORS.find((f) => f.floor === floor)!;
    const extra = Math.round(mobs.length * style.respawns);
    for (let i = 0; i < extra; i++) {
      const m = spawnForFloor(s, floor, R.int(s, def.mobLevel[0], def.mobLevel[1]), { x: 1, y: 1 }, 0, false);
      s.monsters.push(m);
      killMonster(s, m, null);
    }
    const bosses = s.monsters.filter((m) => m.rank === 'nachbarschaftsboss').slice(0, style.hoodBosses);
    for (const b of bosses) killMonster(s, b, null);
    if (style.borough) {
      const b = s.monsters.find((m) => m.rank === 'boroughboss');
      if (b) killMonster(s, b, null);
    }
    levels.push(s.player.level);
    if (floor < 3) {
      toStairs(s);
      descend(s, { ghosts: [] });
      if (s.pendingSelection) chooseRaceAndClass(s, 'elf', classOptions(s)[0].klass.id);
    }
  }
  return levels;
}

describe('Stufenverlauf', () => {
  it('Erfahrung hängt vom Stufenabstand ab', () => {
    expect(levelDiffFactor(-6)).toBeLessThan(levelDiffFactor(-2));
    expect(levelDiffFactor(0)).toBe(1);
    expect(levelDiffFactor(3)).toBeGreaterThan(1);
    const s = newGame({ name: 'A', answers: { beruf: 1 }, seed: 5, meta: emptyMeta() });
    const m = s.monsters.find((x) => x.rank === 'normal')!;
    s.player.level = m.level + 6;
    expect(killXp(s, m).challenge).toBe('trivial');
    s.player.level = Math.max(1, m.level - 4);
    expect(killXp(s, m).xp).toBeGreaterThan(m.xp);
    expect(xpToNext(5)).toBeGreaterThan(xpToNext(4) * 1.3);
  });

  it('gründliche Crawler: Etage 1 um Stufe 5, Etage 2 um 7–8, Etage 3 um 10–12', () => {
    const all = [11, 22, 33, 44, 55].map((seed) => run(seed, THOROUGH));
    const avg = (i: number) => all.reduce((a, l) => a + l[i], 0) / all.length;
    expect(avg(0)).toBeGreaterThanOrEqual(4);
    expect(avg(0)).toBeLessThanOrEqual(6);
    expect(avg(1)).toBeGreaterThanOrEqual(6.5);
    expect(avg(1)).toBeLessThanOrEqual(9);
    expect(avg(2)).toBeGreaterThanOrEqual(9.5);
    expect(avg(2)).toBeLessThanOrEqual(13);
  });

  it('vorsichtige Crawler steigen langsamer auf', () => {
    const all = [11, 22, 33, 44, 55].map((seed) => run(seed, CASUAL));
    const avg = (i: number) => all.reduce((a, l) => a + l[i], 0) / all.length;
    expect(avg(0)).toBeGreaterThanOrEqual(2.5);
    expect(avg(0)).toBeLessThanOrEqual(4.5);
    expect(avg(2)).toBeGreaterThanOrEqual(7);
    expect(avg(2)).toBeLessThanOrEqual(11);
  });

  it('Werte zum Nachschauen', () => {
    const t = [11, 22, 33].map((seed) => run(seed, THOROUGH).join('/'));
    const c = [11, 22, 33].map((seed) => run(seed, CASUAL).join('/'));
    const env = (globalThis as { process?: { env: Record<string, string | undefined> } }).process?.env ?? {};
    if (env.PROG) throw new Error(`gründlich ${t.join(' ')} | vorsichtig ${c.join(' ')}`);
  });
});
