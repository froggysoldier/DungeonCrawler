import { HOOD_BOSSES } from '../data/monsters';
import {
  ARRIVAL_ROOM, FLOORS, GUILD_ROOM, HOOD_NAMES, ROOM_FLAVORS, SAFE_ROOM_FREEBIE, SAFE_ROOM_RESTAURANT, START_ROOM,
} from '../data/world';
import { createItem, rollGroundItem, rollMaterial } from './items';
import { clampLevel, pickMonsterDef, spawnBoss, spawnGhost, spawnMonster } from './monsters';
import * as R from './rng';
import type { FloorMap, Furniture, FurnitureKind, GameState, GhostRecord, Item, Monster, Pos, Room, RoomKind, Tile } from './types';

export const MAP_W = 72;
export const MAP_H = 52;

export interface GeneratedFloor {
  map: FloorMap;
  monsters: Monster[];
  items: { pos: Pos; item: Item }[];
  start: Pos;
}

export const idx = (m: { width: number }, x: number, y: number) => y * m.width + x;

export function inBounds(m: FloorMap, x: number, y: number): boolean {
  return x >= 0 && y >= 0 && x < m.width && y < m.height;
}

export function tileAt(m: FloorMap, x: number, y: number): Tile {
  return inBounds(m, x, y) ? m.tiles[idx(m, x, y)] : 'wall';
}

export function isWalkable(m: FloorMap, x: number, y: number): boolean {
  const t = tileAt(m, x, y);
  return t === 'floor' || t === 'stairs' || t === 'dooropen';
}

/** Blockiert die Sicht (Wände und geschlossene Türen). */
export function blocksSight(m: FloorMap, x: number, y: number): boolean {
  const t = tileAt(m, x, y);
  return t === 'wall' || t === 'door';
}

/**
 * Gilden und Safe Rooms bekommen echte Wände mit Türen: Der Rand des Raums
 * wird zur Mauer, und wo ein Gang ankommt, sitzt eine geschlossene Tür.
 * Mehrere Zugänge nebeneinander teilen sich eine Tür.
 */
function addWallsAndDoors(m: FloorMap, r: Room) {
  const inside = (x: number, y: number) => x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h;
  const edge = (x: number, y: number) => x === r.x || y === r.y || x === r.x + r.w - 1 || y === r.y + r.h - 1;
  const corner = (x: number, y: number) => (x === r.x || x === r.x + r.w - 1) && (y === r.y || y === r.y + r.h - 1);
  const candidates: Pos[] = [];
  for (let y = r.y; y < r.y + r.h; y++) {
    for (let x = r.x; x < r.x + r.w; x++) {
      if (!edge(x, y)) continue;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const q = { x: x + dx, y: y + dy };
        if (inside(q.x, q.y) || !inBounds(m, q.x, q.y)) continue;
        if (m.tiles[idx(m, q.x, q.y)] === 'wall' || m.roomAt[idx(m, q.x, q.y)] !== -1) continue;
        if (!corner(x, y)) {
          candidates.push({ x, y });
          continue;
        }
        // Gang trifft genau auf eine Ecke: Tür eins weiter setzen und den Gang anschließen
        const along = dx !== 0 ? { x, y: y === r.y ? y + 1 : y - 1 } : { x: x === r.x ? x + 1 : x - 1, y };
        if (corner(along.x, along.y)) continue;
        const outside = { x: along.x + dx, y: along.y + dy };
        if (inBounds(m, outside.x, outside.y) && m.roomAt[idx(m, outside.x, outside.y)] === -1) {
          m.tiles[idx(m, outside.x, outside.y)] = 'floor';
          candidates.push(along);
        }
      }
    }
  }
  // Rand zu Wänden machen
  for (let y = r.y; y < r.y + r.h; y++) {
    for (let x = r.x; x < r.x + r.w; x++) {
      if (!edge(x, y)) continue;
      m.tiles[idx(m, x, y)] = 'wall';
      m.roomAt[idx(m, x, y)] = -1;
    }
  }
  // Benachbarte Zugänge zusammenfassen: eine Tür pro Gruppe
  const used = new Set<string>();
  for (const c of candidates) {
    const key = `${c.x},${c.y}`;
    if (used.has(key)) continue;
    const group = [c];
    used.add(key);
    for (let k = 0; k < group.length; k++) {
      for (const o of candidates) {
        const ok = `${o.x},${o.y}`;
        if (!used.has(ok) && Math.abs(o.x - group[k].x) + Math.abs(o.y - group[k].y) === 1) {
          used.add(ok);
          group.push(o);
        }
      }
    }
    const door = group[Math.floor(group.length / 2)];
    m.tiles[idx(m, door.x, door.y)] = 'door';
  }
  // Der Raum selbst ist jetzt das Innere
  r.x += 1;
  r.y += 1;
  r.w -= 2;
  r.h -= 2;
}

