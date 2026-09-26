import { describe, expect, it } from 'vitest';
import { petLevelUp, petTurn } from '../src/engine/ai';
import { evolvePetTo, newGame, petGearOff, petGearOn } from '../src/engine/game';
import { createItem } from '../src/engine/items';
import { isWalkable } from '../src/engine/mapgen';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { totalBonuses } from '../src/engine/player';

const make = () => newGame({ name: 'Test', answers: { beruf: 1, haustier: 1 }, seed: 7100, meta: emptyMeta() });

describe('Haustier-Entwicklung', () => {
  it('ab Stufe 4 wählt man einen Weg, ab Stufe 8 folgt die Endform', () => {
    const s = make();
    const pet = s.player.pet!;
    expect(pet.species).toBe('Hund');
    expect(evolvePetTo(s, 'wachhund').ok).toBe(false);
    while (pet.level < 4) petLevelUp(s);
    expect(pet.evolveReady).toBe(true);
    const hp = pet.maxHp;
    expect(evolvePetTo(s, 'reisser').ok).toBe(false); // falscher Weg für einen Hund
    expect(evolvePetTo(s, 'spuernase').ok).toBe(true);
    expect(pet.maxHp).toBeGreaterThan(hp);
    expect(pet.abilities).toContain('spaeher');
    expect(totalBonuses(s).lichtradius ?? 0).toBeGreaterThanOrEqual(1);
    expect(s.achievements).toContain('evolution');
    while (pet.level < 8) petLevelUp(s);
    expect(evolvePetTo(s, 'rettungshund').ok).toBe(true);
    expect(pet.abilities).toEqual(expect.arrayContaining(['spaeher', 'lecken']));
    expect(s.achievements).toContain('endform');
  });

  it('Halsbänder machen das Haustier stärker und lassen sich abnehmen', () => {
    const s = make();
    const pet = s.player.pet!;
    s.unlocks.push('inventar');
    const collar = createItem(s, 'halsband_stachel');
    s.player.inventory.push(collar);
    const hp = pet.maxHp;
    expect(petGearOn(s, collar.uid).ok).toBe(true);
    expect(pet.maxHp).toBe(hp + 8);
    expect(petGearOff(s).ok).toBe(true);
    expect(pet.maxHp).toBe(hp);
    expect(s.player.inventory.some((i) => i.baseId === 'halsband_stachel')).toBe(true);
  });

  it('Doppelschlag: das Haustier beißt zweimal', () => {
    const s = make();
    const pet = s.player.pet!;
    pet.abilities = ['doppelbiss'];
    pet.dmg = [5, 5];
    const spot = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => ({ x: pet.pos.x + dx, y: pet.pos.y + dy }))
      .find((q) => isWalkable(s.map, q.x, q.y) && !(q.x === s.player.pos.x && q.y === s.player.pos.y))!;
    const m = spawnMonster(s, monsterDefById('ghul')!, 3, spot, 0);
    m.hp = m.maxHp = 500;
    m.ruestung = 0;
    s.monsters = [m];
    const before = s.log.length;
    for (let i = 0; i < 6; i++) petTurn(s);
    const bites = s.log.slice(before).filter((l) => l.text.includes('beißt')).length;
    expect(bites).toBeGreaterThan(6);
  });
});
