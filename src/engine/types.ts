// Zentrale Datentypen. Der gesamte Spielzustand besteht aus reinen
// JSON-Objekten, damit er ohne Umwege gespeichert und geladen werden kann.

export type StatKey = 'str' | 'ges' | 'kon' | 'int' | 'cha';
export type Stats = Record<StatKey, number>;

export interface Pos {
  x: number;
  y: number;
}

// ---------------------------------------------------------------- Karte

/** door = geschlossene Tür (blockiert Weg und Sicht), dooropen = offene Tür. */
export type Tile = 'wall' | 'floor' | 'stairs' | 'door' | 'dooropen';

export type RoomKind = 'start' | 'normal' | 'guild' | 'safe' | 'boss' | 'arena';

export type FurnitureKind = 'automat' | 'haendler' | 'wirt' | 'bett' | 'toilette';

export interface Furniture {
  kind: FurnitureKind;
  pos: Pos;
}

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
  /** Einrichtung (Safe Rooms): Automat, Händler, Wirt, Bett, Toilette. */
  furniture?: Furniture[];
  /** Vorraum einer Boss-Kammer (ID der Kammer). */
  antechamberOf?: number;
  /** Der Versus-Bildschirm wurde für diese Kammer schon gezeigt. */
  versusShown?: boolean;
  /** Laden im Safe Room (wird beim ersten Betreten gefüllt). */
  shop?: Shop;
  /** Der Laden hat schon einen Auftrag angeboten. */
  questOffered?: boolean;
  visited?: boolean;
}

export type TrapKind =
  | 'pfeilplatte' | 'fallgrube' | 'giftgas' | 'stolperdraht' | 'baerenfalle'
  | 'stachelfalle' | 'sprengfalle' | 'schlingfalle';

export interface Trap {
  uid: string;
  pos: Pos;
  kind: TrapKind;
  /** Noch nicht entdeckt (nur Dungeon-Fallen). */
  hidden: boolean;
  owner: 'dungeon' | 'crawler';
}

export interface ShopOffer {
  item: Item;
  price: number;
  /** Bereits verhandelt (nur ein Versuch pro Angebot). */
  haggled?: boolean;
}

export interface Shop {
  keeper: string;
  offers: ShopOffer[];
  /** Laune der Ladenbesitzerin/des Ladenbesitzers: sinkt bei gescheiterten Verhandlungen. */
  mood: number;
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

export interface ThrowCondition {
  id: ConditionId;
  turns: number;
  power: number;
  radius?: number;
}

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
  maxMp?: number;
}

export type ItemKind = 'ausruestung' | 'wurf' | 'verbrauch' | 'box' | 'karte' | 'gold' | 'schrott' | 'buch';

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
  /** Zauberbücher: welcher Zauber gelernt wird. */
  spell?: string;
  /** Pass/Talisman: Gegner mit dieser Facette greifen nicht an (z. B. „z:kobold“). */
  passFacet?: string;
  /** Wurfobjekte, die beim Aufprall explodieren: Schaden im Umkreis von 1 Feld. */
  explosion?: number;
  /** Waffen: Chance in Prozent, eine Blutung zu verursachen. */
  blutung?: number;
  /** Wurfobjekte: Zustand beim Aufprall (mit Radius: alle im Umkreis). */
  wurfZustand?: ThrowCondition;
  /** Eigene Falle zum Aufstellen. */
  trapKind?: TrapKind;
  /** Halsband für das Haustier. */
  petBonus?: { hp?: number; dmg?: number };
  /** Gehört zu einem Auftrag (nicht verkäuflich). */
  questId?: string;
  /** Wie oft die Waffe schon verbessert wurde (Handwerk). */
  upgrades?: number;
  /** Ei: schlüpft in diesem Zug (im Inventar). */
  hatchAt?: number;
  petSpecies?: string;
  wert: number;
}