export function roomOf(m: FloorMap, p: Pos): Room | null {
  if (!inBounds(m, p.x, p.y)) return null;
  const r = m.roomAt[idx(m, p.x, p.y)];
  return r >= 0 ? m.rooms[r] : null;
}

export function hoodOf(m: FloorMap, p: Pos): number {
  const left = p.x < m.width / 2;
  const top = p.y < m.height / 2;
  if (top) return left ? 0 : 1;
  return left ? 3 : 2;
}

const center = (r: Room): Pos => ({ x: Math.floor(r.x + r.w / 2), y: Math.floor(r.y + r.h / 2) });
const dist = (a: Pos, b: Pos) => Math.abs(a.x - b.x) + Math.abs(a.y - b.y);

function overlaps(a: { x: number; y: number; w: number; h: number }, rooms: Room[]): boolean {
  return rooms.some((r) => a.x - 2 < r.x + r.w && a.x + a.w + 2 > r.x && a.y - 2 < r.y + r.h && a.y + a.h + 2 > r.y);
}

function carveRoom(m: FloorMap, r: Room) {
  for (let y = r.y; y < r.y + r.h; y++) {
    for (let x = r.x; x < r.x + r.w; x++) {
      m.tiles[idx(m, x, y)] = 'floor';
      m.roomAt[idx(m, x, y)] = r.id;
    }
  }
}

/**
 * Gräbt einen Gang von a nach b. Boss-Kammern und die Arena werden dabei
 * umgangen (außer sie sind Start oder Ziel), damit man nicht zwangsweise
 * durch eine Boss-Kammer laufen muss. Bestehende Gänge werden bevorzugt.
 */
function carveCorridor(m: FloorMap, a: Pos, b: Pos, forbidden: Set<number>): boolean {
  const start = idx(m, a.x, a.y);
  const goal = idx(m, b.x, b.y);
  const blocked = (i: number) => forbidden.has(i) && i !== start && i !== goal;
  const dist = new Map<number, number>([[start, 0]]);
  const came = new Map<number, number>();
  const open: { i: number; f: number }[] = [{ i: start, f: 0 }];
  const done = new Set<number>();
  while (open.length) {
    let best = 0;
    for (let k = 1; k < open.length; k++) if (open[k].f < open[best].f) best = k;
    const { i } = open.splice(best, 1)[0];
    if (i === goal) break;
    if (done.has(i)) continue;
    done.add(i);
    const x = i % m.width;
    const y = Math.floor(i / m.width);
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx;
      const ny = y + dy;
      if (nx < 1 || ny < 1 || nx >= m.width - 1 || ny >= m.height - 1) continue;
      const ni = idx(m, nx, ny);
      if (blocked(ni)) continue;
      const cost = m.tiles[ni] === 'wall' ? 3 : 1;
      const nd = dist.get(i)! + cost;
      if (nd < (dist.get(ni) ?? Infinity)) {
        dist.set(ni, nd);
        came.set(ni, i);
        open.push({ i: ni, f: nd + Math.abs(nx - b.x) + Math.abs(ny - b.y) });
      }
    }
  }
  if (!came.has(goal)) return false;
  let cur = goal;
  while (cur !== start) {
    if (m.tiles[cur] === 'wall') m.tiles[cur] = 'floor';
    cur = came.get(cur)!;
  }
  return true;
}

