import {
  ANNOUNCE_EVERY, BACKGROUNDS, COLLAPSE_LOSS, DEATH_LINES, FIRST_NAMES, FLOOR_LOSS, LAST_NAMES, PARTY_BARKS, PARTY_MAX,
  PERSONALITIES, START_POPULATION, TIP_LINES,
} from '../data/crawlers';
import { FLOORS } from '../data/world';
import { offerQuest, questOf } from './quests';
import { monsterDefById, spawnMonster } from './monsters';
import { isInSafeRoom, killMonster } from './combat';
import { emit } from './events';
import { chebyshev } from './fov';
import { itemName, NameOf, nameOf } from './identify';
import { log, toast } from './log';
import { idx, isWalkable, tileAt } from './mapgen';
import { canStep, findPath } from './path';
import { effectiveStats } from './player';
import { playerSees } from './sight';
import * as R from './rng';
import { track } from './stats';
import type { GameState, Item, Monster, NpcCrawler, Personality, Pos } from './types';

/**
 * Andere Crawler: Menschen, die wie du in den Dungeon gestürzt sind. Manche
 * schließen sich dir an (Party bis zu vier Personen), manche wollen allein
 * bleiben, einige wollen dein Zeug. Die Systemstimme zählt regelmäßig durch,
 * wie viele noch leben.
 */

const DIRS: Pos[] = [
  { x: 1, y: 0 }, { x: -1, y: 0 }, { x: 0, y: 1 }, { x: 0, y: -1 },
  { x: 1, y: 1 }, { x: 1, y: -1 }, { x: -1, y: 1 }, { x: -1, y: -1 },
];

export function crawlers(s: GameState): NpcCrawler[] {
  s.crawlers ??= [];
  return s.crawlers;
}

export function party(s: GameState): NpcCrawler[] {
  return crawlers(s).filter((c) => c.alive && c.party);
}

export function crawlerAt(s: GameState, p: Pos): NpcCrawler | undefined {
  return crawlers(s).find((c) => c.alive && c.pos.x === p.x && c.pos.y === p.y);
}

function blocked(s: GameState, p: Pos, self?: NpcCrawler): boolean {
  if (!isWalkable(s.map, p.x, p.y)) return true;
  if (s.player.pos.x === p.x && s.player.pos.y === p.y) return true;
  const pet = s.player.pet;
  if (pet?.alive && pet.pos.x === p.x && pet.pos.y === p.y) return true;
  if (s.monsters.some((m) => m.pos.x === p.x && m.pos.y === p.y)) return true;
  return crawlers(s).some((c) => c !== self && c.alive && c.pos.x === p.x && c.pos.y === p.y);
}

// ================================================================ Bevölkerung

export function population(s: GameState) {
  s.population ??= { alive: START_POPULATION, floorStart: START_POPULATION, lastAnnounce: 0 };
  return s.population;
}

/** Aktuelle Zahl lebender Crawler: sinkt im Lauf der Etage. */
function updatePopulation(s: GameState) {
  const pop = population(s);
  const def = FLOORS.find((f) => f.floor === s.floor) ?? FLOORS[0];
  const loss = FLOOR_LOSS[Math.min(s.floor, FLOOR_LOSS.length - 1)];
  const progress = Math.min(1, (s.turn - s.floorStartTurn) / def.duration);
  // Am Anfang sterben die meisten (Unvorbereitete), später flacht es ab.
  const target = Math.round(pop.floorStart * (1 - loss * Math.sqrt(progress)));
  if (target < pop.alive) pop.alive = target;
}

const fmt = (n: number) => n.toLocaleString('de-DE');

export function announcePopulation(s: GameState, force = false) {
  const pop = population(s);
  if (!force && s.turn - pop.lastAnnounce < ANNOUNCE_EVERY) return;
  pop.lastAnnounce = s.turn;
  const lost = START_POPULATION - pop.alive;
  const pct = Math.round((lost / START_POPULATION) * 100);
  log(s, `SYSTEMMELDUNG: Es verbleiben ${fmt(pop.alive)} Crawler. ${pct > 0 ? `${pct} % haben es nicht geschafft. ` : ''}Weitermachen!`, 'system');
}

