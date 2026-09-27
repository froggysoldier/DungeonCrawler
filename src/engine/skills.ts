import { SKILLS, SKILL_BY_ID, skillXpNeeded, type SkillDef, type SkillTrigger } from '../data/skills';
import { emit } from './events';
import { log, toast } from './log';
import { levelDiffFactor } from './progression';
import type { AttackMove, AttackPart, GameEvent, GameState, Technique } from './types';

export const techniqueKey = (t: Technique) => `${t.part}+${t.move}`;

function matches(def: SkillDef, part: AttackPart, move: AttackMove): boolean {
  if (def.trigger !== 'technique') return false;
  if (def.parts && !def.parts.includes(part)) return false;
  if (def.moves && !def.moves.includes(move)) return false;
  return true;
}

/** Wie oft wurde eine zum Skill passende Aktion schon ausgeführt? */
export function skillProgress(s: GameState, def: SkillDef): number {
  const uses = s.player.techniqueUses;
  if (def.trigger === 'technique') {
    return Object.entries(uses)
      .filter(([k]) => !k.startsWith('_'))
      .filter(([k]) => {
        const [part, move] = k.split('+') as [AttackPart, AttackMove];
        return matches(def, part, move);
      })
      .reduce((sum, [, v]) => sum + v, 0);
  }
  return uses[`_${def.trigger}`] ?? 0;
}

/** Skills, die zu einer Technik passen – für Schaden- und Trefferboni. */
export function matchingSkills(s: GameState, t: Technique) {
  return s.player.skills
    .map((st) => ({ st, def: SKILL_BY_ID[st.id] }))
    .filter(({ def }) => def && matches(def, t.part, t.move));
}

export function learnSkill(s: GameState, id: string, level = 1, silent = false) {
  const existing = s.player.skills.find((k) => k.id === id);
  if (existing) {
    existing.level = Math.max(existing.level, level);
    return;
  }
  s.player.skills.push({ id, level, xp: 0 });
  if (silent) return;
  const def = SKILL_BY_ID[id];
  log(s, `NEUER SKILL: ${def.name}! ${def.unlockText}`, 'system');
  toast(s, `Neuer Skill: ${def.name}`, def.description, 'skill');
  emit(s, { type: 'skillLearned', skillId: id });
}

/** Klassenskills lernen schneller (siehe Klassen). */
function skillXpMultiplier(s: GameState, id: string): number {
  return s.player.classSkills?.includes(id) ? 1.5 : 1;
}

function addSkillXp(s: GameState, id: string, amount: number) {
  const st = s.player.skills.find((k) => k.id === id);
  const def = SKILL_BY_ID[id];
  if (!st || !def || st.level >= def.maxLevel) return;
  // Bruchteile sammeln sich an, damit auch kleine Beträge zählen
  st.xp += amount * skillXpMultiplier(s, id);
  while (st.level < def.maxLevel && st.xp >= skillXpNeeded(st.level)) {
    st.xp -= skillXpNeeded(st.level);
    st.level += 1;
    log(s, `Skill verbessert: ${def.name} ist jetzt Stufe ${st.level}.`, 'system');
    toast(s, `${def.name} Stufe ${st.level}`, def.effect ? def.effect(st.level) : def.description, 'skill');
    emit(s, { type: 'skillUp', skillId: id, level: st.level });
  }
  if (st.level >= def.maxLevel) st.xp = 0;
}

/** Zählt eine Aktion und prüft, ob dadurch Skills entstehen oder wachsen. */
function trainTrigger(s: GameState, filter: (d: SkillDef) => boolean, amount: number) {
  for (const def of SKILLS) {
    if (!filter(def)) continue;
    const has = s.player.skills.some((k) => k.id === def.id);
    if (has) addSkillXp(s, def.id, amount);
    else if (skillProgress(s, def) >= def.unlockAt) learnSkill(s, def.id);
  }
}

const bump = (s: GameState, key: string, by = 1) => {
  s.player.techniqueUses[key] = (s.player.techniqueUses[key] ?? 0) + by;
};

