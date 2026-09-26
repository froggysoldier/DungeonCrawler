// Zentrale Datentypen. Der gesamte Spielzustand besteht aus reinen
// JSON-Objekten, damit er ohne Umwege gespeichert und geladen werden kann.

export type StatKey = 'str' | 'ges' | 'kon' | 'int' | 'cha';
export type Stats = Record<StatKey, number>;

export interface Pos {
  x: number;
  y: number;
}

// ---------------------------------------------------------------- Karte

export type Tile = 'wall' | 'floor' | 'stairs';

export type RoomKind = 'start' | 'normal' | 'guild' | 'safe' | 'boss' | 'arena';

export interface Room {
  id: number;
  x: number;
  y: number;
  w: number;
  h: number;
  kind: RoomKind;
  /** Nachbarschaft (0–3), in der der Raum liegt. */
  hood: number;
  name: string;
  description: string;
  safeVariant?: 'freebie' | 'restaurant';
  /** Crawler hat den Gratis-Gegenstand dieses Safe Rooms schon abgeholt. */
  freebieTaken?: boolean;
  visited?: boolean;
}

export interface Hood {
  id: number;
  name: string;
  bossAlive: boolean;
  mapFound: boolean;
}

export interface FloorMap {
  width: number;
  height: number;
  tiles: Tile[];
  /** Raum-Index je Kachel, -1 = Gang. */
  roomAt: number[];
  rooms: Room[];
  hoods: Hood[];
  explored: boolean[];
}

// ---------------------------------------------------------------- Items

export type Slot =
  | 'kopf' | 'gesicht' | 'hals' | 'schultern' | 'brust' | 'ruecken' | 'arme'
  | 'haende' | 'ring' | 'guertel' | 'beine' | 'fuesse' | 'fussring'
  | 'unterwaesche' | 'waffe';

export type EquipSlot =
  | Exclude<Slot, 'ring' | 'fussring'>
  | 'ring1' | 'ring2' | 'fussring1' | 'fussring2';

export type Rarity = 'gewoehnlich' | 'ungewoehnlich' | 'selten' | 'episch' | 'legendaer' | 'himmlisch';

export type BoxTier = 'bronze' | 'silber' | 'gold' | 'platin' | 'legendaer' | 'himmlisch';

export type BoxType =
  | 'abenteurer' | 'waffen' | 'schuh' | 'kleidung' | 'schmuck' | 'haustier'
  | 'boss' | 'brawler' | 'wurf' | 'ueberlebens' | 'fan';

/** Bonuswerte, die Items (und Buffs) gewähren können. */
export interface Bonuses {
  stats?: Partial<Stats>;
  maxHp?: number;
  maxAusdauer?: number;
  /** Rüstung reduziert eingehenden Schaden flach. */
  ruestung?: number;
  /** Ausweichchance in Prozentpunkten. */
  ausweichen?: number;
  /** Schadensbonus in Prozent, je Angriffsart oder 'alle'. */
  schaden?: Partial<Record<AttackPart | 'alle', number>>;
  /** Trefferbonus in Prozentpunkten. */
  treffer?: number;
  krit?: number;
  hpRegen?: number;
  xpBonus?: number;
  dornen?: number;
  lichtradius?: number;
}

export type ItemKind = 'ausruestung' | 'wurf' | 'verbrauch' | 'box' | 'karte' | 'gold' | 'schrott';

export interface Item {
  uid: string;
  baseId: string;
  name: string;
  kind: ItemKind;
  rarity: Rarity;
  slot?: Slot;
  bonuses?: Bonuses;
  /** Nur Waffen: Grundschaden. */
  waffenSchaden?: number;
  /** Wurfobjekte: Grundschaden. */
  wurfSchaden?: number;
  /** Verbrauchsgüter. */
  effekt?: ConsumableEffect;
  box?: { type: BoxType; tier: BoxTier };
  /** Gebietskarte: welche Nachbarschaft. */
  hood?: number;
  menge?: number;
  flavor: string;
  special?: SpecialEffect;
  wert: number;
}

export type SpecialEffect =
  | 'zweite_chance' | 'stampf_beben' | 'katzenfreund' | 'glueckspilz' | 'giftimmun' | 'goldmagnet'
  | 'explosionsschutz' | 'bumerang' | 'vampir';

