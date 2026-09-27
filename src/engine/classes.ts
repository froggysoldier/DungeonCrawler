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
import { effectiveStats, maxAusdauer, maxHp } from './player';
import { petLevelUp } from './ai';
import { learnSkill } from './skills';
import { inflict, inflictPlayer } from './conditions';
import { createGold, createItem, rollGroundItem } from './items';
import { itemName, nameOf } from './identify';
import { learnSpell, maxMp } from './magic';
import { party } from './crawlers';
import { mountFuelMax } from './mounts';
import * as R from './rng';
import { SKILL_BY_ID } from '../data/skills';
import { addSpectacle, fanGift } from './viewers';
import type { Bonuses, Buff, GameState, Monster, Technique } from './types';

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

/** Wie viele gewöhnliche Klassen die persönliche Liste enthält. */
export const CLASS_LIST_SIZE = 10;

/**
 * Die Systemstimme stellt eine persönliche Klassenliste zusammen: Die Klassen
 * werden danach bewertet, wie du bisher gekämpft und gelebt hast. Die zehn
 * passendsten gewöhnlichen Klassen stehen zur Wahl, die drei besten werden
 * empfohlen. Seltene und legendäre Klassen kommen dazu, wenn ihre Bedingung
 * erfüllt ist.
 */
export function classOptions(s: GameState): ClassOption[] {
  const scored = CLASSES.map((klass) => ({ klass, score: klass.score(s) }))
    .filter((c) => c.score > -50)
    .sort((a, b) => b.score - a.score || a.klass.id.localeCompare(b.klass.id));
  const special = scored.filter((c) => c.klass.rarity !== 'normal' && c.klass.requirement?.check(s));
  const normal = scored.filter((c) => c.klass.rarity === 'normal').slice(0, CLASS_LIST_SIZE);
  const recommended = new Set([...special, ...normal].sort((a, b) => b.score - a.score).slice(0, 3).map((c) => c.klass.id));
  return [...special, ...normal].map((c) => ({ ...c, recommended: recommended.has(c.klass.id) }));
}

/** Klassenskills und Begabung der Rasse – sie wachsen 50 % schneller. */
export function classSkillsOf(raceId: string | undefined, classId: string | undefined): string[] {
  const out = new Set<string>();
  if (classId) for (const id of CLASS_BY_ID[classId]?.skills ?? []) out.add(id);
  const talent = raceId ? RACE_BY_ID[raceId]?.talent : undefined;
  if (talent) out.add(talent);
  return [...out];
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
  // Klassenskills: der erste bekommt zwei Stufen, die anderen werden gelernt
  def.skills.forEach((id, i) => {
    const existing = p.skills.find((k) => k.id === id);
    if (i === 0) {
      if (existing) existing.level += 2;
      else learnSkill(s, id, 2);
    } else if (!existing) learnSkill(s, id, 1);
  });
  const talent = race.race.talent;
  if (talent && !p.skills.some((k) => k.id === talent)) learnSkill(s, talent, 1);
  p.classSkills = classSkillsOf(raceId, classId);
  for (const spell of def.spells ?? []) learnSpell(s, spell);
  if (def.spells?.length) p.mp = maxMp(s);
  for (const [id, n] of def.gear ?? []) addToInventory(s, createItem(s, id, n));
  if (def.gear?.length) log(s, `Startausrüstung der Klasse: ${def.gear.map(([id, n]) => `${n > 1 ? `${n}x ` : ''}${itemName(s, createItem(s, id))}`).join(', ')}.`, 'loot');
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
  log(s, `Klassenskills (wachsen schneller): ${p.classSkills.map((id) => SKILL_BY_ID[id]?.name ?? id).join(', ')}.`, 'system');
  emit(s, { type: 'classChosen', race: raceId, klass: classId });
  return { ok: true };
}

// ================================================================ Klassenfähigkeiten

export function currentAbility(s: GameState) {
  const k = s.player.klass ? CLASS_BY_ID[s.player.klass] : null;
  return k ? { id: k.ability, ...ABILITIES[k.ability] } : null;
}

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

const buff = (s: GameState, name: string, turns: number, bonuses: Bonuses = {}, extra: Partial<Buff> = {}) => {
  s.player.buffs = s.player.buffs.filter((b) => b.name !== name);
  s.player.buffs.push({ name, turns, bonuses, ...extra });
};

