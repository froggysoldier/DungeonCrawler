/**
 * Gezeichnete Kreaturen statt Buchstaben: jede Monsterart hat eine
 * erkennbare Silhouette (Spinne, Ratte, Fledermaus, Kobold …). Alles wird
 * mit Canvas-Pfaden in einem Raster von −50 bis 50 gezeichnet und skaliert,
 * damit es auf der Karte und als großes Porträt gleich gut aussieht.
 */

type Ctx = CanvasRenderingContext2D;

export type SpriteKind =
  | 'ratte' | 'kakerlake' | 'kobold' | 'schleim' | 'hase' | 'geist' | 'alien' | 'sack' | 'wurm' | 'zombie'
  | 'gnom' | 'spinne' | 'fledermaus' | 'kroete' | 'irrlicht' | 'tentakel' | 'maschine' | 'drohne' | 'hund'
  | 'troll' | 'skelett' | 'mensch' | 'elementar' | 'kroko' | 'fisch' | 'hexe' | 'pilz' | 'motte' | 'vogel'
  | 'crawler' | 'haustier';

/** Welche Silhouette zu welcher Monsterart gehört. */
const BY_DEF: Record<string, SpriteKind> = {
  kellerratte: 'ratte', rattenmensch: 'ratte', rattenschamane: 'ratte', knochenratte: 'ratte', koenig_kanalratte: 'ratte', rattenkaiser: 'ratte',
  riesenkakerlake: 'kakerlake',
  kobold: 'kobold', kobold_schleuder: 'kobold', elster_goblin: 'kobold', kobold_bombe: 'kobold', schmuggler: 'kobold', wechselbalg: 'kobold',
  schleim: 'schleim', klaerschlamm: 'schleim', kommandant_schlamm: 'schleim',
  wolpertinger: 'hase',
  poltergeist: 'geist', nachtmahr: 'geist',
  grauer_spaeher: 'alien',
  muellsack_mimic: 'sack',
  tatzelwurm: 'wurm', neunauge: 'wurm',
  ghul: 'zombie', moorleiche: 'zombie',
  gnom_buerokrat: 'gnom', heinzelmann: 'gnom', gartenzwerg: 'gnom',
  kellerspinne: 'spinne',
  fledermaus: 'fledermaus',
  blaehkroete: 'kroete',
  irrlicht: 'irrlicht',
  abflusstentakel: 'tentakel',
  toaster_mimic: 'maschine', waschmaschine_mimic: 'maschine', muttis_mixer: 'maschine', heizungsbestie: 'maschine',
  grey_drohne: 'drohne',
  chupacabra: 'hund', ghulhund: 'hund',
  troll_lehrling: 'troll', schwarzmarkt_oger: 'troll',
  kellermeister: 'skelett',
  abtruenniger_crawler: 'crawler', morlock: 'zombie',
  wutelementar: 'elementar',
  kanalkroko: 'kroko',
  fischmensch: 'fisch', nixe: 'fisch', kanalkoenigin: 'fisch',
  kanalhexe: 'hexe', kesselkoenigin: 'hexe',
  pilzmensch: 'pilz',
  mottenmann: 'motte', mottenmutter: 'motte',
  taubenschwarm: 'vogel',
  die_sammlerin: 'mensch', der_hausmeister: 'mensch', kammerjaeger: 'mensch', pfandbaron: 'mensch', hausverwalter: 'mensch',
};

export function spriteFor(defId: string, rankGhost = false): SpriteKind {
  if (rankGhost) return 'geist';
  return BY_DEF[defId] ?? 'kobold';
}

const OUT = '#0a0a0e';

function shade(hex: string, f: number): string {
  const n = parseInt(hex.slice(1), 16);
  const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => Math.max(0, Math.min(255, Math.round(v * f))));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
}

interface Pal {
  body: string;
  dark: string;
  light: string;
}

function pal(color: string): Pal {
  const c = /^#[0-9a-f]{6}$/i.test(color) ? color : '#a39a8c';
  return { body: c, dark: shade(c, 0.55), light: shade(c, 1.35) };
}

