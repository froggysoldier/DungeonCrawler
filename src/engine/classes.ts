import { nameOf } from './identify';
import { ABILITIES, CLASSES, CLASS_BY_ID, type ClassDef } from '../data/classes';
import { RACES, RACE_BY_ID, type RaceDef } from '../data/races';
import { has } from './abilities';
import { attackCost, isInSafeRoom, killMonster, playerAttack, WURF_RANGE } from './combat';
import { emit } from './events';
import { chebyshev, hasLineOfSight } from './fov';
import { endTurn, visibleTiles, type ActionResult } from './game';
import { addToInventory } from './inventory';
import { log } from './log';
import { idx } from './mapgen';
import { effectiveStats, maxHp } from './player';
import { petLevelUp } from './ai';
import { learnSkill } from './skills';
import { inflict } from './conditions';
import { addSpectacle, fanGift } from './viewers';
import type { GameState, Monster, Technique } from './types';

// ================================================================ Auswahl (Etage 3)

export interface RaceOption {
  race: RaceDef;
  available: boolean;
}

export function raceOptions(s: GameState): RaceOption[] {
  return RACES.map((race) => ({ race, available: !race.requirement || race.requirement.check(s) }));
}

export interface ClassOption {
  klass: ClassDef;
  score: number;
  recommended: boolean;
}

/**
 * Die Systemstimme stellt eine persönliche Klassenliste zusammen: Die Klassen
 * werden danach bewertet, wie du bisher gekämpft und gelebt hast. Die drei
 * passendsten werden empfohlen, insgesamt stehen acht zur Auswahl.
 */
export function classOptions(s: GameState): ClassOption[] {
  const scored = CLASSES.map((klass) => ({ klass, score: klass.score(s) }))
    .filter((c) => c.score > -50)
    .sort((a, b) => b.score - a.score || a.klass.id.localeCompare(b.klass.id));
  return scored.slice(0, 8).map((c, i) => ({ ...c, recommended: i < 3 }));
}

export function chooseRaceAndClass(s: GameState, raceId: string, classId: string): ActionResult {
  if (!s.pendingSelection) return { ok: false, message: 'Gerade steht keine Auswahl an.' };
  const race = raceOptions(s).find((r) => r.race.id === raceId);
  if (!race?.available) return { ok: false, message: 'Diese Rasse ist für dich nicht freigeschaltet.' };
  const klass = classOptions(s).find((c) => c.klass.id === classId);
  if (!klass) return { ok: false, message: 'Diese Klasse steht nicht auf deiner Liste.' };
  const p = s.player;
  p.race = raceId;
  p.klass = classId;
  p.abilityCooldown = 0;
  if (raceId === 'mensch') p.statPoints += 4;
  const def = klass.klass;
  if (def.skill) {
    const existing = p.skills.find((k) => k.id === def.skill);
    if (existing) existing.level += 2;
    else learnSkill(s, def.skill, 2);
  }
  if (classId === 'tierfluesterer' && p.pet) for (let i = 0; i < 3; i++) petLevelUp(s);
  s.pendingSelection = false;
  s.unlocks.push('klasse');
  // Wer das Tutorial übersprungen hat, bekommt es hier nachgereicht.
  for (const u of ['inventar', 'stats', 'minimap', 'skills'] as const) if (!s.unlocks.includes(u)) s.unlocks.push(u);
  if (p.hand) {
    addToInventory(s, p.hand);
    p.hand = null;
  }
  p.hp = maxHp(s);
  log(s, `Du bist jetzt: ${RACE_BY_ID[raceId].name.replace(' (bleiben, wie du bist)', '')}, ${def.name}. ${RACE_BY_ID[raceId].comment}`, 'system');
  log(s, `Klassenfähigkeit freigeschaltet: ${ABILITIES[def.ability].name} – ${ABILITIES[def.ability].description}`, 'system');
  emit(s, { type: 'classChosen', race: raceId, klass: classId });
  return { ok: true };
}

// ================================================================ Klassenfähigkeiten

export function currentAbility(s: GameState) {
  const k = s.player.klass ? CLASS_BY_ID[s.player.klass] : null;
  return k ? { id: k.ability, ...ABILITIES[k.ability] } : null;
}

const PEACEFUL = new Set(['heilung', 'showtime', 'bollwerk']);

function visibleMonsters(s: GameState, range: number): Monster[] {
  const vis = visibleTiles(s);
  return s.monsters.filter(
    (m) => vis.has(idx(s.map, m.pos.x, m.pos.y)) && chebyshev(m.pos, s.player.pos) <= range && !isInSafeRoom(s, m.pos),
  );
}

function hurt(s: GameState, m: Monster, dmg: number, verb: string) {
  const final = Math.max(1, Math.round(dmg - m.ruestung));
  m.hp -= final;
  m.aware = true;
  s.counters.damageDealt += final;
  log(s, `${verb} trifft ${nameOf(s, m)} für ${final} Schaden.`, 'kampf');
  if (m.hp <= 0) killMonster(s, m, null);
}

