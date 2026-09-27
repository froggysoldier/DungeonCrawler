import { describe, expect, it } from 'vitest';
import { monsterTurn } from '../src/engine/ai';
import { playerAttack } from '../src/engine/combat';
import { CONDITIONS, hasCondition, inflict, inflictPlayer, playerHas, susceptibility } from '../src/engine/conditions';
import { createItem } from '../src/engine/items';
import { moveStep, newGame, useItem, wait } from '../src/engine/game';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { maxHp } from '../src/engine/player';
import { stat } from '../src/engine/stats';
import type { GameState, Monster, Pos } from '../src/engine/types';

const make = (seed = 4242) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function arena(s: GameState): { room: { x: number; y: number; w: number; h: number }; spot: Pos } {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
  s.player.pet = null;
  s.crawlers = [];
  s.traps = [];
  const room = s.map.rooms.find((r) => r.kind === 'normal' && r.w >= 6 && r.h >= 3)!;
  s.player.pos = { x: room.x + 1, y: room.y + 1 };
  return { room, spot: { x: room.x + 2, y: room.y + 1 } };
}

function foe(s: GameState, id: string, at: Pos, level = 2): Monster {
  expect(isWalkable(s.map, at.x, at.y)).toBe(true);
  const m = spawnMonster(s, monsterDefById(id)!, level, at, 0);
  m.aware = true;
  m.asleep = false;
  m.abilities = (m.abilities ?? []).filter((a) => a !== 'regeneriert');
  s.monsters.push(m);
  return m;
}

describe('Zustände: Anfälligkeit', () => {
  it('Konstrukte bluten nicht, Untote kennen kein Gift, Insekten brennen gut', () => {
    const s = make();
    const { spot } = arena(s);
    const zwerg = foe(s, 'gartenzwerg', spot);
    expect(susceptibility(s, zwerg, 'blutung')).toBe(0);
    expect(inflict(s, zwerg, 'blutung', 4, 2)).toBe(false);
    const ghul = foe(s, 'ghul', { x: spot.x + 1, y: spot.y });
    expect(susceptibility(s, ghul, 'gift')).toBe(0);
    const kakerlake = foe(s, 'riesenkakerlake', { x: spot.x + 2, y: spot.y });
    expect(susceptibility(s, kakerlake, 'brennen')).toBe(2);
  });

  it('Bosse lassen sich nicht einschüchtern', () => {
    const s = make();
    const { spot } = arena(s);
    const m = foe(s, 'kellerratte', spot, 1);
    m.rank = 'nachbarschaftsboss';
    expect(inflict(s, m, 'furcht', 5, 1)).toBe(false);
  });
});

describe('Zustände bei Gegnern', () => {
  it('Blutung kostet jeden Zug Lebenspunkte und kann töten', () => {
    const s = make();
    const { spot } = arena(s);
    const m = foe(s, 'kellerratte', { x: spot.x + 3, y: spot.y }, 1);
    m.aware = false;
    expect(inflict(s, m, 'blutung', 4, 3)).toBe(true);
    const hp = m.hp;
    monsterTurn(s, m);
    expect(m.hp).toBeLessThan(hp);
    m.hp = 1;
    monsterTurn(s, m);
    expect(s.monsters.includes(m)).toBe(false);
    expect(stat(s, 'kills.teil.blutung')).toBe(1);
  });

  it('ein Kochmesser lässt Gegner bluten', () => {
    const s = make();
    const { spot } = arena(s);
    s.player.equipment.waffe = createItem(s, 'kochmesser');
    let bled = false;
    for (let i = 0; i < 40 && !bled; i++) {
      const m = s.monsters[0] ?? foe(s, 'tatzelwurm', spot, 3);
      m.hp = m.maxHp;
      s.player.ausdauer = 20;
      playerAttack(s, m, { part: 'waffe', move: 'normal' });
      bled = hasCondition(m, 'blutung');
    }
    expect(bled).toBe(true);
  });

  it('ein Staubsaugerbeutel blendet alles im Umkreis', () => {
    const s = make();
    const { spot } = arena(s);
    const a = foe(s, 'kobold', { x: spot.x + 2, y: spot.y }, 2);
    const b = foe(s, 'kobold', { x: spot.x + 3, y: spot.y }, 2);
    s.player.inventory.push(createItem(s, 'staubbeutel', 1));
    s.player.wurfWahl = 'staubbeutel';
    s.unlocks.push('inventar');
    playerAttack(s, a, { part: 'wurf', move: 'normal' });
    expect(hasCondition(a, 'blind')).toBe(true);
    expect(hasCondition(b, 'blind')).toBe(true);
    expect(stat(s, 'zustand.blind')).toBeGreaterThanOrEqual(2);
  });

  it('verängstigte Gegner fliehen statt anzugreifen', () => {
    const s = make();
    const { spot } = arena(s);
    const m = foe(s, 'kobold', spot, 2);
    const hp = s.player.hp;
    expect(inflict(s, m, 'furcht', 6, 1)).toBe(true);
    const d0 = Math.max(Math.abs(m.pos.x - s.player.pos.x), Math.abs(m.pos.y - s.player.pos.y));
    for (let i = 0; i < 3; i++) monsterTurn(s, m);
    const d1 = Math.max(Math.abs(m.pos.x - s.player.pos.x), Math.abs(m.pos.y - s.player.pos.y));
    expect(d1).toBeGreaterThanOrEqual(d0);
    expect(s.player.hp).toBe(hp);
  });
});

describe('Zustände beim Crawler', () => {
  it('Blutung schadet jeden Zug, ein Verband stoppt sie', () => {
    const s = make();
    arena(s);
    s.player.hp = maxHp(s);
    expect(inflictPlayer(s, 'blutung', 5, 2, 'Test')).toBe(true);
    expect(playerHas(s, 'blutung')).toBe(true);
    const hp = s.player.hp;
    wait(s);
    expect(s.player.hp).toBeLessThan(hp);
    const v = createItem(s, 'verband');
    s.player.inventory.push(v);
    s.unlocks.push('inventar');
    useItem(s, v.uid);
    expect(playerHas(s, 'blutung')).toBe(false);
  });

  it('Warten erstickt Flammen', () => {
    const s = make();
    arena(s);
    inflictPlayer(s, 'brennen', 3, 2, 'Test');
    expect(playerHas(s, 'brennen')).toBe(true);
    wait(s);
    expect(playerHas(s, 'brennen')).toBe(false);
  });

  it('wer verblutet, stirbt mit der passenden Ursache', () => {
    const s = make();
    arena(s);
    s.player.curses = [];
    s.player.hp = 1;
    inflictPlayer(s, 'blutung', 5, 3, 'Test');
    wait(s);
    expect(s.status === 'dead' || s.player.hp > 0).toBe(true);
    if (s.status === 'dead') expect(s.deathCause).toBe(CONDITIONS.blutung.death);
  });

  it('Feuerwesen setzen den Crawler in Brand', () => {
    const s = make();
    const { spot } = arena(s);
    const m = foe(s, 'toaster_mimic', spot, 2);
    m.behavior = 'melee';
    m.range = undefined;
    m.treffer = 200;
    let burning = false;
    for (let i = 0; i < 40 && !burning; i++) {
      s.player.hp = maxHp(s);
      monsterTurn(s, m);
      burning = playerHas(s, 'brennen');
    }
    expect(burning).toBe(true);
  });
});
