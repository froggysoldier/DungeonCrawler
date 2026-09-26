import { NameOf, nameOf } from './identify';
import { isInSafeRoom, killMonster } from './combat';
import { emit } from './events';
import { chebyshev, hasLineOfSight } from './fov';
import { log } from './log';
import { idx, randomOpenTile, roomOf } from './mapgen';
import { canStep, findPath } from './path';
import { has, onMonsterHit, startOfTurn } from './abilities';
import { handleLethal } from './death';
import { passProtects, petCast } from './extras';
import { crawlerAt, monsterHitsCrawler } from './crawlers';
import { dynDefenseBonus, targetFacets, trainDefense } from './observer';
import { ausweichen, totalBonuses } from './player';
import * as R from './rng';
import type { GameState, Monster, Pos } from './types';

const DIRS: Pos[] = [
  { x: 1, y: 0 }, { x: -1, y: 0 }, { x: 0, y: 1 }, { x: 0, y: -1 },
  { x: 1, y: 1 }, { x: 1, y: -1 }, { x: -1, y: 1 }, { x: -1, y: -1 },
];

export function occupied(s: GameState, p: Pos, except?: Monster): boolean {
  if (s.player.pos.x === p.x && s.player.pos.y === p.y) return true;
  const pet = s.player.pet;
  if (pet?.alive && pet.pos.x === p.x && pet.pos.y === p.y) return true;
  if (crawlerAt(s, p)) return true;
  return s.monsters.some((m) => m !== except && m.pos.x === p.x && m.pos.y === p.y);
}

export function monsterAt(s: GameState, p: Pos): Monster | undefined {
  return s.monsters.find((m) => m.pos.x === p.x && m.pos.y === p.y);
}

function allowedTile(s: GameState, m: Monster, p: Pos): boolean {
  const r = s.map.roomAt[idx(s.map, p.x, p.y)];
  if (m.homeRoom !== undefined) return r === m.homeRoom;
  // Normale Monster meiden Boss-Kammern
  const kind = r >= 0 ? s.map.rooms[r].kind : null;
  return kind !== 'boss' && kind !== 'arena';
}

function stepToward(s: GameState, m: Monster, goal: Pos) {
  const path = findPath(s.map, m.pos, goal, (x, y) => allowedTile(s, m, { x, y }) && !occupied(s, { x, y }, m), 250);
  const next = path?.[0];
  if (next && !occupied(s, next, m) && allowedTile(s, m, next)) {
    m.pos = next;
    return;
  }
  // Fallback: gierig in Richtung Ziel
  const opts = DIRS.map((d) => ({ x: m.pos.x + d.x, y: m.pos.y + d.y }))
    .filter((p) => canStep(s.map, m.pos, p) && !occupied(s, p, m) && allowedTile(s, m, p))
    .sort((a, b) => chebyshev(a, goal) - chebyshev(b, goal));
  if (opts[0] && chebyshev(opts[0], goal) < chebyshev(m.pos, goal)) m.pos = opts[0];
}

function stepAway(s: GameState, m: Monster, from: Pos) {
  const opts = DIRS.map((d) => ({ x: m.pos.x + d.x, y: m.pos.y + d.y }))
    .filter((p) => canStep(s.map, m.pos, p) && !occupied(s, p, m) && allowedTile(s, m, p))
    .sort((a, b) => chebyshev(b, from) - chebyshev(a, from));
  if (opts[0] && chebyshev(opts[0], from) >= chebyshev(m.pos, from)) m.pos = opts[0];
}

function wander(s: GameState, m: Monster) {
  if (!R.chance(s, 0.3)) return;
  const d = R.pick(s, DIRS);
  const p = { x: m.pos.x + d.x, y: m.pos.y + d.y };
  if (canStep(s.map, m.pos, p) && !occupied(s, p, m) && allowedTile(s, m, p) && !isInSafeRoom(s, p)) m.pos = p;
}

function canSeePlayer(s: GameState, m: Monster, range: number): boolean {
  const d = chebyshev(m.pos, s.player.pos);
  return d <= range && hasLineOfSight(s.map, m.pos, s.player.pos);
}

