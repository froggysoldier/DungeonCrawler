import { ACHIEVEMENTS } from '../data/achievements';
import { INTERVIEW } from '../data/interview';
import { DEATH_QUIPS, SHOW_NAME } from '../data/world';
import type { GameState, MetaState } from '../engine/types';
import { bindActions, esc } from './dom';
import { typeText } from './typewriter';

/** Tippt das Zitat der Systemstimme; Antworten erscheinen erst danach. */
function typeQuote(root: HTMLElement) {
  const q = root.querySelector<HTMLElement>('.systemquote');
  if (!q) return;
  const rest = [...root.querySelectorAll<HTMLElement>('.answers, .row, input')];
  for (const el of rest) el.style.visibility = 'hidden';
  const t = typeText(q, q.innerHTML, 20);
  q.addEventListener('click', () => t.finish());
  t.done.then(() => {
    for (const el of rest) el.style.visibility = '';
    root.querySelector<HTMLElement>('input, .answers button, .row button.primary')?.focus();
  });
}

export interface InterviewResult {
  name: string;
  answers: number[];
  petName?: string;
}

function hallOfFame(meta: MetaState): string {
  if (!meta.hallOfFame.length) return '<p class="muted">Noch keine Staffeln gespielt.</p>';
  const rows = [...meta.hallOfFame]
    .reverse()
    .slice(0, 12)
    .map((h) => {
      const icon = h.outcome === 'ueberlebt' ? 'Überlebt' : h.outcome === 'vertrag' ? 'Vertrag' : 'Tot';
      return `<tr><td>${h.season}</td><td>${esc(h.name)}</td><td>${esc(h.background)}</td><td>Lv ${h.level}</td><td>E${h.floor}</td><td>${h.kills}</td><td>${h.achievements}</td><td>${icon}</td><td class="muted">${esc(h.cause)}</td></tr>`;
    })
    .join('');
  return `<table class="hof"><tr><th>#</th><th>Crawler</th><th>Vorher</th><th>Level</th><th>Etage</th><th>Kills</th><th>Erfolge</th><th>Ausgang</th><th>Ende</th></tr>${rows}</table>`;
}

export function titleScreen(
  root: HTMLElement,
  meta: MetaState,
  hasSave: boolean,
  on: { newGame: () => void; continueGame: () => void },
) {
  const ghosts = meta.ghosts.length;
  const guide = meta.guides[meta.guides.length - 1];
  root.innerHTML = `
    <div class="screen"><div class="card stack">
      <div class="title-logo">${esc(SHOW_NAME)}</div>
      <div class="subtitle">Ein textbasierter Dungeon-Crawl. 18 Etagen. Eine Galaxis schaut zu. Du hast einen Bademantel. Vielleicht.</div>
      <div class="row" style="margin-top:12px">
        ${hasSave ? '<button class="primary" data-action="continue">Staffel fortsetzen</button>' : ''}
        <button class="${hasSave ? '' : 'primary'}" data-action="new">Neue Staffel starten</button>
      </div>
      ${hasSave ? '<p class="muted small">Achtung: Eine neue Staffel beendet den laufenden Crawl endgültig.</p>' : ''}
      <div class="section">Karriere</div>
      <div class="muted">Staffeln gespielt: <b>${meta.season}</b> · Achievements jemals: <b>${meta.achievementsEver.length}/${ACHIEVEMENTS.length}</b>
      · Geister im Dungeon: <b>${ghosts}</b>${guide ? ` · Aktueller Guide: <b>${esc(guide.name)}</b>` : ''}</div>
      <div class="section">Hall of Fame</div>
      ${hallOfFame(meta)}
      <div class="section">So funktioniert’s</div>
      <ul class="muted small" style="margin:0;padding-left:18px;line-height:1.6">
        <li>Klick auf die Karte, um dich zu bewegen. Klick auf Gegner, um mit der gewählten Technik anzugreifen.</li>
        <li>Rundenbasiert: Jede Aktion kostet einen Zug (3 Minuten Spielzeit). Die Etage stürzt nach 5 Tagen ein.</li>
        <li>Wie du kämpfst, bestimmt deine Skills. Tritt viel – werde gut im Treten.</li>
        <li>Hardcore: Tod ist endgültig. Dein Geist bleibt aber im Dungeon zurück…</li>
      </ul>
    </div></div>`;
  bindActions(root, { new: on.newGame, continue: on.continueGame });
}

