import { ABILITIES, ARCHETYPE_NAMES, CLASS_RARITY_NAMES, type ClassArchetype, type ClassDef } from '../data/classes';
import { BASE_ITEMS } from '../data/items';
import type { RaceDef } from '../data/races';
import { SKILL_BY_ID } from '../data/skills';
import { SPECIAL_TEXT } from '../data/specials';
import { SPELL_BY_ID } from '../data/spells';
import { describeBonuses, STAT_NAMES } from '../engine/bonuses';
import { chooseRaceAndClass, classOptions, raceOptions } from '../engine/classes';
import type { GameState, SpecialEffect, StatKey } from '../engine/types';
import { esc } from './dom';
import { showCustom } from './modal';

const itemLabel = (id: string) => BASE_ITEMS.find((b) => b.id === id)?.name ?? id;
const specialsHtml = (list: SpecialEffect[] | undefined) =>
  (list ?? []).map((sp) => `<div class="small"><b>${esc(SPECIAL_TEXT[sp]?.name ?? sp)}:</b> <span class="muted">${esc(SPECIAL_TEXT[sp]?.text ?? '')}</span></div>`).join('');
const bonusHtml = (lines: string[]) => (lines.length ? `<div class="small bonuslist">${lines.map(esc).join(' · ')}</div>` : '');

function raceDetail(r: RaceDef): string {
  const talent = r.talent ? SKILL_BY_ID[r.talent] : null;
  return `<div class="detailblock">
    <div class="detailhead">Rasse: ${esc(r.name.replace(' (bleiben, wie du bist)', ''))}</div>
    <div class="small">${esc(r.description)}</div>
    ${bonusHtml(describeBonuses(r.bonuses))}
    ${r.id === 'mensch' ? '<div class="small"><b>Anpassungsfähig:</b> <span class="muted">4 freie Stat-Punkte zum Verteilen.</span></div>' : ''}
    ${specialsHtml(r.specials)}
    ${talent ? `<div class="small"><b>Begabung: ${esc(talent.name)}</b> <span class="muted">– wird gelernt und wächst 50 % schneller. ${esc(talent.description)}</span></div>` : ''}
    <div class="muted small"><i>${esc(r.comment)}</i></div>
  </div>`;
}

function classDetail(c: ClassDef): string {
  const ab = ABILITIES[c.ability];
  const skills = c.skills
    .map((id, i) => {
      const d = SKILL_BY_ID[id];
      return d ? `<div class="small"><b>${esc(d.name)}</b>${i === 0 ? ' <span class="muted">(+2 Stufen)</span>' : ''} <span class="muted">– ${esc(d.description)}</span></div>` : '';
    })
    .join('');
  const spells = (c.spells ?? []).map((id) => SPELL_BY_ID[id]).filter(Boolean);
  return `<div class="detailblock">
    <div class="detailhead">Klasse: ${esc(c.name)} <span class="muted small">${esc(ARCHETYPE_NAMES[c.archetype])} · ${esc(CLASS_RARITY_NAMES[c.rarity])}</span></div>
    <div class="small">${esc(c.description)}</div>
    ${bonusHtml(describeBonuses(c.bonuses))}
    <div class="small ab"><b>Fähigkeit: ${esc(ab.name)}</b> <span class="muted">(alle ${ab.cooldown} Züge)</span> – ${esc(ab.description)}</div>
    <div class="small" style="margin-top:4px"><b>Klassenskills</b> <span class="muted">(wachsen 50 % schneller)</span></div>${skills}
    ${spells.length ? `<div class="small"><b>Startzauber:</b> ${spells.map((sp) => `${esc(sp.name)} <span class="muted">(${esc(sp.description)})</span>`).join(', ')}</div>` : ''}
    ${c.gear?.length ? `<div class="small"><b>Startausrüstung:</b> ${c.gear.map(([id, n]) => `${n > 1 ? `${n}x ` : ''}${esc(itemLabel(id))}`).join(', ')}</div>` : ''}
    ${specialsHtml(c.specials)}
    ${c.requirement ? `<div class="small"><b>Freigeschaltet durch:</b> <span class="muted">${esc(c.requirement.text)}</span></div>` : ''}
    <div class="muted small"><i>${esc(c.comment)}</i></div>
  </div>`;
}

