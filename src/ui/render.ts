import { RARITY_COLORS } from '../data/items';
import { hasUnlock, visibleTiles } from '../engine/game';
import { lichtradius } from '../engine/player';
import { describeMonster } from '../engine/identify';
import { idx, inBounds, isWalkable } from '../engine/mapgen';
import type { GameState, Pos, Room, TrapKind } from '../engine/types';

export const TILE = 24;

export interface View {
  /** Linke obere Ecke der Kamera in Kachelkoordinaten (mit Nachkommastellen). */
  ox: number;
  oy: number;
  cols: number;
  rows: number;
}

/** Laufende Animationen: Positionen zwischen zwei Feldern, Geschosse, Zahlen. */
export interface Anim {
  /** Kamera-Mittelpunkt (Kachelkoordinaten, fließend). */
  cam: Pos;
  /** Aktuelle Zeichenposition einer Figur (Schlüssel z. B. „p“, Monster-UID). */
  pos: (key: string, fallback: Pos) => Pos;
  projectiles: DrawProjectile[];
  floaters: DrawFloater[];
  /** Zeit in ms (für Flackern, Glühen). */
  time: number;
}

export interface DrawProjectile {
  x: number;
  y: number;
  angle: number;
  style: ProjectileStyle;
  trail: Pos[];
}

export type ProjectileStyle = 'stein' | 'pfeil' | 'magie' | 'feuer' | 'schleim' | 'bombe' | 'blitz';

export interface DrawFloater {
  x: number;
  y: number;
  text: string;
  color: string;
  alpha: number;
}

export function computeView(s: GameState, canvas: HTMLCanvasElement, anim?: Anim): View {
  const cols = canvas.clientWidth / TILE;
  const rows = canvas.clientHeight / TILE;
  const c = anim?.cam ?? s.player.pos;
  // Kamera folgt dem Spieler (der Punkt bleibt in der Mitte)
  return { ox: c.x + 0.5 - cols / 2, oy: c.y + 0.5 - rows / 2, cols: Math.ceil(cols), rows: Math.ceil(rows) };
}

export function tileFromMouse(view: View, canvas: HTMLCanvasElement, ev: MouseEvent): Pos {
  const r = canvas.getBoundingClientRect();
  return {
    x: Math.floor((ev.clientX - r.left) / TILE + view.ox),
    y: Math.floor((ev.clientY - r.top) / TILE + view.oy),
  };
}

export interface RenderExtras {
  hover: Pos | null;
  path: Pos[] | null;
}

// ================================================================ Texturen

type Material =
  | 'pflaster' | 'dielen' | 'fliesen' | 'beton' | 'ziegelboden' | 'teppich' | 'marmor' | 'blutstein' | 'arena';

const texCache = new Map<string, HTMLCanvasElement>();

/** Deterministischer Zufall je Kachel (damit sich nichts beim Neuzeichnen verändert). */
function hash(x: number, y: number, salt = 0): number {
  let h = (x * 374761393 + y * 668265263 + salt * 2147483647) | 0;
  h = (h ^ (h >>> 13)) * 1274126177;
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}

function texture(key: string, draw: (c: CanvasRenderingContext2D, T: number) => void): HTMLCanvasElement {
  const dpr = window.devicePixelRatio || 1;
  const full = `${key}@${dpr}`;
  let c = texCache.get(full);
  if (c) return c;
  c = document.createElement('canvas');
  c.width = Math.round(TILE * dpr);
  c.height = Math.round(TILE * dpr);
  const ctx = c.getContext('2d')!;
  ctx.scale(dpr, dpr);
  draw(ctx, TILE);
  texCache.set(full, c);
  return c;
}

const shade = (hex: string, f: number) => {
  const n = parseInt(hex.slice(1), 16);
  const r = Math.min(255, Math.max(0, Math.round(((n >> 16) & 255) * f)));
  const g = Math.min(255, Math.max(0, Math.round(((n >> 8) & 255) * f)));
  const b = Math.min(255, Math.max(0, Math.round((n & 255) * f)));
  return `rgb(${r},${g},${b})`;
};

