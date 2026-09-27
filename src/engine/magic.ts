import { SPELLS, SPELL_BY_ID, SPELL_MAX_LEVEL, spellXpNeeded } from '../data/spells';
import { cure, has } from './abilities';
import { isInSafeRoom, killMonster } from './combat';
import { emit } from './events';
import { FX_COLORS, floatText, shot } from './fx';
import { chebyshev, hasLineOfSight } from './fov';
import { itemName, nameOf } from './identify';
import { uid } from './items';
import { log } from './log';
import { idx, isWalkable } from './mapgen';
import { handleLethal } from './death';
import { targetFacets, selfFacets } from './observer';
import { effectiveStats, maxHp, totalBonuses } from './player';
import * as R from './rng';
import type { GameState, Item, Monster, Pos, Rarity } from './types';

/** Max. Mana: entspricht der Intelligenz (plus Boni). */
export function maxMp(s: GameState, b = totalBonuses(s)): number {
  return Math.max(1, effectiveStats(s, b).int + (b.maxMp ?? 0));
}

export function knowsSpell(s: GameState, id: string): boolean {
  return (s.player.spells ?? []).some((k) => k.id === id);
}

export function learnSpell(s: GameState, id: string, silent = false): boolean {
  const p = s.player;
  p.spells ??= [];
  if (knowsSpell(s, id)) return false;
  p.spells.push({ id, level: 1, xp: 0 });
  if (!silent) log(s, `ZAUBER GELERNT: ${SPELL_BY_ID[id].name}. ${SPELL_BY_ID[id].description}`, 'system');
  return true;
}

export function createTome(s: GameState, spellId: string): Item {
  const def = SPELL_BY_ID[spellId];
  return {
    uid: uid(s),
    baseId: `buch_${spellId}`,
    name: `Zauberbuch: ${def.name}`,
    kind: 'buch',
    rarity: def.rarity as Rarity,
    spell: spellId,
    flavor: `${def.flavor} Lesen verbraucht das Buch und lehrt dich den Zauber.`,
    wert: { gewoehnlich: 10, ungewoehnlich: 25, selten: 60, episch: 150, legendaer: 400 }[def.rarity],
  };
}

/** Zufälliges Zauberbuch bis zu einer Seltenheit. */
export function randomTome(s: GameState, maxRarity: Rarity): Item {
  const order = ['gewoehnlich', 'ungewoehnlich', 'selten', 'episch', 'legendaer', 'himmlisch'];
  const pool = SPELLS.filter((sp) => sp.id !== 'heilen' && order.indexOf(sp.rarity) <= order.indexOf(maxRarity));
  return createTome(s, R.pick(s, pool.length ? pool : SPELLS).id);
}

export function readTome(s: GameState, it: Item): { ok: boolean; message?: string } {
  if (!it.spell) return { ok: false, message: 'Das ist kein Zauberbuch.' };
  if (knowsSpell(s, it.spell)) return { ok: false, message: 'Diesen Zauber kennst du schon.' };
  learnSpell(s, it.spell);
  log(s, `Du liest ${itemName(s, it)}. Die Seiten zerfallen zu Staub, der Zauber bleibt in deinem Kopf.`, 'info');
  return { ok: true };
}

export function spellCost(id: string, chosen?: number): number {
  const c = SPELL_BY_ID[id].cost;
  if (typeof c === 'number') return c;
  return Math.max(c[0], Math.min(c[1], chosen ?? c[0]));
}

export interface CastOptions {
  targetUid?: string;
  pos?: Pos;
  mana?: number;
}

function spellLevel(s: GameState, id: string) {
  return s.player.spells?.find((k) => k.id === id)?.level ?? 1;
}

function trainSpell(s: GameState, id: string, amount: number) {
  const st = s.player.spells?.find((k) => k.id === id);
  if (!st || st.level >= SPELL_MAX_LEVEL) return;
  st.xp += amount;
  while (st.level < SPELL_MAX_LEVEL && st.xp >= spellXpNeeded(st.level)) {
    st.xp -= spellXpNeeded(st.level);
    st.level += 1;
    log(s, `Zauber verbessert: ${SPELL_BY_ID[id].name} ist jetzt Stufe ${st.level}.`, 'system');
  }
}

