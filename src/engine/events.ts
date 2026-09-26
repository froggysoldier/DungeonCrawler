import { checkAchievements } from './achievements';
import { skillsOnEvent } from './skills';
import { observe } from './observer';
import { traitsOnEvent } from './traits';
import { viewersOnEvent } from './viewers';
import { sponsorsOnEvent } from './sponsors';
import { questsOnEvent } from './quests';
import type { GameEvent, GameState } from './types';

/**
 * Zentrale Stelle, an der Spielereignisse verarbeitet werden. Skills und
 * Achievements hängen sich hier ein, statt überall im Code verstreut zu sein.
 */
export function emit(s: GameState, e: GameEvent) {
  skillsOnEvent(s, e);
  checkAchievements(s, e);
  viewersOnEvent(s, e);
  observe(s, e);
  traitsOnEvent(s, e);
  sponsorsOnEvent(s, e);
  questsOnEvent(s, e);
}
