import { ABILITIES } from '../data/classes';
import { describeBonuses } from '../engine/bonuses';
import { chooseRaceAndClass, classOptions, raceOptions } from '../engine/classes';
import type { GameState } from '../engine/types';
import { esc } from './dom';
import { showCustom } from './modal';

/** Rassen- und Klassenwahl auf Etage 3. */
export function showSelection(s: GameState, onDone: () => void): Promise<void> {
  const races = raceOptions(s);
  const classes = classOptions(s);
  let race = 'mensch';
  let klass = classes[0]?.klass.id ?? '';

  return showCustom(
    `<h2>Wer willst du sein?</h2>
     <div class="speaker">Gilde der Einweisung · ${esc(s.guideName)}</div>
     <div class="select-grid">
       <div><div class="section">Rasse</div><div class="choices races"></div></div>
       <div><div class="section">Deine Klassenliste</div><div class="choices classes"></div></div>
     </div>
     <div class="foot"><span class="muted small summary"></span><button class="primary ok">Festlegen</button></div>`,
    (root, close) => {
      root.querySelector('.modal')!.classList.add('wide');
      const raceEl = root.querySelector('.races') as HTMLElement;
      const classEl = root.querySelector('.classes') as HTMLElement;
      const summary = root.querySelector('.summary') as HTMLElement;
      const draw = () => {
        raceEl.innerHTML = races
          .map(({ race: r, available }) => `
            <button class="choice ${r.id === race ? 'sel' : ''}" data-race="${r.id}" ${available ? '' : 'disabled'}>
              <b>${esc(r.name)}</b>
              <span class="small">${esc(r.description)}</span>
              ${available ? '' : `<span class="small lockreq">Gesperrt – Bedingung: ${esc(r.requirement?.text ?? '')}</span>`}
            </button>`)
          .join('');
        classEl.innerHTML = classes
          .map(({ klass: c, recommended }) => `
            <button class="choice ${c.id === klass ? 'sel' : ''}" data-klass="${c.id}">
              <b>${esc(c.name)} ${recommended ? '<span class="rec">Empfohlen</span>' : ''}</b>
              <span class="small">${esc(c.description)}</span>
              <span class="small ab">Fähigkeit: ${esc(ABILITIES[c.ability].name)} – ${esc(ABILITIES[c.ability].description)}</span>
            </button>`)
          .join('');
        const r = races.find((x) => x.race.id === race)!.race;
        const c = classes.find((x) => x.klass.id === klass)!.klass;
        summary.textContent = `${r.name.replace(' (bleiben, wie du bist)', '')} · ${c.name} · ${[...describeBonuses(r.bonuses), ...describeBonuses(c.bonuses)].join(', ')}`;
        raceEl.querySelectorAll<HTMLButtonElement>('[data-race]').forEach((b) =>
          b.addEventListener('click', () => {
            race = b.dataset.race!;
            draw();
          }),
        );
        classEl.querySelectorAll<HTMLButtonElement>('[data-klass]').forEach((b) =>
          b.addEventListener('click', () => {
            klass = b.dataset.klass!;
            draw();
          }),
        );
      };
      draw();
      root.querySelector('.ok')!.addEventListener('click', () => {
        const res = chooseRaceAndClass(s, race, klass);
        if (!res.ok) {
          summary.textContent = res.message ?? 'Das geht nicht.';
          return;
        }
        close();
        onDone();
      });
    },
  );
}