/** Setzt die Klassenfähigkeit ein. `technique` wird für den Wirbelwind genutzt. */
export function useAbility(s: GameState, technique: Technique): ActionResult {
  if (s.status !== 'playing') return { ok: false, message: 'Das Spiel ist vorbei.' };
  const ab = currentAbility(s);
  if (!ab) return { ok: false, message: 'Du hast noch keine Klasse.' };
  const p = s.player;
  if ((p.abilityCooldown ?? 0) > 0) return { ok: false, message: `${ab.name} lädt noch (${p.abilityCooldown} Züge).` };
  if (!PEACEFUL.has(ab.id) && isInSafeRoom(s, p.pos)) return { ok: false, message: 'Im Safe Room ist Gewalt verboten.' };
  const st = effectiveStats(s);

  switch (ab.id) {
    case 'wutanfall':
      p.buffs.push({ name: 'Wutanfall', turns: 8, bonuses: { schaden: { alle: 50 }, ausweichen: -10 } });
      log(s, 'Du brüllst, bis dein Gesicht rot anläuft. WUTANFALL!', 'system');
      break;
    case 'wirbelwind': {
      const targets = s.monsters.filter((m) => chebyshev(m.pos, p.pos) <= 1);
      if (!targets.length) return { ok: false, message: 'Niemand in Reichweite für einen Wirbelwind.' };
      const t: Technique = technique.part === 'wurf' ? { part: 'tritt', move: 'normal' } : { part: technique.part, move: 'normal' };
      log(s, 'Du drehst dich wie ein Kreisel!', 'system');
      for (const m of targets) {
        p.ausdauer += attackCost(t); // Wirbelwind kostet keine Ausdauer pro Treffer
        playerAttack(s, m, t);
      }
      break;
    }
    case 'erdbeben': {
      log(s, 'Du springst hoch und landest mit beiden Füßen. Der Boden bebt!', 'system');
      for (const m of s.monsters.filter((x) => chebyshev(x.pos, p.pos) <= 2 && !isInSafeRoom(s, x.pos))) {
        if (m.size !== 'riesig' && !has(m, 'fliegend')) m.downed = 2;
        hurt(s, m, 4 + st.str + p.level, 'Das Beben');
      }
      break;
    }
    case 'kampfschrei': {
      for (const m of visibleMonsters(s, 7)) inflict(s, m, 'furcht', 6, 1);
      p.buffs.push({ name: 'Kampfschrei', turns: 10, bonuses: { schaden: { alle: 20 } } });
      log(s, 'Dein Kampfschrei hallt durch die Gänge. Deine Gegner nehmen Reißaus!', 'system');
      break;
    }
    case 'bollwerk':
      p.buffs.push({ name: 'Bollwerk', turns: 10, bonuses: { ruestung: 6 } });
      log(s, 'Du spannst jeden Muskel an. Du bist eine Mauer.', 'system');
      break;
    case 'schattenschritt':
      for (const m of s.monsters) if (m.homeRoom === undefined) m.aware = false;
      p.buffs.push({ name: 'Aus dem Schatten', turns: 5, bonuses: { schaden: { alle: 50 } } });
      log(s, 'Du verschmilzt mit den Schatten. Niemand weiß mehr, wo du bist.', 'system');
      break;
    case 'steinhagel': {
      const targets = visibleMonsters(s, WURF_RANGE).filter((m) => hasLineOfSight(s.map, p.pos, m.pos)).slice(0, 4);
      if (!targets.length) return { ok: false, message: 'Kein Ziel in Wurfreichweite.' };
      log(s, 'Aus dem Nichts erscheinen Steine in deinen Händen – und fliegen!', 'system');
      for (const m of targets) hurt(s, m, 4 + st.ges / 2 + p.level, 'Ein magischer Stein');
      break;
    }
    case 'bombe': {
      const target = visibleMonsters(s, 6)
        .filter((m) => hasLineOfSight(s.map, p.pos, m.pos))
        .sort((a, b) => chebyshev(a.pos, p.pos) - chebyshev(b.pos, p.pos))[0];
      if (!target) return { ok: false, message: 'Kein Ziel für die Bombe in Sicht.' };
      const center = { ...target.pos };
      log(s, 'Du wirfst deine selbstgebastelte Bombe. Sie tickt. Dann: BUMM!', 'system');
      for (const m of s.monsters.filter((x) => chebyshev(x.pos, center) <= 1)) hurt(s, m, 8 + st.int + p.level * 1.5, 'Die Explosion');
      break;
    }
    case 'heilung': {
      const amount = Math.round(maxHp(s) * 0.4);
      p.hp = Math.min(maxHp(s), p.hp + amount);
      if (p.pet) {
        p.pet.alive = true;
        p.pet.hp = p.pet.maxHp;
      }
      log(s, `Du atmest tief durch. +${amount} HP.`, 'system');
      break;
    }
    case 'showtime':
      log(s, 'Du drehst dich zur Kamera, zwinkerst und machst eine absurde Pose. Das Publikum rastet aus!', 'system');
      addSpectacle(s, 40, 'boss');
      fanGift(s);
      break;
  }
  p.abilityCooldown = ab.cooldown;
  emit(s, { type: 'abilityUsed', ability: ab.id });
  endTurn(s);
  return { ok: true };
}
