import { emit } from './events';
import { log } from './log';
import { maxHp } from './player';
import type { GameState } from './types';

/** Tod – außer die Zweite-Chance-Klausel greift. */
export function handleLethal(s: GameState, cause: string) {
  const p = s.player;
  const slot = (Object.entries(p.equipment) as [string, { special?: string } | undefined][]).find(
    ([, it]) => it?.special === 'zweite_chance',
  )?.[0];
  if (slot) {
    delete (p.equipment as Record<string, unknown>)[slot];
    if (!p.curses.includes('Kleingedrucktes')) p.curses.push('Kleingedrucktes');
    p.hp = Math.ceil(maxHp(s) / 2);
    log(s, 'Die Welt wird schwarz… und dann wieder hell. Die Zweite-Chance-Klausel zerfällt zu Staub. Das Kleingedruckte: dauerhaft −5 max. HP und −1 Charisma.', 'system');
    emit(s, { type: 'revived' });
    return;
  }
  p.hp = 0;
  s.status = 'dead';
  s.deathCause = cause;
  if (s.contractSigned) {
    s.deathCause = `${cause} – doch der Vertrag greift: in den Dienst der Show übernommen`;
    log(s, 'Kurz bevor alles schwarz wird, leuchtet dein Vertrag auf. Du stirbst nicht. Du wirst… Personal.', 'system');
  }
  log(s, `Du bist gestorben (${cause}).`, 'gefahr');
}