/** Beim Hinabsteigen: wer nicht rechtzeitig die Treppe erreicht hat, stirbt mit der Etage. */
export function populationOnDescend(s: GameState) {
  const pop = population(s);
  // Die Etage stürzt für alle anderen trotzdem ein – den Rest des Rückgangs abrechnen
  const loss = FLOOR_LOSS[Math.min(s.floor, FLOOR_LOSS.length - 1)];
  pop.alive = Math.min(pop.alive, Math.round(pop.floorStart * (1 - loss) * (1 - COLLAPSE_LOSS)));
  pop.floorStart = pop.alive;
}

// ================================================================ Erzeugen

export function makeCrawler(s: GameState, pos: Pos, personality?: Personality): NpcCrawler {
  const def = FLOORS.find((f) => f.floor === s.floor) ?? FLOORS[0];
  const pers = personality ?? R.weighted(s, (Object.entries(PERSONALITIES) as [Personality, { weight: number }][]).map(([k, d]) => [k, d.weight]));
  const level = Math.max(1, R.int(s, def.mobLevel[0], def.mobLevel[1] + 1) - 1);
  const maxHp = 18 + level * 6;
  s.uidCounter += 1;
  return {
    uid: `c${s.uidCounter}`,
    name: `${R.pick(s, FIRST_NAMES)} ${R.pick(s, LAST_NAMES)}`,
    background: R.pick(s, BACKGROUNDS),
    personality: pers,
    level,
    xp: 0,
    hp: pers === 'verzweifelt' ? Math.max(3, Math.round(maxHp * 0.2)) : maxHp,
    maxHp,
    dmg: [2 + level, 4 + Math.round(level * 1.5)],
    pos: { ...pos },
    alive: true,
    met: false,
    party: false,
    trust: pers === 'freundlich' ? 40 : 10,
    kills: 0,
  };
}

/** Beim Betreten einer Etage: Party kommt mit, neue Crawler tauchen auf. */
export function populateCrawlers(s: GameState, start: Pos) {
  const keep = party(s);
  for (const c of keep) {
    const spot = DIRS.map((d) => ({ x: start.x + d.x, y: start.y + d.y })).find((q) => !blocked(s, q, c));
    c.pos = spot ?? { ...start };
  }
  s.crawlers = [...keep];
  const want = 3 + s.floor;
  const rooms = s.map.rooms.filter((r) => r.kind === 'normal');
  for (let tries = 0; tries < 200 && s.crawlers.length - keep.length < want && rooms.length; tries++) {
    const r = R.pick(s, rooms);
    const p = { x: R.int(s, r.x, r.x + r.w - 1), y: R.int(s, r.y, r.y + r.h - 1) };
    if (chebyshev(p, start) < 8 || tileAt(s.map, p.x, p.y) !== 'floor' || blocked(s, p)) continue;
    s.crawlers.push(makeCrawler(s, p));
  }
  // Auf Etage 1 wartet einer ganz in der Nähe – damit man das System kennenlernt
  if (s.floor === 1) {
    const near = s.map.rooms.filter((r) => r.kind === 'normal').sort((a, b) => chebyshev({ x: a.x, y: a.y }, start) - chebyshev({ x: b.x, y: b.y }, start))[1];
    if (near) {
      const p = { x: near.x + Math.floor(near.w / 2), y: near.y + Math.floor(near.h / 2) };
      if (!blocked(s, p)) s.crawlers.push(makeCrawler(s, p, 'freundlich'));
    }
  }
}

// ================================================================ Gespräche

export function describeCrawler(c: NpcCrawler): string {
  const pers = c.met ? `, ${PERSONALITIES[c.personality].name}` : '';
  return `${c.name} (Level ${c.level}, früher ${c.background}${pers})`;
}

function adjacent(s: GameState, c: NpcCrawler) {
  return c.alive && chebyshev(c.pos, s.player.pos) <= 1;
}

export function talkableCrawlers(s: GameState): NpcCrawler[] {
  return crawlers(s).filter((c) => adjacent(s, c));
}

type Res = { ok: boolean; message?: string };

export function talkTo(s: GameState, uid: string): Res {
  const c = crawlers(s).find((x) => x.uid === uid);
  if (!c || !adjacent(s, c)) return { ok: false, message: 'Da ist niemand zum Reden.' };
  const pd = PERSONALITIES[c.personality];
  const first = !c.met;
  c.met = true;
  log(s, `${c.name}: „${R.pick(s, pd.greetings)}“`, 'dialog');
  if (first) emit(s, { type: 'crawlerMet', name: c.name, personality: c.personality });
  if (c.personality === 'feindselig' && !isInSafeRoom(s, s.player.pos)) {
    turnHostile(s, c);
    return { ok: true };
  }
  // Manche haben ein Anliegen
  if (first && !c.party && c.personality !== 'feindselig' && s.unlocks.includes('inventar') && !questOf(s, c.uid) && R.chance(s, 0.6)) {
    const q = offerQuest(s, { kind: 'crawler', ref: c.uid, name: c.name });
    if (q) log(s, `${c.name} hat ein Anliegen: ${q.text}`, 'dialog');
  }
  return { ok: true };
}

