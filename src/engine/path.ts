import { idx, inBounds, isWalkable } from './mapgen';
import type { FloorMap, Pos } from './types';

const DIRS: Pos[] = [
  { x: 1, y: 0 }, { x: -1, y: 0 }, { x: 0, y: 1 }, { x: 0, y: -1 },
  { x: 1, y: 1 }, { x: 1, y: -1 }, { x: -1, y: 1 }, { x: -1, y: -1 },
];

/**
 * A*-Suche mit 8 Richtungen. `passable` kann zusätzliche Einschränkungen
 * machen (z. B. nur bekannte Kacheln). Gibt den Pfad ohne Startfeld zurück.
 */
export function findPath(
  m: FloorMap,
  from: Pos,
  to: Pos,
  passable: (x: number, y: number) => boolean = () => true,
  maxNodes = 4000,
): Pos[] | null {
  if (!inBounds(m, to.x, to.y)) return null;
  const startI = idx(m, from.x, from.y);
  const goalI = idx(m, to.x, to.y);
  const g = new Map<number, number>([[startI, 0]]);
  const came = new Map<number, number>();
  const open: { i: number; f: number }[] = [{ i: startI, f: 0 }];
  const closed = new Set<number>();
  const h = (x: number, y: number) => Math.max(Math.abs(x - to.x), Math.abs(y - to.y));
  let nodes = 0;

  while (open.length) {
    let best = 0;
    for (let k = 1; k < open.length; k++) if (open[k].f < open[best].f) best = k;
    const { i } = open.splice(best, 1)[0];
    if (i === goalI) {
      const path: Pos[] = [];
      let cur = i;
      while (cur !== startI) {
        path.push({ x: cur % m.width, y: Math.floor(cur / m.width) });
        cur = came.get(cur)!;
      }
      return path.reverse();
    }
    if (closed.has(i)) continue;
    closed.add(i);
    if (++nodes > maxNodes) return null;
    const x = i % m.width;
    const y = Math.floor(i / m.width);
    for (const d of DIRS) {
      const nx = x + d.x;
      const ny = y + d.y;
      if (!inBounds(m, nx, ny) || !isWalkable(m, nx, ny)) continue;
      // Keine Diagonale durch Wandecken
      if (d.x && d.y && (!isWalkable(m, x + d.x, y) || !isWalkable(m, x, y + d.y))) continue;
      const ni = idx(m, nx, ny);
      if (ni !== goalI && !passable(nx, ny)) continue;
      const ng = g.get(i)! + (d.x && d.y ? 1.01 : 1);
      if (ng < (g.get(ni) ?? Infinity)) {
        g.set(ni, ng);
        came.set(ni, i);
        open.push({ i: ni, f: ng + h(nx, ny) });
      }
    }
  }
  return null;
}

export function canStep(m: FloorMap, from: Pos, to: Pos): boolean {
  if (!isWalkable(m, to.x, to.y)) return false;
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  if (dx && dy && (!isWalkable(m, from.x + dx, from.y) || !isWalkable(m, from.x, from.y + dy))) return false;
  return true;
}
