import { conditionList } from '../engine/conditions';
import { RARITY_COLORS } from '../data/items';
import { BOX_TIER_COLORS } from '../data/world';
import { hasUnlock, visibleTiles } from '../engine/game';
import { lichtradius } from '../engine/player';
import { describeMonster } from '../engine/identify';
import { idx, inBounds, isWalkable } from '../engine/mapgen';
import type { FurnitureKind, GameState, Item, Pos, Room, TrapKind } from '../engine/types';
import { drawHero, drawSprite, spriteFor } from './sprites';

/**
 * Die Karte als Canvas-Grafik. Alle Texturen sind prozedural (keine
 * Bilddateien) und werden je Zoomstufe einmal erzeugt und zwischengespeichert.
 * Gezeichnet wird in „Design-Einheiten“: eine Kachel ist 32 Einheiten groß,
 * egal wie groß sie auf dem Bildschirm erscheint.
 */

// ================================================================ Zoom

const ZOOM_STEPS = [22, 26, 32, 38, 46, 56];
const ZOOM_KEY = 'grosser-abstieg-zoom-v2';

function storedZoom(): number {
  try {
    const raw = localStorage.getItem(ZOOM_KEY);
    const n = raw === null ? NaN : Number(raw);
    return Number.isInteger(n) && n >= 0 && n < ZOOM_STEPS.length ? n : 3;
  } catch {
    return 3;
  }
}

let zoomIndex = storedZoom();

/** Kantenlänge einer Kachel in CSS-Pixeln (hängt vom Zoom ab). */
export let TILE = ZOOM_STEPS[zoomIndex];

/** Zoom ändern; gibt zurück, ob sich etwas geändert hat. */
export function zoom(delta: number): boolean {
  const next = Math.max(0, Math.min(ZOOM_STEPS.length - 1, zoomIndex + delta));
  if (next === zoomIndex) return false;
  zoomIndex = next;
  TILE = ZOOM_STEPS[zoomIndex];
  try {
    localStorage.setItem(ZOOM_KEY, String(zoomIndex));
  } catch {
    // Zoom gilt dann nur für diese Sitzung
  }
  return true;
}

export const zoomBounds = () => ({ min: zoomIndex === 0, max: zoomIndex === ZOOM_STEPS.length - 1 });

/** Design-Einheiten einer Kachel. */
const U = 32;

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
  /** Untersuchtes Feld (Info-Karte offen). */
  selected?: Pos | null;
}

// ================================================================ Hilfen

type Ctx = CanvasRenderingContext2D;

type Material =
  | 'pflaster' | 'dielen' | 'fliesen' | 'beton' | 'ziegelboden' | 'teppich' | 'marmor' | 'blutstein' | 'arena';

const texCache = new Map<string, HTMLCanvasElement>();

/** Deterministischer Zufall je Kachel (damit sich nichts beim Neuzeichnen verändert). */
export function hash(x: number, y: number, salt = 0): number {
  let h = (x * 374761393 + y * 668265263 + salt * 2147483647) | 0;
  h = (h ^ (h >>> 13)) * 1274126177;
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}

/** Eine Kachel-Textur in Design-Einheiten zeichnen und zwischenspeichern. */
function texture(key: string, draw: (c: Ctx) => void): HTMLCanvasElement {
  const dpr = window.devicePixelRatio || 1;
  const full = `${key}@${TILE}@${dpr}`;
  let c = texCache.get(full);
  if (c) return c;
  c = document.createElement('canvas');
  c.width = Math.round(TILE * dpr);
  c.height = Math.round(TILE * dpr);
  const ctx = c.getContext('2d')!;
  ctx.scale((TILE * dpr) / U, (TILE * dpr) / U);
  draw(ctx);
  texCache.set(full, c);
  return c;
}

const rgb = (hex: string) => {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
};

const shade = (hex: string, f: number) => {
  const [r, g, b] = rgb(hex).map((v) => Math.min(255, Math.max(0, Math.round(v * f))));
  return `rgb(${r},${g},${b})`;
};

const alpha = (hex: string, a: number) => {
  const [r, g, b] = rgb(hex);
  return `rgba(${r},${g},${b},${a})`;
};

/** Ein Stein, eine Fliese, ein Ziegel: gerundet, oben links Licht, unten rechts Schatten. */
function bevel(c: Ctx, x: number, y: number, w: number, h: number, r: number, color: string, light = 0.13, dark = 0.3) {
  c.fillStyle = color;
  c.beginPath();
  c.roundRect(x, y, w, h, r);
  c.fill();
  const g = c.createLinearGradient(x, y, x + w * 0.6, y + h);
  g.addColorStop(0, `rgba(255,244,225,${light})`);
  g.addColorStop(0.45, 'rgba(255,244,225,0)');
  g.addColorStop(1, `rgba(0,0,0,${dark})`);
  c.fillStyle = g;
  c.fill();
  c.strokeStyle = `rgba(255,244,225,${light * 0.6})`;
  c.lineWidth = 0.6;
  c.beginPath();
  c.moveTo(x + r, y + 0.5);
  c.lineTo(x + w - r, y + 0.5);
  c.stroke();
}

function specks(c: Ctx, rnd: (k: number) => number, n: number, light: number, dark: number, size = 1) {
  for (let k = 0; k < n; k++) {
    c.fillStyle = rnd(k + 100) > 0.5 ? `rgba(255,240,215,${light})` : `rgba(0,0,0,${dark})`;
    c.fillRect(rnd(k + 200) * U, rnd(k + 300) * U, size, size);
  }
}

// ================================================================ Böden