/** Pfad füllen mit Verlauf (oben hell, unten dunkel) und dunkler Kontur. */
function fillShape(c: Ctx, p: Pal, build: () => void, outline = 4) {
  c.beginPath();
  build();
  const g = c.createLinearGradient(0, -45, 0, 45);
  g.addColorStop(0, p.light);
  g.addColorStop(0.55, p.body);
  g.addColorStop(1, p.dark);
  c.fillStyle = g;
  c.strokeStyle = OUT;
  c.lineWidth = outline;
  c.lineJoin = 'round';
  c.stroke();
  c.fill();
}

function ell(c: Ctx, x: number, y: number, rx: number, ry: number, rot = 0) {
  c.moveTo(x + rx * Math.cos(rot), y + rx * Math.sin(rot));
  c.ellipse(x, y, rx, ry, rot, 0, Math.PI * 2);
}

function eyes(c: Ctx, pts: [number, number][], r = 3.2, color = '#fff6c8') {
  for (const [x, y] of pts) {
    c.fillStyle = OUT;
    c.beginPath();
    c.arc(x, y, r + 1.4, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = color;
    c.beginPath();
    c.arc(x, y, r, 0, Math.PI * 2);
    c.fill();
  }
}

function strokeLine(c: Ctx, color: string, w: number, pts: [number, number][]) {
  c.strokeStyle = OUT;
  c.lineWidth = w + 3;
  c.lineCap = 'round';
  c.lineJoin = 'round';
  c.beginPath();
  pts.forEach(([x, y], i) => (i ? c.lineTo(x, y) : c.moveTo(x, y)));
  c.stroke();
  c.strokeStyle = color;
  c.lineWidth = w;
  c.stroke();
}

type Drawer = (c: Ctx, p: Pal, t: number) => void;

const DRAW: Record<SpriteKind, Drawer> = {
  ratte(c, p) {
    strokeLine(c, p.dark, 3, [[-20, 18], [-36, 10], [-44, -4], [-40, -14]]);
    fillShape(c, p, () => {
      ell(c, -4, 12, 24, 16);
      ell(c, 20, 2, 13, 11);
    });
    fillShape(c, p, () => {
      ell(c, 18, -10, 6, 7);
      ell(c, 27, -8, 5, 6);
    }, 3);
    c.fillStyle = '#ff9aa8';
    c.beginPath();
    c.arc(33, 4, 3, 0, Math.PI * 2);
    c.fill();
    eyes(c, [[24, -1]], 2.6, '#ff4040');
    strokeLine(c, p.dark, 2.5, [[-14, 26], [-14, 32]]);
    strokeLine(c, p.dark, 2.5, [[8, 26], [8, 32]]);
  },
  kakerlake(c, p) {
    for (const s of [-1, 1]) for (const k of [-12, 0, 12]) strokeLine(c, p.dark, 2.5, [[k, 0], [k + 6 * s, 18 * s], [k + 14 * s, 26 * s]]);
    fillShape(c, p, () => ell(c, 0, 0, 30, 17));
    fillShape(c, p, () => ell(c, 30, 0, 9, 9), 3);
    strokeLine(c, p.dark, 1.5, [[36, -4], [48, -20]]);
    strokeLine(c, p.dark, 1.5, [[36, 4], [48, 20]]);
    c.strokeStyle = 'rgba(0,0,0,0.4)';
    c.lineWidth = 2;
    c.beginPath();
    c.moveTo(-30, 0);
    c.lineTo(22, 0);
    c.stroke();
  },
  kobold(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-14, 40);
      c.lineTo(-16, 10);
      c.quadraticCurveTo(0, 2, 16, 10);
      c.lineTo(14, 40);
      c.closePath();
    });
    fillShape(c, p, () => {
      ell(c, 0, -10, 17, 16);
      c.moveTo(-15, -14);
      c.lineTo(-38, -26);
      c.lineTo(-14, -4);
      c.moveTo(15, -14);
      c.lineTo(38, -26);
      c.lineTo(14, -4);
    });
    eyes(c, [[-6, -12], [6, -12]], 3, '#ffe14a');
    c.strokeStyle = OUT;
    c.lineWidth = 2.5;
    c.beginPath();
    c.moveTo(-7, 0);
    c.quadraticCurveTo(0, 4, 7, 0);
    c.stroke();
  },
  schleim(c, p, t) {
    const wob = Math.sin(t / 300) * 2;
    fillShape(c, p, () => {
      c.moveTo(-36, 34);
      c.bezierCurveTo(-40, 0, -24, -30 - wob, 0, -30 - wob);
      c.bezierCurveTo(24, -30 - wob, 40, 0, 36, 34);
      c.quadraticCurveTo(0, 42, -36, 34);
    });
    c.fillStyle = 'rgba(255,255,255,0.35)';
    c.beginPath();
    c.ellipse(-14, -14, 7, 4, -0.6, 0, Math.PI * 2);
    c.fill();
    eyes(c, [[-9, 4], [9, 4]], 3.5, '#101010');
  },
  hase(c, p) {
    fillShape(c, p, () => {
      ell(c, -2, 18, 24, 18);
      ell(c, 16, -4, 13, 12);
      ell(c, 10, -26, 4, 12, -0.2);
      ell(c, 20, -26, 4, 12, 0.2);
    });
    strokeLine(c, '#d9c29a', 2.5, [[6, -34], [0, -46], [-6, -44]]);
    strokeLine(c, '#d9c29a', 2.5, [[24, -34], [30, -46], [36, -44]]);
    eyes(c, [[20, -6]], 2.6);
  },
  geist(c, p, t) {
    const f = Math.sin(t / 250) * 3;
    c.globalAlpha = 0.9;
    fillShape(c, p, () => {
      c.moveTo(-26, 30 + f);
      c.lineTo(-26, -8);
      c.bezierCurveTo(-26, -40, 26, -40, 26, -8);
      c.lineTo(26, 30 + f);
      c.lineTo(16, 22 + f);
      c.lineTo(8, 32 + f);
      c.lineTo(0, 22 + f);
      c.lineTo(-8, 32 + f);
      c.lineTo(-16, 22 + f);
      c.closePath();
    });
    c.globalAlpha = 1;
    eyes(c, [[-9, -10], [9, -10]], 4, '#101018');
    c.fillStyle = '#101018';
    c.beginPath();
    c.ellipse(0, 6, 5, 7, 0, 0, Math.PI * 2);
    c.fill();
  },
  alien(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-10, 40);
      c.lineTo(-8, 12);
      c.lineTo(8, 12);
      c.lineTo(10, 40);
      c.closePath();
    });
    fillShape(c, p, () => {
      c.moveTo(0, 16);
      c.bezierCurveTo(-30, 4, -30, -38, 0, -38);
      c.bezierCurveTo(30, -38, 30, 4, 0, 16);
    });
    c.fillStyle = OUT;
    c.beginPath();
    c.ellipse(-10, -12, 8, 5, 0.5, 0, Math.PI * 2);
    c.ellipse(10, -12, 8, 5, -0.5, 0, Math.PI * 2);
    c.fill();
  },
  sack(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-30, 36);
      c.bezierCurveTo(-40, 0, -24, -24, -8, -26);
      c.lineTo(-4, -36);
      c.lineTo(4, -36);
      c.lineTo(8, -26);
      c.bezierCurveTo(24, -24, 40, 0, 30, 36);
      c.closePath();
    });
    // Maul mit Zähnen
    c.fillStyle = OUT;
    c.beginPath();
    c.ellipse(0, 10, 18, 9, 0, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = '#f2ecd8';
    for (let x = -14; x <= 14; x += 7) {
      c.beginPath();
      c.moveTo(x - 3, 3);
      c.lineTo(x, 9);
      c.lineTo(x + 3, 3);
      c.fill();
    }
    eyes(c, [[-9, -10], [9, -10]], 3, '#ffe14a');
  },
  wurm(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-44, 26);
      c.bezierCurveTo(-30, -4, -10, 36, 6, 8);
      c.bezierCurveTo(14, -6, 20, -18, 30, -18);
      c.lineTo(34, -8);
      c.bezierCurveTo(24, -6, 22, 10, 12, 22);
      c.bezierCurveTo(-4, 42, -24, 14, -38, 34);
      c.closePath();
    });
    fillShape(c, p, () => ell(c, 34, -18, 13, 11), 3);
    eyes(c, [[38, -22]], 2.8, '#ffe14a');
    strokeLine(c, p.dark, 2.5, [[-6, 26], [-10, 36]]);
    strokeLine(c, p.dark, 2.5, [[14, 16], [16, 28]]);
  },
  zombie(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-15, 40);
      c.lineTo(-17, 2);
      c.quadraticCurveTo(0, -6, 17, 2);
      c.lineTo(15, 40);
      c.closePath();
    });
    strokeLine(c, p.body, 6, [[14, 6], [36, 4]]);
    strokeLine(c, p.body, 6, [[-14, 8], [24, 12]]);
    fillShape(c, p, () => ell(c, 2, -16, 14, 15));
    eyes(c, [[-3, -18], [8, -17]], 2.8, '#d8ff6a');
    c.strokeStyle = OUT;
    c.lineWidth = 2;
    c.beginPath();
    c.moveTo(-4, -6);
    c.lineTo(8, -7);
    c.stroke();
  },
  gnom(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-18, 40);
      c.lineTo(-14, 6);
      c.lineTo(14, 6);
      c.lineTo(18, 40);
      c.closePath();
    });
    fillShape(c, { body: '#f1c9a0', dark: '#b98a60', light: '#ffe3c8' }, () => ell(c, 0, -2, 12, 11));
    fillShape(c, { body: '#d23a32', dark: '#8a1c18', light: '#ff6a5a' }, () => {
      c.moveTo(-15, -6);
      c.lineTo(4, -44);
      c.lineTo(15, -6);
      c.closePath();
    });
    fillShape(c, { body: '#eeeeee', dark: '#aaaaaa', light: '#ffffff' }, () => {
      c.moveTo(-11, 2);
      c.quadraticCurveTo(0, 30, 11, 2);
      c.closePath();
    }, 3);
    eyes(c, [[-4, -3], [4, -3]], 2, '#101010');
  },
  spinne(c, p, t) {
    const w = Math.sin(t / 160) * 2;
    for (const s of [-1, 1]) {
      for (const [k, a] of [[-10, -1], [-3, -0.3], [4, 0.3], [11, 1]] as [number, number][]) {
        strokeLine(c, p.dark, 3, [[k * 0.6, 4], [s * 22 + k * 0.5, -16 + a * 8 + w], [s * 40 + k * 0.4, 20 + a * 6]]);
      }
    }
    fillShape(c, p, () => {
      ell(c, 0, 14, 20, 17);
      ell(c, 0, -10, 12, 10);
    });
    c.fillStyle = 'rgba(200,30,30,0.85)';
    c.beginPath();
    c.moveTo(0, 6);
    c.lineTo(5, 13);
    c.lineTo(0, 20);
    c.lineTo(-5, 13);
    c.fill();
    eyes(c, [[-5, -13], [5, -13], [-2, -8], [2, -8]], 2, '#ff3030');
  },
  fledermaus(c, p, t) {
    const flap = Math.sin(t / 120) * 8;
    fillShape(c, p, () => {
      c.moveTo(0, -4);
      c.bezierCurveTo(-18, -24 - flap, -38, -18 - flap, -48, -6 - flap);
      c.lineTo(-40, 2);
      c.lineTo(-32, -2);
      c.lineTo(-26, 8);
      c.lineTo(-16, 2);
      c.lineTo(-8, 12);
      c.lineTo(0, 8);
      c.lineTo(8, 12);
      c.lineTo(16, 2);
      c.lineTo(26, 8);
      c.lineTo(32, -2);
      c.lineTo(40, 2);
      c.lineTo(48, -6 - flap);
      c.bezierCurveTo(38, -18 - flap, 18, -24 - flap, 0, -4);
    });
    fillShape(c, p, () => {
      ell(c, 0, 0, 9, 12);
      c.moveTo(-7, -9);
      c.lineTo(-9, -20);
      c.lineTo(-2, -12);
      c.moveTo(7, -9);
      c.lineTo(9, -20);
      c.lineTo(2, -12);
    }, 3);
    eyes(c, [[-3.5, -3], [3.5, -3]], 2, '#ff4040');
  },
  kroete(c, p) {
    fillShape(c, p, () => {
      ell(c, 0, 14, 32, 22);
      ell(c, -14, -8, 9, 9);
      ell(c, 14, -8, 9, 9);
    });
    c.fillStyle = 'rgba(0,0,0,0.25)';
    for (const [x, y] of [[-14, 18], [8, 22], [16, 10], [-4, 8]]) {
      c.beginPath();
      c.arc(x, y, 3.5, 0, Math.PI * 2);
      c.fill();
    }
    eyes(c, [[-14, -9], [14, -9]], 4, '#ffd23a');
    c.strokeStyle = OUT;
    c.lineWidth = 2.5;
    c.beginPath();
    c.moveTo(-16, 6);
    c.quadraticCurveTo(0, 14, 16, 6);
    c.stroke();
  },
  irrlicht(c, p, t) {
    const r = 18 + Math.sin(t / 200) * 2;
    const g = c.createRadialGradient(0, 0, 2, 0, 0, 44);
    g.addColorStop(0, 'rgba(255,255,255,0.95)');
    g.addColorStop(0.3, p.light);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    c.fillStyle = g;
    c.beginPath();
    c.arc(0, 0, 44, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = '#ffffff';
    c.beginPath();
    c.arc(0, 0, r * 0.45, 0, Math.PI * 2);
    c.fill();
  },
  tentakel(c, p, t) {
    const w = Math.sin(t / 220) * 6;
    fillShape(c, { body: '#3a3f47', dark: '#1f2228', light: '#5a606a' }, () => ell(c, 0, 34, 30, 8), 3);
    fillShape(c, p, () => {
      c.moveTo(-12, 34);
      c.bezierCurveTo(-18, 0, 10 + w, -10, -2 + w, -38);
      c.bezierCurveTo(16 + w, -14, 8, 4, 12, 34);
      c.closePath();
    });
    c.fillStyle = 'rgba(255,220,230,0.6)';
    for (const y of [22, 8, -6]) {
      c.beginPath();
      c.arc(2 + w * (1 - (y + 10) / 40), y, 3, 0, Math.PI * 2);
      c.fill();
    }
  },
  maschine(c, p) {
    fillShape(c, p, () => {
      c.roundRect(-30, -30, 60, 62, 8);
    });
    c.fillStyle = OUT;
    c.beginPath();
    c.arc(0, 6, 17, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = 'rgba(150,200,255,0.35)';
    c.beginPath();
    c.arc(0, 6, 13, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = '#ffe14a';
    c.fillRect(-22, -24, 8, 5);
    c.fillStyle = '#ff5a4a';
    c.fillRect(-10, -24, 8, 5);
    eyes(c, [[-7, 4], [7, 4]], 3, '#ff3a3a');
    c.fillStyle = '#f2ecd8';
    for (let x = -9; x <= 9; x += 6) {
      c.beginPath();
      c.moveTo(x - 2.5, 12);
      c.lineTo(x, 17);
      c.lineTo(x + 2.5, 12);
      c.fill();
    }
  },
  drohne(c, p, t) {
    const spin = t / 40;
    for (const x of [-28, 28]) {
      strokeLine(c, p.dark, 3, [[x * 0.4, -2], [x, -10]]);
      c.strokeStyle = 'rgba(220,230,255,0.6)';
      c.lineWidth = 3;
      c.beginPath();
      c.moveTo(x - 14 * Math.cos(spin), -12);
      c.lineTo(x + 14 * Math.cos(spin), -12);
      c.stroke();
    }
    fillShape(c, p, () => c.roundRect(-18, -8, 36, 20, 8));
    eyes(c, [[0, 2]], 5, '#ff4040');
  },
  hund(c, p) {
    strokeLine(c, p.dark, 3.5, [[-28, 4], [-40, -12]]);
    fillShape(c, p, () => {
      ell(c, -6, 8, 26, 14);
      ell(c, 24, -8, 12, 11);
      c.moveTo(30, -4);
      c.lineTo(42, 0);
      c.lineTo(30, 4);
      c.moveTo(18, -16);
      c.lineTo(20, -30);
      c.lineTo(26, -17);
    });
    for (const x of [-22, -10, 6, 14]) strokeLine(c, p.dark, 4, [[x, 18], [x, 34]]);
    eyes(c, [[27, -10]], 2.6, '#ff4040');
  },
  troll(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-26, 40);
      c.lineTo(-30, 0);
      c.quadraticCurveTo(0, -18, 30, 0);
      c.lineTo(26, 40);
      c.closePath();
    });
    strokeLine(c, p.body, 9, [[-26, 4], [-38, 30]]);
    strokeLine(c, p.body, 9, [[26, 4], [38, 30]]);
    fillShape(c, p, () => ell(c, 0, -20, 15, 14));
    eyes(c, [[-6, -22], [6, -22]], 2.6, '#ffe14a');
    c.fillStyle = '#f2ecd8';
    c.beginPath();
    c.moveTo(-7, -12);
    c.lineTo(-5, -18);
    c.lineTo(-3, -12);
    c.moveTo(3, -12);
    c.lineTo(5, -18);
    c.lineTo(7, -12);
    c.fill();
  },
  skelett(c) {
    const bone: Pal = { body: '#e9e2cf', dark: '#a39a82', light: '#ffffff' };
    strokeLine(c, bone.body, 4, [[0, -4], [0, 26]]);
    for (const y of [2, 9, 16]) strokeLine(c, bone.body, 3, [[-12, y], [12, y]]);
    strokeLine(c, bone.body, 3.5, [[0, 26], [-10, 42]]);
    strokeLine(c, bone.body, 3.5, [[0, 26], [10, 42]]);
    strokeLine(c, bone.body, 3.5, [[-12, 2], [-22, 22]]);
    strokeLine(c, bone.body, 3.5, [[12, 2], [22, 22]]);
    fillShape(c, bone, () => ell(c, 0, -20, 14, 14));
    c.fillStyle = OUT;
    c.beginPath();
    c.arc(-5, -21, 4, 0, Math.PI * 2);
    c.arc(5, -21, 4, 0, Math.PI * 2);
    c.fill();
  },
  mensch(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-18, 40);
      c.lineTo(-20, 4);
      c.quadraticCurveTo(0, -6, 20, 4);
      c.lineTo(18, 40);
      c.closePath();
    });
    fillShape(c, { body: '#e8b890', dark: '#a87a58', light: '#ffd8b8' }, () => ell(c, 0, -16, 13, 14));
    fillShape(c, { body: '#4a3526', dark: '#2a1c12', light: '#6a4c36' }, () => {
      c.moveTo(-13, -18);
      c.bezierCurveTo(-14, -36, 14, -36, 13, -18);
      c.quadraticCurveTo(0, -24, -13, -18);
    }, 3);
    eyes(c, [[-5, -15], [5, -15]], 2, '#101010');
  },
  crawler(c, p) {
    DRAW.mensch(c, p, 0);
  },
  elementar(c, p, t) {
    const f = Math.sin(t / 120) * 4;
    fillShape(c, p, () => {
      c.moveTo(-26, 36);
      c.bezierCurveTo(-40, 6, -18, -6, -16, -24 + f);
      c.bezierCurveTo(-8, -14, -6, -34, 2, -44 - f);
      c.bezierCurveTo(8, -26, 20, -30, 20, -20 + f);
      c.bezierCurveTo(40, 0, 36, 20, 26, 36);
      c.closePath();
    });
    eyes(c, [[-8, 6], [8, 6]], 4, '#ffffff');
  },
  kroko(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-46, 12);
      c.quadraticCurveTo(-30, -6, -6, -8);
      c.lineTo(34, -10);
      c.lineTo(46, -2);
      c.lineTo(34, 6);
      c.lineTo(-6, 16);
      c.quadraticCurveTo(-30, 22, -46, 12);
    });
    c.fillStyle = '#f2ecd8';
    for (let x = 10; x <= 36; x += 6) {
      c.beginPath();
      c.moveTo(x, -2);
      c.lineTo(x + 2, 3);
      c.lineTo(x + 4, -2);
      c.fill();
    }
    for (const x of [-22, -4]) strokeLine(c, p.dark, 5, [[x, 14], [x - 4, 28]]);
    eyes(c, [[14, -12]], 2.8, '#ffe14a');
  },
  fisch(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-14, 40);
      c.lineTo(-16, 2);
      c.quadraticCurveTo(0, -6, 16, 2);
      c.lineTo(14, 40);
      c.closePath();
    });
    fillShape(c, p, () => {
      ell(c, 0, -16, 16, 13);
      c.moveTo(-6, -28);
      c.lineTo(0, -42);
      c.lineTo(6, -28);
    });
    eyes(c, [[-8, -18], [8, -18]], 4, '#e0ff8a');
    c.strokeStyle = OUT;
    c.lineWidth = 2.5;
    c.beginPath();
    c.moveTo(-8, -7);
    c.lineTo(8, -7);
    c.stroke();
  },
  hexe(c, p) {
    fillShape(c, p, () => {
      c.moveTo(-24, 40);
      c.lineTo(-10, 0);
      c.lineTo(10, 0);
      c.lineTo(24, 40);
      c.closePath();
    });
    fillShape(c, { body: '#9ac27a', dark: '#5a7a44', light: '#c2e2a2' }, () => ell(c, 0, -10, 11, 12));
    fillShape(c, { body: '#2a2238', dark: '#15101c', light: '#463a5c' }, () => {
      c.moveTo(-24, -16);
      c.lineTo(24, -16);
      c.lineTo(6, -20);
      c.lineTo(10, -46);
      c.lineTo(-8, -20);
      c.closePath();
    }, 3);
    eyes(c, [[-4, -10], [4, -10]], 2, '#ffe14a');
  },
  pilz(c, p) {
    fillShape(c, { body: '#e8dcc0', dark: '#a89c80', light: '#fff4dc' }, () => {
      c.moveTo(-12, 40);
      c.lineTo(-10, -4);
      c.lineTo(10, -4);
      c.lineTo(12, 40);
      c.closePath();
    });
    fillShape(c, p, () => {
      c.moveTo(-38, 0);
      c.bezierCurveTo(-36, -40, 36, -40, 38, 0);
      c.quadraticCurveTo(0, 8, -38, 0);
    });
    c.fillStyle = 'rgba(255,255,255,0.75)';
    for (const [x, y, r] of [[-18, -14, 5], [6, -22, 6], [22, -8, 4]]) {
      c.beginPath();
      c.arc(x, y, r, 0, Math.PI * 2);
      c.fill();
    }
    eyes(c, [[-5, 12], [5, 12]], 2.4, '#101010');
  },
  motte(c, p, t) {
    const flap = Math.sin(t / 150) * 5;
    fillShape(c, p, () => {
      c.moveTo(0, -4);
      c.bezierCurveTo(-24, -40 - flap, -48, -20 - flap, -34, 6);
      c.bezierCurveTo(-30, 20, -10, 20, 0, 6);
      c.bezierCurveTo(10, 20, 30, 20, 34, 6);
      c.bezierCurveTo(48, -20 - flap, 24, -40 - flap, 0, -4);
    });
    c.fillStyle = 'rgba(0,0,0,0.3)';
    c.beginPath();
    c.arc(-22, -12, 6, 0, Math.PI * 2);
    c.arc(22, -12, 6, 0, Math.PI * 2);
    c.fill();
    fillShape(c, { body: '#3a3034', dark: '#1a1416', light: '#5a4a50' }, () => ell(c, 0, 4, 7, 20), 3);
    eyes(c, [[-3, -12], [3, -12]], 2.4, '#ff3030');
  },
  vogel(c, p) {
    fillShape(c, p, () => {
      ell(c, -2, 10, 22, 16);
      ell(c, 18, -8, 11, 10);
      c.moveTo(-20, 6);
      c.lineTo(-40, 0);
      c.lineTo(-20, 16);
    });
    fillShape(c, { body: '#e6a23a', dark: '#9a661a', light: '#ffc86a' }, () => {
      c.moveTo(27, -9);
      c.lineTo(38, -5);
      c.lineTo(27, -3);
      c.closePath();
    }, 2.5);
    c.fillStyle = 'rgba(120,200,160,0.5)';
    c.beginPath();
    c.ellipse(12, 2, 7, 4, 0, 0, Math.PI * 2);
    c.fill();
    eyes(c, [[20, -10]], 2.4, '#ff7a3a');
    strokeLine(c, '#e6a23a', 2.5, [[-4, 24], [-6, 34]]);
    strokeLine(c, '#e6a23a', 2.5, [[6, 24], [6, 34]]);
  },
  haustier(c, p) {
    // Kleine Katze/Hund-Silhouette
    strokeLine(c, p.dark, 3.5, [[-22, 10], [-34, -6]]);
    fillShape(c, p, () => {
      ell(c, -4, 14, 20, 12);
      ell(c, 18, -2, 12, 11);
      c.moveTo(10, -10);
      c.lineTo(12, -24);
      c.lineTo(18, -12);
      c.moveTo(20, -12);
      c.lineTo(28, -22);
      c.lineTo(28, -8);
    });
    eyes(c, [[15, -3], [23, -3]], 2.2, '#9fffb0');
  },
};

