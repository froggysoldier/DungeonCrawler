import { idx, inBounds, isWalkable, tileAt } from './mapgen';
import type { FloorMap, Pos } from './types';

/** Sichtfeld per Strahlenwurf. Gibt eine Menge von Kachel-Indizes zurück. */
export function computeFov(m: FloorMap, origin: Pos, radius: number): Set<number> {
  const visible = new Set<number>();
  visible.add(idx(m, origin.x, origin.y));
  const steps = Math.ceil(2 * Math.PI * radius * 1.5);
  for (let i = 0; i < steps; i++) {
    const a = (i / steps) * Math.PI * 2;
    const dx = Math.cos(a);
    const dy = Math.sin(a);
    let x = origin.x + 0.5;
    let y = origin.y + 0.5;
    for (let d = 0; d < radius; d++) {
      x += dx;
      y += dy;
      const tx = Math.floor(x);
      const ty = Math.floor(y);
      if (!inBounds(m, tx, ty)) break;
      visible.add(idx(m, tx, ty));
      if (tileAt(m, tx, ty) === 'wall') break;
    }
  }
  return visible;
}

/** Sichtlinie zwischen zwei Punkten (Bresenham). */
export function hasLineOfSight(m: FloorMap, a: Pos, b: Pos): boolean {
  let x0 = a.x;
  let y0 = a.y;
  const dx = Math.abs(b.x - x0);
  const dy = -Math.abs(b.y - y0);
  const sx = x0 < b.x ? 1 : -1;
  const sy = y0 < b.y ? 1 : -1;
  let err = dx + dy;
  while (!(x0 === b.x && y0 === b.y)) {
    if (!(x0 === a.x && y0 === a.y) && !isWalkable(m, x0, y0)) return false;
    const e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x0 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y0 += sy;
    }
  }
  return true;
}

export const chebyshev = (a: Pos, b: Pos) => Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y));