function randomFloorIn(s: GameState, m: FloorMap, r: Room, occupied: Set<string>): Pos | null {
  for (let i = 0; i < 40; i++) {
    const p = { x: R.int(s, r.x, r.x + r.w - 1), y: R.int(s, r.y, r.y + r.h - 1) };
    const key = `${p.x},${p.y}`;
    if (m.tiles[idx(m, p.x, p.y)] === 'floor' && !occupied.has(key)) {
      occupied.add(key);
      return p;
    }
  }
  return null;
}

export function generateFloor(s: GameState, floor: number, ghosts: GhostRecord[]): GeneratedFloor {
  const def = FLOORS.find((f) => f.floor === floor) ?? FLOORS[FLOORS.length - 1];
  const m: FloorMap = {
    width: MAP_W,
    height: MAP_H,
    tiles: new Array(MAP_W * MAP_H).fill('wall'),
    roomAt: new Array(MAP_W * MAP_H).fill(-1),
    rooms: [],
    hoods: HOOD_NAMES.map((name, id) => ({ id, name, bossAlive: true, mapFound: false })),
    explored: new Array(MAP_W * MAP_H).fill(false),
  };

  // --- Zentrale Arena des Borough-Bosses mit Treppenhaus
  const arena: Room = {
    id: 0, x: Math.floor(MAP_W / 2) - 6, y: Math.floor(MAP_H / 2) - 5, w: 13, h: 10,
    kind: 'arena', hood: -1, name: 'Das Große Gewölbe',
    description: 'Ein riesiges Ziegelgewölbe. In der Mitte blubbert ein Kessel, groß wie ein Pool. Hinter ihm: ein Schild mit einem Pfeil nach unten.',
  };
  m.rooms.push(arena);

  // --- Räume je Viertel
  const halfW = MAP_W / 2;
  const halfH = MAP_H / 2;
  for (let hood = 0; hood < 4; hood++) {
    const qx = hood === 0 || hood === 3 ? 0 : halfW;
    const qy = hood < 2 ? 0 : halfH;
    let placed = 0;
    for (let tries = 0; tries < 400 && placed < 10; tries++) {
      const w = R.int(s, 5, 10);
      const h = R.int(s, 4, 7);
      const x = R.int(s, qx + 1, qx + halfW - w - 2);
      const y = R.int(s, qy + 1, qy + halfH - h - 2);
      const cand = { x, y, w, h };
      if (overlaps(cand, m.rooms)) continue;
      m.rooms.push({ id: m.rooms.length, ...cand, kind: 'normal', hood, name: '', description: '' });
      placed++;
    }
  }
  // --- Raumtypen zuweisen
  const hoodRooms = (h: number) => m.rooms.filter((r) => r.hood === h && r.kind === 'normal');
  const startHood = R.int(s, 0, 3);
  const corner: Pos = {
    x: startHood === 0 || startHood === 3 ? 0 : MAP_W,
    y: startHood < 2 ? 0 : MAP_H,
  };
  const startRoom = hoodRooms(startHood).sort((a, b) => dist(center(a), corner) - dist(center(b), corner))[0];
  const arrival = floor === 1 ? START_ROOM : ARRIVAL_ROOM;
  assign(startRoom, 'start', arrival.name, arrival.description);

  // Gilde: im Start-Viertel in mittlerer Entfernung, plus eine weitere woanders
  const byDistFromStart = (rs: Room[]) =>
    rs.sort((a, b) => dist(center(a), center(startRoom)) - dist(center(b), center(startRoom)));
  const guildCandidates = byDistFromStart(hoodRooms(startHood));
  const guild1 = guildCandidates[Math.min(2, guildCandidates.length - 1)];
  if (guild1) assign(guild1, 'guild', GUILD_ROOM.name, GUILD_ROOM.description);
  const otherHood = (startHood + 2) % 4;
  const guild2 = R.pick(s, hoodRooms(otherHood));
  if (guild2) assign(guild2, 'guild', GUILD_ROOM.name, GUILD_ROOM.description);

  // Boss-Kammern: der vom Start am weitesten entfernte große Raum je Viertel
  const bossRooms: Room[] = [];
  for (let h = 0; h < 4; h++) {
    const cands = hoodRooms(h).filter((r) => r.w * r.h >= 30);
    const list = cands.length ? cands : hoodRooms(h);
    const room = list.sort((a, b) => dist(center(b), center(startRoom)) - dist(center(a), center(startRoom)))[0];
    if (room) {
      assign(room, 'boss', `Kammer: ${HOOD_NAMES[h]}`, 'Die Luft ist schwer. Irgendetwas Großes lebt hier – und es bewacht das ganze Viertel.');
      bossRooms.push(room);
    }
  }

  // Safe Rooms: einer je Viertel, plus einer zusätzlich
  for (let h = 0; h < 5; h++) {
    const hood = h < 4 ? h : R.int(s, 0, 3);
    // Groß genug für Einrichtung (innen mindestens 5 × 3)
    const cands = hoodRooms(hood).filter((r) => r.w >= 7 && r.h >= 5 && r.w * r.h <= 60);
    const room = cands.length ? R.pick(s, cands) : R.pick(s, hoodRooms(hood));
    if (!room) continue;
    const variant = R.chance(s, 0.5) ? 'freebie' : 'restaurant';
    const flavor = variant === 'freebie' ? SAFE_ROOM_FREEBIE : SAFE_ROOM_RESTAURANT;
    assign(room, 'safe', flavor.name, flavor.description);
    room.safeVariant = variant;
  }

  for (const r of m.rooms) carveRoom(m, r);

  // --- Verbinden: minimaler Spannbaum über die normalen Räume, ein paar
  // Extra-Gänge für Rundwege. Boss-Kammern und die Arena sind Sackgassen
  // mit genau einem Zugang – man läuft nie aus Versehen durch sie hindurch.
  const isLair = (r: Room) => r.kind === 'boss' || r.kind === 'arena';
  const hubs = m.rooms.filter((r) => !isLair(r));
  const connected = new Set<number>([startRoom.id]);
  const edges: [number, number][] = [];
  while (connected.size < hubs.length) {
    let best: [number, number] | null = null;
    let bestD = Infinity;
    for (const a of connected) {
      for (const r of hubs) {
        if (connected.has(r.id)) continue;
        const d = dist(center(m.rooms[a]), center(r));
        if (d < bestD) {
          bestD = d;
          best = [a, r.id];
        }
      }
    }
    if (!best) break;
    connected.add(best[1]);
    edges.push(best);
  }
  for (let i = 0; i < 8; i++) {
    const a = R.pick(s, hubs);
    const near = hubs
      .filter((r) => r.id !== a.id)
      .sort((p, q) => dist(center(a), center(p)) - dist(center(a), center(q)))
      .slice(0, 3);
    edges.push([a.id, R.pick(s, near).id]);
  }
  // Jede Kammer hat genau einen Zugang – über ihren Vorraum
  const antechambers: Room[] = [];
  for (const lair of m.rooms.filter(isLair)) {
    const nearest = [...hubs]
      .filter((r) => r.kind === 'normal' && r.antechamberOf === undefined)
      .sort((p, q) => dist(center(lair), center(p)) - dist(center(lair), center(q)))[0];
    if (!nearest) continue;
    nearest.antechamberOf = lair.id;
    antechambers.push(nearest);
    edges.push([nearest.id, lair.id]);
  }
  // Boss-Kammern und Arena (inkl. Rand) sind für fremde Gänge tabu
  const forbiddenFor = (roomIds: number[]) => {
    const set = new Set<number>();
    for (const r of m.rooms) {
      if (!isLair(r) || roomIds.includes(r.id)) continue;
      for (let y = r.y - 1; y <= r.y + r.h; y++) for (let x = r.x - 1; x <= r.x + r.w; x++) set.add(idx(m, x, y));
    }
    return set;
  };
  for (const [a, b] of edges) {
    const from = center(m.rooms[a]);
    const to = center(m.rooms[b]);
    if (!carveCorridor(m, from, to, forbiddenFor([a, b]))) carveCorridor(m, from, to, new Set());
  }

  // Gilden, Safe Rooms und Kammern: Mauern und Türen
  for (const r of m.rooms) if (r.kind === 'guild' || r.kind === 'safe' || isLair(r)) addWallsAndDoors(m, r);

  for (const r of m.rooms) if (r.kind === 'safe') furnish(s, m, r);

  // Übrige Räume bekommen Namen und Beschreibungen
  const flavors = R.shuffle(s, [...(def.flavors ?? ROOM_FLAVORS)]);
  let fi = 0;
  for (const r of m.rooms) {
    if (r.kind !== 'normal') continue;
    const f = flavors[fi++ % flavors.length];
    r.name = f.name;
    r.description = f.description;
    if (r.antechamberOf !== undefined) {
      const lair = m.rooms[r.antechamberOf];
      r.name = `Vorraum: ${f.name}`;
      r.description = `${f.description} Eine schwere, mit rotem Eisen beschlagene Tür führt von hier in ${lair.kind === 'arena' ? 'das Große Gewölbe' : 'eine Boss-Kammer'}. Wer sie durchschreitet, kommt erst wieder heraus, wenn der Boss besiegt ist. Hier haben andere ihre Sachen zurückgelassen.`;
    }
  }

  // --- Treppenhäuser: eins in der Arena, zwei in abgelegenen Räumen
  const arenaC = center(arena);
  m.tiles[idx(m, arenaC.x, arena.y + 1)] = 'stairs';
  const farRooms = m.rooms
    .filter((r) => r.kind === 'normal')
    .sort((a, b) => dist(center(b), center(startRoom)) - dist(center(a), center(startRoom)));
  for (const r of [farRooms[0], farRooms[3]].filter(Boolean)) {
    const c = center(r);
    m.tiles[idx(m, c.x, c.y)] = 'stairs';
    r.description += ' In einer Ecke führt eine schmale Treppe in die Tiefe.';
  }

  // --- Bewohner
  const occupied = new Set<string>();
  const start = center(startRoom);
  occupied.add(`${start.x},${start.y}`);
  const monsters: Monster[] = [];
  const items: { pos: Pos; item: Item }[] = [];
  const maxDist = MAP_W + MAP_H;

  // Bosse: bevorzugt die „eigenen“ Bosse dieser Etage, sonst welche von oben
  const ownBosses = HOOD_BOSSES.filter((b) => b.rank === 'nachbarschaftsboss' && b.floors[0] === floor);
  const visiting = HOOD_BOSSES.filter((b) => b.rank === 'nachbarschaftsboss' && b.floors[0] !== floor && b.floors.includes(floor));
  const bosses = [...R.shuffle(s, ownBosses), ...R.shuffle(s, visiting)];
  bossRooms.forEach((room, i) => {
    const p = center(room);
    occupied.add(`${p.x},${p.y}`);
    monsters.push(spawnBoss(s, bosses[i % bosses.length], p, room.hood, room.id, floor));
  });
  const borough =
    HOOD_BOSSES.find((b) => b.rank === 'boroughboss' && b.floors.includes(floor)) ??
    HOOD_BOSSES.find((b) => b.rank === 'boroughboss')!;
  const arenaBossPos = { x: arenaC.x, y: arenaC.y + 1 };
  occupied.add(`${arenaBossPos.x},${arenaBossPos.y}`);
  monsters.push(spawnBoss(s, borough, arenaBossPos, -1, arena.id, floor));

  for (const r of m.rooms) {
    if (r.kind !== 'normal') continue;
    const d = dist(center(r), start) / maxDist;
    const count = r.antechamberOf !== undefined ? R.int(s, 2, 3) : R.weighted(s, [[0, 2], [1, 4], [2, 3], [3, 1]] as [number, number][]);
    let i = 0;
    while (i < count) {
      const level = Math.max(def.mobLevel[0], Math.round(def.mobLevel[0] + d * 1.6 * (def.mobLevel[1] - def.mobLevel[0]) + R.int(s, -1, 0)));
      const mdef = pickMonsterDef(s, floor, level);
      const lv = clampLevel(mdef, level);
      const packSize = mdef.pack ? R.int(s, mdef.pack[0], mdef.pack[1]) : 1;
      for (let k = 0; k < packSize && i < count + 1; k++, i++) {
        const p = randomFloorIn(s, m, r, occupied);
        if (!p) break;
        const mob = spawnMonster(s, mdef, lv, p, r.hood, d > 0.2 && R.chance(s, 0.07));
        // Ein Teil der Bewohner schläft – Gelegenheit für einen Hinterhalt
        if (mob.behavior !== 'stationary' && R.chance(s, 0.3)) mob.asleep = true;
        monsters.push(mob);
      }
    }
  }

  // Geister früherer Crawler, die auf dieser Etage gestorben sind
  const floorGhosts = ghosts.filter((g) => g.floor === floor).slice(0, 2);
  for (const g of floorGhosts) {
    const room = R.pick(s, farRooms.slice(0, 8));
    const p = room && randomFloorIn(s, m, room, occupied);
    if (p) monsters.push(spawnGhost(s, g, p, room.hood));
  }

  // --- Bodenfunde
  for (let i = 0; i < 3; i++) {
    const p = randomFloorIn(s, m, startRoom, occupied);
    if (p) items.push({ pos: p, item: createItem(s, 'stein') });
  }
  // Normale Räume: nur Material zum Basteln. Echte Beute liegt nur in den
  // Vorräumen der Kammern – dort, wo sich andere nicht weitergetraut haben.
  for (const r of m.rooms) {
    if (r.kind !== 'normal') continue;
    if (r.antechamberOf !== undefined) {
      const n = R.int(s, 2, 4);
      for (let i = 0; i < n; i++) {
        const p = randomFloorIn(s, m, r, occupied);
        if (p) items.push({ pos: p, item: rollGroundItem(s) });
      }
      continue;
    }
    const n = R.weighted(s, [[0, 4], [1, 4], [2, 1]] as [number, number][]);
    for (let i = 0; i < n; i++) {
      const p = randomFloorIn(s, m, r, occupied);
      if (p) items.push({ pos: p, item: rollMaterial(s) });
    }
  }

  return { map: m, monsters, items, start };

  function assign(r: Room | undefined, kind: RoomKind, name: string, description: string) {
    if (!r) return;
    r.kind = kind;
    r.name = name;
    r.description = description;
  }
}

