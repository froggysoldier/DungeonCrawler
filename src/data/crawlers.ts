import type { Personality } from '../engine/types';

/**
 * Andere Crawler. Alle Namen und Figuren sind frei erfunden – Menschen aus
 * derselben zerstörten Stadt, die genauso wenig wussten, was passiert, wie du.
 */
export const FIRST_NAMES = [
  'Birgit', 'Jonas', 'Heike', 'Mehmet', 'Sabine', 'Torsten', 'Ayla', 'Kevin', 'Renate', 'Dimitri',
  'Lena', 'Uwe', 'Fatma', 'Holger', 'Marta', 'Sven', 'Ingrid', 'Paul', 'Janine', 'Ole',
  'Katarzyna', 'Bernd', 'Nele', 'Ferdinand', 'Zeynep', 'Rüdiger', 'Mia', 'Gundula', 'Theo', 'Anouk',
];

export const LAST_NAMES = [
  'Oberlechner', 'Kowalczyk', 'Brandt', 'Yıldız', 'Hoffmeister', 'Pietsch', 'Kraus', 'Demir', 'Lindqvist',
  'Wendehals', 'Schubert', 'Nowak', 'Grünewald', 'Albers', 'Strobel', 'Haferkamp', 'Özdemir', 'Weidlich',
  'Rautenberg', 'Klinger',
];

export const BACKGROUNDS = [
  'Zahnarzthelferin', 'Paketbote', 'Rentner', 'Schülerin', 'Imker', 'Busfahrerin', 'Steuerberater',
  'Kindergärtnerin', 'Metzger', 'Influencerin', 'Nachtwächter', 'Fliesenleger', 'Pflegekraft',
  'Hausmeister', 'Bibliothekarin', 'Kioskbesitzer', 'Tätowiererin', 'Taxifahrer', 'Physikstudentin',
  'Hochzeitsplaner', 'Feuerwehrfrau', 'Friseur', 'Gärtnerin', 'Versicherungsvertreter',
];

export interface PersonalityDef {
  name: string;
  /** Grundchance, einer Party beizutreten (in Prozent). */
  join: number;
  weight: number;
  greetings: string[];
  joinYes: string[];
  joinNo: string[];
}

export const PERSONALITIES: Record<Personality, PersonalityDef> = {
  freundlich: {
    name: 'freundlich', join: 60, weight: 4,
    greetings: [
      'Oh, Gott sei Dank, ein Mensch! Ich dachte schon, hier unten gibt es nur noch Ratten mit Zähnen.',
      'Hallo! Du siehst aus, als wüsstest du, was du tust. Tust du nicht, oder? Egal. Hallo!',
      'Hey! Ich bin seit Stunden allein hier unten. Ich rede schon mit den Wänden. Die Wände sind unhöflich.',
    ],
    joinYes: [
      'Zusammen? Ja! Ja, bitte. Ich halte die Taschenlampe. Also, wenn wir eine hätten.',
      'Endlich jemand, der mir den Rücken freihält. Ich halte deinen auch frei. Versprochen.',
    ],
    joinNo: ['Ich … brauch noch einen Moment. Frag mich später nochmal, ja?'],
  },
  vorsichtig: {
    name: 'vorsichtig', join: 30, weight: 4,
    greetings: [
      'Bleib da stehen. Hände, wo ich sie sehen kann. … Gut. Was willst du?',
      'Du bist nicht der Erste, der hier freundlich tut. Der Letzte hat mir meine Schuhe geklaut.',
      'Ich hab dich schon eine Weile beobachtet. Du kämpfst ganz ordentlich. Für einen Anfänger.',
    ],
    joinYes: ['Na gut. Aber wenn du mich im Stich lässt, lasse ich dich auch im Stich. Deal?'],
    joinNo: [
      'Nein. Ich kenne dich nicht. Zeig mir erst, dass man dir trauen kann.',
      'Vielleicht. Wenn du ein paar Level mehr hast. Ich will nicht babysitten.',
    ],
  },
  eigenbroetler: {
    name: 'eigenbrötlerisch', join: 0, weight: 2,
    greetings: [
      'Ich arbeite allein. Immer schon. Im Büro, und jetzt eben hier.',
      'Keine Party. Keine Freunde. Aber einen Tipp gebe ich dir, wenn du nett fragst.',
    ],
    joinYes: [],
    joinNo: ['Nein. Allein ist man schneller. Und niemand klaut einem das Essen.'],
  },
  feindselig: {
    name: 'feindselig', join: 0, weight: 1,
    greetings: [
      'Schöne Ausrüstung hast du da. Wäre doch schade, wenn ihr was passiert.',
      'Weißt du, was ich gelernt habe? Crawler droppen auch Loot.',
    ],
    joinYes: [],
    joinNo: [],
  },
  verzweifelt: {
    name: 'verzweifelt', join: 20, weight: 2,
    greetings: [
      'Bitte … hast du irgendwas zum Heilen? Irgendwas? Ich schaffe es nicht mehr lange.',
      'Die haben mich erwischt. Überall Blut. Ist das meins? Ich glaube, das ist meins.',
    ],
    joinYes: ['Du … du hilfst mir? Ich folge dir überallhin. Überallhin.'],
    joinNo: ['Ich kann kaum laufen. Erst brauche ich Heilung.'],
  },
};

export const TIP_LINES = [
  'Das Treppenhaus? Ich hab eins gesehen. Hier, ich zeig es dir auf deiner Karte.',
  'Da hinten ist ein Safe Room. Mit Toilette. Glaub mir, das willst du wissen.',
  'Pass auf, wo du hintrittst. Ich hab hier in der Gegend Fallen gesehen.',
];

export const PARTY_BARKS = [
  '{name}: „Links! Nein, anderes Links!“',
  '{name}: „Ich hab noch nie jemanden geschlagen. Das ist … überraschend befriedigend.“',
  '{name}: „Wenn wir hier rauskommen, lade ich dich zum Essen ein. Also, wenn es noch Essen gibt.“',
  '{name}: „Glaubst du, die Zuschauer mögen mich?“',
  '{name}: „Ich vermisse Kaffee. Und Fenster. Und die Sonne.“',
  '{name}: „Du blutest. Nein, warte, das bin ich.“',
];

export const DEATH_LINES = [
  '{name} geht zu Boden und steht nicht mehr auf. Ein Transportlicht nimmt nur noch die Ausrüstung mit.',
  '{name} schreit deinen Namen. Dann ist es still.',
  '{name} schafft es nicht. Die Systemstimme vermerkt es in einer Fußnote.',
];

/** Bevölkerungszahl zu Beginn des Abstiegs (eigene Zahl). */
export const START_POPULATION = 2_117_408;
/** Anteil, der auf jeder Etage bis zum Einsturz stirbt (ohne die Treppen-Nachzügler). */
export const FLOOR_LOSS = [0, 0.52, 0.38, 0.3, 0.25];
/** Wer beim Einsturz nicht auf der Treppe ist, stirbt. */
export const COLLAPSE_LOSS = 0.12;
export const ANNOUNCE_EVERY = 240;
export const PARTY_MAX = 3;
