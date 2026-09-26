import { describe, expect, it } from 'vitest';
import { answerTalkShow, descend, moveStep, newGame } from '../src/engine/game';
import { emptyMeta } from '../src/engine/meta';
import type { GameState } from '../src/engine/types';

const make = (seed = 4100) => newGame({ name: 'Test', answers: { beruf: 1, haustier: 0 }, seed, meta: emptyMeta() });

function tutorial(s: GameState) {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
}

function toStairs(s: GameState) {
  const i = s.map.tiles.findIndex((t) => t === 'stairs');
  s.player.pos = { x: i % s.map.width, y: Math.floor(i / s.map.width) };
}

describe('Rückblick und Talkshow', () => {
  it('beim Abstieg gibt es einen Rückblick, ab dem Publikum auch eine Talkshow', () => {
    const s = make();
    tutorial(s);
    s.counters.kills += 12;
    s.pendingDialogs = [];
    toStairs(s);
    descend(s, { ghosts: [] });
    expect(s.pendingDialogs[0].title).toBe('Rückblick: Etage 1');
    expect(s.pendingDialogs[0].pages.join(' ')).toContain('12 Gegner besiegt');
    expect(s.pendingDialogs.some((d) => d.kind === 'talkshow')).toBe(false);

    s.pendingDialogs = [];
    toStairs(s);
    descend(s, { ghosts: [] });
    expect(s.pendingDialogs[0].title).toBe('Rückblick: Etage 2');
    const show = s.pendingDialogs.find((d) => d.kind === 'talkshow');
    expect(show).toBeDefined();
    expect(s.talkShow?.questions).toHaveLength(3);
    expect(s.talkShow!.questions.map((q) => q.id)).toContain('haustier');

    let res = answerTalkShow(s, 0);
    expect(res.ok).toBe(true);
    res = answerTalkShow(s, 1);
    res = answerTalkShow(s, 0);
    expect(res.finished).toBe(true);
    expect(s.achievements).toContain('primetime');
    expect(answerTalkShow(s, 0).ok).toBe(false);
  });
});
