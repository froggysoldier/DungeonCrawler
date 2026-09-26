import { hasLineOfSight } from './fov';
import { lichtradius } from './player';
import type { GameState, Pos } from './types';

/**
 * Sieht der Crawler diese Stelle gerade? Gleiche Regeln wie das Sichtfeld:
 * innerhalb der Sichtweite und mit freier Sichtlinie.
 */
export function playerSees(s: GameState, p: Pos): boolean {
  const dx = p.x - s.player.pos.x;
  const dy = p.y - s.player.pos.y;
  const r = lichtradius(s);
  if (dx * dx + dy * dy > r * r) return false;
  return hasLineOfSight(s.map, s.player.pos, p);
}
