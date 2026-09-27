import { describe, expect, it } from 'vitest';
import { ABILITIES, CLASSES, CLASS_BY_ID } from '../src/data/classes';
import { BASE_ITEMS } from '../src/data/items';
import { RACES } from '../src/data/races';
import { SKILL_BY_ID } from '../src/data/skills';
import { SPECIAL_TEXT } from '../src/data/specials';
import { SPELL_BY_ID } from '../src/data/spells';
import { passProtects } from '../src/engine/extras';
import { CLASS_LIST_SIZE, chooseRaceAndClass, classOptions, raceOptions } from '../src/engine/classes';
import { descend, newGame } from '../src/engine/game';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { maxHp, totalBonuses } from '../src/engine/player';
import { createItem } from '../src/engine/items';
import { offerPrice, sellPrice } from '../src/engine/shop';
import type { GameState } from '../src/engine/types';

const make = (seed = 3100) => newGame({ name: 'Test', answers: [0, 0, 0, 0, 0], seed, meta: emptyMeta() });

function toFloor3(s: GameState) {
  while (s.floor < 3) {
    const i = s.map.tiles.indexOf('stairs');
    s.player.pos = { x: i % s.map.width, y: Math.floor(i / s.map.width) };
    descend(s, { ghosts: [] });
  }
}

describe('Klassen und Rassen: Daten', () => {
  it('es gibt viele Klassen und Rassen mit eindeutigen IDs und Namen', () => {
    expect(CLASSES.length).toBeGreaterThanOrEqual(45);
    expect(RACES.length).toBeGreaterThanOrEqual(24);
    expect(new Set(CLASSES.map((c) => c.id)).size).toBe(CLASSES.length);
    expect(new Set(CLASSES.map((c) => c.name)).size).toBe(CLASSES.length);
    expect(new Set(RACES.map((r) => r.id)).size).toBe(RACES.length);
  });

  it('alle Verweise zeigen auf existierende Skills, Zauber, Gegenstände und Fähigkeiten', () => {
    for (const c of CLASSES) {
      expect(ABILITIES[c.ability], c.id).toBeDefined();
      expect(c.skills.length, c.id).toBeGreaterThanOrEqual(1);
      for (const id of c.skills) expect(SKILL_BY_ID[id], `${c.id}: ${id}`).toBeDefined();
      for (const id of c.spells ?? []) expect(SPELL_BY_ID[id], `${c.id}: ${id}`).toBeDefined();
      for (const [id] of c.gear ?? []) expect(BASE_ITEMS.some((b) => b.id === id), `${c.id}: ${id}`).toBe(true);
      for (const sp of c.specials ?? []) expect(SPECIAL_TEXT[sp], `${c.id}: ${sp}`).toBeDefined();
      if (c.rarity !== 'normal') expect(c.requirement, c.id).toBeDefined();
    }
    for (const r of RACES) {
      if (r.talent) expect(SKILL_BY_ID[r.talent], `${r.id}: ${r.talent}`).toBeDefined();
      for (const sp of r.specials ?? []) expect(SPECIAL_TEXT[sp], `${r.id}: ${sp}`).toBeDefined();
    }
  });
});

describe('Persönliche Klassenliste', () => {
  it('zeigt zehn gewöhnliche Klassen und seltene nur mit erfüllter Bedingung', () => {
    const s = make();
    const opts = classOptions(s);
    expect(opts.filter((o) => o.klass.rarity === 'normal')).toHaveLength(CLASS_LIST_SIZE);
    expect(opts.some((o) => o.klass.rarity !== 'normal')).toBe(false);
    expect(opts.filter((o) => o.recommended)).toHaveLength(3);
    s.stats = { ...s.stats, 'knapp.ueberlebt': 12 };
    const withRare = classOptions(s);
    expect(withRare.some((o) => o.klass.id === 'todesveraechter')).toBe(true);
  });

  it('Interview und Verhalten beeinflussen die Empfehlung', () => {
    const s = make(3101);
    s.player.traits = [...(s.player.traits ?? []), 'social_media'];
    expect(classOptions(s).find((o) => o.klass.id === 'influencer')?.recommended).toBe(true);
  });
});

describe('Wahl von Rasse und Klasse', () => {
  it('Klassenskills, Begabung, Startzauber und Startausrüstung werden vergeben', () => {
    const s = make(3102);
    toFloor3(s);
    s.player.stats = { ...s.player.stats, int: 12 };
    s.player.techniqueUses = {};
    const opt = classOptions(s).find((o) => o.klass.id === 'kellermagier');
    expect(opt).toBeDefined();
    expect(chooseRaceAndClass(s, 'elf', 'kellermagier').ok).toBe(true);
    const p = s.player;
    expect(p.classSkills).toEqual(expect.arrayContaining(['arkane_kunde', 'wahrnehmung']));
    expect(p.skills.find((k) => k.id === 'arkane_kunde')!.level).toBeGreaterThanOrEqual(2);
    expect(p.spells?.map((x) => x.id)).toEqual(expect.arrayContaining(['geschoss', 'fackel']));
    expect(p.inventory.some((i) => i.baseId === 'kleiner_manatrank')).toBe(true);
  });

  it('gesperrte Rassen und Klassen lassen sich nicht wählen', () => {
    const s = make(3103);
    toFloor3(s);
    expect(raceOptions(s).find((r) => r.race.id === 'drachenblut')!.available).toBe(false);
    expect(chooseRaceAndClass(s, 'drachenblut', classOptions(s)[0].klass.id).ok).toBe(false);
    expect(chooseRaceAndClass(s, 'mensch', 'wiedergaenger').ok).toBe(false);
  });
});

describe('Sondereigenschaften', () => {
  it('Rattenfreund: Ratten lassen dich in Ruhe, bis du sie angreifst', () => {
    const s = make(3104);
    s.player.race = 'rattling';
    const rat = spawnMonster(s, monsterDefById('kellerratte')!, 1, s.player.pos, 0);
    expect(passProtects(s, rat)).toBe(true);
    rat.provoked = true;
    expect(passProtects(s, rat)).toBe(false);
  });

  it('Händlerblut: günstiger kaufen, teurer verkaufen', () => {
    const s = make(3105);
    const it = createItem(s, 'heiltrank');
    const buy = offerPrice(100, it, s);
    const sell = sellPrice(it, s);
    s.player.klass = 'marktschreier';
    expect(offerPrice(100, it, s)).toBeLessThan(buy);
    expect(sellPrice(it, s)).toBeGreaterThan(sell);
  });

  it('Zäh: unter 25 % Lebenspunkten mehr Schaden und Ausweichen', () => {
    const s = make(3106);
    s.player.klass = 'todesveraechter';
    s.player.hp = maxHp(s);
    const full = totalBonuses(s);
    s.player.hp = 1;
    const low = totalBonuses(s);
    expect(low.schaden?.alle ?? 0).toBeGreaterThan(full.schaden?.alle ?? 0);
    expect(low.ausweichen ?? 0).toBeGreaterThan(full.ausweichen ?? 0);
  });

  it('jede Klasse ist über ihre ID erreichbar', () => {
    for (const c of CLASSES) expect(CLASS_BY_ID[c.id]).toBe(c);
  });
});