/**
 * Trainiert alle Skills eines Auslösers: zählt die Aktion (für die
 * Freischaltung) und gibt Skill-XP.
 */
export function trainSkill(s: GameState, trigger: Exclude<SkillTrigger, 'technique'>, amount = 1) {
  bump(s, `_${trigger}`);
  trainTrigger(s, (d) => d.trigger === trigger, amount);
}

/** Lernfaktor nach Gegnerstärke: an viel schwächeren Gegnern lernt man kaum etwas. */
export function learnFactor(s: GameState, targetLevel: number): number {
  return Math.max(0.1, Math.min(1.5, levelDiffFactor(targetLevel - s.player.level)));
}

export function skillsOnEvent(s: GameState, e: GameEvent) {
  switch (e.type) {
    case 'attack': {
      bump(s, techniqueKey(e.technique));
      const f = learnFactor(s, e.target.level);
      trainTrigger(s, (d) => matches(d, e.technique.part, e.technique.move), (e.hit ? 2 : 1) * f);
      break;
    }
    case 'kill': {
      const f = learnFactor(s, e.monster.level);
      if (e.technique) trainTrigger(s, (d) => matches(d, e.technique!.part, e.technique!.move), 2 * f);
      trainTrigger(s, (d) => d.trigger === 'kill', f);
      if (e.byPet && !e.byAlly) trainSkill(s, 'pet', f);
      if (e.facets?.includes('t:bombe')) trainSkill(s, 'explode', 2 * f);
      break;
    }
    case 'dodged':
      trainSkill(s, 'dodge', 1);
      break;
    case 'damageTaken':
      trainSkill(s, 'hurt', 1);
      break;
    case 'sleep':
      trainSkill(s, 'heal', 3);
      break;
    case 'eat':
      trainSkill(s, 'eat', 3);
      break;
    case 'trapDetected':
      trainSkill(s, 'trap', 3);
      trainSkill(s, 'perceive', 2);
      break;
    case 'trapDisarmed':
    case 'trapPlaced':
      trainSkill(s, 'trap', 3);
      break;
    case 'trapTriggered':
      if (!e.onPlayer) trainSkill(s, 'trap', 2);
      break;
    case 'crafted':
      trainSkill(s, 'craft', 3);
      break;
    case 'enterRoom':
      if (e.first) trainSkill(s, 'perceive', 1);
      break;
    case 'haggle':
      trainSkill(s, 'haggle', e.success ? 3 : 1);
      break;
    case 'petGained':
      trainSkill(s, 'pet', 3);
      break;
    case 'petLevel':
      trainSkill(s, 'pet', 2);
      break;
    case 'spellCast':
      trainSkill(s, 'cast', 2);
      break;
    case 'poisoned':
      trainSkill(s, 'poison', 1);
      break;
    case 'rammed':
      trainSkill(s, 'ride', 2);
      break;
    default:
      break;
  }
}

/** Wird bei einem Angriff auf einen ahnungslosen Gegner aufgerufen. */
export function trainAmbush(s: GameState) {
  trainSkill(s, 'ambush', 2);
}

/** Wirkung eines Skills auf einer Stufe als Klartext (für die Anzeige). */
export function skillEffectText(def: SkillDef, level: number): string {
  if (def.effect) return def.effect(level);
  const parts: string[] = [];
  if (def.matchDamage) parts.push(`+${def.matchDamage * level} % Schaden`);
  if (def.matchTreffer) parts.push(`+${def.matchTreffer * level} % Treffer`);
  if (def.knockdown) parts.push(`+${def.knockdown * level} % Umwerfen`);
  const b = def.perLevel;
  if (b.krit) parts.push(`+${b.krit * level} % Krit`);
  if (b.ausweichen) parts.push(`+${(b.ausweichen * level).toString().replace('.', ',')} % Ausweichen`);
  if (b.maxHp) parts.push(`+${b.maxHp * level} max. HP`);
  if (b.maxAusdauer) parts.push(`+${b.maxAusdauer * level} max. Ausdauer`);
  if (b.xpBonus) parts.push(`+${b.xpBonus * level} % XP`);
  return parts.join(' · ') || def.description;
}
