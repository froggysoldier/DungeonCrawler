import { TARGET_FACETS } from '../data/facets';
import { MONSTERS } from '../data/monsters';
import {
  BOSS_TEXTS, DELIVER_WANTS, FETCH_ITEMS, HUNT_TEXTS, MAX_ACTIVE_QUESTS, QUEST_THANKS, RESCUE_TEXTS,
} from '../data/quests';
import { FLOORS } from '../data/world';
import { crawlers, makeCrawler } from './crawlers';
import { emit } from './events';
import { chebyshev } from './fov';
import { giveItem } from './inventory';
import { createBox, createGold, createItem } from './items';
import { log, toast } from './log';
import { isWalkable, roomOf, tileAt } from './mapgen';
import { monsterDefById, spawnMonster } from './monsters';
import { targetFacets } from './observer';
import { gainXp } from './player';
import * as R from './rng';
import type { GameEvent, GameState, Pos, Quest, QuestKind, Room } from './types';

/**
 * Aufträge: Andere Crawler und Ladenbesitzer bitten um Hilfe. Jagen, Dinge
 * finden, Dinge liefern, Leute retten, Bosse erledigen. Aufträge gelten nur
 * auf der Etage, auf der man sie angenommen hat.
 */

type Res = { ok: boolean; message?: string };

export function quests(s: GameState): Quest[] {
  s.quests ??= [];
  return s.quests;
}

export const activeQuests = (s: GameState) => quests(s).filter((q) => q.status === 'aktiv');

export function questOf(s: GameState, giverRef: string): Quest | undefined {
  return quests(s).find((q) => q.giver.ref === giverRef && (q.status === 'angebot' || q.status === 'aktiv'));
}

function uid(s: GameState, prefix: string) {
  s.uidCounter += 1;
  return `${prefix}${s.uidCounter}`;
}

function reward(s: GameState, kind: QuestKind): Quest['reward'] {
  const f = s.floor;
  const base = { jagd: 25, finden: 30, liefern: 20, retten: 45, boss: 80 }[kind];
  return { gold: Math.round((base + R.int(s, 0, 20)) * f), xp: Math.round(base * 1.5 * f), box: kind === 'boss' || kind === 'retten' || R.chance(s, 0.3) };
}

/** Ein Raum weit weg vom Crawler, bevorzugt in einem anderen Viertel. */
function farRoom(s: GameState): Room | undefined {
  const rooms = s.map.rooms.filter((r) => r.kind === 'normal');
  const here = s.player.pos;
  const far = rooms.filter((r) => chebyshev({ x: r.x, y: r.y }, here) >= 18);
  return R.pick(s, far.length ? far : rooms);
}

function freeSpot(s: GameState, r: Room): Pos | null {
  for (let i = 0; i < 40; i++) {
    const p = { x: R.int(s, r.x, r.x + r.w - 1), y: R.int(s, r.y, r.y + r.h - 1) };
    if (tileAt(s.map, p.x, p.y) !== 'floor') continue;
    if (s.monsters.some((m) => m.pos.x === p.x && m.pos.y === p.y) || crawlers(s).some((c) => c.pos.x === p.x && c.pos.y === p.y)) continue;
    return p;
  }
  return null;
}

/** Monster-Merkmale, die auf dieser Etage vorkommen (für Jagdaufträge). */
function huntFacets(s: GameState): string[] {
  const tags = new Set<string>();
  for (const m of MONSTERS) if (m.floors.includes(s.floor) && m.weight > 0) for (const t of m.tags ?? []) if (TARGET_FACETS[t]) tags.add(t);
  return [...tags];
}

