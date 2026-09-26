import type { Stats } from '../engine/types';

export interface InterviewAnswer {
  label: string;
  /** Kommentar der Systemstimme zu dieser Antwort. */
  reaction: string;
  stats?: Partial<Stats>;
  skills?: string[];
  items?: string[];
  /** Gegenstand, den man beim Start in der Hand hält. */
  hand?: string;
  handMenge?: number;
  flags?: string[];
  traits?: string[];
  pet?: { species: string; defaultName: string };
  background?: string;
  gold?: number;
}

export type Answers = Record<string, number>;

export interface InterviewQuestion {
  id: string;
  question: string;
  /** Frage wird nur gestellt, wenn die Bedingung erfüllt ist (Verzweigung). */
  when?: (a: Answers) => boolean;
  answers: InterviewAnswer[];
}

const is = (a: Answers, id: string, ...idx: number[]) => a[id] !== undefined && idx.includes(a[id]);

// Das Interview der Systemstimme. Die Fragen verzweigen je nach Antwort, und
// die Antworten bestimmen Werte, Start-Skills, Ausrüstung, den Gegenstand in
// der Hand, Eigenschaften (Ängste, Laster, Stärken) und versteckte Flags für
// die spätere Klassenwahl.
export const INTERVIEW: InterviewQuestion[] = [
  // ------------------------------------------------------------ Beruf
  {
    id: 'beruf',
    question: 'In welchem Bereich hast du gearbeitet, bevor wir deinen Planeten… umgebaut haben?',
    answers: [
      /* 0 */ { label: 'Handwerk', background: 'Handwerker*in', stats: { str: 1, ges: 1 }, flags: ['handwerk'], reaction: 'Praktisch veranlagt. Du wirst Dinge reparieren können. Hauptsächlich Gesichter. Kaputt.' },
      /* 1 */ { label: 'Büro und Verwaltung', background: 'Bürokraft', stats: { int: 2 }, flags: ['buero'], reaction: 'Jahre an einem Schreibtisch. Dein Rücken ist ein Wrack, aber du kannst Formulare lesen.' },
      /* 2 */ { label: 'Gesundheit und Pflege', background: 'Pflegekraft', stats: { int: 1, kon: 1 }, flags: ['heiler'], reaction: 'Du hast Menschen geholfen. Hier unten hilft dir das nur bei dir selbst. Aber immerhin.' },
      /* 3 */ { label: 'Sicherheit (Polizei, Militär, Security, Feuerwehr)', background: 'Sicherheitskraft', stats: { kon: 1, str: 1 }, skills: ['faustkampf'], flags: ['kaempfer'], reaction: 'Endlich jemand mit Erfahrung im Verprügeln. Die Zuschauer reiben sich die Tentakel.' },
      /* 4 */ { label: 'Gastronomie', background: 'Gastronom*in', stats: { kon: 1, cha: 1 }, flags: ['gastro'], reaction: 'Stress, Hitze, unzufriedene Gäste. Du bist bestens vorbereitet.' },
      /* 5 */ { label: 'Profisport', background: 'Profisportler*in', stats: { ges: 1, kon: 1 }, flags: ['sportler'], reaction: 'Durchtrainiert. Schnell. Die Monster mögen Fastfood, aber sie jagen auch gerne.' },
      /* 6 */ { label: 'Bildung (Schule, Studium, Lehre, Forschung)', background: 'Akademiker*in', stats: { int: 2 }, flags: ['student'], reaction: 'Bildung! Die Monster sind beeindruckt. Nein, sind sie nicht.' },
      /* 7 */ { label: 'IT und Internet', background: 'IT-Mensch', stats: { int: 1, ges: 1 }, flags: ['it'], reaction: 'Du hast Computer repariert. Hier gibt es keine Computer. Nur Probleme.' },
      /* 8 */ { label: 'Kunst, Musik oder Schauspiel', background: 'Künstler*in', stats: { cha: 2 }, flags: ['kuenstler'], reaction: 'Endlich jemand, der weiß, dass das hier eine Show ist.' },
      /* 9 */ { label: 'Natur (Landwirtschaft, Forst, Garten)', background: 'Naturmensch', stats: { kon: 1, str: 1 }, flags: ['natur'], reaction: 'Du kennst dich mit Lebewesen aus. Vor allem damit, wie man sie loswird.' },
      /* 10 */ { label: 'Verkauf und Handel', background: 'Verkäufer*in', stats: { cha: 2 }, flags: ['handel'], gold: 10, reaction: 'Du kannst Dinge verkaufen. Hier unten verkauft man vor allem sein Leben. Teuer, hoffentlich.' },
      /* 11 */ { label: 'Nichts davon (arbeitslos, Rente, Haushalt)', background: 'Freigeist', stats: { cha: 1, int: 1 }, flags: ['frei'], reaction: 'Viel Zeit gehabt. Die Systemstimme hofft, du hast sie genutzt. Für Kampftraining.' },
    ],
  },
  {
    id: 'handwerk', question: 'Welches Handwerk genau?', when: (a) => is(a, 'beruf', 0),
    answers: [
      { label: 'Schreiner*in', background: 'Schreiner*in', stats: { str: 1 }, skills: ['improvisation'], reaction: 'Holz ist geduldig. Monster nicht. Aber ein Stuhlbein ist ein Stuhlbein.' },
      { label: 'Klempner*in', background: 'Klempner*in', hand: 'rohrzange', traits: ['klempner'], reaction: 'Abflüsse. Rohre. Dinge, die aus Abflüssen kommen. Du bist hier genau richtig.' },
      { label: 'Elektriker*in', background: 'Elektriker*in', stats: { int: 1, ges: 1 }, reaction: 'Strom gibt es keinen mehr. Du hast trotzdem ein Gefühl für Spannung.' },
      { label: 'Dachdecker*in', background: 'Dachdecker*in', traits: ['dachdecker'], stats: { ges: 1 }, reaction: 'Schwindelfrei. Sprünge sind dein Ding. Landungen hoffentlich auch.' },
      { label: 'Schädlingsbekämpfer*in', background: 'Schädlingsbekämpfer*in', traits: ['schaedlingsbekaempfer'], reaction: 'Ratten, Kakerlaken, Spinnen. Du kennst sie alle. Sie kennen dich jetzt auch.' },
    ],
  },
  {
    id: 'gesundheit', question: 'Was genau hast du im Gesundheitswesen gemacht?', when: (a) => is(a, 'beruf', 2),
    answers: [
      { label: 'Pflege', background: 'Pfleger*in', skills: ['erste_hilfe'], stats: { kon: 1 }, reaction: 'Nachtschichten, Stress, Rückenschmerzen. Der Dungeon ist fast Urlaub.' },
      { label: 'Ärztin oder Arzt', background: 'Ärztin/Arzt', skills: ['erste_hilfe'], stats: { int: 2 }, reaction: 'Du weißt genau, wo es wehtut. Das ist im Kampf erstaunlich nützlich.' },
      { label: 'Tiermedizin', background: 'Tierärztin/Tierarzt', traits: ['tierarzt'], reaction: 'Tiere versorgen. Und Tiere besiegen. Beides ist jetzt dein Job.' },
      { label: 'Rettungsdienst', background: 'Rettungssanitäter*in', skills: ['erste_hilfe'], stats: { ges: 1, kon: 1 }, reaction: 'Schnell rein, schnell raus, niemand stirbt. Gute Einstellung für hier.' },
    ],
  },
  {
    id: 'sicherheit', question: 'Welche Uniform hast du getragen?', when: (a) => is(a, 'beruf', 3),
    answers: [
      { label: 'Polizei', background: 'Polizist*in', stats: { cha: 1 }, flags: ['polizei'], reaction: 'Du darfst hier niemanden verhaften. Aber verprügeln geht.' },
      { label: 'Militär', background: 'Soldat*in', stats: { kon: 1, str: 1 }, reaction: 'Befehle befolgen. Die Systemstimme hat viele Befehle. Keiner davon hilft dir.' },
      { label: 'Türsteher*in', background: 'Türsteher*in', traits: ['tuersteher'], stats: { str: 1 }, reaction: 'Du kommst hier nicht rein. Oh, warte. Du bist schon drin.' },
      { label: 'Feuerwehr', background: 'Feuerwehrmann/-frau', traits: ['feuerwehr'], stats: { kon: 1 }, reaction: 'Explosionen, Rauch, Chaos. Du fühlst dich hier fast wie zu Hause.' },
      { label: 'Kammerjäger*in mit Giftschein', background: 'Kammerjäger*in', traits: ['kammerjaeger_gift'], reaction: 'Du hast jahrelang Gift eingeatmet. Dein Körper hat aufgegeben, darauf zu reagieren.' },
    ],
  },
  {
    id: 'gastro', question: 'Wo in der Gastronomie?', when: (a) => is(a, 'beruf', 4),
    answers: [
      { label: 'In der Küche', background: 'Koch/Köchin', skills: ['kochen'], hand: 'kochmesser', flags: ['koch'], reaction: 'Du hattest gerade ein Messer in der Hand, als der Himmel aufriss. Glück gehabt.' },
      { label: 'Im Service', background: 'Kellner*in', stats: { ges: 2 }, reaction: 'Du kannst zehn Teller tragen und dabei lächeln. Ausweichen liegt dir.' },
      { label: 'Hinter der Bar', background: 'Barkeeper*in', traits: ['barkeeper'], hand: 'flasche', reaction: 'Flaschen fangen, Flaschen werfen. Das Werfen wird wichtiger.' },
    ],
  },
  {
    id: 'sport', question: 'Welcher Sport?', when: (a) => is(a, 'beruf', 5),
    answers: [
      { label: 'Fußball', background: 'Fußballprofi', traits: ['fussballer'], reaction: 'Du hast Millionen mit deinen Füßen verdient. Jetzt tötest du damit. Karriereentwicklung.' },
      { label: 'Boxen', background: 'Profiboxer*in', skills: ['faustkampf'], stats: { str: 1 }, flags: ['schlaeger'], reaction: 'Ein echter Boxer. Die Ratten werden das bereuen.' },
      { label: 'Turnen', background: 'Turner*in', stats: { ges: 2 }, traits: ['dachdecker'], reaction: 'Flickflack in den Dungeon. Die Punktrichter sind leider tot.' },
      { label: 'Rugby', background: 'Rugbyspieler*in', traits: ['rugby'], stats: { kon: 1 }, reaction: 'Kopf runter, durch. Eine Philosophie, die hier gut funktioniert.' },
      { label: 'Marathon', background: 'Marathonläufer*in', stats: { kon: 2 }, flags: ['laeufer'], reaction: 'Du kannst stundenlang laufen. Hier wirst du es müssen.' },
    ],
  },
  {
    id: 'it', question: 'Was hast du mit Computern gemacht?', when: (a) => is(a, 'beruf', 7),
    answers: [
      { label: 'Programmiert', background: 'Entwickler*in', stats: { int: 2 }, reaction: 'Du findest Fehler in Systemen. Die Systemstimme hofft, du findest keine in ihr.' },
      { label: 'Gestreamt und gezockt', background: 'Streamer*in', traits: ['streamer'], skills: ['spielerfahrung'], flags: ['gamer'], reaction: 'Du kennst Kameras und Chats. Die Galaxis ist nur ein größerer Chat.' },
      { label: 'Netzwerke betreut', background: 'Admin', stats: { int: 1, kon: 1 }, reaction: 'Hast du es schon mit Aus- und wieder Einschalten versucht? Bei Monstern klappt es nicht.' },
    ],
  },
  {
    id: 'natur', question: 'Was genau in der Natur?', when: (a) => is(a, 'beruf', 9),
    answers: [
      { label: 'Landwirtschaft', background: 'Landwirt*in', stats: { str: 2 }, reaction: 'Du stehst früh auf und arbeitest hart. Beides hilft hier unten.' },
      { label: 'Forstwirtschaft', background: 'Förster*in', traits: ['foerster'], reaction: 'Du kennst den Wald. Die Wesen im Keller sind wie Waldwesen. Nur wütender.' },
      { label: 'Gärtnerei', background: 'Gärtner*in', traits: ['gaertner'], reaction: 'Du hast Gartenzwerge immer gehasst. Gute Nachrichten: Hier darfst du sie zerschlagen.' },
    ],
  },
  // ------------------------------------------------------------ Körper
  {
    id: 'alter', question: 'Wie alt bist du?',
    answers: [
      { label: '18 bis 25', traits: ['jugendlich'], stats: { ges: 1 }, reaction: 'Jung und unsterblich. Zumindest fühlt es sich so an. Noch.' },
      { label: '26 bis 40', stats: { kon: 1 }, reaction: 'Im besten Alter. Für den Tod ist man nie zu alt, aber auch nie zu jung.' },
      { label: '41 bis 60', traits: ['lebenserfahrung'], reaction: 'Lebenserfahrung. Die Knie knacken, aber der Kopf ist klar.' },
      { label: 'Über 60', traits: ['lebenserfahrung', 'alte_knochen'], stats: { int: 1, cha: 1 }, reaction: 'Du hast die Welt schon einmal untergehen sehen. Zumindest gefühlt. Jetzt eben richtig.' },
    ],
  },
  {
    id: 'fitness',
    question: 'Wie fit warst du, ehrlich gesagt?',
    answers: [
      { label: 'Sehr fit. Fitnessstudio, fünfmal die Woche.', stats: { str: 2, kon: 1 }, flags: ['fit'], reaction: 'Der Bizeps ist notiert. Leider kann man mit Bizeps keine Fallen entschärfen.' },
      { label: 'Normal. Treppen gehen geht.', stats: { kon: 1, ges: 1 }, reaction: 'Durchschnitt. Die Systemstimme liebt Durchschnitt. Durchschnitt stirbt so unterhaltsam.' },
      { label: 'Ich war eher der gemütliche Typ.', stats: { kon: 2, str: -1, cha: 1 }, flags: ['gemuetlich'], reaction: 'Du hast Reserven. Das ist gut. Monster mögen Reserven auch.' },
      { label: 'Ich bin zu allem gerannt. Marathon, Triathlon …', stats: { ges: 2, kon: 2, str: -1 }, flags: ['laeufer'], reaction: 'Ausdauer und Beine. Wegrennen ist eine völlig legitime Kampftechnik.' },
    ],
  },
  {
    id: 'hobbysport', question: 'Hast du in deiner Freizeit Sport gemacht?',
    answers: [
      { label: 'Nein', reaction: 'Ehrlich. Die Systemstimme schätzt Ehrlichkeit. Sie bestraft sie trotzdem.' },
      { label: 'Kampfsport', flags: ['kampfsport'], reaction: 'Oh, interessant. Welcher denn?' },
      { label: 'Tanzen', stats: { ges: 2 }, skills: ['ausweichen'], reaction: 'Tanzen ist Ausweichen mit Musik. Hier ohne Musik.' },
      { label: 'Klettern', traits: ['dachdecker'], stats: { str: 1 }, reaction: 'Schwindelfrei und griffstark. Die Wände hier sind leider glatt.' },
      { label: 'Mannschaftssport', traits: ['teamplayer'], reaction: 'Du spielst gerne im Team. Hoffentlich hast du ein Haustier.' },
    ],
  },
  {
    id: 'kampfsport', question: 'Welcher Kampfsport?', when: (a) => is(a, 'hobbysport', 1),
    answers: [
      { label: 'Karate', skills: ['treten'], stats: { ges: 1 }, reaction: 'Gelber Gürtel? Die Systemstimme sieht es in deinen Augen. Gelber Gürtel.' },
      { label: 'Kickboxen', skills: ['treten', 'faustkampf'], reaction: 'Hände und Füße. Die Grundausstattung für diesen Dungeon.' },
      { label: 'Judo', skills: ['sturmangriff'], stats: { str: 1 }, reaction: 'Umwerfen ist deine Stärke. Draufstampfen lernst du hier.' },
      { label: 'Boxen', skills: ['faustkampf'], stats: { str: 1 }, reaction: 'Ein Boxer im Hobby. Die Faust ist schon warm.' },
      { label: 'Muay Thai', skills: ['knie', 'ellbogen'], reaction: 'Knie und Ellbogen. Die unterschätzten Waffen. Nicht mehr lange.' },
    ],
  },
  {
    id: 'augen', question: 'Wie gut siehst du?',
    answers: [
      { label: 'Sehr gut', traits: ['adleraugen'], reaction: 'Adleraugen. Du siehst die Monster früh. Das hilft beim Wegrennen.' },
      { label: 'Normal', reaction: 'Normal. Du wirst die Monster rechtzeitig sehen. Knapp.' },
      { label: 'Ich trage eine Brille – und hatte sie auf', items: ['brille'], reaction: 'Die Brille hat den Weltuntergang überlebt. Pass auf sie auf.' },
      { label: 'Ich brauche eine Brille – hatte sie aber nicht auf', traits: ['kurzsichtig'], reaction: 'Oh. Oh nein. Das wird… unscharf.' },
    ],
  },
  {
    id: 'schlaf', question: 'Wie schläfst du normalerweise?',
    answers: [
      { label: 'Früh ins Bett, früh raus', traits: ['fruehaufsteher'], reaction: 'Frühaufsteher. Der Dungeon hat keinen Morgen, aber du wirst trotzdem wach sein.' },
      { label: 'Ich bin eine Nachteule', traits: ['nachteule'], reaction: 'Du siehst im Dunkeln besser als andere. Hier ist es immer dunkel. Glückwunsch.' },
      { label: 'Ich schlafe kaum', traits: ['schlaflos'], reaction: 'Wer nicht schläft, lernt mehr. Und stirbt müder.' },
      { label: 'Ganz normal', reaction: 'Normal ist gut. Normal ist langweilig. Die Zuschauer mögen es nicht, aber du lebst länger.' },
    ],
  },
  // ------------------------------------------------------------ Situation beim Weltuntergang
  {
    id: 'haustier',
    question: 'Hattest du ein Haustier, als es passierte?',
    answers: [
      { label: 'Ja, eine Katze. Sie ist bei mir.', pet: { species: 'Katze', defaultName: 'Mausi' }, reaction: 'Eine Katze. Natürlich. Sie wird dich überleben. Katzen überleben immer.' },
      { label: 'Ja, einen Hund. Er ist bei mir.', pet: { species: 'Hund', defaultName: 'Bello' }, reaction: 'Ein Hund! Treu, mutig, und er hält dich vermutlich für den Anführer. Armer Hund.' },
      { label: 'Ja, aber es hat es nicht geschafft.', stats: { cha: -1, kon: 1 }, flags: ['trauer'], reaction: 'Das tut der Systemstimme leid. Nein, eigentlich nicht. Aber das Protokoll sagt, sie soll das sagen.' },
      { label: 'Nein.', stats: { int: 1 }, reaction: 'Keine Verantwortung für andere. Das macht das Sterben leichter. Für alle Beteiligten.' },
    ],
  },
  {
    id: 'ort', question: 'Wo warst du, als der Himmel aufriss?',
    answers: [
      { label: 'Zu Hause auf dem Sofa', stats: { kon: 1 }, reaction: 'Gemütlich. Bis eben.' },
      { label: 'Bei der Arbeit', stats: { int: 1 }, reaction: 'Überstunden. Die letzten deines Lebens. Zumindest die letzten bezahlten.' },
      { label: 'Im Supermarkt', hand: 'dose', handMenge: 3, reaction: 'Du hattest Dosen in der Hand. Dosen sind hier Munition.' },
      { label: 'In der Kneipe', hand: 'bierkrug', traits: ['trinker'], reaction: 'Du hast noch dein Glas in der Hand. Prost auf den Weltuntergang.' },
      { label: 'Im Bett', stats: { kon: 1 }, reaction: 'Im Bett. Hoffentlich allein. Die Systemstimme fragt nicht weiter.' },
      { label: 'Auf der Toilette', hand: 'klobuerste', reaction: 'Oh. Oh nein. Du hast die Klobürste noch in der Hand. Die Zuschauer weinen vor Lachen.' },
    ],
  },
  {
    id: 'hand', question: 'Was hattest du in der Hand?', when: (a) => !is(a, 'ort', 2, 3, 5),
    answers: [
      { label: 'Mein Handy', hand: 'handy', reaction: 'Kein Netz. Kein Akku bald. Aber es fliegt.' },
      { label: 'Eine Kaffeetasse', hand: 'kaffeetasse', traits: ['koffein'], reaction: 'Mit Kaffee. Kalt jetzt. Die Tasse ist trotzdem ein gutes Wurfgeschoss.' },
      { label: 'Die Fernbedienung', hand: 'fernbedienung', reaction: 'Du hast umgeschaltet, als die Welt unterging. Jetzt bist du das Programm.' },
      { label: 'Meinen Schlüsselbund', hand: 'schluesselbund', reaction: 'Schlüssel zu einer Tür, die es nicht mehr gibt.' },
      { label: 'Eine Bratpfanne', hand: 'bratpfanne', reaction: 'Du hattest eine Bratpfanne in der Hand. Das Schicksal meint es gut mit dir.' },
      { label: 'Nichts', stats: { ges: 1 }, reaction: 'Leere Hände. Freie Hände. Fäuste.' },
    ],
  },
  {
    id: 'kleidung',
    question: 'Was hattest du an?',
    answers: [
      { label: 'Bademantel und Boxershorts', items: ['bademantel', 'boxershorts'], flags: ['bademantel'], reaction: 'Oh. Oh nein. Oh, das ist WUNDERBAR. Die Zuschauer werden dich lieben.' },
      { label: 'Arbeitskleidung', items: ['arbeitsjacke', 'feinripp'], reaction: 'Praktisch. Langweilig. Praktisch langweilig.' },
      { label: 'Sportzeug', items: ['sportshirt', 'turnschuhe'], reaction: 'Sportlich gekleidet. Du bist schon mal bereit zum Wegrennen.' },
      { label: 'Einen Schlafanzug', items: ['schlafanzug', 'hausschuhe'], reaction: 'Mit Dinos! Die Systemstimme bewertet: 10 von 10.' },
      { label: 'Einen Anzug', items: ['anzug', 'feinripp'], reaction: 'Schick! Du wirst die bestgekleidete Leiche auf dieser Etage.' },
    ],
  },
  // ------------------------------------------------------------ Charakter
  {
    id: 'konflikt',
    question: 'Wie hast du früher Konflikte gelöst?',
    answers: [
      { label: 'Reden. Immer erst reden.', stats: { cha: 2 }, flags: ['diplomat'], reaction: 'Reden funktioniert hier unten selten. Aber die Zuschauer mögen Monologe vor dem Tod.' },
      { label: 'Mit den Fäusten.', stats: { str: 2 }, flags: ['schlaeger'], reaction: 'Ehrlich. Direkt. Die Systemstimme sieht Potenzial.' },
      { label: 'Weglaufen.', stats: { ges: 2 }, flags: ['feigling'], reaction: 'Wer wegläuft, lebt länger. Das ist keine Feigheit, das ist Statistik.' },
      { label: 'Planen, Fallen stellen, abwarten.', stats: { int: 2 }, flags: ['planer'], reaction: 'Ein Planer. Die gefährlichste Sorte Crawler. Die Systemstimme wird dich im Auge behalten.' },
      { label: 'Mit dem Kopf durch die Wand.', traits: ['dickkopf'], reaction: 'Wörtlich? Wird sich zeigen. Hier gibt es viele Wände.' },
    ],
  },
  {
    id: 'charakter', question: 'Wie würdest du dich selbst beschreiben?',
    answers: [
      { label: 'Mutig', traits: ['mutig'], reaction: 'Mutig. Oder einfach schlecht darin, Gefahren einzuschätzen.' },
      { label: 'Vorsichtig', traits: ['vorsichtig'], reaction: 'Vorsicht ist die Mutter der Porzellankiste. Porzellan gibt es hier genug. Zum Werfen.' },
      { label: 'Chaotisch', traits: ['chaotisch'], reaction: 'Chaos ist unterhaltsam. Die Einschaltquoten danken.' },
      { label: 'Berechnend', traits: ['berechnend'], reaction: 'Du rechnest. Die Systemstimme rechnet auch. Mit deinem Tod.' },
    ],
  },
  {
    id: 'sozial', question: 'Wie bist du unter Menschen?',
    answers: [
      { label: 'Ich bin am liebsten allein', traits: ['einzelgaenger'], reaction: 'Hier unten bist du allein. Wunsch erfüllt.' },
      { label: 'Ich bin gern im Team', traits: ['teamplayer'], reaction: 'Teamwork! Such dir Freunde. Die meisten hier wollen dich allerdings essen.' },
      { label: 'Ich stehe gern im Mittelpunkt', traits: ['rampensau'], stats: { cha: 1 }, reaction: 'Eine Rampensau! Die Kameras lieben dich schon.' },
      { label: 'Ich bin eher schüchtern', traits: ['schuechtern'], reaction: 'Schüchtern. Das heißt, du kannst dich gut anschleichen.' },
    ],
  },
  {
    id: 'angst', question: 'Wovor hast du am meisten Angst?',
    answers: [
      { label: 'Spinnen und Krabbeltiere', traits: ['angst_krabbeltiere'], reaction: 'Oh. Die Systemstimme hat da eine Nachricht für dich. Nein, lieber nicht. Du wirst es sehen.' },
      { label: 'Ratten', traits: ['angst_ratten'], reaction: 'Ratten. Im Keller. Das wird eine sehr lange erste Etage.' },
      { label: 'Dunkelheit', traits: ['angst_dunkel'], reaction: 'Angst im Dunkeln. In einem Dungeon. Die Systemstimme liebt Ironie.' },
      { label: 'Höhe', traits: ['hoehenangst'], reaction: 'Höhenangst. Gut, dass es nur nach unten geht.' },
      { label: 'Enge Räume', traits: ['platzangst'], reaction: 'Platzangst in einem Labyrinth aus Gängen. Das ist fast schon Absicht.' },
      { label: 'Vor nichts', traits: ['mutig'], reaction: 'Vor nichts? Das wird sich ändern.' },
    ],
  },
  {
    id: 'laster', question: 'Hast du ein Laster?',
    answers: [
      { label: 'Ich rauche', traits: ['raucher'], reaction: 'Rauchen gefährdet deine Gesundheit. Hier ist das dein kleinstes Problem.' },
      { label: 'Ich trinke gern mal einen', traits: ['trinker'], reaction: 'Prost! Es gibt hier Bier. Warm, aber es gibt es.' },
      { label: 'Süßigkeiten', traits: ['naschkatze'], reaction: 'Schokoriegel sind hier Heilmittel. Endlich eine Ausrede.' },
      { label: 'Kaffee', traits: ['koffein'], reaction: 'Ohne Kaffee geht nichts. Die Restaurants hier haben welchen. Zum Glück.' },
      { label: 'Glücksspiel und Videospiele', traits: ['zocker'], reaction: 'Lootboxen! Du wirst es lieben. Und hassen. Vor allem lieben.' },
      { label: 'Keins', reaction: 'Keine Laster. Die Systemstimme glaubt dir kein Wort.' },
    ],
  },
  {
    id: 'glueck', question: 'Hast du im Leben eher Glück oder Pech gehabt?',
    answers: [
      { label: 'Ich bin ein Glückspilz', traits: ['glueckspilz'], reaction: 'Du hast den Weltuntergang überlebt. Das zählt als Glück. Knapp.' },
      { label: 'Ich bin ein Pechvogel', traits: ['pechvogel'], reaction: 'Pechvogel. Dein Planet wurde zerstört. Ja, das passt.' },
      { label: 'Mal so, mal so', reaction: 'Durchschnittliches Glück. Die Würfel entscheiden hier unten ohnehin alles.' },
    ],
  },
];

