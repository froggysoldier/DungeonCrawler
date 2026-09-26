import {
  MOVE_PLURAL, PART_BOX, PART_PLURAL, PATTERN_COMMENTS, SELF_FACETS, SKILL_UNLOCK_HITS, STAGES, STAGE_NUMERALS,
  TARGET_FACETS, type FacetDef,
} from '../data/facets';
import { MONSTERS } from '../data/monsters';
import { BOX_TIERS, BOX_TIER_NAMES, BOX_TYPE_NAMES } from '../data/world';
import { chebyshev } from './fov';
import { createBox } from './items';
import { log, toast } from './log';
import { sound } from './fx';
import { roomOf } from './mapgen';
import { currentWeapon, maxHp } from './player';
import * as R from './rng';
import type {
  AttackMove, AttackPart, BoxType, Chronicle, DynSkill, GameEvent, GameState, Monster, MonsterAbility, Technique,
} from './types';

/**
 * Der Beobachter: Er zeichnet jede Aktion mit ihrem vollen Kontext auf,
 * zählt, welche Merkmals-Kombinationen wie oft vorkommen, und leitet daraus
 * dynamisch Achievements und maßgeschneiderte Skills ab. Es gibt keine feste
 * Liste – was belohnt wird, ergibt sich aus dem, was tatsächlich passiert.
 */

const ABILITY_FACET: Record<MonsterAbility, string> = {
  gift: 'giftig', explodiert: 'explosiv', diebisch: 'diebisch', rufer: 'rufer',
  regeneriert: 'regeneriert', schnell: 'schnell', fliegend: 'fliegend', gepanzert: 'gepanzert',
};

const PART_WEIGHT: Record<string, number> = {
  zauber: 0.5, falle: 1.5, bombe: 1, faust: 0, tritt: 0, knie: 0.5, ellbogen: 0.5, kopf: 1, waffe: 0, wurf: 0.5 };
const MOVE_WEIGHT: Record<AttackMove, number> = { normal: 0, sprung: 1, stampfen: 1, anlauf: 1 };

function chronicle(s: GameState): Chronicle {
  s.chronicle ??= { counts: {}, stages: {}, lastAward: -99 };
  return s.chronicle;
}

// ================================================================ Facetten erkennen

