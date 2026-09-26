import { INTERVIEW, BASE_STATS } from '../data/interview';
import { FOOD_IDS } from '../data/items';
import { HOOD_BOSSES } from '../data/monsters';
import {
  COLLAPSE_WARNINGS, DEFAULT_GUIDE, FLOORS, LAST_PLAYABLE_FLOOR, RESTAURANT_HOSTS, RESTAURANT_MENU,
  SHOW_NAME, tutorialPages,
} from '../data/world';
import { monsterAt, monsterTurn, occupied, petLevelUp, petTurn } from './ai';
import { cure } from './abilities';
import { isInSafeRoom, playerAttack } from './combat';
import { handleLethal } from './death';
import { emit } from './events';
import { chebyshev, computeFov } from './fov';
import { createItem, generateEquipment, rollBoxContents } from './items';
import { log, toast } from './log';
import { MAP_H, MAP_W, generateFloor, hoodOf, idx, inBounds, isWalkable, roomOf, tileAt } from './mapgen';
import { spawnForFloor } from './monsters';
import { canStep, findPath } from './path';
import { clampVitals, lichtradius, maxAusdauer, maxHp, skillLevel, totalBonuses } from './player';
import * as R from './rng';
import { addToInventory, giveItem } from './inventory';
import { describeMonster, itemName } from './identify';
import { learnSkill } from './skills';
import { viewersTick } from './viewers';
import type {
  ConsumableEffect, EquipSlot, GameState, Item, MetaState, Pet, Pos, Rarity, StatKey, Technique,
} from './types';

export const SAVE_VERSION = 1;

export interface NewGameOptions {
  name: string;
  answers: number[];
  petName?: string;
  seed?: number;
  meta: MetaState;
}

export interface ActionResult {
  ok: boolean;
  message?: string;
}

const fail = (message: string): ActionResult => ({ ok: false, message });
const OK: ActionResult = { ok: true };

// ================================================================ Start

export function newGame(opts: NewGameOptions): GameState {
  const seed = opts.seed ?? Math.floor(Math.random() * 2 ** 31);
  const lastGuide = opts.meta.guides[opts.meta.guides.length - 1];
  const s: GameState = {
    version: SAVE_VERSION,
    seed,
    rng: seed,
    floor: 1,
    turn: 0,
    collapseAt: FLOORS[0].duration,
    floorStartTurn: 0,
    map: null as unknown as GameState['map'],
    player: {
      name: opts.name.trim() || 'Namenlos',
      background: 'Unbekannt',
      pos: { x: 0, y: 0 },
      level: 1,
      xp: 0,
      hp: 1,
      maxHpBase: 10,
      ausdauer: 1,
      maxAusdauerBase: 4,
      stats: { ...BASE_STATS },
      statPoints: 0,
      gold: 0,
      hand: null,
      inventory: [],
      boxes: [],
      equipment: {},
      skills: [],
      buffs: [],
      techniqueUses: {},
      techniqueKills: {},
      lastMoveDir: null,
      pet: null,
      flags: [],
      curses: [],
    },
    monsters: [],
    items: [],
    unlocks: [],
    achievements: [],
    counters: {
      kills: 0, killsByDef: {}, steps: 0, itemsPicked: 0, boxesOpened: 0, missStreak: 0,
      hitTakenStreak: 0, throws: 0, bossKills: 0, damageDealt: 0, damageTaken: 0,
      goldEarned: 0, goldStolen: 0, poisonDamage: 0, mealsEaten: 0, potionsDrunk: 0, sleeps: 0,
      crits: 0, knockdowns: 0, eliteKills: 0,
    },
    log: [],
    status: 'playing',
    lastSpawnTurn: 0,
    uidCounter: 0,
    currentRoom: -1,
    pendingDialogs: [],
    guideName: lastGuide?.name ?? DEFAULT_GUIDE.name,
    season: opts.meta.season + 1,
    contractSigned: false,
    firstEver: [...opts.meta.achievementsEver],
    ghostsDefeated: [],
    viewers: { follower: 0, hype: 0, nextFanBox: 0, lastSpectacle: 0 },
    pendingSelection: false,
    toasts: [],
  };

  // --- Interview auswerten
  const p = s.player;
  INTERVIEW.forEach((q, qi) => {
    const a = q.answers[opts.answers[qi] ?? 0];
    if (!a) return;
    if (a.background) p.background = a.background;
    if (a.stats) for (const [k, v] of Object.entries(a.stats) as [StatKey, number][]) p.stats[k] = Math.max(1, p.stats[k] + v);
    for (const sk of a.skills ?? []) learnSkill(s, sk, 1, true);
    for (const f of a.flags ?? []) p.flags.push(f);
    for (const id of a.items ?? []) {
      const it = createItem(s, id);
      if (it.slot) p.equipment[it.slot as EquipSlot] = it;
    }
    if (a.pet) {
      const petName = opts.petName?.trim() || a.pet.defaultName;
      p.pet = makePet(a.pet.species, petName);
    }
  });

  enterFloor(s, 1, opts.meta);
  p.hp = maxHp(s);
  p.ausdauer = maxAusdauer(s);

  log(s, `Willkommen bei ${SHOW_NAME}, Staffel ${s.season}!`, 'system');
  s.pendingDialogs.push({
    title: `${SHOW_NAME} – Staffel ${s.season}`,
    speaker: 'Die Systemstimme',
    pages: [
      `Crawler ${p.name}! Deine Welt wurde soeben… sagen wir: „umgenutzt“. Die gute Nachricht: Du darfst an der beliebtesten Show der Galaxis teilnehmen. Die schlechte: Du hast keine Wahl.`,
      `${FLOORS[0].intro}`,
      'Du hast nichts. Kein Inventar, keine Karte, keine Ahnung. Irgendwo auf dieser Etage gibt es eine Gilde der Einweisung – such sie. Bis dahin kannst du genau einen Gegenstand in der Hand halten. Und deine Fäuste. Und Füße. Viel Spaß!',
    ],
  });
  emit(s, { type: 'start' });
  return s;
}

