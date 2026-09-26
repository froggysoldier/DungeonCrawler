// Deterministischer Zufall (mulberry32). Der Zustand liegt in einem
// Objekt mit Feld `rng`, damit er mit dem Spielstand gespeichert wird.

export interface RngHolder {
  rng: number;
}

export function next(h: RngHolder): number {
  h.rng = (h.rng + 0x6d2b79f5) | 0;
  let t = h.rng;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

/** Ganzzahl im Bereich [min, max] (inklusive). */
export function int(h: RngHolder, min: number, max: number): number {
  return min + Math.floor(next(h) * (max - min + 1));
}

export function chance(h: RngHolder, p: number): boolean {
  return next(h) < p;
}

export function pick<T>(h: RngHolder, arr: readonly T[]): T {
  return arr[Math.floor(next(h) * arr.length)];
}

export function weighted<T>(h: RngHolder, entries: readonly [T, number][]): T {
  const total = entries.reduce((s, [, w]) => s + w, 0);
  let r = next(h) * total;
  for (const [v, w] of entries) {
    r -= w;
    if (r < 0) return v;
  }
  return entries[entries.length - 1][0];
}

export function shuffle<T>(h: RngHolder, arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(next(h) * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}
