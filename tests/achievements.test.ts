import { describe, expect, it } from 'vitest';
import { ACHIEVEMENTS, ACHIEVEMENT_CATEGORIES } from '../src/data/achievements';
import { counterStrike, killMonster } from '../src/engine/combat';
import { emit } from '../src/engine/events';
import { moveStep, newGame } from '../src/engine/game';
import { emptyMeta } from '../src/engine/meta';
import { monsterDefById, spawnMonster } from '../src/engine/monsters';
import { maxHp } from '../src/engine/player';
import { stat } from '../src/engine/stats';
import type { GameState, Monster } from '../src/engine/types';

const make = (seed = 5150) => newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: emptyMeta() });

/** Spielbereit machen: Tutorial vorbei, leerer Raum, ein Gegner daneben. */
function ready(s: GameState) {
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

function foe(s: GameState, id: string, level: number): Monster {
  const spot = ready(s);
  const m = spawnMonster(s, monsterDefById(id)!, level, spot, 0);
  m.aware = true;
  m.abilities = [];
  s.monsters.push(m);
  return m;
}

const has = (s: GameState, id: string) => s.achievements.includes(id);

describe('Achievements: Umfang und Regeln', () => {
  it('es gibt sehr viele Achievements, jedes mit eindeutiger ID und eindeutigem Namen', () => {
    expect(ACHIEVEMENTS.length).toBeGreaterThan(400);
    const ids = new Set(ACHIEVEMENTS.map((a) => a.id));
    expect(ids.size).toBe(ACHIEVEMENTS.length);
    const names = ACHIEVEMENTS.map((a) => a.name);
    const dupes = names.filter((n, i) => names.indexOf(n) !== i);
    expect(dupes).toEqual([]);
  });

  it('jedes Achievement hat eine Kategorie, Beschreibung und einen Kommentar', () => {
    const cats = new Set(ACHIEVEMENT_CATEGORIES.map((c) => c.id));
    for (const a of ACHIEVEMENTS) {
      expect(cats.has(a.category!), a.id).toBe(true);
      expect(a.description.length, a.id).toBeGreaterThan(5);
      expect(a.comment.length, a.id).toBeGreaterThan(5);
    }
    // Jede Kategorie ist gefüllt
    for (const c of cats) expect(ACHIEVEMENTS.some((a) => a.category === c), c).toBe(true);
  });

  it('keine Emojis in Namen, Beschreibungen und Kommentaren', () => {
    const emoji = /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F000}-\u{1F2FF}]/u;
    for (const a of ACHIEVEMENTS) {
      expect(emoji.test(`${a.name} ${a.description} ${a.comment}`), a.id).toBe(false);
    }
  });
});

describe('Statistik', () => {
  it('Kills werden nach Art, Technik und Umständen gezählt', () => {
    const s = make();
    const m = foe(s, 'kellerratte', 1);
    m.asleep = true;
    killMonster(s, m, { part: 'tritt', move: 'normal', zone: 'kopf' }, false, ['t:tritt']);
    expect(stat(s, 'kills')).toBe(1);
    expect(stat(s, 'kills.art.kellerratte')).toBe(1);
    expect(stat(s, 'bestiarium.arten')).toBe(1);
    expect(stat(s, 'kills.teil.tritt')).toBe(1);
    expect(stat(s, 'kills.zone.kopf')).toBe(1);
    expect(stat(s, 'kills.schlafend')).toBe(1);
    expect(has(s, 'fam_schlafend_1')).toBe(true);
  });

  it('eine Art erscheint erst im Bestiarium, wenn man sie erkennen konnte', () => {
    const s = make();
    // Weit über der eigenen Stufe: nicht einzuschätzen
    const big = foe(s, 'kellerratte', 1);
    big.level = s.player.level + 12;
    killMonster(s, big, { part: 'faust', move: 'normal' });
    expect(stat(s, 'kills.unbekannt')).toBe(1);
    expect(has(s, 'art_kellerratte_1')).toBe(false);
    expect(has(s, 'mo_unbekannt')).toBe(true);
    const small = foe(s, 'kellerratte', 1);
    killMonster(s, small, { part: 'faust', move: 'normal' });
    expect(has(s, 'art_kellerratte_1')).toBe(true);
  });

  it('Achievements ohne Box geben nur Ruhm', () => {
    const s = make();
    ready(s);
    const boxes = s.player.boxes.length;
    s.stats = { ...s.stats, 'tueren.geoeffnet': 1 };
    emit(s, { type: 'moved' });
    expect(has(s, 'fam_tueren_1')).toBe(true);
    expect(s.player.boxes.length).toBe(boxes);
    s.stats['tueren.geoeffnet'] = 10;
    emit(s, { type: 'moved' });
    expect(has(s, 'fam_tueren_10')).toBe(true);
    expect(s.player.boxes.length).toBe(boxes + 1);
  });

  it('Konter-Kills werden erkannt', () => {
    const s = make();
    const m = foe(s, 'kellerratte', 1);
    m.hp = 1;
    counterStrike(s, m);
    expect(s.monsters.includes(m)).toBe(false);
    expect(stat(s, 'kills.konter')).toBe(1);
    expect(stat(s, '_konter')).toBe(0);
  });
});

describe('Besondere Momente', () => {
  it('ein Boss bei vollen Lebenspunkten: Makellos', () => {
    const s = make();
    const boss = foe(s, 'kellerratte', 1);
    boss.rank = 'nachbarschaftsboss';
    s.player.hp = maxHp(s);
    killMonster(s, boss, { part: 'faust', move: 'sprung' });
    expect(has(s, 'mo_boss_makellos')).toBe(true);
    expect(has(s, 'mo_boss_sprung')).toBe(true);
  });

  it('Rettung durch das Haustier bei wenig Lebenspunkten', () => {
    const s = make();
    const m = foe(s, 'kellerratte', 1);
    s.player.hp = 1;
    killMonster(s, m, null, true);
    expect(has(s, 'mo_rettung_haustier')).toBe(true);
  });

  it('Kopf, Arme und Beine am selben Gegner: Anatomiestunde', () => {
    const s = make();
    const m = foe(s, 'kellerratte', 1);
    m.zonesHit = ['kopf', 'arme', 'beine'];
    killMonster(s, m, { part: 'faust', move: 'normal' });
    expect(has(s, 'mo_anatomie')).toBe(true);
  });

  it('zwei Stufen mit einem Kill', () => {
    const s = make();
    ready(s);
    const turn = s.turn;
    emit(s, { type: 'levelUp', level: 2 });
    expect(has(s, 'mo_doppelaufstieg')).toBe(false);
    expect(s.turn).toBe(turn);
    emit(s, { type: 'levelUp', level: 3 });
    expect(has(s, 'mo_doppelaufstieg')).toBe(true);
  });

  it('frühe Etagen mit niedriger Stufe', () => {
    const s = make();
    ready(s);
    s.player.level = 3;
    emit(s, { type: 'descend', floor: 2 });
    expect(has(s, 'mo_etage2_frueh')).toBe(true);
  });
});
