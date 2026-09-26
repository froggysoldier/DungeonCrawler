import { describe, expect, it } from 'vitest';
import { monsterTurn } from '../src/engine/ai';
import { hitChance } from '../src/engine/combat';
import { attack, defend, moveStep, newGame } from '../src/engine/game';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import type { GameState } from '../src/engine/types';

const make = (seed = 9900) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function duel(s: GameState, id = 'ghul') {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
  s.player.pet = null;
  s.crawlers = [];
  s.traps = [];
  const room = s.map.rooms.find((r) => r.kind === 'normal' && r.w >= 5)!;
  s.player.pos = { x: room.x + 1, y: room.y + 1 };
  const spot = { x: room.x + 2, y: room.y + 1 };
  expect(isWalkable(s.map, spot.x, spot.y)).toBe(true);
  const m = spawnMonster(s, monsterDefById(id)!, 2, spot, 0);
  m.aware = true;
  m.abilities = [];
  s.monsters = [m];
  return m;
}

describe('Trefferzonen', () => {
  it('Kopf ist schwerer zu treffen als der Körper, liegende Gegner halten den Kopf hin', () => {
    const s = make();
    const m = duel(s);
    const head = hitChance(s, m, { part: 'faust', move: 'normal', zone: 'kopf' });
    const body = hitChance(s, m, { part: 'faust', move: 'normal', zone: 'koerper' });
    expect(head).toBeLessThan(body);
    m.downed = 2;
    expect(hitChance(s, m, { part: 'faust', move: 'normal', zone: 'kopf' })).toBeGreaterThan(head);
  });

  it('Beintreffer lassen humpeln, Armtreffer schwächen, Kopftreffer machen benommen', () => {
    const effects = new Set<string>();
    for (let seed = 0; seed < 40 && effects.size < 3; seed++) {
      const s = make(9950 + seed);
      const m = duel(s);
      m.hp = m.maxHp = 999;
      m.ausweichen = -300;
      for (const zone of ['kopf', 'arme', 'beine'] as const) {
        s.player.ausdauer = 20;
        attack(s, m.uid, { part: 'faust', move: 'normal', zone });
      }
      if (m.stunned !== undefined) effects.add('benommen');
      if (m.weakened !== undefined) effects.add('geschwaecht');
      if (m.slowed !== undefined) effects.add('humpelt');
    }
    expect([...effects].sort()).toEqual(['benommen', 'geschwaecht', 'humpelt']);
  });

  it('benommene Gegner setzen aus', () => {
    const s = make();
    const m = duel(s);
    m.stunned = 1;
    const hp = s.player.hp;
    monsterTurn(s, m);
    expect(s.player.hp).toBe(hp);
    expect(m.stunned).toBe(0);
  });

  it('Deckung macht bis zum nächsten Zug schwerer zu treffen', () => {
    const s = make();
    duel(s);
    expect(defend(s).ok).toBe(true);
    expect(s.log.some((l) => l.text.includes('Deckung'))).toBe(true);
    expect(s.player.buffs.some((b) => b.name === 'Deckung')).toBe(false); // nach dem Zug wieder weg
  });
});
