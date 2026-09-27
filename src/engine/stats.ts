import { chebyshev } from './fov';
import { monsterInsight } from './identify';
import { tileAt } from './mapgen';
import { currentWeapon, maxHp } from './player';
import type { GameEvent, GameState, Monster } from './types';

/**
 * Statistik: Der Dungeon zählt alles mit. Aus diesen Zahlen entstehen die
 * gestuften Achievements (Familien) und die Statistik-Anzeige.
 *
 * Schlüssel sind einfache Texte, z. B. „kills“, „kills.teil.tritt“,
 * „kills.art.kellerratte“, „max.treffer“. Werte beginnen mit „max.“, wenn
 * nur der Höchstwert zählt.
 */
export function stat(s: GameState, key: string): number {
  return s.stats?.[key] ?? 0;
}

export function track(s: GameState, key: string, amount = 1) {
  s.stats ??= {};
  s.stats[key] = (s.stats[key] ?? 0) + amount;
}

export function trackMax(s: GameState, key: string, value: number) {
  s.stats ??= {};
  if (value > (s.stats[key] ?? 0)) s.stats[key] = value;
}

function set(s: GameState, key: string, value: number) {
  s.stats ??= {};
  s.stats[key] = value;
}

/** Womit ein Kill erzielt wurde – für die Technik-Familien. */
function killPart(e: Extract<GameEvent, { type: 'kill' }>): string {
  if (e.byAlly) return 'party';
  if (e.byPet) return 'haustier';
  const t = e.facets?.find((f) => f.startsWith('t:'))?.slice(2);
  if (t) return t;
  return e.technique?.part ?? 'sonstiges';
}