function makePet(species: string, name: string): Pet {
  const cat = species === 'Katze';
  return {
    name, species, level: 1, xp: 0,
    hp: cat ? 12 : 16, maxHp: cat ? 12 : 16,
    dmg: cat ? [1, 3] : [2, 3],
    pos: { x: 0, y: 0 }, alive: true,
  };
}

function enterFloor(s: GameState, floor: number, meta: Pick<MetaState, 'ghosts'>) {
  const gen = generateFloor(s, floor, meta.ghosts);
  s.floor = floor;
  s.map = gen.map;
  s.monsters = gen.monsters;
  s.items = gen.items;
  s.player.pos = { ...gen.start };
  s.currentRoom = -1;
  const def = FLOORS.find((f) => f.floor === floor) ?? FLOORS[0];
  s.floorStartTurn = s.turn;
  s.collapseAt = s.turn + def.duration;
  s.lastSpawnTurn = s.turn;
  const pet = s.player.pet;
  if (pet) {
    const spot = neighbors(gen.start).find((q) => isWalkable(s.map, q.x, q.y) && !occupied(s, q));
    pet.pos = spot ?? { ...gen.start };
  }
  afterMove(s);
}

function neighbors(p: Pos): Pos[] {
  const out: Pos[] = [];
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (dx || dy) out.push({ x: p.x + dx, y: p.y + dy });
  return out;
}

// ================================================================ Abfragen

export const hasUnlock = (s: GameState, u: GameState['unlocks'][number]) => s.unlocks.includes(u);

export function visibleTiles(s: GameState): Set<number> {
  return computeFov(s.map, s.player.pos, lichtradius(s));
}

export function itemsAt(s: GameState, p: Pos) {
  return s.items.filter((e) => e.pos.x === p.x && e.pos.y === p.y);
}

export function currentRoom(s: GameState) {
  return roomOf(s.map, s.player.pos);
}

export function timeLeft(s: GameState): number {
  return Math.max(0, s.collapseAt - s.turn);
}

/** Weg über bekannte Kacheln zu einem Ziel (für Klick-Bewegung). */
export function planPath(s: GameState, target: Pos): Pos[] | null {
  if (!inBounds(s.map, target.x, target.y)) return null;
  const known = (x: number, y: number) => s.map.explored[idx(s.map, x, y)];
  if (!known(target.x, target.y)) return null;
  return findPath(s.map, s.player.pos, target, (x, y) => known(x, y) && !monsterAt(s, { x, y }), 6000);
}

// ================================================================ Züge

const SELECT_FIRST = 'Wähle zuerst deine Rasse und Klasse.';

