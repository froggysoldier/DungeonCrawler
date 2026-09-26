import { describe, expect, it } from 'vitest';
import { acceptSponsorOffer, newGame } from '../src/engine/game';
import { emit } from '../src/engine/events';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { sponsorStates } from '../src/engine/sponsors';
import type { GameState } from '../src/engine/types';

const make = () => newGame({ name: 'Test', answers: { beruf: 1 }, seed: 5100, meta: emptyMeta() });

function stompKill(s: GameState) {
  const m = spawnMonster(s, monsterDefById('kellerratte')!, 1, { x: 1, y: 1 }, 0);
  emit(s, { type: 'kill', monster: m, technique: { part: 'tritt', move: 'stampfen' }, facets: ['t:tritt', 'm:stampfen', 'z:ratte'] });
}

describe('Sponsoren', () => {
  it('ohne Publikum interessiert sich niemand', () => {
    const s = make();
    for (let i = 0; i < 30; i++) stompKill(s);
    expect(sponsorStates(s).every((x) => x.status === 'none')).toBe(true);
  });

  it('Stil weckt Interesse, Angebot annehmen, Wünsche erfüllen, Missfallen kostet Gunst', () => {
    const s = make();
    s.unlocks.push('zuschauer');
    s.viewers.follower = 500;
    s.viewers.hype = 50;
    for (let i = 0; i < 30; i++) stompKill(s);
    const vornex = sponsorStates(s).find((x) => x.id === 'vornex')!;
    expect(vornex.status).toBe('offer');
    expect(acceptSponsorOffer(s, 'vornex').ok).toBe(true);
    const boxes = s.player.boxes.length;
    for (let i = 0; i < 4; i++) stompKill(s);
    expect(vornex.completed).toBe(1);
    expect(s.player.boxes.length).toBeGreaterThan(boxes);
    expect(s.achievements).toContain('sponsor_wunsch');
    for (let i = 0; i < 10; i++) emit(s, { type: 'trapTriggered', kind: 'pfeilplatte', onPlayer: true });
    expect(vornex.status).toBe('dropped');
  });
});