/**
 * Safe Rooms einrichten: Gratis-Automat, Händler, Bett, Toilette und im
 * Restaurant ein Wirt. Alles steht am Rand, weg von der Tür, und jeder
 * freie Platz bleibt erreichbar.
 */
function furnish(s: GameState, m: FloorMap, r: Room) {
  const kinds: FurnitureKind[] = ['automat', ...(r.safeVariant === 'restaurant' ? ['wirt' as const] : []), 'haendler', 'bett', 'toilette'];
  const doorWithin = (x: number, y: number, d: number) => {
    for (let dy = -d; dy <= d; dy++) for (let dx = -d; dx <= d; dx++) {
      const t2 = tileAt(m, x + dx, y + dy);
      if (t2 === 'door' || t2 === 'dooropen') return true;
    }
    return false;
  };
  const edge = (x: number, y: number) => x === r.x || y === r.y || x === r.x + r.w - 1 || y === r.y + r.h - 1;
  const floorTiles: Pos[] = [];
  for (let y = r.y; y < r.y + r.h; y++) for (let x = r.x; x < r.x + r.w; x++) if (m.tiles[idx(m, x, y)] === 'floor') floorTiles.push({ x, y });
  // Oben die „Theken“ (Automat, Wirt, Händler), unten die Möbel; abwechselnd, damit Lücken zum Hinstellen bleiben
  const top = floorTiles.filter((p) => p.y === r.y && !doorWithin(p.x, p.y, 2)).sort((a, b) => a.x - b.x);
  const rest = floorTiles.filter((p) => p.y !== r.y && edge(p.x, p.y) && !doorWithin(p.x, p.y, 2)).sort((a, b) => b.y - a.y || a.x - b.x);
  const preferred = [...top.filter((_, i) => i % 2 === 0), ...rest.filter((_, i) => i % 2 === 0), ...top.filter((_, i) => i % 2 === 1), ...rest.filter((_, i) => i % 2 === 1)];
  // Notfalls näher an die Tür oder in die Raummitte
  const fallback = floorTiles.filter((p) => !doorWithin(p.x, p.y, 1)).sort((a, b) => Number(edge(b.x, b.y)) - Number(edge(a.x, a.y)));
  const pool = [...preferred, ...fallback.filter((p) => !preferred.some((q) => q.x === p.x && q.y === p.y))];
  r.furniture = [];
  for (const kind of kinds) {
    while (pool.length) {
      const pos = pool.shift()!;
      r.furniture.push({ kind, pos });
      // Nichts darf den Raum zerschneiden
      if (roomConnected(m, r) && r.furniture.every((f) => hasFreeSide(m, r, f.pos))) break;
      r.furniture.pop();
    }
  }
  void s;
}

