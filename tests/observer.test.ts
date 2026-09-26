import { describe, expect, it } from 'vitest';
import { INTERVIEW, visibleQuestions } from '../src/data/interview';
import { hitChance } from '../src/engine/combat';
import { emit } from '../src/engine/events';
import { newGame } from '../src/engine/game';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { attackFacets, selfFacets, targetFacets } from '../src/engine/observer';
import type { GameState, Monster, Technique } from '../src/engine/types';

const make = (answers: Record<string, number> = { beruf: 1 }) => newGame({ name: 'Test', answers, seed: 1200, meta: emptyMeta() });

function mob(s: GameState, id: string, level = 2): Monster {
  const m = spawnMonster(s, monsterDefById(id)!, level, { x: s.player.pos.x + 1, y: s.player.pos.y }, 0);
  m.aware = true;
  return m;
}

/** Simuliert einen Kill mit vollem Kontext, wie ihn der Kampf erzeugt. */
function kill(s: GameState, m: Monster, t: Technique) {
  const facets = attackFacets(s, m, t);
  emit(s, { type: 'attack', technique: t, hit: true, crit: false, damage: 5, target: m, facets });
  s.counters.kills += 1;
  s.counters.killsByDef[m.defId] = (s.counters.killsByDef[m.defId] ?? 0) + 1;
  emit(s, { type: 'kill', monster: m, technique: t, facets });
  s.turn += 10; // Abstand zwischen Mustern
}

describe('Beobachter: Facetten', () => {
  it('erkennt Ziel, Zustand und Technik', () => {
    const s = make();
    const bat = mob(s, 'fledermaus');
    bat.aware = false;
    const z = targetFacets(s, bat);
    expect(z).toEqual(expect.arrayContaining(['z:tier', 'z:winzig', 'z:fliegend', 'z:schnell', 'z:ahnungslos']));
    delete s.player.equipment.fuesse;
    s.player.hp = 1;
    expect(selfFacets(s)).toEqual(expect.arrayContaining(['i:barfuss', 'i:fasttot']));
    expect(attackFacets(s, bat, { part: 'tritt', move: 'sprung' })).toEqual(expect.arrayContaining(['t:tritt', 'm:sprung']));
  });
});

describe('Beobachter: dynamische Achievements', () => {
  it('ungewöhnliche Kombinationen werden sofort erkannt und benannt', () => {
    const s = make();
    delete s.player.equipment.fuesse;
    const before = s.player.boxes.length;
    kill(s, mob(s, 'ghul', 3), { part: 'kopf', move: 'normal' });
    expect(s.dynAchievements?.length).toBeGreaterThan(0);
    expect(s.player.boxes.length).toBeGreaterThan(before);
    const a = s.dynAchievements![0];
    expect(a.name).toMatch(/ I$/);
    expect(a.description).toMatch(/Getötet: 1/);
  });

  it('gewöhnliche Kills lösen nicht sofort etwas aus, aber bei Wiederholung', () => {
    const s = make();
    s.player.equipment.fuesse = s.player.equipment.fuesse ?? { uid: 'x', baseId: 'turnschuhe', name: 'Turnschuhe', kind: 'ausruestung', rarity: 'gewoehnlich', slot: 'fuesse', flavor: '', wert: 1 };
    s.player.equipment.brust = { uid: 'y', baseId: 'hoodie', name: 'Hoodie', kind: 'ausruestung', rarity: 'gewoehnlich', slot: 'brust', flavor: '', wert: 1 };
    s.player.hand = { uid: 'w', baseId: 'rohr', name: 'Rohr', kind: 'ausruestung', rarity: 'gewoehnlich', slot: 'waffe', waffenSchaden: 3, flavor: '', wert: 1 };
    kill(s, mob(s, 'kellerratte', 1), { part: 'faust', move: 'normal' });
    expect(s.dynAchievements ?? []).toHaveLength(0);
    for (let i = 0; i < 20; i++) kill(s, mob(s, 'kellerratte', 1), { part: 'faust', move: 'normal' });
    expect((s.dynAchievements ?? []).length).toBeGreaterThan(0);
  });

  it('dieselbe Kombination steigt in Stufen auf (I, II, …)', () => {
    const s = make();
    delete s.player.equipment.fuesse;
    for (let i = 0; i < 16; i++) kill(s, mob(s, 'ghul', 3), { part: 'kopf', move: 'normal' });
    const names = (s.dynAchievements ?? []).map((a) => a.name);
    expect(names.some((n) => n.endsWith(' II'))).toBe(true);
  });
});