export function joinChance(s: GameState, c: NpcCrawler): number {
  const pd = PERSONALITIES[c.personality];
  if (pd.join <= 0) return 0;
  const cha = effectiveStats(s).cha;
  const lvl = (s.player.level - c.level) * 5;
  const followers = s.unlocks.includes('zuschauer') ? Math.min(15, Math.floor(Math.log10(Math.max(1, s.viewers.follower)) * 4)) : 0;
  const hurt = c.personality === 'verzweifelt' && c.hp < c.maxHp * 0.5 ? -40 : 0;
  return Math.max(0, Math.min(95, pd.join + (cha - 5) * 4 + lvl + followers + (c.trust - 20) / 2 + hurt)) / 100;
}

export function invite(s: GameState, uid: string): Res {
  const c = crawlers(s).find((x) => x.uid === uid);
  if (!c || !adjacent(s, c)) return { ok: false, message: 'Da ist niemand.' };
  if (c.party) return { ok: false, message: `${c.name} ist schon in deiner Party.` };
  if (party(s).length >= PARTY_MAX) return { ok: false, message: 'Deine Party ist voll (vier Crawler inklusive dir).' };
  if (c.refusedUntil && s.turn < c.refusedUntil) return { ok: false, message: `${c.name} hat gerade erst abgelehnt. Gib ihr oder ihm etwas Zeit.` };
  c.met = true;
  const pd = PERSONALITIES[c.personality];
  if (c.personality === 'feindselig') {
    turnHostile(s, c);
    return { ok: true };
  }
  if (R.chance(s, joinChance(s, c))) {
    c.party = true;
    c.trust = Math.max(c.trust, 50);
    log(s, `${c.name}: „${R.pick(s, pd.joinYes)}“`, 'dialog');
    log(s, `${c.name} ist jetzt in deiner Party.`, 'system');
    if (c.healed) track(s, 'party.gerettet');
    emit(s, { type: 'partyJoined', name: c.name, size: party(s).length + 1 });
  } else {
    c.refusedUntil = s.turn + 40;
    log(s, `${c.name}: „${R.pick(s, pd.joinNo.length ? pd.joinNo : ['Nein.'])}“`, 'dialog');
  }
  return { ok: true };
}

export function dismiss(s: GameState, uid: string): Res {
  const c = party(s).find((x) => x.uid === uid);
  if (!c) return { ok: false, message: 'Nicht in deiner Party.' };
  c.party = false;
  c.refusedUntil = s.turn + 200;
  log(s, `${c.name} nickt stumm und geht eigene Wege.`, 'dialog');
  emit(s, { type: 'partyLeft', name: c.name });
  return { ok: true };
}

/** Ein Tipp pro Crawler: Treppe, Safe Room oder Fallen in der Nähe. */
export function askTip(s: GameState, uid: string): Res {
  const c = crawlers(s).find((x) => x.uid === uid);
  if (!c || !adjacent(s, c)) return { ok: false, message: 'Da ist niemand.' };
  if (c.personality === 'feindselig') return talkTo(s, uid);
  if (c.tipGiven) return { ok: false, message: `${c.name} hat dir schon alles erzählt, was sie oder er weiß.` };
  c.tipGiven = true;
  c.met = true;
  const m = s.map;
  const reveal = (p: Pos, r: number) => {
    for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
      const x = p.x + dx;
      const y = p.y + dy;
      if (x >= 0 && y >= 0 && x < m.width && y < m.height) m.explored[idx(m, x, y)] = true;
    }
  };
  const kind = R.int(s, 0, 2);
  if (kind === 0) {
    const i = m.tiles.findIndex((t) => t === 'stairs');
    if (i >= 0) reveal({ x: i % m.width, y: Math.floor(i / m.width) }, 2);
  } else if (kind === 1) {
    const safe = m.rooms.filter((r) => r.kind === 'safe').sort((a, b) => chebyshev({ x: a.x, y: a.y }, s.player.pos) - chebyshev({ x: b.x, y: b.y }, s.player.pos))[0];
    if (safe) reveal({ x: safe.x + Math.floor(safe.w / 2), y: safe.y + Math.floor(safe.h / 2) }, Math.max(safe.w, safe.h));
  } else {
    for (const t of s.traps ?? []) if (t.owner === 'dungeon' && chebyshev(t.pos, s.player.pos) <= 15) t.hidden = false;
  }
  log(s, `${c.name}: „${TIP_LINES[kind]}“`, 'dialog');
  c.trust = Math.min(100, c.trust + 5);
  track(s, 'tipps');
  return { ok: true };
}

