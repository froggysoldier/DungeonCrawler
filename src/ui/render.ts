import { RARITY_COLORS } from '../data/items';
import { hasUnlock, visibleTiles } from '../engine/game';
import { idx, isWalkable } from '../engine/mapgen';
import type { GameState, Pos, RoomKind } from '../engine/types';

export const TILE = 22;

const FLOOR_COLORS: Record<RoomKind | 'gang', string> = {
  gang: '#2a241e',
  normal: '#322b24',
  start: '#34302a',
  guild: '#1f2e44',
  safe: '#1b3a24',
  boss: '#3e1f1f',
  arena: '#4a1d14',
};

export interface View {
  /** Linke obere Ecke der Kamera in Kachelkoordinaten. */
  ox: number;
  oy: number;
  cols: number;
  rows: number;
}

export function computeView(s: GameState, canvas: HTMLCanvasElement): View {
  const cols = Math.ceil(canvas.clientWidth / TILE);
  const rows = Math.ceil(canvas.clientHeight / TILE);
  // Kamera folgt immer dem Spieler (der Punkt bleibt in der Mitte)
  return { ox: s.player.pos.x - Math.floor(cols / 2), oy: s.player.pos.y - Math.floor(rows / 2), cols, rows };
}

export function tileFromMouse(view: View, canvas: HTMLCanvasElement, ev: MouseEvent): Pos {
  const r = canvas.getBoundingClientRect();
  return {
    x: Math.floor((ev.clientX - r.left) / TILE) + view.ox,
    y: Math.floor((ev.clientY - r.top) / TILE) + view.oy,
  };
}

export interface RenderExtras {
  hover: Pos | null;
  path: Pos[] | null;
}

