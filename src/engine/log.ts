import type { GameState, LogEntry, Toast } from './types';

const MAX_LOG = 300;

export function log(s: GameState, text: string, kind: LogEntry['kind'] = 'info') {
  s.log.push({ turn: s.turn, text, kind });
  if (s.log.length > MAX_LOG) s.log.splice(0, s.log.length - MAX_LOG);
}

export function toast(s: GameState, title: string, text: string, kind: Toast['kind']) {
  s.toasts.push({ title, text, kind });
}