/** Zauberschaden an einem Monster; Kills gehen durch den normalen Kampfweg. */
/** Arkane Kunde verstärkt alle Zauberwirkungen. */
const arcane = (s: GameState) => 1 + 0.04 * (s.player.skills.find((k) => k.id === 'arkane_kunde')?.level ?? 0);

function spellHurt(s: GameState, m: Monster, dmg: number, label: string): boolean {
  const facets = ['t:zauber', ...targetFacets(s, m), ...selfFacets(s)];
  dmg *= arcane(s);
  const final = Math.max(1, Math.round(dmg - m.ruestung / 2));
  m.hp -= final;
  m.aware = true;
  floatText(s, m.pos, String(final), FX_COLORS.mana);
  s.counters.damageDealt += final;
  log(s, `${label} trifft ${nameOf(s, m)} für ${final} Schaden.`, 'kampf');
  if (m.hp <= 0) {
    killMonster(s, m, null, false, facets);
    return true;
  }
  return false;
}

export function castSpell(s: GameState, id: string, opts: CastOptions = {}): { ok: boolean; message?: string } {
  const p = s.player;
  const def = SPELL_BY_ID[id];
  if (!def || !knowsSpell(s, id)) return { ok: false, message: 'Diesen Zauber kennst du nicht.' };
  const cd = p.spellCooldowns?.[id] ?? 0;
  if (cd > 0) return { ok: false, message: `${def.name} lädt noch (${cd} Züge).` };
  const cost = spellCost(id, opts.mana);
  if ((p.mp ?? 0) < cost) return { ok: false, message: `Nicht genug Mana (${def.name} kostet ${cost}).` };
  const level = spellLevel(s, id);
  const st = effectiveStats(s);
  let kills = 0;

  // Ziel prüfen
  let target: Monster | undefined;
  if (def.target === 'gegner') {
    target = s.monsters.find((m) => m.uid === opts.targetUid);
    if (!target) return { ok: false, message: 'Wähle ein Ziel: Klicke nach dem Zauber auf einen Gegner.' };
    if (chebyshev(p.pos, target.pos) > (def.range ?? 6)) return { ok: false, message: 'Das Ziel ist zu weit weg.' };
    if (!hasLineOfSight(s.map, p.pos, target.pos)) return { ok: false, message: 'Keine freie Sicht auf das Ziel.' };
    if (isInSafeRoom(s, p.pos) || isInSafeRoom(s, target.pos)) return { ok: false, message: 'Im Safe Room ist Gewalt verboten.' };
  }
  if (def.target === 'feld') {
    const t = opts.pos;
    if (!t) return { ok: false, message: 'Wähle ein Feld: Klicke nach dem Zauber auf ein freies Feld.' };
    if (chebyshev(p.pos, t) > (def.range ?? 6) || !hasLineOfSight(s.map, p.pos, t)) return { ok: false, message: 'Dieses Feld ist außer Reichweite.' };
    if (!isWalkable(s.map, t.x, t.y) || s.monsters.some((m) => m.pos.x === t.x && m.pos.y === t.y)) return { ok: false, message: 'Dieses Feld ist nicht frei.' };
  }

  switch (id) {
    case 'heilen': {
      const amount = Math.round(maxHp(s) * (0.2 + 0.03 * (level - 1)) * arcane(s));
      p.hp = Math.min(maxHp(s), p.hp + amount);
      floatText(s, p.pos, `+${amount}`, FX_COLORS.heilung);
      log(s, `Warmes Licht umhüllt dich. +${amount} HP.`, 'info');
      break;
    }
    case 'geschoss': {
      const dmg = cost * 2.5 + st.int * 0.5 + level * (0.8 + R.next(s) * 0.4);
      shot(s, p.pos, target!.pos, 'magie');
      if (spellHurt(s, target!, dmg, `Dein Magisches Geschoss (${cost} Mana)`)) kills++;
      break;
    }
    case 'fackel':
      p.buffs = p.buffs.filter((b) => b.name !== 'Fackel');
      p.buffs.push({ name: 'Fackel', turns: 100 + level * 10, bonuses: { lichtradius: 2 } });
      log(s, 'Ein kleines Licht schwebt über deinem Kopf.', 'info');
      break;
    case 'irrlichtruestung': {
      const shield = Math.round((6 + level * 2 + st.int) * arcane(s));
      p.buffs = p.buffs.filter((b) => b.name !== 'Irrlichtrüstung');
      p.buffs.push({ name: 'Irrlichtrüstung', turns: 60, bonuses: {}, absorb: shield });
      log(s, `Irrlichter tanzen um dich herum. Schild: ${shield}.`, 'info');
      break;
    }
    case 'pfuetzensprung':
      p.pos = { ...opts.pos! };
      log(s, 'Du versinkst in einer Pfütze und tauchst woanders wieder auf.', 'info');
      break;
    case 'feuerball': {
      const center = { ...target!.pos };
      const dmg = 10 + st.int + level * 2;
      shot(s, p.pos, center, 'feuer');
      log(s, 'Ein Feuerball rast los und explodiert!', 'kampf');
      for (const m of s.monsters.filter((x) => chebyshev(x.pos, center) <= 1)) if (spellHurt(s, m, dmg, 'Der Feuerball')) kills++;
      if (chebyshev(p.pos, center) <= 1) {
        const self = Math.round(dmg / 2);
        p.hp -= self;
        log(s, `Du stehst zu nah dran. Der Feuerball erwischt auch dich: −${self} HP.`, 'gefahr');
        if (p.hp <= 0) handleLethal(s, 'vom eigenen Feuerball verbrannt');
      }
      break;
    }
    case 'schutzhuelle': {
      const around = s.monsters.filter((m) => chebyshev(m.pos, p.pos) <= 1);
      for (const m of around) {
        const dx = Math.sign(m.pos.x - p.pos.x);
        const dy = Math.sign(m.pos.y - p.pos.y);
        for (let i = 0; i < 3; i++) {
          const n = { x: m.pos.x + dx, y: m.pos.y + dy };
          if (!isWalkable(s.map, n.x, n.y) || s.monsters.some((o) => o !== m && o.pos.x === n.x && o.pos.y === n.y)) break;
          if (m.homeRoom !== undefined && s.map.roomAt[idx(s.map, n.x, n.y)] !== m.homeRoom) break;
          m.pos = n;
        }
        if (m.size !== 'riesig' && !has(m, 'fliegend')) m.downed = 2;
      }
      log(s, `Eine Blase aus Kraft explodiert um dich herum. ${around.length ? `${around.length} Gegner fliegen durch die Luft.` : 'Niemand war in der Nähe. Schade drum.'}`, 'kampf');
      break;
    }
    case 'schattenmantel':
      for (const m of s.monsters) if (m.homeRoom === undefined) m.aware = false;
      p.buffs = p.buffs.filter((b) => b.name !== 'Schattenmantel');
      p.buffs.push({ name: 'Schattenmantel', turns: 10 + level * 2, bonuses: { ausweichen: 5 } });
      log(s, 'Du ziehst die Schatten um dich. Niemand weiß mehr, wo du bist.', 'info');
      break;
    case 'entgiften':
      if (!cure(s)) log(s, 'Da war gar kein Gift. Die Minze war trotzdem nett.', 'info');
      break;
  }
  p.mp = (p.mp ?? 0) - cost;
  p.spellCooldowns = { ...(p.spellCooldowns ?? {}), [id]: def.cooldown };
  trainSpell(s, id, 1 + kills);
  emit(s, { type: 'spellCast', spell: id, kills });
  return { ok: true };
}

/** Zeit vergeht: Mana regeneriert, Abklingzeiten laufen ab. */
export function magicTick(s: GameState, turns: number) {
  const p = s.player;
  if (p.spellCooldowns) {
    for (const k of Object.keys(p.spellCooldowns)) p.spellCooldowns[k] = Math.max(0, p.spellCooldowns[k] - turns);
  }
  if (p.spells?.length) {
    const lvl = p.skills.find((k) => k.id === 'arkane_kunde')?.level ?? 0;
    const every = lvl >= 10 ? 4 : lvl >= 5 ? 5 : 6;
    const ticks = Math.floor(s.turn / every) - Math.floor((s.turn - turns) / every);
    p.mp = Math.min(maxMp(s), (p.mp ?? 0) + ticks);
  }
}
