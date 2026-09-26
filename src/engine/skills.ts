import { SKILLS, SKILL_BY_ID, skillXpNeeded, type SkillDef } from '../data/skills';
import { emit } from './events';
import { log, toast } from './log';
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
  switch (def.trigger) {
    case 'technique':
      return Object.entries(uses)
        .filter(([k]) => !k.startsWith('_'))
        .filter(([k]) => {
          const [part, move] = k.split('+') as [AttackPart, AttackMove];
          return matches(def, part, move);
        })
        .reduce((sum, [, v]) => sum + v, 0);
    case 'dodge':
      return uses['_dodge'] ?? 0;
    case 'hurt':
      return uses['_hurt'] ?? 0;
    case 'ambush':
      return uses['_ambush'] ?? 0;
    default:
      return 0;
  }
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

function addSkillXp(s: GameState, id: string, amount: number) {
  const st = s.player.skills.find((k) => k.id === id);
  const def = SKILL_BY_ID[id];
  if (!st || !def || st.level >= def.maxLevel) return;
  st.xp += amount;
  while (st.level < def.maxLevel && st.xp >= skillXpNeeded(st.level)) {
    st.xp -= skillXpNeeded(st.level);
    st.level += 1;
    log(s, `Skill verbessert: ${def.name} ist jetzt Stufe ${st.level}.`, 'system');
    toast(s, `${def.name} Stufe ${st.level}`, def.description, 'skill');
    emit(s, { type: 'skillUp', skillId: id, level: st.level });
  }
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

const bump = (s: GameState, key: string) => {
  s.player.techniqueUses[key] = (s.player.techniqueUses[key] ?? 0) + 1;
};

export function skillsOnEvent(s: GameState, e: GameEvent) {
  switch (e.type) {
    case 'attack': {
      bump(s, techniqueKey(e.technique));
      trainTrigger(s, (d) => matches(d, e.technique.part, e.technique.move), e.hit ? 2 : 1);
      break;
    }
    case 'kill': {
      if (e.technique) trainTrigger(s, (d) => matches(d, e.technique!.part, e.technique!.move), 2);
      trainTrigger(s, (d) => d.trigger === 'kill', 1);
      break;
    }
    case 'dodged':
      bump(s, '_dodge');
      trainTrigger(s, (d) => d.trigger === 'dodge', 1);
      break;
    case 'damageTaken':
      bump(s, '_hurt');
      trainTrigger(s, (d) => d.trigger === 'hurt', 1);
      break;
    case 'sleep':
      trainTrigger(s, (d) => d.trigger === 'rest', 4);
      break;
    case 'eat':
      trainTrigger(s, (d) => d.trigger === 'eat', 3);
      break;
    default:
      break;
  }
}

/** Wird bei einem Angriff auf einen ahnungslosen Gegner aufgerufen. */
export function trainAmbush(s: GameState) {
  bump(s, '_ambush');
  trainTrigger(s, (d) => d.trigger === 'ambush', 2);
}