export function moveStep(s: GameState, to: Pos): ActionResult {
  if (s.status !== 'playing') return fail('Das Spiel ist vorbei.');
  if (s.pendingSelection) return fail(SELECT_FIRST);
  const p = s.player;
  if (chebyshev(p.pos, to) !== 1) return fail('Nur ein Feld pro Zug.');
  if (!canStep(s.map, p.pos, to)) return fail('Da ist eine Wand.');
  if (monsterAt(s, to)) return fail('Da steht ein Gegner.');
  const pet = p.pet;
  if (pet?.alive && pet.pos.x === to.x && pet.pos.y === to.y) {
    pet.pos = { ...p.pos }; // Platz tauschen
  }
  p.lastMoveDir = { x: to.x - p.pos.x, y: to.y - p.pos.y };
  p.pos = { ...to };
  s.counters.steps += 1;
  emit(s, { type: 'moved' });
  afterMove(s);
  endTurn(s, { keepMoveDir: true });
  return OK;
}

export function attack(s: GameState, targetUid: string, t: Technique): ActionResult {
  if (s.status !== 'playing') return fail('Das Spiel ist vorbei.');
  if (s.pendingSelection) return fail(SELECT_FIRST);
  const m = s.monsters.find((x) => x.uid === targetUid);
  if (!m) return fail('Kein Ziel.');
  const res = playerAttack(s, m, t);
  if (!res.ok) return fail(res.reason ?? 'Geht nicht.');
  endTurn(s);
  return OK;
}

export function wait(s: GameState): ActionResult {
  if (s.status !== 'playing') return fail('Das Spiel ist vorbei.');
  if (s.pendingSelection) return fail(SELECT_FIRST);
  s.player.ausdauer = Math.min(maxAusdauer(s), s.player.ausdauer + 1);
  endTurn(s);
  return OK;
}

interface EndTurnOpts {
  keepMoveDir?: boolean;
}

export function endTurn(s: GameState, opts: EndTurnOpts = {}) {
  if (!opts.keepMoveDir) s.player.lastMoveDir = null;
  if (s.status !== 'playing') return;
  const before = timeLeft(s);
  s.turn += 1;

  // Monster in der Nähe handeln; weit entfernte schlafen (Performance)
  for (const m of [...s.monsters]) {
    if (s.status !== 'playing') break;
    if (chebyshev(m.pos, s.player.pos) > 24 && !m.aware) continue;
    monsterTurn(s, m);
  }
  petTurn(s);
  if (s.status !== 'playing') return;
  tickTime(s, 1, before);
}

/** Zeit vergeht: Buffs, Regeneration, Nachspawns, Einsturz. */
function tickTime(s: GameState, turns: number, before: number) {
  const p = s.player;
  // Gift und andere Schadenseffekte
  for (const b of p.buffs) {
    if (!b.dot) continue;
    const ticks = Math.min(turns, b.turns);
    const dmg = b.dot * ticks;
    p.hp -= dmg;
    s.counters.poisonDamage += dmg;
    if (turns === 1) log(s, `${b.name}: −${dmg} HP.`, 'gefahr');
    if (p.hp <= 0) {
      handleLethal(s, 'an einer Vergiftung gestorben');
      if (s.status !== 'playing') return;
    }
  }
  for (const b of p.buffs) b.turns -= turns;
  const expired = p.buffs.filter((b) => b.turns <= 0);
  if (expired.length) {
    p.buffs = p.buffs.filter((b) => b.turns > 0);
    for (const b of expired) log(s, `Der Effekt „${b.name}“ lässt nach.`, 'info');
  }
  const bon = totalBonuses(s);
  const regenTicks = Math.floor(s.turn / 8) - Math.floor((s.turn - turns) / 8);
  if (regenTicks > 0) p.hp = Math.min(maxHp(s, bon), p.hp + regenTicks * (1 + (bon.hpRegen ?? 0)));
  // Außerhalb von Kämpfen erholt man sich schneller
  const calm = !s.monsters.some((m) => m.aware && chebyshev(m.pos, p.pos) <= 10);
  if (turns === 1 && calm && s.turn % 3 === 0) p.hp = Math.min(maxHp(s, bon), p.hp + 1);
  p.ausdauer = Math.min(maxAusdauer(s, bon), p.ausdauer + turns);
  clampVitals(s);

  viewersTick(s, turns);
  if (p.abilityCooldown) p.abilityCooldown = Math.max(0, p.abilityCooldown - turns);

  while (s.turn - s.lastSpawnTurn >= 30) {
    s.lastSpawnTurn += 30;
    respawn(s);
  }

  const left = timeLeft(s);
  for (const [threshold, text] of COLLAPSE_WARNINGS) {
    if (before > threshold && left <= threshold) {
      log(s, `SYSTEMMELDUNG: ${text}`, 'gefahr');
      toast(s, 'Einsturz-Warnung', text, 'warnung');
    }
  }
  if (left <= 20 && isInSafeRoom(s, p.pos)) kickFromSafeRoom(s);
  if (left <= 0) {
    p.hp = 0;
    s.status = 'dead';
    s.deathCause = 'unter der einstürzenden Etage begraben';
    log(s, 'Die Decke kommt herunter. Die ganze Etage stürzt ein – und du mit ihr.', 'gefahr');
  }
}

