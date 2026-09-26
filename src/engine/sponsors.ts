import { MAX_SPONSORS, SPONSOR_BY_ID, SPONSORS, type SponsorDef } from '../data/sponsors';
import { BOX_TIER_NAMES, BOX_TYPE_NAMES } from '../data/world';
import { emit } from './events';
import { createBox } from './items';
import { log, toast } from './log';
import type { BoxTier, GameEvent, GameState, SponsorState } from './types';

/**
 * Sponsoren beobachten die Show. Jede Aktion, die ihrem Geschmack entspricht,
 * steigert ihr Interesse; ab 100 (und genug Followern) machen sie ein Angebot.
 * Aktive Sponsoren stellen Wünsche und schicken für jeden erfüllten Wunsch eine
 * Sponsorenbox. Wer tut, was sie hassen, verliert ihre Gunst.
 */

const TIERS: BoxTier[] = ['silber', 'silber', 'gold', 'gold', 'platin'];

export function sponsorStates(s: GameState): SponsorState[] {
  s.sponsors ??= SPONSORS.map((d) => ({ id: d.id, interest: 0, status: 'none', favor: 50, wish: 0, progress: 0, completed: 0 }));
  for (const d of SPONSORS) {
    if (!s.sponsors.some((x) => x.id === d.id)) s.sponsors.push({ id: d.id, interest: 0, status: 'none', favor: 50, wish: 0, progress: 0, completed: 0 });
  }
  return s.sponsors;
}

export const activeSponsors = (s: GameState) => sponsorStates(s).filter((x) => x.status === 'active');

/** Übersetzt ein Spielereignis in Signale, die Sponsoren interessieren. */
export function signalsOf(e: GameEvent): string[] {
  switch (e.type) {
    case 'kill': {
      const out = ['kill'];
      if (e.byPet) out.push('kill|pet');
      else for (const f of e.facets ?? []) out.push(`kill|${f}`);
      return out;
    }
    case 'attack':
      return e.crit ? ['crit'] : [];
    case 'crafted':
      return ['crafted', `crafted|${e.recipe}`];
    case 'trapTriggered':
      return [e.onPlayer ? 'trap|self' : 'trap|monster'];
    case 'trapDisarmed':
      return e.success ? ['trap|disarmed'] : [];
    case 'haggle':
      return [e.success ? 'haggle|ok' : 'haggle|fail'];
    case 'bought':
      return [e.haggled ? 'bought|haggled' : 'bought|full'];
    case 'petGained':
      return ['petGained'];
    case 'petLevel':
      return ['pet|level'];
    case 'petEvolved':
      return ['pet|evolve'];
    case 'talkShow':
      return [`talk|${e.tone}`];
    case 'sleep':
      return ['sleep'];
    case 'eat':
      return ['eat'];
    default:
      return [];
  }
}

function giveReward(s: GameState, def: SponsorDef, st: SponsorState) {
  const tier = TIERS[Math.min(TIERS.length - 1, st.completed)];
  s.player.boxes.push(createBox(s, def.box, tier));
  st.completed += 1;
  st.favor = Math.min(100, st.favor + 15);
  log(s, `SPONSOR: ${def.name} ist zufrieden. Du erhältst eine ${BOX_TIER_NAMES[tier]} ${BOX_TYPE_NAMES[def.box]} als Sponsorengeschenk.`, 'loot');
  toast(s, `Sponsorengeschenk: ${def.name}`, `${BOX_TIER_NAMES[tier]} ${BOX_TYPE_NAMES[def.box]}`, 'loot');
  st.wish = (st.wish + 1) % def.wishes.length;
  st.progress = 0;
  log(s, `${def.name} wünscht sich als Nächstes: ${def.wishes[st.wish].text}`, 'system');
  emit(s, { type: 'sponsorWish', id: def.id, completed: st.completed });
}

export function sponsorsOnEvent(s: GameState, e: GameEvent) {
  if (!s.unlocks.includes('zuschauer') || s.status !== 'playing') return;
  const signals = signalsOf(e);
  if (!signals.length) return;
  for (const st of sponsorStates(s)) {
    const def = SPONSOR_BY_ID[st.id];
    if (!def) continue;
    if (st.status === 'none') {
      let gain = 0;
      for (const sig of signals) gain += def.likes[sig] ?? 0;
      if (!gain) continue;
      // Mehr Hype = mehr Aufmerksamkeit bei den Sponsoren
      st.interest = Math.min(100, st.interest + gain * (0.6 + s.viewers.hype / 100));
      if (st.interest >= 100 && s.viewers.follower >= def.minFollower && activeSponsors(s).length < MAX_SPONSORS) {
        st.status = 'offer';
        log(s, `SPONSORENANGEBOT von ${def.name}: ${def.offer} (Annehmen oder ablehnen im Crawler-Tab.)`, 'system');
        toast(s, 'Sponsorenangebot', def.name, 'loot');
      }
      continue;
    }
    if (st.status !== 'active') continue;
    if (signals.includes(def.dislike.signal)) {
      st.favor -= 15;
      log(s, `${def.name} ist verstimmt: ${def.dislike.text} (Gunst ${Math.max(0, st.favor)})`, 'gefahr');
      if (st.favor <= 0) {
        st.status = 'dropped';
        log(s, `${def.name} beendet das Sponsoring. Die Pressemitteilung ist kurz und gemein.`, 'gefahr');
        emit(s, { type: 'sponsorDropped', id: def.id });
        continue;
      }
    }
    const wish = def.wishes[st.wish];
    const hits = signals.filter((sig) => wish.signals.includes(sig)).length;
    if (!hits) continue;
    st.progress += hits;
    if (st.progress >= wish.count) giveReward(s, def, st);
  }
}

export function acceptSponsor(s: GameState, id: string): { ok: boolean; message?: string } {
  const st = sponsorStates(s).find((x) => x.id === id);
  const def = SPONSOR_BY_ID[id];
  if (!st || !def || st.status !== 'offer') return { ok: false, message: 'Dieses Angebot gibt es nicht.' };
  if (activeSponsors(s).length >= MAX_SPONSORS) return { ok: false, message: `Mehr als ${MAX_SPONSORS} Sponsoren erlaubt der Vertrag nicht.` };
  st.status = 'active';
  st.favor = 50;
  st.progress = 0;
  log(s, `Du unterschreibst bei ${def.name}. Ihr Logo erscheint klein in der Ecke jeder Übertragung. Erster Wunsch: ${def.wishes[st.wish].text}`, 'system');
  emit(s, { type: 'sponsorJoined', id, count: activeSponsors(s).length });
  return { ok: true };
}

export function declineSponsor(s: GameState, id: string): { ok: boolean; message?: string } {
  const st = sponsorStates(s).find((x) => x.id === id);
  const def = SPONSOR_BY_ID[id];
  if (!st || !def || st.status !== 'offer') return { ok: false, message: 'Dieses Angebot gibt es nicht.' };
  st.status = 'none';
  st.interest = 40;
  log(s, `Du lehnst ${def.name} ab. Vielleicht fragen sie später noch einmal.`, 'info');
  return { ok: true };
}
