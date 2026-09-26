import type { Fx, GameState, Pos } from '../engine/types';
import type { Anim, DrawFloater, DrawProjectile, ProjectileStyle } from './render';

/**
 * Weiche Bewegung und Effekte: Figuren gleiten von Feld zu Feld, die Kamera
 * folgt sanft, Geschosse fliegen sichtbar, Schadenszahlen steigen auf.
 * Die Spiellogik bleibt rundenbasiert – das hier ist nur die Darstellung.
 */
interface Tween {
  from: Pos;
  to: Pos;
  start: number;
  dur: number;
}

interface Shot {
  from: Pos;
  to: Pos;
  start: number;
  dur: number;
  style: ProjectileStyle;
}

interface Floater {
  at: Pos;
  text: string;
  color: string;
  start: number;
  dur: number;
}

export const STEP_MS = 125;

const ease = (t: number) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);
const lerp = (a: Pos, b: Pos, t: number): Pos => ({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t });

export class Animator {
  private tweens = new Map<string, Tween>();
  private shots: Shot[] = [];
  private floaters: Floater[] = [];
  private cam: Pos | null = null;

  /** Positionen aller Figuren vor einer Aktion festhalten. */
  snapshot(s: GameState): Map<string, Pos> {
    const out = new Map<string, Pos>();
    out.set('p', { ...s.player.pos });
    if (s.player.pet) out.set('pet', { ...s.player.pet.pos });
    for (const m of s.monsters) out.set(m.uid, { ...m.pos });
    for (const c of s.crawlers ?? []) out.set(c.uid, { ...c.pos });
    return out;
  }

  /** Nach einer Aktion: Bewegungen weich machen und Effekte starten. */
  after(s: GameState, before: Map<string, Pos>, fx: Fx[], now = performance.now()) {
    const current = this.snapshot(s);
    for (const [key, to] of current) {
      const prev = this.drawPos(key, before.get(key) ?? to, now);
      const from = before.get(key);
      if (!from || (from.x === to.x && from.y === to.y)) continue;
      const jump = Math.max(Math.abs(to.x - from.x), Math.abs(to.y - from.y));
      if (jump > 3) {
        this.tweens.delete(key); // Teleport oder Etagenwechsel: kein Gleiten
        continue;
      }
      this.tweens.set(key, { from: prev, to: { ...to }, start: now, dur: STEP_MS * Math.min(2, jump) });
    }
    if (Math.max(Math.abs((before.get('p')?.x ?? 0) - s.player.pos.x), Math.abs((before.get('p')?.y ?? 0) - s.player.pos.y)) > 3) this.cam = null;
    let delay = 0;
    for (const f of fx) {
      if (f.kind === 'shot') {
        const dist = Math.hypot(f.to.x - f.from.x, f.to.y - f.from.y);
        const dur = Math.max(120, dist * 45);
        this.shots.push({ from: f.from, to: f.to, start: now + delay, dur, style: f.style as ProjectileStyle });
        delay += 60;
      } else {
        this.floaters.push({ at: { ...f.at }, text: f.text, color: f.color, start: now + delay, dur: 900 });
      }
    }
  }

  private drawPos(key: string, fallback: Pos, now: number): Pos {
    const t = this.tweens.get(key);
    if (!t) return fallback;
    const k = Math.min(1, (now - t.start) / t.dur);
    if (k >= 1) {
      this.tweens.delete(key);
      return t.to;
    }
    return lerp(t.from, t.to, ease(k));
  }

  /** Läuft gerade noch eine Bewegung des Spielers? */
  playerMoving(now = performance.now()): number {
    const t = this.tweens.get('p');
    return t ? Math.max(0, 1 - (now - t.start) / t.dur) : 0;
  }

  busy(now = performance.now()): boolean {
    return this.tweens.size > 0 || this.shots.some((s) => now < s.start + s.dur) || this.floaters.some((f) => now < f.start + f.dur);
  }

  reset() {
    this.tweens.clear();
    this.shots = [];
    this.floaters = [];
    this.cam = null;
  }

  frame(s: GameState, now = performance.now()): Anim {
    const player = this.drawPos('p', s.player.pos, now);
    // Kamera gleitet dem Spieler hinterher
    if (!this.cam) this.cam = { ...player };
    this.cam = lerp(this.cam, player, 0.25);
    if (Math.abs(this.cam.x - player.x) < 0.01 && Math.abs(this.cam.y - player.y) < 0.01) this.cam = { ...player };

    const projectiles: DrawProjectile[] = [];
    this.shots = this.shots.filter((sh) => now < sh.start + sh.dur);
    for (const sh of this.shots) {
      if (now < sh.start) continue;
      const k = (now - sh.start) / sh.dur;
      const p = lerp(sh.from, sh.to, k);
      // Würfe fliegen im Bogen, Pfeile und Zauber gerade
      const arc = sh.style === 'stein' || sh.style === 'bombe' || sh.style === 'schleim' ? Math.sin(k * Math.PI) * 0.6 : 0;
      const trail: Pos[] = [];
      for (let j = 4; j >= 1; j--) {
        const kk = Math.max(0, k - j * 0.06);
        const tp = lerp(sh.from, sh.to, kk);
        trail.push({ x: tp.x, y: tp.y - Math.sin(kk * Math.PI) * (arc ? 0.6 : 0) });
      }
      projectiles.push({
        x: p.x, y: p.y - arc,
        angle: Math.atan2(sh.to.y - sh.from.y, sh.to.x - sh.from.x) + (sh.style === 'stein' || sh.style === 'bombe' ? k * 6 : 0),
        style: sh.style, trail,
      });
    }
    const floaters: DrawFloater[] = [];
    this.floaters = this.floaters.filter((f) => now < f.start + f.dur);
    for (const f of this.floaters) {
      if (now < f.start) continue;
      const k = (now - f.start) / f.dur;
      floaters.push({ x: f.at.x, y: f.at.y - 0.2 - k * 0.9, text: f.text, color: f.color, alpha: k < 0.7 ? 1 : 1 - (k - 0.7) / 0.3 });
    }
    return {
      cam: this.cam,
      pos: (key, fallback) => this.drawPos(key, fallback, now),
      projectiles,
      floaters,
      time: now,
    };
  }
}