export function interviewScreen(root: HTMLElement, onDone: (r: InterviewResult) => void) {
  const answers: number[] = [];
  let name = '';
  let petName = '';
  let step = -1;

  const draw = () => {
    if (step === -1) {
      root.innerHTML = `
        <div class="screen"><div class="card stack">
          <div class="systemquote">„Hallo! Hier spricht die Systemstimme. Bevor du in den Dungeon darfst, müssen wir ein paar Formalitäten klären. Wie heißt du?“</div>
          <input id="name" maxlength="24" placeholder="Dein Name" value="${esc(name)}" autofocus />
          <div class="row"><button class="primary" data-action="next">Weiter</button></div>
        </div></div>`;
      const input = root.querySelector('#name') as HTMLInputElement;
      input.focus();
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') go();
      });
      const go = () => {
        name = input.value.trim() || 'Namenlos';
        step = 0;
        draw();
      };
      bindActions(root, { next: go });
      typeQuote(root);
      return;
    }
    if (step < INTERVIEW.length) {
      const q = INTERVIEW[step];
      root.innerHTML = `
        <div class="screen"><div class="card stack">
          <div class="muted small">Frage ${step + 1} von ${INTERVIEW.length} · Crawler ${esc(name)}</div>
          <div class="systemquote">„${esc(q.question)}“</div>
          <div class="answers">${q.answers.map((a, i) => `<button data-action="answer" data-i="${i}">${esc(a.label)}</button>`).join('')}</div>
        </div></div>`;
      typeQuote(root);
      bindActions(root, {
        answer: (el) => {
          const i = Number(el.dataset.i);
          answers[step] = i;
          const a = q.answers[i];
          if (a.pet) {
            askPetName(a.pet.species, a.pet.defaultName, a.reaction);
            return;
          }
          showReaction(a.reaction);
        },
      });
      return;
    }
    // Zusammenfassung
    const lines = INTERVIEW.map((q, i) => `<li>${esc(q.answers[answers[i]].label)}</li>`).join('');
    root.innerHTML = `
      <div class="screen"><div class="card stack">
        <div class="systemquote">„Wunderbar, ${esc(name)}. Die Formalitäten sind erledigt. Deine Werte wurden berechnet. Deine Überlebenschance wurde auch berechnet. Die sagen wir dir lieber nicht.“</div>
        <ul class="muted">${lines}</ul>
        <div class="row"><button data-action="back">Nochmal von vorn</button><button class="primary" data-action="go">In den Dungeon!</button></div>
      </div></div>`;
    typeQuote(root);
    bindActions(root, {
      back: () => {
        step = -1;
        answers.length = 0;
        draw();
      },
      go: () => onDone({ name, answers, petName: petName || undefined }),
    });
  };

  const showReaction = (text: string) => {
    root.innerHTML = `
      <div class="screen"><div class="card stack">
        <div class="systemquote">„${esc(text)}“</div>
        <div class="row"><button class="primary" data-action="next">Weiter</button></div>
      </div></div>`;
    typeQuote(root);
    bindActions(root, {
      next: () => {
        step += 1;
        draw();
      },
    });
  };

  const askPetName = (species: string, def: string, reaction: string) => {
    root.innerHTML = `
      <div class="screen"><div class="card stack">
        <div class="systemquote">„${esc(reaction)} Wie heißt ${species === 'Katze' ? 'die Katze' : 'der Hund'}?“</div>
        <input id="pet" maxlength="20" placeholder="${esc(def)}" />
        <div class="row"><button class="primary" data-action="next">Weiter</button></div>
      </div></div>`;
    const input = root.querySelector('#pet') as HTMLInputElement;
    typeQuote(root);
    const go = () => {
      petName = input.value.trim() || def;
      step += 1;
      draw();
    };
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') go();
    });
    bindActions(root, { next: go });
  };

  draw();
}

export function endScreen(root: HTMLElement, s: GameState, meta: MetaState, onNew: () => void, onTitle: () => void) {
  const victory = s.status === 'victory';
  const contract = !victory && s.contractSigned;
  const quip = DEATH_QUIPS[s.turn % DEATH_QUIPS.length];
  const headline = victory ? `Etage ${s.floor} überlebt!` : contract ? 'In den Dienst übernommen' : 'Staffel beendet';
  const text = victory
    ? 'Du hast es bis ans Ende dessen geschafft, was bisher gebaut ist. Die Systemstimme ist beeindruckt und leicht verärgert. Weitere Etagen folgen.'
    : contract
      ? `${s.player.name} ist nicht tot – sondern jetzt Personal. In der nächsten Staffel wartet ${s.player.name} als Guide in der Gilde der Einweisung.`
      : `${quip} Ursache: ${s.deathCause ?? 'unbekannt'}. Der Geist von ${s.player.name} wandert jetzt durch Etage ${s.floor} – mit der alten Ausrüstung. Vielleicht triffst du ihn in der nächsten Staffel.`;
  const b = s.counters;
  root.innerHTML = `
    <div class="screen"><div class="card stack">
      <div class="title-logo" style="font-size:36px">${esc(headline)}</div>
      <div class="systemquote">${esc(text)}</div>
      <div class="section">Bilanz von ${esc(s.player.name)} (${esc(s.player.background)})</div>
      <div class="muted">Level ${s.player.level} · Etage ${s.floor} · ${b.kills} Kills (${b.bossKills} Bosse) · ${b.damageDealt} Schaden ausgeteilt · ${b.damageTaken} eingesteckt · ${b.steps} Schritte · ${s.achievements.length} Achievements · ${b.boxesOpened} Boxen geöffnet</div>
      <div class="section">Hall of Fame</div>
      ${hallOfFame(meta)}
      <div class="row" style="margin-top:12px"><button class="primary" data-action="new">Neue Staffel</button><button data-action="title">Zum Titel</button></div>
    </div></div>`;
  bindActions(root, { new: onNew, title: onTitle });
}