function respawn(s: GameState) {
  const def = FLOORS.find((f) => f.floor === s.floor) ?? FLOORS[0];
  const vis = visibleTiles(s);
  for (const hood of s.map.hoods) {
    if (!hood.bossAlive) continue;
    const count = s.monsters.filter((m) => m.hood === hood.id && m.rank === 'normal').length;
    if (count >= 14) continue;
    const rooms = s.map.rooms.filter((r) => r.hood === hood.id && r.kind === 'normal');
    if (!rooms.length) continue;
    const room = R.pick(s, rooms);
    const p = { x: R.int(s, room.x, room.x + room.w - 1), y: R.int(s, room.y, room.y + room.h - 1) };
    if (vis.has(idx(s.map, p.x, p.y)) || occupied(s, p) || tileAt(s.map, p.x, p.y) !== 'floor') continue;
    const level = R.int(s, def.mobLevel[0], def.mobLevel[1]);
    s.monsters.push(spawnForFloor(s, s.floor, level, p, hood.id, R.chance(s, 0.05)));
  }
}

function kickFromSafeRoom(s: GameState) {
  const start = s.player.pos;
  const seen = new Set<number>([idx(s.map, start.x, start.y)]);
  const queue: Pos[] = [start];
  while (queue.length) {
    const cur = queue.shift()!;
    if (!isInSafeRoom(s, cur) && !occupied(s, cur)) {
      s.player.pos = cur;
      log(s, 'Der Safe Room schließt! Ein unsichtbarer Türsteher wirft dich hinaus. „Letzte Runde war vor einer Stunde.“', 'gefahr');
      afterMove(s);
      return;
    }
    for (const n of neighbors(cur)) {
      const i = idx(s.map, n.x, n.y);
      if (!inBounds(s.map, n.x, n.y) || seen.has(i) || !isWalkable(s.map, n.x, n.y)) continue;
      seen.add(i);
      queue.push(n);
    }
  }
}

/** Sichtfeld, Karte, Räume und Hinweise nach jeder Bewegung aktualisieren. */
function afterMove(s: GameState) {
  const vis = visibleTiles(s);
  let stairsNew = false;
  for (const i of vis) {
    if (!s.map.explored[i]) {
      s.map.explored[i] = true;
      if (s.map.tiles[i] === 'stairs') stairsNew = true;
    }
  }
  if (stairsNew) {
    log(s, 'Du entdeckst ein Treppenhaus nach unten!', 'system');
    emit(s, { type: 'stairsFound' });
  }

  const room = currentRoom(s);
  const roomId = room?.id ?? -1;
  if (roomId !== s.currentRoom) {
    s.currentRoom = roomId;
    if (room) onEnterRoom(s, room);
  }

  const here = itemsAt(s, s.player.pos);
  if (here.length) log(s, `Hier liegt: ${here.map((e) => itemName(s, e.item)).join(', ')}.`, 'loot');
  if (tileAt(s.map, s.player.pos.x, s.player.pos.y) === 'stairs') {
    log(s, 'Du stehst an einem Treppenhaus. Hier kannst du auf die nächste Etage hinabsteigen.', 'system');
  }
}

function onEnterRoom(s: GameState, room: NonNullable<ReturnType<typeof currentRoom>>) {
  const first = !room.visited;
  room.visited = true;
  if (first) log(s, `【${room.name}】 ${room.description}`, 'info');
  else log(s, `Du betrittst: ${room.name}.`, 'info');

  if (room.kind === 'guild' && !hasUnlock(s, 'inventar')) runTutorial(s);
  if (room.kind === 'safe' && first) {
    if (room.safeVariant === 'restaurant') {
      const host = RESTAURANT_HOSTS[room.id % RESTAURANT_HOSTS.length];
      log(s, `${host.name} (${host.race}): ${host.greeting}`, 'dialog');
    } else {
      log(s, 'Der Automat piept freundlich. „EIN GRATIS-GEGENSTAND PRO CRAWLER!“', 'dialog');
    }
    log(s, 'Hier drin kann dir niemand etwas tun. Hier kannst du Lootboxen öffnen und schlafen.', 'system');
  }
  if ((room.kind === 'boss' || room.kind === 'arena') && first) {
    const boss = s.monsters.find((m) => m.homeRoom === room.id);
    const def = boss && HOOD_BOSSES.find((b) => b.id === boss.defId);
    if (def) {
      log(s, def.intro, 'gefahr');
      const info = describeMonster(s, boss!);
      log(s, info.insight <= 2 ? `BOSS: ${def.name} (${info.level}). ${def.flavor}` : `BOSS: ${info.name}. ${info.level}. Du kannst nicht einschätzen, womit du es zu tun hast.`, 'gefahr');
    }
  }
  emit(s, { type: 'enterRoom', room });
}