/** Setzt die Klassenfähigkeit ein. `technique` wird für den Wirbelwind genutzt. */
export function useAbility(s: GameState, technique: Technique): ActionResult {
  if (s.status !== 'playing') return { ok: false, message: 'Das Spiel ist vorbei.' };
  const ab = currentAbility(s);
  if (!ab) return { ok: false, message: 'Du hast noch keine Klasse.' };
  const p = s.player;
  if ((p.abilityCooldown ?? 0) > 0) return { ok: false, message: `${ab.name} lädt noch (${p.abilityCooldown} Züge).` };
  if (!ab.peaceful && isInSafeRoom(s, p.pos)) return { ok: false, message: 'Im Safe Room ist Gewalt verboten.' };
  const st = effectiveStats(s);

  switch (ab.id) {
    case 'wutanfall':
      buff(s, 'Wutanfall', 8, { schaden: { alle: 50 }, ausweichen: -10 });
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
      buff(s, 'Kampfschrei', 10, { schaden: { alle: 20 } });
      log(s, 'Dein Kampfschrei hallt durch die Gänge. Deine Gegner nehmen Reißaus!', 'system');
      break;
    }
    case 'bollwerk':
      buff(s, 'Bollwerk', 10, { ruestung: 6 });
      log(s, 'Du spannst jeden Muskel an. Du bist eine Mauer.', 'system');
      break;
    case 'schattenschritt':
      for (const m of s.monsters) if (m.homeRoom === undefined) m.aware = false;
      buff(s, 'Aus dem Schatten', 5, { schaden: { alle: 50 } });
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
      const target = nearestVisible(s, 6);
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
    case 'blutrausch':
      buff(s, 'Blutrausch', 8, { schaden: { alle: 15 } });
      log(s, 'Deine Augen werden rot. Jeder Treffer soll bluten.', 'system');
      break;
    case 'gnadenstoss':
      buff(s, 'Gnadenstoß', 3);
      log(s, 'Du suchst die Schwachstelle. Wer wankt, fällt jetzt.', 'system');
      break;
    case 'giftwolke': {
      const target = nearestVisible(s, 7);
      if (!target) return { ok: false, message: 'Kein Ziel für die Giftwolke in Sicht.' };
      const center = { ...target.pos };
      log(s, 'Du zerdrückst eine Phiole. Eine grüne Wolke quillt hervor.', 'system');
      for (const m of s.monsters.filter((x) => chebyshev(x.pos, center) <= 2 && !isInSafeRoom(s, x.pos))) inflict(s, m, 'gift', 6, 2 + Math.floor(p.level / 4));
      if (chebyshev(p.pos, center) <= 2) inflictPlayer(s, 'gift', 4, 1, 'Deine eigene Giftwolke');
      break;
    }
    case 'brandsatz': {
      const near = s.monsters.filter((x) => chebyshev(x.pos, p.pos) <= 2 && !isInSafeRoom(s, x.pos));
      if (!near.length) return { ok: false, message: 'Niemand in der Nähe, den du anzünden könntest.' };
      log(s, 'Ein Ring aus Flammen schießt um dich herum aus dem Boden!', 'system');
      for (const m of near) inflict(s, m, 'brennen', 3, 3 + Math.floor(p.level / 3));
      break;
    }
    case 'blitzlicht': {
      const targets = visibleMonsters(s, 4);
      if (!targets.length) return { ok: false, message: 'Niemand in Sicht, den du blenden könntest.' };
      log(s, 'Du reißt die Kamera hoch. BLITZ! Für einen Moment ist alles weiß.', 'system');
      for (const m of targets) inflict(s, m, 'blind', 3, 1);
      addSpectacle(s, 6, 'achievement');
      break;
    }
    case 'meditation': {
      p.ausdauer = maxAusdauer(s);
      if (p.spells?.length) p.mp = Math.min(maxMp(s), (p.mp ?? 0) + Math.ceil(maxMp(s) / 2));
      buff(s, 'Meditation', 6, { ausweichen: 10 });
      log(s, 'Du schließt die Augen. Einatmen. Ausatmen. Die Welt wird langsam.', 'system');
      break;
    }
    case 'rudelruf': {
      const pet = p.pet;
      if (!pet) return { ok: false, message: 'Du hast kein Haustier, das du rufen könntest.' };
      pet.alive = true;
      pet.hp = pet.maxHp;
      if (chebyshev(pet.pos, p.pos) > 2) pet.pos = { ...p.pos };
      buff(s, 'Rudelruf', 10);
      log(s, `Du pfeifst. ${pet.name} ist sofort da, mit gefletschten Zähnen und doppelter Wut.`, 'system');
      break;
    }
    case 'zeitlupe': {
      const targets = visibleMonsters(s, 8);
      if (!targets.length) return { ok: false, message: 'Niemand in Sicht.' };
      for (const m of targets) m.slowed = Math.max(m.slowed ?? 0, 6);
      log(s, 'Die Zeit dehnt sich. Deine Gegner bewegen sich wie durch Sirup.', 'system');
      break;
    }
    case 'rauchbombe': {
      log(s, 'PUFF! Eine dichte Rauchwolke hüllt dich ein.', 'system');
      for (const m of s.monsters) {
        if (chebyshev(m.pos, p.pos) <= 1) inflict(s, m, 'blind', 3, 1);
        else if (m.homeRoom === undefined) m.aware = false;
      }
      break;
    }
    case 'langfinger': {
      const m = s.monsters.find((x) => chebyshev(x.pos, p.pos) <= 1 && !x.pickpocketed);
      if (!m) return { ok: false, message: 'Neben dir steht niemand, den du noch bestehlen könntest.' };
      m.pickpocketed = true;
      const gold = 5 + m.level * 3 + (m.stolenGold ?? 0);
      m.stolenGold = 0;
      addToInventory(s, createGold(s, gold));
      log(s, `Deine Finger sind schneller als ${nameOf(s, m)}. Du erbeutest ${gold} Gold.`, 'loot');
      if (R.chance(s, 0.3)) {
        const loot = rollGroundItem(s);
        addToInventory(s, loot);
        log(s, `Außerdem: ${itemName(s, loot)}.`, 'loot');
      }
      m.aware = true;
      m.provoked = true;
      break;
    }
    case 'notreparatur': {
      const mount = p.mount;
      if (mount) {
        mount.down = false;
        mount.hp = mount.maxHp;
        if (mount.fuel !== undefined) mount.fuel = Math.min(mountFuelMax(s), mount.fuel + 30);
        log(s, `Klebeband, Kabelbinder, ein beherzter Tritt: ${mount.name} ist wieder wie neu.`, 'system');
      } else log(s, 'Du flickst deine Ausrüstung mit Klebeband und Blech.', 'system');
      buff(s, 'Schrottpanzer', 10, { ruestung: 4 });
      break;
    }
    case 'motivationsrede': {
      for (const c of party(s)) c.hp = Math.min(c.maxHp, c.hp + Math.round(c.maxHp * 0.3));
      if (p.pet?.alive) p.pet.hp = Math.min(p.pet.maxHp, p.pet.hp + Math.round(p.pet.maxHp * 0.3));
      p.hp = Math.min(maxHp(s), p.hp + Math.round(maxHp(s) * 0.1));
      buff(s, 'Motiviert', 10, { schaden: { alle: 15 } });
      log(s, '„Wir schaffen das. Und wenn nicht, dann wenigstens mit Stil!“ Alle stehen etwas gerader.', 'system');
      break;
    }
    case 'arkanschild': {
      const absorb = 10 + st.int * 2 + p.level;
      buff(s, 'Arkaner Schild', 30, {}, { absorb });
      log(s, `Ein schimmernder Schild legt sich um dich. Er fängt ${absorb} Schaden ab.`, 'system');
      break;
    }
    case 'manaflut':
      p.mp = maxMp(s);
      buff(s, 'Manaflut', 10);
      log(s, 'Mana strömt in dich hinein, bis deine Fingerspitzen knistern.', 'system');
      break;
    case 'totstellen': {
      for (const m of s.monsters) if (m.homeRoom === undefined) {
        m.aware = false;
        m.lastSeen = undefined;
        m.searching = 0;
      }
      const heal = Math.round(maxHp(s) * 0.15);
      p.hp = Math.min(maxHp(s), p.hp + heal);
      log(s, `Du fällst um und rührst dich nicht mehr. Sehr überzeugend. Niemand interessiert sich mehr für dich. (+${heal} HP)`, 'system');
      break;
    }
  }
  p.abilityCooldown = ab.cooldown;
  emit(s, { type: 'abilityUsed', ability: ab.id });
  endTurn(s);
  return { ok: true };
}

function nearestVisible(s: GameState, range: number): Monster | undefined {
  const p = s.player;
  return visibleMonsters(s, range)
    .filter((m) => hasLineOfSight(s.map, p.pos, m.pos))
    .sort((a, b) => chebyshev(a.pos, p.pos) - chebyshev(b.pos, p.pos))[0];
}
