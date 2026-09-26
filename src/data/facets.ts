import type { AttackMove, BoxType } from '../engine/types';

/**
 * Facetten sind die Merkmale, die der Beobachter an jeder Aktion erkennt.
 * Schlüssel-Präfixe: t: Technik (Körperteil), m: Ausführung, z: Ziel,
 * i: eigener Zustand, o: Ort.
 *
 * `weight` beschreibt, wie ungewöhnlich/spektakulär eine Facette ist.
 * Ungewöhnliche Kombinationen werden früher und besser belohnt.
 */
export interface FacetDef {
  /** Anzeige im Satz, z. B. „Ratten“ (Ziel), „barfuß“ (Zustand). */
  label: string;
  /** Kurzform für Namen, z. B. „Am Abgrund“. */
  short?: string;
  weight: number;
  /** Darf daraus ein eigener Skill entstehen? */
  skill?: boolean;
  box?: BoxType;
}

export const PART_PLURAL: Record<string, string> = {
  zauber: 'Zauber',
  faust: 'Faustschläge', tritt: 'Tritte', knie: 'Kniestöße', ellbogen: 'Ellbogenchecks',
  kopf: 'Kopfstöße', waffe: 'Waffenhiebe', wurf: 'Würfe',
};

export const MOVE_PLURAL: Record<Exclude<AttackMove, 'normal'>, string> = {
  sprung: 'Sprungangriffe', stampfen: 'Stampfer', anlauf: 'Sturmangriffe',
};

export const PART_BOX: Record<string, BoxType> = {
  zauber: 'abenteurer',
  faust: 'brawler', tritt: 'schuh', knie: 'brawler', ellbogen: 'brawler', kopf: 'kleidung', waffe: 'waffen', wurf: 'wurf',
};

/** Ziel-Facetten (z:…). Aus Monster-Tags, Größe, Fähigkeiten, Verhalten, Rang, Zustand. */
export const TARGET_FACETS: Record<string, FacetDef> = {
  // Arten (aus Tags)
  ratte: { label: 'Ratten', weight: 0, skill: true },
  insekt: { label: 'Krabbeltiere', weight: 0.5, skill: true },
  kobold: { label: 'Kobolde', weight: 0, skill: true },
  untot: { label: 'Untote', weight: 1, skill: true },
  geist: { label: 'Geister', weight: 1.5, skill: true },
  alien: { label: 'Außerirdische', weight: 1.5, skill: true },
  mimic: { label: 'Mimics', weight: 1.5, skill: true },
  folklore: { label: 'Fabelwesen', weight: 1, skill: true },
  schleim: { label: 'Schleime', weight: 0.5, skill: true },
  troll: { label: 'Trolle', weight: 1.5, skill: true },
  aquatisch: { label: 'Wasserwesen', weight: 1, skill: true },
  reptil: { label: 'Echsen', weight: 1.5, skill: true },
  kryptid: { label: 'Kryptiden', weight: 2, skill: true },
  konstrukt: { label: 'Konstrukte', weight: 1, skill: true },
  tier: { label: 'Tiere', weight: 0, skill: true },
  humanoid: { label: 'Humanoide', weight: 0.5, skill: true },
  hexe: { label: 'Hexen', weight: 2, skill: true },
  pflanze: { label: 'Pflanzenwesen', weight: 1, skill: true },
  elementar: { label: 'Elementare', weight: 2, skill: true },
  aberration: { label: 'Abscheulichkeiten', weight: 2, skill: true },
  gnom: { label: 'Gnome', weight: 0.5, skill: true },
  // Größe
  winzig: { label: 'Winzlinge', weight: 0 },
  gross: { label: 'große Gegner', weight: 1, skill: true },
  riesig: { label: 'Riesen', weight: 2.5, skill: true },
  // Fähigkeiten
  fliegend: { label: 'Flieger', weight: 1, skill: true },
  gepanzert: { label: 'Gepanzerte', weight: 1, skill: true },
  giftig: { label: 'Giftige', weight: 1, skill: true },
  explosiv: { label: 'Explosive', weight: 1.5, skill: true },
  diebisch: { label: 'Diebe', weight: 1, skill: true },
  rufer: { label: 'Rudelführer', weight: 1, skill: true },
  regeneriert: { label: 'Regenerierende', weight: 1, skill: true },
  schnell: { label: 'Flinke', weight: 1, skill: true },
  // Verhalten
  fernkampf: { label: 'Fernkämpfer', weight: 0.5, skill: true },
  feigling: { label: 'Feiglinge', weight: 0.5 },
  lauerer: { label: 'Lauerer', weight: 1, skill: true },
  // Rang
  elite: { label: 'Elite-Gegner', weight: 2, skill: true },
  boss: { label: 'Bosse', weight: 4, skill: true },
  geistcrawler: { label: 'Geister früherer Crawler', weight: 4 },
  // Lage im Kampf
  liegend: { label: 'liegende Gegner', weight: 0.5, skill: true },
  ahnungslos: { label: 'ahnungslose Gegner', weight: 1, skill: true },
  fliehend: { label: 'fliehende Gegner', weight: 1 },
  staerker: { label: 'stärkere Gegner (3+ Level über dir)', short: 'Stärkere', weight: 3, skill: true },
  schwaecher: { label: 'schwächere Gegner (3+ Level unter dir)', short: 'Schwächere', weight: -1 },
};