function runTutorial(s: GameState) {
  const formerCrawler = s.guideName !== DEFAULT_GUIDE.name;
  s.pendingDialogs.push({
    title: 'Gilde der Einweisung',
    speaker: s.guideName,
    pages: tutorialPages(s.guideName, DEFAULT_GUIDE.description, formerCrawler),
  });
  s.unlocks.push('inventar', 'stats', 'minimap', 'skills');
  const p = s.player;
  if (p.hand) {
    addToInventory(s, p.hand);
    p.hand = null;
  }
  addToInventory(s, createItem(s, 'kleiner_heiltrank', 2));
  log(s, `${s.guideName} schiebt dir zwei kleine Heiltränke über den Tresen. „Geht aufs Haus.“`, 'loot');
  if (formerCrawler) {
    p.stats.str += 1;
    p.stats.ges += 1;
    p.stats.kon += 1;
    log(s, `${s.guideName} bringt dir ein paar Tricks aus der eigenen Staffel bei: +1 Stärke, +1 Geschick, +1 Konstitution.`, 'system');
  }
  log(s, 'FREIGESCHALTET: Inventar, Werte, Skills und automatische Kartierung.', 'system');
  toast(s, 'Tutorial abgeschlossen', 'Inventar, Werte, Skills und Karte freigeschaltet!', 'level');
  emit(s, { type: 'tutorialDone' });
}

// ================================================================ Items

export function pickup(s: GameState, uid?: string): ActionResult {
  const p = s.player;
  const here = itemsAt(s, p.pos).filter((e) => !uid || e.item.uid === uid);
  if (!here.length) return fail('Hier liegt nichts.');
  for (const entry of here) {
    const it = entry.item;
    if (it.kind === 'karte') {
      s.items = s.items.filter((e) => e !== entry);
      revealHood(s, it.hood ?? 0);
      continue;
    }
    if (!hasUnlock(s, 'inventar') && it.kind !== 'gold') {
      if (p.hand) {
        // Tauschen: alten Gegenstand hinlegen
        s.items.push({ pos: { ...p.pos }, item: p.hand });
        log(s, `Du legst ${p.hand.name} ab.`, 'info');
      }
      p.hand = it;
      s.items = s.items.filter((e) => e !== entry);
      log(s, `Du nimmst ${itemName(s, it)} in die Hand.`, 'loot');
      s.counters.itemsPicked += 1;
      emit(s, { type: 'pickup', item: it });
      break; // nur ein Gegenstand in der Hand
    }
    s.items = s.items.filter((e) => e !== entry);
    giveItem(s, it);
    s.counters.itemsPicked += 1;
    log(s, `Aufgehoben: ${itemName(s, it)}${it.menge && it.menge > 1 && it.kind !== 'gold' ? ` ×${it.menge}` : ''}.`, 'loot');
    emit(s, { type: 'pickup', item: it });
  }
  return OK;
}

function revealHood(s: GameState, hood: number) {
  const m = s.map;
  for (let y = 0; y < MAP_H; y++) {
    for (let x = 0; x < MAP_W; x++) {
      if (hoodOf(m, { x, y }) !== hood) continue;
      const near = neighbors({ x, y }).some((n) => isWalkable(m, n.x, n.y)) || isWalkable(m, x, y);
      if (near) m.explored[idx(m, x, y)] = true;
    }
  }
  m.hoods[hood].mapFound = true;
  log(s, `Die Gebietskarte zeigt dir den kompletten Grundriss: ${m.hoods[hood].name}.`, 'system');
  emit(s, { type: 'mapPicked', hood });
}

function findOwned(s: GameState, uid: string): { item: Item; from: 'hand' | 'inv' } | null {
  if (s.player.hand?.uid === uid) return { item: s.player.hand, from: 'hand' };
  const it = s.player.inventory.find((i) => i.uid === uid);
  return it ? { item: it, from: 'inv' } : null;
}