export interface ConsumableEffect {
  heal?: number;
  /** Heilt Vergiftung. */
  cure?: boolean;
  ausdauer?: number;
  buff?: { name: string; turns: number; bonuses: Bonuses };
}

// ---------------------------------------------------------------- Kampf

export type AttackPart = 'faust' | 'tritt' | 'knie' | 'ellbogen' | 'kopf' | 'waffe' | 'wurf';
export type AttackMove = 'normal' | 'sprung' | 'stampfen' | 'anlauf';

export interface Technique {
  part: AttackPart;
  move: AttackMove;
}

// ---------------------------------------------------------------- Wesen

export type MonsterSize = 'winzig' | 'klein' | 'mittel' | 'gross' | 'riesig';
export type Behavior = 'melee' | 'ranged' | 'coward' | 'boss' | 'stationary';

/**
 * Besondere Fähigkeiten von Monstern:
 * gift – Treffer vergiften · explodiert – explodiert beim Tod · diebisch – klaut Gold und flieht ·
 * rufer – ruft Verstärkung · regeneriert – heilt sich · schnell – zwei Schritte pro Zug ·
 * fliegend – kann nicht umgeworfen oder gestampft werden · gepanzert – halber Schaden von Fäusten.
 */
export type MonsterAbility = 'gift' | 'explodiert' | 'diebisch' | 'rufer' | 'regeneriert' | 'schnell' | 'fliegend' | 'gepanzert';

export interface Monster {
  uid: string;
  defId: string;
  name: string;
  glyph: string;
  color: string;
  level: number;
  hp: number;
  maxHp: number;
  dmg: [number, number];
  treffer: number;
  ruestung: number;
  ausweichen: number;
  size: MonsterSize;
  behavior: Behavior;
  xp: number;
  pos: Pos;
  hood: number;
  rank: 'normal' | 'elite' | 'nachbarschaftsboss' | 'boroughboss' | 'geist';
  /** Liegt am Boden (nach Tritt/Umwerfen) – ermöglicht Stampfen. */
  downed: number;
  /** Hat den Crawler bemerkt. */
  aware: boolean;
  fleeing?: boolean;
  /** Bosse bleiben in ihrem Raum. */
  homeRoom?: number;
  range?: number;
  loot?: string[];
  ghostOf?: string;
  ghostItems?: Item[];
  flavor: string;
  abilities?: MonsterAbility[];
  /** Wie oft dieser Mob schon Verstärkung gerufen hat. */
  summoned?: number;
  /** Gestohlenes Gold, das beim Tod zurückfällt. */
  stolenGold?: number;
  /** Techniken, mit denen dieser Mob in diesem Kampf getroffen wurde. */
  hitBy?: string[];
}

export interface Pet {
  name: string;
  species: string;
  level: number;
  xp: number;
  hp: number;
  maxHp: number;
  dmg: [number, number];
  pos: Pos;
  alive: boolean;
}

export interface SkillState {
  id: string;
  level: number;
  xp: number;
}

export interface Buff {
  name: string;
  turns: number;
  bonuses: Bonuses;
  /** Schaden pro Zug (Gift). */
  dot?: number;
  debuff?: boolean;
}

export interface Player {
  name: string;
  background: string;
  pos: Pos;
  level: number;
  xp: number;
  hp: number;
  maxHpBase: number;
  ausdauer: number;
  maxAusdauerBase: number;
  stats: Stats;
  statPoints: number;
  gold: number;
  /** Vor dem Tutorial: genau ein Gegenstand in der Hand. */
  hand: Item | null;
  inventory: Item[];
  /** Lootboxen werden vom System verwahrt, bis man sie im Safe Room öffnet. */
  boxes: Item[];
  equipment: Partial<Record<EquipSlot, Item>>;
  skills: SkillState[];
  buffs: Buff[];
  /** Zähler je Technik-Schlüssel, z. B. "tritt+stampfen". */
  techniqueUses: Record<string, number>;
  techniqueKills: Record<string, number>;
  /** Bewegte sich im letzten Zug auf ein Ziel zu (für Anlauf). */
  lastMoveDir: Pos | null;
  pet: Pet | null;
  flags: string[];
  curses: string[];
}

