import { classSkillsOf } from './classes';
import type { GameState, Item, MetaState } from './types';

const META_KEY = 'grosser-abstieg.meta.v1';
const RUN_KEY = 'grosser-abstieg.run.v1';

export function emptyMeta(): MetaState {
  return { season: 0, achievementsEver: [], bestiary: {}, hallOfFame: [], ghosts: [], guides: [] };
}

function storage(): Storage | null {
  try {
    return typeof localStorage === 'undefined' ? null : localStorage;
  } catch {
    return null;
  }
}

export function loadMeta(): MetaState {
  try {
    const raw = storage()?.getItem(META_KEY);
    return raw ? { ...emptyMeta(), ...JSON.parse(raw) } : emptyMeta();
  } catch {
    return emptyMeta();
  }
}

export function saveMeta(meta: MetaState) {
  try {
    storage()?.setItem(META_KEY, JSON.stringify(meta));
  } catch {
    /* Speicher nicht verfügbar – dann eben ohne. */
  }
}

export function saveRun(s: GameState) {
  try {
    storage()?.setItem(RUN_KEY, JSON.stringify(s));
  } catch {
    /* ignorieren */
  }
}

export function loadRun(): GameState | null {
  try {
    const raw = storage()?.getItem(RUN_KEY);
    if (!raw) return null;
    const s = migrate(JSON.parse(raw) as GameState);
    return s.status === 'playing' ? s : null;
  } catch {
    return null;
  }
}

/** Ergänzt Felder, die ältere Spielstände noch nicht hatten. */
export function migrate(s: GameState): GameState {
  s.viewers ??= { follower: 0, hype: 0, nextFanBox: 0, lastSpectacle: 0 };
  s.pendingSelection ??= false;
  s.player.traits ??= [];
  const counters = s.counters as unknown as Record<string, number>;
  for (const k of ['goldEarned', 'goldStolen', 'poisonDamage', 'mealsEaten', 'potionsDrunk', 'sleeps', 'crits', 'knockdowns', 'eliteKills', 'trapsFound', 'trapsTriggered', 'trapsDisarmed', 'trapKills', 'crafted']) {
    counters[k] ??= 0;
  }
  // Wer mit altem Spielstand schon auf Etage 2 ist, bekommt das Publikum nachträglich
  if (s.floor >= 2 && !s.unlocks.includes('zuschauer')) s.unlocks.push('zuschauer');
  // Klassenskills und Begabung für Spielstände von vor dem Klassen-Umbau
  if (s.player.klass && !s.player.classSkills) s.player.classSkills = classSkillsOf(s.player.race, s.player.klass);
  s.stats ??= {};
  return s;
}

export function deleteRun() {
  try {
    storage()?.removeItem(RUN_KEY);
  } catch {
    /* ignorieren */
  }
}

/** Überträgt laufende Erfolge in den Meta-Fortschritt (auch mitten im Run). */
export function syncMeta(meta: MetaState, s: GameState) {
  meta.achievementsEver = [...new Set([...meta.achievementsEver, ...s.achievements])];
}

function bestItems(s: GameState): Item[] {
  return Object.values(s.player.equipment)
    .filter((i): i is Item => !!i)
    .sort((a, b) => b.wert - a.wert)
    .slice(0, 3)
    .map((i) => structuredClone(i));
}

/**
 * Ende einer Staffel. Hardcore: der Run wird gelöscht. Übrig bleiben
 * Hall of Fame, Achievements, Bestiarium – und je nach Ausgang ein Geist
 * (Tod) oder ein Guide (Vertrag) für kommende Staffeln.
 */
export function recordRunEnd(meta: MetaState, s: GameState): MetaState {
  syncMeta(meta, s);
  meta.season = Math.max(meta.season, s.season);
  for (const [k, v] of Object.entries(s.counters.killsByDef)) meta.bestiary[k] = (meta.bestiary[k] ?? 0) + v;
  const outcome = s.status === 'victory' ? 'ueberlebt' : s.contractSigned ? 'vertrag' : 'tot';
  meta.hallOfFame.push({
    season: s.season,
    name: s.player.name,
    background: s.player.background,
    level: s.player.level,
    floor: s.floor,
    kills: s.counters.kills,
    achievements: s.achievements.length,
    cause: s.status === 'victory' ? `Etage ${s.floor} überlebt` : s.deathCause ?? 'unbekannt',
    outcome,
  });
  meta.ghosts = meta.ghosts.filter((g) => !s.ghostsDefeated.includes(g.name));
  if (outcome === 'tot') {
    meta.ghosts.push({ name: s.player.name, floor: s.floor, level: s.player.level, season: s.season, items: bestItems(s) });
    meta.ghosts = meta.ghosts.slice(-10);
  }
  if (outcome === 'vertrag') meta.guides.push({ name: s.player.name, season: s.season, level: s.player.level });
  deleteRun();
  saveMeta(meta);
  return meta;
}
