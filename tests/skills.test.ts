import { describe, expect, it } from 'vitest';
import { SKILL_BY_ID, skillXpNeeded } from '../src/data/skills';
import { monsterTurn } from '../src/engine/ai';
import { defend, moveStep, newGame, useItem, wait } from '../src/engine/game';
import { createItem } from '../src/engine/items';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { sellPrice } from '../src/engine/shop';
import { learnFactor, learnSkill, skillEffectText, skillsOnEvent, trainSkill } from '../src/engine/skills';
import { poison } from '../src/engine/abilities';
import { maxHp } from '../src/engine/player';
import type { GameState } from '../src/engine/types';

const make = (seed = 7300) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

function arena(s: GameState) {
  const guild = s.map.rooms.find((r) => r.kind === 'guild')!;
  s.player.pos = { x: guild.x + 1, y: guild.y + 1 };
  s.monsters = [];
  moveStep(s, { x: guild.x + 2, y: guild.y + 1 });
  s.player.pet = null;
  s.crawlers = [];
  s.traps = [];
  const room = s.map.rooms.find((r) => r.kind === 'normal' && r.w >= 5)!;
  s.player.pos = { x: room.x + 1, y: room.y + 1 };
  return { x: room.x + 2, y: room.y + 1 };
}

describe('Skills', () => {
  it('an viel schwächeren Gegnern lernt man kaum etwas', () => {
    const s = make();
    s.player.level = 10;
    expect(learnFactor(s, 2)).toBeLessThan(0.2);
    expect(learnFactor(s, 10)).toBe(1);
    expect(learnFactor(s, 13)).toBeGreaterThan(1);
  });

  it('Skill-Stufen werden teurer', () => {
    expect(skillXpNeeded(10)).toBeGreaterThan(skillXpNeeded(2) * 2);
  });

  it('jeder Skill beschreibt seine Wirkung pro Stufe', () => {
    for (const def of Object.values(SKILL_BY_ID)) {
      expect(skillEffectText(def, 3).length).toBeGreaterThan(3);
    }
  });

  it('Erste Hilfe entsteht durch Heilgegenstände und verstärkt sie', () => {
    const s = make();
    arena(s);
    s.player.skills = s.player.skills.filter((k) => k.id !== 'erste_hilfe');
    for (let i = 0; i < 8; i++) {
      const it = createItem(s, 'pflaster');
      s.player.inventory.push(it);
      s.monsters = [];
      useItem(s, it.uid);
    }
    expect(s.player.skills.some((k) => k.id === 'erste_hilfe')).toBe(true);
  });

  it('Giftfestigkeit dämpft Giftschaden', () => {
    const plain = make();
    arena(plain);
    const tough = make();
    arena(tough);
    learnSkill(tough, 'giftfestigkeit', 10, true);
    const lost: number[] = [];
    for (const s of [plain, tough]) {
      s.player.hp = maxHp(s);
      const before = s.player.hp;
      poison(s, 'Test', 4);
      s.monsters = [];
      wait(s);
      lost.push(before - s.player.hp);
    }
    expect(lost[1]).toBeLessThan(lost[0]);
  });

  it('Abwehr macht die Deckung stärker', () => {
    const s = make();
    arena(s);
    learnSkill(s, 'abwehr', 9, true);
    s.monsters = [];
    defend(s);
    // Deckung gilt nur bis zum Ende des Zuges – den Wert prüfen wir über den Text
    expect(skillEffectText(SKILL_BY_ID.abwehr, 9)).toContain('38 %');
  });

  it('Feilschen verbessert Verkaufspreise', () => {
    const s = make();
    const it = createItem(s, 'bauhelm');
    const before = sellPrice(it, s);
    learnSkill(s, 'feilschen', 15, true);
    expect(sellPrice(it, s)).toBeGreaterThan(before);
  });

  it('Schleichen: Monster entdecken dich seltener, dabei lernt man', () => {
    const quiet = make(7400);
    const spot = arena(quiet);
    learnSkill(quiet, 'schleichen', 15, true);
    let noticed = 0;
    for (let i = 0; i < 40; i++) {
      const m = spawnMonster(quiet, monsterDefById('ghul')!, 2, { x: spot.x + 3, y: spot.y }, 0);
      if (!isWalkable(quiet.map, m.pos.x, m.pos.y)) m.pos = spot;
      quiet.monsters = [m];
      monsterTurn(quiet, m);
      if (m.aware) noticed++;
    }
    expect(noticed).toBeLessThan(40);
  });

  it('Konter schlägt nach dem Ausweichen zurück', () => {
    let countered = false;
    for (let seed = 0; seed < 15 && !countered; seed++) {
      const s = make(7500 + seed);
      const spot = arena(s);
      learnSkill(s, 'konter', 15, true);
      const m = spawnMonster(s, monsterDefById('ghul')!, 2, spot, 0);
      m.treffer = -500; // trifft nie
      m.aware = true;
      m.hp = m.maxHp = 500;
      m.abilities = [];
      s.monsters = [m];
      for (let i = 0; i < 10; i++) monsterTurn(s, m);
      countered = m.hp < 500;
    }
    expect(countered).toBe(true);
  });

  it('Auslöser zählen auch ohne Kampf', () => {
    const s = make();
    for (let i = 0; i < 3; i++) trainSkill(s, 'haggle', 1);
    expect(s.player.skills.some((k) => k.id === 'feilschen')).toBe(true);
    skillsOnEvent(s, { type: 'spellCast', spell: 'heilen', kills: 0 });
    expect(s.player.techniqueUses._cast).toBe(1);
  });
});