// ---------------------------------------------------------------- Spiel

export type Unlock = 'inventar' | 'stats' | 'minimap' | 'skills';

export interface LogEntry {
  turn: number;
  text: string;
  kind: 'info' | 'kampf' | 'system' | 'loot' | 'achievement' | 'gefahr' | 'dialog';
}

export interface Counters {
  kills: number;
  killsByDef: Record<string, number>;
  steps: number;
  itemsPicked: number;
  boxesOpened: number;
  missStreak: number;
  hitTakenStreak: number;
  throws: number;
  bossKills: number;
  damageDealt: number;
  damageTaken: number;
  goldEarned: number;
  goldStolen: number;
  poisonDamage: number;
  mealsEaten: number;
  potionsDrunk: number;
  sleeps: number;
  crits: number;
  knockdowns: number;
  eliteKills: number;
}

export interface GameState {
  version: number;
  seed: number;
  rng: number;
  floor: number;
  turn: number;
  /** Züge bis zum Einsturz der Etage. */
  collapseAt: number;
  floorStartTurn: number;
  map: FloorMap;
  player: Player;
  monsters: Monster[];
  items: { pos: Pos; item: Item }[];
  unlocks: Unlock[];
  achievements: string[];
  counters: Counters;
  log: LogEntry[];
  status: 'playing' | 'dead' | 'victory';
  deathCause?: string;
  /** Zug, in dem zuletzt ein Mob nachgespawnt wurde. */
  lastSpawnTurn: number;
  uidCounter: number;
  currentRoom: number;
  /** Laufende Dialoge, die die UI anzeigen soll. */
  pendingDialogs: Dialog[];
  guideName: string;
  season: number;
  contractSigned: boolean;
  /** Achievements, die vor diesem Run schon einmal erreicht wurden. */
  firstEver: string[];
  ghostsDefeated: string[];
  toasts: Toast[];
}

export interface Toast {
  title: string;
  text: string;
  kind: 'achievement' | 'skill' | 'level' | 'loot' | 'warnung';
}

export interface Dialog {
  title: string;
  speaker?: string;
  pages: string[];
}

// ---------------------------------------------------------------- Events

export type GameEvent =
  | { type: 'kill'; monster: Monster; technique: Technique | null; byPet?: boolean }
  | { type: 'attack'; technique: Technique; hit: boolean; crit: boolean; damage: number; target: Monster; thrown?: Item }
  | { type: 'damageTaken'; amount: number; source: string }
  | { type: 'dodged'; source: string }
  | { type: 'enterRoom'; room: Room }
  | { type: 'pickup'; item: Item }
  | { type: 'equip'; item: Item }
  | { type: 'boxOpened'; item: Item; contents: Item[] }
  | { type: 'levelUp'; level: number }
  | { type: 'skillUp'; skillId: string; level: number }
  | { type: 'skillLearned'; skillId: string }
  | { type: 'tutorialDone' }
  | { type: 'eat'; item: Item }
  | { type: 'sleep' }
  | { type: 'descend'; floor: number }
  | { type: 'stairsFound' }
  | { type: 'mapPicked'; hood: number }
  | { type: 'revived' }
  | { type: 'poisoned'; source: string }
  | { type: 'cured' }
  | { type: 'robbed'; amount: number; source: string }
  | { type: 'explosion'; damage: number; source: string }
  | { type: 'goldGained'; amount: number }
  | { type: 'moved' }
  | { type: 'start' };

/** Meta-Fortschritt, der über den Tod hinaus erhalten bleibt. */
export interface MetaState {
  season: number;
  achievementsEver: string[];
  bestiary: Record<string, number>;
  hallOfFame: HallEntry[];
  ghosts: GhostRecord[];
  guides: GuideRecord[];
}

export interface HallEntry {
  season: number;
  name: string;
  background: string;
  level: number;
  floor: number;
  kills: number;
  achievements: number;
  cause: string;
  outcome: 'tot' | 'vertrag' | 'ueberlebt';
}

export interface GhostRecord {
  name: string;
  floor: number;
  level: number;
  season: number;
  items: Item[];
}

export interface GuideRecord {
  name: string;
  season: number;
  level: number;
}
