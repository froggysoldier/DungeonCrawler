// Zuschauer-System ab Etage 2: Die ganze Galaxis schaut zu.

/** Follower-Schwellen, bei denen es eine Fan-Box gibt, und deren Stufe. */
export const FAN_THRESHOLDS: [number, 'bronze' | 'silber' | 'gold' | 'platin' | 'legendaer'][] = [
  [100, 'bronze'],
  [250, 'bronze'],
  [500, 'silber'],
  [1000, 'silber'],
  [2500, 'gold'],
  [5000, 'gold'],
  [10000, 'platin'],
  [25000, 'platin'],
  [50000, 'legendaer'],
];

export const VIEWER_NAMES = [
  'xX_Glorbnak_Xx', 'Zyrrk vom Mars', 'Oma_Tentakel', 'N’thrax (verifiziert)', 'Blubb7', 'TeamKellerassel',
  'Sternenkind_42', 'Quorzl', 'Krrk!Krrk!', 'Die_echte_Vexa', 'Schleimfan88', 'H0rnochse', 'Laminator3000',
  'Gl’orp', 'FrauMitAchtAugen', 'Zentauri-Zensor', 'Bürokrat_Vogon', 'Pixelfisch', 'SchnappiDerZweite', 'MegaMaus',
];

export const VIEWER_COMMENTS: Record<string, string[]> = {
  kill: ['LOL', 'weiter so!!', 'noch einer, hahaha', 'ez', 'mehr Blut bitte', 'mein Kind schaut zu, danke dafür'],
  stomp: ['DRAUFGESTAMPFT HAHAHA', 'der Stampfer!!!', 'Clip it!', 'Ich kann nicht mehr vor Lachen', 'SMUSH'],
  jump: ['FLIEGENDER TRITT', 'was für ein Sprung', 'Physik: 0, Crawler: 1'],
  crit: ['KRITISCH!!', 'das tat sogar mir weh', 'AUTSCH'],
  boss: ['BOSS DOWN!!!', 'GG', 'Legende.', 'Ich hab 50 Credits auf dich gesetzt und gewonnen!!', 'Abonniert.'],
  achievement: ['Achievement-Jäger, ich seh dich', 'was für ein Name für ein Achievement', 'Sammelt alle!'],
  closecall: ['KNAPP!!!', 'mein Herz', 'ich dachte, das wars', 'LEBT NOCH!!'],
  boring: ['langweilig', 'mach mal was', '*schnarch*', 'schaltet um…', 'schläft da jemand?'],
  item: ['OMG das Teil', 'Neid.', 'steht dir!'],
  pet: ['DAS HAUSTIER!!! So süß!', 'gib dem Tier eine eigene Show', 'bestes Haustier der Staffel'],
};

export const FAN_GIFTS = ['heiltrank', 'energydrink', 'gegengift', 'schokoriegel', 'grosser_heiltrank', 'wutpille', 'ausdauertrank'];
