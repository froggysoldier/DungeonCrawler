// Aufzeichnungs-Bot für den Godot-Vergleichstest. Spielt Partien in der
// TypeScript-Version und hält jede Aktion samt Kurzzustand fest. Die
// Godot-Tests spielen dieselben Aktionen nach und vergleichen.
import * as G from '../src/engine/game';
import { findPath } from '../src/engine/path';
import { furnitureAt } from '../src/engine/mapgen';
import { maxHp, throwables } from '../src/engine/player';
import { emptyMeta } from '../src/engine/meta';
import { isInSafeRoom, techniqueBlocker } from '../src/engine/combat';
import { chooseRaceAndClass, classOptions, useAbility } from '../src/engine/classes';
import { knowsSpell } from '../src/engine/magic';
import type { GameState, Pos, Technique } from '../src/engine/types';

type Action = { a: string; args: unknown[] };

const cheb = (a: Pos, b: Pos) => Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));
const center = (r: { x: number; y: number; w: number; h: number }) => ({ x: r.x + Math.floor(r.w / 2), y: r.y + Math.floor(r.h / 2) });

/** Kompakter Zustand für den Vergleich (Karte als Text statt riesiger Listen). */
export function snapshot(s: GameState): unknown {
  const c = JSON.parse(JSON.stringify(s));
  c.map.tiles = c.map.tiles.map((t: string) => ({ wall: '#', floor: '.', stairs: '>', door: '+', dooropen: "'" })[t]).join('');
  c.map.explored = c.map.explored.map((e: boolean) => (e ? '1' : '0')).join('');
  c.map.roomAt = c.map.roomAt.join(',');
  delete c.fx;
  delete c.sfx;
  return c;
}

const digest = (s: GameState) => [s.rng, s.turn, s.player.hp, s.player.pos.x, s.player.pos.y, s.monsters.length, s.logCounter ?? s.log.length, s.status];