/** Ein Monster greift den Crawler an. */
function attackPlayer(s: GameState, m: Monster, ranged: boolean) {
  const p = s.player;
  // Safe-Room-Regel: Wer im Safe Room angreift, wird weg-teleportiert.
  if (isInSafeRoom(s, p.pos)) {
    const dest = randomOpenTile(s, m.pos, 25, (q) => occupied(s, q, m) || chebyshev(q, p.pos) < 8);
    if (dest) {
      m.pos = dest;
      m.aware = false;
      log(s, `${NameOf(s, m)} will dich im Safe Room angreifen – und wird mit einem lauten *PLOPP* weggebeamt.`, 'system');
    }
    return;
  }
  const b = totalBonuses(s);
  const source = targetFacets(s, m).filter((f) => f !== 'z:ahnungslos');
  if (ranged && !source.includes('z:fernkampf')) source.push('z:fernkampf');
  const defense = dynDefenseBonus(s, source);
  const hit = Math.max(5, Math.min(95, m.treffer - ausweichen(s, b) - defense.ausweichen - (ranged ? 5 : 0)));
  const verb = ranged ? 'schießt auf dich' : 'greift an';
  if (R.next(s) * 100 >= hit) {
    s.counters.hitTakenStreak = 0;
    log(s, `${NameOf(s, m)} ${verb} – du weichst aus.`, 'kampf');
    trainDefense(s, source, 'ausweichen');
    emit(s, { type: 'dodged', source: m.name, facets: source });
    return;
  }
  let raw = R.int(s, m.dmg[0], m.dmg[1]);
  // Schilde (z. B. Irrlichtrüstung) fangen zuerst ab
  for (const buff of p.buffs) {
    if (!buff.absorb || raw <= 0) continue;
    const taken = Math.min(buff.absorb, raw);
    buff.absorb -= taken;
    raw -= taken;
    log(s, `${buff.name} fängt ${taken} Schaden ab.`, 'kampf');
    if (buff.absorb <= 0) buff.turns = 0;
  }
  if (raw <= 0) {
    emit(s, { type: 'dodged', source: m.name, facets: source });
    return;
  }
  const dmg = Math.max(1, Math.round((raw - Math.floor(b.ruestung ?? 0)) * (1 - defense.reduktion / 100)));
  if (defense.reduktion) trainDefense(s, source, 'abhaertung');
  p.hp -= dmg;
  s.counters.damageTaken += dmg;
  s.counters.hitTakenStreak += 1;
  log(s, `${NameOf(s, m)} ${verb} und trifft dich für ${dmg} Schaden.`, 'gefahr');
  if (b.dornen && !ranged) {
    m.hp -= b.dornen;
    log(s, `Deine Dornen stechen ${nameOf(s, m)} für ${b.dornen} Schaden.`, 'kampf');
    if (m.hp <= 0) killMonster(s, m, null);
  }
  if (p.hp <= 0) {
    handleLethal(s, `getötet von ${nameOf(s, m)}`);
    return;
  }
  emit(s, { type: 'damageTaken', amount: dmg, source: m.name, facets: source });
  onMonsterHit(s, m);
}

function attackPet(s: GameState, m: Monster) {
  const pet = s.player.pet!;
  if (R.chance(s, 0.3)) {
    log(s, `${NameOf(s, m)} schnappt nach ${pet.name}, verfehlt aber.`, 'kampf');
    return;
  }
  const dmg = Math.max(1, R.int(s, m.dmg[0], m.dmg[1]) - 1);
  pet.hp -= dmg;
  log(s, `${NameOf(s, m)} trifft ${pet.name} für ${dmg} Schaden.`, 'gefahr');
  if (pet.hp <= 0) {
    pet.hp = 0;
    pet.alive = false;
    log(s, `${pet.name} bricht bewusstlos zusammen und verschwindet in einem Transportlicht. Schlaf in einem Safe Room, dann kommt ${pet.name} zurück.`, 'gefahr');
  }
}

export function monsterTurn(s: GameState, m: Monster) {
  if (s.status !== 'playing' || !s.monsters.includes(m)) return;
  if (m.downed > 0) {
    m.downed -= 1;
    if (m.downed === 0) log(s, `${NameOf(s, m)} rappelt sich wieder auf.`, 'kampf');
    return;
  }
  startOfTurn(s, m);
  const p = s.player;
  const d = chebyshev(m.pos, p.pos);

  // Wahrnehmung
  if (!m.aware) {
    if (m.homeRoom !== undefined) {
      if (roomOf(s.map, p.pos)?.id === m.homeRoom) {
        m.aware = true;
        log(s, `${NameOf(s, m)} bemerkt dich!`, 'gefahr');
      }
    } else if (canSeePlayer(s, m, 7) && R.chance(s, d <= 1 ? 1 : d <= 3 ? 0.7 : 0.35)) {
      m.aware = true;
      log(s, `${NameOf(s, m)} hat dich bemerkt!`, 'gefahr');
    }
  }
  if (!m.aware) {
    if (m.behavior !== 'stationary' && m.homeRoom === undefined) wander(s, m);
    return;
  }
  // Pässe und Talismane: diese Gegnerart lässt dich in Ruhe, solange du sie nicht angreifst
  if (passProtects(s, m)) {
    m.aware = false;
    wander(s, m);
    return;
  }

  // Verliert das Interesse, wenn der Crawler weit weg ist
  if (d > 14 && m.homeRoom === undefined) {
    m.aware = false;
    return;
  }

  const pet = p.pet?.alive ? p.pet : null;
  const petAdj = pet && chebyshev(m.pos, pet.pos) <= 1;

  // Fliehen bei wenig Leben (keine Bosse)
  if (m.rank === 'normal' && m.hp < m.maxHp * 0.25 && !m.fleeing && R.chance(s, 0.3)) {
    m.fleeing = true;
    log(s, `${NameOf(s, m)} versucht zu fliehen!`, 'kampf');
  }
  if (m.behavior === 'coward' && d <= 4) m.fleeing = true;
  if (m.fleeing) {
    stepAway(s, m, p.pos);
    if (has(m, 'schnell')) stepAway(s, m, p.pos);
    return;
  }

  if (monsterHitsCrawler(s, m)) return;
  if (d <= 1) {
    if (petAdj && R.chance(s, 0.25)) attackPet(s, m);
    else attackPlayer(s, m, false);
    return;
  }
  if (petAdj && m.behavior !== 'ranged') {
    attackPet(s, m);
    return;
  }
  if ((m.behavior === 'ranged' || m.range) && d <= (m.range ?? 4) && hasLineOfSight(s.map, m.pos, p.pos)) {
    attackPlayer(s, m, true);
    return;
  }
  if (m.behavior === 'stationary') return;
  stepToward(s, m, p.pos);
  if (has(m, 'schnell') && chebyshev(m.pos, p.pos) > 1) stepToward(s, m, p.pos);
}