/** Ein Möbelstück braucht eine freie Seite, von der aus man es benutzt. */
function hasFreeSide(m: FloorMap, r: Room, p: Pos): boolean {
  return [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
    const x = p.x + dx;
    const y = p.y + dy;
    if (x < r.x || y < r.y || x >= r.x + r.w || y >= r.y + r.h) return false;
    return m.tiles[idx(m, x, y)] === 'floor' && !(r.furniture ?? []).some((f) => f.pos.x === x && f.pos.y === y);
  });
}

function roomConnected(m: FloorMap, r: Room): boolean {
  const blocked = new Set((r.furniture ?? []).map((f) => `${f.pos.x},${f.pos.y}`));
  const free: Pos[] = [];
  for (let y = r.y; y < r.y + r.h; y++) for (let x = r.x; x < r.x + r.w; x++) {
    if (m.tiles[idx(m, x, y)] !== 'wall' && !blocked.has(`${x},${y}`)) free.push({ x, y });
  }
  if (!free.length) return false;
  const seen = new Set([`${free[0].x},${free[0].y}`]);
  const queue = [free[0]];
  while (queue.length) {
    const c = queue.shift()!;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const n = { x: c.x + dx, y: c.y + dy };
      const key = `${n.x},${n.y}`;
      if (seen.has(key) || blocked.has(key)) continue;
      if (n.x < r.x || n.y < r.y || n.x >= r.x + r.w || n.y >= r.y + r.h) continue;
      if (m.tiles[idx(m, n.x, n.y)] === 'wall') continue;
      seen.add(key);
      queue.push(n);
    }
  }
  return seen.size === free.length;
}

export function furnitureAt(m: FloorMap, p: Pos): Furniture | undefined {
  const r = inBounds(m, p.x, p.y) ? m.roomAt[idx(m, p.x, p.y)] : -1;
  if (r < 0) return undefined;
  return m.rooms[r].furniture?.find((f) => f.pos.x === p.x && f.pos.y === p.y);
}

/** Zufällige begehbare Position, die nicht in einem Safe Room liegt. */
export function randomOpenTile(s: GameState, near: Pos, radius: number, avoid: (p: Pos) => boolean): Pos | null {
  const m = s.map;
  for (let i = 0; i < 200; i++) {
    const p = { x: near.x + R.int(s, -radius, radius), y: near.y + R.int(s, -radius, radius) };
    if (!inBounds(m, p.x, p.y) || !isWalkable(m, p.x, p.y)) continue;
    const r = roomOf(m, p);
    if (r && (r.kind === 'safe' || r.kind === 'guild')) continue;
    if (avoid(p)) continue;
    return p;
  }
  return null;
}