describe('Beobachter: dynamische Skills', () => {
  it('wiederholte Treffer gegen eine Gegnerart erzeugen einen passenden Skill mit Bonus', () => {
    const s = make();
    const bat = mob(s, 'fledermaus');
    const t: Technique = { part: 'tritt', move: 'normal' };
    const hitBefore = hitChance(s, bat, t);
    for (let i = 0; i < 12; i++) emit(s, { type: 'attack', technique: t, hit: true, crit: false, damage: 3, target: bat, facets: attackFacets(s, bat, t) });
    const skill = (s.player.dynSkills ?? []).find((k) => k.name === 'Tritte gegen Flieger');
    expect(skill).toBeDefined();
    expect(hitChance(s, bat, t)).toBeGreaterThan(hitBefore);
    // Gilt nicht für andere Techniken
    const fist = (s.player.dynSkills ?? []).filter((k) => k.part === 'faust');
    expect(fist).toHaveLength(0);
  });

  it('wiederholtes Ausweichen erzeugt einen Ausweich-Skill', () => {
    const s = make();
    for (let i = 0; i < 10; i++) emit(s, { type: 'dodged', source: 'x', facets: ['z:fernkampf'] });
    expect((s.player.dynSkills ?? []).some((k) => k.kind === 'ausweichen' && k.facet === 'z:fernkampf')).toBe(true);
  });
});

describe('Eigenschaften und Interview', () => {
  it('Angst senkt die Trefferchance und lässt sich überwinden', () => {
    const calm = make({ beruf: 1, angst: 5 });
    const scared = make({ beruf: 1, angst: 0 });
    const t: Technique = { part: 'faust', move: 'normal' };
    const spiderA = mob(calm, 'kellerspinne');
    const spiderB = mob(scared, 'kellerspinne');
    expect(hitChance(scared, spiderB, t)).toBeLessThan(hitChance(calm, spiderA, t));
    expect(scared.player.traits).toContain('angst_krabbeltiere');
    for (let i = 0; i < 10; i++) kill(scared, mob(scared, 'kellerspinne'), t);
    expect(scared.player.traits).toContain('krabbeltier_schreck');
    expect(scared.player.traits).not.toContain('angst_krabbeltiere');
  });

  it('Folgefragen erscheinen nur passend zur vorherigen Antwort', () => {
    const ids = (a: Record<string, number>) => visibleQuestions(a).map((q) => q.id);
    expect(ids({ beruf: 0 })).toContain('handwerk');
    expect(ids({ beruf: 0 })).not.toContain('sport');
    expect(ids({ beruf: 5 })).toContain('sport');
    expect(ids({ hobbysport: 1 })).toContain('kampfsport');
    expect(ids({ ort: 5 })).not.toContain('hand');
    expect(INTERVIEW.length).toBeGreaterThanOrEqual(20);
  });

  it('Antworten bestimmen Handgegenstand, Eigenschaften und Kombinationen', () => {
    const s = make({ beruf: 5, sport: 1, hobbysport: 1, kampfsport: 3, ort: 5 });
    expect(s.player.hand?.baseId).toBe('klobuerste');
    expect(s.player.traits).toContain('profischlaeger');
    expect(s.player.background).toBe('Profiboxer*in');
  });
});