function floorTexture(mat: Material, v: number): HTMLCanvasElement {
  return texture(`f:${mat}:${v}`, (c, T) => {
    const rnd = (k: number) => hash(v * 31 + k, k * 7 + v, 99);
    switch (mat) {
      case 'pflaster': {
        c.fillStyle = '#1d1915';
        c.fillRect(0, 0, T, T);
        const stones = [[1, 1, 11, 10], [13, 1, 10, 7], [13, 9, 10, 14], [1, 12, 11, 11]];
        stones.forEach(([x, y, w, h], k) => {
          const base = 0.85 + rnd(k) * 0.35;
          c.fillStyle = shade('#3a332b', base);
          c.beginPath();
          c.roundRect(x, y, w, h, 3);
          c.fill();
          c.fillStyle = 'rgba(255,240,210,0.06)';
          c.fillRect(x + 1, y + 1, w - 2, 2);
        });
        break;
      }
      case 'dielen': {
        c.fillStyle = '#2a1d13';
        c.fillRect(0, 0, T, T);
        for (let k = 0; k < 3; k++) {
          const y = k * 8;
          c.fillStyle = shade('#5a4029', 0.8 + rnd(k) * 0.35);
          c.fillRect(0, y, T, 7);
          c.strokeStyle = 'rgba(30,18,8,0.45)';
          c.lineWidth = 0.6;
          c.beginPath();
          c.moveTo(0, y + 2 + rnd(k + 5) * 3);
          c.bezierCurveTo(8, y + 1, 16, y + 5, T, y + 3);
          c.stroke();
          const cut = 4 + Math.floor(rnd(k + 9) * 16);
          c.fillStyle = '#20160d';
          c.fillRect(cut, y, 1, 7);
          c.fillStyle = 'rgba(0,0,0,0.5)';
          c.fillRect(cut + 2, y + 3, 1, 1);
        }
        break;
      }
      case 'fliesen': {
        c.fillStyle = '#1e2124';
        c.fillRect(0, 0, T, T);
        for (let yy = 0; yy < 2; yy++) for (let xx = 0; xx < 2; xx++) {
          c.fillStyle = shade((xx + yy) % 2 ? '#4a5157' : '#3c4247', 0.9 + rnd(xx * 2 + yy) * 0.2);
          c.fillRect(xx * 12 + 1, yy * 12 + 1, 10, 10);
          c.fillStyle = 'rgba(255,255,255,0.07)';
          c.fillRect(xx * 12 + 1, yy * 12 + 1, 10, 1);
        }
        if (rnd(7) > 0.7) {
          c.strokeStyle = 'rgba(0,0,0,0.5)';
          c.beginPath();
          c.moveTo(3, 4);
          c.lineTo(9, 9);
          c.lineTo(8, 14);
          c.stroke();
        }
        break;
      }
      case 'beton': {
        c.fillStyle = shade('#3b3833', 0.9 + rnd(1) * 0.15);
        c.fillRect(0, 0, T, T);
        for (let k = 0; k < 18; k++) {
          c.fillStyle = rnd(k + 20) > 0.5 ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.18)';
          c.fillRect(rnd(k) * T, rnd(k + 40) * T, 1, 1);
        }
        if (rnd(3) > 0.75) {
          c.fillStyle = 'rgba(15,12,8,0.35)';
          c.beginPath();
          c.ellipse(8 + rnd(4) * 8, 8 + rnd(5) * 8, 5, 3, rnd(6) * 3, 0, Math.PI * 2);
          c.fill();
        }
        c.strokeStyle = 'rgba(0,0,0,0.25)';
        c.strokeRect(0.5, 0.5, T - 1, T - 1);
        break;
      }
      case 'ziegelboden': {
        c.fillStyle = '#2b1712';
        c.fillRect(0, 0, T, T);
        for (let row = 0; row < 4; row++) {
          const off = row % 2 ? 6 : 0;
          for (let col = -1; col < 3; col++) {
            c.fillStyle = shade('#6a3a2a', 0.75 + rnd(row * 4 + col + 3) * 0.35);
            c.fillRect(col * 12 + off + 1, row * 6 + 1, 10, 4);
          }
        }
        break;
      }
      case 'teppich': {
        c.fillStyle = '#3d2a22';
        c.fillRect(0, 0, T, T);
        c.fillStyle = '#5a2f2a';
        c.fillRect(2, 2, T - 4, T - 4);
        c.strokeStyle = '#b08a4a';
        c.lineWidth = 1;
        c.strokeRect(4.5, 4.5, T - 9, T - 9);
        c.fillStyle = '#b08a4a';
        c.beginPath();
        c.moveTo(T / 2, 7);
        c.lineTo(T - 7, T / 2);
        c.lineTo(T / 2, T - 7);
        c.lineTo(7, T / 2);
        c.closePath();
        c.globalAlpha = 0.35;
        c.fill();
        c.globalAlpha = 1;
        break;
      }
      case 'marmor': {
        c.fillStyle = shade('#26324a', 0.95 + rnd(2) * 0.1);
        c.fillRect(0, 0, T, T);
        c.strokeStyle = 'rgba(190,210,255,0.18)';
        c.lineWidth = 0.8;
        c.beginPath();
        c.moveTo(0, rnd(1) * T);
        c.bezierCurveTo(T * 0.3, rnd(2) * T, T * 0.6, rnd(3) * T, T, rnd(4) * T);
        c.stroke();
        c.strokeStyle = 'rgba(0,0,0,0.35)';
        c.strokeRect(0.5, 0.5, T - 1, T - 1);
        break;
      }
      case 'blutstein': {
        c.fillStyle = '#1a0c0b';
        c.fillRect(0, 0, T, T);
        const stones = [[1, 1, 13, 9], [15, 1, 8, 12], [1, 11, 9, 12], [11, 14, 12, 9]];
        stones.forEach(([x, y, w, h], k) => {
          c.fillStyle = shade('#4a2320', 0.8 + rnd(k) * 0.4);
          c.beginPath();
          c.roundRect(x, y, w, h, 2);
          c.fill();
        });
        if (rnd(9) > 0.6) {
          c.fillStyle = 'rgba(120,10,10,0.45)';
          c.beginPath();
          c.ellipse(12, 12, 4 + rnd(3) * 3, 2.5, rnd(4) * 3, 0, Math.PI * 2);
          c.fill();
        }
        break;
      }
      case 'arena': {
        c.fillStyle = shade('#5a4430', 0.9 + rnd(1) * 0.15);
        c.fillRect(0, 0, T, T);
        for (let k = 0; k < 24; k++) {
          c.fillStyle = rnd(k) > 0.5 ? 'rgba(255,230,190,0.08)' : 'rgba(40,20,10,0.2)';
          c.fillRect(rnd(k + 3) * T, rnd(k + 60) * T, 1.5, 1.5);
        }
        break;
      }
    }
  });
}

