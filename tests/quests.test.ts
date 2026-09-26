import { describe, expect, it } from 'vitest';
import { MONSTERS } from '../src/data/monsters';
import { acceptQuestOffer, descend, moveStep, newGame, turnInQuest, wait } from '../src/engine/game';
import { crawlers } from '../src/engine/crawlers';
import { emit } from '../src/engine/events';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { offerQuest, quests } from '../src/engine/quests';
import { createItem } from '../src/engine/items';
import type { GameState, NpcCrawler, QuestKind } from '../src/engine/types';

const make = (seed = 6100) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function tutorial(s: GameState) {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
  s.traps = [];
}

function giverNextToMe(s: GameState): NpcCrawler {
  const room = s.map.rooms.find((r) => r.kind === 'normal' && r.w >= 5)!;
  s.player.pos = { x: room.x + 2, y: room.y + 2 };
  const pos = [[1, 0], [-1, 0], [0, 1]].map(([dx, dy]) => ({ x: s.player.pos.x + dx, y: s.player.pos.y + dy })).find((q) => isWalkable(s.map, q.x, q.y))!;
  const c: NpcCrawler = { uid: 'giver', name: 'Ole Pietsch', background: 'Imker', personality: 'freundlich', level: 1, xp: 0, hp: 30, maxHp: 30, dmg: [2, 4], pos, alive: true, met: true, party: false, trust: 40, kills: 0 };
  s.crawlers = [c];
  return c;
}

function offerOf(s: GameState, kind: QuestKind) {
  for (let i = 0; i < 60; i++) {
    const q = offerQuest(s, { kind: 'crawler', ref: 'giver', name: 'Ole Pietsch' });
    if (q?.kind === kind) return q;
    s.quests = [];
  }
  throw new Error('kein Angebot ' + kind);
}

describe('Aufträge', () => {
  it('Jagdauftrag zählt passende Kills und belohnt', () => {
    const s = make();
    tutorial(s);
    giverNextToMe(s);
    const q = offerOf(s, 'jagd');
    expect(acceptQuestOffer(s, q.id).ok).toBe(true);
    const gold = s.player.gold;
    const tag = q.facet!.slice(2);
    const def = MONSTERS.find((m) => (m.tags ?? []).includes(tag) && m.floors.includes(1))!;
    for (let i = 0; i < q.count; i++) {
      const m = spawnMonster(s, monsterDefById(def.id)!, 1, { x: 1, y: 1 }, 0);
      emit(s, { type: 'kill', monster: m, technique: null });
    }
    expect(q.status).toBe('erledigt');
    expect(s.player.gold).toBeGreaterThan(gold);
  });

  it('Liefern: Sachen beim Auftraggeber abgeben', () => {
    const s = make();
    tutorial(s);
    giverNextToMe(s);
    const q = offerOf(s, 'liefern');
    acceptQuestOffer(s, q.id);
    s.player.inventory = [];
    expect(turnInQuest(s, q.id).ok).toBe(false);
    s.player.inventory.push(createItem(s, q.itemIds![0], q.count));
    expect(turnInQuest(s, q.id).ok).toBe(true);
    expect(q.status).toBe('erledigt');
    expect(s.achievements).toContain('auftrag_erster');
  });

  it('Finden: das Andenken liegt irgendwo und wird zurückgebracht', () => {
    const s = make();
    tutorial(s);
    giverNextToMe(s);
    const q = offerOf(s, 'finden');
    acceptQuestOffer(s, q.id);
    const entry = s.items.find((e) => e.item.questId === q.id)!;
    expect(entry).toBeDefined();
    s.items = s.items.filter((e) => e !== entry);
    s.player.inventory.push(entry.item);
    expect(turnInQuest(s, q.id).ok).toBe(true);
    expect(s.player.inventory.some((i) => i.questId)).toBe(false);
  });

  it('Retten: die Person wartet bewacht und ist nach dem Erreichen gerettet', () => {
    const s = make();
    tutorial(s);
    giverNextToMe(s);
    const q = offerOf(s, 'retten');
    acceptQuestOffer(s, q.id);
    const target = crawlers(s).find((c) => c.uid === q.targetUid)!;
    expect(target.personality).toBe('verzweifelt');
    const spot = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => ({ x: target.pos.x + dx, y: target.pos.y + dy })).find((p) => isWalkable(s.map, p.x, p.y) && !s.monsters.some((m) => m.pos.x === p.x && m.pos.y === p.y))!;
    s.player.pos = spot;
    s.monsters = [];
    wait(s);
    expect(q.status).toBe('erledigt');
    expect(target.personality).toBe('freundlich');
  });

  it('offene Aufträge scheitern beim Abstieg', () => {
    const s = make();
    tutorial(s);
    giverNextToMe(s);
    const q = offerOf(s, 'finden');
    acceptQuestOffer(s, q.id);
    const i = s.map.tiles.indexOf('stairs');
    s.player.pos = { x: i % s.map.width, y: Math.floor(i / s.map.width) };
    descend(s, { ghosts: [] });
    expect(quests(s).find((x) => x.id === q.id)?.status).toBe('gescheitert');
  });
});

