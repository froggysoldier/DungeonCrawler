import {
  SHOW_HOST, SHOW_INTRO, SHOW_OUTRO_BAD, SHOW_OUTRO_GOOD, SHOW_OUTRO_OK, SHOW_QUESTIONS, SHOW_TITLE, type ShowQuestionDef,
} from '../data/talkshow';
import { FLOORS } from '../data/world';
import { ACHIEVEMENTS } from '../data/achievements';
import { PART_NAMES } from './bonuses';
import { population } from './crawlers';
import { emit } from './events';
import { createBox } from './items';
import { log } from './log';
import { effectiveStats } from './player';
import * as R from './rng';
import type { AttackPart, Dialog, GameState, ShowTone, TalkShow } from './types';

// ================================================================ Rückblick

/** Hält den Stand zu Beginn einer Etage fest. */
export function snapshotFloor(s: GameState) {
  const { killsByDef: _ignored, ...counters } = s.counters;
  s.floorSnapshot = {
    turn: s.turn,
    counters: { ...counters },
    achievements: s.achievements.length,
    patterns: s.dynAchievements?.length ?? 0,
    follower: s.viewers.follower,
    fallen: s.fallen?.length ?? 0,
    level: s.player.level,
  };
}

const fmt = (n: number) => Math.round(n).toLocaleString('de-DE');

function favoritePart(s: GameState): AttackPart | null {
  const byPart: Record<string, number> = {};
  for (const [k, v] of Object.entries(s.player.techniqueKills)) {
    const part = k.split('+')[0];
    byPart[part] = (byPart[part] ?? 0) + v;
  }
  const best = Object.entries(byPart).sort((a, b) => b[1] - a[1])[0];
  return best ? (best[0] as AttackPart) : null;
}

/** Rückblick auf die gerade beendete Etage – als Dialogseiten. */
export function floorRecap(s: GameState): Dialog {
  const snap = s.floorSnapshot;
  const c = s.counters;
  const d = (k: keyof NonNullable<typeof snap>['counters']) => (c[k] as number) - ((snap?.counters[k] as number) ?? 0);
  const def = FLOORS.find((f) => f.floor === s.floor);
  const turns = s.turn - (snap?.turn ?? s.floorStartTurn);
  const newAch = s.achievements.slice(snap?.achievements ?? 0).map((id) => ACHIEVEMENTS.find((a) => a.id === id)?.name).filter(Boolean);
  const newPatterns = (s.dynAchievements ?? []).slice(snap?.patterns ?? 0).map((a) => a.name);
  const fallen = (s.fallen ?? []).slice(snap?.fallen ?? 0);
  const pages: string[] = [];

  const fight = [
    `Kampf: ${d('kills')} Gegner besiegt${d('eliteKills') ? `, davon ${d('eliteKills')} Elite` : ''}${d('bossKills') ? `, ${d('bossKills')} Boss${d('bossKills') > 1 ? 'e' : ''}` : ''}.`,
    `Schaden ausgeteilt: ${fmt(d('damageDealt'))}. Schaden eingesteckt: ${fmt(d('damageTaken'))}. Kritische Treffer: ${d('crits')}. Gegner umgeworfen: ${d('knockdowns')}.`,
  ];
  const fav = favoritePart(s);
  if (fav) fight.push(`Liebste Angriffsart bisher: ${PART_NAMES[fav]}.`);
  pages.push(`RÜCKBLICK: ETAGE ${s.floor}${def ? ` – ${def.name}` : ''}\n\nDu hast ${fmt(turns)} Züge auf dieser Etage verbracht und bist mit Level ${s.player.level} abgestiegen${snap && s.player.level > snap.level ? ` (${s.player.level - snap.level} Level aufgestiegen)` : ''}.\n\n${fight.join(' ')}`);

  const misc: string[] = [];
  misc.push(`Gegenstände aufgehoben: ${d('itemsPicked')}. Lootboxen geöffnet: ${d('boxesOpened')}. Gold verdient: ${fmt(d('goldEarned'))}.`);
  if (d('trapsFound') || d('trapsTriggered') || d('trapsDisarmed')) {
    misc.push(`Fallen: ${d('trapsFound')} entdeckt, ${d('trapsDisarmed')} entschärft, ${d('trapsTriggered')} selbst ausgelöst.`);
  }
  if (d('crafted') || d('trapKills')) misc.push(`Handwerk: ${d('crafted')} Dinge gebaut, ${d('trapKills')} Gegner durch Fallen und Sprengsätze erledigt.`);
  if (d('potionsDrunk') || d('mealsEaten')) misc.push(`Tränke getrunken: ${d('potionsDrunk')}. Mahlzeiten: ${d('mealsEaten')}.`);
  pages.push(misc.join('\n\n'));

  const social: string[] = [];
  if (newAch.length) social.push(`Neue Achievements (${newAch.length}): ${newAch.join(', ')}.`);
  if (newPatterns.length) social.push(`Die Systemstimme hat Muster erkannt: ${newPatterns.join(', ')}.`);
  if (s.unlocks.includes('zuschauer') && snap) {
    const gained = s.viewers.follower - snap.follower;
    social.push(`Follower: ${fmt(s.viewers.follower)} (${gained >= 0 ? '+' : ''}${fmt(gained)} auf dieser Etage).`);
  }
  const members = (s.crawlers ?? []).filter((x) => x.alive && x.party);
  if (members.length) social.push(`Deine Party: ${members.map((m) => `${m.name} (Level ${m.level}, ${m.kills} Kills)`).join(', ')}.`);
  if (fallen.length) social.push(`Gefallen: ${fallen.join(', ')}. Die Systemstimme vermerkt es. Du wirst es nicht so schnell vergessen.`);
  social.push(`Laut letzter Zählung leben noch ${fmt(population(s).alive)} Crawler.`);
  pages.push(social.join('\n\n'));
  return { title: `Rückblick: Etage ${s.floor}`, speaker: 'Die Systemstimme', pages };
}