export type SpecialEffect =
  | 'zweite_chance' | 'stampf_beben' | 'katzenfreund' | 'glueckspilz' | 'giftimmun' | 'goldmagnet'
  | 'explosionsschutz' | 'bumerang' | 'vampir'
  // Schutz vor Zuständen
  | 'blutlos' | 'feuerfest' | 'furchtlos' | 'scharfsichtig'
  // Klassen und Rassen
  | 'klingenmeister' | 'krallen' | 'giftklinge' | 'brandstifter' | 'trankkunde' | 'aasfresser' | 'schrauber' | 'sattelfest'
  | 'systemkenntnis' | 'haendler' | 'rattenfreund' | 'konterprofi' | 'zaeh' | 'nudist' | 'jaeger' | 'fallenmeister' | 'reichweite';

export interface ConsumableEffect {
  heal?: number;
  /** Heilung in Prozent der max. HP. */
  healPct?: number;
  mana?: number;
  manaPct?: number;
  /** Füllt die Blase (Getränke). */
  blase?: number;
  /** Heilt Vergiftung. */
  cure?: boolean;
  /** Verband: stoppt Blutungen. */
  bandage?: boolean;
  ausdauer?: number;
  buff?: { name: string; turns: number; bonuses: Bonuses };
}

// ---------------------------------------------------------------- Kampf

export type AttackPart = 'faust' | 'tritt' | 'knie' | 'ellbogen' | 'kopf' | 'waffe' | 'wurf';
export type AttackMove = 'normal' | 'sprung' | 'stampfen' | 'anlauf';

/** Trefferzone: wohin der Angriff zielt. */
export type HitZone = 'kopf' | 'koerper' | 'arme' | 'beine';

export interface Technique {
  part: AttackPart;
  move: AttackMove;
  /** Ziel am Körper des Gegners (Standard: Körper). */
  zone?: HitZone;
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
export type MonsterAbility =
  | 'gift' | 'explodiert' | 'diebisch' | 'rufer' | 'regeneriert' | 'schnell' | 'fliegend' | 'gepanzert'
  | 'blutig' | 'brennend' | 'blendend' | 'furchterregend';

/** Zustände im Kampf (siehe engine/conditions.ts). */
export type ConditionId = 'blutung' | 'brennen' | 'gift' | 'furcht' | 'blind';

export interface ActiveCondition {
  turns: number;
  /** Schaden pro Zug (Blutung, Brennen, Gift) bzw. Stärke. */
  power: number;
}

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
  /** Vom Crawler angegriffen – Pässe schützen dann nicht mehr. */
  provoked?: boolean;
  /** Techniken, mit denen dieser Mob in diesem Kampf getroffen wurde. */
  hitBy?: string[];
  /** Trefferzonen, die der Crawler an diesem Mob schon getroffen hat. */
  zonesHit?: HitZone[];
  /** Hat seinen Schreckensschrei schon ausgestoßen. */
  roared?: boolean;
  /** Wurde schon bestohlen (Klassenfähigkeit Langfinger). */
  pickpocketed?: boolean;
  /** Aktive Zustände: Blutung, Brennen, Gift, Furcht, Blindheit. */
  conditions?: Partial<Record<ConditionId, ActiveCondition>>;
  /** Schläft (wacht bei Lärm oder direkt daneben auf). */
  asleep?: boolean;
  /** Wo es den Crawler zuletzt gesehen oder gehört hat. */
  lastSeen?: Pos;
  /** Züge, die es noch sucht. */
  searching?: number;
  /** Raserei bei wenig Leben (Elite, Bosse). */
  enraged?: boolean;
  /** Benommen (Kopftreffer): setzt Züge aus. */
  stunned?: number;
  /** Geschwächt (Armtreffer): richtet weniger Schaden an. */
  weakened?: number;
  /** Humpelt (Beintreffer): bewegt sich nur jeden zweiten Zug. */
  slowed?: number;
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
  /** Nach dem Superkeks: das Haustier zaubert Magische Geschosse. */
  caster?: boolean;
  /** Entwicklungsform (siehe PET_FORMS). */
  form?: string;
  /** Eine Entwicklung steht zur Wahl. */
  evolveReady?: boolean;
  /** Fähigkeiten aus den Entwicklungen. */
  abilities?: string[];
  /** Halsband des Haustiers. */
  gear?: Item;
  /** Zug der letzten Pflege (Fähigkeit „Pflegen“). */
  lastHeal?: number;
}

