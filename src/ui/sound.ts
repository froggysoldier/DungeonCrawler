import type { BoxTier, Sfx } from '../engine/types';

/**
 * Klänge, direkt im Browser erzeugt (Web Audio, keine Audiodateien):
 * Lootbox öffnen, Level-Aufstieg, Achievement, neuer Skill.
 * Ein- und ausschaltbar; die Einstellung merkt sich der Browser.
 */
const KEY = 'grosser-abstieg-ton';
let ctx: AudioContext | null = null;
let master: GainNode | null = null;

function stored(): boolean {
  try {
    return localStorage.getItem(KEY) !== 'aus';
  } catch {
    return true;
  }
}

let enabled = stored();

export function soundEnabled(): boolean {
  return enabled;
}

export function setSoundEnabled(on: boolean) {
  enabled = on;
  try {
    localStorage.setItem(KEY, on ? 'an' : 'aus');
  } catch {
    // Speicher nicht verfügbar – dann eben nur für diese Sitzung
  }
}

function audio(): { ac: AudioContext; out: GainNode } | null {
  if (!enabled) return null;
  try {
    if (!ctx) {
      const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
      master = ctx.createGain();
      master.gain.value = 0.35;
      // Ein wenig Hall über eine kurze Rückkopplung
      const delay = ctx.createDelay();
      delay.delayTime.value = 0.11;
      const fb = ctx.createGain();
      fb.gain.value = 0.25;
      master.connect(ctx.destination);
      master.connect(delay);
      delay.connect(fb);
      fb.connect(delay);
      delay.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') void ctx.resume();
    return { ac: ctx, out: master! };
  } catch {
    return null;
  }
}

/** Ein Ton mit Hüllkurve. */
function tone(freq: number, start: number, dur: number, type: OscillatorType, vol: number, glideTo?: number) {
  const a = audio();
  if (!a) return;
  const { ac, out } = a;
  const t0 = ac.currentTime + start;
  const osc = ac.createOscillator();
  const g = ac.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t0);
  if (glideTo) osc.frequency.exponentialRampToValueAtTime(glideTo, t0 + dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(vol, t0 + 0.012);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  osc.connect(g);
  g.connect(out);
  osc.start(t0);
  osc.stop(t0 + dur + 0.05);
}

/** Glocke: Grundton plus unharmonische Obertöne, langes Ausklingen. */
function bell(freq: number, start: number, vol = 0.3, dur = 1.4) {
  tone(freq, start, dur, 'sine', vol);
  tone(freq * 2.01, start, dur * 0.7, 'sine', vol * 0.45);
  tone(freq * 3.02, start, dur * 0.4, 'sine', vol * 0.2);
  tone(freq * 4.2, start, dur * 0.25, 'triangle', vol * 0.08);
}

/** Rauschen (z. B. knarzender Deckel). */
function noise(start: number, dur: number, vol: number, from: number, to: number) {
  const a = audio();
  if (!a) return;
  const { ac, out } = a;
  const t0 = ac.currentTime + start;
  const len = Math.max(1, Math.floor(ac.sampleRate * dur));
  const buf = ac.createBuffer(1, len, ac.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const src = ac.createBufferSource();
  src.buffer = buf;
  const filter = ac.createBiquadFilter();
  filter.type = 'bandpass';
  filter.Q.value = 6;
  filter.frequency.setValueAtTime(from, t0);
  filter.frequency.exponentialRampToValueAtTime(to, t0 + dur);
  const g = ac.createGain();
  g.gain.setValueAtTime(vol, t0);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  src.connect(filter);
  filter.connect(g);
  g.connect(out);
  src.start(t0);
}

const TIER_RANK: Record<BoxTier, number> = { bronze: 0, silber: 1, gold: 2, platin: 3, legendaer: 4, himmlisch: 5 };
const note = (semi: number) => 523.25 * Math.pow(2, semi / 12); // relativ zu C5

function playBox(tier: BoxTier = 'bronze') {
  const r = TIER_RANK[tier] ?? 0;
  // Deckel knarzt auf, dann ein „Plopp“
  noise(0, 0.35, 0.25, 300, 1200);
  tone(180, 0.3, 0.12, 'sine', 0.35, 90);
  // Glitzern: je besser die Box, desto länger und höher
  const scale = [0, 4, 7, 12, 16, 19, 24, 28];
  const n = 3 + r;
  for (let i = 0; i < n; i++) tone(note(scale[i % scale.length] + 12), 0.42 + i * 0.07, 0.35, 'triangle', 0.16);
  if (r >= 2) bell(note(24), 0.42 + n * 0.07, 0.18, 1.6);
  if (r >= 4) {
    for (const s of [0, 4, 7, 12]) tone(note(s), 0.5 + n * 0.07, 1.4, 'sawtooth', 0.04);
  }
}

function playLevelUp() {
  const seq = [0, 4, 7, 12];
  seq.forEach((s, i) => {
    tone(note(s), i * 0.11, 0.22, 'square', 0.09);
    tone(note(s + 12), i * 0.11, 0.18, 'triangle', 0.06);
  });
  // Schlussakkord
  for (const s of [0, 4, 7, 12, 16]) tone(note(s), 0.46, 1.1, 'sawtooth', 0.035);
  bell(note(24), 0.46, 0.2, 1.3);
}

function playAchievement(tier: BoxTier = 'bronze') {
  const r = TIER_RANK[tier] ?? 0;
  bell(note(7), 0, 0.28);
  bell(note(12 + (r >= 2 ? 4 : 0)), 0.16, 0.26);
  if (r >= 2) bell(note(19), 0.32, 0.2);
  for (let i = 0; i < 5; i++) tone(note(24 + i * 2), 0.2 + i * 0.04, 0.2, 'sine', 0.05);
}

function playSkill() {
  bell(note(12), 0, 0.18, 0.9);
  tone(note(19), 0.08, 0.5, 'sine', 0.08);
}

export function playSfx(list: Sfx[]) {
  if (!enabled || !list.length) return;
  // Mehrere gleichzeitige Klänge nicht übereinanderstapeln: der wichtigste zählt
  const order: Sfx['kind'][] = ['levelup', 'box', 'achievement', 'skill'];
  const best = [...list].sort((a, b) => order.indexOf(a.kind) - order.indexOf(b.kind))[0];
  switch (best.kind) {
    case 'box':
      playBox(best.tier);
      break;
    case 'levelup':
      playLevelUp();
      break;
    case 'achievement':
      playAchievement(best.tier);
      break;
    case 'skill':
      playSkill();
      break;
  }
}
