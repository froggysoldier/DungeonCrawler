export function esc(v: unknown): string {
  return String(v)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function $(sel: string, root: ParentNode = document): HTMLElement {
  const el = root.querySelector(sel);
  if (!el) throw new Error(`Element fehlt: ${sel}`);
  return el as HTMLElement;
}

/** Hängt Klick-Handler an alle Elemente mit data-action. */
export function bindActions(root: HTMLElement, handlers: Record<string, (el: HTMLElement) => void>) {
  root.querySelectorAll<HTMLElement>('[data-action]').forEach((el) => {
    const fn = handlers[el.dataset.action!];
    if (fn) el.addEventListener('click', (e) => {
      e.preventDefault();
      fn(el);
    });
  });
}

export function formatTime(turns: number): string {
  const minutes = turns * 3;
  const d = Math.floor(minutes / 1440);
  const h = Math.floor((minutes % 1440) / 60);
  const m = minutes % 60;
  const hh = String(h).padStart(2, '0');
  const mm = String(m).padStart(2, '0');
  return d > 0 ? `${d} T ${hh}:${mm}` : `${hh}:${mm}`;
}