function floorTexture(mat: Material, v: number): HTMLCanvasElement {
  return texture(`f:${mat}:${v}`, (c) => {
    const rnd = (k: number) => hash(v * 31 + k, k * 7 + v, 99);
    switch (mat) {
      case 'pflaster': {
        c.fillStyle = '#15120f';
        c.fillRect(0, 0, U, U);
        const layouts = [
          [[1, 1, 15, 13], [17, 1, 14, 9], [17, 11, 14, 20], [1, 15, 9, 16], [11, 15, 5, 16]],
          [[1, 1, 10, 15], [12, 1, 19, 12], [1, 17, 14, 14], [16, 14, 15, 8], [16, 23, 15, 8]],
          [[1, 1, 19, 10], [21, 1, 10, 16], [1, 12, 12, 19], [14, 12, 6, 19], [21, 18, 10, 13]],
          [[1, 1, 13, 18], [15, 1, 16, 14], [1, 20, 17, 11], [19, 16, 12, 15], [15, 16, 3, 3]],
        ];
        layouts[v % 4].forEach(([x, y, w, h], k) => bevel(c, x, y, w, h, 3.5, shade('#4a4036', 0.82 + rnd(k) * 0.32)));
        specks(c, rnd, 26, 0.05, 0.22);
        break;
      }
      case 'dielen': {
        c.fillStyle = '#1b120b';
        c.fillRect(0, 0, U, U);
        for (let k = 0; k < 4; k++) {
          const y = k * 8;
          const tone = shade('#5e432a', 0.82 + rnd(k) * 0.3);
          c.fillStyle = tone;
          c.fillRect(0, y + 0.5, U, 7);
          // Maserung
          c.strokeStyle = 'rgba(28,16,6,0.42)';
          c.lineWidth = 0.55;
          for (let g = 0; g < 2; g++) {
            const gy = y + 2 + g * 3 + rnd(k * 3 + g) * 1.5;
            c.beginPath();
            c.moveTo(0, gy);
            c.bezierCurveTo(10, gy - 1 + rnd(k + g + 20) * 2, 22, gy + 1.5 - rnd(k + g + 30) * 2, U, gy);
            c.stroke();
          }
          c.fillStyle = 'rgba(255,225,180,0.08)';
          c.fillRect(0, y + 0.5, U, 1);
          c.fillStyle = 'rgba(0,0,0,0.3)';
          c.fillRect(0, y + 6.5, U, 1);
          // Stoßfuge mit zwei Nägeln
          const cut = 3 + Math.floor(rnd(k + 9) * 26);
          c.fillStyle = '#140c06';
          c.fillRect(cut, y + 0.5, 1, 7);
          c.fillStyle = 'rgba(200,190,170,0.35)';
          c.fillRect(cut - 2, y + 2, 1, 1);
          c.fillRect(cut + 2, y + 5, 1, 1);
          if (rnd(k + 40) > 0.8) {
            c.fillStyle = 'rgba(30,16,6,0.6)';
            c.beginPath();
            c.ellipse(4 + rnd(k + 41) * 24, y + 4, 1.6, 1, 0, 0, Math.PI * 2);
            c.fill();
          }
        }
        break;
      }
      case 'fliesen': {
        c.fillStyle = '#16191c';
        c.fillRect(0, 0, U, U);
        for (let yy = 0; yy < 2; yy++) for (let xx = 0; xx < 2; xx++) {
          const base = (xx + yy) % 2 ? '#56606a' : '#4a535b';
          bevel(c, xx * 16 + 1, yy * 16 + 1, 14, 14, 1.5, shade(base, 0.9 + rnd(xx * 2 + yy) * 0.18), 0.16, 0.22);
        }
        break;
      }
      case 'beton': {
        c.fillStyle = shade('#403c36', 0.9 + rnd(1) * 0.14);
        c.fillRect(0, 0, U, U);
        specks(c, rnd, 60, 0.05, 0.16);
        // Fugen nur alle zwei Kacheln, damit kein strenges Raster entsteht
        c.fillStyle = 'rgba(0,0,0,0.18)';
        if (v % 2) c.fillRect(U - 1, 0, 1, U);
        if (v >= 2) c.fillRect(0, U - 1, U, 1);
        c.fillStyle = 'rgba(255,245,230,0.03)';
        c.fillRect(0, 0, U, 1);
        c.fillRect(0, 0, 1, U);
        break;
      }
      case 'ziegelboden': {
        c.fillStyle = '#26140e';
        c.fillRect(0, 0, U, U);
        for (let row = 0; row < 4; row++) {
          const off = row % 2 ? 8 : 0;
          for (let col = -1; col < 2; col++) {
            bevel(c, col * 16 + off + 1, row * 8 + 1, 14, 6, 1, shade('#723f2d', 0.75 + rnd(row * 4 + col + 3) * 0.35), 0.12, 0.3);
          }
        }
        break;
      }
      case 'teppich': {
        c.fillStyle = '#5a1d22';
        c.fillRect(0, 0, U, U);
        // Gewebe
        c.strokeStyle = 'rgba(0,0,0,0.12)';
        c.lineWidth = 0.6;
        for (let d = -U; d < U; d += 3) {
          c.beginPath();
          c.moveTo(d, 0);
          c.lineTo(d + U, U);
          c.stroke();
        }
        // Ornament: Raute in der Mitte, Viertel an den Ecken ergeben ein Muster
        const gold = 'rgba(214,170,90,0.55)';
        c.fillStyle = gold;
        const diamond = (x: number, y: number, r: number) => {
          c.beginPath();
          c.moveTo(x, y - r);
          c.lineTo(x + r, y);
          c.lineTo(x, y + r);
          c.lineTo(x - r, y);
          c.closePath();
          c.fill();
        };
        diamond(16, 16, 5);
        for (const [x, y] of [[0, 0], [U, 0], [0, U], [U, U]]) diamond(x, y, 5);
        c.fillStyle = '#5a1d22';
        diamond(16, 16, 2.4);
        c.fillStyle = 'rgba(255,220,160,0.06)';
        c.fillRect(0, 0, U, U / 2);
        break;
      }
      case 'marmor': {
        c.fillStyle = '#10141c';
        c.fillRect(0, 0, U, U);
        for (let yy = 0; yy < 2; yy++) for (let xx = 0; xx < 2; xx++) {
          const x = xx * 16 + 0.5;
          const y = yy * 16 + 0.5;
          c.fillStyle = shade('#2c3850', 0.92 + rnd(xx + yy * 2) * 0.16);
          c.fillRect(x, y, 15, 15);
          c.strokeStyle = 'rgba(200,215,255,0.22)';
          c.lineWidth = 0.6;
          c.beginPath();
          c.moveTo(x, y + rnd(xx * 5 + yy) * 15);
          c.bezierCurveTo(x + 5, y + rnd(xx + 7) * 15, x + 10, y + rnd(yy + 9) * 15, x + 15, y + rnd(xx + yy + 11) * 15);
          c.stroke();
          const g = c.createLinearGradient(x, y, x + 15, y + 15);
          g.addColorStop(0, 'rgba(255,255,255,0.12)');
          g.addColorStop(0.5, 'rgba(255,255,255,0)');
          g.addColorStop(1, 'rgba(0,0,0,0.2)');
          c.fillStyle = g;
          c.fillRect(x, y, 15, 15);
        }
        break;
      }
      case 'blutstein': {
        c.fillStyle = '#120807';
        c.fillRect(0, 0, U, U);
        const stones = [[1, 1, 17, 12], [19, 1, 12, 16], [1, 14, 12, 17], [14, 18, 17, 13]];
        stones.forEach(([x, y, w, h], k) => bevel(c, x, y, w, h, 2.5, shade('#4a2420', 0.78 + rnd(k) * 0.4), 0.1, 0.35));
        if (rnd(9) > 0.55) {
          c.fillStyle = 'rgba(130,12,12,0.45)';
          c.beginPath();
          c.ellipse(16, 16, 5 + rnd(3) * 4, 3, rnd(4) * 3, 0, Math.PI * 2);
          c.fill();
        }
        c.strokeStyle = 'rgba(190,30,20,0.35)';
        c.lineWidth = 0.6;
        c.beginPath();
        c.moveTo(rnd(20) * U, 0);
        c.lineTo(rnd(21) * U, U * 0.5);
        c.lineTo(rnd(22) * U, U);
        c.stroke();
        break;
      }
      case 'arena': {
        c.fillStyle = shade('#6a5236', 0.9 + rnd(1) * 0.14);
        c.fillRect(0, 0, U, U);
        specks(c, rnd, 70, 0.09, 0.18, 1.2);
        if (rnd(5) > 0.6) {
          c.fillStyle = 'rgba(50,30,15,0.18)';
          c.beginPath();
          c.ellipse(rnd(6) * U, rnd(7) * U, 9, 5, rnd(8) * 3, 0, Math.PI * 2);
          c.fill();
        }
        break;
      }
    }
  });
}

