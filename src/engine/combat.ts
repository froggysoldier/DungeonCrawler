import { NameOf, nameOf } from './identify';
import { has, hasSpecial } from './abilities';
import { PART_NAMES } from './bonuses';
import { handleLethal } from './death';
import { attackFacets, dynAttackBonus } from './observer';
import { traitAttackBonus } from './traits';
import { emit } from './events';
import { chebyshev, hasLineOfSight } from './fov';
import { createAreaMap, createBox, createGold, createItem, rollMobDrop } from './items';
import { log } from './log';
import { blast } from './traps';
import { population } from './crawlers';
import { roomOf } from './mapgen';
import { currentWeapon, effectiveStats, gainXp, maxHp, skillLevel, throwables, totalBonuses } from './player';
import * as R from './rng';
import { matchingSkills, techniqueKey, trainAmbush } from './skills';
import type { AttackMove, AttackPart, GameState, Item, Monster, Pos, Technique } from './types';

export const MOVE_NAMES: Record<AttackMove, string> = {
  normal: 'Normal', sprung: 'Sprung', stampfen: 'Stampfen', anlauf: 'Anlauf',
};

export const ATTACK_PARTS: AttackPart[] = ['faust', 'tritt', 'knie', 'ellbogen', 'kopf', 'waffe', 'wurf'];
export const ATTACK_MOVES: AttackMove[] = ['normal', 'sprung', 'stampfen', 'anlauf'];

const BASE_DAMAGE: Record<Exclude<AttackPart, 'waffe' | 'wurf'>, number> = {
  faust: 3, tritt: 4, knie: 4, ellbogen: 4, kopf: 5,
};

const MOVE_MULT: Record<AttackMove, number> = { normal: 1, sprung: 1.5, stampfen: 1.8, anlauf: 1.4 };
const MOVE_TREFFER: Record<AttackMove, number> = { normal: 0, sprung: -10, stampfen: 15, anlauf: -5 };
const MOVE_COST: Record<AttackMove, number> = { normal: 1, sprung: 4, stampfen: 2, anlauf: 3 };

export const WURF_RANGE = 6;

export function attackCost(t: Technique): number {
  return MOVE_COST[t.move] + (t.part === 'kopf' ? 1 : 0);
}

/** Beschreibt, wie die Technik angesagt wird, z. B. „Sprung-Tritt“. */
export function techniqueName(t: Technique): string {
  const part = PART_NAMES[t.part];
  return t.move === 'normal' ? part : `${MOVE_NAMES[t.move]}-${part}`;
}

export function isInSafeRoom(s: GameState, p: Pos): boolean {
  return roomOf(s.map, p)?.kind === 'safe';
}

/** Prüft, ob eine Technik gegen ein Ziel möglich ist. Gibt einen Grund zurück, falls nicht. */
export function techniqueBlocker(s: GameState, target: Monster, t: Technique): string | null {
  const p = s.player;
  const d = chebyshev(p.pos, target.pos);
  if (isInSafeRoom(s, p.pos) || isInSafeRoom(s, target.pos)) return 'Im Safe Room ist Gewalt verboten.';
  if (t.part === 'wurf') {
    if (t.move !== 'normal') return 'Würfe gehen nur normal.';
    if (!throwables(s).length) return 'Du hast nichts zum Werfen.';
    if (d > WURF_RANGE) return 'Zu weit weg zum Werfen.';
    if (!hasLineOfSight(s.map, p.pos, target.pos)) return 'Keine freie Wurfbahn.';
    return null;
  }
  if (d > 1) return 'Zu weit weg – du musst direkt daneben stehen.';
  if (t.part === 'waffe' && !currentWeapon(s)) return 'Du hast keine Waffe.';
  if (t.move === 'stampfen' && target.downed <= 0 && target.size !== 'winzig') {
    return 'Stampfen geht nur auf Gegner, die am Boden liegen (oder winzig sind).';
  }
  if (t.move === 'stampfen' && t.part !== 'tritt') return 'Stampfen geht nur mit dem Fuß.';
  if (t.move === 'stampfen' && has(target, 'fliegend')) return `${NameOf(s, target)} fliegt – draufstampfen unmöglich.`;
  if (t.move === 'anlauf') {
    const dir = p.lastMoveDir;
    if (!dir) return 'Für Anlauf musst du dich im letzten Zug auf den Gegner zubewegt haben.';
    const dx = Math.sign(target.pos.x - p.pos.x);
    const dy = Math.sign(target.pos.y - p.pos.y);
    if (dir.x * dx + dir.y * dy <= 0) return 'Für Anlauf musst du dich im letzten Zug auf den Gegner zubewegt haben.';
  }
  if (p.ausdauer < attackCost(t)) return 'Nicht genug Ausdauer.';
  return null;
}