function removeOne(s: GameState, uid: string) {
  const p = s.player;
  const owned = findOwned(s, uid);
  if (!owned) return;
  const it = owned.item;
  if ((it.menge ?? 1) > 1) {
    it.menge = (it.menge ?? 1) - 1;
    return;
  }
  if (owned.from === 'hand') p.hand = null;
  else p.inventory = p.inventory.filter((i) => i.uid !== uid);
}

const FOOD = FOOD_IDS;

function applyEffect(s: GameState, e: ConsumableEffect, isFood: boolean) {
  const p = s.player;
  if (e.heal) {
    const boost = isFood ? 1 + 0.15 * skillLevel(s, 'kochen') : 1;
    const amount = Math.round(e.heal * boost);
    p.hp = Math.min(maxHp(s), p.hp + amount);
    log(s, `+${amount} HP.`, 'info');
  }
  if (e.ausdauer) p.ausdauer = Math.min(maxAusdauer(s), p.ausdauer + e.ausdauer);
  if (e.cure) cure(s);
  if (e.buff) {
    p.buffs = p.buffs.filter((b) => b.name !== e.buff!.name);
    p.buffs.push(structuredClone(e.buff));
    log(s, `Effekt: ${e.buff.name} (${e.buff.turns} Züge).`, 'info');
  }
}

export function useItem(s: GameState, uid: string): ActionResult {
  const owned = findOwned(s, uid);
  if (!owned) return fail('Nicht gefunden.');
  const it = owned.item;
  if (it.kind !== 'verbrauch') return fail('Das kann man nicht benutzen.');
  if (it.baseId === 'leckerli') {
    const pet = s.player.pet;
    if (pet) {
      petLevelUp(s);
      pet.alive = true;
      log(s, `${pet.name} verschlingt das Leckerli und glüht kurz auf.`, 'system');
    } else {
      log(s, 'Du isst das Haustier-Leckerli. Es schmeckt nach Fisch und Reue. Die Zuschauer sind verstört.', 'info');
    }
  } else {
    log(s, `Du benutzt: ${itemName(s, it)}.`, 'info');
    if (it.baseId.includes('trank') || it.baseId === 'gegengift') s.counters.potionsDrunk += 1;
    applyEffect(s, it.effekt ?? {}, FOOD.has(it.baseId));
    if (FOOD.has(it.baseId)) emit(s, { type: 'eat', item: it });
  }
  removeOne(s, uid);
  endTurn(s);
  return OK;
}

function slotFor(s: GameState, it: Item): EquipSlot | null {
  const eq = s.player.equipment;
  if (!it.slot) return null;
  if (it.slot === 'ring') return !eq.ring1 ? 'ring1' : !eq.ring2 ? 'ring2' : 'ring1';
  if (it.slot === 'fussring') return !eq.fussring1 ? 'fussring1' : !eq.fussring2 ? 'fussring2' : 'fussring1';
  return it.slot as EquipSlot;
}

export function equip(s: GameState, uid: string): ActionResult {
  if (!hasUnlock(s, 'inventar')) return fail('Ohne Inventar kannst du nichts umziehen. Finde die Gilde.');
  const p = s.player;
  const it = p.inventory.find((i) => i.uid === uid);
  if (!it || it.kind !== 'ausruestung') return fail('Das kann man nicht anlegen.');
  const slot = slotFor(s, it);
  if (!slot) return fail('Kein passender Platz.');
  const old = p.equipment[slot];
  p.inventory = p.inventory.filter((i) => i.uid !== uid);
  if (old) p.inventory.push(old);
  p.equipment[slot] = it;
  log(s, `Angelegt: ${itemName(s, it)}.`, 'info');
  emit(s, { type: 'equip', item: it });
  clampVitals(s);
  endTurn(s);
  return OK;
}

export function unequip(s: GameState, slot: EquipSlot): ActionResult {
  if (!hasUnlock(s, 'inventar')) return fail('Ohne Inventar wohin damit? Finde die Gilde.');
  const p = s.player;
  const it = p.equipment[slot];
  if (!it) return fail('Da ist nichts.');
  delete p.equipment[slot];
  p.inventory.push(it);
  clampVitals(s);
  log(s, `Abgelegt: ${itemName(s, it)}.`, 'info');
  return OK;
}

export function dropItem(s: GameState, uid: string): ActionResult {
  const owned = findOwned(s, uid);
  if (!owned) return fail('Nicht gefunden.');
  const p = s.player;
  if (owned.from === 'hand') p.hand = null;
  else p.inventory = p.inventory.filter((i) => i.uid !== uid);
  s.items.push({ pos: { ...p.pos }, item: owned.item });
  log(s, `Du lässt ${itemName(s, owned.item)} fallen.`, 'info');
  return OK;
}

