import { describe, expect, it } from 'vitest';
import { drainSfx, moveStep, newGame, openBox } from '../src/engine/game';
import { createBox } from '../src/engine/items';
import { emptyMeta } from '../src/engine/meta';
import { gainXp } from '../src/engine/player';

describe('Klänge', () => {
  it('Lootboxen, Level-Aufstiege und Achievements melden einen Klang an', () => {
    const s = newGame({ name: 'Test', answers: { beruf: 1 }, seed: 4242, meta: emptyMeta() });
    expect(drainSfx(s).some((x) => x.kind === 'achievement')).toBe(true); // Start-Achievement
    gainXp(s, 500);
    expect(drainSfx(s).some((x) => x.kind === 'levelup')).toBe(true);
    const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
    s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
    s.monsters = [];
    moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
    const safe = s.map.rooms.find((r) => r.kind === 'safe')!;
    s.player.pos = { x: safe.x + 1, y: safe.y + 1 };
    s.monsters = [];
    moveStep(s, { x: safe.x + 2, y: safe.y + 1 });
    drainSfx(s);
    const box = createBox(s, 'abenteurer', 'gold');
    s.player.boxes.push(box);
    expect(openBox(s, box.uid).ok).toBe(true);
    expect(drainSfx(s).find((x) => x.kind === 'box')?.tier).toBe('gold');
  });
});
