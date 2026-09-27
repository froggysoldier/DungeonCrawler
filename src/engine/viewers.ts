import { FAN_GIFTS, FAN_THRESHOLDS, VIEWER_COMMENTS, VIEWER_NAMES } from '../data/viewers';
import { BOX_TIER_NAMES } from '../data/world';
import { emit } from './events';
import { itemName } from './identify';
import { giveItem } from './inventory';
import { traitFollowerMult } from './traits';
import { trainSkill } from './skills';
import { createBox, createItem } from './items';
import { log, toast } from './log';
import { effectiveStats, maxHp } from './player';
import * as R from './rng';
import { track } from './stats';
import { hasSpecial } from './abilities';
import type { GameEvent, GameState } from './types';

/**
 * Zuschauer-System (ab Etage 2). Spektakuläre Aktionen bringen Hype und
 * Follower. Follower-Meilensteine bringen Fan-Boxen, große Momente
 * manchmal Geschenke aus dem Publikum. Langeweile lässt den Hype sinken.
 */
export const viewersActive = (s: GameState) => s.unlocks.includes('zuschauer');

/** Live-Zuschauer: ein Teil der Follower, je nach Hype. */
export function liveViewers(s: GameState): number {
  const v = s.viewers;
  return Math.round(v.follower * (0.15 + v.hype / 120) + v.hype * 3);
}

export function addSpectacle(s: GameState, points: number, kind: string) {
  if (!viewersActive(s) || points <= 0) return;
  const v = s.viewers;
  const cha = effectiveStats(s).cha;
  const stage = 1 + (s.player.skills.find((k) => k.id === 'rampenlicht')?.level ?? 0) * 0.05;
  const mult = Math.max(0.3, 1 + (cha - 5) * 0.08) * (0.5 + v.hype / 50) * (hasSpecial(s, 'reichweite') ? 2 : 1) * traitFollowerMult(s) * stage;
  if (points >= 4) trainSkill(s, 'show', 1);
  v.hype = Math.min(100, v.hype + points * 1.5);
  v.lastSpectacle = s.turn;
  const gained = Math.max(1, Math.round(points * 3 * mult));
  v.follower += gained;

  const comments = VIEWER_COMMENTS[kind];
  if (comments && points >= 4 && R.chance(s, 0.35)) {
    log(s, `Zuschauer ${R.pick(s, VIEWER_NAMES)}: „${R.pick(s, comments)}“`, 'dialog');
  }
  // Große Momente: Geschenk aus dem Publikum
  if (points >= 15 && R.chance(s, Math.min(0.6, 0.15 + (cha - 5) * 0.03))) fanGift(s);

  while (v.nextFanBox < FAN_THRESHOLDS.length && v.follower >= FAN_THRESHOLDS[v.nextFanBox][0]) {
    const [threshold, tier] = FAN_THRESHOLDS[v.nextFanBox];
    v.nextFanBox += 1;
    s.player.boxes.push(createBox(s, 'fan', tier));
    log(s, `${threshold} Follower! Die Fans schicken dir eine ${BOX_TIER_NAMES[tier]} Fan-Box.`, 'loot');
    toast(s, `${threshold} Follower!`, `${BOX_TIER_NAMES[tier]} Fan-Box erhalten`, 'loot');
  }
  emit(s, { type: 'followers', follower: v.follower });
}

export function fanGift(s: GameState) {
  const item = createItem(s, R.pick(s, FAN_GIFTS));
  giveItem(s, item);
  track(s, 'fangeschenke');
  log(s, `Zuschauer ${R.pick(s, VIEWER_NAMES)} schickt dir ein Geschenk: ${itemName(s, item)}!`, 'loot');
}

/** Zeit vergeht: Hype kühlt ab, bei Langeweile murrt das Publikum. */
export function viewersTick(s: GameState, turns: number) {
  if (!viewersActive(s)) return;
  const v = s.viewers;
  v.hype = Math.max(0, v.hype - turns * 0.4);
  if (turns === 1 && s.turn - v.lastSpectacle > 80 && R.chance(s, 0.02)) {
    log(s, `Zuschauer ${R.pick(s, VIEWER_NAMES)}: „${R.pick(s, VIEWER_COMMENTS.boring)}“`, 'dialog');
  }
}

export function viewersOnEvent(s: GameState, e: GameEvent) {
  if (!viewersActive(s)) return;
  switch (e.type) {
    case 'kill': {
      const m = e.monster;
      let pts = 2 + Math.floor(m.level / 2);
      let kind = 'kill';
      if (e.technique?.move === 'stampfen') { pts += 6; kind = 'stomp'; }
      if (e.technique?.move === 'sprung') { pts += 5; kind = 'jump'; }
      if (e.technique?.move === 'anlauf') pts += 3;
      if (e.technique?.part === 'kopf') pts += 3;
      if (m.rank === 'elite') pts += 8;
      if (m.rank === 'nachbarschaftsboss') { pts += 40; kind = 'boss'; }
      if (m.rank === 'boroughboss') { pts += 100; kind = 'boss'; }
      if (m.rank === 'geist') pts += 40;
      if (e.byPet) { pts += 6; kind = 'pet'; }
      if (m.fleeing) pts += 3;
      if (e.facets?.includes('t:falle')) { pts += 5; kind = 'trap'; }
      if (e.facets?.includes('t:bombe')) { pts += 4; kind = 'bomb'; }
      addSpectacle(s, pts, kind);
      break;
    }
    case 'trapTriggered':
      // Das Publikum liebt es, wenn jemand in eine Falle tritt – egal wer
      addSpectacle(s, e.onPlayer ? 4 : 3, 'trap');
      break;
    case 'crawlerDied':
      if (e.party) addSpectacle(s, 10, 'drama');
      break;
    case 'rammed':
      addSpectacle(s, e.kill ? 7 : 4, 'stomp');
      break;
    case 'partyJoined':
      addSpectacle(s, 3, 'party');
      break;
    case 'attack':
      if (e.crit) addSpectacle(s, 3, 'crit');
      if (e.damage >= 25) addSpectacle(s, 4, 'crit');
      break;
    case 'damageTaken':
      if (s.player.hp <= maxHp(s) * 0.2 && s.turn - (s.viewers.lastCloseCall ?? -999) > 20) {
        s.viewers.lastCloseCall = s.turn;
        addSpectacle(s, 8, 'closecall');
      }
      break;
    case 'explosion':
      addSpectacle(s, 5, 'closecall');
      break;
    case 'robbed':
      addSpectacle(s, 4, 'kill');
      break;
    case 'levelUp':
      addSpectacle(s, 10, 'achievement');
      break;
    case 'boxOpened':
      addSpectacle(s, 3, 'item');
      break;
    default:
      break;
  }
}