export type Personality = 'freundlich' | 'vorsichtig' | 'eigenbroetler' | 'feindselig' | 'verzweifelt';

/** Ein anderer Crawler (NPC) auf derselben Etage. */
export interface NpcCrawler {
  uid: string;
  name: string;
  background: string;
  personality: Personality;
  level: number;
  xp: number;
  hp: number;
  maxHp: number;
  dmg: [number, number];
  pos: Pos;
  alive: boolean;
  /** Schon angesprochen. */
  met: boolean;
  party: boolean;
  /** Vertrauen 0–100: steigt durch Geschenke und gemeinsame Kämpfe. */
  trust: number;
  tipGiven?: boolean;
  /** Vom Crawler versorgt (Heilung geschenkt). */
  healed?: boolean;
  /** Zug, bis zu dem eine erneute Einladung abgelehnt wird. */
  refusedUntil?: number;
  kills: number;
}

export interface Population {
  alive: number;
  /** Stand zu Beginn der Etage (für den Rückgang). */
  floorStart: number;
  lastAnnounce: number;
}

export type QuestKind = 'jagd' | 'finden' | 'liefern' | 'retten' | 'boss';

export interface Quest {
  id: string;
  kind: QuestKind;
  floor: number;
  /** Wer den Auftrag gibt: ein Crawler (uid) oder ein Laden (Raum-ID). */
  giver: { kind: 'crawler' | 'laden'; ref: string; name: string };
  title: string;
  text: string;
  status: 'angebot' | 'aktiv' | 'erledigt' | 'gescheitert';
  /** jagd: Ziel-Facette (z. B. „z:ratte“); boss: Viertel; liefern: Basis-IDs. */
  facet?: string;
  hood?: number;
  itemIds?: string[];
  /** finden: das gesuchte Item; retten: die gesuchte Person. */
  targetUid?: string;
  count: number;
  progress: number;
  reward: { gold: number; xp: number; box?: boolean };
}

export interface SponsorState {
  id: string;
  /** Interesse bis zum Angebot (0–100). */
  interest: number;
  status: 'none' | 'offer' | 'active' | 'dropped';
  /** Gunst als Sponsor (0–100): sinkt bei Dingen, die sie nicht mag. */
  favor: number;
  wish: number;
  progress: number;
  completed: number;
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
  /** Schild, der Schaden abfängt (verbraucht sich). */
  absorb?: number;
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
  /** Ab Etage 3 gewählt. */
  race?: string;
  klass?: string;
  abilityCooldown?: number;
  /** Vom Beobachter entdeckte, maßgeschneiderte Skills. */
  dynSkills?: DynSkill[];
  /** Eigenschaften aus dem Vorleben (Ängste, Laster, Stärken). */
  traits?: string[];
  /** Mana (ab dem Tutorial sichtbar). */
  mp?: number;
  spells?: SpellState[];
  spellCooldowns?: Record<string, number>;
  /** Blase 0–100: Erleichtern darf man sich nur in Toiletten. */
  blase?: number;
  /** Abklingzeit für Tränke in Zügen. */
  potionCooldown?: number;
  /** Dauerhafte Pässe (Tätowierungen), Facetten wie „z:kobold“. */
  passes?: string[];
  /** Festgehalten (z. B. Bärenfalle): so viele Züge keine Bewegung. */
  immobile?: number;
  /** Reittier oder Fahrzeug. */
  mount?: Mount;
  /** Sitzt gerade auf dem Reittier. */
  riding?: boolean;
  /** Zähler für Extraschritte beim Reiten. */
  mountSteps?: number;
  /** Skills der gewählten Klasse (lernen 50 % schneller). */
  classSkills?: string[];
  /** Bevorzugtes Wurfobjekt (Basis-ID). */
  wurfWahl?: string;
}