/** Trefferchance in Prozent (5–95). */
export function hitChance(s: GameState, target: Monster, t: Technique): number {
  const b = totalBonuses(s);
  const st = effectiveStats(s, b);
  let hit = 75 + (st.ges - 5) * 2 + (b.treffer ?? 0) + MOVE_TREFFER[t.move] - target.ausweichen;
  for (const { st: sk, def } of matchingSkills(s, t)) hit += (def.matchTreffer ?? 0) * sk.level;
  if (t.part === 'wurf') hit -= 5 + chebyshev(s.player.pos, target.pos) * 2;
  if (!target.aware) hit += 20;
  if (target.downed > 0) hit += 25;
  const facets = attackFacets(s, target, t);
  hit += dynAttackBonus(s, facets, t).hit + traitAttackBonus(s, facets).hit;
  return Math.max(5, Math.min(95, Math.round(hit)));
}

export interface AttackResult {
  ok: boolean;
  reason?: string;
}

export function playerAttack(s: GameState, target: Monster, t: Technique): AttackResult {
  const blocker = techniqueBlocker(s, target, t);
  if (blocker) return { ok: false, reason: blocker };
  const p = s.player;
  const b = totalBonuses(s);
  const st = effectiveStats(s, b);
  const skills = matchingSkills(s, t);
  const ambush = !target.aware;
  p.ausdauer -= attackCost(t);

  // --- Wurfobjekt bestimmen und verbrauchen
  let thrown: Item | null = null;
  if (t.part === 'wurf') {
    const src = throwables(s)[0];
    thrown = { ...src, menge: 1 };
    if (p.hand && p.hand.uid === src.uid) {
      if ((src.menge ?? 1) > 1) src.menge = (src.menge ?? 1) - 1;
      else p.hand = null;
    } else {
      src.menge = (src.menge ?? 1) - 1;
      if ((src.menge ?? 0) <= 0) p.inventory = p.inventory.filter((i) => i.uid !== src.uid);
    }
    s.counters.throws += 1;
  }

  // --- Trefferchance
  // Kontext VOR dem Angriff festhalten – der Beobachter wertet ihn aus
  const facets = attackFacets(s, target, t);
  target.provoked = true;
  const isHit = R.next(s) * 100 < hitChance(s, target, t);

  const name = techniqueName(t);
  if (!isHit) {
    s.counters.missStreak += 1;
    log(s, `Dein ${name} verfehlt ${nameOf(s, target)}.`, 'kampf');
    target.aware = true;
    if (thrown?.special === 'bumerang') returnThrown(s, thrown);
    else if (thrown?.explosion) detonate(s, thrown, target.pos);
    else if (thrown) dropNear(s, thrown, target.pos);
    emit(s, { type: 'attack', technique: t, hit: false, crit: false, damage: 0, target, thrown: thrown ?? undefined, facets });
    return { ok: true };
  }
  s.counters.missStreak = 0;

  // --- Schaden
  let base: number;
  if (t.part === 'waffe') base = (currentWeapon(s)?.waffenSchaden ?? 2) + st.str / 2;
  else if (t.part === 'wurf') base = (thrown?.wurfSchaden ?? 2) + st.ges / 3;
  else base = BASE_DAMAGE[t.part] + st.str / 2;
  let pct = (b.schaden?.[t.part] ?? 0) + (b.schaden?.alle ?? 0) + dynAttackBonus(s, facets, t).dmg + traitAttackBonus(s, facets).dmg;
  for (const { st: sk, def } of skills) pct += (def.matchDamage ?? 0) * sk.level;
  if (ambush) {
    pct += 25 * skillLevel(s, 'hinterhalt');
    trainAmbush(s);
  }
  let dmg = base * MOVE_MULT[t.move] * (1 + pct / 100) * (0.8 + R.next(s) * 0.4);
  if (target.downed > 0) dmg *= 1.2;
  if (has(target, 'gepanzert') && t.part === 'faust') dmg *= 0.5;
  const critChance = 5 + (b.krit ?? 0) + Math.max(0, st.ges - 5);
  const crit = R.next(s) * 100 < critChance;
  if (crit) {
    dmg *= 2;
    s.counters.crits += 1;
  }
  const final = Math.max(1, Math.round(dmg - target.ruestung));

  target.hp -= final;
  target.aware = true;
  target.hitBy = [...new Set([...(target.hitBy ?? []), t.part])];
  s.counters.damageDealt += final;
  const critTxt = crit ? ' KRITISCH!' : '';
  log(s, `${ambush ? 'Überraschungsangriff! ' : ''}Dein ${name} trifft ${nameOf(s, target)} für ${final} Schaden.${critTxt}`, 'kampf');

  // Kopfstoß tut auch dir weh – außer du bist geübt darin.
  if (t.part === 'kopf' && R.chance(s, Math.max(0, 0.5 - skillLevel(s, 'kopfnuss') * 0.1))) {
    p.hp -= 1;
    log(s, 'Aua. Dein Schädel brummt. (−1 HP)', 'kampf');
    if (p.hp <= 0) handleLethal(s, 'am eigenen Kopfstoß gestorben');
  }

  // Umwerfen
  if (target.hp > 0 && (t.part === 'tritt' || t.move === 'anlauf' || t.move === 'sprung')) {
    let kd = t.part === 'tritt' ? 12 : 6;
    if (t.move === 'sprung') kd += 13;
    if (t.move === 'anlauf') kd += 12;
    for (const { st: sk, def } of skills) kd += (def.knockdown ?? 0) * sk.level;
    if (target.size === 'gross') kd /= 2;
    if (target.size === 'riesig' || has(target, 'fliegend')) kd = 0;
    if (R.next(s) * 100 < kd) {
      target.downed = 2;
      s.counters.knockdowns += 1;
      log(s, `${NameOf(s, target)} geht zu Boden!`, 'kampf');
    }
  }

  // Stiefel des ungebremsten Stampfens: Beben trifft Nachbarn
  if (t.move === 'stampfen' && p.equipment.fuesse?.special === 'stampf_beben') {
    for (const m of [...s.monsters]) {
      if (m === target || chebyshev(m.pos, target.pos) > 1) continue;
      const quake = Math.max(1, Math.round(final / 2) - m.ruestung);
      m.hp -= quake;
      m.aware = true;
      log(s, `Das Beben erwischt ${nameOf(s, m)} für ${quake} Schaden.`, 'kampf');
      if (m.hp <= 0) killMonster(s, m, t);
    }
  }

  if (thrown) {
    if (thrown.special === 'bumerang') {
      returnThrown(s, thrown);
      log(s, `${thrown.name} fliegt zu dir zurück.`, 'kampf');
    } else if (thrown.explosion) {
      // erst den Treffer auswerten, dann die Explosion
    } else if (thrown.baseId === 'flasche' || thrown.baseId === 'kaffeetasse') log(s, `${thrown.name} zerschellt.`, 'kampf');
    else dropNear(s, thrown, target.pos);
  }

  // Vampir-Effekt: ein Teil des Schadens heilt dich
  if (hasSpecial(s, 'vampir') && t.part !== 'wurf') {
    const heal = Math.max(1, Math.round(final * 0.15));
    p.hp = Math.min(maxHp(s), p.hp + heal);
  }

  emit(s, { type: 'attack', technique: t, hit: true, crit, damage: final, target, thrown: thrown ?? undefined, facets });
  const at = { ...target.pos };
  if (target.hp <= 0) killMonster(s, target, t, false, facets);
  if (thrown?.explosion) detonate(s, thrown, at);
  return { ok: true };
}