// ================================================================ Talkshow

function fill(s: GameState, text: string): string {
  const pet = s.player.pet;
  const fav = favoritePart(s);
  return text
    .replaceAll('{name}', s.player.name)
    .replaceAll('{background}', s.player.background)
    .replaceAll('{haustier}', pet?.name ?? 'dein Haustier')
    .replaceAll('{gefallen}', s.fallen?.[s.fallen.length - 1] ?? 'Jemand')
    .replaceAll('{kills}', fmt(s.counters.kills))
    .replaceAll('{lieblingsangriff}', fav ? `${PART_NAMES[fav]}-Angriffen` : 'bloßen Händen')
    .replaceAll('{achievements}', String(s.achievements.length));
}

function pickQuestions(s: GameState): ShowQuestionDef[] {
  const pool = SHOW_QUESTIONS.filter((q) => q.id !== 'plan' && q.when(s));
  // Nach Priorität, bei Gleichstand zufällig
  const ranked = pool
    .map((q) => ({ q, r: q.priority + R.next(s) * 0.9 }))
    .sort((a, b) => b.r - a.r)
    .map((x) => x.q);
  const plan = SHOW_QUESTIONS.find((q) => q.id === 'plan')!;
  return [...ranked.slice(0, 2), plan];
}

/** Erzeugt die Talkshow und hängt sie als Sonderdialog an. */
export function startTalkShow(s: GameState): Dialog {
  const questions = pickQuestions(s).map((q) => ({
    id: q.id,
    text: fill(s, q.text),
    answers: q.answers.map((a) => ({ label: fill(s, a.label), tone: a.tone })),
  }));
  s.talkShow = { host: SHOW_HOST, title: SHOW_TITLE, questions, index: 0, followerDelta: 0, done: false };
  return { kind: 'talkshow', title: SHOW_TITLE, speaker: SHOW_HOST, pages: SHOW_INTRO.map((p) => fill(s, p)) };
}

export interface ShowAnswerResult {
  ok: boolean;
  reaction?: string;
  delta?: number;
  finished?: boolean;
  outro?: string;
}

/** Beantwortet die aktuelle Frage. Wirkung: Follower und Hype. */
export function answerShow(s: GameState, answerIndex: number): ShowAnswerResult {
  const show: TalkShow | undefined = s.talkShow;
  if (!show || show.done) return { ok: false };
  const q = show.questions[show.index];
  const def = SHOW_QUESTIONS.find((x) => x.id === q?.id);
  const a = def?.answers[answerIndex];
  if (!q || !def || !a) return { ok: false };

  const cha = effectiveStats(s).cha;
  const v = s.viewers;
  const scale = Math.min(60, 3 + v.follower * 0.04);
  const chaMult = Math.max(0.4, 1 + (cha - 5) * 0.08);
  let delta: number;
  let reaction = a.reaction;
  if (a.risky) {
    const chance = Math.max(0.1, Math.min(0.9, 0.35 + (cha - 5) * 0.06 + v.hype / 300));
    if (R.chance(s, chance)) delta = Math.round(Math.abs(a.base) * scale * chaMult * 1.3);
    else {
      delta = -Math.round(Math.abs(a.base) * scale * 0.6);
      reaction = a.failReaction ?? reaction;
    }
  } else {
    delta = Math.round(a.base * scale * (a.base > 0 ? chaMult : 1));
  }
  v.follower = Math.max(0, v.follower + delta);
  v.hype = Math.max(0, Math.min(100, v.hype + (delta > 0 ? 8 : -10)));
  show.followerDelta += delta;
  show.index += 1;
  log(s, `Talkshow – ${fill(s, a.label)}: ${reaction} (${delta >= 0 ? '+' : ''}${fmt(delta)} Follower)`, 'dialog');

  const tone: ShowTone = a.tone;
  if (show.index < show.questions.length) return { ok: true, reaction, delta };

  show.done = true;
  const total = show.followerDelta;
  const outroTpl = total >= 150 ? SHOW_OUTRO_GOOD : total >= 0 ? SHOW_OUTRO_OK : SHOW_OUTRO_BAD;
  const outro = fill(s, outroTpl);
  log(s, `Talkshow vorbei. ${outro} Bilanz: ${total >= 0 ? '+' : ''}${fmt(total)} Follower.`, 'system');
  if (total >= 150) s.player.boxes.push(createBox(s, 'fan', total >= 600 ? 'gold' : 'silber'));
  emit(s, { type: 'talkShow', delta: total, tone });
  return { ok: true, reaction, delta, finished: true, outro };
}
