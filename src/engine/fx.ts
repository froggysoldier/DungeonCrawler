import type { Fx, GameState, Pos } from './types';

/**
 * Sichtbare Effekte für die Oberfläche: Geschosse und aufsteigende Zahlen.
 * Die Spiellogik hängt sie nur an; die Oberfläche holt sie ab und animiert sie.
 */
function push(s: GameState, f: Fx) {
  s.fx ??= [];
  s.fx.push(f);
  if (s.fx.length > 60) s.fx.splice(0, s.fx.length - 60);
}

export function shot(s: GameState, from: Pos, to: Pos, style: Extract<Fx, { kind: 'shot' }>['style']) {
  push(s, { kind: 'shot', from: { ...from }, to: { ...to }, style });
}

export function floatText(s: GameState, at: Pos, text: string, color: string) {
  push(s, { kind: 'text', at: { ...at }, text, color });
}

export function drainFx(s: GameState): Fx[] {
  const out = s.fx ?? [];
  s.fx = [];
  return out;
}

export const FX_COLORS = {
  schaden: '#ffd0a0',
  krit: '#ff6a3a',
  gegenSpieler: '#ff5a4a',
  heilung: '#6ee07a',
  info: '#c8c0b0',
  mana: '#9fb8ff',
};