// ================================================================ Safe Room

export function openBox(s: GameState, uid: string): { ok: boolean; message?: string; contents?: Item[] } {
  const p = s.player;
  if (!isInSafeRoom(s, p.pos)) return fail('Lootboxen kannst du nur in einem Safe Room öffnen.');
  if (!hasUnlock(s, 'inventar')) return fail('Du brauchst erst ein Inventar. Schließ das Tutorial in der Gilde ab.');
  const box = p.boxes.find((b) => b.uid === uid);
  if (!box?.box) return fail('Box nicht gefunden.');
  p.boxes = p.boxes.filter((b) => b.uid !== uid);
  const contents = rollBoxContents(s, box.box.type, box.box.tier);
  for (const it of contents) giveItem(s, it);
  s.counters.boxesOpened += 1;
  log(s, `Du öffnest: ${box.name}. Inhalt: ${contents.map((c) => itemName(s, c) + (c.menge && c.menge > 1 && c.kind !== 'gold' ? ` ×${c.menge}` : '')).join(', ')}.`, 'loot');
  emit(s, { type: 'boxOpened', item: box, contents });
  return { ok: true, contents };
}

export function takeFreebie(s: GameState): { ok: boolean; message?: string; item?: Item } {
  const room = currentRoom(s);
  if (room?.kind !== 'safe' || room.safeVariant !== 'freebie') return fail('Hier gibt es keinen Gratis-Automaten.');
  if (room.freebieTaken) return fail('„ERROR: Du hattest deinen Gratis-Gegenstand schon, Crawler.“');
  room.freebieTaken = true;
  const rarity = R.weighted<Rarity>(s, [['ungewoehnlich', 60], ['selten', 35], ['episch', 5]]);
  const item = R.chance(s, 0.25) ? createItem(s, 'heiltrank', 2) : generateEquipment(s, rarity);
  giveItem(s, item);
  log(s, `Der Automat spuckt aus: ${itemName(s, item)}${item.menge && item.menge > 1 ? ` ×${item.menge}` : ''}.`, 'loot');
  return { ok: true, item };
}

export function buyMeal(s: GameState, menuId: string): ActionResult {
  const room = currentRoom(s);
  if (room?.kind !== 'safe' || room.safeVariant !== 'restaurant') return fail('Hier gibt es kein Restaurant.');
  const meal = RESTAURANT_MENU.find((m) => m.id === menuId);
  if (!meal) return fail('Das steht nicht auf der Karte.');
  if (s.player.gold < meal.price) return fail('Nicht genug Gold. „Anschreiben gibt’s nicht, Schätzchen.“');
  s.player.gold -= meal.price;
  log(s, `Du bestellst ${meal.name}. ${meal.flavor}`, 'dialog');
  s.counters.mealsEaten += 1;
  applyEffect(s, meal.effekt, true);
  const pseudo: Item = {
    uid: `meal${s.turn}`, baseId: meal.id, name: meal.name, kind: 'verbrauch', rarity: 'gewoehnlich',
    flavor: meal.flavor, wert: meal.price,
  };
  emit(s, { type: 'eat', item: pseudo });
  endTurn(s);
  return OK;
}

export function sleep(s: GameState): ActionResult {
  if (!isInSafeRoom(s, s.player.pos)) return fail('Schlafen kannst du nur in einem Safe Room.');
  const duration = Math.min(160, timeLeft(s) - 21);
  if (duration < 10) return fail('Keine Zeit mehr zum Schlafen – die Etage stürzt bald ein!');
  const p = s.player;
  const before = timeLeft(s);
  s.turn += duration;
  const healPct = 0.6 + 0.1 * skillLevel(s, 'erste_hilfe');
  p.hp = Math.min(maxHp(s), p.hp + Math.round(maxHp(s) * healPct));
  p.ausdauer = maxAusdauer(s);
  if (p.pet) {
    if (!p.pet.alive) log(s, `${p.pet.name} taucht in einem Lichtblitz wieder auf und rollt sich neben dir zusammen.`, 'info');
    p.pet.alive = true;
    p.pet.hp = p.pet.maxHp;
    p.pet.pos = { ...(neighbors(p.pos).find((q) => isWalkable(s.map, q.x, q.y) && !occupied(s, q)) ?? p.pos) };
  }
  // Wache Monster verlieren das Interesse.
  for (const m of s.monsters) if (m.homeRoom === undefined) m.aware = false;
  log(s, `Du schläfst ${Math.round((duration * 3) / 60)} Stunden. Du fühlst dich erholt (${Math.round(healPct * 100)} % Heilung).`, 'info');
  s.counters.sleeps += 1;
  cure(s);
  emit(s, { type: 'sleep' });
  tickTime(s, duration, before);
  return OK;
}