/** Erzeugt ein Auftragsangebot für einen Crawler oder einen Laden. */
export function offerQuest(s: GameState, giver: Quest['giver']): Quest | null {
  const kinds: QuestKind[] = giver.kind === 'laden' ? ['jagd', 'boss', 'liefern'] : ['jagd', 'finden', 'liefern', 'retten', 'finden'];
  const bossHoods = s.map.hoods.filter((h) => h.bossAlive);
  const kind = R.pick(s, kinds.filter((k) => k !== 'boss' || bossHoods.length));
  const room = farRoom(s);
  const hoodName = room ? s.map.hoods[room.hood]?.name ?? 'Nachbarviertel' : 'Nachbarviertel';
  const q: Quest = {
    id: uid(s, 'q'), kind, floor: s.floor, giver, title: '', text: '', status: 'angebot', count: 1, progress: 0, reward: reward(s, kind),
  };
  switch (kind) {
    case 'jagd': {
      const tags = huntFacets(s);
      if (!tags.length) return null;
      const tag = R.pick(s, tags);
      q.facet = `z:${tag}`;
      q.count = R.int(s, 3, 6);
      const label = TARGET_FACETS[tag].label;
      q.title = `Jagd: ${q.count} ${label}`;
      q.text = R.pick(s, HUNT_TEXTS).replace('{n}', String(q.count)).replace('{was}', label);
      break;
    }
    case 'finden': {
      if (!room) return null;
      const f = R.pick(s, FETCH_ITEMS);
      q.hood = room.hood;
      q.title = `Finden: ${f.name}`;
      q.text = f.text.replace('{viertel}', hoodName);
      q.itemIds = [f.name];
      break;
    }
    case 'liefern': {
      const w = R.pick(s, DELIVER_WANTS);
      q.itemIds = [...w.ids];
      q.count = w.n;
      q.title = `Liefern: ${w.n}x ${w.label}`;
      q.text = w.text;
      break;
    }
    case 'retten': {
      if (!room) return null;
      q.hood = room.hood;
      const person = makeCrawler(s, { x: 0, y: 0 }, 'verzweifelt');
      q.title = `Retten: ${person.name}`;
      q.text = R.pick(s, RESCUE_TEXTS).replace('{person}', person.name).replace('{viertel}', hoodName);
      q.itemIds = [person.name];
      break;
    }
    case 'boss': {
      const h = R.pick(s, bossHoods);
      q.hood = h.id;
      q.title = `Boss: ${h.name}`;
      q.text = R.pick(s, BOSS_TEXTS).replace('{viertel}', h.name);
      break;
    }
  }
  quests(s).push(q);
  return q;
}

export function acceptQuest(s: GameState, id: string): Res {
  const q = quests(s).find((x) => x.id === id);
  if (!q || q.status !== 'angebot') return { ok: false, message: 'Diesen Auftrag gibt es nicht.' };
  if (activeQuests(s).length >= MAX_ACTIVE_QUESTS) return { ok: false, message: `Du hast schon ${MAX_ACTIVE_QUESTS} offene Aufträge.` };
  // Ziel in die Welt setzen
  if (q.kind === 'finden' || q.kind === 'retten') {
    const rooms = s.map.rooms.filter((r) => r.kind === 'normal' && r.hood === q.hood);
    const room = rooms.length ? R.pick(s, rooms) : farRoom(s);
    const spot = room && freeSpot(s, room);
    if (!room || !spot) return { ok: false, message: 'Der Auftrag lässt sich gerade nicht annehmen.' };
    if (q.kind === 'finden') {
      const it = createItem(s, 'andenken');
      it.name = q.itemIds![0];
      it.flavor = `Gehört jemandem, der darauf wartet: ${q.giver.name}.`;
      it.questId = q.id;
      s.items.push({ pos: spot, item: it });
      q.targetUid = it.uid;
    } else {
      const c = makeCrawler(s, spot, 'verzweifelt');
      c.name = q.itemIds![0];
      crawlers(s).push(c);
      q.targetUid = c.uid;
      // Ein paar Monster halten die Person in Schach
      const def = FLOORS.find((f) => f.floor === s.floor) ?? FLOORS[0];
      const pool = MONSTERS.filter((m) => m.floors.includes(s.floor) && m.weight > 0 && m.behavior !== 'stationary');
      for (let i = 0; i < 2 && pool.length; i++) {
        const near = [[2, 0], [-2, 0], [0, 2], [0, -2], [2, 2], [-2, -2]].map(([dx, dy]) => ({ x: spot.x + dx, y: spot.y + dy }))
          .find((p) => isWalkable(s.map, p.x, p.y) && roomOf(s.map, p)?.kind === 'normal' && !s.monsters.some((m) => m.pos.x === p.x && m.pos.y === p.y));
        const md = monsterDefById(R.pick(s, pool).id);
        if (near && md) s.monsters.push(spawnMonster(s, md, R.int(s, def.mobLevel[0], def.mobLevel[1]), near, room.hood));
      }
    }
  }
  q.status = 'aktiv';
  log(s, `AUFTRAG ANGENOMMEN: ${q.title}. ${hint(s, q)}`, 'system');
  emit(s, { type: 'questAccepted', kind: q.kind });
  return { ok: true };
}