export function makeReplay(seed: number, answers: Record<string, number>, steps: number, every: number) {
  const bot = { rng: seed * 7919 + 13 };
  const rnd = () => {
    bot.rng = (bot.rng + 0x6d2b79f5) | 0;
    let t = bot.rng;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const opts = { name: 'Bot', answers, seed, meta: emptyMeta() };
  const s = G.newGame(opts);
  const start = snapshot(s);
  const actions: Action[] = [];
  const digests: unknown[] = [];
  const checkpoints: Record<number, unknown> = {};
  const API = {
    moveStep: G.moveStep, attack: G.attack, wait: G.wait, pickup: G.pickup, useItem: G.useItem, equip: G.equip,
    openBox: G.openBox, sleep: G.sleep, descend: G.descend, cast: G.cast, defend: G.defend, closeDoor: G.closeDoor,
    chooseRaceAndClass, useAbility, talkCrawler: G.talkCrawler, inviteCrawler: G.inviteCrawler, toilet: G.toilet,
    buyOffer: G.buyOffer, allocateStat: G.allocateStat, craftItem: G.craftItem, answerTalkShow: G.answerTalkShow,
    // Nur für den Test: volle Lebenspunkte, damit die Partie spätere Etagen erreicht
    testHeal: (st: GameState) => {
      st.player.hp = maxHp(st);
      return { ok: true };
    },
  } as Record<string, (s: GameState, ...a: never[]) => { ok: boolean }>;
  const act = (a: string, ...args: unknown[]) => {
    const res = API[a](s, ...(args as never[]));
    actions.push({ a, args });
    digests.push(digest(s));
    if (actions.length % every === 0) checkpoints[actions.length] = snapshot(s);
    return res.ok;
  };

  const goTo = (target: Pos): boolean => {
    const lairs = new Set(s.monsters.filter((m) => m.homeRoom !== undefined).map((m) => m.homeRoom!));
    const targetRoom = s.map.roomAt[target.y * s.map.width + target.x];
    const path = findPath(s.map, s.player.pos, target, (x, y) => {
      const r = s.map.roomAt[y * s.map.width + x];
      if (r >= 0 && lairs.has(r) && r !== targetRoom) return false;
      if (furnitureAt(s.map, { x, y })) return false;
      return !s.monsters.some((m) => m.pos.x === x && m.pos.y === y);
    }, 8000, true);
    if (!path?.length) return false;
    return act('moveStep', path[0]);
  };
  const wander = () => {
    const p = s.player.pos;
    const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => ({ x: p.x + dx, y: p.y + dy }))
      .filter((q) => s.map.tiles[q.y * s.map.width + q.x] === 'floor' && !furnitureAt(s.map, q) && !s.monsters.some((m) => m.pos.x === q.x && m.pos.y === q.y));
    if (dirs.length && rnd() < 0.7) act('moveStep', dirs[Math.floor(rnd() * dirs.length)]);
    else act('wait');
  };

  const PARTS = ['faust', 'tritt', 'knie', 'ellbogen', 'kopf', 'waffe'] as const;
  const MOVES = ['normal', 'normal', 'sprung', 'stampfen', 'anlauf'] as const;
  const ZONES = [undefined, 'kopf', 'koerper', 'arme', 'beine'] as const;
  const fight = (): boolean => {
    const p = s.player;
    // Werfen auf Entfernung
    const far = s.monsters.filter((m) => m.aware && cheb(m.pos, p.pos) >= 2 && cheb(m.pos, p.pos) <= 5);
    if (far.length && throwables(s).length && rnd() < 0.15) {
      const t: Technique = { part: 'wurf', move: 'normal' };
      if (!techniqueBlocker(s, far[0], t)) return act('attack', far[0].uid, t);
    }
    if (far.length && knowsSpell(s, 'geschoss') && (p.mp ?? 0) >= 3 && rnd() < 0.15) {
      if (act('cast', 'geschoss', { targetUid: far[0].uid, mana: 3 })) return true;
    }
    const adj = s.monsters.filter((m) => cheb(m.pos, p.pos) <= 1).sort((a, b) => a.hp - b.hp)[0];
    if (!adj) return false;
    if (rnd() < 0.05) return act('defend');
    for (let i = 0; i < (rnd() < 0.3 ? 6 : 0); i++) {
      const t: Technique = { part: PARTS[Math.floor(rnd() * PARTS.length)], move: MOVES[Math.floor(rnd() * MOVES.length)] };
      const z = ZONES[Math.floor(rnd() * ZONES.length)];
      if (z) t.zone = z;
      if (!techniqueBlocker(s, adj, t)) return act('attack', adj.uid, t);
    }
    for (const t of [{ part: 'tritt', move: 'stampfen' }, { part: 'tritt', move: 'normal' }, { part: 'faust', move: 'normal' }] as Technique[]) {
      if (!techniqueBlocker(s, adj, t)) return act('attack', adj.uid, t);
    }
    return act('wait');
  };

  let phase: 'guild' | 'clear' | 'stairs' = 'guild';
  let floor = 1;
  let guard = 0;
  while (s.status === 'playing' && actions.length < steps && guard++ < steps * 4) {
    const p = s.player;
    if (s.floor !== floor) {
      floor = s.floor;
      phase = 'clear';
    }
    if (s.talkShow && !s.talkShow.done) {
      act('answerTalkShow', Math.floor(rnd() * 3));
      continue;
    }
    if (s.pendingSelection) {
      const opts2 = classOptions(s);
      act('chooseRaceAndClass', 'mensch', opts2[Math.floor(rnd() * Math.min(3, opts2.length))].klass.id);
      continue;
    }
    if (p.statPoints > 0 && s.unlocks.includes('stats')) {
      act('allocateStat', (['str', 'ges', 'kon', 'int', 'cha'] as const)[Math.floor(rnd() * 5)]);
      continue;
    }
    if (p.klass && !p.abilityCooldown && s.monsters.some((m) => cheb(m.pos, p.pos) <= 2) && rnd() < 0.3) {
      if (act('useAbility', { part: 'tritt', move: 'normal' })) continue;
    }
    const neighborCrawler = (s.crawlers ?? []).find((c) => c.alive && !c.party && cheb(c.pos, p.pos) <= 1);
    if (neighborCrawler && !neighborCrawler.met && rnd() < 0.5) {
      act(rnd() < 0.5 ? 'talkCrawler' : 'inviteCrawler', neighborCrawler.uid);
      continue;
    }
    if (p.hp < maxHp(s) * 0.25) {
      act('testHeal');
      continue;
    }
    // Blase: rechtzeitig zur Toilette (hineinlaufen benutzt sie)
    if ((p.blase ?? 0) >= 60) {
      const safes = s.map.rooms.filter((r) => r.kind === 'safe' && r.furniture?.some((f) => f.kind === 'toilette'))
        .sort((a, b) => cheb(center(a), p.pos) - cheb(center(b), p.pos));
      const wc = safes[0]?.furniture?.find((f) => f.kind === 'toilette');
      if (wc) {
        if (cheb(wc.pos, p.pos) === 1 && (Math.abs(wc.pos.x - p.pos.x) + Math.abs(wc.pos.y - p.pos.y)) === 1) {
          act('moveStep', wc.pos);
          continue;
        }
        const spots = [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([dx, dy]) => ({ x: wc.pos.x + dx, y: wc.pos.y + dy }))
          .filter((q) => s.map.tiles[q.y * s.map.width + q.x] === 'floor' && !furnitureAt(s.map, q));
        if (spots.length && goTo(spots[0])) continue;
      }
    }
    const danger = s.monsters.some((m) => m.aware && cheb(m.pos, p.pos) <= 3 && m.level >= p.level + 3);
    if (p.hp < maxHp(s) * 0.5 || (danger && p.hp < maxHp(s) * 0.8)) {
      const pot = p.inventory.find((i) => i.kind === 'verbrauch' && (i.effekt?.heal || i.effekt?.healPct) && !(i.baseId.includes('trank') && (p.potionCooldown ?? 0) > 0));
      if (pot) {
        act('useItem', pot.uid);
        continue;
      }
      if (knowsSpell(s, 'heilen') && (p.mp ?? 0) >= 3 && act('cast', 'heilen', {})) continue;
      const safe = s.map.rooms.filter((r) => r.kind === 'safe').sort((a, b) => cheb(center(a), p.pos) - cheb(center(b), p.pos))[0];
      if (safe && !isInSafeRoom(s, p.pos)) {
        if (!danger && fight()) continue;
        if (!goTo(center(safe))) wander();
        continue;
      }
      if (safe) {
        if (p.boxes.length && s.unlocks.includes('inventar')) {
          act('openBox', p.boxes[0].uid);
          continue;
        }
        const gear = p.inventory.find((i) => i.kind === 'ausruestung');
        if (gear && rnd() < 0.7) {
          act('equip', gear.uid);
          continue;
        }
        if ((p.blase ?? 0) > 20) {
          act('toilet');
          continue;
        }
        if (!act('sleep')) act('wait');
        continue;
      }
    }
    if (fight()) continue;
    const last = actions[actions.length - 1];
    if (s.items.some((e) => e.pos.x === p.pos.x && e.pos.y === p.pos.y) && last?.a !== 'pickup') {
      act('pickup');
      continue;
    }
    if (s.unlocks.includes('inventar') && rnd() < 0.05) {
      const it = p.inventory[Math.floor(rnd() * p.inventory.length)];
      if (it?.kind === 'ausruestung') {
        act('equip', it.uid);
        continue;
      }
      if (it?.kind === 'verbrauch' || it?.kind === 'buch') {
        act('useItem', it.uid);
        continue;
      }
    }
    if (s.unlocks.includes('inventar') && rnd() < 0.02) {
      act('craftItem', ['verband', 'brandflasche', 'nagelbombe', 'stachelfalle'][Math.floor(rnd() * 4)]);
      continue;
    }
    if (phase === 'guild') {
      if (s.unlocks.includes('inventar')) {
        phase = 'clear';
        continue;
      }
      const g = s.map.rooms.filter((r) => r.kind === 'guild').sort((a, b) => cheb(center(a), p.pos) - cheb(center(b), p.pos))[0];
      if (!goTo(center(g))) wander();
      continue;
    }
    if (phase === 'clear') {
      const targets = s.monsters
        .filter((m) => (p.level < 5 ? m.rank === 'normal' || m.rank === 'elite' : m.rank !== 'boroughboss') && m.level <= p.level + 1)
        .sort((a, b) => cheb(a.pos, p.pos) - cheb(b.pos, p.pos));
      const t = targets[0];
      if (!t || s.turn - s.floorStartTurn > 900) {
        phase = 'stairs';
        continue;
      }
      if (!goTo(t.pos)) wander();
      continue;
    }
    const stairs: Pos[] = [];
    s.map.tiles.forEach((tile, i) => tile === 'stairs' && stairs.push({ x: i % s.map.width, y: Math.floor(i / s.map.width) }));
    stairs.sort((a, b) => cheb(a, p.pos) - cheb(b, p.pos));
    if (stairs.some((q) => q.x === p.pos.x && q.y === p.pos.y)) {
      act('descend', { ghosts: [] });
      continue;
    }
    if (!goTo(stairs[0])) wander();
  }
  checkpoints[actions.length] = snapshot(s);
  return { seed, opts: { name: opts.name, answers, seed }, start, actions, digests, checkpoints };
}