export interface Mount {
  id: string;
  name: string;
  hp: number;
  maxHp: number;
  fuel?: number;
  /** Bewusstlos (Tier) oder kaputt (Fahrzeug, dann weg). */
  down?: boolean;
}

export interface SpellState {
  id: string;
  level: number;
  xp: number;
}

export interface DynSkill {
  key: string;
  name: string;
  description: string;
  kind: 'angriff' | 'ausweichen' | 'abhaertung';
  part?: AttackPart;
  move?: AttackMove;
  facet: string;
  level: number;
  xp: number;
}

export interface DynAchievement {
  id: string;
  name: string;
  description: string;
  comment: string;
  tier: BoxTier;
  box: BoxType;
  turn: number;
  floor: number;
}

/** Aufzeichnung des Beobachters: wie oft welche Merkmals-Kombination vorkam. */
export interface Chronicle {
  counts: Record<string, number>;
  /** Nächste noch nicht belohnte Stufe je Kombination. */
  stages: Record<string, number>;
  lastAward: number;
}

export interface Viewers {
  follower: number;
  /** Kurzfristige Begeisterung (0–100): steigt mit Spektakel, sinkt mit Langeweile. */
  hype: number;
  /** Index der nächsten Fan-Box-Schwelle. */
  nextFanBox: number;
  /** Zug der letzten spektakulären Aktion. */
  lastSpectacle: number;
  lastCloseCall?: number;
}

// ---------------------------------------------------------------- Spiel

export type Unlock = 'inventar' | 'stats' | 'minimap' | 'skills' | 'zuschauer' | 'klasse';

export interface LogEntry {
  /** Fortlaufende Nummer, damit die Oberfläche neue Zeilen erkennt. */
  id?: number;
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
  trapsFound: number;
  trapsTriggered: number;
  trapsDisarmed: number;
  trapKills: number;
  crafted: number;
}

/** Stand zu Beginn einer Etage – für den Rückblick beim Abstieg. */
export interface FloorSnapshot {
  turn: number;
  counters: Omit<Counters, 'killsByDef'>;
  achievements: number;
  patterns: number;
  follower: number;
  fallen: number;
  level: number;
}

export type ShowTone = 'ehrlich' | 'witzig' | 'frech' | 'bescheiden' | 'dramatisch';

export interface ShowQuestion {
  id: string;
  text: string;
  answers: { label: string; tone: ShowTone }[];
}

export interface TalkShow {
  host: string;
  title: string;
  questions: ShowQuestion[];
  index: number;
  followerDelta: number;
  done: boolean;
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
  viewers: Viewers;
  logCounter?: number;
  chronicle?: Chronicle;
  traps?: Trap[];
  crawlers?: NpcCrawler[];
  population?: Population;
  /** Namen gefallener Party-Mitglieder (für Rückblicke). */
  fallen?: string[];
  floorSnapshot?: FloorSnapshot;
  fx?: Fx[];
  /** Statistik: zählt alles mit (Grundlage für gestufte Achievements). */
  stats?: Record<string, number>;
  sfx?: Sfx[];
  sponsors?: SponsorState[];
  quests?: Quest[];
  talkShow?: TalkShow;
  dynAchievements?: DynAchievement[];
  /** Rassen- und Klassenwahl steht an (Etage 3). */
  pendingSelection: boolean;
  /** Gegenstände, die die Oberfläche gleich groß zeigen soll (z. B. vom Automaten). */
  pendingReveal?: { title: string; items: Item[] };
  /** Boss, gegen den gleich der Versus-Bildschirm gezeigt wird. */
  pendingVersus?: string;
  toasts: Toast[];
}