function wallTexture(v: number, face: boolean): HTMLCanvasElement {
  return texture(`w:${v}:${face ? 1 : 0}`, (c, T) => {
    const rnd = (k: number) => hash(v * 17 + k, k * 13 + v, 7);
    // Mauerkrone (von oben gesehen): dunkler Naturstein
    c.fillStyle = '#16130f';
    c.fillRect(0, 0, T, T);
    for (let k = 0; k < 6; k++) {
      c.fillStyle = shade('#26211b', 0.85 + rnd(k) * 0.3);
      c.fillRect(Math.floor(rnd(k + 10) * (T - 8)), Math.floor(rnd(k + 20) * (T - 6)), 8, 6);
    }
    if (!face) return;
    // Sichtbare Mauerseite zum Raum hin: große, helle Steinquader
    const top = Math.round(T * 0.38);
    c.fillStyle = '#2a241d';
    c.fillRect(0, top, T, T - top);
    const rows = 2;
    const rh = (T - top) / rows;
    for (let row = 0; row < rows; row++) {
      const off = row % 2 ? 7 : 0;
      for (let col = -1; col < 2; col++) {
        const x = col * 14 + off;
        c.fillStyle = shade('#7d7162', 0.78 + rnd(row * 3 + col + 30) * 0.3);
        c.fillRect(x + 1, top + row * rh + 1, 13, rh - 1.5);
        c.fillStyle = 'rgba(255,245,225,0.12)';
        c.fillRect(x + 1, top + row * rh + 1, 13, 1);
      }
    }
    // Kante der Mauerkrone
    c.fillStyle = '#9a8c78';
    c.fillRect(0, top - 1, T, 2);
    const g = c.createLinearGradient(0, top, 0, T);
    g.addColorStop(0, 'rgba(0,0,0,0)');
    g.addColorStop(1, 'rgba(0,0,0,0.35)');
    c.fillStyle = g;
    c.fillRect(0, top, T, T - top);
  });
}

function doorTexture(open: boolean, horizontal: boolean): HTMLCanvasElement {
  return texture(`d:${open ? 1 : 0}:${horizontal ? 1 : 0}`, (c, T) => {
    c.save();
    if (!horizontal) {
      c.translate(T / 2, T / 2);
      c.rotate(Math.PI / 2);
      c.translate(-T / 2, -T / 2);
    }
    // Schwelle
    c.fillStyle = '#2a2018';
    c.fillRect(0, 0, T, T);
    c.fillStyle = '#4a3b2c';
    c.fillRect(0, T / 2 - 3, T, 6);
    // Zarge links und rechts
    c.fillStyle = '#3b2c1e';
    c.fillRect(0, T / 2 - 5, 3, 10);
    c.fillRect(T - 3, T / 2 - 5, 3, 10);
    if (!open) {
      // Türblatt: Bretter mit Metallbändern und Klinke
      c.fillStyle = '#8a5a2c';
      c.fillRect(3, T / 2 - 5, T - 6, 10);
      c.strokeStyle = 'rgba(40,22,10,0.8)';
      c.lineWidth = 0.8;
      for (let x = 7; x < T - 4; x += 4) {
        c.beginPath();
        c.moveTo(x, T / 2 - 4);
        c.lineTo(x, T / 2 + 4);
        c.stroke();
      }
      c.fillStyle = '#9a8a70';
      c.fillRect(3, T / 2 - 3, T - 6, 1.2);
      c.fillRect(3, T / 2 + 2, T - 6, 1.2);
      c.fillStyle = '#e0c060';
      c.beginPath();
      c.arc(T - 7, T / 2, 1.5, 0, Math.PI * 2);
      c.fill();
    } else {
      // Offen: Türblatt steht aufgeklappt an der Zarge
      c.fillStyle = '#7a5230';
      c.fillRect(3, T / 2 - 4 - 9, 3, 12);
      c.fillStyle = '#e0c060';
      c.fillRect(3.5, T / 2 - 11, 2, 1.5);
    }
    c.restore();
  });
}

function roomMaterial(r: Room | null): Material {
  if (!r) return 'pflaster';
  switch (r.kind) {
    case 'safe': return 'teppich';
    case 'guild': return 'marmor';
    case 'boss': return 'blutstein';
    case 'arena': return 'arena';
    case 'start': return 'beton';
    default: {
      const n = r.name.toLowerCase();
      if (/bad|dusch|wasch|küche|kueche|toilette|sauna|labor/.test(n)) return 'fliesen';
      if (/werkstatt|lager|garage|heizung|tank|schacht|bunker/.test(n)) return 'beton';
      if (/wein|gewölbe|kapelle|gruft|brunnen|ofen/.test(n)) return 'ziegelboden';
      const pool: Material[] = ['dielen', 'beton', 'fliesen', 'ziegelboden', 'dielen'];
      return pool[r.id % pool.length];
    }
  }
}

