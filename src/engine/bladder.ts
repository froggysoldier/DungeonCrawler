import { emit } from './events';
import { log, toast } from './log';
import { isWalkable } from './mapgen';
import { monsterDefById, spawnMonster } from './monsters';
import type { GameState, Pos } from './types';

/**
 * Die wichtigste Regel des Dungeons: Erleichtern darf man sich nur in einer
 * Toilette (in jedem Safe Room gibt es eine). Wer es nicht rechtzeitig
 * schafft, ruft ein Wutelementar herbei – und das ist fast immer tödlich.
 */
const WARNINGS: [number, string][] = [
  [60, 'Du müsstest mal. Nichts Dringendes. Noch nicht.'],
  [80, 'Du musst jetzt wirklich dringend. Such eine Toilette in einem Safe Room.'],
  [95, 'ES IST GLEICH SO WEIT. Die Systemstimme erinnert an die Regel: nur in Toiletten!'],
];

export function addBladder(s: GameState, amount: number) {
  const p = s.player;
  const before = p.blase ?? 0;
  p.blase = Math.min(100, before + amount);
  for (const [t, text] of WARNINGS) {
    if (before < t && p.blase >= t) {
      log(s, text, t >= 80 ? 'gefahr' : 'info');
      if (t >= 80) toast(s, 'Blase', text, 'warnung');
    }
  }
  if (p.blase >= 100) accident(s);
}

/** Die Blase füllt sich langsam: etwa alle 30 Stunden einmal voll. */
export function bladderTick(s: GameState, turns: number) {
  if (!s.unlocks.includes('inventar')) return; // vor dem Tutorial kennt man die Regel noch nicht
  addBladder(s, turns / 6);
}

function accident(s: GameState) {
  const p = s.player;
  p.blase = 0;
  log(s, 'Oh nein. Es ist passiert. Nicht in einer Toilette. Die Luft beginnt zu brodeln …', 'gefahr');
  const def = monsterDefById('wutelementar');
  const spot = neighbors(p.pos).find((q) => isWalkable(s.map, q.x, q.y) && !s.monsters.some((m) => m.pos.x === q.x && m.pos.y === q.y));
  if (def && spot) {
    const m = spawnMonster(s, def, Math.max(15, p.level + 12), spot, -1);
    m.aware = true;
    s.monsters.push(m);
    log(s, 'Ein WUTELEMENTAR erscheint. Es ist sehr, sehr wütend über das, was du getan hast. LAUF.', 'gefahr');
    toast(s, 'Wutelementar!', 'Du hast gegen die Toiletten-Regel verstoßen. Lauf!', 'warnung');
  }
  emit(s, { type: 'accident' });
}

export function useToilet(s: GameState): { ok: boolean; message?: string } {
  const p = s.player;
  if ((p.blase ?? 0) < 5) return { ok: false, message: 'Du musst gerade nicht.' };
  p.blase = 0;
  log(s, 'Du benutzt die Toilette. Erleichterung. Die Systemstimme dreht diskret die Kamera weg. Meistens.', 'info');
  emit(s, { type: 'relief' });
  return { ok: true };
}

function neighbors(p: Pos): Pos[] {
  const out: Pos[] = [];
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (dx || dy) out.push({ x: p.x + dx, y: p.y + dy });
  return out;
}
