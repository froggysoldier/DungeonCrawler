import { checkAchievements } from './achievements';
import { skillsOnEvent } from './skills';
import type { GameEvent, GameState } from './types';

/**
 * Zentrale Stelle, an der Spielereignisse verarbeitet werden. Skills und
 * Achievements hängen sich hier ein, statt überall im Code verstreut zu sein.
 */
export function emit(s: GameState, e: GameEvent) {
  skillsOnEvent(s, e);
  checkAchievements(s, e);
}
