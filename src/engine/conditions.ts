import { has, hasSpecial, poison } from './abilities';
import { emit } from './events';
import { floatText } from './fx';
import { NameOf } from './identify';
import { log } from './log';
import { targetFacets } from './observer';
import { effectiveStats } from './player';
import * as R from './rng';
import { playerSees } from './sight';
import { track } from './stats';
import type { ConditionId, GameState, Monster } from './types';

/**
 * Zustände im Kampf: Blutung, Brennen, Gift, Furcht und Blindheit.
 * Gegner tragen sie in `conditions`, der Crawler als Buffs (mit Schaden pro
 * Zug oder Abzügen). Welche Wesen wofür anfällig sind, hängt von ihrer Art ab:
 * Konstrukte bluten nicht, Geister kennen kein Gift, Pflanzen brennen gut.
 */
export interface ConditionDef {
  name: string;
  /** Zustand als Wort, z. B. „blutet“. */
  state: string;
  color: string;
  text: string;
  /** Name des Buffs beim Crawler. */
  buff: string;
  /** Todesursache, wenn der Crawler daran stirbt. */
  death: string;
}

export const CONDITIONS: Record<ConditionId, ConditionDef> = {
  blutung: { name: 'Blutung', state: 'blutet', color: '#e0434a', text: 'verliert jeden Zug Lebenspunkte', buff: 'Blutung', death: 'verblutet' },
  brennen: { name: 'Brennen', state: 'brennt', color: '#ff8a2a', text: 'nimmt jeden Zug Feuerschaden, Tiere geraten in Panik', buff: 'Brennen', death: 'verbrannt' },
  gift: { name: 'Gift', state: 'vergiftet', color: '#7bd66b', text: 'verliert langsam Lebenspunkte', buff: 'Vergiftet', death: 'an einer Vergiftung gestorben' },
  furcht: { name: 'Furcht', state: 'verängstigt', color: '#b38cff', text: 'flieht und greift nicht an', buff: 'Furcht', death: 'vor Angst gestorben' },
  blind: { name: 'Blindheit', state: 'geblendet', color: '#d9d9d9', text: 'trifft kaum und sieht fast nichts', buff: 'Geblendet', death: 'blind in den Tod gelaufen' },
};

export const CONDITION_IDS = Object.keys(CONDITIONS) as ConditionId[];

/** Schadenszustände zählen als eigene „Angriffsart“ für Statistik und Beobachter. */
export const CONDITION_PART: Partial<Record<ConditionId, string>> = { blutung: 'blutung', brennen: 'feuer', gift: 'gift' };

const tagsOf = (s: GameState, m: Monster) => targetFacets(s, m);

/**
 * Wie stark ein Wesen auf einen Zustand reagiert: 0 = immun,
 * 0.5 = halbe Wirkung, 1 = normal, 2 = besonders anfällig.
 */
export function susceptibility(s: GameState, m: Monster, id: ConditionId): number {
  const f = tagsOf(s, m);
  const boss = m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss';
  switch (id) {
    case 'blutung':
      if (f.includes('z:konstrukt') || f.includes('z:geist') || f.includes('z:elementar') || f.includes('z:schleim')) return 0;
      if (f.includes('z:untot') || f.includes('z:pflanze') || f.includes('z:mimic')) return 0.5;
      return 1;
    case 'brennen':
      if (has(m, 'brennend') || f.includes('z:geist')) return 0;
      if (f.includes('z:aquatisch') || f.includes('z:schleim') || f.includes('z:konstrukt')) return 0.5;
      if (f.includes('z:pflanze') || f.includes('z:insekt') || f.includes('z:untot')) return 2;
      return 1;
    case 'gift':
      if (has(m, 'gift') || f.includes('z:konstrukt') || f.includes('z:geist') || f.includes('z:untot') || f.includes('z:elementar')) return 0;
      if (f.includes('z:mimic') || f.includes('z:pflanze')) return 0.5;
      return 1;
    case 'furcht':
      if (boss || f.includes('z:konstrukt') || f.includes('z:untot') || f.includes('z:mimic') || f.includes('z:elementar')) return 0;
      if (m.rank === 'elite' || m.enraged) return 0.5;
      return 1;
    case 'blind':
      if (f.includes('z:konstrukt') || f.includes('z:schleim') || f.includes('z:pflanze') || f.includes('z:mimic')) return 0;
      if (boss) return 0.5;
      return 1;
  }
}