/** Merkmale des Ziels, VOR dem Angriff erfasst. */
export function targetFacets(s: GameState, m: Monster): string[] {
  const out = new Set<string>();
  for (const tag of monsterTags(m.defId)) if (TARGET_FACETS[tag]) out.add(`z:${tag}`);
  if (m.size === 'winzig' || m.size === 'gross' || m.size === 'riesig') out.add(`z:${m.size}`);
  for (const a of m.abilities ?? []) out.add(`z:${ABILITY_FACET[a]}`);
  if (m.behavior === 'ranged' || m.range) out.add('z:fernkampf');
  if (m.behavior === 'coward') out.add('z:feigling');
  if (m.behavior === 'stationary') out.add('z:lauerer');
  if (m.rank === 'elite') out.add('z:elite');
  if (m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss') out.add('z:boss');
  if (m.rank === 'geist') out.add('z:geistcrawler');
  if (m.downed > 0) out.add('z:liegend');
  if (!m.aware) out.add('z:ahnungslos');
  if (m.asleep) out.add('z:schlafend');
  if (m.fleeing) out.add('z:fliehend');
  const diff = m.level - s.player.level;
  if (diff >= 3) out.add('z:staerker');
  if (diff <= -3) out.add('z:schwaecher');
  return [...out];
}

const MONSTER_TAGS: Record<string, string[]> = Object.fromEntries(MONSTERS.map((m) => [m.id, m.tags ?? []]));
const monsterTags = (defId: string) => MONSTER_TAGS[defId] ?? [];

/** Eigener Zustand im Moment der Aktion. */
export function selfFacets(s: GameState): string[] {
  const p = s.player;
  const out: string[] = [];
  const mh = maxHp(s);
  if (p.hp < mh * 0.2) out.push('i:fasttot');
  else if (p.hp < mh * 0.5) out.push('i:verletzt');
  if (p.buffs.some((b) => b.name === 'Vergiftet')) out.push('i:vergiftet');
  if (p.buffs.some((b) => b.name === 'Mut angetrunken')) out.push('i:angetrunken');
  if (p.buffs.some((b) => b.name === 'Wutanfall' || b.name === 'Rasende Wut')) out.push('i:wuetend');
  if (p.ausdauer <= 2) out.push('i:erschoepft');
  if (!p.equipment.fuesse) out.push('i:barfuss');
  if (!p.equipment.brust && !p.equipment.beine) out.push('i:nackt');
  if (p.equipment.brust?.baseId === 'bademantel') out.push('i:bademantel');
  if (s.monsters.filter((m) => chebyshev(m.pos, p.pos) <= 1).length >= 3) out.push('i:umzingelt');
  if (p.pet?.alive && chebyshev(p.pet.pos, p.pos) <= 2) out.push('i:haustier');
  if (s.collapseAt - s.turn <= 20) out.push('i:letztestunde');
  if (!currentWeapon(s)) out.push('i:unbewaffnet');
  if (!roomOf(s.map, p.pos)) out.push('i:im_gang');
  return out;
}

/** Alle Facetten eines Angriffs: Technik, Ausführung, Ziel, Zustand, Ort. */
export function attackFacets(s: GameState, target: Monster, t: Technique): string[] {
  const out = [`t:${t.part}`];
  if (t.move !== 'normal') out.push(`m:${t.move}`);
  out.push(...targetFacets(s, target), ...selfFacets(s));
  const room = roomOf(s.map, s.player.pos);
  if (room && room.kind !== 'boss' && room.kind !== 'arena') out.push(`o:${room.name}`);
  return out;
}

// ================================================================ Beschriftung

function facetDef(f: string): FacetDef | null {
  const [kind, id] = f.split(':') as [string, string];
  if (kind === 'z') return TARGET_FACETS[id] ?? null;
  if (kind === 'i') return SELF_FACETS[id] ?? null;
  return null;
}

function facetWeight(f: string): number {
  const [kind, id] = f.split(':');
  if (kind === 't') return PART_WEIGHT[id as AttackPart] ?? 0;
  if (kind === 'm') return MOVE_WEIGHT[id as AttackMove] ?? 0;
  if (kind === 'o') return 0.5;
  return facetDef(f)?.weight ?? 0;
}

const cap = (x: string) => x.charAt(0).toUpperCase() + x.slice(1);

function techLabel(fs: string[]): string | null {
  const m = fs.find((f) => f.startsWith('m:'));
  if (m) return MOVE_PLURAL[m.slice(2) as Exclude<AttackMove, 'normal'>];
  const t = fs.find((f) => f.startsWith('t:'));
  return t ? PART_PLURAL[t.slice(2) as AttackPart] : null;
}

function describeCombo(fs: string[]) {
  const tech = techLabel(fs);
  const z = fs.find((f) => f.startsWith('z:'));
  const i = fs.find((f) => f.startsWith('i:'));
  const o = fs.find((f) => f.startsWith('o:'));
  const zDef = z ? facetDef(z) : null;
  const iDef = i ? facetDef(i) : null;
  const zName = zDef ? (zDef.short ?? cap(zDef.label)) : null;
  const iName = iDef ? (iDef.short ?? cap(iDef.label)) : null;
  let name: string;
  if (o) name = `Revier: ${o.slice(2)}`;
  else if (tech && zName && iName) name = `${iName}: ${tech} gegen ${zName}`;
  else if (tech && zName) name = `${tech} gegen ${zName}`;
  else if (tech && iName) name = `${iName}: ${tech}`;
  else if (zName && iName) name = `${iName}: Siege gegen ${zName}`;
  else if (zName) name = `Jagd auf ${zName}`;
  else name = tech ?? 'Unbekanntes Muster';
  return { name, tech, zLabel: zDef?.label, iLabel: iDef?.label, place: o?.slice(2), iDef };
}

// ================================================================ Aufzeichnen

function bump(c: Chronicle, key: string): number {
  c.counts[key] = (c.counts[key] ?? 0) + 1;
  return c.counts[key];
}

/** Welche Kombinationen einer Aktion gezählt werden. */
function combos(fs: string[]): string[][] {
  const tech = fs.filter((f) => f.startsWith('t:') || f.startsWith('m:'));
  const z = fs.filter((f) => f.startsWith('z:'));
  const i = fs.filter((f) => f.startsWith('i:') && f !== 'i:unbewaffnet');
  const o = fs.filter((f) => f.startsWith('o:'));
  const out: string[][] = [];
  for (const zz of z) out.push([zz]);
  for (const oo of o) out.push([oo]);
  for (const t of tech) {
    for (const zz of z) out.push([t, zz]);
    for (const ii of i) out.push([t, ii]);
  }
  for (const zz of z) for (const ii of i) out.push([zz, ii]);
  const main = tech.find((t) => t.startsWith('m:')) ?? tech[0];
  if (main) for (const zz of z) for (const ii of i) out.push([main, zz, ii]);
  return out;
}

export function observe(s: GameState, e: GameEvent) {
  if (s.status !== 'playing') return;
  const c = chronicle(s);
  switch (e.type) {
    case 'kill': {
      if (!e.facets || e.byPet) return;
      for (const f of e.facets) bump(c, `total|kill|${f}`);
      const keys = combos(e.facets).map((fs) => ({ fs, key: `kill|${[...fs].sort().join('+')}` }));
      for (const k of keys) bump(c, k.key);
      awardPatterns(s, keys);
      trainDynSkills(s, e.facets, 2);
      break;
    }
    case 'attack': {
      if (!e.facets || !e.hit) return;
      const tech = e.facets.filter((f) => f.startsWith('t:') || f.startsWith('m:'));
      for (const t of tech) bump(c, `total|hit|${t}`);
      const ctx = e.facets.filter((f) => (f.startsWith('z:') || f.startsWith('i:')) && facetDef(f)?.skill);
      for (const t of tech) for (const f of ctx) maybeUnlockSkill(s, 'angriff', t, f, bump(c, `hit|${t}+${f}`));
      trainDynSkills(s, e.facets, 1);
      break;
    }
    case 'dodged':
      for (const f of (e.facets ?? []).filter((x) => facetDef(x)?.skill)) maybeUnlockSkill(s, 'ausweichen', null, f, bump(c, `dodge|${f}`));
      break;
    case 'damageTaken':
      for (const f of (e.facets ?? []).filter((x) => facetDef(x)?.skill)) maybeUnlockSkill(s, 'abhaertung', null, f, bump(c, `hurt|${f}`));
      break;
    default:
      break;
  }
}

// ================================================================ Dynamische Achievements

function awardPatterns(s: GameState, keys: { fs: string[]; key: string }[]) {
  const c = chronicle(s);
  let best: { fs: string[]; key: string; stage: number; score: number } | null = null;
  for (const k of keys) {
    const next = c.stages[k.key] ?? 0;
    // Höchste Stufe, die die Anzahl bereits erreicht hat
    let stage = -1;
    for (let i = 0; i < STAGES.length; i++) if (c.counts[k.key] >= STAGES[i]) stage = i;
    if (stage < next) continue;
    const base = k.fs.reduce((a, f) => a + facetWeight(f), 0) + (k.fs.length - 1) * 0.5;
    const score = base + stage * 1.3;
    // Gewöhnliches wird erst bei höheren Zahlen belohnt, Ungewöhnliches sofort
    if (score < 3) continue;
    if (!best || score > best.score) best = { ...k, stage, score };
  }
  if (!best) return;
  // Nicht zu viele auf einmal: Pause zwischen Mustern, außer bei sehr Besonderem
  if (s.turn - c.lastAward < 10 && best.score < 5.5) return;
  c.stages[best.key] = best.stage + 1;
  // Teilmuster derselben Situation gelten als mit abgedeckt – keine doppelten Belohnungen
  for (const k of keys) {
    if (k.key === best.key) continue;
    const covered = k.fs.every((f) => best!.fs.includes(f)) || best.fs.every((f) => k.fs.includes(f));
    if (covered) c.stages[k.key] = Math.max(c.stages[k.key] ?? 0, best.stage + 1);
  }
  c.lastAward = s.turn;
  grantPattern(s, best.fs, best.stage, best.score, c.counts[best.key]);
}

function grantPattern(s: GameState, fs: string[], stage: number, score: number, count: number) {
  const d = describeCombo(fs);
  const id = `muster:${[...fs].sort().join('+')}:${stage}`;
  const name = `${d.name} ${STAGE_NUMERALS[stage]}`;
  const details = [
    `Getötet: ${count} × ${d.zLabel ?? 'Gegner'}`,
    d.tech ? `Technik: ${d.tech}` : null,
    d.iLabel ? `Zustand: ${d.iLabel}` : null,
    d.place ? `Ort: ${d.place}` : null,
  ].filter(Boolean);
  const description = details.join(' · ');
  const comment = R.pick(s, PATTERN_COMMENTS).replace('{zahl}', String(count)).replace('{was}', d.name);
  const first = !s.firstEver.includes(id);
  const tierIdx = Math.max(0, Math.min(BOX_TIERS.length - 1, Math.floor(score / 2.2) + (first ? 1 : 0) - 1));
  const tier = BOX_TIERS[tierIdx];
  const t = fs.find((f) => f.startsWith('t:'))?.slice(2) as AttackPart | undefined;
  const box: BoxType = d.iDef?.box ?? (fs.includes('z:boss') ? 'boss' : t ? PART_BOX[t] : 'abenteurer');
  s.player.boxes.push(createBox(s, box, tier));
  s.achievements.push(id);
  (s.dynAchievements ??= []).push({ id, name, description, comment, tier, box, turn: s.turn, floor: s.floor });
  sound(s, { kind: 'achievement', tier });
  log(s, `DIE SYSTEMSTIMME HAT ETWAS BEMERKT: ${name} – ${description}`, 'achievement');
  log(s, comment, 'achievement');
  log(s, `Belohnung: ${BOX_TIER_NAMES[tier]} ${BOX_TYPE_NAMES[box]}.${first ? ' Zum ersten Mal in deiner Karriere – Box-Stufe erhöht!' : ''}`, 'loot');
  toast(s, name, description, 'achievement');
}

// ================================================================ Dynamische Skills

const SKILL_THRESHOLDS = { angriff: SKILL_UNLOCK_HITS, ausweichen: 10, abhaertung: 15 };

function skillName(kind: DynSkill['kind'], tech: string | null, facet: string): { name: string; description: string } {
  const def = facetDef(facet)!;
  const label = def.short ?? cap(def.label);
  if (kind === 'ausweichen') {
    return { name: `Ausweichen gegen ${label}`, description: `+1,5 % Ausweichen pro Stufe gegen ${def.label}.` };
  }
  if (kind === 'abhaertung') {
    return { name: `Abgehärtet gegen ${label}`, description: `−5 % erlittener Schaden pro Stufe durch ${def.label} (max. 40 %).` };
  }
  const t = techLabel([tech!])!;
  if (facet.startsWith('i:')) {
    return { name: `${label}: ${t}`, description: `+6 % Schaden und +1,5 % Treffer pro Stufe für ${t}, wenn du ${def.label} bist.` };
  }
  return { name: `${t} gegen ${label}`, description: `+6 % Schaden und +1,5 % Treffer pro Stufe für ${t} gegen ${def.label}.` };
}

function maybeUnlockSkill(s: GameState, kind: DynSkill['kind'], tech: string | null, facet: string, count: number) {
  if (count < SKILL_THRESHOLDS[kind]) return;
  const key = `${kind}|${tech ?? ''}|${facet}`;
  const p = s.player;
  p.dynSkills ??= [];
  if (p.dynSkills.some((k) => k.key === key)) return;
  const { name, description } = skillName(kind, tech, facet);
  const skill: DynSkill = { key, name, description, kind, facet, level: 1, xp: 0 };
  if (tech?.startsWith('t:')) skill.part = tech.slice(2) as AttackPart;
  if (tech?.startsWith('m:')) skill.move = tech.slice(2) as AttackMove;
  p.dynSkills.push(skill);
  log(s, `NEUER SKILL ENTDECKT: ${name}. ${description}`, 'system');
  toast(s, `Neuer Skill: ${name}`, description, 'skill');
}

export const dynXpNeeded = (level: number) => 8 + level * 6;
const DYN_MAX = 10;

function matches(k: DynSkill, facets: string[], part?: AttackPart, move?: AttackMove): boolean {
  if (!facets.includes(k.facet)) return false;
  if (k.part && k.part !== part) return false;
  if (k.move && k.move !== move) return false;
  return true;
}

function trainDynSkills(s: GameState, facets: string[], amount: number) {
  const part = facets.find((f) => f.startsWith('t:'))?.slice(2) as AttackPart | undefined;
  const move = (facets.find((f) => f.startsWith('m:'))?.slice(2) ?? 'normal') as AttackMove;
  for (const k of s.player.dynSkills ?? []) {
    if (k.kind !== 'angriff' || !matches(k, facets, part, move) || k.level >= DYN_MAX) continue;
    k.xp += amount;
    while (k.level < DYN_MAX && k.xp >= dynXpNeeded(k.level)) {
      k.xp -= dynXpNeeded(k.level);
      k.level += 1;
      log(s, `Skill verbessert: ${k.name} ist jetzt Stufe ${k.level}.`, 'system');
    }
  }
}

/** Angriffsboni aus dynamischen Skills für einen konkreten Angriff. */
export function dynAttackBonus(s: GameState, facets: string[], t: Technique): { dmg: number; hit: number } {
  let dmg = 0;
  let hit = 0;
  for (const k of s.player.dynSkills ?? []) {
    if (k.kind !== 'angriff' || !matches(k, facets, t.part, t.move)) continue;
    dmg += 6 * k.level;
    hit += 1.5 * k.level;
  }
  return { dmg, hit };
}

/** Verteidigungsboni gegen eine konkrete Quelle. */
export function dynDefenseBonus(s: GameState, sourceFacets: string[]): { ausweichen: number; reduktion: number } {
  let ausweichen = 0;
  let reduktion = 0;
  for (const k of s.player.dynSkills ?? []) {
    if (!sourceFacets.includes(k.facet)) continue;
    if (k.kind === 'ausweichen') ausweichen += 1.5 * k.level;
    if (k.kind === 'abhaertung') reduktion += 5 * k.level;
  }
  return { ausweichen, reduktion: Math.min(40, reduktion) };
}

/** Defensive Skills leveln, wenn sie greifen. */
export function trainDefense(s: GameState, sourceFacets: string[], kind: 'ausweichen' | 'abhaertung') {
  for (const k of s.player.dynSkills ?? []) {
    if (k.kind !== kind || !sourceFacets.includes(k.facet) || k.level >= DYN_MAX) continue;
    k.xp += 1;
    if (k.xp >= dynXpNeeded(k.level)) {
      k.xp -= dynXpNeeded(k.level);
      k.level += 1;
      log(s, `Skill verbessert: ${k.name} ist jetzt Stufe ${k.level}.`, 'system');
    }
  }
}

/** Fortschritt zu noch nicht entdeckten Skills (für die Anzeige „Du spürst Fortschritt …“). */
export function skillHints(s: GameState): { name: string; progress: number; needed: number }[] {
  const c = s.chronicle;
  if (!c) return [];
  const owned = new Set((s.player.dynSkills ?? []).map((k) => k.key));
  const out: { name: string; progress: number; needed: number }[] = [];
  for (const [key, n] of Object.entries(c.counts)) {
    const [kind, rest] = key.split('|');
    let skillKind: DynSkill['kind'] | null = null;
    let tech: string | null = null;
    let facet: string;
    if (kind === 'hit') {
      skillKind = 'angriff';
      [tech, facet] = rest.split('+');
    } else if (kind === 'dodge') {
      skillKind = 'ausweichen';
      facet = rest;
    } else if (kind === 'hurt') {
      skillKind = 'abhaertung';
      facet = rest;
    } else continue;
    if (!facetDef(facet)?.skill) continue;
    if (owned.has(`${skillKind}|${tech ?? ''}|${facet}`)) continue;
    const needed = SKILL_THRESHOLDS[skillKind];
    if (n < needed * 0.4) continue;
    out.push({ name: skillName(skillKind, tech, facet).name, progress: n, needed });
  }
  return out.sort((a, b) => b.progress / b.needed - a.progress / a.needed).slice(0, 8);
}