export interface SpriteOpts {
  /** Zeit in ms für kleine Animationen (Flügel, Wabern). */
  time?: number;
  /** Nach links schauen. */
  flip?: boolean;
  /** Krone für Bosse. */
  crown?: boolean;
  /** Unbekannt: echte Gestalt, aber mit Fragezeichen-Marke. */
  unknown?: boolean;
}

/**
 * Zeichnet eine Kreatur mittig bei (cx, cy) mit der Kantenlänge `size`.
 */
export function drawSprite(ctx: Ctx, kind: SpriteKind, color: string, cx: number, cy: number, size: number, opts: SpriteOpts = {}) {
  ctx.save();
  ctx.translate(cx, cy);
  const s = size / 100;
  ctx.scale(opts.flip ? -s : s, s);
  DRAW[kind](ctx, pal(color), opts.time ?? 0);
  if (opts.unknown) {
    // Die Gestalt siehst du, nur was es genau ist, weißt du nicht: kleines Fragezeichen als Marke
    ctx.scale(opts.flip ? -1 : 1, 1);
    ctx.beginPath();
    ctx.arc(30, -34, 13, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(20, 20, 26, 0.92)';
    ctx.fill();
    ctx.lineWidth = 3;
    ctx.strokeStyle = '#e8e2d4';
    ctx.stroke();
    ctx.font = '800 19px Montserrat, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#e8e2d4';
    ctx.fillText('?', 30, -33);
    ctx.scale(opts.flip ? -1 : 1, 1);
  }
  if (opts.crown) {
    ctx.scale(opts.flip ? -1 : 1, 1);
    ctx.fillStyle = '#ffcc33';
    ctx.strokeStyle = OUT;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(-16, -38);
    ctx.lineTo(-16, -50);
    ctx.lineTo(-8, -43);
    ctx.lineTo(0, -54);
    ctx.lineTo(8, -43);
    ctx.lineTo(16, -50);
    ctx.lineTo(16, -38);
    ctx.closePath();
    ctx.stroke();
    ctx.fill();
  }
  ctx.restore();
}

/** Die Spielfigur: ein Mensch mit leuchtendem Rand, damit man sich sofort findet. */
export function drawHero(ctx: Ctx, cx: number, cy: number, size: number, flip = false) {
  ctx.save();
  ctx.translate(cx, cy);
  const s = size / 100;
  ctx.scale(flip ? -s : s, s);
  const coat: Pal = { body: '#d9a634', dark: '#8a6414', light: '#ffd873' };
  fillShape(ctx, coat, () => {
    ctx.moveTo(-18, 40);
    ctx.lineTo(-21, 4);
    ctx.quadraticCurveTo(0, -6, 21, 4);
    ctx.lineTo(18, 40);
    ctx.closePath();
  });
  strokeLine(ctx, '#b88a24', 6, [[20, 8], [30, 24]]);
  strokeLine(ctx, '#b88a24', 6, [[-20, 8], [-30, 24]]);
  fillShape(ctx, { body: '#f0c49a', dark: '#b08660', light: '#ffe0c0' }, () => ell(ctx, 0, -16, 13, 14));
  fillShape(ctx, { body: '#5a3a22', dark: '#2e1c0e', light: '#7a5434' }, () => {
    ctx.moveTo(-13, -18);
    ctx.bezierCurveTo(-15, -38, 15, -38, 13, -18);
    ctx.quadraticCurveTo(4, -26, -13, -18);
  }, 3);
  eyes(ctx, [[-5, -15], [5, -15]], 2, '#101010');
  ctx.restore();
}