/** Heilung verschenken: wer verzweifelt ist, vergisst das nie. */
export function giveHealing(s: GameState, uid: string, item: Item): Res {
  const c = crawlers(s).find((x) => x.uid === uid);
  if (!c || !adjacent(s, c)) return { ok: false, message: 'Da ist niemand.' };
  const e = item.effekt;
  if (!e?.heal && !e?.healPct) return { ok: false, message: 'Das heilt nicht.' };
  const amount = Math.round((e.heal ?? 0) + ((e.healPct ?? 0) / 100) * c.maxHp);
  c.hp = Math.min(c.maxHp, c.hp + Math.max(8, amount));
  c.trust = Math.min(100, c.trust + (c.personality === 'verzweifelt' ? 60 : 25));
  c.refusedUntil = undefined;
  c.met = true;
  if (c.personality === 'verzweifelt') c.personality = 'freundlich';
  c.healed = true;
  track(s, 'crawler.geheilt');
  log(s, `Du gibst ${c.name} ${itemName(s, item)}. „Danke. Wirklich. Das vergesse ich dir nicht.“`, 'dialog');
  return { ok: true };
}

// ================================================================ Feindselige Crawler

function turnHostile(s: GameState, c: NpcCrawler) {
  const def = monsterDefById('abtruenniger_crawler');
  if (!def) return;
  c.alive = false;
  const m = spawnMonster(s, def, Math.max(def.levels[0], c.level + 1), c.pos, -1);
  m.name = c.name;
  m.aware = true;
  m.provoked = true;
  m.hp = m.maxHp = Math.max(m.maxHp, c.maxHp);
  s.monsters.push(m);
  s.crawlers = crawlers(s).filter((x) => x !== c);
  log(s, `${c.name} zieht eine Klinge. „Nichts Persönliches. Ich will nur dein Zeug.“`, 'gefahr');
  emit(s, { type: 'crawlerTurned', name: c.name });
}

// ================================================================ Züge

function hitMonster(s: GameState, c: NpcCrawler, m: Monster) {
  if (R.chance(s, 0.3)) {
    if (seen(s, c)) log(s, `${c.name} schlägt nach ${nameOf(s, m)} und verfehlt.`, 'kampf');
    return;
  }
  const dmg = Math.max(1, R.int(s, c.dmg[0], c.dmg[1]) - m.ruestung);
  m.hp -= dmg;
  m.aware = true;
  if (seen(s, c)) log(s, `${c.name} trifft ${nameOf(s, m)} für ${dmg} Schaden.`, 'kampf');
  if (m.hp <= 0) {
    c.kills += 1;
    c.xp += m.xp;
    c.trust = Math.min(100, c.trust + 2);
    while (c.xp >= c.level * 50) {
      c.xp -= c.level * 50;
      c.level += 1;
      c.maxHp += 6;
      c.hp = c.maxHp;
      c.dmg = [c.dmg[0] + 1, c.dmg[1] + 2];
      if (seen(s, c)) log(s, `${c.name} steigt auf Level ${c.level} auf.`, 'system');
    }
    killMonster(s, m, null, c.name);
  }
}

/** Nur was der Crawler selbst sieht, landet im Log – auch bei der eigenen Party. */
function seen(s: GameState, c: NpcCrawler) {
  return playerSees(s, c.pos);
}

export function hurtCrawler(s: GameState, c: NpcCrawler, dmg: number, by: string) {
  c.hp -= dmg;
  if (seen(s, c)) log(s, `${by} trifft ${c.name} für ${dmg} Schaden.`, c.party ? 'gefahr' : 'kampf');
  if (c.hp <= 0) crawlerDies(s, c);
}

