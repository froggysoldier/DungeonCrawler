import { GHOST_DEF, MONSTERS, type BossDef, type MonsterDef } from '../data/monsters';
import * as R from './rng';
import type { GameState, GhostRecord, Monster, Pos } from './types';

function mid(s: GameState): string {
  s.uidCounter += 1;
  return `m${s.uidCounter}`;
}

export function spawnMonster(s: GameState, def: MonsterDef, level: number, pos: Pos, hood: number, elite = false): Monster {
  const lv = level + (elite ? 1 : 0);
  const extra = lv - def.levels[0];
  const hpMul = elite ? 1.8 : 1;
  const dmgMul = elite ? 1.3 : 1;
  const maxHp = Math.round((def.hp + def.hpPerLevel * extra) * hpMul);
  return {
    uid: mid(s),
    defId: def.id,
    name: elite ? `${def.name} [Elite]` : def.name,
    glyph: def.glyph,
    color: elite ? '#ff5050' : def.color,
    level: lv,
    hp: maxHp,
    maxHp,
    dmg: [
      Math.round((def.dmg[0] + def.dmgPerLevel * extra * 0.5) * dmgMul),
      Math.round((def.dmg[1] + def.dmgPerLevel * extra) * dmgMul),
    ],
    treffer: def.treffer + lv,
    ruestung: def.ruestung + (elite ? 1 : 0),
    ausweichen: def.ausweichen,
    size: def.size,
    behavior: def.behavior,
    range: def.range,
    xp: Math.round((def.xp + extra * 4) * (elite ? 2.5 : 1)),
    pos: { ...pos },
    hood,
    rank: elite ? 'elite' : 'normal',
    downed: 0,
    aware: false,
    flavor: def.flavor,
    abilities: def.abilities ? [...def.abilities] : undefined,
  };
}

export function spawnBoss(s: GameState, def: BossDef, pos: Pos, hood: number, room: number, floor: number): Monster {
  // Bosse, die auf einer tieferen Etage als ihrer ersten auftauchen, werden stärker.
  const levelBonus = Math.max(0, floor - Math.min(...def.floors)) * 2;
  const scale = 1 + levelBonus * 0.25;
  const maxHp = Math.round(def.hp * scale);
  return {
    uid: mid(s),
    defId: def.id,
    name: def.name,
    glyph: def.glyph,
    color: def.color,
    level: def.level + levelBonus,
    hp: maxHp,
    maxHp,
    dmg: [Math.round(def.dmg[0] * scale), Math.round(def.dmg[1] * scale)],
    treffer: def.treffer,
    ruestung: def.ruestung,
    ausweichen: def.ausweichen,
    size: def.size,
    behavior: def.range ? 'ranged' : 'boss',
    range: def.range,
    xp: Math.round(def.xp * scale),
    pos: { ...pos },
    hood,
    rank: def.rank,
    downed: 0,
    aware: false,
    homeRoom: room,
    loot: def.loot,
    flavor: def.flavor,
    abilities: def.abilities ? [...def.abilities] : undefined,
  };
}

/** Der Geist eines früheren, gestorbenen Crawlers. */
export function spawnGhost(s: GameState, ghost: GhostRecord, pos: Pos, hood: number): Monster {
  const lv = Math.max(2, ghost.level + 1);
  const maxHp = 20 + lv * 9;
  return {
    uid: mid(s),
    defId: 'geist',
    name: `Geist von ${ghost.name}`,
    glyph: GHOST_DEF.glyph,
    color: GHOST_DEF.color,
    level: lv,
    hp: maxHp,
    maxHp,
    dmg: [2 + lv, 4 + lv * 2],
    treffer: 75,
    ruestung: 1 + Math.floor(lv / 3),
    ausweichen: 15,
    size: 'mittel',
    behavior: 'melee',
    xp: 40 + lv * 20,
    pos: { ...pos },
    hood,
    rank: 'geist',
    downed: 0,
    aware: false,
    ghostOf: ghost.name,
    ghostItems: ghost.items,
    flavor: `Das ist ${ghost.name} aus Staffel ${ghost.season}. Oder was davon übrig ist. Gestorben auf dieser Etage, mit Level ${ghost.level}. Trägt noch die alte Ausrüstung.`,
  };
}

/** Wählt einen Monstertyp, der auf dieser Etage und in diesem Level vorkommt. */
export function pickMonsterDef(s: GameState, floor: number, level: number): MonsterDef {
  const onFloor = MONSTERS.filter((m) => m.floors.includes(floor));
  const pool = onFloor.filter((m) => level >= m.levels[0] && level <= m.levels[1] + 2);
  const list = pool.length ? pool : onFloor.length ? onFloor : MONSTERS;
  return R.weighted(s, list.map((m) => [m, m.weight] as [MonsterDef, number]));
}

/** Level eines Mobs: innerhalb seiner Spanne, auf tieferen Etagen bis zu 2 darüber. */
export function clampLevel(def: MonsterDef, level: number): number {
  return Math.max(def.levels[0], Math.min(def.levels[1] + 2, level));
}

/** Spawnt einen Mob passend zur Etage (für Nachspawns und Verstärkung). */
export function spawnForFloor(s: GameState, floor: number, level: number, pos: Pos, hood: number, elite: boolean): Monster {
  const def = pickMonsterDef(s, floor, level);
  return spawnMonster(s, def, clampLevel(def, level), pos, hood, elite);
}

export function monsterDefById(id: string): MonsterDef | undefined {
  return MONSTERS.find((m) => m.id === id);
}