function onKill(s: GameState, e: Extract<GameEvent, { type: 'kill' }>) {
  const m: Monster = e.monster;
  const p = s.player;
  track(s, 'kills');
  track(s, `kills.art.${m.defId}`);
  if (stat(s, `kills.art.${m.defId}`) === 1) track(s, 'bestiarium.arten');
  track(s, `kills.teil.${killPart(e)}`);
  if (e.technique && !e.byPet) {
    if (e.technique.move !== 'normal') track(s, `kills.bewegung.${e.technique.move}`);
    if (e.technique.zone && e.technique.zone !== 'koerper') track(s, `kills.zone.${e.technique.zone}`);
  }
  if (m.rank === 'elite') track(s, 'kills.elite');
  if (m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss') track(s, 'kills.boss');
  if (m.asleep) track(s, 'kills.schlafend');
  if (m.fleeing) track(s, 'kills.fliehend');
  if (m.downed > 0) track(s, 'kills.liegend');
  if (m.stunned) track(s, 'kills.benommen');
  const diff = m.level - p.level;
  if (diff >= 3) track(s, 'kills.staerker');
  if (diff <= -5) track(s, 'kills.harmlos');
  if (p.hp > 0 && p.hp < maxHp(s) * 0.2) track(s, 'kills.fasttot');
  if (m.defId === 'abtruenniger_crawler') track(s, 'kills.crawler');
  if (stat(s, '_konter')) track(s, 'kills.konter');
  // Art erkannt? Erst dann darf ihr Name in Achievements auftauchen.
  if (monsterInsight(s, m) <= 2) set(s, `bekannt.${m.defId}`, 1);
  else track(s, 'kills.unbekannt');
  // Ein einziger Treffer hätte gereicht: Schaden mindestens so hoch wie die vollen Lebenspunkte
  if (e.technique && !e.byPet && !stat(s, '_konter') && stat(s, '_letzterSchaden') >= m.maxHp) track(s, 'kills.einschlag');
  if (tileAt(s.map, m.pos.x, m.pos.y) === 'dooropen') track(s, 'kills.tuer');
  if (m.size === 'riesig') track(s, 'kills.riesig');
  if (e.technique?.part === 'wurf' && chebyshev(p.pos, m.pos) >= 5) track(s, 'kills.weitwurf');
  // Mehrere Gegner mit einer Explosion
  if (e.facets?.includes('t:bombe') || e.facets?.includes('t:falle')) {
    set(s, '_explosionKills', stat(s, '_explosionZug') === s.turn ? stat(s, '_explosionKills') + 1 : 1);
    set(s, '_explosionZug', s.turn);
    trackMax(s, 'max.explosionkills', stat(s, '_explosionKills'));
  }
  // Serien: mehrere Kills kurz hintereinander, Kills ohne erlittenen Schaden
  const last = stat(s, '_letzterKill');
  set(s, '_killserie', s.turn - last <= 2 && last > 0 ? stat(s, '_killserie') + 1 : 1);
  set(s, '_letzterKill', s.turn);
  trackMax(s, 'max.killserie', stat(s, '_killserie'));
  set(s, '_sauber', stat(s, '_sauber') + 1);
  trackMax(s, 'max.sauber', stat(s, '_sauber'));
  if (e.byPet && !e.byAlly) track(s, 'haustier.kills');
  onKillMoments(s, e, diff);
}

/** Besondere Umstände eines Kills – Grundlage der Moment-Achievements. */
function onKillMoments(s: GameState, e: Extract<GameEvent, { type: 'kill' }>, diff: number) {
  const m = e.monster;
  const p = s.player;
  const mh = maxHp(s);
  const own = !e.byPet && !e.byAlly;
  const f = e.facets ?? [];
  if (diff >= 6) track(s, 'kills.toedlich');
  if (m.rank === 'elite' && diff >= 3) track(s, 'kills.elite.staerker');
  if ((m.zonesHit ?? []).filter((z) => z !== 'koerper').length >= 3) track(s, 'kills.anatomie');
  if (own && e.technique && p.ausdauer <= 0) track(s, 'kills.erschoepft');
  if (own && !Object.values(p.equipment).some(Boolean)) track(s, 'kills.nackt');
  if (own && f.includes('i:barfuss')) track(s, 'kills.barfuss');
  if (own && f.includes('i:bademantel')) track(s, 'kills.bademantel');
  if (own && f.includes('i:umzingelt')) track(s, 'kills.umzingelt');
  if (own && f.includes('i:angetrunken')) track(s, 'kills.angetrunken');
  if (own && f.includes('i:brennend')) track(s, 'kills.selbstbrennend');
  if (own && f.includes('i:geblendet')) track(s, 'kills.geblendet');
  if (own && f.includes('i:veraengstigt')) track(s, 'kills.veraengstigt');
  if (own && e.technique?.part === 'waffe') {
    const w = currentWeapon(s);
    if (w) track(s, `kills.waffe.${w.baseId}`);
  }
  if (p.hp > 0 && p.hp < mh * 0.2) {
    if (e.byAlly) track(s, 'rettung.party');
    else if (e.byPet) track(s, 'rettung.haustier');
  }
  if (m.rank !== 'nachbarschaftsboss' && m.rank !== 'boroughboss') return;
  if (p.hp >= mh) track(s, 'boss.makellos');
  if (f.includes('t:zauber')) track(s, 'boss.zauber');
  if (f.includes('t:falle') || f.includes('t:bombe')) track(s, 'boss.falle');
  if (e.byAlly) track(s, 'boss.party');
  else if (e.byPet) track(s, 'boss.haustier');
  if (own && e.technique?.move === 'sprung') track(s, 'boss.sprung');
  if (own && e.technique?.zone === 'kopf') track(s, 'boss.kopf');
  if (own && e.technique?.move === 'anlauf' && p.riding) track(s, 'boss.gerammt');
  if (stat(s, '_konter')) track(s, 'boss.konter');
  if (m.asleep) track(s, 'boss.schlafend');
}

/** Wach und feindlich gesinnt in der Nähe? */
function threatsNear(s: GameState, range: number): number {
  return s.monsters.filter((m) => m.aware && !m.fleeing && m.hp > 0 && chebyshev(m.pos, s.player.pos) <= range).length;
}

/** Ereignisse in Statistik übersetzen (läuft vor den Achievements). */
export function statsOnEvent(s: GameState, e: GameEvent) {
  switch (e.type) {
    case 'kill':
      onKill(s, e);
      break;
    case 'attack':
      set(s, '_letzterSchaden', e.hit ? e.damage : 0);
      if (e.hit) {
        track(s, 'treffer');
        track(s, 'schaden.ausgeteilt', e.damage);
        trackMax(s, 'max.treffer', e.damage);
        if (e.crit) track(s, 'krits');
      } else track(s, 'fehlschlaege');
      if (e.thrown) track(s, 'wuerfe');
      break;
    case 'damageTaken': {
      track(s, 'schaden.erlitten', e.amount);
      set(s, '_sauber', 0);
      const hp = s.player.hp;
      if (hp > 0 && hp <= maxHp(s) * 0.1) track(s, 'knapp.ueberlebt');
      if (hp === 1) track(s, 'ueberlebt.einlp');
      break;
    }
    case 'explosion':
      if (e.source === 'eigener Sprengsatz') track(s, 'explosion.selbst');
      break;
    case 'potion':
      track(s, 'traenke');
      if (e.hpBefore > 0 && e.hpBefore < maxHp(s) * 0.1) track(s, 'traenke.knapp');
      break;
    case 'levelUp':
      set(s, '_aufstiege', stat(s, '_aufstiegZug') === s.turn ? stat(s, '_aufstiege') + 1 : 1);
      set(s, '_aufstiegZug', s.turn);
      trackMax(s, 'max.aufstiege.zug', stat(s, '_aufstiege'));
      if (s.monsters.filter((m) => m.hp > 0 && chebyshev(m.pos, s.player.pos) <= 1).length >= 2) track(s, 'aufstieg.umzingelt');
      break;
    case 'sleep':
      track(s, 'geschlafen');
      set(s, '_letzterSchlaf', s.turn);
      break;
    case 'doorClosed':
      track(s, 'tueren.geschlossen');
      if (s.monsters.some((m) => m.aware && chebyshev(m.pos, e.pos) <= 3)) track(s, 'tueren.zugeschlagen');
      break;
    case 'dodged':
      track(s, 'ausgewichen');
      break;
    case 'enterRoom':
      if (e.first) {
        track(s, 'raeume.entdeckt');
        if (e.room.kind === 'safe') track(s, 'saferooms.entdeckt');
      }
      if (e.room.kind === 'safe' && threatsNear(s, 2) > 0) track(s, 'saferoom.knapp');
      trackMax(s, 'max.erkundet', exploredPct(s));
      break;
    case 'doorOpened':
      track(s, 'tueren.geoeffnet');
      break;
    case 'pickup':
      track(s, 'gegenstaende.aufgehoben');
      track(s, `fund.${e.item.rarity}`);
      break;
    case 'boxOpened':
      track(s, 'boxen.geoeffnet');
      if (e.item.box) track(s, `boxen.stufe.${e.item.box.tier}`);
      break;
    case 'bought': {
      track(s, 'gekauft');
      track(s, 'gold.ausgegeben', e.price);
      const pos = s.player.pos;
      const room = s.map.rooms.find((r) => pos.x >= r.x && pos.x < r.x + r.w && pos.y >= r.y && pos.y < r.y + r.h);
      if (room?.shop && room.shop.offers.length === 0) track(s, 'laden.leergekauft');
      break;
    }
    case 'sold':
      track(s, 'verkauft');
      break;
    case 'haggle':
      if (e.success) {
        track(s, 'feilschen.gewonnen');
        if (e.percent >= 25) track(s, 'feilschen.maximal');
        set(s, '_feilschpleiten', 0);
      } else {
        set(s, '_feilschpleiten', stat(s, '_feilschpleiten') + 1);
        trackMax(s, 'max.feilschpleiten', stat(s, '_feilschpleiten'));
      }
      break;
    case 'lottery':
      track(s, 'lose');
      if (e.outcome === 'niete') track(s, 'lose.nieten');
      if (e.outcome === 'jackpot') track(s, 'lose.jackpot');
      break;
    case 'relief':
      track(s, 'toilette');
      if (threatsNear(s, 5) > 0) track(s, 'toilette.imkampf');
      break;
    case 'accident':
      track(s, 'unfall');
      break;
    case 'conditioned':
      track(s, 'zustand.erlitten');
      track(s, `zustand.erlitten.${e.condition}`);
      break;
    case 'eat':
      track(s, 'gegessen');
      if (threatsNear(s, 2) > 0) track(s, 'essen.imkampf');
      break;
    case 'goldGained':
      trackMax(s, 'max.gold', s.player.gold);
      break;
    case 'questFailed':
      track(s, 'auftraege.verpatzt');
      break;
    case 'trapPlaced':
      track(s, 'fallen.aufgestellt');
      break;
    case 'crafted':
      track(s, `hergestellt.${e.recipe}`);
      break;
    case 'spellCast':
      track(s, 'zauber.gewirkt');
      track(s, `zauber.${e.spell}`);
      break;
    case 'crawlerMet':
      track(s, 'crawler.getroffen');
      break;
    case 'partyJoined':
      track(s, 'party.beigetreten');
      break;
    case 'crawlerDied':
      if (e.party) track(s, 'party.verloren');
      break;
    case 'questDone':
      track(s, 'auftraege.erledigt');
      break;
    case 'sponsorWish':
      track(s, 'sponsor.wuensche');
      break;
    case 'rammed':
      track(s, 'reittier.rammen');
      if (e.kill) track(s, 'reittier.kills');
      break;
    case 'talkShow':
      track(s, 'talkshows');
      break;
    case 'moved':
      if (s.player.riding) track(s, 'reittier.schritte');
      trackMax(s, 'max.wach', s.turn - stat(s, '_letzterSchlaf'));
      break;
    case 'descend':
      trackMax(s, 'max.erkundet', exploredPct(s));
      break;
    default:
      break;
  }
}

/** Wie viel Prozent der begehbaren Fläche dieser Etage schon entdeckt sind. */
export function exploredPct(s: GameState): number {
  let open = 0;
  let seen = 0;
  const t = s.map.tiles;
  for (let i = 0; i < t.length; i++) {
    if (t[i] === 'wall') continue;
    open++;
    if (s.map.explored[i]) seen++;
  }
  return open ? Math.floor((100 * seen) / open) : 0;
}