export function declineQuest(s: GameState, id: string): Res {
  const q = quests(s).find((x) => x.id === id);
  if (!q || q.status !== 'angebot') return { ok: false, message: 'Diesen Auftrag gibt es nicht.' };
  s.quests = quests(s).filter((x) => x !== q);
  return { ok: true };
}

/** Kurzer Hinweis, was als Nächstes zu tun ist. */
export function hint(s: GameState, q: Quest): string {
  const hood = q.hood !== undefined ? s.map.hoods[q.hood]?.name : '';
  switch (q.kind) {
    case 'jagd': return `Noch ${Math.max(0, q.count - q.progress)} ${TARGET_FACETS[q.facet!.slice(2)]?.label ?? 'Gegner'}.`;
    case 'finden': return hasQuestItem(s, q) ? `Bring es zu ${q.giver.name}.` : `Such im ${hood}.`;
    case 'liefern': return `Bring die Sachen zu ${q.giver.name}.`;
    case 'retten': return `Such im ${hood} und sprich die Person an.`;
    case 'boss': return `Besiege den Boss im ${hood}.`;
  }
}

function hasQuestItem(s: GameState, q: Quest) {
  return s.player.inventory.some((i) => i.questId === q.id) || s.player.hand?.questId === q.id;
}

function countOf(s: GameState, ids: string[]) {
  return s.player.inventory.filter((i) => ids.includes(i.baseId)).reduce((a, i) => a + (i.menge ?? 1), 0);
}

function consume(s: GameState, ids: string[], n: number) {
  for (const it of [...s.player.inventory]) {
    if (n <= 0) break;
    if (!ids.includes(it.baseId)) continue;
    const take = Math.min(it.menge ?? 1, n);
    n -= take;
    if ((it.menge ?? 1) - take > 0) it.menge = (it.menge ?? 1) - take;
    else s.player.inventory = s.player.inventory.filter((x) => x !== it);
  }
}

function complete(s: GameState, q: Quest, thanks?: string) {
  q.status = 'erledigt';
  q.progress = q.count;
  const r = q.reward;
  log(s, `AUFTRAG ERLEDIGT: ${q.title}. ${thanks ?? ''}`.trim(), 'system');
  giveItem(s, createGold(s, r.gold));
  const xp = gainXp(s, r.xp);
  log(s, `Belohnung: ${r.gold} Gold, ${xp} XP${r.box ? ' und eine Abenteurer-Box' : ''}.`, 'loot');
  if (r.box) s.player.boxes.push(createBox(s, 'abenteurer', s.floor >= 2 ? 'silber' : 'bronze'));
  toast(s, 'Auftrag erledigt', q.title, 'loot');
  // Ladenbesitzer machen danach Freundschaftspreise
  if (q.giver.kind === 'laden') {
    const room = s.map.rooms[Number(q.giver.ref)];
    if (room?.shop) {
      room.shop.mood = Math.min(150, room.shop.mood + 40);
      for (const o of room.shop.offers) o.price = Math.max(1, Math.round(o.price * 0.85));
      log(s, `${room.shop.keeper} gibt dir ab sofort 15 % Freundschaftsrabatt.`, 'dialog');
    }
  } else {
    const giver = crawlers(s).find((c) => c.uid === q.giver.ref);
    if (giver) giver.trust = Math.min(100, giver.trust + 40);
  }
  emit(s, { type: 'questDone', kind: q.kind, done: quests(s).filter((x) => x.status === 'erledigt').length });
}

