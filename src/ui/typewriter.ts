/**
 * Schreibmaschinen-Effekt: Text erscheint Zeichen für Zeichen, als würde ihn
 * jemand tippen. Ein Klick (oder `finish()`) zeigt sofort den ganzen Text.
 */
export interface Typing {
  finish: () => void;
  done: Promise<void>;
  isDone: () => boolean;
}

const reducedMotion = () => typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;

export function typeText(el: HTMLElement, html: string, msPerChar = 18): Typing {
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
    for (let n = 0; n < 2 && i < tokens.length; n++) shown += tokens[i++];
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

  constructor(private msPerChar = 8, private onStep?: () => void) {}

  push(el: HTMLElement, html: string) {
    this.queue.push({ el, html });
    // Bei vielen wartenden Zeilen die älteren sofort zeigen, damit das Spiel nicht hinterherhinkt
    while (this.queue.length > 6) {
      const old = this.queue.shift()!;
      old.el.innerHTML = old.html;
    }
    if (!this.current) this.next();
  }

  finishAll() {
    this.current?.finish();
    for (const q of this.queue) q.el.innerHTML = q.html;
    this.queue = [];
  }

  private next() {
    const item = this.queue.shift();
    if (!item) {
      this.current = null;
      return;
    }
    this.current = typeText(item.el, item.html, this.msPerChar);
    const step = setInterval(() => this.onStep?.(), 60);
    this.current.done.then(() => {
      clearInterval(step);
      this.onStep?.();
      this.next();
    });
  }
}