export function render(s: GameState, canvas: HTMLCanvasElement, extras: RenderExtras): { view: View; visible: Set<number> } {
  const dpr = window.devicePixelRatio || 1;
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) {
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
  }
  const ctx = canvas.getContext('2d')!;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.fillStyle = '#050403';
  ctx.fillRect(0, 0, w, h);

  const view = computeView(s, canvas);
  const vis = visibleTiles(s);
  const memory = hasUnlock(s, 'minimap');
  const m = s.map;
  const sx = (x: number) => (x - view.ox) * TILE;
  const sy = (y: number) => (y - view.oy) * TILE;

  // --- Kacheln
  for (let y = Math.max(0, view.oy); y < Math.min(m.height, view.oy + view.rows + 1); y++) {
    for (let x = Math.max(0, view.ox); x < Math.min(m.width, view.ox + view.cols + 1); x++) {
      const i = idx(m, x, y);
      const seen = vis.has(i);
      const known = seen || (memory && m.explored[i]);
      if (!known) continue;
      const tile = m.tiles[i];
      const px = sx(x);
      const py = sy(y);
      if (tile === 'wall') {
        // Nur Wände zeichnen, die an begehbare Felder grenzen
        let edge = false;
        for (let dy = -1; dy <= 1 && !edge; dy++) for (let dx = -1; dx <= 1 && !edge; dx++) if (isWalkable(m, x + dx, y + dy)) edge = true;
        if (!edge) continue;
        ctx.fillStyle = seen ? '#6b5a45' : '#3a3126';
        ctx.fillRect(px, py, TILE, TILE);
        ctx.fillStyle = seen ? '#7d6a52' : '#40372b';
        ctx.fillRect(px, py, TILE, 3);
        continue;
      }
      const room = m.roomAt[i] >= 0 ? m.rooms[m.roomAt[i]] : null;
      ctx.fillStyle = FLOOR_COLORS[room?.kind ?? 'gang'];
      ctx.fillRect(px, py, TILE, TILE);
      if ((x + y) % 2 === 0) {
        ctx.fillStyle = 'rgba(255,255,255,0.025)';
        ctx.fillRect(px, py, TILE, TILE);
      }
      if (tile === 'stairs') {
        ctx.fillStyle = '#ffcc33';
        ctx.font = `bold ${TILE - 4}px JetBrains Mono, monospace`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText('▼', px + TILE / 2, py + TILE / 2 + 1);
      }
      if (!seen) {
        ctx.fillStyle = 'rgba(0,0,0,0.55)';
        ctx.fillRect(px, py, TILE, TILE);
      }
    }
  }

  // --- Pfadvorschau
  if (extras.path) {
    ctx.fillStyle = 'rgba(255, 204, 51, 0.35)';
    for (const p of extras.path) {
      ctx.beginPath();
      ctx.arc(sx(p.x) + TILE / 2, sy(p.y) + TILE / 2, 2.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // --- Gegenstände
  for (const e of s.items) {
    const i = idx(m, e.pos.x, e.pos.y);
    if (!vis.has(i) && !(memory && m.explored[i])) continue;
    const cx = sx(e.pos.x) + TILE / 2;
    const cy = sy(e.pos.y) + TILE / 2;
    ctx.fillStyle = e.item.kind === 'karte' ? '#7cc4ff' : e.item.kind === 'gold' ? '#ffd700' : RARITY_COLORS[e.item.rarity];
    ctx.globalAlpha = vis.has(i) ? 1 : 0.5;
    ctx.beginPath();
    ctx.moveTo(cx, cy - 5);
    ctx.lineTo(cx + 5, cy);
    ctx.lineTo(cx, cy + 5);
    ctx.lineTo(cx - 5, cy);
    ctx.closePath();
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  // --- Monster (nur sichtbare)
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (const mo of s.monsters) {
    if (!vis.has(idx(m, mo.pos.x, mo.pos.y))) continue;
    const cx = sx(mo.pos.x) + TILE / 2;
    const cy = sy(mo.pos.y) + TILE / 2;
    const boss = mo.rank !== 'normal' && mo.rank !== 'elite';
    const r = boss ? TILE / 2 : TILE / 2 - 3;
    ctx.fillStyle = '#140d0a';
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = mo.color;
    ctx.lineWidth = boss ? 3 : 2;
    ctx.stroke();
    ctx.fillStyle = mo.color;
    ctx.font = `bold ${boss ? 13 : 12}px JetBrains Mono, monospace`;
    ctx.fillText(mo.glyph, cx, cy + 1);
    if (mo.hp < mo.maxHp) {
      ctx.fillStyle = '#000';
      ctx.fillRect(sx(mo.pos.x) + 2, sy(mo.pos.y) - 3, TILE - 4, 3);
      ctx.fillStyle = '#ff5a4a';
      ctx.fillRect(sx(mo.pos.x) + 2, sy(mo.pos.y) - 3, (TILE - 4) * Math.max(0, mo.hp / mo.maxHp), 3);
    }
    if (mo.downed > 0) {
      ctx.fillStyle = '#7cc4ff';
      ctx.font = 'bold 10px JetBrains Mono, monospace';
      ctx.fillText('z', sx(mo.pos.x) + TILE - 3, sy(mo.pos.y) + 5);
    } else if (mo.aware) {
      ctx.fillStyle = '#ff5a4a';
      ctx.font = 'bold 11px JetBrains Mono, monospace';
      ctx.fillText('!', sx(mo.pos.x) + TILE - 3, sy(mo.pos.y) + 5);
    }
  }

  // --- Haustier
  const pet = s.player.pet;
  if (pet?.alive) {
    const cx = sx(pet.pos.x) + TILE / 2;
    const cy = sy(pet.pos.y) + TILE / 2;
    ctx.fillStyle = '#ffb3e6';
    ctx.beginPath();
    ctx.arc(cx, cy, 5, 0, Math.PI * 2);
    ctx.fill();
  }

  // --- Spieler: ein leuchtender Punkt
  const px = sx(s.player.pos.x) + TILE / 2;
  const py = sy(s.player.pos.y) + TILE / 2;
  const glow = ctx.createRadialGradient(px, py, 2, px, py, TILE);
  glow.addColorStop(0, 'rgba(255, 220, 90, 0.45)');
  glow.addColorStop(1, 'rgba(255, 220, 90, 0)');
  ctx.fillStyle = glow;
  ctx.fillRect(px - TILE, py - TILE, TILE * 2, TILE * 2);
  ctx.fillStyle = '#ffdc5a';
  ctx.beginPath();
  ctx.arc(px, py, 6, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = '#fff5cc';
  ctx.lineWidth = 2;
  ctx.stroke();

  // --- Hover-Rahmen
  if (extras.hover) {
    ctx.strokeStyle = 'rgba(255, 204, 51, 0.8)';
    ctx.lineWidth = 1.5;
    ctx.strokeRect(sx(extras.hover.x) + 0.5, sy(extras.hover.y) + 0.5, TILE - 1, TILE - 1);
  }

  return { view, visible: vis };
}
