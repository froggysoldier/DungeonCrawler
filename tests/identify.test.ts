import { describe, expect, it } from 'vitest';
import { describeItem, describeMonster, itemName, monsterInsight, nameOf } from '../src/engine/identify';
import { generateEquipment } from '../src/engine/items';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { newGame } from '../src/engine/game';

const make = () => newGame({ name: 'Test', answers: [0, 0, 3, 0, 0], seed: 900, meta: emptyMeta() });

describe('Identifikation', () => {
  it('je höher das Monster über dir, desto weniger weißt du', () => {
    const s = make();
    s.player.stats.int = 5;
    const def = monsterDefById('kanalkroko')!;
    const at = (lv: number) => {
      const m = spawnMonster(s, def, 7, s.player.pos, 0);
      m.level = lv;
      return m;
    };
    s.player.level = 5;
    expect(monsterInsight(s, at(5))).toBe(0);
    expect(monsterInsight(s, at(7))).toBe(1);
    expect(monsterInsight(s, at(9))).toBe(2);
    expect(monsterInsight(s, at(11))).toBe(3);
    expect(monsterInsight(s, at(14))).toBe(4);

    const full = describeMonster(s, at(5));
    expect(full.name).toBe('Kanal-Krokodil');
    expect(full.combat).toMatch(/Schaden/);
    expect(full.abilities).toMatch(/gepanzert/);

    const rough = describeMonster(s, at(9));
    expect(rough.name).toBe('Kanal-Krokodil');
    expect(rough.combat).toBeNull();
    expect(rough.health).toMatch(/Zustand/);

    expect(nameOf(s, at(11))).toBe('ein unbekanntes großes Wesen');
    expect(nameOf(s, at(14))).toBe('etwas sehr Gefährliches');
    expect(describeMonster(s, at(14)).flavor).toBeNull();
  });

  it('Intelligenz und Erfahrung verbessern die Einschätzung', () => {
    const s = make();
    s.player.level = 5;
    s.player.stats.int = 5;
    const m = spawnMonster(s, monsterDefById('kanalkroko')!, 7, s.player.pos, 0);
    m.level = 9;
    expect(monsterInsight(s, m)).toBe(2);
    s.player.stats.int = 11;
    expect(monsterInsight(s, m)).toBe(1);
    s.counters.killsByDef['kanalkroko'] = 6;
    expect(monsterInsight(s, m)).toBe(0);
  });

  it('hohe Seltenheit bleibt bei niedrigem Level unlesbar', () => {
    const s = make();
    s.player.level = 1;
    s.player.stats.int = 5;
    const epic = generateEquipment(s, 'episch', ['fuesse']);
    const d = describeItem(s, epic);
    expect(d.insight).toBe(2);
    expect(d.bonuses).toEqual(['Unbekannte magische Eigenschaften']);
    expect(itemName(s, epic)).toMatch(/Unbekannter epischer Gegenstand/);
    s.player.level = 4;
    expect(describeItem(s, epic).bonuses.every((b) => b.startsWith('?'))).toBe(true);
    s.player.level = 6;
    expect(describeItem(s, epic).name).toBe(epic.name);
  });
});
