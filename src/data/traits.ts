import type { Bonuses, GameState, SpecialEffect } from '../engine/types';

/**
 * Eigenschaften aus dem Vorleben: Ängste, Laster, Stärken, Berufserfahrung.
 * Sie wirken dauerhaft. Manche gelten nur in bestimmten Situationen
 * (`vs`: Facetten des Beobachters, z. B. „z:insekt“ oder „m:sprung“), und
 * manche lassen sich im Dungeon überwinden (`overcome`).
 */
export interface TraitDef {
  id: string;
  name: string;
  description: string;
  kind: 'angst' | 'laster' | 'staerke' | 'erfahrung' | 'eigenart';
  bonuses?: Bonuses;
  vs?: { facet: string; hit?: number; dmg?: number }[];
  special?: SpecialEffect;
  /** Follower-Multiplikator (Publikum). */
  followerMult?: number;
  overcome?: { check: (s: GameState) => boolean; becomes: string; text: string };
}

const kills = (s: GameState, ...ids: string[]) => ids.reduce((a, id) => a + (s.counters.killsByDef[id] ?? 0), 0);
/** Gesamtzähler des Beobachters, z. B. „total|hit|m:sprung“. */
const total = (s: GameState, key: string) => s.chronicle?.counts[`total|${key}`] ?? 0;

