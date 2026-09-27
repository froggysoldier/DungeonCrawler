import { newGame } from './engine/game';
import { loadMeta, loadRun, recordRunEnd, saveRun } from './engine/meta';
import type { GameState, MetaState } from './engine/types';
import { GameView } from './ui/gameview';
import { confirmBox } from './ui/modal';
import { endScreen, interviewScreen, titleScreen } from './ui/screens';

const root = document.getElementById('app')!;
let meta: MetaState = loadMeta();
let view: GameView | null = null;

function clear() {
  view?.destroy();
  view = null;
  document.getElementById('toasts')!.innerHTML = '';
}

function showTitle() {
  clear();
  meta = loadMeta();
  const save = loadRun();
  titleScreen(root, meta, !!save, {
    newGame: async () => {
      if (save) {
        const ok = await confirmBox(
          'Neue Staffel?',
          'Dein laufender Crawl wird als gescheitert gewertet (Hardcore!). Wirklich neu beginnen?',
          'Ja, neue Staffel',
        );
        if (!ok) return;
        save.status = 'dead';
        save.deathCause = 'hat die Show verlassen';
        meta = recordRunEnd(meta, save);
      }
      showInterview();
    },
    continueGame: () => save && startGame(save),
  });
}

function showInterview() {
  clear();
  interviewScreen(root, (r) => {
    const s = newGame({ name: r.name, answers: r.answers, petName: r.petName, meta });
    saveRun(s);
    startGame(s);
  });
}

function startGame(s: GameState) {
  clear();
  view = new GameView(root, s, meta, (ended) => {
    meta = recordRunEnd(meta, ended);
    clear();
    endScreen(root, ended, meta, showInterview, showTitle);
  });
  if (import.meta.env.DEV) (window as unknown as { __dc: () => GameState | undefined }).__dc = () => view?.state;
  if (import.meta.env.DEV) (window as unknown as { __dcv: () => unknown }).__dcv = () => view;
  // Offene Dialoge (z. B. Intro) direkt anzeigen
  view.flushDialogs();
}

showTitle();