export function petTurn(s: GameState) {
  const pet = s.player.pet;
  if (!pet?.alive || s.status !== 'playing') return;
  const p = s.player;
  // Gegner neben dem Haustier angreifen (bevorzugt solche, die auch neben dem Crawler stehen)
  const targets = s.monsters
    .filter((m) => chebyshev(m.pos, pet.pos) <= 1 && !isInSafeRoom(s, m.pos))
    .sort((a, b) => chebyshev(a.pos, p.pos) - chebyshev(b.pos, p.pos));
  // Ein erwachtes Haustier zaubert Magische Geschosse
  const spellTarget = petCast(s, pet);
  if (spellTarget) {
    const dmg = Math.max(1, Math.round(2 + pet.level * 1.5 - spellTarget.ruestung / 2));
    spellTarget.hp -= dmg;
    spellTarget.aware = true;
    log(s, `${pet.name} schießt Magische Geschosse aus den Augen: ${dmg} Schaden an ${nameOf(s, spellTarget)}.`, 'kampf');
    if (spellTarget.hp <= 0) killMonster(s, spellTarget, null, true);
    return;
  }
  const t = targets[0];
  if (t) {
    if (R.chance(s, 0.25)) {
      log(s, `${pet.name} faucht ${nameOf(s, t)} an, verfehlt aber.`, 'kampf');
      return;
    }
    let dmg = R.int(s, pet.dmg[0], pet.dmg[1]);
    if (Object.values(p.equipment).some((i) => i?.special === 'katzenfreund')) dmg = Math.round(dmg * 1.5);
    t.hp -= Math.max(1, dmg - t.ruestung);
    t.aware = true;
    log(s, `${pet.name} beißt ${nameOf(s, t)} für ${Math.max(1, dmg - t.ruestung)} Schaden.`, 'kampf');
    if (t.hp <= 0) {
      pet.xp += t.xp;
      while (pet.xp >= pet.level * 60) {
        pet.xp -= pet.level * 60;
        petLevelUp(s);
      }
      killMonster(s, t, null, true);
    }
    return;
  }
  // Folgen
  if (chebyshev(pet.pos, p.pos) > 2) {
    const path = findPath(s.map, pet.pos, p.pos, (x, y) => !occupied(s, { x, y }), 300);
    const next = path?.[0];
    if (next && !(next.x === p.pos.x && next.y === p.pos.y) && !occupied(s, next)) pet.pos = next;
    else if (chebyshev(pet.pos, p.pos) > 8) {
      // Zu weit weg – das Haustier teleportiert sich hinterher (Dungeon-Magie).
      const dest = DIRS.map((d) => ({ x: p.pos.x + d.x, y: p.pos.y + d.y })).find(
        (q) => canStep(s.map, p.pos, q) && !occupied(s, q),
      );
      if (dest) pet.pos = dest;
    }
  }
}

export function petLevelUp(s: GameState) {
  const pet = s.player.pet;
  if (!pet) return;
  pet.level += 1;
  pet.maxHp += 5;
  pet.hp = pet.maxHp;
  pet.dmg = [pet.dmg[0] + 1, pet.dmg[1] + 1];
  log(s, `${pet.name} steigt auf Stufe ${pet.level} auf!`, 'system');
  emit(s, { type: 'petLevel', level: pet.level });
}
