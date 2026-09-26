import { esc } from './dom';

let open = false;
const queue: (() => void)[] = [];

export const isModalOpen = () => open;

export function showCustom(html: string, onMount: (root: HTMLElement, close: () => void) => void): Promise<void> {
  return new Promise((resolve) => {
    const run = () => {
      open = true;
      const root = document.getElementById('modal-root')!;
      root.innerHTML = `<div class="modal-back"><div class="modal">${html}</div></div>`;
      const close = () => {
        root.innerHTML = '';
        open = false;
        resolve();
        const next = queue.shift();
        if (next) next();
      };
      onMount(root, close);
    };
    if (open) queue.push(run);
    else run();
  });
}

/** Mehrseitiger Dialog (Systemstimme, Guide …). */
export function showDialog(title: string, speaker: string | undefined, pages: string[]): Promise<void> {
  let page = 0;
  return showCustom(
    `<h2>${esc(title)}</h2>${speaker ? `<div class="speaker">${esc(speaker)}</div>` : ''}
     <div class="page"></div>
     <div class="foot"><span class="muted small pageno"></span><button class="primary next">Weiter</button></div>`,
    (root, close) => {
      const pageEl = root.querySelector('.page') as HTMLElement;
      const no = root.querySelector('.pageno') as HTMLElement;
      const btn = root.querySelector('.next') as HTMLButtonElement;
      const draw = () => {
        pageEl.innerHTML = esc(pages[page]).replace(/\*(.+?)\*/g, '<em>$1</em>');
        no.textContent = `${page + 1} / ${pages.length}`;
        btn.textContent = page === pages.length - 1 ? 'Los geht’s' : 'Weiter';
      };
      const advance = () => {
        if (page < pages.length - 1) {
          page += 1;
          draw();
        } else {
          document.removeEventListener('keydown', onKey);
          close();
        }
      };
      const onKey = (e: KeyboardEvent) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          advance();
        }
      };
      document.addEventListener('keydown', onKey);
      btn.addEventListener('click', advance);
      btn.focus();
      draw();
    },
  );
}

/** Freier HTML-Inhalt mit Schließen-Knopf. */
export function showHtml(title: string, html: string, button = 'Schließen'): Promise<void> {
  return showCustom(
    `<h2>${esc(title)}</h2>${html}<div class="foot"><span></span><button class="primary ok">${esc(button)}</button></div>`,
    (root, close) => {
      const btn = root.querySelector('.ok') as HTMLButtonElement;
      const onKey = (e: KeyboardEvent) => {
        if (e.key === 'Enter' || e.key === 'Escape') {
          e.preventDefault();
          done();
        }
      };
      const done = () => {
        document.removeEventListener('keydown', onKey);
        close();
      };
      document.addEventListener('keydown', onKey);
      btn.addEventListener('click', done);
      btn.focus();
    },
  );
}

export function confirmBox(title: string, text: string, yes: string, no = 'Abbrechen'): Promise<boolean> {
  let result = false;
  return showCustom(
    `<h2>${esc(title)}</h2><div class="page">${esc(text)}</div>
     <div class="foot"><button class="cancel">${esc(no)}</button><button class="primary ok">${esc(yes)}</button></div>`,
    (root, close) => {
      root.querySelector('.ok')!.addEventListener('click', () => {
        result = true;
        close();
      });
      root.querySelector('.cancel')!.addEventListener('click', close);
      (root.querySelector('.ok') as HTMLButtonElement).focus();
    },
  ).then(() => result);
}

export function showToast(title: string, text: string, kind: string) {
  const root = document.getElementById('toasts')!;
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.innerHTML = `<div class="tt">${esc(title)}</div><div class="tx">${esc(text)}</div>`;
  root.appendChild(el);
  setTimeout(() => {
    el.style.transition = 'opacity 0.5s';
    el.style.opacity = '0';
    setTimeout(() => el.remove(), 500);
  }, 5000);
  while (root.children.length > 5) root.firstChild?.remove();
}