/** Die Replays für den Godot-Test. */
/** Sucht Seeds, die weit kommen (nur für die Auswahl). */
export function probe(seeds: number[], steps: number) {
  return seeds.map((seed) => {
    const r = makeReplay(seed, ANSWERS[seed % ANSWERS.length], steps, 1e9);
    const last = r.checkpoints[r.actions.length] as { floor: number; status: string; turn: number; deathCause?: string; player: { level: number } };
    const kinds: Record<string, number> = {};
    for (const a of r.actions.slice(-200)) kinds[a.a] = (kinds[a.a] ?? 0) + 1;
    return { seed, actions: r.actions.length, floor: last.floor, turn: last.turn, level: last.player.level, cause: last.deathCause ?? last.status, tail: JSON.stringify(kinds) };
  });
}

const ANSWERS: Record<string, number>[] = [
  { beruf: 1 },
  { beruf: 5, sport: 1, hobbysport: 1, kampfsport: 3, haustier: 0, ort: 0, hand: 1, kleidung: 3, schuhe: 2, angst: 1, laster: 2, glueck: 0, alter: 2, charakter: 1 },
  { beruf: 7, it: 1, sozial: 2, haustier: 1, ort: 1, hand: 3, kleidung: 0, hose: 1, schuhe: 4, extra: 2, angst: 3, laster: 4, konflikt: 4, augen: 0 },
];

