import { ACHIEVEMENTS } from '../data/achievements';
import { BOX_TIERS, BOX_TIER_NAMES, BOX_TYPE_NAMES } from '../data/world';
import { createBox } from './items';
import { log, toast } from './log';
import { addSpectacle } from './viewers';
import type { BoxTier, GameEvent, GameState } from './types';

/**
 * Prüft alle Achievements gegen ein Ereignis. Wer ein Achievement als
 * Erster (über alle eigenen Staffeln) erreicht, bekommt eine Box-Stufe mehr.
 */
export function checkAchievements(s: GameState, e: GameEvent) {
  if (s.status !== 'playing' && e.type !== 'start') return;
  for (const a of ACHIEVEMENTS) {
    if (s.achievements.includes(a.id)) continue;
    let ok = false;
    try {
      ok = a.check(e, s);
    } catch {
      ok = false;
    }
    if (!ok) continue;
    s.achievements.push(a.id);
    const first = !s.firstEver.includes(a.id);
    const tier: BoxTier = first ? upgrade(a.tier) : a.tier;
    const box = createBox(s, a.box, tier);
    s.player.boxes.push(box);
    const firstNote = first ? ' ERSTMALIG IN DEINER KARRIERE – Box-Stufe erhöht!' : '';
    log(s, `NEUES ACHIEVEMENT: ${a.name}! ${a.description}`, 'achievement');
    log(s, `${a.comment}`, 'achievement');
    log(s, `Belohnung: ${BOX_TIER_NAMES[tier]} ${BOX_TYPE_NAMES[a.box]}.${firstNote}`, 'loot');
    addSpectacle(s, 4 + BOX_TIERS.indexOf(tier) * 4, 'achievement');
    toast(s, `🏆 ${a.name}`, `${a.description} → ${BOX_TIER_NAMES[tier]} ${BOX_TYPE_NAMES[a.box]}`, 'achievement');
  }
}

function upgrade(t: BoxTier): BoxTier {
  const i = BOX_TIERS.indexOf(t);
  return BOX_TIERS[Math.min(BOX_TIERS.length - 1, i + 1)];
}