/** Sprengsatz geht hoch: Schaden im Umkreis von einem Feld. */
function detonate(s: GameState, thrown: Item, at: Pos) {
  const dmg = Math.round((thrown.explosion ?? 0) * (1 + 0.1 * skillLevel(s, 'handwerk')) + effectiveStats(s).ges / 3);
  log(s, thrown.baseId === 'brandflasche' ? 'Die Brandflasche zerplatzt in einer Feuerwolke!' : `${thrown.name} detoniert mit ohrenbetäubendem Knall!`, 'kampf');
  blast(s, at, dmg, 'bombe', `vom eigenen Sprengsatz (${thrown.name}) zerlegt`);
}

export function dropNear(s: GameState, item: Item, pos: Pos) {
  s.items.push({ pos: { ...pos }, item });
}

function returnThrown(s: GameState, item: Item) {
  const p = s.player;
  const same = p.inventory.find((i) => i.baseId === item.baseId);
  if (same) same.menge = (same.menge ?? 0) + 1;
  else if (!p.hand && !s.unlocks.includes('inventar')) p.hand = item;
  else p.inventory.push(item);
}

/** Explosion beim Tod: trifft alles in direkter Nähe – auch dich. */
function explode(s: GameState, m: Monster) {
  const dmg = R.int(s, 3, 6) + Math.floor(m.level / 2);
  log(s, `${NameOf(s, m)} explodiert mit einem feuchten KNALL!`, 'gefahr');
  for (const o of [...s.monsters]) {
    if (chebyshev(o.pos, m.pos) > 1) continue;
    o.hp -= dmg;
    log(s, `Die Explosion trifft ${nameOf(s, o)} für ${dmg} Schaden.`, 'kampf');
    if (o.hp <= 0) killMonster(s, o, null);
  }
  const pet = s.player.pet;
  if (pet?.alive && chebyshev(pet.pos, m.pos) <= 1) {
    pet.hp -= dmg;
    if (pet.hp <= 0) {
      pet.hp = 0;
      pet.alive = false;
      log(s, `${pet.name} wird von der Explosion umgehauen und verschwindet bewusstlos in einem Transportlicht.`, 'gefahr');
    }
  }
  if (chebyshev(s.player.pos, m.pos) <= 1 && s.status === 'playing') {
    const taken = hasSpecial(s, 'explosionsschutz') ? Math.ceil(dmg / 2) : dmg;
    s.player.hp -= taken;
    s.counters.damageTaken += taken;
    log(s, `Die Explosion erwischt dich für ${taken} Schaden.`, 'gefahr');
    if (s.player.hp <= 0) handleLethal(s, `durch die Explosion von ${nameOf(s, m)} zerfetzt`);
    else emit(s, { type: 'explosion', damage: taken, source: m.name });
  }
}