// ================================================================ Zeichnen

export function render(
  s: GameState, canvas: HTMLCanvasElement, extras: RenderExtras, anim?: Anim,
): { view: View; visible: Set<number> } {
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
  }
  const ctx = canvas.getContext('2d')!;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = '#040302';
  ctx.fillRect(0, 0, w, h);

  const view = computeView(s, canvas, anim);
  const vis = visibleTiles(s);
  const memory = hasUnlock(s, 'minimap');
  const m = s.map;
  const time = anim?.time ?? 0;
  const sx = (x: number) => Math.round((x - view.ox) * TILE);
  const sy = (y: number) => Math.round((y - view.oy) * TILE);
  const at = (key: string, p: Pos) => (anim ? anim.pos(key, p) : p);
  const known = (i: number) => vis.has(i) || (memory && m.explored[i]);

  const x0 = Math.max(0, Math.floor(view.ox) - 1);
  const y0 = Math.max(0, Math.floor(view.oy) - 1);
  const x1 = Math.min(m.width, Math.ceil(view.ox + view.cols) + 1);
  const y1 = Math.min(m.height, Math.ceil(view.oy + view.rows) + 1);

  // --- Böden, Treppen, Türen
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = idx(m, x, y);
      if (!known(i)) continue;
      const tile = m.tiles[i];
      if (tile === 'wall') continue;
      const px = sx(x);
      const py = sy(y);
      const room = m.roomAt[i] >= 0 ? m.rooms[m.roomAt[i]] : null;
      ctx.drawImage(floorTexture(roomMaterial(room), Math.floor(hash(x, y) * 4)), px, py, TILE, TILE);
      // Einrichtung an den Wänden normaler Räume (nur Dekoration)
      if (room && room.kind === 'normal' && tile === 'floor' && hash(x, y, 5) < 0.09) {
        const wallN = !isWalkable(m, x, y - 1) && m.tiles[idx(m, x, y - 1)] === 'wall';
        const wallW = !isWalkable(m, x - 1, y) && m.tiles[idx(m, x - 1, y)] === 'wall';
        const wallE = !isWalkable(m, x + 1, y) && m.tiles[idx(m, x + 1, y)] === 'wall';
        if (wallN || wallW || wallE) drawProp(ctx, px, py, Math.floor(hash(x, y, 6) * 5));
      }
      if (tile === 'stairs') drawStairs(ctx, px, py, vis.has(i));
      if (tile === 'door' || tile === 'dooropen') {
        const horizontal = !isWalkable(m, x - 1, y) && m.tiles[idx(m, x - 1, y)] !== 'door';
        ctx.drawImage(doorTexture(tile === 'dooropen', horizontal), px, py, TILE, TILE);
      }
    }
  }

  // --- Wände mit Vorderseite und Schattenwurf auf den Boden darunter
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = idx(m, x, y);
      if (m.tiles[i] !== 'wall' || !known(i)) continue;
      let edge = false;
      for (let dy = -1; dy <= 1 && !edge; dy++) for (let dx = -1; dx <= 1 && !edge; dx++) {
        if (inBounds(m, x + dx, y + dy) && m.tiles[idx(m, x + dx, y + dy)] !== 'wall') edge = true;
      }
      if (!edge) continue;
      const below = inBounds(m, x, y + 1) && m.tiles[idx(m, x, y + 1)] !== 'wall';
      const px = sx(x);
      const py = sy(y);
      ctx.drawImage(wallTexture(Math.floor(hash(x, y, 3) * 4), below), px, py, TILE, TILE);
      if (below && known(idx(m, x, y + 1))) {
        const g = ctx.createLinearGradient(0, py + TILE, 0, py + TILE + 7);
        g.addColorStop(0, 'rgba(0,0,0,0.45)');
        g.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = g;
        ctx.fillRect(px, py + TILE, TILE, 7);
      }
    }
  }

  // --- Erinnerung (nicht im Sichtfeld): stark abgedunkelt
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = idx(m, x, y);
      if (!known(i) || vis.has(i)) continue;
      ctx.fillStyle = 'rgba(6,5,8,0.6)';
      ctx.fillRect(sx(x), sy(y), TILE, TILE);
    }
  }

  // --- Pfadvorschau
  if (extras.path) {
    for (const [k, p] of extras.path.entries()) {
      ctx.fillStyle = `rgba(255, 204, 51, ${Math.max(0.12, 0.5 - k * 0.02)})`;
      ctx.beginPath();
      ctx.arc(sx(p.x) + TILE / 2, sy(p.y) + TILE / 2, 2.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // --- Bekannte Fallen
  for (const tr of s.traps ?? []) {
    if (tr.hidden) continue;
    const i = idx(m, tr.pos.x, tr.pos.y);
    if (!known(i)) continue;
    ctx.globalAlpha = vis.has(i) ? 1 : 0.45;
    drawTrap(ctx, tr.kind, sx(tr.pos.x), sy(tr.pos.y), tr.owner === 'crawler');
    ctx.globalAlpha = 1;
  }

  // --- Gegenstände
  for (const e of s.items) {
    const i = idx(m, e.pos.x, e.pos.y);
    if (!known(i)) continue;
    const cx = sx(e.pos.x) + TILE / 2;
    const cy = sy(e.pos.y) + TILE / 2;
    ctx.globalAlpha = vis.has(i) ? 1 : 0.35;
    if (e.item.kind === 'gold') drawCoins(ctx, cx, cy);
    else if (e.item.kind === 'karte') drawScroll(ctx, cx, cy);
    else {
      const col = RARITY_COLORS[e.item.rarity];
      if (vis.has(i) && e.item.rarity !== 'gewoehnlich') {
        const g = ctx.createRadialGradient(cx, cy, 1, cx, cy, 10);
        g.addColorStop(0, col + '88');
        g.addColorStop(1, col + '00');
        ctx.fillStyle = g;
        ctx.fillRect(cx - 10, cy - 10, 20, 20);
      }
      ctx.fillStyle = 'rgba(0,0,0,0.5)';
      ctx.beginPath();
      ctx.ellipse(cx, cy + 5, 5, 2, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.moveTo(cx, cy - 6);
      ctx.lineTo(cx + 5, cy);
      ctx.lineTo(cx, cy + 5);
      ctx.lineTo(cx - 5, cy);
      ctx.closePath();
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.5)';
      ctx.beginPath();
      ctx.moveTo(cx, cy - 6);
      ctx.lineTo(cx + 2, cy - 2);
      ctx.lineTo(cx - 2, cy - 2);
      ctx.closePath();
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // --- Andere Crawler (nur sichtbare)
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (const c of s.crawlers ?? []) {
    if (!c.alive || !vis.has(idx(m, c.pos.x, c.pos.y))) continue;
    const p = at(c.uid, c.pos);
    const cx = sx(p.x) + TILE / 2;
    const cy = sy(p.y) + TILE / 2;
    drawToken(ctx, cx, cy, 7, c.party ? '#8fe38f' : '#7cc4ff', '#10161c');
    ctx.fillStyle = c.party ? '#8fe38f' : '#7cc4ff';
    ctx.font = 'bold 10px Montserrat, sans-serif';
    ctx.fillText(c.name.charAt(0), cx, cy + 0.5);
    if (c.hp < c.maxHp) healthBar(ctx, sx(p.x), sy(p.y), c.hp / c.maxHp, '#6ee07a');
  }

  // --- Monster (nur sichtbare)
  for (const mo of s.monsters) {
    if (!vis.has(idx(m, mo.pos.x, mo.pos.y))) continue;
    const p = at(mo.uid, mo.pos);
    const cx = sx(p.x) + TILE / 2;
    const cy = sy(p.y) + TILE / 2;
    const boss = mo.rank !== 'normal' && mo.rank !== 'elite';
    const info = describeMonster(s, mo);
    const unknown = info.insight >= 3;
    const color = unknown ? '#9a9080' : mo.color;
    const r = boss ? TILE / 2 : mo.size === 'winzig' ? 6.5 : mo.size === 'klein' ? 8 : mo.size === 'gross' || mo.size === 'riesig' ? 11 : 9.5;
    if (mo.aware && !mo.asleep) {
      // Pulsierender roter Rand: dieser Gegner ist hinter dir her
      const pulse = 0.35 + 0.25 * Math.sin(time / 180);
      ctx.strokeStyle = `rgba(255,70,50,${pulse})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(cx, cy, r + 3, 0, Math.PI * 2);
      ctx.stroke();
    }
    drawToken(ctx, cx, cy, r, color, mo.rank === 'elite' ? '#2a0808' : '#140d0a', boss ? 3 : 2);
    ctx.fillStyle = color;
    ctx.font = `bold ${boss ? 14 : r < 8 ? 10 : 12}px Montserrat, sans-serif`;
    ctx.fillText(unknown ? '?' : mo.glyph, cx, cy + 1);
    if (mo.hp < mo.maxHp && info.showHealthBar) healthBar(ctx, sx(p.x), sy(p.y) - 4, mo.hp / mo.maxHp, '#ff5a4a');
    // Stufenmarke unten links: Farbe zeigt die Herausforderung
    ctx.fillStyle = 'rgba(0,0,0,0.75)';
    ctx.beginPath();
    ctx.arc(cx - r + 1, cy + r - 1, 5.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = info.challenge.color;
    ctx.font = 'bold 8px Montserrat, sans-serif';
    ctx.fillText(info.insight <= 1 ? String(mo.level) : '?', cx - r + 1, cy + r - 0.5);
    ctx.font = 'bold 10px Montserrat, sans-serif';
    if (mo.asleep) {
      ctx.fillStyle = '#9fc4ff';
      const bob = Math.sin(time / 400) * 2;
      ctx.fillText('z', sx(p.x) + TILE - 2, sy(p.y) + 3 + bob);
      ctx.fillText('z', sx(p.x) + TILE + 3, sy(p.y) - 2 + bob);
    } else if (mo.downed > 0) {
      ctx.fillStyle = '#7cc4ff';
      ctx.fillText('am Boden', cx, sy(p.y) + TILE + 4);
    } else if (mo.fleeing) {
      ctx.fillStyle = '#ffd24a';
      ctx.fillText('flieht', cx, sy(p.y) + TILE + 4);
    }
  }

  // --- Haustier
  const pet = s.player.pet;
  if (pet?.alive) {
    const p = at('pet', pet.pos);
    drawToken(ctx, sx(p.x) + TILE / 2, sy(p.y) + TILE / 2, 6, '#ffb3e6', '#2a1422');
  }

  // --- Spieler: ein leuchtender Punkt
  const pp = at('p', s.player.pos);
  const px = sx(pp.x) + TILE / 2;
  const py = sy(pp.y) + TILE / 2;
  const glow = ctx.createRadialGradient(px, py, 2, px, py, TILE * 1.3);
  glow.addColorStop(0, 'rgba(255, 220, 90, 0.5)');
  glow.addColorStop(1, 'rgba(255, 220, 90, 0)');
  ctx.fillStyle = glow;
  ctx.fillRect(px - TILE * 1.3, py - TILE * 1.3, TILE * 2.6, TILE * 2.6);
  if (s.player.riding && s.player.mount && !s.player.mount.down) {
    ctx.fillStyle = '#6b4a2a';
    ctx.beginPath();
    ctx.ellipse(px, py + 3, 11, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#c98a4b';
    ctx.lineWidth = 2;
    ctx.stroke();
  }
  ctx.fillStyle = 'rgba(0,0,0,0.5)';
  ctx.beginPath();
  ctx.ellipse(px, py + 6, 6, 2.5, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = s.player.buffs.some((b) => b.name === 'Vergiftet') ? '#9be04a' : '#ffdc5a';
  ctx.beginPath();
  ctx.arc(px, py, 6.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#fff5cc';
  ctx.lineWidth = 2;
  ctx.stroke();
  const dir = s.player.lastMoveDir;
  if (dir && (dir.x || dir.y)) {
    const len = Math.hypot(dir.x, dir.y);
    ctx.fillStyle = '#fff5cc';
    ctx.beginPath();
    ctx.arc(px + (dir.x / len) * 9, py + (dir.y / len) * 9, 1.8, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.lineWidth = 1;

  // --- Licht: weicher Lichtkegel um den Crawler, warmer Schein
  const radius = lichtradius(s) * TILE;
  const flicker = 1 + Math.sin(time / 90) * 0.012 + Math.sin(time / 37) * 0.008;
  const dark = ctx.createRadialGradient(px, py, radius * 0.35 * flicker, px, py, radius * 1.02 * flicker);
  dark.addColorStop(0, 'rgba(0,0,0,0)');
  dark.addColorStop(0.75, 'rgba(0,0,0,0.16)');
  dark.addColorStop(1, 'rgba(0,0,0,0.42)');
  ctx.fillStyle = dark;
  ctx.fillRect(0, 0, w, h);
  ctx.globalCompositeOperation = 'lighter';
  const warm = ctx.createRadialGradient(px, py, 0, px, py, radius * 0.7);
  warm.addColorStop(0, 'rgba(90,55,15,0.16)');
  warm.addColorStop(1, 'rgba(90,55,15,0)');
  ctx.fillStyle = warm;
  ctx.fillRect(px - radius, py - radius, radius * 2, radius * 2);
  ctx.globalCompositeOperation = 'source-over';

  // --- Geschosse und schwebende Zahlen
  for (const pr of anim?.projectiles ?? []) drawProjectile(ctx, pr, sx, sy);
  ctx.font = 'bold 13px Montserrat, sans-serif';
  for (const f of anim?.floaters ?? []) {
    ctx.globalAlpha = f.alpha;
    ctx.fillStyle = '#000';
    ctx.fillText(f.text, sx(f.x) + TILE / 2 + 1, sy(f.y) + 1);
    ctx.fillStyle = f.color;
    ctx.fillText(f.text, sx(f.x) + TILE / 2, sy(f.y));
  }
  ctx.globalAlpha = 1;

  // --- Hover-Rahmen
  if (extras.hover) {
    ctx.strokeStyle = 'rgba(255, 204, 51, 0.85)';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(sx(extras.hover.x) + 0.5, sy(extras.hover.y) + 0.5, TILE - 1, TILE - 1);
  }

  return { view, visible: vis };
}

/** Kisten, Fässer, Regale, Gerümpel. */
function drawProp(ctx: CanvasRenderingContext2D, px: number, py: number, kind: number) {
  const T = TILE;
  ctx.fillStyle = 'rgba(0,0,0,0.35)';
  ctx.fillRect(px + 4, py + T - 6, T - 8, 3);
  switch (kind) {
    case 0: // Holzkiste
      ctx.fillStyle = '#6b4a2a';
      ctx.fillRect(px + 5, py + 6, T - 10, T - 11);
      ctx.strokeStyle = '#3a2614';
      ctx.strokeRect(px + 5.5, py + 6.5, T - 11, T - 12);
      ctx.beginPath();
      ctx.moveTo(px + 6, py + 7);
      ctx.lineTo(px + T - 6, py + T - 6);
      ctx.stroke();
      break;
    case 1: // Fass
      ctx.fillStyle = '#5a3a1e';
      ctx.beginPath();
      ctx.ellipse(px + T / 2, py + T / 2, 7, 8, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#8a8a8a';
      ctx.beginPath();
      ctx.ellipse(px + T / 2, py + T / 2, 7, 3, 0, 0, Math.PI * 2);
      ctx.stroke();
      break;
    case 2: // Regal
      ctx.fillStyle = '#4a3420';
      ctx.fillRect(px + 3, py + 4, T - 6, 6);
      ctx.fillStyle = '#a08a60';
      ctx.fillRect(px + 5, py + 5, 3, 4);
      ctx.fillRect(px + 10, py + 5, 4, 4);
      ctx.fillStyle = '#6a8aa0';
      ctx.fillRect(px + 16, py + 5, 3, 4);
      break;
    case 3: // Gerümpel
      ctx.fillStyle = '#5a534a';
      ctx.fillRect(px + 6, py + 12, 6, 5);
      ctx.fillStyle = '#7a6a50';
      ctx.fillRect(px + 12, py + 9, 5, 8);
      ctx.fillStyle = '#3a3a3a';
      ctx.fillRect(px + 9, py + 7, 4, 4);
      break;
    default: // Eimer
      ctx.fillStyle = '#708090';
      ctx.fillRect(px + 8, py + 9, 8, 8);
      ctx.fillStyle = '#2a3238';
      ctx.fillRect(px + 8, py + 9, 8, 2);
  }
}

function drawToken(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, ring: string, fill: string, lw = 2) {
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.beginPath();
  ctx.ellipse(cx, cy + r * 0.8, r * 0.9, r * 0.35, 0, 0, Math.PI * 2);
  ctx.fill();
  const g = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.4, 1, cx, cy, r);
  g.addColorStop(0, '#3a2f28');
  g.addColorStop(1, fill);
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = ring;
  ctx.lineWidth = lw;
  ctx.stroke();
  ctx.lineWidth = 1;
}

function healthBar(ctx: CanvasRenderingContext2D, x: number, y: number, frac: number, color: string) {
  ctx.fillStyle = 'rgba(0,0,0,0.8)';
  ctx.fillRect(x + 2, y, TILE - 4, 3);
  ctx.fillStyle = color;
  ctx.fillRect(x + 2, y, (TILE - 4) * Math.max(0, Math.min(1, frac)), 3);
}

function drawCoins(ctx: CanvasRenderingContext2D, cx: number, cy: number) {
  for (const [dx, dy] of [[-3, 2], [3, 2], [0, -1]]) {
    ctx.fillStyle = '#8a6a10';
    ctx.beginPath();
    ctx.ellipse(cx + dx, cy + dy + 1, 4, 2.2, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#ffd24a';
    ctx.beginPath();
    ctx.ellipse(cx + dx, cy + dy, 4, 2.2, 0, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawScroll(ctx: CanvasRenderingContext2D, cx: number, cy: number) {
  ctx.fillStyle = '#e8d8a8';
  ctx.fillRect(cx - 6, cy - 4, 12, 8);
  ctx.fillStyle = '#b89a5a';
  ctx.fillRect(cx - 7, cy - 5, 2, 10);
  ctx.fillRect(cx + 5, cy - 5, 2, 10);
  ctx.strokeStyle = '#7cc4ff';
  ctx.beginPath();
  ctx.moveTo(cx - 3, cy - 1);
  ctx.lineTo(cx + 3, cy + 1);
  ctx.stroke();
}

function drawTrap(ctx: CanvasRenderingContext2D, kind: TrapKind, px: number, py: number, own: boolean) {
  const cx = px + TILE / 2;
  const cy = py + TILE / 2;
  const col = own ? '#6ee07a' : '#ff5a4a';
  ctx.strokeStyle = col;
  ctx.fillStyle = col;
  ctx.lineWidth = 1.5;
  switch (kind) {
    case 'pfeilplatte':
      ctx.strokeRect(px + 4.5, py + 4.5, TILE - 9, TILE - 9);
      for (const [dx, dy] of [[-3, -3], [3, -3], [-3, 3], [3, 3]]) {
        ctx.beginPath();
        ctx.arc(cx + dx, cy + dy, 1, 0, Math.PI * 2);
        ctx.fill();
      }
      break;
    case 'fallgrube':
      ctx.fillStyle = 'rgba(0,0,0,0.75)';
      ctx.beginPath();
      ctx.ellipse(cx, cy, 8, 6, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      break;
    case 'giftgas':
      ctx.beginPath();
      ctx.arc(cx, cy, 3, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = 'rgba(140,220,90,0.35)';
      ctx.beginPath();
      ctx.arc(cx - 3, cy - 4, 4, 0, Math.PI * 2);
      ctx.arc(cx + 4, cy - 2, 3, 0, Math.PI * 2);
      ctx.fill();
      break;
    case 'stolperdraht':
      ctx.beginPath();
      ctx.moveTo(px + 2, cy + 2);
      ctx.lineTo(px + TILE - 2, cy - 2);
      ctx.stroke();
      ctx.fillRect(px + 2, cy, 3, 4);
      ctx.fillRect(px + TILE - 5, cy - 4, 3, 4);
      break;
    case 'baerenfalle':
    case 'schlingfalle':
      ctx.beginPath();
      ctx.arc(cx, cy, 7, 0, Math.PI * 2);
      ctx.stroke();
      for (let a = 0; a < 8; a++) {
        const ang = (a / 8) * Math.PI * 2;
        ctx.beginPath();
        ctx.moveTo(cx + Math.cos(ang) * 7, cy + Math.sin(ang) * 7);
        ctx.lineTo(cx + Math.cos(ang) * 4, cy + Math.sin(ang) * 4);
        ctx.stroke();
      }
      break;
    case 'stachelfalle':
      for (const [dx, dy] of [[-5, 4], [0, 4], [5, 4], [-2.5, -2], [2.5, -2]]) {
        ctx.beginPath();
        ctx.moveTo(cx + dx - 2, cy + dy);
        ctx.lineTo(cx + dx, cy + dy - 5);
        ctx.lineTo(cx + dx + 2, cy + dy);
        ctx.closePath();
        ctx.fill();
      }
      break;
    case 'sprengfalle':
      ctx.fillRect(cx - 5, cy - 3, 10, 7);
      ctx.beginPath();
      ctx.moveTo(cx + 5, cy - 3);
      ctx.quadraticCurveTo(cx + 9, cy - 8, cx + 4, cy - 9);
      ctx.stroke();
      break;
  }
  ctx.lineWidth = 1;
}

function drawProjectile(ctx: CanvasRenderingContext2D, pr: DrawProjectile, sx: (x: number) => number, sy: (y: number) => number) {
  const cx = sx(pr.x) + TILE / 2;
  const cy = sy(pr.y) + TILE / 2;
  const color = { stein: '#c8c0b0', pfeil: '#e0d0a0', magie: '#c080ff', feuer: '#ff8a2a', schleim: '#8ce04a', bombe: '#555', blitz: '#9fdcff' }[pr.style];
  // Schweif
  for (const [k, t] of pr.trail.entries()) {
    ctx.globalAlpha = ((k + 1) / pr.trail.length) * 0.35;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(sx(t.x) + TILE / 2, sy(t.y) + TILE / 2, pr.style === 'magie' || pr.style === 'feuer' ? 3.5 : 2, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
  if (pr.style === 'pfeil') {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(pr.angle);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-8, 0);
    ctx.lineTo(6, 0);
    ctx.stroke();
    ctx.fillStyle = '#ddd';
    ctx.beginPath();
    ctx.moveTo(8, 0);
    ctx.lineTo(4, -3);
    ctx.lineTo(4, 3);
    ctx.fill();
    ctx.restore();
    return;
  }
  if (pr.style === 'magie' || pr.style === 'feuer' || pr.style === 'blitz') {
    const g = ctx.createRadialGradient(cx, cy, 1, cx, cy, 10);
    g.addColorStop(0, '#fff');
    g.addColorStop(0.3, color);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(cx, cy, 10, 0, Math.PI * 2);
    ctx.fill();
    return;
  }
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(pr.angle * 3);
  ctx.fillStyle = color;
  ctx.fillRect(-3, -3, 6, 6);
  if (pr.style === 'bombe') {
    ctx.fillStyle = '#ffb040';
    ctx.fillRect(2, -5, 2, 3);
  }
  ctx.restore();
}

/**
 * Eine Treppe nach unten, von oben gesehen: ein Steinrahmen, darin Stufen,
 * die zur Tiefe hin schmaler und dunkler werden, mit zwei Handläufen.
 */
function drawStairs(ctx: CanvasRenderingContext2D, px: number, py: number, seen: boolean) {
  const T = TILE;
  if (seen) {
    const glow = ctx.createRadialGradient(px + T / 2, py + T / 2, 2, px + T / 2, py + T / 2, T);
    glow.addColorStop(0, 'rgba(255, 190, 80, 0.35)');
    glow.addColorStop(1, 'rgba(255, 190, 80, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(px - T / 2, py - T / 2, T * 2, T * 2);
  }
  ctx.fillStyle = '#6e5a42';
  ctx.fillRect(px + 1, py + 1, T - 2, T - 2);
  ctx.fillStyle = '#8a7356';
  ctx.fillRect(px + 1, py + 1, T - 2, 2);
  ctx.fillStyle = '#2a1f14';
  ctx.fillRect(px + 3, py + 3, T - 6, T - 5);
  const steps = 4;
  const inner = T - 6;
  const stepH = (T - 6) / steps;
  for (let i = 0; i < steps; i++) {
    const t = i / (steps - 1);
    const inset = i * 1.2;
    const x = px + 3 + inset;
    const w = inner - inset * 2;
    const y = py + 3 + i * stepH;
    const light = Math.round(225 - t * 90);
    ctx.fillStyle = `rgb(${light}, ${Math.round(light * 0.84)}, ${Math.round(light * 0.62)})`;
    ctx.fillRect(x, y, w, stepH - 1.2);
    ctx.fillStyle = `rgba(255, 245, 220, ${0.8 - t * 0.5})`;
    ctx.fillRect(x, y, w, 1);
    ctx.fillStyle = '#140e08';
    ctx.fillRect(x, y + stepH - 1.2, w, 1.2);
  }
  ctx.strokeStyle = '#d4a94c';
  ctx.lineWidth = 1.2;
  ctx.beginPath();
  ctx.moveTo(px + 2.5, py + 3);
  ctx.lineTo(px + 2.5 + steps * 1.2, py + T - 3);
  ctx.moveTo(px + T - 2.5, py + 3);
  ctx.lineTo(px + T - 2.5 - steps * 1.2, py + T - 3);
  ctx.stroke();
  ctx.lineWidth = 1;
}