/** Eigene Zustände (i:…). */
export const SELF_FACETS: Record<string, FacetDef> = {
  vergiftet: { label: 'vergiftet', weight: 2, skill: true, box: 'ueberlebens' },
  fasttot: { label: 'mit weniger als 20 % HP', short: 'Am Abgrund', weight: 3, skill: true, box: 'ueberlebens' },
  verletzt: { label: 'verletzt (unter 50 % HP)', short: 'Angeschlagen', weight: 0.5, skill: true },
  barfuss: { label: 'barfuß', weight: 1, skill: true, box: 'schuh' },
  nackt: { label: 'fast nackt', weight: 2, skill: true, box: 'kleidung' },
  bademantel: { label: 'im Bademantel', weight: 1.5, box: 'kleidung' },
  umzingelt: { label: 'umzingelt (3+ Gegner neben dir)', short: 'Umzingelt', weight: 2.5, skill: true, box: 'ueberlebens' },
  haustier: { label: 'mit Haustier an deiner Seite', short: 'Im Team mit dem Haustier', weight: 0.5, skill: true, box: 'haustier' },
  angetrunken: { label: 'angetrunken', weight: 2, skill: true, box: 'fan' },
  wuetend: { label: 'in Rage', weight: 1, skill: true },
  erschoepft: { label: 'erschöpft (kaum Ausdauer)', short: 'Erschöpft', weight: 1.5, skill: true },
  letztestunde: { label: 'in der letzten Stunde vor dem Einsturz', short: 'Auf den letzten Drücker', weight: 3, box: 'ueberlebens' },
  unbewaffnet: { label: 'ohne Waffe', weight: 0 },
  im_gang: { label: 'in einem Gang', weight: 0 },
};

export const STAGES = [1, 5, 15, 40, 100];
export const STAGE_NUMERALS = ['I', 'II', 'III', 'IV', 'V'];

/** Kommentare der Systemstimme für entdeckte Muster. Platzhalter: {was}, {zahl}. */
export const PATTERN_COMMENTS = [
  'Die Systemstimme hat mitgezählt. {zahl}. Sie zählt gerne mit.',
  'Ein Muster! Die Systemstimme liebt Muster. Die Opfer weniger.',
  'Niemand hat dich darum gebeten. Du hast es trotzdem getan. {zahl}-mal.',
  'Das Publikum fragt sich, ob das eine Strategie ist oder ein Zwang.',
  'Die Statistikabteilung hat dafür extra eine neue Tabelle angelegt.',
  'Irgendwo in der Galaxis schreibt jemand eine Doktorarbeit über dich.',
  'Du wiederholst dich. Das ist in Ordnung. Die Monster wiederholen sich auch.',
  'Die Systemstimme ist nicht beeindruckt. Das Achievement gibt es trotzdem.',
  'So spezifisch. So sinnlos. So wunderbar.',
  'Das stand in keinem Handbuch. Weil niemand auf so eine Idee kommt.',
  'Auf deinem Grabstein wird das stehen. Die Systemstimme hat es schon notiert.',
  'Die Zuschauer haben dafür einen eigenen Namen erfunden. Er ist nicht jugendfrei.',
];

export const SKILL_UNLOCK_HITS = 12;