function crawlerDies(s: GameState, c: NpcCrawler) {
  c.alive = false;
  c.hp = 0;
  const wasParty = c.party;
  c.party = false;
  population(s).alive -= 1;
  s.crawlers = crawlers(s).filter((x) => x !== c);
  if (seen(s, c)) log(s, R.pick(s, DEATH_LINES).replace('{name}', c.name), 'gefahr');
  if (wasParty) {
    s.fallen ??= [];
    s.fallen.push(c.name);
    if (seen(s, c)) toast(s, 'Party-Mitglied gefallen', c.name, 'warnung');
  }
  emit(s, { type: 'crawlerDied', name: c.name, party: wasParty });
}

function stepToward(s: GameState, c: NpcCrawler, goal: Pos, maxLen = 200) {
  const path = findPath(s.map, c.pos, goal, (x, y) => !blocked(s, { x, y }, c) || (x === goal.x && y === goal.y), maxLen);
  const next = path?.[0];
  if (next && !blocked(s, next, c)) c.pos = next;
}

/** Alle NPC-Crawler handeln einmal. */
export function crawlersTurn(s: GameState) {
  if (s.status !== 'playing') return;
  updatePopulation(s);
  announcePopulation(s);
  for (const c of [...crawlers(s)]) {
    if (!c.alive || s.status !== 'playing') continue;
    if (s.turn % 10 === 0) c.hp = Math.min(c.maxHp, c.hp + 1);
    const foes = s.monsters
      .filter((m) => chebyshev(m.pos, c.pos) <= 1 && !isInSafeRoom(s, m.pos) && (m.homeRoom === undefined || (m.aware && c.party)))
      .sort((a, b) => a.hp - b.hp);
    const foe = foes[0];
    if (foe) {
      hitMonster(s, c, foe);
      // Der Gegner schlägt zurück, wenn er noch steht und nicht mit dir beschäftigt ist
      if (s.monsters.includes(foe) && foe.downed <= 0 && (chebyshev(foe.pos, s.player.pos) > 1 || R.chance(s, 0.3)) && R.chance(s, 0.55)) {
        hurtCrawler(s, c, Math.max(1, R.int(s, foe.dmg[0], foe.dmg[1]) - Math.floor(c.level / 3)), NameOf(s, foe));
      }
      continue;
    }
    const d = chebyshev(c.pos, s.player.pos);
    if (c.party) {
      // Zu Gegnern laufen, die dich bedrohen; sonst folgen
      const threat = s.monsters.find((m) => m.aware && chebyshev(m.pos, s.player.pos) <= 3 && chebyshev(m.pos, c.pos) <= 6);
      if (threat) stepToward(s, c, threat.pos, 120);
      else if (d > 2) stepToward(s, c, s.player.pos, 400);
      if (chebyshev(c.pos, s.player.pos) > 12) {
        const spot = DIRS.map((q) => ({ x: s.player.pos.x + q.x, y: s.player.pos.y + q.y })).find((q) => canStep(s.map, s.player.pos, q) && !blocked(s, q, c));
        if (spot) c.pos = spot;
      }
      if (seen(s, c) && R.chance(s, 0.004)) log(s, R.pick(s, PARTY_BARKS).replace('{name}', c.name), 'dialog');
      continue;
    }
    // Fremde Crawler: umherstreifen; weit weg lebt es sich gefährlich
    if (d > 20 && R.chance(s, 0.0006 * s.floor)) {
      crawlerDies(s, c);
      continue;
    }
    if (R.chance(s, 0.25)) {
      const q = R.pick(s, DIRS);
      const p = { x: c.pos.x + q.x, y: c.pos.y + q.y };
      if (canStep(s.map, c.pos, p) && !blocked(s, p, c) && !isInSafeRoom(s, p)) c.pos = p;
    }
  }
}

/** Monster greifen gelegentlich Crawler an, die neben ihnen stehen (statt dich). */
export function monsterHitsCrawler(s: GameState, m: Monster): boolean {
  if (chebyshev(m.pos, s.player.pos) <= 1 && R.chance(s, 0.75)) return false;
  const c = crawlers(s).find((x) => x.alive && chebyshev(x.pos, m.pos) <= 1);
  if (!c || isInSafeRoom(s, c.pos)) return false;
  if (!R.chance(s, c.party ? 0.5 : 0.35)) return false;
  hurtCrawler(s, c, Math.max(1, R.int(s, m.dmg[0], m.dmg[1]) - Math.floor(c.level / 3)), NameOf(s, m));
  return true;
}
