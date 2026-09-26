import { emit } from './events';
import { chebyshev } from './fov';
import { log } from './log';
import { isWalkable } from './mapgen';
import { monsterDefById, spawnForFloor, spawnMonster } from './monsters';
import * as R from './rng';
import type { GameState, Monster, MonsterAbility, Pos } from './types';

export const ABILITY_NAMES: Record<MonsterAbility, string> = {
  gift: 'giftig',
  explodiert: 'explodiert beim Tod',
  diebisch: 'klaut Gold',
  rufer: 'ruft Verstärkung',
  regeneriert: 'regeneriert',
  schnell: 'schnell',
  fliegend: 'fliegt',
  gepanzert: 'gepanzert (halber Faustschaden)',
};

export const has = (m: Monster, a: MonsterAbility) => !!m.abilities?.includes(a);

export function hasSpecial(s: GameState, special: string): boolean {
  return Object.values(s.player.equipment).some((i) => i?.special === special);
}

/** Vergiftet den Crawler (stapelt nicht, frischt aber auf). */
export function poison(s: GameState, source: string, strength: number) {
  if (hasSpecial(s, 'giftimmun')) {
    log(s, `${source} will dich vergiften – deine Ausrüstung neutralisiert das Gift.`, 'info');
    return;
  }
  const p = s.player;
  const existing = p.buffs.find((b) => b.name === 'Vergiftet');
  if (existing) {
    existing.turns = Math.max(existing.turns, 6);
    existing.dot = Math.max(existing.dot ?? 1, strength);
  } else {
    p.buffs.push({ name: 'Vergiftet', turns: 6, bonuses: {}, dot: strength, debuff: true });
  }
  log(s, `Du bist vergiftet! (${strength} Schaden pro Zug)`, 'gefahr');
  emit(s, { type: 'poisoned', source });
}

export function cure(s: GameState): boolean {
  const before = s.player.buffs.length;
  s.player.buffs = s.player.buffs.filter((b) => b.name !== 'Vergiftet');
  if (s.player.buffs.length === before) return false;
  log(s, 'Das Gift ist neutralisiert.', 'info');
  emit(s, { type: 'cured' });
  return true;
}

/** Wird aufgerufen, wenn ein Monster den Crawler getroffen hat. */
export function onMonsterHit(s: GameState, m: Monster) {
  if (has(m, 'gift') && R.chance(s, 0.4)) poison(s, m.name, 1 + Math.floor(m.level / 4));
  if (has(m, 'diebisch') && s.player.gold > 0 && !m.stolenGold && R.chance(s, 0.5)) {
    const amount = Math.min(s.player.gold, 5 + m.level * 3);
    s.player.gold -= amount;
    m.stolenGold = amount;
    m.fleeing = true;
    s.counters.goldStolen += amount;
    log(s, `${m.name} klaut dir ${amount} Gold und rennt davon!`, 'gefahr');
    emit(s, { type: 'robbed', amount, source: m.name });
  }
}

/** Fähigkeiten, die zu Beginn eines Monsterzugs greifen. */
export function startOfTurn(s: GameState, m: Monster) {
  if (has(m, 'regeneriert') && m.hp < m.maxHp) {
    m.hp = Math.min(m.maxHp, m.hp + Math.max(1, Math.round(m.maxHp * 0.04)));
  }
  if (has(m, 'rufer') && m.aware && (m.summoned ?? 0) < 2 && R.chance(s, 0.12)) summon(s, m);
}

const NEIGHBORS: Pos[] = [
  { x: 1, y: 0 }, { x: -1, y: 0 }, { x: 0, y: 1 }, { x: 0, y: -1 },
  { x: 1, y: 1 }, { x: 1, y: -1 }, { x: -1, y: 1 }, { x: -1, y: -1 },
];

function summon(s: GameState, m: Monster) {
  const free = NEIGHBORS.map((d) => ({ x: m.pos.x + d.x, y: m.pos.y + d.y })).filter(
    (p) => isWalkable(s.map, p.x, p.y) && !isTaken(s, p) && (m.homeRoom === undefined || s.map.roomAt[p.y * s.map.width + p.x] === m.homeRoom),
  );
  if (!free.length) return;
  const pos = R.pick(s, free);
  const level = Math.max(1, m.level - 3);
  const isRat = m.defId.includes('ratte') || m.defId === 'rattenschamane' || m.defId === 'rattenkaiser' || m.defId === 'rattenmensch';
  const ratDef = monsterDefById(s.floor >= 2 ? 'knochenratte' : 'kellerratte');
  const minion = isRat && ratDef ? spawnMonster(s, ratDef, Math.max(ratDef.levels[0], level), pos, m.hood) : spawnForFloor(s, s.floor, level, pos, m.hood, false);
  minion.aware = true;
  // Diener eines Bosses bleiben mit ihm in der Kammer
  if (m.homeRoom !== undefined) minion.homeRoom = m.homeRoom;
  s.monsters.push(minion);
  m.summoned = (m.summoned ?? 0) + 1;
  log(s, `${m.name} ruft Verstärkung: ${minion.name} taucht auf!`, 'gefahr');
}

function isTaken(s: GameState, p: Pos): boolean {
  if (s.player.pos.x === p.x && s.player.pos.y === p.y) return true;
  const pet = s.player.pet;
  if (pet?.alive && pet.pos.x === p.x && pet.pos.y === p.y) return true;
  return s.monsters.some((o) => o.pos.x === p.x && o.pos.y === p.y);
}

export function isAdjacent(a: Pos, b: Pos) {
  return chebyshev(a, b) <= 1;
}