export const conditionOf = (m: Monster, id: ConditionId) => m.conditions?.[id];
export const hasCondition = (m: Monster, id: ConditionId) => (m.conditions?.[id]?.turns ?? 0) > 0;

/**
 * Belegt einen Gegner mit einem Zustand. Gibt zurück, ob er wirkt.
 * Blutungen stapeln sich (bis zur dreifachen Stärke), alles andere frischt auf.
 */
export function inflict(s: GameState, m: Monster, id: ConditionId, turns: number, power: number, source = 'du'): boolean {
  const sus = susceptibility(s, m, id);
  const seen = playerSees(s, m.pos);
  if (sus <= 0) {
    if (seen) log(s, `${NameOf(s, m)} ist immun gegen ${CONDITIONS[id].name}.`, 'kampf');
    return false;
  }
  // Halbe Anfälligkeit: die Hälfte der Versuche prallt ab
  if (sus < 1 && !R.chance(s, sus)) {
    if (seen) log(s, `${NameOf(s, m)} widersteht der ${CONDITIONS[id].name}.`, 'kampf');
    return false;
  }
  m.conditions ??= {};
  const cur = m.conditions[id];
  // Brandstifter: eigene Brände brennen heißer und länger
  if (id === 'brennen' && source === 'du' && hasSpecial(s, 'brandstifter')) {
    power *= 1.5;
    turns += 1;
  }
  const strength = Math.max(1, Math.round(power * (sus > 1 ? 1.5 : 1)));
  if (cur && cur.turns > 0) {
    cur.turns = Math.max(cur.turns, turns);
    cur.power = id === 'blutung' ? Math.min(strength * 3, cur.power + strength) : Math.max(cur.power, strength);
  } else {
    m.conditions[id] = { turns, power: strength };
    if (seen) {
      log(s, `${NameOf(s, m)} ${CONDITIONS[id].state}!`, 'kampf');
      floatText(s, m.pos, CONDITIONS[id].state, CONDITIONS[id].color);
    }
  }
  if (id === 'furcht') {
    m.fleeing = true;
    m.asleep = false;
  }
  if (source === 'du') track(s, `zustand.${id}`);
  return true;
}

/**
 * Zu Beginn eines Monsterzugs: Schaden pro Zug, Zustände laufen ab.
 * Gibt true zurück, wenn das Monster daran gestorben ist.
 */
export function conditionsTurn(s: GameState, m: Monster, kill: (m: Monster, part: string) => void): boolean {
  const c = m.conditions;
  if (!c) return false;
  for (const id of CONDITION_IDS) {
    const cur = c[id];
    if (!cur || cur.turns <= 0) continue;
    cur.turns -= 1;
    const part = CONDITION_PART[id];
    if (part) {
      const dmg = Math.max(1, cur.power);
      m.hp -= dmg;
      s.counters.damageDealt += dmg;
      if (playerSees(s, m.pos)) {
        floatText(s, m.pos, String(dmg), CONDITIONS[id].color);
        log(s, `${NameOf(s, m)} ${CONDITIONS[id].state}: ${dmg} Schaden.`, 'kampf');
      }
      if (m.hp <= 0) {
        kill(m, part);
        return true;
      }
    }
    if (cur.turns <= 0) {
      delete c[id];
      if (id === 'furcht') m.fleeing = false;
      if (playerSees(s, m.pos)) log(s, `${NameOf(s, m)} ${id === 'furcht' ? 'fasst wieder Mut' : id === 'blind' ? 'kann wieder sehen' : id === 'brennen' ? 'brennt nicht mehr' : id === 'blutung' ? 'blutet nicht mehr' : 'hat das Gift überstanden'}.`, 'kampf');
    }
  }
  return false;
}