/** Werte vor und nach der Wahl. */
function statsPreview(s: GameState, r: RaceDef, c: ClassDef): string {
  const rows = (Object.keys(STAT_NAMES) as StatKey[]).map((k) => {
    const before = s.player.stats[k];
    const delta = (r.bonuses.stats?.[k] ?? 0) + (c.bonuses.stats?.[k] ?? 0);
    const after = Math.max(1, before + delta);
    return `<span>${STAT_NAMES[k]}</span><b>${before}${delta ? ` <span style="color:${delta > 0 ? 'var(--ok)' : 'var(--danger)'}">→ ${after}</span>` : ''}</b>`;
  });
  return `<div class="detailblock"><div class="detailhead">Deine Grundwerte</div><div class="kv2 small">${rows.join('')}</div></div>`;
}

/** Rassen- und Klassenwahl auf Etage 3. */
export function showSelection(s: GameState, onDone: () => void): Promise<void> {
  const races = raceOptions(s).sort((a, b) => Number(b.available) - Number(a.available));
  const classes = classOptions(s);
  const archetypes = [...new Set(classes.map((c) => c.klass.archetype))] as ClassArchetype[];
  let race = 'mensch';
  let klass = classes.find((c) => c.recommended)?.klass.id ?? classes[0]?.klass.id ?? '';
  let filter: ClassArchetype | 'alle' = 'alle';

  return showCustom(
    `<h2>Wer willst du sein?</h2>
     <div class="speaker">Gilde der Einweisung · ${esc(s.guideName)}</div>
     <div class="muted small" style="margin-bottom:8px">Die Systemstimme hat deine Akte gelesen. Deine Klassenliste richtet sich danach, wie du bisher gekämpft und gelebt hast. Seltene Klassen tauchen nur auf, wenn du dir etwas Besonderes verdient hast.</div>
     <div class="select3">
       <div><div class="section">Rasse</div><div class="choices races"></div></div>
       <div><div class="section">Deine Klassenliste</div><div class="archfilter"></div><div class="choices classes"></div></div>
       <div class="detail"></div>
     </div>
     <div class="foot"><span class="muted small summary"></span><button class="primary ok">Festlegen</button></div>`,
    (root, close) => {
      root.querySelector('.modal')!.classList.add('wide', 'widest');
      const raceEl = root.querySelector('.races') as HTMLElement;
      const classEl = root.querySelector('.classes') as HTMLElement;
      const filterEl = root.querySelector('.archfilter') as HTMLElement;
      const detailEl = root.querySelector('.detail') as HTMLElement;
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
        filterEl.innerHTML = [`<button class="${filter === 'alle' ? 'sel' : ''}" data-arch="alle">Alle</button>`, ...archetypes.map((a) => `<button class="${filter === a ? 'sel' : ''}" data-arch="${a}">${esc(ARCHETYPE_NAMES[a])}</button>`)].join('');
        classEl.innerHTML = classes
          .filter((c) => filter === 'alle' || c.klass.archetype === filter)
          .map(({ klass: c, recommended }) => `
            <button class="choice ${c.id === klass ? 'sel' : ''}" data-klass="${c.id}">
              <b>${esc(c.name)}${recommended ? '<span class="rec">Empfohlen</span>' : ''}${c.rarity !== 'normal' ? `<span class="rec rare-${c.rarity}">${esc(CLASS_RARITY_NAMES[c.rarity])}</span>` : ''}</b>
              <span class="small muted">${esc(ARCHETYPE_NAMES[c.archetype])} · Fähigkeit: ${esc(ABILITIES[c.ability].name)}</span>
              <span class="small">${esc(c.description)}</span>
            </button>`)
          .join('');
        const r = races.find((x) => x.race.id === race)!.race;
        const c = classes.find((x) => x.klass.id === klass)!.klass;
        detailEl.innerHTML = raceDetail(r) + classDetail(c) + statsPreview(s, r, c);
        summary.textContent = `${r.name.replace(' (bleiben, wie du bist)', '')} · ${c.name}`;
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
        filterEl.querySelectorAll<HTMLButtonElement>('[data-arch]').forEach((b) =>
          b.addEventListener('click', () => {
            filter = b.dataset.arch as ClassArchetype | 'alle';
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