/** `byPet`: true = Haustier, Text = Name eines Party-Mitglieds. */
export function killMonster(s: GameState, m: Monster, t: Technique | null, byPet: boolean | string = false, facets?: string[]) {
  if (!s.monsters.includes(m)) return;
  s.monsters = s.monsters.filter((x) => x !== m);
  s.counters.kills += 1;
  s.counters.killsByDef[m.defId] = (s.counters.killsByDef[m.defId] ?? 0) + 1;
  if (m.rank === 'elite') s.counters.eliteKills += 1;
  if (t) {
    const key = techniqueKey(t);
    s.player.techniqueKills[key] = (s.player.techniqueKills[key] ?? 0) + 1;
  }
  const killer = typeof byPet === 'string' ? byPet : byPet && s.player.pet ? s.player.pet.name : 'Du';
  log(s, `${killer === 'Du' ? 'Du tötest' : `${killer} tötet`} ${nameOf(s, m)}!`, 'kampf');
  const xp = gainXp(s, m.xp);
  log(s, `+${xp} XP`, 'info');

  // Beute
  for (const drop of rollMobDrop(s, m.level, m.rank === 'elite')) dropNear(s, drop, m.pos);
  if (m.stolenGold) {
    dropNear(s, createGold(s, m.stolenGold), m.pos);
    log(s, `Dein gestohlenes Gold (${m.stolenGold}) fällt klimpernd zu Boden.`, 'loot');
  }
  if (m.loot) for (const id of m.loot) dropNear(s, createItem(s, id), m.pos);
  if (m.defId === 'kobold_bombe' && R.chance(s, 0.6)) dropNear(s, createItem(s, 'schwarzpulver'), m.pos);

  if (m.rank === 'nachbarschaftsboss') {
    s.counters.bossKills += 1;
    const hood = s.map.hoods[m.hood];
    if (hood) hood.bossAlive = false;
    dropNear(s, createAreaMap(s, m.hood), m.pos);
    s.player.boxes.push(createBox(s, 'boss', s.floor >= 2 ? 'gold' : 'silber'));
    log(s, `Nachbarschafts-Boss besiegt! Im ${hood?.name ?? 'Viertel'} spawnen keine neuen Monster mehr. Eine Gebietskarte liegt am Boden. Du erhältst eine Boss-Box.`, 'system');
  }
  if (m.rank === 'boroughboss') {
    s.counters.bossKills += 1;
    s.player.boxes.push(createBox(s, 'boss', s.floor >= 2 ? 'platin' : 'gold'));
    log(s, 'Borough-Boss besiegt! Der Weg zur Treppe ist frei. Du erhältst eine Boss-Box.', 'system');
  }
  if (m.rank === 'geist' && m.ghostOf) s.ghostsDefeated.push(m.ghostOf);
  if (m.rank === 'geist' && m.ghostItems) {
    for (const it of m.ghostItems) dropNear(s, { ...it, uid: `${it.uid}g${s.turn}` }, m.pos);
    log(s, `Der Geist zerfällt. Zurück bleibt, was ${m.ghostOf} einst getragen hat.`, 'system');
  }
  if (m.defId === 'abtruenniger_crawler') population(s).alive -= 1;
  emit(s, { type: 'kill', monster: m, technique: t, byPet: !!byPet, facets });
  if (has(m, 'explodiert')) explode(s, m);
}
