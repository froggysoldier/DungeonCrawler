import type { BoxType } from '../engine/types';

/**
 * Sponsoren: außerirdische Firmen und Adelshäuser, die dem Crawler Geld und
 * Ausrüstung schicken, wenn er zeigt, was sie sehen wollen. Alle Namen frei
 * erfunden.
 *
 * Signale entstehen aus Spielereignissen, z. B. „kill|m:stampfen“ (Kill per
 * Stampfer), „kill|pet“ (Kill des Haustiers), „crafted“, „trap|monster“.
 */
export interface SponsorWish {
  text: string;
  /** Eines dieser Signale zählt als Fortschritt. */
  signals: string[];
  count: number;
}

export interface SponsorDef {
  id: string;
  name: string;
  description: string;
  /** Was ihr gefällt: Signal → Interesse-Punkte. */
  likes: Record<string, number>;
  /** Was ihr missfällt, solange sie dich sponsert. */
  dislike: { signal: string; text: string };
  /** Mindestens so viele Follower, bevor ein Angebot kommt. */
  minFollower: number;
  box: BoxType;
  offer: string;
  wishes: SponsorWish[];
}

export const MAX_SPONSORS = 3;

export const SPONSORS: SponsorDef[] = [
  {
    id: 'vornex', name: 'Kristallhaus Vornex', box: 'schuh', minFollower: 150,
    description: 'Ein Juwelierhaus vom Planeten Vorn. Liebt Eleganz: Sprünge, Stampfer, Sturmangriffe.',
    likes: { 'kill|m:stampfen': 6, 'kill|m:sprung': 7, 'kill|m:anlauf': 5, crit: 1 },
    dislike: { signal: 'trap|self', text: 'In eine Falle zu treten ist nicht elegant.' },
    offer: '„Wir haben Ihre Sprünge gesehen. Wunderbar. Das Kristallhaus Vornex möchte Ihr Sponsor sein. Bleiben Sie anmutig.“',
    wishes: [
      { text: 'Erledige 4 Gegner mit Sprung-, Stampf- oder Sturmangriffen.', signals: ['kill|m:sprung', 'kill|m:stampfen', 'kill|m:anlauf'], count: 4 },
      { text: 'Lande 6 kritische Treffer.', signals: ['crit'], count: 6 },
      { text: 'Stampfe 5 Gegner zu Tode.', signals: ['kill|m:stampfen'], count: 5 },
    ],
  },
  {
    id: 'pyrrax', name: 'Brennstoffwerke Pyrrax', box: 'wurf', minFollower: 150,
    description: 'Ein Energiekonzern mit einem Faible für alles, was brennt oder knallt.',
    likes: { 'kill|t:bombe': 9, 'kill|t:zauber': 4, 'crafted|brandflasche': 5, 'crafted|nagelbombe': 6 },
    dislike: { signal: 'sleep', text: 'Schlafen? Die Brennstoffwerke schlafen nie.' },
    offer: '„Feuer! Knall! Wir lieben es. Die Brennstoffwerke Pyrrax sponsern ab sofort Ihre Explosionen.“',
    wishes: [
      { text: 'Stelle 2 Sprengsätze her.', signals: ['crafted|brandflasche', 'crafted|nagelbombe', 'crafted|sprengfalle'], count: 2 },
      { text: 'Erledige 3 Gegner mit Sprengsätzen oder Zaubern.', signals: ['kill|t:bombe', 'kill|t:zauber'], count: 3 },
      { text: 'Erledige 6 Gegner mit Sprengsätzen.', signals: ['kill|t:bombe'], count: 6 },
    ],
  },
  {
    id: 'oolu', name: 'Gräfin Oolu vom Nebelmond', box: 'haustier', minFollower: 100,
    description: 'Eine uralte Adlige mit sieben Zoos. Sie liebt Tiere – vor allem die, die für dich kämpfen.',
    likes: { 'kill|pet': 6, petGained: 20, 'pet|level': 8, 'pet|evolve': 30 },
    dislike: { signal: 'kill|z:tier', text: 'Sie haben ein Tier getötet. Die Gräfin weint in ihr Spitzentuch.' },
    offer: '„Ihr Haustier ist entzückend. Die Gräfin Oolu wünscht, es zu fördern. Und Sie, meinetwegen, auch.“',
    wishes: [
      { text: 'Lass dein Haustier 4 Gegner erledigen.', signals: ['kill|pet'], count: 4 },
      { text: 'Lass dein Haustier eine Stufe aufsteigen.', signals: ['pet|level'], count: 1 },
      { text: 'Lass dein Haustier sich entwickeln.', signals: ['pet|evolve'], count: 1 },
      { text: 'Lass dein Haustier 10 Gegner erledigen.', signals: ['kill|pet'], count: 10 },
    ],
  },
  {
    id: 'grimmzahn', name: 'Konsortium Grimmzahn', box: 'brawler', minFollower: 200,
    description: 'Ein Söldnerverband, der Mut bezahlt: Bosse, Elite, Gegner weit über deinem Level.',
    likes: { 'kill|z:boss': 30, 'kill|z:elite': 10, 'kill|z:staerker': 6, 'kill|i:fasttot': 5 },
    dislike: { signal: 'kill|z:schwaecher', text: 'Schwächere verprügeln? Das Konsortium ist enttäuscht.' },
    offer: '„Sie haben Mumm. Das Konsortium Grimmzahn zahlt für Mumm. Unterschreiben Sie hier. Mit Blut, wenn möglich.“',
    wishes: [
      { text: 'Besiege 2 Elite-Gegner oder Gegner weit über deinem Level.', signals: ['kill|z:elite', 'kill|z:staerker'], count: 2 },
      { text: 'Besiege einen Boss.', signals: ['kill|z:boss'], count: 1 },
      { text: 'Erledige 3 Gegner mit weniger als 20 % HP.', signals: ['kill|i:fasttot'], count: 3 },
    ],
  },
  {
    id: 'schleimbrueder', name: 'Die Schleimbrüder GmbH', box: 'ueberlebens', minFollower: 150,
    description: 'Zwei Schleime in einem Anzug. Sie lieben schmutzige Tricks: Fallen, Hinterhalte, Diebstahl am Preis.',
    likes: { 'kill|t:falle': 8, 'kill|z:ahnungslos': 3, 'trap|monster': 4, 'haggle|ok': 4, 'trap|disarmed': 3 },
    dislike: { signal: 'bought|full', text: 'Sie haben den vollen Preis bezahlt. Die Schleimbrüder schämen sich für Sie.' },
    offer: '„Hehe. Sie sind hinterhältig. Wir mögen hinterhältig. Die Schleimbrüder sind dabei.“',
    wishes: [
      { text: 'Lass 2 Gegner in deine eigenen Fallen tappen.', signals: ['trap|monster'], count: 2 },
      { text: 'Greife 5 Gegner an, die dich nicht bemerkt haben, und erledige sie.', signals: ['kill|z:ahnungslos'], count: 5 },
      { text: 'Feilsche erfolgreich 2-mal oder entschärfe 2 Fallen.', signals: ['haggle|ok', 'trap|disarmed'], count: 2 },
    ],
  },
  {
    id: 'modeag', name: 'Galaktische Mode AG', box: 'kleidung', minFollower: 250,
    description: 'Ein Modehaus, das Mut zur Hässlichkeit zeigt. Bademantel, barfuß, fast nackt: je absurder, desto besser.',
    likes: { 'kill|i:nackt': 5, 'kill|i:bademantel': 4, 'kill|i:barfuss': 3, 'talk|witzig': 10, 'talk|frech': 8 },
    dislike: { signal: 'eat', text: 'Kohlenhydrate. Die Mode AG ist entsetzt.' },
    offer: '„Darling! Dieser Look! Die Galaktische Mode AG muss Sie einkleiden. Oder eben auskleiden.“',
    wishes: [
      { text: 'Erledige 5 Gegner barfuß, im Bademantel oder fast nackt.', signals: ['kill|i:nackt', 'kill|i:bademantel', 'kill|i:barfuss'], count: 5 },
      { text: 'Erledige 10 Gegner barfuß, im Bademantel oder fast nackt.', signals: ['kill|i:nackt', 'kill|i:bademantel', 'kill|i:barfuss'], count: 10 },
    ],
  },
];

export const SPONSOR_BY_ID: Record<string, SponsorDef> = Object.fromEntries(SPONSORS.map((d) => [d.id, d]));
