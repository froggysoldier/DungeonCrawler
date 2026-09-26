import type { Stats } from '../engine/types';

export interface InterviewAnswer {
  label: string;
  /** Kommentar der Systemstimme zu dieser Antwort. */
  reaction: string;
  stats?: Partial<Stats>;
  skills?: string[];
  items?: string[];
  flags?: string[];
  pet?: { species: string; defaultName: string };
  background?: string;
}

export interface InterviewQuestion {
  id: string;
  question: string;
  answers: InterviewAnswer[];
}

// Die Systemstimme führt das Interview. Die Antworten bestimmen
// Start-Stats, Start-Skills, Startkleidung und versteckte Flags, die
// später die Klassenauswahl auf Etage 3 beeinflussen.
export const INTERVIEW: InterviewQuestion[] = [
  {
    id: 'beruf',
    question: 'Was hast du gemacht, bevor wir deinen Planeten… umgebaut haben?',
    answers: [
      { label: 'Handwerk (Schreiner, Elektrikerin, Mechaniker …)', background: 'Handwerker', stats: { str: 2, ges: 1 }, flags: ['handwerk'],
        reaction: 'Praktisch veranlagt. Du wirst Dinge reparieren können. Hauptsächlich Gesichter. Kaputt.' },
      { label: 'Büro (Sachbearbeitung, IT, Verwaltung …)', background: 'Bürokraft', stats: { int: 3 }, flags: ['buero'],
        reaction: 'Jahre an einem Schreibtisch. Dein Rücken ist ein Wrack, aber du kannst Formulare lesen. Das wird hier unten wichtiger, als du denkst.' },
      { label: 'Pflege oder Medizin', background: 'Pfleger*in', stats: { int: 1, kon: 1, cha: 1 }, skills: ['erste_hilfe'], flags: ['heiler'],
        reaction: 'Du hast Menschen geholfen. Hier unten hilft dir das nur bei dir selbst. Aber immerhin.' },
      { label: 'Militär, Polizei oder Security', background: 'Uniformträger*in', stats: { str: 1, kon: 2 }, skills: ['faustkampf'], flags: ['kaempfer'],
        reaction: 'Endlich jemand mit Erfahrung im Verprügeln. Die Zuschauer reiben sich die Tentakel.' },
      { label: 'Küche oder Gastronomie', background: 'Koch/Köchin', stats: { kon: 1, ges: 1, cha: 1 }, skills: ['kochen'], flags: ['koch'],
        reaction: 'Du kannst kochen? Gut. Irgendwann wirst du Dinge essen müssen, die du selbst getötet hast.' },
      { label: 'Profisport', background: 'Sportler*in', stats: { str: 1, ges: 2, kon: 1 }, flags: ['sportler'],
        reaction: 'Durchtrainiert. Schnell. Die Monster mögen Fastfood, aber sie jagen auch gerne.' },
      { label: 'Schule oder Studium', background: 'Student*in', stats: { int: 2, ges: 1 }, flags: ['student'],
        reaction: 'Du hattest noch dein ganzes Leben vor dir. Hast du immer noch! Es ist nur deutlich kürzer.' },
      { label: 'Nichts Besonderes, ich habe viel gezockt', background: 'Gamer*in', stats: { ges: 1, int: 1 }, skills: ['spielerfahrung'], flags: ['gamer'],
        reaction: 'Ein Gamer in einem echten Dungeon. Die Ironie ist so dick, dass man sie schneiden könnte. Mit einem Schwert. Das du nicht hast.' },
      { label: 'Kunst, Musik oder Schauspiel', background: 'Künstler*in', stats: { cha: 3 }, flags: ['kuenstler'],
        reaction: 'Endlich jemand, der weiß, dass das hier eine Show ist. Lächle für die Kamera!' },
    ],
  },
  {
    id: 'fitness',
    question: 'Wie fit warst du, ehrlich gesagt?',
    answers: [
      { label: 'Sehr fit. Fitnessstudio, fünfmal die Woche.', stats: { str: 2, kon: 1 }, flags: ['fit'],
        reaction: 'Der Bizeps ist notiert. Leider kann man mit Bizeps keine Fallen entschärfen.' },
      { label: 'Normal. Treppen gehen geht.', stats: { kon: 1, ges: 1 },
        reaction: 'Durchschnitt. Die Systemstimme liebt Durchschnitt. Durchschnitt stirbt so unterhaltsam.' },
      { label: 'Ich war eher der gemütliche Typ.', stats: { kon: 2, str: -1, cha: 1 }, flags: ['gemuetlich'],
        reaction: 'Du hast Reserven. Das ist gut. Monster mögen Reserven auch.' },
      { label: 'Ich bin zu allem gerannt. Marathon, Triathlon …', stats: { ges: 2, kon: 2, str: -1 }, flags: ['laeufer'],
        reaction: 'Ausdauer und Beine. Wegrennen ist eine völlig legitime Kampftechnik.' },
    ],
  },
  {
    id: 'haustier',
    question: 'Hattest du ein Haustier, als es passierte?',
    answers: [
      { label: 'Ja, eine Katze. Sie ist bei mir.', pet: { species: 'Katze', defaultName: 'Mausi' },
        reaction: 'Eine Katze. Natürlich. Sie wird dich überleben. Katzen überleben immer.' },
      { label: 'Ja, einen Hund. Er ist bei mir.', pet: { species: 'Hund', defaultName: 'Bello' },
        reaction: 'Ein Hund! Treu, mutig, und er hält dich vermutlich für den Anführer. Armer Hund.' },
      { label: 'Ja, aber es hat es nicht geschafft.', stats: { cha: -1, kon: 1 }, flags: ['trauer'],
        reaction: 'Das tut der Systemstimme leid. Nein, eigentlich nicht. Aber das Protokoll sagt, sie soll das sagen.' },
      { label: 'Nein.', stats: { int: 1 },
        reaction: 'Keine Verantwortung für andere. Das macht das Sterben leichter. Für alle Beteiligten.' },
    ],
  },
  {
    id: 'kleidung',
    question: 'Was hattest du an, als die Welt unterging?',
    answers: [
      { label: 'Bademantel und Boxershorts', items: ['bademantel', 'boxershorts'], flags: ['bademantel'],
        reaction: 'Oh. Oh nein. Oh, das ist WUNDERBAR. Die Zuschauer werden dich lieben.' },
      { label: 'Arbeitskleidung', items: ['arbeitsjacke', 'feinripp'],
        reaction: 'Praktisch. Langweilig. Praktisch langweilig.' },
      { label: 'Sportzeug', items: ['sportshirt', 'turnschuhe'],
        reaction: 'Sportlich gekleidet. Du bist schon mal bereit zum Wegrennen.' },
      { label: 'Einen Schlafanzug', items: ['schlafanzug', 'hausschuhe'],
        reaction: 'Mit Dinos! Die Systemstimme bewertet: 10/10.' },
      { label: 'Einen Anzug', items: ['anzug', 'feinripp'],
        reaction: 'Schick! Du wirst die bestgekleidete Leiche auf dieser Etage.' },
    ],
  },
  {
    id: 'konflikt',
    question: 'Wie hast du früher Konflikte gelöst?',
    answers: [
      { label: 'Reden. Immer erst reden.', stats: { cha: 2 }, flags: ['diplomat'],
        reaction: 'Reden funktioniert hier unten selten. Aber die Zuschauer mögen Monologe vor dem Tod.' },
      { label: 'Mit den Fäusten.', stats: { str: 2 }, flags: ['schlaeger'],
        reaction: 'Ehrlich. Direkt. Die Systemstimme sieht Potenzial.' },
      { label: 'Weglaufen.', stats: { ges: 2 }, flags: ['feigling'],
        reaction: 'Wer wegläuft, lebt länger. Das ist keine Feigheit, das ist Statistik.' },
      { label: 'Planen, Fallen stellen, abwarten.', stats: { int: 2 }, flags: ['planer'],
        reaction: 'Ein Planer. Die gefährlichste Sorte Crawler. Die Systemstimme wird dich im Auge behalten.' },
    ],
  },
];

export const BASE_STATS: Stats = { str: 5, ges: 5, kon: 5, int: 5, cha: 5 };