function fail(s: GameState, q: Quest, why: string) {
  q.status = 'gescheitert';
  log(s, `AUFTRAG GESCHEITERT: ${q.title}. ${why}`, 'gefahr');
  emit(s, { type: 'questFailed', kind: q.kind });
}

/** Kann der Crawler diesen Auftrag gerade beim Auftraggeber abgeben? */
export function canTurnIn(s: GameState, q: Quest): boolean {
  if (q.status !== 'aktiv' || (q.kind !== 'finden' && q.kind !== 'liefern')) return false;
  if (q.kind === 'finden' && !hasQuestItem(s, q)) return false;
  if (q.kind === 'liefern' && countOf(s, q.itemIds ?? []) < q.count) return false;
  if (q.giver.kind === 'laden') return roomOf(s.map, s.player.pos)?.id === Number(q.giver.ref);
  const c = crawlers(s).find((x) => x.uid === q.giver.ref && x.alive);
  return !!c && chebyshev(c.pos, s.player.pos) <= 1;
}

export function turnIn(s: GameState, id: string): Res {
  const q = quests(s).find((x) => x.id === id);
  if (!q || !canTurnIn(s, q)) return { ok: false, message: 'Das kannst du hier noch nicht abgeben.' };
  if (q.kind === 'finden') {
    s.player.inventory = s.player.inventory.filter((i) => i.questId !== q.id);
    if (s.player.hand?.questId === q.id) s.player.hand = null;
  } else consume(s, q.itemIds ?? [], q.count);
  complete(s, q, R.pick(s, QUEST_THANKS));
  return { ok: true };
}

export function questsOnEvent(s: GameState, e: GameEvent) {
  if (e.type !== 'kill' || !s.quests?.length) return;
  for (const q of activeQuests(s)) {
    if (q.kind === 'jagd' && q.facet && targetFacets(s, e.monster).includes(q.facet)) {
      q.progress += 1;
      if (q.progress >= q.count) complete(s, q, `Die Nachricht erreicht ${q.giver.name}. Die Belohnung wird dir vom System gutgeschrieben.`);
    }
    if (q.kind === 'boss' && e.monster.rank === 'nachbarschaftsboss' && e.monster.hood === q.hood) {
      complete(s, q, `${q.giver.name} hat zugesehen. Die Belohnung kommt per Transportlicht.`);
    }
  }
}

/** Nach jedem Zug: Rettungen prüfen, verschwundene Auftraggeber erkennen. */
export function questsTick(s: GameState) {
  if (!s.quests?.length) return;
  for (const q of activeQuests(s)) {
    if (q.kind === 'retten') {
      const c = crawlers(s).find((x) => x.uid === q.targetUid);
      if (!c || !c.alive) {
        fail(s, q, 'Die Person hat es nicht geschafft.');
        continue;
      }
      if (chebyshev(c.pos, s.player.pos) <= 1) {
        c.personality = 'freundlich';
        c.trust = 90;
        c.met = true;
        log(s, `${c.name}: „Du … bist wegen mir gekommen? Danke. Ich gehe mit dir, wenn du mich lässt.“`, 'dialog');
        complete(s, q, `${c.name} ist gerettet.`);
      }
      continue;
    }
    if ((q.kind === 'finden' || q.kind === 'liefern') && q.giver.kind === 'crawler' && !crawlers(s).some((c) => c.uid === q.giver.ref && c.alive)) {
      fail(s, q, `${q.giver.name} lebt nicht mehr.`);
    }
  }
}

/** Beim Abstieg: offene Aufträge der alten Etage scheitern. */
export function questsOnDescend(s: GameState) {
  for (const q of quests(s)) {
    if (q.status === 'aktiv') fail(s, q, 'Die Etage ist Geschichte.');
    if (q.status === 'angebot') q.status = 'gescheitert';
  }
  s.player.inventory = s.player.inventory.filter((i) => !i.questId);
}
