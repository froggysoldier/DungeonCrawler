import type { AchievementDef } from './achievements';

// Dritte Welle: Fallen, Handwerk, andere Crawler und die Party.

export const SOCIAL_ACHIEVEMENTS: AchievementDef[] = [
  {
    id: 'adlerauge', name: 'Adlerauge', tier: 'bronze', box: 'ueberlebens',
    description: 'Entdecke eine versteckte Falle.',
    comment: 'Der Boden hat dich angelogen. Du hast es gemerkt. Die Systemstimme ist ein bisschen enttäuscht.',
    check: (e) => e.type === 'trapDetected',
  },
  {
    id: 'reingetreten', name: 'Voll reingetreten', tier: 'bronze', box: 'ueberlebens',
    description: 'Löse eine Falle aus. Mit dem eigenen Körper.',
    comment: 'Die Falle hat jahrelang auf diesen Moment gewartet. Danke, dass du ihr den Tag gerettet hast.',
    check: (e) => e.type === 'trapTriggered' && e.onPlayer,
  },
  {
    id: 'entschaerfer', name: 'Roter oder blauer Draht?', tier: 'silber', box: 'ueberlebens',
    description: 'Entschärfe eine Falle.',
    comment: 'Ruhige Hände. Die Zuschauer hätten lieber eine Explosion gesehen.',
    check: (e) => e.type === 'trapDisarmed' && e.success,
  },
  {
    id: 'fallensteller', name: 'Wer anderen eine Grube gräbt', tier: 'silber', box: 'wurf',
    description: 'Ein Monster tappt in deine eigene Falle.',
    comment: '… fällt normalerweise selbst hinein. Diesmal nicht. Sprichwörter sind hier unten außer Kraft.',
    check: (e) => e.type === 'trapTriggered' && !e.onPlayer,
  },
  {
    id: 'bastler', name: 'Bastelstunde', tier: 'bronze', box: 'wurf',
    description: 'Stelle etwas her.',
    comment: 'Aus Müll wird Ausrüstung. Die Galaxis nennt das Recycling. Du nennst es Überleben.',
    check: (e) => e.type === 'crafted',
  },
  {
    id: 'brandstifter', name: 'Brandbeschleuniger', tier: 'silber', box: 'wurf',
    description: 'Stelle eine Brandflasche oder Nagelbombe her.',
    comment: 'Die Systemstimme hat das Rezept nicht verraten. Du hast es trotzdem herausgefunden. Beunruhigend.',
    check: (e) => e.type === 'crafted' && (e.recipe === 'brandflasche' || e.recipe === 'nagelbombe'),
  },
  {
    id: 'bombig', name: 'Bombenstimmung', tier: 'gold', box: 'wurf',
    description: 'Töte einen Gegner mit einem selbstgebauten Sprengsatz.',
    comment: 'Handwerk hat goldenen Boden. Und jetzt auch Einzelteile eines Gegners darauf.',
    check: (e) => e.type === 'kill' && !!e.facets?.includes('t:bombe'),
  },
  {
    id: 'hallo_nachbar', name: 'Hallo, Nachbar', tier: 'bronze', box: 'fan',
    description: 'Sprich mit einem anderen Crawler.',
    comment: 'Ein Mensch! Wie aufregend. Genieß es. Die Zahl sinkt schnell.',
    check: (e) => e.type === 'crawlerMet',
  },
  {
    id: 'gemeinsam', name: 'Gemeinsam statt einsam', tier: 'silber', box: 'abenteurer',
    description: 'Nimm jemanden in deine Party auf.',
    comment: 'Jetzt seid ihr zu zweit. Doppelt so viele Ziele für die Monster.',
    check: (e) => e.type === 'partyJoined',
  },
  {
    id: 'volles_haus', name: 'Volles Haus', tier: 'gold', box: 'abenteurer',
    description: 'Führe eine Party mit vier Crawlern an.',
    comment: 'Vier Leute, ein Ziel, null Plan. Klassische Abenteurergruppe.',
    check: (e) => e.type === 'partyJoined' && e.size >= 4,
  },
  {
    id: 'trauer', name: 'Es gibt kein Wiedersehen', tier: 'silber', box: 'ueberlebens',
    description: 'Verliere ein Party-Mitglied.',
    comment: 'Die Systemstimme spricht ihr Beileid aus. Sie hat eine Vorlage dafür. Sie benutzt sie oft.',
    check: (e) => e.type === 'crawlerDied' && e.party,
  },
  {
    id: 'crawler_gegen_crawler', name: 'Homo homini lupus', tier: 'gold', box: 'brawler',
    description: 'Besiege einen Crawler, der dich ausrauben wollte.',
    comment: 'Der Mensch ist des Menschen Wolf. Heute warst du der größere Wolf.',
    check: (e) => e.type === 'kill' && e.monster.defId === 'abtruenniger_crawler',
  },
];