export function roomMaterial(r: Room | null): Material {
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

// ================================================================ Wände

interface WallTheme {
  cap: string;
  capStone: string;
  face: string;
  mortar: string;
  lip: string;
  moss?: string;
}

/** Jede Etage hat ihr eigenes Mauerwerk. */
const WALL_THEMES: Record<number, WallTheme> = {
  1: { cap: '#191511', capStone: '#29231c', face: '#7b6c5a', mortar: '#2b241c', lip: '#a8977f' },
  2: { cap: '#14161a', capStone: '#232830', face: '#6c737e', mortar: '#22262c', lip: '#9aa3ae' },
  3: { cap: '#101512', capStone: '#1d2821', face: '#5d6d5e', mortar: '#1b231d', lip: '#8fa08e', moss: '#4f7a3a' },
};

const wallTheme = (floor: number) => WALL_THEMES[Math.min(3, Math.max(1, floor))];

function wallTexture(floor: number, v: number, face: boolean): HTMLCanvasElement {
  const th = wallTheme(floor);
  return texture(`w:${floor}:${v}:${face ? 1 : 0}`, (c) => {
    const rnd = (k: number) => hash(v * 17 + k, k * 13 + v, 7);
    // Mauerkrone (von oben gesehen)
    const cg = c.createLinearGradient(0, 0, U, U);
    cg.addColorStop(0, shade(th.capStone, 0.95 + rnd(1) * 0.1));
    cg.addColorStop(1, th.cap);
    c.fillStyle = cg;
    c.fillRect(0, 0, U, U);
    // Zwei große, flache Deckplatten mit feiner Fuge
    c.strokeStyle = 'rgba(0,0,0,0.35)';
    c.lineWidth = 0.8;
    c.beginPath();
    const seam = 10 + rnd(2) * 12;
    c.moveTo(seam, 0);
    c.lineTo(seam, U);
    c.stroke();
    specks(c, rnd, 22, 0.035, 0.2);
    if (!face) return;
    // Sichtbare Mauerseite zum Raum hin
    const top = 12;
    c.fillStyle = th.mortar;
    c.fillRect(0, top, U, U - top);
    const rows = 2;
    const rh = (U - top) / rows;
    for (let row = 0; row < rows; row++) {
      const off = row % 2 ? 9 : 0;
      for (let col = -1; col < 3; col++) {
        const x = col * 18 + off;
        bevel(c, x + 1, top + row * rh + 1, 16, rh - 2, 1.2, shade(th.face, 0.74 + rnd(row * 4 + col + 30) * 0.3), 0.16, 0.34);
      }
    }
    if (th.moss && rnd(50) > 0.45) {
      c.fillStyle = alpha(th.moss, 0.55);
      for (let k = 0; k < 5; k++) {
        c.beginPath();
        c.ellipse(rnd(k + 60) * U, U - 2 - rnd(k + 70) * 5, 2.5 + rnd(k + 80) * 3, 1.5, 0, 0, Math.PI * 2);
        c.fill();
      }
    }
    // Lichtkante der Mauerkrone und Schatten darunter
    c.fillStyle = th.lip;
    c.fillRect(0, top - 1.5, U, 1.5);
    c.fillStyle = 'rgba(0,0,0,0.45)';
    c.fillRect(0, top, U, 1.2);
    const g = c.createLinearGradient(0, top, 0, U);
    g.addColorStop(0, 'rgba(0,0,0,0.05)');
    g.addColorStop(1, 'rgba(0,0,0,0.42)');
    c.fillStyle = g;
    c.fillRect(0, top, U, U - top);
  });
}

/** Umgebungsverdeckung: Böden werden an Wänden weich dunkler. */
function aoTexture(side: 'n' | 's' | 'w' | 'e' | 'nw' | 'ne' | 'sw' | 'se'): HTMLCanvasElement {
  return texture(`ao:${side}`, (c) => {
    const depth = side === 'n' ? 11 : side === 's' ? 5 : 8;
    let g: CanvasGradient;
    switch (side) {
      case 'n':
        g = c.createLinearGradient(0, 0, 0, depth);
        break;
      case 's':
        g = c.createLinearGradient(0, U, 0, U - depth);
        break;
      case 'w':
        g = c.createLinearGradient(0, 0, depth, 0);
        break;
      case 'e':
        g = c.createLinearGradient(U, 0, U - depth, 0);
        break;
      default: {
        const x = side.includes('w') ? 0 : U;
        const y = side.includes('n') ? 0 : U;
        g = c.createRadialGradient(x, y, 0, x, y, 9);
      }
    }
    const strength = side === 'n' ? 0.5 : side === 's' ? 0.22 : side.length === 2 ? 0.35 : 0.38;
    g.addColorStop(0, `rgba(0,0,0,${strength})`);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    c.fillStyle = g;
    c.fillRect(0, 0, U, U);
  });
}

// ================================================================ Türen

function doorTexture(open: boolean, horizontal: boolean, boss = false): HTMLCanvasElement {
  return texture(`d:${open ? 1 : 0}:${horizontal ? 1 : 0}:${boss ? 1 : 0}`, (c) => {
    c.save();
    if (!horizontal) {
      c.translate(U / 2, U / 2);
      c.rotate(Math.PI / 2);
      c.translate(-U / 2, -U / 2);
    }
    const mid = U / 2;
    // Schwelle aus Stein
    bevel(c, 0, mid - 5, U, 10, 1, '#5a4d3e', 0.14, 0.3);
    // Zarge
    bevel(c, 0, mid - 7, 4, 14, 1, '#4a3522', 0.2, 0.4);
    bevel(c, U - 4, mid - 7, 4, 14, 1, '#4a3522', 0.2, 0.4);
    if (!open) {
      // Türblatt: Bretter, Eisenbänder, Klinke
      c.fillStyle = 'rgba(0,0,0,0.45)';
      c.fillRect(4, mid - 4, U - 8, 9);
      bevel(c, 4, mid - 5, U - 8, 9, 1, boss ? '#5a1c18' : '#8e5e2f', 0.18, 0.35);
      c.strokeStyle = 'rgba(40,20,8,0.7)';
      c.lineWidth = 0.7;
      for (let x = 9; x < U - 5; x += 5) {
        c.beginPath();
        c.moveTo(x, mid - 4.5);
        c.lineTo(x, mid + 3.5);
        c.stroke();
      }
      c.fillStyle = boss ? '#c0392b' : '#6f6a62';
      c.fillRect(5, mid - 3.2, U - 10, 1.4);
      c.fillRect(5, mid + 1.2, U - 10, 1.4);
      if (boss) {
        // Nieten und ein schweres Schloss
        c.fillStyle = '#e8b04a';
        for (let x = 7; x < U - 6; x += 4) c.fillRect(x, mid - 0.6, 1.4, 1.4);
        bevel(c, U / 2 - 3, mid - 3.5, 6, 7, 1, '#2a2a2e', 0.2, 0.4);
      }
      c.fillStyle = '#e7c46a';
      c.beginPath();
      c.arc(U - 9, mid - 0.5, 1.6, 0, Math.PI * 2);
      c.fill();
    } else {
      // Offen: das Türblatt steht aufgeklappt an der Zarge
      c.fillStyle = 'rgba(0,0,0,0.4)';
      c.fillRect(5, mid - 17, 5, 14);
      bevel(c, 4, mid - 18, 4, 15, 1, '#7e532b', 0.2, 0.35);
      c.fillStyle = '#e7c46a';
      c.fillRect(4.8, mid - 15, 2.2, 1.6);
    }
    c.restore();
  });
}

// ================================================================ Nebel

let fogCanvas: HTMLCanvasElement | null = null;

/**
 * Nebel des Krieges als kleines Bild (ein Pixel pro Kachel), das weich
 * hochskaliert wird: Kanten zwischen Sicht, Erinnerung und Dunkel verlaufen.
 */
function drawFog(ctx: Ctx, s: GameState, vis: Set<number>, memory: boolean, x0: number, y0: number, x1: number, y1: number, sx: (x: number) => number, sy: (y: number) => number) {
  const m = s.map;
  const fw = x1 - x0 + 2;
  const fh = y1 - y0 + 2;
  fogCanvas ??= document.createElement('canvas');
  if (fogCanvas.width !== fw || fogCanvas.height !== fh) {
    fogCanvas.width = fw;
    fogCanvas.height = fh;
  }
  const fctx = fogCanvas.getContext('2d')!;
  const img = fctx.createImageData(fw, fh);
  const d = img.data;
  for (let fy = 0; fy < fh; fy++) {
    for (let fx = 0; fx < fw; fx++) {
      const x = x0 - 1 + fx;
      const y = y0 - 1 + fy;
      let a = 255;
      if (inBounds(m, x, y)) {
        const i = idx(m, x, y);
        if (vis.has(i)) a = 0;
        else if (memory && m.explored[i]) a = 150;
      }
      const o = (fy * fw + fx) * 4;
      d[o] = 5;
      d[o + 1] = 6;
      d[o + 2] = 12;
      d[o + 3] = a;
    }
  }
  fctx.putImageData(img, 0, 0);
  ctx.save();
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  // Pixelmitte = Kachelmitte
  ctx.drawImage(fogCanvas, sx(x0 - 1), sy(y0 - 1), fw * TILE, fh * TILE);
  ctx.restore();
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
  ctx.imageSmoothingEnabled = true;
  ctx.fillStyle = '#05060b';
  ctx.fillRect(0, 0, w, h);

  const view = computeView(s, canvas, anim);
  const vis = visibleTiles(s);
  const memory = hasUnlock(s, 'minimap');
  const m = s.map;
  const time = anim?.time ?? 0;
  const k = TILE / U;
  const sx = (x: number) => Math.round((x - view.ox) * TILE);
  const sy = (y: number) => Math.round((y - view.oy) * TILE);
  const at = (key: string, p: Pos) => (anim ? anim.pos(key, p) : p);
  const known = (i: number) => vis.has(i) || (memory && m.explored[i]);
  const isWall = (x: number, y: number) => !inBounds(m, x, y) || m.tiles[idx(m, x, y)] === 'wall';

  const x0 = Math.max(0, Math.floor(view.ox) - 1);
  const y0 = Math.max(0, Math.floor(view.oy) - 1);
  const x1 = Math.min(m.width, Math.ceil(view.ox + view.cols) + 1);
  const y1 = Math.min(m.height, Math.ceil(view.oy + view.rows) + 1);

  // --- Böden, Umgebungsverdeckung, Treppen, Türen
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
      // Weiche Schatten an angrenzenden Wänden
      const n = isWall(x, y - 1);
      const so = isWall(x, y + 1);
      const we = isWall(x - 1, y);
      const ea = isWall(x + 1, y);
      if (n) ctx.drawImage(aoTexture('n'), px, py, TILE, TILE);
      if (so) ctx.drawImage(aoTexture('s'), px, py, TILE, TILE);
      if (we) ctx.drawImage(aoTexture('w'), px, py, TILE, TILE);
      if (ea) ctx.drawImage(aoTexture('e'), px, py, TILE, TILE);
      if (!n && !we && isWall(x - 1, y - 1)) ctx.drawImage(aoTexture('nw'), px, py, TILE, TILE);
      if (!n && !ea && isWall(x + 1, y - 1)) ctx.drawImage(aoTexture('ne'), px, py, TILE, TILE);
      if (!so && !we && isWall(x - 1, y + 1)) ctx.drawImage(aoTexture('sw'), px, py, TILE, TILE);
      if (!so && !ea && isWall(x + 1, y + 1)) ctx.drawImage(aoTexture('se'), px, py, TILE, TILE);
      if (tile === 'floor' && room?.kind !== 'safe' && room?.kind !== 'guild') drawDecal(ctx, px, py, k, x, y, s.floor);
      // Einrichtung an den Wänden normaler Räume (nur Dekoration)
      if (room && room.kind === 'normal' && tile === 'floor' && hash(x, y, 5) < 0.09 && (n || we || ea)) {
        drawProp(ctx, px, py, k, Math.floor(hash(x, y, 6) * 5));
      }
      if (tile === 'stairs') drawStairs(ctx, px, py, k, vis.has(i), time);
      const furn = room?.furniture?.find((f) => f.pos.x === x && f.pos.y === y);
      if (furn) drawFurniture(ctx, furn.kind, px, py, k, time);
      if (tile === 'door' || tile === 'dooropen') {
        const horizontal = !isWalkable(m, x - 1, y) && m.tiles[idx(m, x - 1, y)] !== 'door';
        const lairDoor = [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dx, dy]) => {
          const ri = inBounds(m, x + dx, y + dy) ? m.roomAt[idx(m, x + dx, y + dy)] : -1;
          return ri >= 0 && (m.rooms[ri].kind === 'boss' || m.rooms[ri].kind === 'arena');
        });
        if (lairDoor && vis.has(i)) {
          const pulse = 0.25 + 0.15 * Math.sin(time / 400);
          const g = ctx.createRadialGradient(px + TILE / 2, py + TILE / 2, 1, px + TILE / 2, py + TILE / 2, TILE);
          g.addColorStop(0, `rgba(255,60,40,${pulse})`);
          g.addColorStop(1, 'rgba(255,60,40,0)');
          ctx.fillStyle = g;
          ctx.fillRect(px - TILE / 2, py - TILE / 2, TILE * 2, TILE * 2);
        }
        ctx.drawImage(doorTexture(tile === 'dooropen', horizontal, lairDoor), px, py, TILE, TILE);
      }
    }
  }

  // --- Wände mit Vorderseite, Kanten zum Raum hin betont
  const th = wallTheme(s.floor);
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = idx(m, x, y);
      if (m.tiles[i] !== 'wall' || !known(i)) continue;
      let edge = false;
      for (let dy = -1; dy <= 1 && !edge; dy++) for (let dx = -1; dx <= 1 && !edge; dx++) {
        if (inBounds(m, x + dx, y + dy) && m.tiles[idx(m, x + dx, y + dy)] !== 'wall') edge = true;
      }
      if (!edge) continue;
      const below = !isWall(x, y + 1);
      const px = sx(x);
      const py = sy(y);
      ctx.drawImage(wallTexture(s.floor, Math.floor(hash(x, y, 3) * 4), below), px, py, TILE, TILE);
      // Helle Kante der Mauerkrone, wo sie an Boden grenzt
      ctx.fillStyle = alpha(th.lip, 0.55);
      const lw = Math.max(1, 1.2 * k);
      if (!isWall(x, y - 1)) ctx.fillRect(px, py, TILE, lw);
      if (!isWall(x - 1, y)) ctx.fillRect(px, py, lw, below ? TILE * 0.38 : TILE);
      if (!isWall(x + 1, y)) ctx.fillRect(px + TILE - lw, py, lw, below ? TILE * 0.38 : TILE);
    }
  }

  // --- Nebel: Erinnerung abgedunkelt, Unbekanntes schwarz, weiche Kanten
  drawFog(ctx, s, vis, memory, x0, y0, x1, y1, sx, sy);

  // --- Pfadvorschau
  if (extras.path?.length) {
    for (const [n, p] of extras.path.entries()) {
      const last = n === extras.path.length - 1;
      const cx = sx(p.x) + TILE / 2;
      const cy = sy(p.y) + TILE / 2;
      if (last) {
        ctx.strokeStyle = 'rgba(255,214,90,0.85)';
        ctx.lineWidth = 1.5 * k;
        ctx.beginPath();
        ctx.arc(cx, cy, 7 * k, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.fillStyle = `rgba(255, 214, 90, ${Math.max(0.18, 0.7 - n * 0.025)})`;
      ctx.beginPath();
      ctx.arc(cx, cy, 2.4 * k, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // --- Bekannte Fallen
  for (const tr of s.traps ?? []) {
    if (tr.hidden) continue;
    const i = idx(m, tr.pos.x, tr.pos.y);
    if (!known(i)) continue;
    ctx.globalAlpha = vis.has(i) ? 1 : 0.45;
    drawTrap(ctx, tr.kind, sx(tr.pos.x), sy(tr.pos.y), k, tr.owner === 'crawler');
    ctx.globalAlpha = 1;
  }

  // --- Gegenstände
  for (const e of s.items) {
    const i = idx(m, e.pos.x, e.pos.y);
    if (!known(i)) continue;
    ctx.globalAlpha = vis.has(i) ? 1 : 0.4;
    drawItem(ctx, e.item, sx(e.pos.x) + TILE / 2, sy(e.pos.y) + TILE / 2, k, vis.has(i), time);
    ctx.globalAlpha = 1;
  }

  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  // --- Andere Crawler (nur sichtbare)
  for (const c of s.crawlers ?? []) {
    if (!c.alive || !vis.has(idx(m, c.pos.x, c.pos.y))) continue;
    const p = at(c.uid, c.pos);
    const cx = sx(p.x) + TILE / 2;
    const cy = sy(p.y) + TILE / 2;
    const col = c.party ? '#7fe0a0' : '#7cc4ff';
    const r = 9.5 * k;
    groundRing(ctx, cx, cy + r * 0.72, r, k, alpha(col, 0.6));
    drawSprite(ctx, 'crawler', c.party ? '#4f9a6a' : '#4a7fb0', cx, cy - 1.5 * k, r * 2.7, { time });
    if (c.hp < c.maxHp) hpBar(ctx, cx, cy - r - 5 * k, r * 2, k, c.hp / c.maxHp, '#6ee07a');
  }

  // --- Monster (nur sichtbare)
  for (const mo of s.monsters) {
    if (!vis.has(idx(m, mo.pos.x, mo.pos.y))) continue;
    const p = at(mo.uid, mo.pos);
    const cx = sx(p.x) + TILE / 2;
    const cy = sy(p.y) + TILE / 2;
    const boss = mo.rank !== 'normal' && mo.rank !== 'elite';
    const elite = mo.rank === 'elite';
    const info = describeMonster(s, mo);
    const unknown = info.insight >= 3;
    const color = mo.color;
    const base = boss ? 14.5 : mo.size === 'winzig' ? 10.5 : mo.size === 'klein' ? 12 : mo.size === 'gross' || mo.size === 'riesig' ? 14 : 13;
    const r = base * k;
    // Bodenmarke: Farbe zeigt Herausforderung, pulsiert rot, wenn der Gegner dich jagt
    groundRing(ctx, cx, cy + r * 0.72, r * 1.05, k, mo.aware && !mo.asleep ? `rgba(255,76,60,${0.45 + 0.35 * (0.5 + 0.5 * Math.sin(time / 170))})` : alpha(info.challenge.color.length === 7 ? info.challenge.color : '#a39a8c', 0.55), boss ? '#ffcc33' : elite ? '#ff5a4a' : undefined);
    const bob = mo.asleep ? 0 : Math.sin(time / 260 + mo.pos.x * 1.7) * 0.8 * k;
    ctx.globalAlpha = mo.asleep ? 0.85 : 1;
    drawSprite(ctx, spriteFor(mo.defId, mo.rank === 'geist'), color, cx, cy - 2 * k + bob, r * 3.1, {
      time, flip: p.x > (anim?.pos('p', s.player.pos).x ?? s.player.pos.x), crown: boss, unknown,
    });
    ctx.globalAlpha = 1;
    // Brennende Gegner flackern
    if ((mo.conditions?.brennen?.turns ?? 0) > 0) {
      const flicker = 0.45 + 0.35 * Math.sin(time / 70 + mo.pos.x);
      ctx.strokeStyle = `rgba(255,140,40,${flicker})`;
      ctx.lineWidth = 2 * k;
      ctx.beginPath();
      ctx.arc(cx, cy, r + 1.8 * k, 0, Math.PI * 2);
      ctx.stroke();
    }
    if (mo.hp < mo.maxHp && info.showHealthBar) hpBar(ctx, cx, cy - r - 6 * k, Math.max(r * 2, 18 * k), k, mo.hp / mo.maxHp, '#ff5a4a');
    // Stufenmarke unten links: Farbe zeigt die Herausforderung
    levelPill(ctx, cx - r * 0.72, cy + r * 0.78, k, info.insight <= 1 ? String(mo.level) : '?', info.challenge.color);
    // Zustände als kleine farbige Punkte oben rechts
    conditionList(mo).forEach((c, n) => {
      const dx = cx + r * 0.95 - n * 7.5 * k;
      const dy = cy - r * 1.02;
      ctx.fillStyle = 'rgba(0,0,0,0.8)';
      ctx.beginPath();
      ctx.arc(dx, dy, 3.8 * k, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = c.color;
      ctx.beginPath();
      ctx.arc(dx, dy, 2.6 * k, 0, Math.PI * 2);
      ctx.fill();
    });
    if (mo.asleep) {
      ctx.font = `700 ${10 * k}px Montserrat, sans-serif`;
      ctx.fillStyle = '#a9c8ff';
      const bob = Math.sin(time / 400) * 2 * k;
      ctx.fillText('z', cx + r + 2 * k, cy - r + bob);
      ctx.font = `700 ${8 * k}px Montserrat, sans-serif`;
      ctx.fillText('z', cx + r + 7 * k, cy - r - 5 * k + bob);
    } else {
      const label = mo.downed > 0 ? ['am Boden', '#7cc4ff'] : (mo.conditions?.furcht?.turns ?? 0) > 0 ? ['verängstigt', '#c3a3ff'] : (mo.conditions?.blind?.turns ?? 0) > 0 ? ['geblendet', '#e2e2e2'] : mo.fleeing ? ['flieht', '#ffd24a'] : null;
      if (label) tag(ctx, cx, cy + r + 7 * k, k, label[0], label[1]);
    }
  }

  // --- Haustier
  const pet = s.player.pet;
  if (pet?.alive) {
    const p = at('pet', pet.pos);
    const cx = sx(p.x) + TILE / 2;
    const cy = sy(p.y) + TILE / 2;
    groundRing(ctx, cx, cy + 6 * k, 8.5 * k, k, 'rgba(255,179,230,0.6)');
    drawSprite(ctx, 'haustier', '#e0a0c8', cx, cy - 1 * k, 19 * k, { time });
    if (pet.hp < pet.maxHp) hpBar(ctx, cx, cy - 13 * k, 16 * k, k, pet.hp / pet.maxHp, '#ff8ad8');
  }

  // --- Spieler
  const pp = at('p', s.player.pos);
  const px = sx(pp.x) + TILE / 2;
  const py = sy(pp.y) + TILE / 2;
  drawPlayer(ctx, s, px, py, k, time);

  // --- Licht: weicher Lichtkegel um den Crawler, warmer Schein
  const radius = lichtradius(s) * TILE;
  const flicker = 1 + Math.sin(time / 90) * 0.012 + Math.sin(time / 37) * 0.008;
  const dark = ctx.createRadialGradient(px, py, radius * 0.4 * flicker, px, py, radius * 1.05 * flicker);
  dark.addColorStop(0, 'rgba(0,0,0,0)');
  dark.addColorStop(0.7, 'rgba(2,3,8,0.14)');
  dark.addColorStop(1, 'rgba(2,3,8,0.4)');
  ctx.fillStyle = dark;
  ctx.fillRect(0, 0, w, h);
  ctx.globalCompositeOperation = 'lighter';
  const warm = ctx.createRadialGradient(px, py, 0, px, py, radius * 0.75);
  warm.addColorStop(0, 'rgba(110,70,22,0.17)');
  warm.addColorStop(1, 'rgba(110,70,22,0)');
  ctx.fillStyle = warm;
  ctx.fillRect(px - radius, py - radius, radius * 2, radius * 2);
  ctx.globalCompositeOperation = 'source-over';

  // --- Geschosse und schwebende Zahlen
  for (const pr of anim?.projectiles ?? []) drawProjectile(ctx, pr, sx, sy, k);
  ctx.font = `800 ${14 * k}px Montserrat, sans-serif`;
  ctx.lineJoin = 'round';
  for (const f of anim?.floaters ?? []) {
    ctx.globalAlpha = f.alpha;
    ctx.strokeStyle = 'rgba(0,0,0,0.85)';
    ctx.lineWidth = 3.2 * k;
    ctx.strokeText(f.text, sx(f.x) + TILE / 2, sy(f.y));
    ctx.fillStyle = f.color;
    ctx.fillText(f.text, sx(f.x) + TILE / 2, sy(f.y));
  }
  ctx.globalAlpha = 1;

  // --- Hover-Rahmen
  if (extras.hover) {
    const hx = sx(extras.hover.x);
    const hy = sy(extras.hover.y);
    ctx.fillStyle = 'rgba(255, 214, 90, 0.07)';
    ctx.strokeStyle = 'rgba(255, 214, 90, 0.9)';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.roundRect(hx + 1, hy + 1, TILE - 2, TILE - 2, 4 * k);
    ctx.fill();
    ctx.stroke();
  }

  // --- Untersuchtes Feld: Eckklammern
  if (extras.selected) {
    const qx = sx(extras.selected.x);
    const qy = sy(extras.selected.y);
    const L = TILE * 0.3;
    ctx.strokeStyle = 'rgba(140, 200, 255, 0.95)';
    ctx.lineWidth = 2;
    ctx.beginPath();
    for (const [cx, cy, dx, dy] of [[qx, qy, 1, 1], [qx + TILE, qy, -1, 1], [qx, qy + TILE, 1, -1], [qx + TILE, qy + TILE, -1, -1]]) {
      ctx.moveTo(cx + dx * L, cy + dy * 1);
      ctx.lineTo(cx + dx * 1, cy + dy * 1);
      ctx.lineTo(cx + dx * 1, cy + dy * L);
    }
    ctx.stroke();
  }

  // --- Vignette: Ränder weich abdunkeln
  const vg = ctx.createRadialGradient(w / 2, h / 2, Math.min(w, h) * 0.35, w / 2, h / 2, Math.max(w, h) * 0.75);
  vg.addColorStop(0, 'rgba(0,0,0,0)');
  vg.addColorStop(1, 'rgba(0,0,0,0.5)');
  ctx.fillStyle = vg;
  ctx.fillRect(0, 0, w, h);

  return { view, visible: vis };
}

// ================================================================ Figuren

/** Leuchtender Ring am Boden unter einer Figur. */
function groundRing(ctx: Ctx, cx: number, cy: number, r: number, k: number, color: string, outer?: string) {
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.beginPath();
  ctx.ellipse(cx, cy, r, r * 0.42, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.8 * k;
  ctx.stroke();
  if (outer) {
    ctx.strokeStyle = outer;
    ctx.lineWidth = 1.2 * k;
    ctx.beginPath();
    ctx.ellipse(cx, cy, r + 3 * k, (r + 3 * k) * 0.42, 0, 0, Math.PI * 2);
    ctx.stroke();
  }
}

function hpBar(ctx: Ctx, cx: number, y: number, width: number, k: number, frac: number, color: string) {
  const f = Math.max(0, Math.min(1, frac));
  const hgt = 4 * k;
  const x = cx - width / 2;
  ctx.fillStyle = 'rgba(0,0,0,0.8)';
  ctx.beginPath();
  ctx.roundRect(x - 1, y - 1, width + 2, hgt + 2, hgt);
  ctx.fill();
  if (f <= 0) return;
  const g = ctx.createLinearGradient(0, y, 0, y + hgt);
  g.addColorStop(0, shade(color.length === 7 ? color : '#ff5a4a', 1.25));
  g.addColorStop(1, color);
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.roundRect(x, y, Math.max(hgt, width * f), hgt, hgt / 2);
  ctx.fill();
}

function levelPill(ctx: Ctx, cx: number, cy: number, k: number, text: string, color: string) {
  ctx.font = `800 ${8.5 * k}px Montserrat, sans-serif`;
  const w = Math.max(11 * k, ctx.measureText(text).width + 6 * k);
  const h = 10 * k;
  ctx.fillStyle = 'rgba(0,0,0,0.85)';
  ctx.beginPath();
  ctx.roundRect(cx - w / 2 - 1, cy - h / 2 - 1, w + 2, h + 2, h);
  ctx.fill();
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.roundRect(cx - w / 2, cy - h / 2, w, h, h / 2);
  ctx.fill();
  ctx.fillStyle = '#12100c';
  ctx.fillText(text, cx, cy + 0.5 * k);
}

/** Kleines Schild unter einer Figur, z. B. „am Boden“. */
function tag(ctx: Ctx, cx: number, cy: number, k: number, text: string, color: string) {
  ctx.font = `700 ${9 * k}px Montserrat, sans-serif`;
  const w = ctx.measureText(text).width + 8 * k;
  const h = 12 * k;
  ctx.fillStyle = 'rgba(8,9,14,0.82)';
  ctx.beginPath();
  ctx.roundRect(cx - w / 2, cy - h / 2, w, h, 4 * k);
  ctx.fill();
  ctx.strokeStyle = alpha(color.length === 7 ? color : '#ffffff', 0.5);
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.fillStyle = color;
  ctx.fillText(text, cx, cy + 0.5 * k);
}

function drawPlayer(ctx: Ctx, s: GameState, px: number, py: number, k: number, time: number) {
  const p = s.player;
  const r = 10 * k;
  // Leuchten
  const glow = ctx.createRadialGradient(px, py, 2, px, py, 34 * k);
  glow.addColorStop(0, 'rgba(255, 214, 110, 0.42)');
  glow.addColorStop(1, 'rgba(255, 214, 110, 0)');
  ctx.fillStyle = glow;
  ctx.fillRect(px - 34 * k, py - 34 * k, 68 * k, 68 * k);
  if (p.riding && p.mount && !p.mount.down) {
    const mg = ctx.createLinearGradient(0, py - 6 * k, 0, py + 14 * k);
    mg.addColorStop(0, '#8a6038');
    mg.addColorStop(1, '#4a3018');
    ctx.fillStyle = mg;
    ctx.beginPath();
    ctx.ellipse(px, py + 4 * k, 15 * k, 9.5 * k, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#d19a5b';
    ctx.lineWidth = 1.6 * k;
    ctx.stroke();
  }
  // Bodenring in Gold, darauf die Figur
  groundRing(ctx, px, py + r * 0.75, r * 1.05, k, 'rgba(255,214,90,0.9)');
  const dir = p.lastMoveDir;
  const flip = !!dir && dir.x < 0;
  drawHero(ctx, px, py - 2 * k + Math.sin(time / 300) * 0.6 * k, r * 3.1, flip);
  if (p.buffs.some((b) => b.name === 'Vergiftet')) {
    ctx.strokeStyle = 'rgba(155,224,74,0.8)';
    ctx.lineWidth = 1.6 * k;
    ctx.beginPath();
    ctx.ellipse(px, py + r * 0.75, r * 1.3, r * 0.55, 0, 0, Math.PI * 2);
    ctx.stroke();
  }
  // Zustände des Crawlers als Außenring
  const ail = [['Blutung', '#e0434a'], ['Brennen', '#ff8a2a'], ['Furcht', '#b38cff'], ['Geblendet', '#d9d9d9']].filter(([n]) => p.buffs.some((b) => b.name === n));
  ail.forEach(([, col], n) => {
    ctx.strokeStyle = alpha(col, 0.55 + 0.3 * Math.sin(time / 150 + n));
    ctx.lineWidth = 1.6 * k;
    ctx.beginPath();
    ctx.ellipse(px, py + r * 0.75, r * 1.3 + (2 + n * 2.5) * k, (r * 1.3 + (2 + n * 2.5) * k) * 0.42, 0, 0, Math.PI * 2);
    ctx.stroke();
  });
}

// ================================================================ Gegenstände

function drawItem(ctx: Ctx, it: Item, cx: number, cy: number, k: number, visible: boolean, time: number) {
  const col = it.kind === 'box' && it.box ? BOX_TIER_COLORS[it.box.tier] : RARITY_COLORS[it.rarity];
  if (visible && (it.rarity !== 'gewoehnlich' || it.kind === 'box')) {
    const pulse = 0.75 + 0.25 * Math.sin(time / 420 + cx);
    const g = ctx.createRadialGradient(cx, cy, 1, cx, cy, 14 * k);
    g.addColorStop(0, alpha(col, 0.45 * pulse));
    g.addColorStop(1, alpha(col, 0));
    ctx.fillStyle = g;
    ctx.fillRect(cx - 14 * k, cy - 14 * k, 28 * k, 28 * k);
  }
  ctx.fillStyle = 'rgba(0,0,0,0.45)';
  ctx.beginPath();
  ctx.ellipse(cx, cy + 6.5 * k, 7 * k, 2.4 * k, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.save();
  ctx.translate(cx, cy);
  ctx.scale(k, k);
  switch (it.kind) {
    case 'gold':
      coins();
      break;
    case 'karte':
      scroll();
      break;
    case 'box':
      chest(col);
      break;
    case 'wurf':
      rock(it.explosion ? '#3a3a3a' : '#8d857a', !!it.explosion);
      break;
    case 'verbrauch':
      flask(col);
      break;
    case 'buch':
      book(col);
      break;
    case 'schrott':
      nut();
      break;
    default:
      gem(col);
  }
  ctx.restore();

  function gem(c: string) {
    ctx.fillStyle = shade(c.length === 7 ? c : '#c8c8c8', 0.6);
    ctx.beginPath();
    ctx.moveTo(0, -7);
    ctx.lineTo(6.5, -1.5);
    ctx.lineTo(0, 6.5);
    ctx.lineTo(-6.5, -1.5);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = c;
    ctx.beginPath();
    ctx.moveTo(0, -7);
    ctx.lineTo(6.5, -1.5);
    ctx.lineTo(0, 1);
    ctx.lineTo(-6.5, -1.5);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.6)';
    ctx.beginPath();
    ctx.moveTo(0, -7);
    ctx.lineTo(2.5, -2.5);
    ctx.lineTo(-2.5, -2.5);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = 'rgba(0,0,0,0.6)';
    ctx.lineWidth = 0.8;
    ctx.beginPath();
    ctx.moveTo(0, -7);
    ctx.lineTo(6.5, -1.5);
    ctx.lineTo(0, 6.5);
    ctx.lineTo(-6.5, -1.5);
    ctx.closePath();
    ctx.stroke();
  }
  function coins() {
    for (const [dx, dy] of [[-3.5, 2.5], [3.5, 2.5], [0, -1]]) {
      ctx.fillStyle = '#8a6a10';
      ctx.beginPath();
      ctx.ellipse(dx, dy + 1.4, 4.6, 2.5, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = '#ffd24a';
      ctx.beginPath();
      ctx.ellipse(dx, dy, 4.6, 2.5, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = 'rgba(255,255,255,0.55)';
      ctx.fillRect(dx - 2, dy - 1.2, 2.5, 0.9);
    }
  }
  function scroll() {
    ctx.fillStyle = '#eadcb0';
    ctx.fillRect(-6.5, -4.5, 13, 9);
    ctx.fillStyle = '#b89a5a';
    ctx.beginPath();
    ctx.roundRect(-8, -5.5, 2.6, 11, 1.2);
    ctx.roundRect(5.4, -5.5, 2.6, 11, 1.2);
    ctx.fill();
    ctx.strokeStyle = '#6a8fb8';
    ctx.lineWidth = 0.9;
    ctx.beginPath();
    ctx.moveTo(-4, -1.5);
    ctx.lineTo(0, 1);
    ctx.lineTo(4, -1);
    ctx.stroke();
  }
  function chest(c: string) {
    ctx.fillStyle = '#5b3a1e';
    ctx.beginPath();
    ctx.roundRect(-7.5, -3, 15, 9, 1.5);
    ctx.fill();
    ctx.fillStyle = '#7a4f28';
    ctx.beginPath();
    ctx.roundRect(-7.5, -7, 15, 5, [3, 3, 0, 0]);
    ctx.fill();
    ctx.fillStyle = c;
    ctx.fillRect(-7.5, -2.6, 15, 1.4);
    ctx.fillRect(-1.3, -4, 2.6, 5);
    ctx.fillRect(-7.5, -7, 1.4, 13);
    ctx.fillRect(6.1, -7, 1.4, 13);
  }
  function rock(c: string, fuse: boolean) {
    ctx.fillStyle = c;
    ctx.beginPath();
    ctx.moveTo(-5.5, 2);
    ctx.lineTo(-4, -3.5);
    ctx.lineTo(1, -5);
    ctx.lineTo(5.5, -1.5);
    ctx.lineTo(4.5, 4);
    ctx.lineTo(-2, 5);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.22)';
    ctx.beginPath();
    ctx.moveTo(-4, -3.5);
    ctx.lineTo(1, -5);
    ctx.lineTo(0, -1);
    ctx.closePath();
    ctx.fill();
    if (fuse) {
      ctx.strokeStyle = '#c8a060';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(2, -4.5);
      ctx.quadraticCurveTo(5, -9, 7, -7);
      ctx.stroke();
      ctx.fillStyle = '#ffb040';
      ctx.beginPath();
      ctx.arc(7, -7, 1.3, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  function flask(c: string) {
    ctx.fillStyle = 'rgba(210,230,255,0.35)';
    ctx.beginPath();
    ctx.arc(0, 2, 5.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillRect(-1.8, -6, 3.6, 5);
    ctx.fillStyle = c === '#c8c8c8' ? '#d8604a' : c;
    ctx.beginPath();
    ctx.arc(0, 2.3, 4.3, 0, Math.PI);
    ctx.fill();
    ctx.fillStyle = '#8a6a44';
    ctx.fillRect(-2.2, -7.5, 4.4, 2);
    ctx.fillStyle = 'rgba(255,255,255,0.55)';
    ctx.beginPath();
    ctx.arc(-2, 0, 1.2, 0, Math.PI * 2);
    ctx.fill();
  }
  function book(c: string) {
    ctx.fillStyle = shade(c.length === 7 ? c : '#c8c8c8', 0.55);
    ctx.beginPath();
    ctx.roundRect(-6, -5.5, 12, 11, 1.2);
    ctx.fill();
    ctx.fillStyle = '#efe6cc';
    ctx.fillRect(-4.5, -4, 9.5, 8);
    ctx.fillStyle = c;
    ctx.fillRect(-6, -5.5, 2.2, 11);
    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    ctx.fillRect(-2.5, -2, 6, 0.8);
    ctx.fillRect(-2.5, 0.5, 6, 0.8);
  }
  function nut() {
    ctx.fillStyle = '#8f949b';
    ctx.beginPath();
    for (let n = 0; n < 6; n++) {
      const a = (n / 6) * Math.PI * 2;
      ctx.lineTo(Math.cos(a) * 5.5, Math.sin(a) * 5.5);
    }
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#2a2d31';
    ctx.beginPath();
    ctx.arc(0, 0, 2.2, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(255,255,255,0.25)';
    ctx.fillRect(-3, -4.5, 5, 1);
  }
}

// ================================================================ Einrichtung, Treppe, Fallen, Geschosse

/** Einrichtung der Safe Rooms: Automat, Händler, Wirt, Bett, Toilette. */
function drawFurniture(ctx: Ctx, kind: FurnitureKind, px: number, py: number, k: number, time: number) {
  const cx = px + TILE / 2;
  const cy = py + TILE / 2;
  if (kind === 'haendler' || kind === 'wirt') {
    // Theke, dahinter die Figur
    drawSprite(ctx, 'mensch', kind === 'wirt' ? '#8a4a3a' : '#3a6a8a', cx, cy - 6 * k, 24 * k, { time });
    ctx.save();
    ctx.translate(px, py);
    ctx.scale(k, k);
    bevel(ctx, 2, 18, 28, 12, 2, '#6e4a2a', 0.22, 0.4);
    ctx.fillStyle = kind === 'wirt' ? '#e7c46a' : '#9fd0ff';
    ctx.fillRect(6, 22, 20, 1.5);
    ctx.restore();
    return;
  }
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(k, k);
  ctx.fillStyle = 'rgba(0,0,0,0.4)';
  ctx.beginPath();
  ctx.ellipse(16, 28, 12, 3.5, 0, 0, Math.PI * 2);
  ctx.fill();
  switch (kind) {
    case 'automat': {
      const glow = 0.5 + 0.3 * Math.sin(time / 350);
      const g = ctx.createRadialGradient(16, 14, 2, 16, 14, 22);
      g.addColorStop(0, `rgba(120,220,255,${glow * 0.5})`);
      g.addColorStop(1, 'rgba(120,220,255,0)');
      ctx.fillStyle = g;
      ctx.fillRect(-8, -8, 48, 48);
      bevel(ctx, 6, 1, 20, 28, 2.5, '#2e5f8a', 0.25, 0.4);
      ctx.fillStyle = `rgba(170,235,255,${0.55 + glow * 0.3})`;
      ctx.fillRect(9, 4, 14, 12);
      ctx.fillStyle = '#ffe14a';
      ctx.fillRect(10, 6, 3, 3);
      ctx.fillStyle = '#ff7a6a';
      ctx.fillRect(15, 6, 3, 3);
      ctx.fillStyle = '#9fffb0';
      ctx.fillRect(10, 11, 3, 3);
      ctx.fillStyle = '#111';
      ctx.fillRect(9, 20, 14, 4);
      break;
    }
    case 'bett':
      bevel(ctx, 4, 3, 24, 26, 3, '#5a3a22', 0.2, 0.4);
      bevel(ctx, 6, 9, 20, 18, 2, '#3f6ea8', 0.25, 0.3);
      bevel(ctx, 7, 4, 18, 6, 2.5, '#efe8d8', 0.3, 0.2);
      break;
    case 'toilette':
      bevel(ctx, 10, 2, 12, 8, 2, '#e8ecef', 0.3, 0.25);
      ctx.fillStyle = '#e8ecef';
      ctx.strokeStyle = '#9aa2a8';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.ellipse(16, 19, 8, 9, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = '#9fd0e8';
      ctx.beginPath();
      ctx.ellipse(16, 20, 4.5, 5.5, 0, 0, Math.PI * 2);
      ctx.fill();
      break;
  }
  ctx.restore();
}

/** Einzelne Flecken, Risse und Pfützen – selten, an zufälliger Stelle. */
function drawDecal(ctx: Ctx, px: number, py: number, k: number, x: number, y: number, floor: number) {
  const roll = hash(x, y, 41);
  if (roll > 0.11) return;
  const r = (n: number) => hash(x, y, 50 + n);
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(k, k);
  if (roll < 0.04) {
    // Pfütze (auf Etage 3 grünlich)
    ctx.fillStyle = floor >= 3 ? 'rgba(70,110,60,0.28)' : 'rgba(30,40,55,0.35)';
    ctx.beginPath();
    ctx.ellipse(8 + r(1) * 16, 8 + r(2) * 16, 5 + r(3) * 5, 3 + r(4) * 2, r(5) * 3, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = 'rgba(200,220,255,0.10)';
    ctx.beginPath();
    ctx.ellipse(8 + r(1) * 16 - 1.5, 8 + r(2) * 16 - 1, 2, 0.8, r(5) * 3, 0, Math.PI * 2);
    ctx.fill();
  } else if (roll < 0.075) {
    // Riss
    ctx.strokeStyle = 'rgba(0,0,0,0.45)';
    ctx.lineWidth = 0.8;
    ctx.beginPath();
    let cx = r(6) * 10 + 4;
    let cy = r(7) * 10 + 4;
    ctx.moveTo(cx, cy);
    for (let n = 0; n < 4; n++) {
      cx += 3 + r(8 + n) * 5;
      cy += (r(12 + n) - 0.3) * 7;
      ctx.lineTo(cx, cy);
    }
    ctx.stroke();
  } else {
    // Fleck
    ctx.fillStyle = 'rgba(12,8,4,0.26)';
    ctx.beginPath();
    ctx.ellipse(8 + r(1) * 16, 8 + r(2) * 16, 4 + r(3) * 4, 2.5 + r(4) * 2, r(5) * 3, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}

/** Kisten, Fässer, Regale, Gerümpel. */
function drawProp(ctx: Ctx, px: number, py: number, k: number, kind: number) {
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(k, k);
  ctx.fillStyle = 'rgba(0,0,0,0.35)';
  ctx.beginPath();
  ctx.ellipse(16, 26, 11, 3, 0, 0, Math.PI * 2);
  ctx.fill();
  switch (kind) {
    case 0: // Holzkiste
      bevel(ctx, 7, 8, 18, 17, 1.5, '#6e4c2b', 0.18, 0.35);
      ctx.strokeStyle = '#3a2614';
      ctx.lineWidth = 1;
      ctx.strokeRect(7.5, 8.5, 17, 16);
      ctx.beginPath();
      ctx.moveTo(8, 9);
      ctx.lineTo(24, 24);
      ctx.stroke();
      break;
    case 1: {
      // Fass
      const g = ctx.createLinearGradient(7, 0, 25, 0);
      g.addColorStop(0, '#3e2812');
      g.addColorStop(0.45, '#7a5230');
      g.addColorStop(1, '#3e2812');
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.ellipse(16, 16, 9, 10, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#8f949b';
      ctx.lineWidth = 1.2;
      ctx.beginPath();
      ctx.ellipse(16, 11, 8.5, 2.5, 0, 0, Math.PI * 2);
      ctx.ellipse(16, 21, 8.5, 2.5, 0, 0, Math.PI * 2);
      ctx.stroke();
      break;
    }
    case 2: // Regal
      bevel(ctx, 4, 5, 24, 8, 1, '#4c3521', 0.15, 0.4);
      ctx.fillStyle = '#b09468';
      ctx.fillRect(7, 6.5, 4, 5);
      ctx.fillStyle = '#6a8aa0';
      ctx.fillRect(13, 6.5, 5, 5);
      ctx.fillStyle = '#8a5a5a';
      ctx.fillRect(20, 7.5, 4, 4);
      break;
    case 3: // Gerümpel
      bevel(ctx, 8, 16, 8, 7, 1, '#5a534a');
      bevel(ctx, 15, 12, 7, 11, 1, '#7a6a50');
      bevel(ctx, 11, 9, 6, 6, 1, '#3e3e3e');
      break;
    default: // Eimer
      bevel(ctx, 10, 12, 12, 11, 2, '#708090', 0.2, 0.35);
      ctx.fillStyle = '#2a3238';
      ctx.fillRect(10, 12, 12, 2.5);
      ctx.strokeStyle = '#9aa6b0';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(16, 13, 6, Math.PI, 0);
      ctx.stroke();
  }
  ctx.restore();
}

/**
 * Eine Treppe nach unten, von oben gesehen: ein Steinrahmen, darin Stufen,
 * die zur Tiefe hin schmaler und dunkler werden, mit zwei Handläufen.
 */
function drawStairs(ctx: Ctx, px: number, py: number, k: number, seen: boolean, time: number) {
  const T = TILE;
  if (seen) {
    const pulse = 0.28 + 0.08 * Math.sin(time / 500);
    const glow = ctx.createRadialGradient(px + T / 2, py + T / 2, 2, px + T / 2, py + T / 2, T * 1.2);
    glow.addColorStop(0, `rgba(255, 190, 80, ${pulse})`);
    glow.addColorStop(1, 'rgba(255, 190, 80, 0)');
    ctx.fillStyle = glow;
    ctx.fillRect(px - T, py - T, T * 3, T * 3);
  }
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(k, k);
  bevel(ctx, 1, 1, 30, 30, 2, '#6e5a42', 0.2, 0.35);
  ctx.fillStyle = '#1d150d';
  ctx.fillRect(4, 4, 24, 25);
  const steps = 5;
  const stepH = 25 / steps;
  for (let i = 0; i < steps; i++) {
    const t = i / (steps - 1);
    const inset = i * 1.3;
    const x = 4 + inset;
    const w = 24 - inset * 2;
    const y = 4 + i * stepH;
    const light = Math.round(222 - t * 110);
    ctx.fillStyle = `rgb(${light}, ${Math.round(light * 0.84)}, ${Math.round(light * 0.62)})`;
    ctx.fillRect(x, y, w, stepH - 1.3);
    ctx.fillStyle = `rgba(255, 245, 220, ${0.75 - t * 0.5})`;
    ctx.fillRect(x, y, w, 0.9);
    ctx.fillStyle = '#120c06';
    ctx.fillRect(x, y + stepH - 1.3, w, 1.3);
  }
  ctx.strokeStyle = '#d9ae52';
  ctx.lineWidth = 1.4;
  ctx.beginPath();
  ctx.moveTo(3, 4);
  ctx.lineTo(3 + steps * 1.3, 29);
  ctx.moveTo(29, 4);
  ctx.lineTo(29 - steps * 1.3, 29);
  ctx.stroke();
  ctx.restore();
}

function drawTrap(ctx: Ctx, kind: TrapKind, px: number, py: number, k: number, own: boolean) {
  const col = own ? '#6ee07a' : '#ff5a4a';
  ctx.save();
  ctx.translate(px, py);
  ctx.scale(k, k);
  const cx = 16;
  const cy = 16;
  // Markierung: getönter Kreis, damit Fallen auf jedem Boden auffallen
  ctx.fillStyle = alpha(col, 0.12);
  ctx.strokeStyle = alpha(col, 0.45);
  ctx.setLineDash([2.5, 2]);
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(cx, cy, 12.5, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.strokeStyle = col;
  ctx.fillStyle = col;
  ctx.lineWidth = 1.8;
  switch (kind) {
    case 'pfeilplatte':
      ctx.strokeRect(9.5, 9.5, 13, 13);
      for (const [dx, dy] of [[-3, -3], [3, -3], [-3, 3], [3, 3]]) {
        ctx.beginPath();
        ctx.arc(cx + dx, cy + dy, 1.3, 0, Math.PI * 2);
        ctx.fill();
      }
      break;
    case 'fallgrube':
      ctx.fillStyle = 'rgba(0,0,0,0.8)';
      ctx.beginPath();
      ctx.ellipse(cx, cy, 9, 7, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      break;
    case 'giftgas':
      ctx.fillStyle = 'rgba(140,220,90,0.4)';
      ctx.beginPath();
      ctx.arc(cx - 4, cy - 3, 5, 0, Math.PI * 2);
      ctx.arc(cx + 4, cy - 1, 4, 0, Math.PI * 2);
      ctx.arc(cx, cy + 4, 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(cx, cy, 3, 0, Math.PI * 2);
      ctx.stroke();
      break;
    case 'stolperdraht':
      ctx.beginPath();
      ctx.moveTo(4, cy + 3);
      ctx.lineTo(28, cy - 3);
      ctx.stroke();
      ctx.fillRect(3, cy + 1, 3, 5);
      ctx.fillRect(26, cy - 5, 3, 5);
      break;
    case 'baerenfalle':
    case 'schlingfalle':
      ctx.beginPath();
      ctx.arc(cx, cy, 8, 0, Math.PI * 2);
      ctx.stroke();
      for (let a = 0; a < 10; a++) {
        const ang = (a / 10) * Math.PI * 2;
        ctx.beginPath();
        ctx.moveTo(cx + Math.cos(ang) * 8, cy + Math.sin(ang) * 8);
        ctx.lineTo(cx + Math.cos(ang) * 4.5, cy + Math.sin(ang) * 4.5);
        ctx.stroke();
      }
      break;
    case 'stachelfalle':
      for (const [dx, dy] of [[-6, 5], [0, 5], [6, 5], [-3, -2], [3, -2]]) {
        ctx.beginPath();
        ctx.moveTo(cx + dx - 2.5, cy + dy);
        ctx.lineTo(cx + dx, cy + dy - 6);
        ctx.lineTo(cx + dx + 2.5, cy + dy);
        ctx.closePath();
        ctx.fill();
      }
      break;
    case 'sprengfalle':
      ctx.beginPath();
      ctx.roundRect(cx - 6, cy - 3, 12, 8, 1.5);
      ctx.fill();
      ctx.beginPath();
      ctx.moveTo(cx + 5, cy - 3);
      ctx.quadraticCurveTo(cx + 10, cy - 9, cx + 5, cy - 10);
      ctx.stroke();
      break;
  }
  ctx.restore();
}

function drawProjectile(ctx: Ctx, pr: DrawProjectile, sx: (x: number) => number, sy: (y: number) => number, k: number) {
  const cx = sx(pr.x) + TILE / 2;
  const cy = sy(pr.y) + TILE / 2;
  const color = { stein: '#c8c0b0', pfeil: '#e0d0a0', magie: '#c080ff', feuer: '#ff8a2a', schleim: '#8ce04a', bombe: '#555555', blitz: '#9fdcff' }[pr.style];
  // Schweif
  for (const [n, t] of pr.trail.entries()) {
    ctx.globalAlpha = ((n + 1) / pr.trail.length) * 0.4;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(sx(t.x) + TILE / 2, sy(t.y) + TILE / 2, (pr.style === 'magie' || pr.style === 'feuer' ? 4.5 : 2.5) * k, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
  if (pr.style === 'pfeil') {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(pr.angle);
    ctx.scale(k, k);
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-10, 0);
    ctx.lineTo(8, 0);
    ctx.stroke();
    ctx.fillStyle = '#e8e8e8';
    ctx.beginPath();
    ctx.moveTo(11, 0);
    ctx.lineTo(6, -3.5);
    ctx.lineTo(6, 3.5);
    ctx.fill();
    ctx.fillStyle = '#c05040';
    ctx.fillRect(-11, -2.5, 3, 5);
    ctx.restore();
    return;
  }
  if (pr.style === 'magie' || pr.style === 'feuer' || pr.style === 'blitz') {
    const g = ctx.createRadialGradient(cx, cy, 1, cx, cy, 13 * k);
    g.addColorStop(0, '#ffffff');
    g.addColorStop(0.3, color);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(cx, cy, 13 * k, 0, Math.PI * 2);
    ctx.fill();
    return;
  }
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(pr.angle * 3);
  ctx.scale(k, k);
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.roundRect(-4, -4, 8, 8, 2);
  ctx.fill();
  ctx.fillStyle = 'rgba(255,255,255,0.25)';
  ctx.fillRect(-3, -3, 4, 2);
  if (pr.style === 'bombe') {
    ctx.fillStyle = '#ffb040';
    ctx.fillRect(3, -7, 2, 4);
  }
  ctx.restore();
}

// ================================================================ Übersichtskarte

/**
 * Kleine Übersichtskarte aller bekannten Felder: Räume nach Art eingefärbt,
 * Treppe und Crawler hervorgehoben. Wird nur neu gezeichnet, wenn sich etwas ändert.
 */
export function renderMinimap(s: GameState, canvas: HTMLCanvasElement) {
  const m = s.map;
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (!w || !h) return;
  if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
  }
  const ctx = canvas.getContext('2d')!;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);
  // Nur den bekannten Bereich zeigen (mit etwas Rand), damit er groß genug ist
  let bx0 = m.width, by0 = m.height, bx1 = 0, by1 = 0;
  for (let y = 0; y < m.height; y++) for (let x = 0; x < m.width; x++) {
    if (!m.explored[idx(m, x, y)]) continue;
    if (x < bx0) bx0 = x;
    if (y < by0) by0 = y;
    if (x > bx1) bx1 = x;
    if (y > by1) by1 = y;
  }
  if (bx1 < bx0) return;
  const pad = 3;
  bx0 = Math.max(0, bx0 - pad);
  by0 = Math.max(0, by0 - pad);
  bx1 = Math.min(m.width - 1, bx1 + pad);
  by1 = Math.min(m.height - 1, by1 + pad);
  const bw = bx1 - bx0 + 1;
  const bh = by1 - by0 + 1;
  const cell = Math.min(w / bw, h / bh, 8);
  const ox = (w - cell * bw) / 2 - bx0 * cell;
  const oy = (h - cell * bh) / 2 - by0 * cell;
  const roomColor: Record<string, string> = {
    safe: '#c9973a', guild: '#4f7fc9', boss: '#b0413a', arena: '#9a6a3a', start: '#6b6f7a',
  };
  for (let y = by0; y <= by1; y++) {
    for (let x = bx0; x <= bx1; x++) {
      const i = idx(m, x, y);
      if (!m.explored[i]) continue;
      const tile = m.tiles[i];
      if (tile === 'wall') {
        // Nur Wände an bekanntem Boden zeigen
        let edge = false;
        for (let dy = -1; dy <= 1 && !edge; dy++) for (let dx = -1; dx <= 1 && !edge; dx++) {
          if (inBounds(m, x + dx, y + dy) && m.tiles[idx(m, x + dx, y + dy)] !== 'wall' && m.explored[idx(m, x + dx, y + dy)]) edge = true;
        }
        if (!edge) continue;
        ctx.fillStyle = '#3a3e4a';
      } else if (tile === 'stairs') ctx.fillStyle = '#ffcc33';
      else if (tile === 'door' || tile === 'dooropen') ctx.fillStyle = '#a0703a';
      else {
        const r = m.roomAt[i] >= 0 ? m.rooms[m.roomAt[i]] : null;
        ctx.fillStyle = r ? roomColor[r.kind] ?? '#8a8f9b' : '#6a6f7a';
      }
      ctx.fillRect(ox + x * cell, oy + y * cell, Math.ceil(cell), Math.ceil(cell));
    }
  }
  const i = m.tiles.indexOf('stairs');
  if (i >= 0 && m.explored[i]) {
    const sx = ox + (i % m.width) * cell + cell / 2;
    const sy = oy + Math.floor(i / m.width) * cell + cell / 2;
    ctx.strokeStyle = '#ffcc33';
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(sx, sy, Math.max(3, cell * 1.6), 0, Math.PI * 2);
    ctx.stroke();
  }
  const px = ox + s.player.pos.x * cell + cell / 2;
  const py = oy + s.player.pos.y * cell + cell / 2;
  ctx.fillStyle = 'rgba(255,214,90,0.3)';
  ctx.beginPath();
  ctx.arc(px, py, Math.max(4, cell * 2.4), 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#fff4cc';
  ctx.beginPath();
  ctx.arc(px, py, Math.max(2, cell * 1.1), 0, Math.PI * 2);
  ctx.fill();
}
