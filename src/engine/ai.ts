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
import { checkEvolve, petAbilityTurn, petBiteBonus } from './petevo';
import { mountAbsorbs } from './mounts';
import { playerSees } from './sight';
import { levelGapHit } from './progression';
import { dynDefenseBonus, targetFacets, trainDefense } from './observer';
import { ausweichen, totalBonuses } from './player';
import * as R from './rng';
import type { Fx, GameState, Monster, Pos } from './types';
import { FX_COLORS, floatText, shot } from './fx';

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

/** Wie das Geschoss eines Fernkämpfers aussieht. */
function shotStyle(s: GameState, m: Monster): Extract<Fx, { kind: 'shot' }>['style'] {
  const f = targetFacets(s, m);
  if (f.includes('z:schleim')) return 'schleim';
  if (m.defId.includes('schleuder') || f.includes('z:kobold')) return 'stein';
  if (f.includes('z:elementar') || f.includes('z:hexe') || f.includes('z:alien') || f.includes('z:geist')) return 'magie';
  if (f.includes('z:konstrukt')) return 'blitz';
  return 'pfeil';
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
  const hit = Math.max(5, Math.min(95, m.treffer - ausweichen(s, b) - defense.ausweichen - (ranged ? 5 : 0) + levelGapHit(m.level, p.level)));
  const verb = ranged ? 'schießt auf dich' : 'greift an';
  if (ranged) shot(s, m.pos, p.pos, shotStyle(s, m));
  if (R.next(s) * 100 >= hit) {
    floatText(s, p.pos, 'ausgewichen', FX_COLORS.info);
    s.counters.hitTakenStreak = 0;
    log(s, `${NameOf(s, m)} ${verb} – du weichst aus.`, 'kampf');
    trainDefense(s, source, 'ausweichen');
    emit(s, { type: 'dodged', source: m.name, facets: source });
    return;
  }
  let raw = R.int(s, m.dmg[0], m.dmg[1]);
  if (m.weakened && m.weakened > 0) raw = Math.max(1, Math.round(raw * 0.7));
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
  if (mountAbsorbs(s, dmg, NameOf(s, m))) return;
  if (defense.reduktion) trainDefense(s, source, 'abhaertung');
  p.hp -= dmg;
  floatText(s, p.pos, `-${dmg}`, FX_COLORS.gegenSpieler);
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

/** Sichtweite eines Monsters: Fernkämpfer sehen weiter, Schattenmantel halbiert sie. */
function perceptionRange(s: GameState, m: Monster): number {
  let r = m.behavior === 'ranged' || m.range ? 9 : 8;
  if (m.size === 'winzig') r -= 1;
  if (s.player.buffs.some((b) => b.name === 'Schattenmantel')) r = Math.floor(r / 2);
  return r;
}

/** Wann ein Monster flieht – nur wenn es zu seiner Art passt. */
function wantsToFlee(s: GameState, m: Monster, d: number): boolean {
  if (m.rank !== 'normal') return false;
  // Feiglinge laut Beschreibung (Bürokraten, Heinzelmännchen …) halten Abstand
  if (m.behavior === 'coward') return d <= 4;
  // Diebe verschwinden mit der Beute
  if (m.stolenGold) return true;
  // Kleine Tiere hauen ab, wenn sie schwer verletzt sind
  const smallAnimal = (m.size === 'winzig' || m.size === 'klein') && targetFacets(s, m).includes('z:tier');
  return smallAnimal && m.hp < m.maxHp * 0.25;
}

/** Ein Monster hat den Crawler entdeckt: es warnt Artgenossen in der Nähe. */
function spotPlayer(s: GameState, m: Monster, text: string) {
  m.aware = true;
  m.asleep = false;
  m.lastSeen = { ...s.player.pos };
  m.searching = 0;
  if (playerSees(s, m.pos)) log(s, text, 'gefahr');
  let warned = 0;
  for (const o of s.monsters) {
    if (o === m || o.aware || o.asleep || o.homeRoom !== undefined || chebyshev(o.pos, m.pos) > 6) continue;
    if (o.defId !== m.defId && o.hood !== m.hood) continue;
    o.aware = true;
    o.lastSeen = { ...s.player.pos };
    warned++;
  }
  if (warned && playerSees(s, m.pos)) log(s, `${NameOf(s, m)} warnt ${warned === 1 ? 'einen Artgenossen' : `${warned} Artgenossen`}.`, 'gefahr');
}

/**
 * Lärm (Kampf, Explosionen, Stolperdrähte) weckt Schlafende und lockt
 * Wache an die Stelle, an der es laut war.
 */
export function makeNoise(s: GameState, at: Pos, radius: number) {
  for (const m of s.monsters) {
    if (m.homeRoom !== undefined || chebyshev(m.pos, at) > radius) continue;
    if (m.asleep) {
      m.asleep = false;
      if (playerSees(s, m.pos)) log(s, `${NameOf(s, m)} schreckt aus dem Schlaf hoch.`, 'gefahr');
      continue;
    }
    if (!m.aware) {
      m.lastSeen = { ...at };
      m.searching = 12;
    }
  }
}

export function monsterTurn(s: GameState, m: Monster) {
  if (s.status !== 'playing' || !s.monsters.includes(m)) return;
  if (m.downed > 0) {
    m.downed -= 1;
    if (m.downed === 0 && playerSees(s, m.pos)) log(s, `${NameOf(s, m)} rappelt sich wieder auf.`, 'kampf');
    return;
  }
  if (m.aware) m.asleep = false;
  // Benommen: Zug aussetzen
  if (m.stunned && m.stunned > 0) {
    m.stunned -= 1;
    if (playerSees(s, m.pos)) log(s, `${NameOf(s, m)} ist noch benommen.`, 'kampf');
    return;
  }
  if (m.weakened) m.weakened -= 1;
  // Schlafende bemerken nur, was direkt neben ihnen passiert
  if (m.asleep) {
    if (chebyshev(m.pos, s.player.pos) <= 1 && R.chance(s, 0.5)) spotPlayer(s, m, `${NameOf(s, m)} wacht auf und sieht dich!`);
    return;
  }
  startOfTurn(s, m);
  const p = s.player;
  const d = chebyshev(m.pos, p.pos);
  const sees = canSeePlayer(s, m, perceptionRange(s, m));

  // Wahrnehmung: wer dich sieht, greift an
  if (!m.aware) {
    if (m.homeRoom !== undefined) {
      if (roomOf(s.map, p.pos)?.id === m.homeRoom) spotPlayer(s, m, `${NameOf(s, m)} bemerkt dich!`);
    } else if (sees && (d <= 5 || R.chance(s, 0.6))) {
      spotPlayer(s, m, `${NameOf(s, m)} hat dich entdeckt!`);
    }
  }
  if (!m.aware) {
    // Einem Geräusch oder der letzten Spur nachgehen
    if (m.searching && m.lastSeen && m.behavior !== 'stationary' && m.homeRoom === undefined) {
      m.searching -= 1;
      stepToward(s, m, m.lastSeen);
      if (chebyshev(m.pos, m.lastSeen) <= 1) m.searching = 0;
      return;
    }
    if (m.behavior !== 'stationary' && m.homeRoom === undefined) wander(s, m);
    return;
  }
  // Pässe und Talismane: diese Gegnerart lässt dich in Ruhe, solange du sie nicht angreifst
  if (passProtects(s, m)) {
    m.aware = false;
    wander(s, m);
    return;
  }

  // Außer Sicht: zur letzten bekannten Position, dann eine Weile suchen, dann aufgeben
  if (sees) m.lastSeen = { ...p.pos };
  else if (m.homeRoom === undefined) {
    m.aware = false;
    m.searching = 15;
    if (m.lastSeen && m.behavior !== 'stationary') stepToward(s, m, m.lastSeen);
    return;
  }

  const pet = p.pet?.alive ? p.pet : null;
  const petAdj = pet && chebyshev(m.pos, pet.pos) <= 1;

  if (!m.fleeing && wantsToFlee(s, m, d)) {
    m.fleeing = true;
    if (playerSees(s, m.pos)) log(s, `${NameOf(s, m)} ergreift die Flucht!`, 'kampf');
  }
  if (m.fleeing) {
    if (!wantsToFlee(s, m, d) && m.behavior !== 'coward') m.fleeing = false;
    else {
      stepAway(s, m, p.pos);
      if (has(m, 'schnell')) stepAway(s, m, p.pos);
      return;
    }
  }

  // Elite und Bosse werden wütend, wenn es eng wird
  if ((m.rank === 'elite' || m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss') && !m.enraged && m.hp < m.maxHp * 0.3) {
    m.enraged = true;
    m.dmg = [Math.round(m.dmg[0] * 1.3), Math.round(m.dmg[1] * 1.3)];
    m.treffer += 5;
    if (playerSees(s, m.pos)) log(s, `${NameOf(s, m)} gerät in Raserei! Die Angriffe werden härter.`, 'gefahr');
  }

  if (monsterHitsCrawler(s, m)) return;
  const ranged = m.behavior === 'ranged' || !!m.range;
  // Fernkämpfer halten Abstand, statt sich verprügeln zu lassen
  if (ranged && d <= 1 && R.chance(s, 0.6)) {
    const before = m.pos;
    stepAway(s, m, p.pos);
    if (m.pos !== before) return;
  }
  if (d <= 1) {
    if (petAdj && R.chance(s, 0.25)) attackPet(s, m);
    else attackPlayer(s, m, false);
    return;
  }
  if (petAdj && !ranged) {
    attackPet(s, m);
    return;
  }
  if (ranged && d <= (m.range ?? 4) && hasLineOfSight(s.map, m.pos, p.pos)) {
    attackPlayer(s, m, true);
    return;
  }
  if (m.behavior === 'stationary') return;
  // Humpeln: nur jeden zweiten Zug ein Schritt, kein Sprinten
  if (m.slowed && m.slowed > 0) {
    m.slowed -= 1;
    if (m.slowed % 2 === 1) return;
    stepToward(s, m, p.pos);
    return;
  }
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
    shot(s, pet.pos, spellTarget.pos, 'magie');
    spellTarget.hp -= dmg;
    spellTarget.aware = true;
    log(s, `${pet.name} schießt Magische Geschosse aus den Augen: ${dmg} Schaden an ${nameOf(s, spellTarget)}.`, 'kampf');
    if (spellTarget.hp <= 0) killMonster(s, spellTarget, null, true);
    return;
  }
  const petKill = (m: Monster) => {
    pet.xp += m.xp;
    while (pet.xp >= pet.level * 60) {
      pet.xp -= pet.level * 60;
      petLevelUp(s);
    }
    killMonster(s, m, null, true);
  };
  if (petAbilityTurn(s, pet, petKill)) return;
  const t = targets[0];
  if (t) {
    const bites = pet.abilities?.includes('doppelbiss') ? 2 : 1;
    for (let i = 0; i < bites && s.monsters.includes(t); i++) {
      if (R.chance(s, 0.25)) {
        log(s, `${pet.name} schnappt nach ${nameOf(s, t)}, verfehlt aber.`, 'kampf');
        continue;
      }
      let dmg = R.int(s, pet.dmg[0], pet.dmg[1]) + petBiteBonus(s);
      if (Object.values(p.equipment).some((i) => i?.special === 'katzenfreund')) dmg = Math.round(dmg * 1.5);
      const dealt = Math.max(1, dmg - t.ruestung);
      t.hp -= dealt;
      t.aware = true;
      log(s, `${pet.name} beißt ${nameOf(s, t)} für ${dealt} Schaden.`, 'kampf');
      if (t.hp <= 0) petKill(t);
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
  checkEvolve(s);
}