export const TRAITS: TraitDef[] = [
  // ------------------------------------------------------------ Ängste (überwindbar)
  {
    id: 'angst_krabbeltiere', name: 'Angst vor Krabbeltieren', kind: 'angst',
    description: '−15 % Treffer und −10 % Schaden gegen Krabbeltiere. Überwindbar: 10 Krabbeltiere besiegen.',
    vs: [{ facet: 'z:insekt', hit: -15, dmg: -10 }],
    overcome: {
      check: (s) => kills(s, 'kellerspinne', 'riesenkakerlake') >= 10, becomes: 'krabbeltier_schreck',
      text: 'Du hast deiner Angst so oft ins Gesicht getreten, dass sie jetzt Angst vor dir hat.',
    },
  },
  {
    id: 'krabbeltier_schreck', name: 'Krabbeltier-Schreck', kind: 'staerke',
    description: '+10 % Treffer und +15 % Schaden gegen Krabbeltiere. Aus überwundener Angst entstanden.',
    vs: [{ facet: 'z:insekt', hit: 10, dmg: 15 }],
  },
  {
    id: 'angst_ratten', name: 'Angst vor Ratten', kind: 'angst',
    description: '−15 % Treffer gegen Ratten. Überwindbar: 15 Ratten besiegen.',
    vs: [{ facet: 'z:ratte', hit: -15 }],
    overcome: {
      check: (s) => kills(s, 'kellerratte', 'rattenmensch', 'rattenschamane', 'knochenratte') >= 15, becomes: 'rattenfaenger',
      text: 'Ratten sind jetzt keine Bedrohung mehr. Sie sind Arbeit.',
    },
  },
  {
    id: 'rattenfaenger', name: 'Rattenfänger', kind: 'staerke',
    description: '+20 % Schaden gegen Ratten. Aus überwundener Angst entstanden.',
    vs: [{ facet: 'z:ratte', dmg: 20 }],
  },
  {
    id: 'angst_dunkel', name: 'Angst im Dunkeln', kind: 'angst',
    description: '−1 Sichtweite. Überwindbar: 8 Geister oder Untote besiegen.',
    bonuses: { lichtradius: -1 },
    overcome: {
      check: (s) => kills(s, 'poltergeist', 'irrlicht', 'ghul', 'moorleiche', 'nachtmahr', 'knochenratte', 'kellermeister', 'ghulhund') >= 8,
      becomes: 'nachtauge',
      text: 'Die Dunkelheit ist jetzt dein Zuhause. Du siehst in ihr besser als die meisten im Licht.',
    },
  },
  {
    id: 'nachtauge', name: 'Nachtauge', kind: 'staerke',
    description: '+1 Sichtweite. Aus überwundener Angst entstanden.',
    bonuses: { lichtradius: 1 },
  },
  {
    id: 'hoehenangst', name: 'Höhenangst', kind: 'angst',
    description: '−15 % Treffer bei Sprungangriffen. Überwindbar: 15 Treffer mit Sprungangriffen.',
    vs: [{ facet: 'm:sprung', hit: -15 }],
    overcome: {
      check: (s) => total(s, 'hit|m:sprung') >= 15, becomes: 'luftakrobat',
      text: 'Du springst jetzt, ohne nach unten zu schauen. Meistens landest du auf jemandem.',
    },
  },
  {
    id: 'luftakrobat', name: 'Luftakrobat', kind: 'staerke',
    description: '+10 % Treffer und +10 % Schaden bei Sprungangriffen.',
    vs: [{ facet: 'm:sprung', hit: 10, dmg: 10 }],
  },
  {
    id: 'platzangst', name: 'Platzangst', kind: 'angst',
    description: '−10 % Treffer, wenn du in einem Gang kämpfst. Überwindbar: 20 Siege in Gängen.',
    vs: [{ facet: 'i:im_gang', hit: -10 }],
    overcome: {
      check: (s) => total(s, 'kill|i:im_gang') >= 20, becomes: 'tunnelkaempfer',
      text: 'Enge Gänge sind jetzt dein Revier.',
    },
  },
  {
    id: 'tunnelkaempfer', name: 'Tunnelkämpfer', kind: 'staerke',
    description: '+10 % Schaden in Gängen.',
    vs: [{ facet: 'i:im_gang', dmg: 10 }],
  },
  // ------------------------------------------------------------ Laster
  { id: 'raucher', name: 'Raucher', kind: 'laster', description: '−3 max. Ausdauer.', bonuses: { maxAusdauer: -3 } },
  {
    id: 'trinker', name: 'Gelegenheitstrinker', kind: 'laster',
    description: '+15 % Schaden, wenn du angetrunken bist. −1 Geschick.',
    bonuses: { stats: { ges: -1 } }, vs: [{ facet: 'i:angetrunken', dmg: 15 }],
  },
  { id: 'naschkatze', name: 'Naschkatze', kind: 'laster', description: '+3 max. HP (Reserven), −1 Geschick.', bonuses: { maxHp: 3, stats: { ges: -1 } } },
  { id: 'koffein', name: 'Koffein-abhängig', kind: 'laster', description: '+2 max. Ausdauer, −2 % Treffer.', bonuses: { maxAusdauer: 2, treffer: -2 } },
  { id: 'zocker', name: 'Zocker', kind: 'laster', description: '+5 % XP, −1 Konstitution.', bonuses: { xpBonus: 5, stats: { kon: -1 } } },
  // ------------------------------------------------------------ Körper & Sinne
  { id: 'kurzsichtig', name: 'Kurzsichtig', kind: 'eigenart', description: '−1 Sichtweite, −3 % Treffer.', bonuses: { lichtradius: -1, treffer: -3 } },
  { id: 'adleraugen', name: 'Adleraugen', kind: 'staerke', description: '+1 Sichtweite, +3 % Treffer bei Würfen.', bonuses: { lichtradius: 1 }, vs: [{ facet: 't:wurf', hit: 3 }] },
  { id: 'nachteule', name: 'Nachteule', kind: 'eigenart', description: '+1 Sichtweite.', bonuses: { lichtradius: 1 } },
  { id: 'fruehaufsteher', name: 'Frühaufsteher', kind: 'eigenart', description: '+2 max. Ausdauer.', bonuses: { maxAusdauer: 2 } },
  { id: 'schlaflos', name: 'Schlaflos', kind: 'eigenart', description: '+5 % XP, −3 max. HP.', bonuses: { xpBonus: 5, maxHp: -3 } },
  { id: 'jugendlich', name: 'Jugendlicher Leichtsinn', kind: 'eigenart', description: '+2 max. Ausdauer, +10 % Schaden gegen stärkere Gegner.', bonuses: { maxAusdauer: 2 }, vs: [{ facet: 'z:staerker', dmg: 10 }] },
  { id: 'lebenserfahrung', name: 'Lebenserfahrung', kind: 'erfahrung', description: '+8 % XP.', bonuses: { xpBonus: 8 } },
  { id: 'alte_knochen', name: 'Alte Knochen', kind: 'eigenart', description: '−2 max. Ausdauer, +1 Rüstung (dicke Haut).', bonuses: { maxAusdauer: -2, ruestung: 1 } },
  // ------------------------------------------------------------ Charakter
  { id: 'einzelgaenger', name: 'Einzelgänger', kind: 'eigenart', description: '+3 % Ausweichen, −1 Charisma.', bonuses: { ausweichen: 3, stats: { cha: -1 } } },
  { id: 'teamplayer', name: 'Teamplayer', kind: 'eigenart', description: '+10 % Schaden, wenn dein Haustier neben dir ist.', vs: [{ facet: 'i:haustier', dmg: 10 }] },
  { id: 'rampensau', name: 'Rampensau', kind: 'eigenart', description: '+30 % Follower-Zuwachs.', followerMult: 1.3 },
  { id: 'schuechtern', name: 'Schüchtern', kind: 'eigenart', description: '−2 Charisma, +15 % Schaden gegen ahnungslose Gegner.', bonuses: { stats: { cha: -2 } }, vs: [{ facet: 'z:ahnungslos', dmg: 15 }] },
  { id: 'glueckspilz', name: 'Glückspilz', kind: 'eigenart', description: '+4 % Krit-Chance.', bonuses: { krit: 4 } },
  { id: 'pechvogel', name: 'Pechvogel', kind: 'eigenart', description: '−2 % Krit-Chance, +10 % XP (du lernst aus Fehlern).', bonuses: { krit: -2, xpBonus: 10 } },
  { id: 'mutig', name: 'Draufgänger', kind: 'eigenart', description: '+12 % Schaden gegen stärkere Gegner.', vs: [{ facet: 'z:staerker', dmg: 12 }] },
  { id: 'vorsichtig', name: 'Vorsichtig', kind: 'eigenart', description: '+4 % Ausweichen.', bonuses: { ausweichen: 4 } },
  { id: 'chaotisch', name: 'Chaotisch', kind: 'eigenart', description: '+4 % Krit-Chance, −3 % Treffer.', bonuses: { krit: 4, treffer: -3 } },
  { id: 'berechnend', name: 'Berechnend', kind: 'eigenart', description: '+4 % Treffer.', bonuses: { treffer: 4 } },
  { id: 'dickkopf', name: 'Dickkopf', kind: 'eigenart', description: '+20 % Kopfstoßschaden.', bonuses: { schaden: { kopf: 20 } } },
  // ------------------------------------------------------------ Berufserfahrung
  { id: 'schaedlingsbekaempfer', name: 'Schädlingsbekämpfer', kind: 'erfahrung', description: '+15 % Schaden gegen Ratten und Krabbeltiere.', vs: [{ facet: 'z:ratte', dmg: 15 }, { facet: 'z:insekt', dmg: 15 }] },
  { id: 'klempner', name: 'Klempner', kind: 'erfahrung', description: '+15 % Schaden gegen Schleime und Wasserwesen.', vs: [{ facet: 'z:schleim', dmg: 15 }, { facet: 'z:aquatisch', dmg: 15 }] },
  { id: 'dachdecker', name: 'Schwindelfrei', kind: 'erfahrung', description: '+10 % Treffer bei Sprungangriffen.', vs: [{ facet: 'm:sprung', hit: 10 }] },
  { id: 'feuerwehr', name: 'Feuerwehrerfahrung', kind: 'erfahrung', description: 'Halber Explosionsschaden.', special: 'explosionsschutz' },
  { id: 'tierarzt', name: 'Tiermedizin', kind: 'erfahrung', description: '+15 % Schaden gegen Tiere, Haustier +1 Stufe.', vs: [{ facet: 'z:tier', dmg: 15 }] },
  { id: 'kammerjaeger_gift', name: 'Giftkunde', kind: 'erfahrung', description: 'Immun gegen Gift.', special: 'giftimmun' },
  { id: 'tuersteher', name: 'Türsteher-Blick', kind: 'erfahrung', description: '+10 % Schaden gegen Humanoide und Kobolde.', vs: [{ facet: 'z:humanoid', dmg: 10 }, { facet: 'z:kobold', dmg: 10 }] },
  { id: 'barkeeper', name: 'Barkeeper-Wurfarm', kind: 'erfahrung', description: '+20 % Wurfschaden.', bonuses: { schaden: { wurf: 20 } } },
  { id: 'profischlaeger', name: 'Profi-Schläger', kind: 'erfahrung', description: '+15 % Faustschaden (Beruf und Hobby passen zusammen).', bonuses: { schaden: { faust: 15 } } },
  { id: 'fussballer', name: 'Fußballer-Schuss', kind: 'erfahrung', description: '+15 % Trittschaden.', bonuses: { schaden: { tritt: 15 } } },
  { id: 'rugby', name: 'Gedränge-Erfahrung', kind: 'erfahrung', description: '+20 % Schaden bei Sturmangriffen.', vs: [{ facet: 'm:anlauf', dmg: 20 }] },
  { id: 'streamer', name: 'Streamer-Routine', kind: 'erfahrung', description: '+50 % Follower-Zuwachs.', followerMult: 1.5 },
  { id: 'foerster', name: 'Waldläufer', kind: 'erfahrung', description: '+10 % Schaden gegen Fabelwesen und Kryptiden.', vs: [{ facet: 'z:folklore', dmg: 10 }, { facet: 'z:kryptid', dmg: 10 }] },
  { id: 'gaertner', name: 'Gartenzwerg-Groll', kind: 'erfahrung', description: '+30 % Schaden gegen Konstrukte (Gartenzwerge).', vs: [{ facet: 'z:konstrukt', dmg: 30 }] },
];

export const TRAIT_BY_ID: Record<string, TraitDef> = Object.fromEntries(TRAITS.map((t) => [t.id, t]));

export const TRAIT_KIND_NAMES: Record<TraitDef['kind'], string> = {
  angst: 'Angst', laster: 'Laster', staerke: 'Stärke', erfahrung: 'Erfahrung', eigenart: 'Eigenart',
};