// ================================================================ Werte

export function allocateStat(s: GameState, key: StatKey): ActionResult {
  if (!hasUnlock(s, 'stats')) return fail('Werte sind noch nicht freigeschaltet.');
  if (s.player.statPoints <= 0) return fail('Keine Punkte übrig.');
  s.player.statPoints -= 1;
  s.player.stats[key] += 1;
  return OK;
}

// ================================================================ Etagenwechsel

export function onStairs(s: GameState): boolean {
  return tileAt(s.map, s.player.pos.x, s.player.pos.y) === 'stairs';
}

export function descend(s: GameState, meta: Pick<MetaState, 'ghosts'>): ActionResult {
  if (!onStairs(s)) return fail('Hier ist keine Treppe.');
  emit(s, { type: 'descend', floor: s.floor + 1 });
  if (s.floor + 1 > LAST_PLAYABLE_FLOOR) {
    s.status = 'victory';
    log(s, `Du steigst hinab… und landest vor einer Tür mit einem Schild: „Etage ${s.floor + 1} – Baustelle. Bitte später wiederkommen.“`, 'system');
    return OK;
  }
  const next = s.floor + 1;
  enterFloor(s, next, meta);
  const def = FLOORS.find((f) => f.floor === next)!;
  log(s, `Etage ${next}: ${def.name}.`, 'system');
  const pages = [def.intro];
  if (next === 2 && !hasUnlock(s, 'zuschauer')) {
    s.unlocks.push('zuschauer');
    pages.push(
      'NEU: DAS PUBLIKUM! Ab sofort schaut dir die ganze Galaxis live zu. Spektakuläre Aktionen – Stampfer, Sprungtritte, Bosskills, knappe Rettungen, Achievements – bringen Hype und Follower.',
      'Mehr Follower bedeuten Fan-Boxen (bei 100, 250, 500, 1000 … Followern) und ab und zu Geschenke aus dem Publikum. Charisma hilft. Langeweile nicht. Die Zuschauer schalten nicht gerne bei jemandem ein, der nur wartet.',
    );
    log(s, 'FREIGESCHALTET: Zuschauer, Follower und Fan-Boxen.', 'system');
  }
  if (next === 3 && !hasUnlock(s, 'klasse')) {
    s.pendingSelection = true;
    pages.push(
      `Kaum hast du die Treppe verlassen, zieht dich ein Lichtstrahl zurück in die Gilde der Einweisung. ${s.guideName} wartet schon. „Es ist so weit. Etage 3. Zeit, dich zu entscheiden, was du sein willst.“`,
      '„Du darfst deine RASSE wählen – oder Mensch bleiben. Einige Rassen hast du dir durch dein Verhalten erst freigeschaltet. Und die Systemstimme hat dir eine persönliche KLASSENLISTE erstellt – basierend darauf, wie du bisher gekämpft hast. Die drei Empfehlungen oben passen am besten zu dir.“',
      '„Jede Klasse bringt eine besondere Fähigkeit mit. Überleg gut. Das kannst du nicht rückgängig machen.“',
    );
  }
  s.pendingDialogs.push({ title: `Etage ${next}: ${def.name}`, speaker: 'Die Systemstimme', pages });
  return OK;
}

// ================================================================ Verträge (ab Etage 9)

export const CONTRACT_MIN_FLOOR = 9;

export function canSignContract(s: GameState): boolean {
  return s.floor >= CONTRACT_MIN_FLOOR && !s.contractSigned;
}

/** Unterschreibt einen NPC-Vertrag: Beim Tod wird man stattdessen Guide für den nächsten Crawler. */
export function signContract(s: GameState): ActionResult {
  if (!canSignContract(s)) return fail(`Verträge gibt es erst ab Etage ${CONTRACT_MIN_FLOOR}.`);
  s.contractSigned = true;
  log(s, 'Du unterschreibst den Vertrag. Die Tinte leuchtet kurz rot auf. Das ist bestimmt normal.', 'system');
  return OK;
}

// ================================================================ Hilfen für die UI

export function drainToasts(s: GameState) {
  const t = s.toasts;
  s.toasts = [];
  return t;
}

export function isVisible(vis: Set<number>, s: GameState, p: Pos) {
  return vis.has(idx(s.map, p.x, p.y));
}