export function replays() {
  return [
    makeReplay(1, ANSWERS[1], 3500, 700),
    makeReplay(5, ANSWERS[2], 3500, 700),
    makeReplay(8, ANSWERS[2], 400, 100),
  ];
}

/**
 * Vergleichswerte für die Oberflächen-Hilfen: spielt eine aufgezeichnete
 * Partie nach und hält alle `every` Aktionen fest, was die Anzeige berechnet.
 */
export async function uiChecks(r: ReturnType<typeof makeReplay>, every: number) {
  const { nextGoals } = await import('../src/data/achievement_families');
  const { formatTime } = await import('../src/ui/dom');
  const { hash, roomMaterial } = await import('../src/ui/render');
  const { describeBonuses } = await import('../src/engine/bonuses');
  const { describeCrawler, talkableCrawlers } = await import('../src/engine/crawlers');
  const { disarmableTraps } = await import('../src/engine/traps');
  const { sponsorStates } = await import('../src/engine/sponsors');
  const { petFormName } = await import('../src/engine/petevo');
  const { skillEffectText } = await import('../src/engine/skills');
  const { SKILL_BY_ID } = await import('../src/data/skills');
  const s = G.newGame({ ...r.opts, meta: emptyMeta() });
  const API = {
    moveStep: G.moveStep, attack: G.attack, wait: G.wait, pickup: G.pickup, useItem: G.useItem, equip: G.equip,
    openBox: G.openBox, sleep: G.sleep, descend: G.descend, cast: G.cast, defend: G.defend, closeDoor: G.closeDoor,
    chooseRaceAndClass, useAbility, talkCrawler: G.talkCrawler, inviteCrawler: G.inviteCrawler, toilet: G.toilet,
    buyOffer: G.buyOffer, allocateStat: G.allocateStat, craftItem: G.craftItem, answerTalkShow: G.answerTalkShow,
    testHeal: (st: GameState) => {
      st.player.hp = maxHp(st);
      return { ok: true };
    },
  } as Record<string, (s: GameState, ...a: never[]) => { ok: boolean }>;
  const out: unknown[] = [];
  const record = (step: number) => {
    const items = [...s.player.inventory, ...Object.values(s.player.equipment).filter(Boolean)];
    out.push({
      step,
      time: formatTime(s.turn),
      goals: nextGoals(s),
      materials: s.map.rooms.map((room) => roomMaterial(room)),
      bonuses: items.map((it) => describeBonuses(it!.bonuses)),
      crawlers: (s.crawlers ?? []).map((c) => describeCrawler(c)),
      talkable: talkableCrawlers(s).map((c) => c.uid),
      traps: disarmableTraps(s).map((t) => t.uid),
      sponsors: sponsorStates(s).map((x) => `${x.id}:${x.status}`),
      pet: s.player.pet ? petFormName(s.player.pet) : null,
      skills: s.player.skills.map((k) => [skillEffectText(SKILL_BY_ID[k.id], k.level), skillEffectText(SKILL_BY_ID[k.id], k.level + 1)]),
    });
  };
  record(0);
  r.actions.forEach((a, i) => {
    API[a.a](s, ...(a.args as never[]));
    if ((i + 1) % every === 0 || i === r.actions.length - 1) record(i + 1);
  });
  const hashes: number[] = [];
  for (let y = -3; y < 60; y += 7) for (let x = -2; x < 90; x += 11) for (const salt of [0, 3, 5, 6, 41, 50, 99]) hashes.push(hash(x, y, salt));
  return { seed: r.seed, every, checks: out, hashes, times: [0, 1, 19, 20, 479, 480, 481, 2399, 12345].map((t) => formatTime(t)) };
}