/** Die Fragen, die bei diesen Antworten gestellt werden (in Reihenfolge). */
export function visibleQuestions(a: Answers): InterviewQuestion[] {
  return INTERVIEW.filter((q) => !q.when || q.when(a));
}

/** Frühere Spielstände und Tests übergeben Antworten als Liste in dieser Reihenfolge. */
export const LEGACY_ORDER = ['beruf', 'fitness', 'haustier', 'kleidung', 'konflikt'];

/** Kombinationen, die sich gegenseitig beeinflussen. */
export const INTERVIEW_COMBOS: { when: (a: Answers) => boolean; traits: string[]; text: string }[] = [
  {
    when: (a) => is(a, 'sport', 1) && is(a, 'kampfsport', 3),
    traits: ['profischlaeger'],
    text: 'Boxen als Beruf UND als Hobby. Die Systemstimme vermerkt: Profi-Schläger.',
  },
  {
    when: (a) => is(a, 'sicherheit', 2) && is(a, 'konflikt', 1),
    traits: ['profischlaeger'],
    text: 'Türsteher*in, die Konflikte mit den Fäusten löst. Überraschung: Profi-Schläger.',
  },
  {
    when: (a) => is(a, 'handwerk', 4) && is(a, 'angst', 0),
    traits: [],
    text: 'Schädlingsbekämpfung – mit Angst vor Krabbeltieren? Die Systemstimme hat Fragen. Viele Fragen.',
  },
  {
    when: (a) => is(a, 'it', 1) && is(a, 'sozial', 2),
    traits: ['rampensau'],
    text: 'Streamer und Rampensau. Die Galaxis wird dich lieben. Oder hassen. Hauptsache Quote.',
  },
];

export const BASE_STATS: Stats = { str: 5, ges: 5, kon: 5, int: 5, cha: 5 };
