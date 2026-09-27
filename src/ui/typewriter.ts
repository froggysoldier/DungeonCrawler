import { typeClick } from './sound';

/**
 * Schreibmaschinen-Effekt: Text erscheint Zeichen für Zeichen, als würde ihn
 * jemand tippen, mit weichem Tastenklicken. Ein Klick (oder `finish()`) zeigt
 * sofort den ganzen Text.
 */
export interface Typing {
  finish: () => void;
  done: Promise<void>;
  isDone: () => boolean;
}

const reducedMotion = () => typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

/** Wie laut und wie oft es beim Tippen klickt. `stumm` für ganz leise Stellen. */
export type TypeSound = 'dialog' | 'log' | 'stumm';

const CLICK: Record<Exclude<TypeSound, 'stumm'>, { gap: number; loud: number }> = {
  dialog: { gap: 46, loud: 1 },
  log: { gap: 72, loud: 0.55 },
};

/** Gemeinsame Drossel: mehrere Texte gleichzeitig klicken nicht doppelt. */
let lastClick = 0;

function clickFor(token: string, sound: TypeSound) {
  if (sound === 'stumm' || token.startsWith('<')) return;
  const cfg = CLICK[sound];
  const now = performance.now();
  // Leicht unregelmäßiger Takt, wie bei echtem Tippen
  if (now - lastClick < cfg.gap * (0.85 + Math.random() * 0.3)) return;
  lastClick = now;
  typeClick(token === ' ' ? 'leer' : 'taste', cfg.loud);
}

export function typeText(el: HTMLElement, html: string, msPerChar = 18, sound: TypeSound = 'dialog'): Typing {
  // HTML-Tags (z. B. <em>) werden in einem Schritt eingefügt, Text zeichenweise.
  const tokens = html.match(/<[^>]+>|&[^;]+;|[^<&]/g) ?? [];
  let i = 0;
  let finished = false;
  let resolveDone!: () => void;
  const done = new Promise<void>((r) => (resolveDone = r));
  const complete = () => {
    if (finished) return;
    finished = true;
    el.innerHTML = html;
    resolveDone();
  };
  if (reducedMotion() || msPerChar <= 0) {
    complete();
    return { finish: complete, done, isDone: () => true };
  }
  el.innerHTML = '';
  let shown = '';
  const tick = () => {
    if (finished) return;
    // Pro Tick mehrere Zeichen, damit lange Texte nicht ewig dauern
    for (let n = 0; n < 2 && i < tokens.length; n++) {
      const tok = tokens[i++];
      shown += tok;
      clickFor(tok, sound);
    }
    el.innerHTML = shown + '<span class="caret"></span>';
    if (i >= tokens.length) complete();
    else setTimeout(tick, msPerChar);
  };
  tick();
  return { finish: complete, done, isDone: () => finished };
}

/** Warteschlange für mehrere Zeilen (z. B. das Log): Zeile für Zeile tippen. */
export class TypeQueue {
  private queue: { el: HTMLElement; html: string }[] = [];
  private current: Typing | null = null;

  constructor(private msPerChar = 8, private onStep?: () => void, private sound: TypeSound = 'log') {}

  push(el: HTMLElement, html: string) {
    this.queue.push({ el, html });
    // Bei vielen wartenden Zeilen die älteren sofort zeigen, damit das Spiel nicht hinterherhinkt
    while (this.queue.length > 6) {
      const old = this.queue.shift()!;
      old.el.parentElement?.classList.remove('pending');
      old.el.innerHTML = old.html;
    }
    if (!this.current) this.next();
  }

  finishAll() {
    this.current?.finish();
    for (const q of this.queue) {
      q.el.parentElement?.classList.remove('pending');
      q.el.innerHTML = q.html;
    }
    this.queue = [];
  }

  private next() {
    const item = this.queue.shift();
    if (!item) {
      this.current = null;
      return;
    }
    item.el.parentElement?.classList.remove('pending');
    this.current = typeText(item.el, item.html, this.msPerChar, this.sound);
    const step = setInterval(() => this.onStep?.(), 60);
    this.current.done.then(() => {
      clearInterval(step);
      this.onStep?.();
      this.next();
    });
  }
}