/** Klang für die Oberfläche. */
export interface Sfx {
  kind: 'box' | 'levelup' | 'achievement' | 'skill';
  tier?: BoxTier;
}

/** Sichtbarer Effekt für die Oberfläche (wird nicht gespeichert). */
export type Fx =
  | { kind: 'shot'; from: Pos; to: Pos; style: 'stein' | 'pfeil' | 'magie' | 'feuer' | 'schleim' | 'bombe' | 'blitz' }
  | { kind: 'text'; at: Pos; text: string; color: string };

export interface Toast {
  title: string;
  text: string;
  kind: 'achievement' | 'skill' | 'level' | 'loot' | 'warnung';
}

export interface Dialog {
  /** Sonderdialog: die Talkshow (Fragen mit Antworten). */
  kind?: 'talkshow';
  title: string;
  speaker?: string;
  pages: string[];
}

// ---------------------------------------------------------------- Events

export type GameEvent =
  | { type: 'kill'; monster: Monster; technique: Technique | null; byPet?: boolean; byAlly?: boolean; facets?: string[] }
  | { type: 'attack'; technique: Technique; hit: boolean; crit: boolean; damage: number; target: Monster; thrown?: Item; facets?: string[] }
  | { type: 'damageTaken'; amount: number; source: string; facets?: string[] }
  | { type: 'dodged'; source: string; facets?: string[] }
  | { type: 'enterRoom'; room: Room; first?: boolean }
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
  | { type: 'conditioned'; condition: ConditionId; source: string }
  | { type: 'cured' }
  | { type: 'robbed'; amount: number; source: string }
  | { type: 'explosion'; damage: number; source: string }
  | { type: 'goldGained'; amount: number }
  | { type: 'classChosen'; race: string; klass: string }
  | { type: 'abilityUsed'; ability: string }
  | { type: 'followers'; follower: number }
  | { type: 'spellCast'; spell: string; kills: number }
  | { type: 'accident' }
  | { type: 'trapTriggered'; kind: TrapKind; onPlayer: boolean }
  | { type: 'trapDetected'; kind: TrapKind }
  | { type: 'trapDisarmed'; kind: TrapKind; success: boolean }
  | { type: 'trapPlaced'; kind: TrapKind }
  | { type: 'crafted'; recipe: string }
  | { type: 'crawlerMet'; name: string; personality: Personality }
  | { type: 'partyJoined'; name: string; size: number }
  | { type: 'partyLeft'; name: string }
  | { type: 'crawlerDied'; name: string; party: boolean }
  | { type: 'crawlerTurned'; name: string }
  | { type: 'talkShow'; delta: number; tone: ShowTone }
  | { type: 'petLevel'; level: number }
  | { type: 'petEvolved'; form: string; stage: number }
  | { type: 'doorOpened'; pos: Pos }
  | { type: 'doorClosed'; pos: Pos }
  | { type: 'potion'; item: Item; hpBefore: number }
  | { type: 'mountGained'; id: string }
  | { type: 'rammed'; kill: boolean }
  | { type: 'mountLost'; id: string }
  | { type: 'questAccepted'; kind: QuestKind }
  | { type: 'questDone'; kind: QuestKind; done: number }
  | { type: 'questFailed'; kind: QuestKind }
  | { type: 'sponsorJoined'; id: string; count: number }
  | { type: 'sponsorWish'; id: string; completed: number }
  | { type: 'sponsorDropped'; id: string }
  | { type: 'bought'; item: Item; price: number; haggled: boolean }
  | { type: 'sold'; item: Item; price: number }
  | { type: 'haggle'; success: boolean; percent: number }
  | { type: 'lottery'; outcome: string }
  | { type: 'petGained'; species: string; how: 'ei' | 'zaehmen' }
  | { type: 'relief' }
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