/** Kurzbeschreibung aller aktiven Zustände für Tooltip und Zielliste. */
export function conditionList(m: Monster): { id: ConditionId; name: string; state: string; color: string; turns: number }[] {
  return CONDITION_IDS.filter((id) => hasCondition(m, id)).map((id) => ({
    id, name: CONDITIONS[id].name, state: CONDITIONS[id].state, color: CONDITIONS[id].color, turns: m.conditions![id]!.turns,
  }));
}

// ================================================================ Crawler

/** Besondere Eigenschaften (Rasse, Klasse, Ausrüstung), die vor Zuständen schützen. */
const IMMUNITY: Partial<Record<ConditionId, string>> = {
  blutung: 'blutlos', brennen: 'feuerfest', gift: 'giftimmun', furcht: 'furchtlos', blind: 'scharfsichtig',
};

export function playerImmune(s: GameState, id: ConditionId): boolean {
  const special = IMMUNITY[id];
  return !!special && hasSpecial(s, special);
}

/**
 * Belegt den Crawler mit einem Zustand. Furcht kann man mit Charisma
 * abschütteln, Blindheit mit Geschick (man duckt sich weg).
 */
export function inflictPlayer(s: GameState, id: ConditionId, turns: number, power: number, source: string): boolean {
  const p = s.player;
  if (id === 'gift') {
    poison(s, source, power);
    return true;
  }
  const def = CONDITIONS[id];
  if (playerImmune(s, id)) {
    log(s, `${source} will dich ${id === 'blind' ? 'blenden' : id === 'furcht' ? 'einschüchtern' : id === 'brennen' ? 'in Brand setzen' : 'aufschlitzen'} – es perlt an dir ab.`, 'info');
    return false;
  }
  const st = effectiveStats(s);
  if (id === 'furcht' && R.chance(s, Math.min(0.75, 0.1 + (st.cha - 5) * 0.05 + (p.level - 1) * 0.02))) {
    log(s, `${source} versucht, dir Angst einzujagen. Du lachst nur.`, 'info');
    return false;
  }
  if (id === 'blind' && R.chance(s, Math.min(0.6, 0.05 + (st.ges - 5) * 0.04))) {
    log(s, `${source} will dich blenden – du drehst rechtzeitig den Kopf weg.`, 'info');
    return false;
  }
  const existing = p.buffs.find((b) => b.name === def.buff);
  const bonuses = id === 'furcht' ? { treffer: -15, schaden: { alle: -15 } } : id === 'blind' ? { treffer: -25, lichtradius: -4 } : {};
  const dot = id === 'blutung' || id === 'brennen' ? power : undefined;
  if (existing) {
    existing.turns = Math.max(existing.turns, turns);
    if (dot) existing.dot = id === 'blutung' ? Math.min(power * 3, (existing.dot ?? 0) + power) : Math.max(existing.dot ?? 0, power);
  } else {
    p.buffs.push({ name: def.buff, turns, bonuses, dot, debuff: true });
  }
  floatText(s, p.pos, def.state, def.color);
  const what = id === 'blutung' ? `Du blutest! (${power} Schaden pro Zug – ein Verband hilft)` : id === 'brennen' ? `Du brennst! (${power} Schaden pro Zug – Warten heißt: am Boden wälzen)` : id === 'furcht' ? 'Die Angst packt dich. Deine Hände zittern (−15 % Treffer und Schaden).' : 'Du bist geblendet! Du siehst kaum noch etwas (−25 % Treffer, weniger Sicht).';
  log(s, `${source}: ${what}`, 'gefahr');
  emit(s, { type: 'conditioned', condition: id, source });
  return true;
}

/** Den Crawler von einem Zustand befreien. */
export function clearPlayer(s: GameState, id: ConditionId): boolean {
  const name = CONDITIONS[id].buff;
  const before = s.player.buffs.length;
  s.player.buffs = s.player.buffs.filter((b) => b.name !== name);
  return s.player.buffs.length < before;
}

export const playerHas = (s: GameState, id: ConditionId) => s.player.buffs.some((b) => b.name === CONDITIONS[id].buff);

/** Todesursache für einen Schadens-Buff. */
export function deathByBuff(name: string): string {
  const def = Object.values(CONDITIONS).find((c) => c.buff === name);
  return def?.death ?? 'an den Folgen gestorben';
}
