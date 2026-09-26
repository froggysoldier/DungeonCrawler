import { ACHIEVEMENTS } from '../data/achievements';
import { RARITY_COLORS, RARITY_NAMES, SLOT_NAMES } from '../data/items';
import { SKILLS, skillXpNeeded } from '../data/skills';
import { BOX_TIER_COLORS, FLOORS, RESTAURANT_HOSTS, RESTAURANT_MENU, SHOW_NAME } from '../data/world';
import { monsterAt } from '../engine/ai';
import { CLASS_BY_ID } from '../data/classes';
import { RACE_BY_ID } from '../data/races';
import { currentAbility, useAbility } from '../engine/classes';
import { maxMp, spellCost } from '../engine/magic';
import { offerPrice, sellPrice } from '../engine/shop';
import { SPELL_BY_ID } from '../data/spells';
import { describeItem, describeMonster, INSIGHT_NAMES, itemName } from '../engine/identify';
import { liveViewers } from '../engine/viewers';
import { dynXpNeeded, skillHints } from '../engine/observer';
import { TRAIT_BY_ID, TRAIT_KIND_NAMES } from '../data/traits';
import { describeBonuses, PART_NAMES, STAT_NAMES } from '../engine/bonuses';
import {
  ATTACK_MOVES, ATTACK_PARTS, MOVE_NAMES, attackCost, hitChance, isInSafeRoom, techniqueBlocker, techniqueName,
} from '../engine/combat';
import { chebyshev } from '../engine/fov';
import { disarmableTraps, disarmChance, knownTrapAt, trapName } from '../engine/traps';
import { allRecipes, hasWorkbench } from '../engine/crafting';
import { crawlerAt, describeCrawler, joinChance, party, population, talkableCrawlers } from '../engine/crawlers';
import { PERSONALITIES } from '../data/crawlers';
import { SPONSOR_BY_ID } from '../data/sponsors';
import { sponsorStates } from '../engine/sponsors';
import { evolveOptions, petFormName } from '../engine/petevo';
import { PET_ABILITIES, type PetAbility } from '../data/pets';
import { activeQuests, canTurnIn, hint, questOf, quests } from '../engine/quests';
import type { Quest } from '../engine/types';
import {
  allocateStat, attack, buyMeal, currentRoom, descend, drainToasts, dropItem, equip, hasUnlock, itemsAt,
  buyOffer, cast, haggleOffer, moveStep, sellItem, onStairs, openBox, pickup, planPath, sleep, takeFreebie, timeLeft, toilet, unequip, useItem, wait,
  chooseThrowable, craftItem, disarmTrap, placeTrap,
  askCrawlerTip, dismissCrawler, healCrawler, inviteCrawler, talkCrawler, answerTalkShow, acceptSponsorOffer, declineSponsorOffer, acceptQuestOffer, declineQuestOffer, turnInQuest, evolvePetTo, petGearOn, petGearOff,
  type ActionResult,
} from '../engine/game';
import { idx, isWalkable } from '../engine/mapgen';
import { saveRun, syncMeta, saveMeta } from '../engine/meta';
import { canStep } from '../engine/path';
import {
  ausweichen, currentWeapon, effectiveStats, lichtradius, maxAusdauer, maxHp, throwables, totalBonuses, xpToNext,
} from '../engine/player';
import { skillProgress } from '../engine/skills';
import type { AttackMove, AttackPart, EquipSlot, GameState, Item, MetaState, Pos, StatKey } from '../engine/types';
import { bindActions, esc, formatTime } from './dom';
import { confirmBox, isModalOpen, showCustom, showDialog, showHtml, showToast } from './modal';
import { render, tileFromMouse, type View } from './render';
import { TypeQueue, typeText, type Typing } from './typewriter';
import { TONE_NAMES } from '../data/talkshow';
import { showSelection } from './selection';

type Tab = 'crawler' | 'inventar' | 'handwerk' | 'skills' | 'erfolge';

const EQUIP_ORDER: EquipSlot[] = [
  'kopf', 'gesicht', 'hals', 'schultern', 'brust', 'ruecken', 'arme', 'haende', 'ring1', 'ring2',
  'guertel', 'beine', 'fuesse', 'fussring1', 'fussring2', 'unterwaesche', 'waffe',
];

const EQUIP_NAMES: Record<EquipSlot, string> = {
  ...(SLOT_NAMES as unknown as Record<EquipSlot, string>),
  ring1: 'Ring 1', ring2: 'Ring 2', fussring1: 'Fußring 1', fussring2: 'Fußring 2',
};

const PART_KEYS: Record<AttackPart, string> = { faust: '1', tritt: '2', knie: '3', ellbogen: '4', kopf: '5', waffe: '6', wurf: '7' };
const MOVE_KEYS: Record<AttackMove, string> = { normal: 'Q', sprung: 'W', stampfen: 'E', anlauf: 'R' };

const DIR_KEYS: Record<string, Pos> = {
  ArrowUp: { x: 0, y: -1 }, ArrowDown: { x: 0, y: 1 }, ArrowLeft: { x: -1, y: 0 }, ArrowRight: { x: 1, y: 0 },
  Numpad8: { x: 0, y: -1 }, Numpad2: { x: 0, y: 1 }, Numpad4: { x: -1, y: 0 }, Numpad6: { x: 1, y: 0 },
  Numpad7: { x: -1, y: -1 }, Numpad9: { x: 1, y: -1 }, Numpad1: { x: -1, y: 1 }, Numpad3: { x: 1, y: 1 },
};

export class GameView {
  private tab: Tab = 'crawler';
  private part: AttackPart = 'faust';
  /** Zauber, der auf ein Ziel wartet (nächster Klick auf die Karte). */
  private pendingSpell: string | null = null;
  private missileMana = 4;
  private move: AttackMove = 'normal';
  private hover: Pos | null = null;
  private view: View | null = null;
  private visible = new Set<number>();
  private traveling = false;
  private canvas!: HTMLCanvasElement;
  private lastLogId = -1;
  private typer = new TypeQueue(9, () => {
    const el = this.root.querySelector('.log') as HTMLElement | null;
    if (el) el.scrollTop = el.scrollHeight;
  });
  private ended = false;
  private keyHandler = (e: KeyboardEvent) => this.onKey(e);

  constructor(
    private root: HTMLElement,
    private s: GameState,
    private meta: MetaState,
    private onEnd: (s: GameState) => void,
  ) {
    this.build();
    document.addEventListener('keydown', this.keyHandler);
    window.addEventListener('resize', () => this.draw());
    this.refresh();
  }

  get state() {
    return this.s;
  }

  destroy() {
    document.removeEventListener('keydown', this.keyHandler);
  }

  // ---------------------------------------------------------------- Aufbau

  private build() {
    this.root.innerHTML = `
      <div class="game">
        <div class="topbar"></div>
        <div class="mapwrap">
          <canvas></canvas>
          <div class="roomlabel"></div>
          <div class="tooltip" hidden></div>
        </div>
        <div class="side">
          <div class="here"></div>
          <div class="tabs">
            <button data-tab="crawler">Crawler</button>
            <button data-tab="inventar">Inventar</button>
            <button data-tab="handwerk">Handwerk</button>
            <button data-tab="skills">Skills</button>
            <button data-tab="erfolge">Erfolge</button>
          </div>
          <div class="tabcontent"></div>
        </div>
        <div class="bottom">
          <div class="actionbar"></div>
          <div class="log"></div>
        </div>
      </div>`;
    this.canvas = this.root.querySelector('canvas')!;
    this.root.querySelector('.log')!.addEventListener('click', () => this.typer.finishAll());
    this.root.querySelectorAll<HTMLButtonElement>('.tabs button').forEach((b) =>
      b.addEventListener('click', () => {
        this.tab = b.dataset.tab as Tab;
        this.refreshSide();
      }),
    );
    this.canvas.addEventListener('mousemove', (e) => this.onHover(e));
    this.canvas.addEventListener('mouseleave', () => {
      this.hover = null;
      (this.root.querySelector('.tooltip') as HTMLElement).hidden = true;
      this.draw();
    });
    this.canvas.addEventListener('click', (e) => this.onClick(e));
    this.canvas.addEventListener('contextmenu', (e) => {
      e.preventDefault();
      this.examine(e);
    });
  }

  // ---------------------------------------------------------------- Aktionen

  /** Führt eine Engine-Aktion aus und kümmert sich um alles danach. */
  private act(fn: () => ActionResult | { ok: boolean; message?: string }): boolean {
    if (this.s.status !== 'playing' || isModalOpen()) return false;
    const res = fn();
    if (!res.ok && res.message) this.s.log.push({ turn: this.s.turn, text: res.message, kind: 'info' });
    this.afterAction();
    return res.ok;
  }

  private afterAction() {
    // Einblendungen nur noch für Warnungen – alles andere steht im Log (sonst stünde es doppelt da)
    for (const t of drainToasts(this.s)) if (t.kind === 'warnung') showToast(t.title, t.text, t.kind);
    syncMeta(this.meta, this.s);
    saveMeta(this.meta);
    if (this.s.status === 'playing') saveRun(this.s);
    this.refresh();
    this.flushDialogs();
    if (this.s.status !== 'playing' && !this.ended) {
      this.ended = true;
      this.traveling = false;
      const s = this.s;
      const title = s.status === 'victory' ? 'Geschafft!' : 'Tot.';
      setTimeout(() => {
        const text = s.status === 'victory' ? 'Du hast alle bisher gebauten Etagen überlebt.' : `Todesursache: ${s.deathCause ?? 'unbekannt'}.`;
        showHtml(title, `<div class="page">${esc(text)}</div>`, 'Weiter').then(() => this.onEnd(s));
      }, 300);
    }
  }

  flushDialogs() {
    while (this.s.pendingDialogs.length) {
      const d = this.s.pendingDialogs.shift()!;
      const shown = d.kind === 'talkshow' ? this.runTalkShow(d.title, d.pages) : showDialog(d.title, d.speaker, d.pages);
      shown.then(() => {
        this.refresh();
        this.maybeSelect();
      });
    }
    saveRun(this.s);
    this.maybeSelect();
  }

  private selecting = false;

  /** Die Talkshow: Einleitung, dann Fragen mit Antwortmöglichkeiten – alles in einem Fenster. */
  private runTalkShow(title: string, intro: string[]): Promise<void> {
    const s = this.s;
    return showCustom(
      `<h2>${esc(title)}</h2><div class="speaker">Veronika Glanz</div><div class="page show-q"></div><div class="show-a"></div>
       <div class="foot"><span class="muted small show-no"></span><span class="muted small show-f"></span></div>`,
      (root, close) => {
        const qEl = root.querySelector('.show-q') as HTMLElement;
        const aEl = root.querySelector('.show-a') as HTMLElement;
        const noEl = root.querySelector('.show-no') as HTMLElement;
        const fEl = root.querySelector('.show-f') as HTMLElement;
        let typing: Typing | null = null;
        const type = (html: string) => {
          typing?.finish();
          typing = typeText(qEl, html, 18);
        };
        const button = (label: string, onClick: () => void) => {
          aEl.innerHTML = `<button class="primary show-next">${esc(label)}</button>`;
          const b = aEl.querySelector('.show-next') as HTMLButtonElement;
          b.addEventListener('click', () => {
            // Erster Klick zeigt den Text sofort ganz, zweiter geht weiter
            if (typing && !typing.isDone()) typing.finish();
            else onClick();
          });
          b.focus();
        };
        const follower = () => {
          const d = s.talkShow?.followerDelta ?? 0;
          fEl.textContent = `Follower ${s.viewers.follower.toLocaleString('de-DE')} (${d >= 0 ? '+' : ''}${d.toLocaleString('de-DE')} in dieser Sendung)`;
        };
        let page = 0;
        const showIntro = () => {
          noEl.textContent = `Einleitung ${page + 1} / ${intro.length}`;
          type(esc(intro[page]));
          button(page < intro.length - 1 ? 'Weiter' : 'Zur ersten Frage', () => {
            page += 1;
            if (page < intro.length) showIntro();
            else ask();
          });
        };
        const ask = () => {
          const show = s.talkShow;
          if (!show || show.done) return close();
          const q = show.questions[show.index];
          noEl.textContent = `Frage ${show.index + 1} von ${show.questions.length}`;
          follower();
          type(esc(q.text));
          aEl.innerHTML = q.answers
            .map((a, i) => `<button class="show-btn" data-i="${i}"><span class="muted small">${esc(TONE_NAMES[a.tone])}:</span> ${esc(a.label)}</button>`)
            .join('');
          aEl.querySelectorAll<HTMLButtonElement>('.show-btn').forEach((b) => b.addEventListener('click', () => answer(Number(b.dataset.i))));
        };
        const answer = (i: number) => {
          const res = answerTalkShow(s, i);
          if (!res.ok) return close();
          follower();
          const d = res.delta ?? 0;
          type(`${esc(res.reaction ?? '')}\n\n<b style="color:${d >= 0 ? 'var(--ok)' : 'var(--danger)'}">${d >= 0 ? '+' : ''}${d.toLocaleString('de-DE')} Follower</b>${res.finished ? `\n\n${esc(res.outro ?? '')}` : ''}`);
          button(res.finished ? 'Zurück in den Dungeon' : 'Nächste Frage', () => {
            if (!res.finished) return ask();
            close();
            this.refresh();
          });
        };
        showIntro();
      },
    );
  }

  /** Öffnet die Rassen-/Klassenwahl, sobald keine anderen Dialoge mehr offen sind. */
  private maybeSelect() {
    if (!this.s.pendingSelection || this.selecting || isModalOpen()) return;
    this.selecting = true;
    showSelection(this.s, () => {
      this.selecting = false;
      this.afterAction();
    });
  }

  private technique() {
    return { part: this.part, move: this.move };
  }

  private attackMonster(uid: string) {
    this.act(() => attack(this.s, uid, this.technique()));
  }

  private stepToward(target: Pos) {
    const path = planPath(this.s, target);
    const next = path?.[0];
    if (next && !monsterAt(this.s, next)) this.act(() => moveStep(this.s, next));
    else this.say('Kein Weg dorthin.');
  }

  private say(text: string) {
    this.s.log.push({ turn: this.s.turn, text, kind: 'info' });
    this.refreshLog();
  }

  private async travel(path: Pos[]) {
    if (this.traveling) return;
    this.traveling = true;
    const seenBefore = new Set(this.visibleMonsters().map((m) => m.uid));
    for (const step of path) {
      if (!this.traveling || this.s.status !== 'playing' || isModalOpen()) break;
      const hpBefore = this.s.player.hp;
      const roomBefore = this.s.currentRoom;
      const trapsBefore = (this.s.traps ?? []).filter((x) => !x.hidden).length;
      if (!this.act(() => moveStep(this.s, step))) break;
      if ((this.s.traps ?? []).filter((x) => !x.hidden).length > trapsBefore) break;
      if (this.s.player.pos.x !== step.x || this.s.player.pos.y !== step.y) break;
      const newMonster = this.visibleMonsters().some((m) => !seenBefore.has(m.uid) || m.aware);
      if (newMonster) {
        const m = this.visibleMonsters().find((x) => !seenBefore.has(x.uid) || x.aware);
        if (m) this.say(`Du hältst an: ${describeMonster(this.s, m).name} in Sicht.`);
        break;
      }
      if (this.s.player.hp < hpBefore) break;
      if (this.s.currentRoom !== roomBefore) break;
      if (itemsAt(this.s, this.s.player.pos).length || onStairs(this.s)) break;
      await new Promise((r) => setTimeout(r, 55));
    }
    this.traveling = false;
  }

  private visibleMonsters() {
    return this.s.monsters.filter((m) => this.visible.has(idx(this.s.map, m.pos.x, m.pos.y)));
  }

  // ---------------------------------------------------------------- Eingabe

  private onClick(e: MouseEvent) {
    if (!this.view || isModalOpen()) return;
    if (this.traveling) {
      this.traveling = false;
      return;
    }
    const t = tileFromMouse(this.view, this.canvas, e);
    const s = this.s;
    const mon = monsterAt(s, t);
    // Zauber mit Ziel: der nächste Klick bestimmt das Ziel
    if (this.pendingSpell) {
      const sp = this.pendingSpell;
      this.pendingSpell = null;
      const target = mon && this.visible.has(idx(s.map, t.x, t.y)) ? mon : undefined;
      this.act(() => cast(s, sp, { targetUid: target?.uid, pos: t, mana: this.missileMana }));
      return;
    }
    if (mon && this.visible.has(idx(s.map, t.x, t.y))) {
      const blocker = techniqueBlocker(s, mon, this.technique());
      if (!blocker) return this.attackMonster(mon.uid);
      const d = chebyshev(s.player.pos, mon.pos);
      if (d > 1 && this.part !== 'wurf') return this.stepToward(mon.pos);
      return this.say(blocker);
    }
    const npc = crawlerAt(s, t);
    if (npc && this.visible.has(idx(s.map, t.x, t.y)) && !npc.party) {
      if (chebyshev(npc.pos, s.player.pos) <= 1) return void this.act(() => talkCrawler(s, npc.uid));
      return this.stepToward(npc.pos);
    }
    if (t.x === s.player.pos.x && t.y === s.player.pos.y) {
      if (itemsAt(s, t).length) this.act(() => pickup(s));
      else if (onStairs(s)) this.askDescend();
      else this.act(() => wait(s));
      return;
    }
    if (chebyshev(t, s.player.pos) === 1 && canStep(s.map, s.player.pos, t)) {
      this.act(() => moveStep(s, t));
      return;
    }
    const path = planPath(s, t);
    if (path?.length) this.travel(path);
    else this.say('Dorthin kennst du keinen Weg.');
  }

  private onHover(e: MouseEvent) {
    if (!this.view) return;
    const t = tileFromMouse(this.view, this.canvas, e);
    if (this.hover && this.hover.x === t.x && this.hover.y === t.y) return;
    this.hover = t;
    this.draw();
    this.updateTooltip(e);
  }

  private tooltipFor(t: Pos): string | null {
    const s = this.s;
    const i = idx(s.map, t.x, t.y);
    const visible = this.visible.has(i);
    const known = visible || (hasUnlock(s, 'minimap') && s.map.explored[i]);
    if (!known) return null;
    const parts: string[] = [];
    const mon = visible ? monsterAt(s, t) : undefined;
    if (mon) {
      const tech = this.technique();
      const blocker = techniqueBlocker(s, mon, tech);
      const info = describeMonster(s, mon);
      const color = info.insight >= 3 ? '#b0a898' : mon.color;
      parts.push(`<b style="color:${color}">${esc(info.name)}</b>${info.rank ? ` <span class="muted">${info.rank}</span>` : ''}`);
      parts.push(`<span class="muted">${esc(info.level)} · ${esc(INSIGHT_NAMES[info.insight])}</span>`);
      parts.push(`${esc(info.health)}${mon.downed > 0 ? ' · <span style="color:#7cc4ff">am Boden</span>' : ''}${!mon.aware ? ' · <span style="color:#6ee07a">ahnungslos</span>' : ''}`);
      if (info.combat) parts.push(esc(info.combat));
      if (info.abilities) parts.push(`<span style="color:#ff9dff">${esc(info.abilities)}</span>`);
      if (blocker) parts.push(`<span class="muted">${esc(techniqueName(tech))}: ${esc(blocker)}</span>`);
      else if (info.showHitChance) parts.push(`${esc(techniqueName(tech))}: <b>${hitChance(s, mon, tech)} %</b> Trefferchance`);
      else parts.push(`${esc(techniqueName(tech))}: Trefferchance nicht einschätzbar`);
      if (info.flavor) parts.push(`<span class="muted small">${esc(info.flavor)}</span>`);
    }
    const npc = visible ? crawlerAt(s, t) : undefined;
    if (npc) parts.push(`<b style="color:${npc.party ? '#8fe38f' : '#7cc4ff'}">${esc(describeCrawler(npc))}</b><br>${npc.party ? 'In deiner Party' : npc.met ? 'Crawler' : 'Ein anderer Crawler. Stell dich daneben, um zu reden.'} · HP ${npc.hp}/${npc.maxHp}`);
    const trap = knownTrapAt(s, t);
    if (trap) parts.push(`<b style="color:${trap.owner === 'crawler' ? '#6ee07a' : 'var(--danger)'}">${trap.owner === 'crawler' ? 'Deine ' : ''}${esc(trapName(trap.kind))}</b>`);
    const items = itemsAt(s, t);
    if (items.length) parts.push(items.map((e) => `<span style="color:${RARITY_COLORS[e.item.rarity]}">${esc(itemName(s, e.item))}</span>`).join('<br>'));
    const room = s.map.roomAt[i] >= 0 ? s.map.rooms[s.map.roomAt[i]] : null;
    if (s.map.tiles[i] === 'stairs') parts.push('<b style="color:#ffcc33">Treppenhaus nach unten</b>');
    if (room && room.visited) parts.push(`<span class="muted small">${esc(room.name)}</span>`);
    return parts.length ? parts.join('<br>') : null;
  }

  private updateTooltip(e: MouseEvent) {
    const tip = this.root.querySelector('.tooltip') as HTMLElement;
    const html = this.hover ? this.tooltipFor(this.hover) : null;
    if (!html) {
      tip.hidden = true;
      return;
    }
    tip.innerHTML = html;
    tip.hidden = false;
    const r = this.canvas.getBoundingClientRect();
    let x = e.clientX - r.left + 16;
    let y = e.clientY - r.top + 16;
    if (x + 290 > r.width) x = e.clientX - r.left - 290;
    if (y + tip.offsetHeight > r.height) y = e.clientY - r.top - tip.offsetHeight - 8;
    tip.style.left = `${Math.max(4, x)}px`;
    tip.style.top = `${Math.max(4, y)}px`;
  }

  private examine(e: MouseEvent) {
    if (!this.view) return;
    const t = tileFromMouse(this.view, this.canvas, e);
    const mon = this.visible.has(idx(this.s.map, t.x, t.y)) ? monsterAt(this.s, t) : undefined;
    if (mon) {
      const info = describeMonster(this.s, mon);
      return this.say([`${info.name} (${info.level}, ${INSIGHT_NAMES[info.insight]})`, info.health, info.combat, info.abilities, info.flavor].filter(Boolean).join('. '));
    }
    const items = itemsAt(this.s, t);
    if (items.length) {
      return this.say(items.map((i) => {
        const d = describeItem(this.s, i.item);
        return `${d.name}: ${d.flavor ?? d.note ?? ''}`;
      }).join(' | '));
    }
    const room = this.s.map.roomAt[idx(this.s.map, t.x, t.y)];
    if (room >= 0 && this.s.map.rooms[room].visited) this.say(`${this.s.map.rooms[room].name}: ${this.s.map.rooms[room].description}`);
  }

  private onKey(e: KeyboardEvent) {
    if (isModalOpen() || this.s.status !== 'playing') return;
    if ((e.target as HTMLElement)?.tagName === 'INPUT') return;
    const s = this.s;
    const dir = DIR_KEYS[e.code];
    if (dir) {
      e.preventDefault();
      this.traveling = false;
      const to = { x: s.player.pos.x + dir.x, y: s.player.pos.y + dir.y };
      const mon = monsterAt(s, to);
      if (mon) this.attackMonster(mon.uid);
      else this.act(() => moveStep(s, to));
      return;
    }
    const part = (Object.entries(PART_KEYS) as [AttackPart, string][]).find(([, k]) => k === e.key)?.[0];
    if (part) {
      this.part = part;
      if (part === 'wurf') this.move = 'normal';
      this.refreshActions();
      return;
    }
    const move = (Object.entries(MOVE_KEYS) as [AttackMove, string][]).find(([, k]) => k.toLowerCase() === e.key.toLowerCase())?.[0];
    if (move) {
      this.move = move;
      if (move === 'stampfen') this.part = 'tritt';
      this.refreshActions();
      return;
    }
    if (e.code === 'Space' || e.code === 'Numpad5') {
      e.preventDefault();
      this.act(() => wait(s));
    } else if ((e.key === 'f' || e.key === 'F') && currentAbility(s)) {
      this.act(() => useAbility(s, this.technique()));
    } else if (e.key === 'g' || e.key === 'G') {
      this.act(() => pickup(s));
    } else if (e.key === 'Enter' && onStairs(s)) {
      this.askDescend();
    } else if (e.key === 'Escape') {
      this.traveling = false;
      if (this.pendingSpell) {
        this.pendingSpell = null;
        this.say('Zauber abgebrochen.');
        this.refreshActions();
      }
    }
  }

  private async askDescend() {
    const s = this.s;
    const next = s.floor + 1;
    const def = FLOORS.find((f) => f.floor === next);
    const ok = await confirmBox(
      'Treppenhaus',
      `Auf Etage ${next}${def ? ` („${def.name}“)` : ''} hinabsteigen? Es gibt kein Zurück.${s.player.boxes.length ? ` Du hast noch ${s.player.boxes.length} ungeöffnete Box(en) – die bleiben dir erhalten.` : ''}`,
      'Hinabsteigen',
    );
    if (ok) this.act(() => descend(s, this.meta));
  }

  // ---------------------------------------------------------------- Darstellung

  refresh() {
    this.draw();
    this.refreshTop();
    this.refreshHere();
    this.refreshSide();
    this.refreshActions();
    this.refreshLog();
  }

  private draw() {
    const pathTarget = this.hover;
    let path: Pos[] | null = null;
    if (pathTarget && !this.traveling && !monsterAt(this.s, pathTarget) && this.s.status === 'playing') {
      const i = idx(this.s.map, pathTarget.x, pathTarget.y);
      if (pathTarget.x >= 0 && pathTarget.y >= 0 && pathTarget.x < this.s.map.width && pathTarget.y < this.s.map.height && this.s.map.explored[i] && isWalkable(this.s.map, pathTarget.x, pathTarget.y)) {
        path = planPath(this.s, pathTarget);
      }
    }
    const res = render(this.s, this.canvas, { hover: this.hover, path });
    this.view = res.view;
    this.visible = res.visible;
    const room = currentRoom(this.s);
    (this.root.querySelector('.roomlabel') as HTMLElement).textContent = room ? room.name : 'Gang';
  }

  private refreshTop() {
    const s = this.s;
    const def = FLOORS.find((f) => f.floor === s.floor);
    const left = timeLeft(s);
    const p = s.player;
    const pet = p.pet;
    (this.root.querySelector('.topbar') as HTMLElement).innerHTML = `
      <span class="show">${esc(SHOW_NAME)}</span>
      <span class="muted">Staffel ${s.season}</span>
      <span>Etage <b>${s.floor}</b>: ${esc(def?.name ?? '')}</span>
      <span class="timer ${left <= 120 ? 'warn' : ''}" title="Zeit bis zum Einsturz">Einsturz in ${formatTime(left)}</span>
      <span class="spacer"></span>
      <span>${esc(p.name)} · Lv <b>${p.level}</b></span>
      ${hasUnlock(s, 'zuschauer') ? `<span class="viewers">Zuschauer ${liveViewers(s).toLocaleString('de-DE')} · Follower ${s.viewers.follower.toLocaleString('de-DE')} · Hype ${Math.round(s.viewers.hype)}</span>` : ''}
      ${hasUnlock(s, 'inventar') ? `<span class="muted" title="Lebende Crawler laut letzter Zählung">Crawler übrig ${population(s).alive.toLocaleString('de-DE')}</span>` : ''}
      <span style="color:#ffd700">Gold ${p.gold}</span>
      <span>Lootboxen ${p.boxes.length}</span>
      ${pet ? `<span style="color:#ffb3e6">Haustier ${esc(pet.name)} ${pet.alive ? `${pet.hp}/${pet.maxHp}` : '(bewusstlos)'}</span>` : ''}`;
  }

  private refreshHere() {
    const s = this.s;
    const el = this.root.querySelector('.here') as HTMLElement;
    const room = currentRoom(s);
    const items = itemsAt(s, s.player.pos);
    const blocks: string[] = [];
    if (items.length) {
      blocks.push(`<div class="section">Hier liegt</div>${items
        .map((e) => `<div class="row" style="margin-bottom:4px"><span style="color:${RARITY_COLORS[e.item.rarity]};flex:1">${esc(itemName(s, e.item))}</span><button data-action="pick" data-uid="${e.item.uid}">Aufheben</button></div>`)
        .join('')}`);
    }
    if (onStairs(s)) blocks.push('<div class="row" style="margin:6px 0"><button class="primary" data-action="descend">Hinabsteigen (Enter)</button></div>');
    const people = talkableCrawlers(s);
    if (people.length) {
      const healer = s.player.inventory.find((i) => i.kind === 'verbrauch' && (i.effekt?.heal || i.effekt?.healPct));
      blocks.push(`<div class="section">Andere Crawler</div>${people
        .map((c) => {
          const btns = [`<button data-action="talk" data-uid="${c.uid}">Ansprechen</button>`];
          if (c.party) btns.push(`<button data-action="dismiss" data-uid="${c.uid}">Entlassen</button>`);
          else if (c.met && PERSONALITIES[c.personality].join > 0) btns.push(`<button data-action="invite" data-uid="${c.uid}">In die Party einladen (${Math.round(joinChance(s, c) * 100)} %)</button>`);
          else if (!c.met) btns.push(`<button data-action="invite" data-uid="${c.uid}">In die Party einladen</button>`);
          if (!c.tipGiven && !c.party) btns.push(`<button data-action="tip" data-uid="${c.uid}">Nach Tipps fragen</button>`);
          if (healer && c.hp < c.maxHp) btns.push(`<button data-action="heal" data-uid="${c.uid}" data-item="${healer.uid}">${esc(itemName(s, healer))} geben</button>`);
          return `<div style="margin-bottom:6px"><div class="small" style="color:${c.party ? '#8fe38f' : '#7cc4ff'}">${esc(describeCrawler(c))} · HP ${c.hp}/${c.maxHp}</div><div class="row" style="flex-wrap:wrap;gap:4px">${btns.join('')}</div>${this.questHtml(questOf(s, c.uid))}</div>`;
        })
        .join('')}`);
    }
    const nearTraps = disarmableTraps(s);
    if (nearTraps.length) {
      blocks.push(`<div class="section">Fallen in der Nähe</div>${nearTraps
        .map((tr) => tr.owner === 'crawler'
          ? `<div class="row" style="margin-bottom:4px"><span style="flex:1;color:#6ee07a">Deine ${esc(trapName(tr.kind))}</span><button data-action="disarm" data-uid="${tr.uid}">Abbauen</button></div>`
          : `<div class="row" style="margin-bottom:4px"><span style="flex:1;color:var(--danger)">${esc(trapName(tr.kind))}</span><button data-action="disarm" data-uid="${tr.uid}">Entschärfen (${Math.round(disarmChance(s, tr) * 100)} %)</button></div>`)
        .join('')}`);
    }
    if (room?.kind === 'safe') {
      const inside = isInSafeRoom(s, s.player.pos);
      let html = `<div class="section">Safe Room</div>`;
      if (room.safeVariant === 'freebie') {
        html += `<div class="row" style="margin-bottom:6px"><button data-action="freebie" ${room.freebieTaken ? 'disabled' : ''}>${room.freebieTaken ? 'Gratis-Gegenstand abgeholt' : 'Gratis-Gegenstand abholen'}</button></div>`;
      } else {
        const host = RESTAURANT_HOSTS[room.id % RESTAURANT_HOSTS.length];
        html += `<div class="muted small">${esc(host.name)} (${esc(host.race)}) serviert:</div>`;
        html += RESTAURANT_MENU.map(
          (m) => `<div class="row" style="margin:3px 0"><span style="flex:1">${esc(m.name)} <span class="muted small">${esc(m.effekt.buff?.name ?? '')}</span></span><button data-action="meal" data-id="${m.id}" ${s.player.gold < m.price ? 'disabled' : ''}>${m.price} G</button></div>`,
        ).join('');
      }
      if (inside) {
        html += `<div class="row" style="margin-top:6px"><button data-action="sleep">Schlafen (8 Std.)</button><button data-action="toilet">Toilette benutzen</button></div>`;
        if (room.shop) {
          html += `<div class="section">Laden</div><div class="muted small">${esc(room.shop.keeper)}${room.shop.mood < 70 ? ' – wirkt verstimmt' : ''}</div>`;
          html += room.shop.offers
            .map((o, i) => {
              const total = offerPrice(o.price, o.item);
              return `<div class="row shoprow"><span style="flex:1;color:${RARITY_COLORS[o.item.rarity]}" title="${esc(describeItem(s, o.item).bonuses.join(', '))}">${esc(itemName(s, o.item))}${o.item.menge && o.item.menge > 1 ? ` ×${o.item.menge}` : ''}</span><span class="muted small">${total} G</span><button data-action="buy" data-i="${i}" ${s.player.gold < total ? 'disabled' : ''}>Kaufen</button><button data-action="haggle" data-i="${i}" ${o.haggled ? 'disabled' : ''}>Feilschen</button></div>`;
            })
            .join('');
          html += '<div class="muted small">Verkaufen: im Inventar-Tab beim Gegenstand.</div>';
          html += this.questHtml(questOf(s, String(room.id)));
        }
        if (s.player.boxes.length) {
          html += `<div class="muted small" style="margin-top:6px">Lootboxen öffnen:</div>`;
          html += s.player.boxes
            .map((b) => `<div class="row" style="margin:3px 0"><span style="flex:1;color:${BOX_TIER_COLORS[b.box!.tier]}">${esc(b.name)}</span><button data-action="box" data-uid="${b.uid}">Öffnen</button></div>`)
            .join('');
        }
      }
      blocks.push(html);
    }
    el.innerHTML = blocks.length ? `<div style="padding:4px 12px 8px;border-bottom:1px solid var(--line)">${blocks.join('')}</div>` : '';
    bindActions(el, {
      pick: (b) => this.act(() => pickup(s, b.dataset.uid)),
      disarm: (b) => this.act(() => disarmTrap(s, b.dataset.uid!)),
      talk: (b) => this.act(() => talkCrawler(s, b.dataset.uid!)),
      invite: (b) => this.act(() => inviteCrawler(s, b.dataset.uid!)),
      dismiss: (b) => this.act(() => dismissCrawler(s, b.dataset.uid!)),
      tip: (b) => this.act(() => askCrawlerTip(s, b.dataset.uid!)),
      heal: (b) => this.act(() => healCrawler(s, b.dataset.uid!, b.dataset.item!)),
      'quest-yes': (b) => this.act(() => acceptQuestOffer(s, b.dataset.id!)),
      'quest-no': (b) => this.act(() => declineQuestOffer(s, b.dataset.id!)),
      'quest-turnin': (b) => this.act(() => turnInQuest(s, b.dataset.id!)),
      descend: () => this.askDescend(),
      freebie: () => {
        let item: Item | undefined;
        this.act(() => {
          const res = takeFreebie(s);
          item = res.item;
          return res;
        });
        if (item) this.revealItems('Gratis-Automat', [item]);
      },
      meal: (b) => this.act(() => buyMeal(s, b.dataset.id!)),
      sleep: () => this.act(() => sleep(s)),
      toilet: () => this.act(() => toilet(s)),
      buy: (b) => this.act(() => buyOffer(s, Number(b.dataset.i))),
      haggle: (b) => this.act(() => haggleOffer(s, Number(b.dataset.i))),
      box: (b) => {
        const box = s.player.boxes.find((x) => x.uid === b.dataset.uid);
        let contents: Item[] | undefined;
        this.act(() => {
          const res = openBox(s, b.dataset.uid!);
          contents = res.contents;
          return res;
        });
        if (contents && box) this.revealItems(box.name, contents);
      },
    });
  }

  private revealItems(title: string, items: Item[]) {
    const html = `<div class="reveal">${items.map((it, i) => `<div style="animation-delay:${i * 0.25}s" class="item">${this.itemHtml(it, false)}</div>`).join('')}</div>`;
    showHtml(title, html, 'Super!');
  }

  private itemHtml(it: Item, withActions: boolean, from: 'hand' | 'inv' = 'inv'): string {
    const color = RARITY_COLORS[it.rarity];
    const bits: string[] = [];
    if (it.slot) bits.push(SLOT_NAMES[it.slot]);
    if (it.kind === 'wurf') bits.push(`Wurfschaden ${it.wurfSchaden}`);
    if (it.waffenSchaden) bits.push(`Waffenschaden ${it.waffenSchaden}`);
    if (it.kind !== 'gold') bits.push(RARITY_NAMES[it.rarity]);
    const known = describeItem(this.s, it);
    const bon = [...known.bonuses];
    const eff = it.effekt;
    if (eff?.heal) bon.push(`Heilt ${eff.heal} HP`);
    if (eff?.healPct) bon.push(`Heilt ${eff.healPct} % der HP`);
    if (eff?.mana) bon.push(`+${eff.mana} Mana`);
    if (eff?.manaPct) bon.push(`Füllt ${eff.manaPct} % Mana`);
    if (eff?.cure) bon.push('Heilt Vergiftung');
    if (it.kind === 'buch' && it.spell) bon.push(`Lehrt den Zauber: ${SPELL_BY_ID[it.spell].name}`);
    if (eff?.ausdauer) bon.push(`+${eff.ausdauer} Ausdauer`);
    if (eff?.buff) bon.push(`${eff.buff.name}: ${describeBonuses(eff.buff.bonuses).join(', ')}`);
    if (it.explosion) bon.push(`Explodiert: etwa ${it.explosion} Schaden an allem im Umkreis von einem Feld`);
    if (it.trapKind) bon.push(`Falle zum Aufstellen: ${trapName(it.trapKind)}`);
    if (it.upgrades) bon.push(`${it.upgrades}x benagelt`);
    if (it.petBonus) bon.push(`Haustier: ${[it.petBonus.hp ? `+${it.petBonus.hp} HP` : '', it.petBonus.dmg ? `+${it.petBonus.dmg} Schaden` : ''].filter(Boolean).join(', ')}`);
    const actions: string[] = [];
    if (withActions) {
      if (it.kind === 'ausruestung' && from === 'inv' && hasUnlock(this.s, 'inventar')) actions.push(`<button data-action="equip" data-uid="${it.uid}">Anlegen</button>`);
      if (it.kind === 'verbrauch') actions.push(`<button data-action="use" data-uid="${it.uid}">Benutzen</button>`);
      if (it.kind === 'buch') actions.push(`<button data-action="use" data-uid="${it.uid}">Lesen</button>`);
      if (it.petBonus && from === 'inv' && this.s.player.pet) actions.push(`<button data-action="petgear-on" data-uid="${it.uid}">Dem Haustier anlegen</button>`);
      if (it.trapKind && from === 'inv') actions.push(`<button data-action="place" data-uid="${it.uid}">Hier aufstellen</button>`);
      if (it.kind === 'wurf' && from === 'inv') {
        const picked = throwables(this.s)[0]?.baseId === it.baseId;
        actions.push(picked
          ? `<button data-action="throwpick" data-id="" ${this.s.player.wurfWahl ? '' : 'disabled'}>Wird als Nächstes geworfen</button>`
          : `<button data-action="throwpick" data-id="${it.baseId}">Als Nächstes werfen</button>`);
      }
      actions.push(`<button data-action="drop" data-uid="${it.uid}">Ablegen</button>`);
      if (from === 'inv' && currentRoom(this.s)?.kind === 'safe' && it.kind !== 'box' && !it.questId) actions.push(`<button data-action="sell" data-uid="${it.uid}">Verkaufen (${sellPrice(it)} G)</button>`);
    }
    return `<div class="name" style="color:${color}">${esc(known.name)}${it.menge && it.menge > 1 && it.kind !== 'gold' ? ` ×${it.menge}` : ''}</div>
      <div class="meta">${esc(bits.join(' · '))}</div>
      ${bon.length ? `<div class="bon">${esc(bon.join(', '))}</div>` : ''}
      ${known.flavor ? `<div class="meta"><i>${esc(known.flavor)}</i></div>` : ''}
      ${known.note ? `<div class="meta" style="color:var(--danger)">${esc(known.note)}</div>` : ''}
      ${actions.length ? `<div class="actions">${actions.join('')}</div>` : ''}`;
  }

  private refreshSide() {
    this.root.querySelectorAll<HTMLButtonElement>('.tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === this.tab));
    const el = this.root.querySelector('.tabcontent') as HTMLElement;
    switch (this.tab) {
      case 'crawler':
        el.innerHTML = this.crawlerTab();
        break;
      case 'inventar':
        el.innerHTML = this.inventoryTab();
        break;
      case 'handwerk':
        el.innerHTML = this.craftTab();
        break;
      case 'skills':
        el.innerHTML = this.skillsTab();
        break;
      case 'erfolge':
        el.innerHTML = this.achievementsTab();
        break;
    }
    bindActions(el, {
      stat: (b) => this.act(() => allocateStat(this.s, b.dataset.stat as StatKey)),
      equip: (b) => this.act(() => equip(this.s, b.dataset.uid!)),
      unequip: (b) => this.act(() => unequip(this.s, b.dataset.slot as EquipSlot)),
      use: (b) => this.act(() => useItem(this.s, b.dataset.uid!)),
      drop: (b) => this.act(() => dropItem(this.s, b.dataset.uid!)),
      sell: (b) => this.act(() => sellItem(this.s, b.dataset.uid!)),
      place: (b) => this.act(() => placeTrap(this.s, b.dataset.uid!)),
      evolve: (b) => this.act(() => evolvePetTo(this.s, b.dataset.id!)),
      'petgear-on': (b) => this.act(() => petGearOn(this.s, b.dataset.uid!)),
      'petgear-off': () => this.act(() => petGearOff(this.s)),
      'sponsor-yes': (b) => this.act(() => acceptSponsorOffer(this.s, b.dataset.id!)),
      'sponsor-no': (b) => this.act(() => declineSponsorOffer(this.s, b.dataset.id!)),
      craft: (b) => this.act(() => craftItem(this.s, b.dataset.id!)),
      throwpick: (b) => this.act(() => chooseThrowable(this.s, b.dataset.id || null)),
    });
  }

  private petHtml(): string {
    const pet = this.s.player.pet!;
    let html = `<div class="section">Haustier</div><div class="small"><b style="color:#ffb3e6">${esc(pet.name)}</b> · ${esc(petFormName(pet))} · Stufe ${pet.level} · ${pet.alive ? `HP ${pet.hp}/${pet.maxHp}` : 'bewusstlos'} · Schaden ${pet.dmg[0]}–${pet.dmg[1]}</div>`;
    for (const a of pet.abilities ?? []) {
      const d = PET_ABILITIES[a as PetAbility];
      if (d) html += `<div class="small"><b>${esc(d.name)}:</b> <span class="muted">${esc(d.text)}</span></div>`;
    }
    html += pet.gear
      ? `<div class="row small" style="margin:4px 0"><span style="flex:1">Halsband: ${esc(itemName(this.s, pet.gear))}</span><button data-action="petgear-off">Abnehmen</button></div>`
      : '<div class="muted small">Kein Halsband. Halsbänder gibt es in Haustier-Boxen.</div>';
    if (pet.evolveReady) {
      html += `<div class="item"><div class="name" style="color:var(--accent)">Entwicklung möglich</div>${evolveOptions(pet)
        .map((f) => `<div class="small" style="margin:4px 0"><b>${esc(f.name)}</b>: ${esc(f.flavor)}<br><span class="muted">+${f.hp} HP, +${f.dmg[0]}–${f.dmg[1]} Schaden, Fähigkeit: ${esc(PET_ABILITIES[f.ability].name)} – ${esc(PET_ABILITIES[f.ability].text)}</span><br><button data-action="evolve" data-id="${f.id}">${esc(f.name)} wählen</button></div>`)
        .join('')}</div>`;
    }
    return html;
  }

  /** Angebot oder Abgabe eines Auftrags beim Auftraggeber. */
  private questHtml(q: Quest | undefined): string {
    if (!q) return '';
    if (q.status === 'angebot') {
      return `<div class="item"><div class="name" style="color:var(--accent)">Auftrag: ${esc(q.title)}</div><div class="meta">${esc(q.text)}</div>
        <div class="bon">Belohnung: ${q.reward.gold} Gold, ${q.reward.xp} XP${q.reward.box ? ', eine Lootbox' : ''}</div>
        <div class="actions"><button data-action="quest-yes" data-id="${q.id}">Annehmen</button><button data-action="quest-no" data-id="${q.id}">Ablehnen</button></div></div>`;
    }
    if (canTurnIn(this.s, q)) return `<div class="row" style="margin:4px 0"><button class="primary" data-action="quest-turnin" data-id="${q.id}">Auftrag abgeben: ${esc(q.title)}</button></div>`;
    return `<div class="small muted">Offener Auftrag: ${esc(q.title)} – ${esc(hint(this.s, q))}</div>`;
  }

  private sponsorHtml(): string {
    const s = this.s;
    const rows = sponsorStates(s)
      .filter((st) => st.status !== 'none' || st.interest >= 20)
      .map((st) => {
        const d = SPONSOR_BY_ID[st.id];
        if (!d) return '';
        if (st.status === 'offer') {
          return `<div class="item"><div class="name" style="color:var(--accent)">Angebot: ${esc(d.name)}</div><div class="meta">${esc(d.description)}</div>
            <div class="bon">Mag nicht: ${esc(d.dislike.text)}</div>
            <div class="actions"><button data-action="sponsor-yes" data-id="${d.id}">Annehmen</button><button data-action="sponsor-no" data-id="${d.id}">Ablehnen</button></div></div>`;
        }
        if (st.status === 'active') {
          const w = d.wishes[st.wish];
          return `<div class="small" style="margin-bottom:5px"><b style="color:#8fe38f">${esc(d.name)}</b> · Gunst ${st.favor} · ${st.completed} Wünsche erfüllt<br>Wunsch: ${esc(w.text)} <span class="muted">(${st.progress}/${w.count})</span></div>`;
        }
        if (st.status === 'dropped') return `<div class="small muted">${esc(d.name)}: Sponsoring beendet.</div>`;
        return `<div class="small muted">${esc(d.name)} beobachtet dich (Interesse ${Math.round(st.interest)} %)</div>`;
      })
      .join('');
    return `<div class="section">Sponsoren</div>${rows || '<div class="muted small">Noch interessiert sich niemand für dich. Mach eine gute Show.</div>'}`;
  }

  private craftTab(): string {
    const s = this.s;
    if (!hasUnlock(s, 'inventar')) {
      return '<div class="locked">Gesperrt: Ohne Inventar kein Handwerk.<br>Finde die <b>Gilde der Einweisung</b>.</div>';
    }
    const bench = hasWorkbench(s);
    let html = `<div class="muted small">Aus Kram, den du findest, baust du Sprengsätze, Fallen und Verbände. ${bench ? '<b style="color:var(--ok)">Eine Werkbank ist in Reichweite.</b>' : 'Aufwendige Rezepte brauchen eine Werkbank: in Werkstätten, Schmieden und Safe Rooms – oder eine Klappwerkbank im Rucksack.'}</div>`;
    for (const { recipe: r, missing } of allRecipes(s)) {
      const ing = r.ingredients.map((x) => `${x.n}x ${x.label}`).join(', ');
      html += `<div class="item"><div class="name">${esc(r.name)}${r.workbench ? ' <span class="muted small">(Werkbank)</span>' : ''}</div>
        <div class="meta">${esc(ing)}</div>
        <div class="bon">${esc(r.description)}</div>
        ${missing.length ? `<div class="meta" style="color:var(--danger)">Es fehlt: ${esc(missing.join(', '))}</div>` : ''}
        <div class="actions"><button data-action="craft" data-id="${r.id}" ${missing.length ? 'disabled' : ''}>Herstellen</button></div></div>`;
    }
    return html;
  }

  private crawlerTab(): string {
    const s = this.s;
    const p = s.player;
    const b = totalBonuses(s);
    const mh = maxHp(s, b);
    const ma = maxAusdauer(s, b);
    const need = xpToNext(p.level);
    const poisoned = p.buffs.some((x) => x.name === 'Vergiftet');
    let html = `<div class="bars">
      <div class="bar hp ${poisoned ? 'poison' : ''}"><div style="width:${(100 * Math.max(0, p.hp)) / mh}%"></div><span>HP ${Math.max(0, p.hp)} / ${mh}${poisoned ? ' · vergiftet' : ''}</span></div>
      <div class="bar st"><div style="width:${(100 * p.ausdauer) / ma}%"></div><span>Ausdauer ${p.ausdauer} / ${ma}</span></div>
      ${p.spells?.length ? `<div class="bar mp"><div style="width:${(100 * (p.mp ?? 0)) / maxMp(s, b)}%"></div><span>Mana ${p.mp ?? 0} / ${maxMp(s, b)}</span></div>` : ''}
      ${hasUnlock(s, 'inventar') ? `<div class="bar bl ${(p.blase ?? 0) >= 80 ? 'urgent' : ''}"><div style="width:${p.blase ?? 0}%"></div><span>Blase ${Math.round(p.blase ?? 0)} %${(p.blase ?? 0) >= 80 ? ' – such eine Toilette!' : ''}</span></div>` : ''}
      <div class="bar xp"><div style="width:${(100 * p.xp) / need}%"></div><span>XP ${p.xp} / ${need} (Level ${p.level})</span></div>
    </div>
    <div class="muted small">${esc(p.name)} · früher: ${esc(p.background)}${p.race ? ` · ${esc(RACE_BY_ID[p.race].name.replace(' (bleiben, wie du bist)', ''))}` : ''}${p.klass ? ` · <b style="color:var(--accent)">${esc(CLASS_BY_ID[p.klass].name)}</b>` : ''}</div>`;
    if (!hasUnlock(s, 'stats')) {
      return html + `<div class="locked" style="margin-top:12px">Gesperrt: Deine Werte siehst du erst nach dem Tutorial.<br>Finde die <b>Gilde der Einweisung</b>.</div>
        <div class="section">In der Hand</div>${p.hand ? `<div class="item">${this.itemHtml(p.hand, true, 'hand')}</div>` : '<div class="muted">Nichts. Heb etwas auf (G).</div>'}`;
    }
    const st = effectiveStats(s, b);
    html += `<div class="section">Werte ${p.statPoints ? `<span style="color:var(--ok)">(${p.statPoints} Punkte frei)</span>` : ''}</div><div class="kv">`;
    for (const k of Object.keys(STAT_NAMES) as StatKey[]) {
      const diff = st[k] - p.stats[k];
      html += `<span>${STAT_NAMES[k]}</span><b>${st[k]}${diff ? ` <span class="muted small">(${diff > 0 ? '+' : ''}${diff})</span>` : ''}</b>${p.statPoints ? `<button data-action="stat" data-stat="${k}">+</button>` : '<span></span>'}`;
    }
    html += `</div><div class="section">Kampf</div><div class="kv">
      <span>Rüstung</span><b>${b.ruestung ?? 0}</b><span></span>
      <span>Ausweichen</span><b>${Math.round(ausweichen(s, b))} %</b><span></span>
      <span>Krit-Chance</span><b>${5 + (b.krit ?? 0) + Math.max(0, st.ges - 5)} %</b><span></span>
      <span>Waffe</span><b>${esc(currentWeapon(s)?.name ?? '–')}</b><span></span>
      <span>Sichtweite</span><b>${lichtradius(s, b)} Felder</b><span></span>
    </div>`;
    if (p.buffs.length) {
      html += `<div class="section">Effekte</div>${p.buffs
        .map((x) => `<div class="small" style="color:${x.debuff ? 'var(--danger)' : 'inherit'}">${x.debuff ? 'Negativ:' : 'Positiv:'} ${esc(x.name)}${x.dot ? ` (−${x.dot} HP/Zug)` : ''} <span class="muted">(${x.turns} Züge)</span></div>`)
        .join('')}`;
    }
    if (p.traits?.length) {
      html += `<div class="section">Eigenschaften</div>${p.traits
        .map((id) => TRAIT_BY_ID[id])
        .filter(Boolean)
        .map((t) => `<div class="small" style="margin-bottom:4px"><b>${esc(t.name)}</b> <span class="muted">(${esc(TRAIT_KIND_NAMES[t.kind])})</span><br><span class="muted">${esc(t.description)}</span></div>`)
        .join('')}`;
    }
    if (p.immobile) html += `<div class="small" style="color:var(--danger)">Festgehalten: noch ${p.immobile} Züge (oder losreißen, indem du dich bewegst)</div>`;
    if (p.curses.length) html += `<div class="section">Flüche</div>${p.curses.map((c) => `<div class="small" style="color:var(--danger)">${esc(c)}</div>`).join('')}`;
    if (p.pet) html += this.petHtml();
    const members = party(s);
    if (members.length) {
      html += `<div class="section">Party (${members.length + 1} von 4)</div>${members
        .map((c) => `<div class="small" style="margin-bottom:3px"><b style="color:#8fe38f">${esc(c.name)}</b> · Level ${c.level} · HP ${c.hp}/${c.maxHp} · ${c.kills} Kills <span class="muted">(früher ${esc(c.background)})</span></div>`)
        .join('')}`;
    }
    const open = activeQuests(s);
    const doneCount = quests(s).filter((q) => q.status === 'erledigt').length;
    if (open.length || doneCount) {
      html += `<div class="section">Aufträge (${doneCount} erledigt)</div>${open
        .map((q) => `<div class="small" style="margin-bottom:4px"><b>${esc(q.title)}</b> <span class="muted">von ${esc(q.giver.name)}</span><br>${esc(hint(s, q))}${q.kind === 'jagd' ? ` <span class="muted">(${q.progress}/${q.count})</span>` : ''}</div>`)
        .join('') || '<div class="muted small">Keine offenen Aufträge.</div>'}`;
    }
    if (hasUnlock(s, 'zuschauer')) html += this.sponsorHtml();
    if (s.fallen?.length) html += `<div class="muted small">Gefallen: ${esc(s.fallen.join(', '))}</div>`;
    const hoods = s.map.hoods.map((h) => `<div class="small">${esc(h.name)}: ${h.bossAlive ? 'Boss lebt' : 'Boss besiegt'}${h.mapFound ? ', Karte gefunden' : ''}</div>`).join('');
    html += `<div class="section">Viertel</div>${hoods}`;
    return html;
  }

  private inventoryTab(): string {
    const s = this.s;
    const p = s.player;
    let html = '';
    if (!hasUnlock(s, 'inventar')) {
      html += `<div class="locked">Gesperrt: Kein Inventar. Du kannst nur einen Gegenstand in der Hand halten.<br>Finde die <b>Gilde der Einweisung</b>.</div>
        <div class="section">In der Hand</div>${p.hand ? `<div class="item">${this.itemHtml(p.hand, true, 'hand')}</div>` : '<div class="muted">Nichts.</div>'}`;
    } else {
      html += `<div class="section">Ausrüstung</div><div class="eqgrid">`;
      for (const slot of EQUIP_ORDER) {
        const it = p.equipment[slot];
        html += `<span class="muted">${EQUIP_NAMES[slot]}</span><span style="color:${it ? RARITY_COLORS[it.rarity] : 'inherit'}" title="${esc(it ? [describeItem(this.s, it).flavor ?? '', ...describeItem(this.s, it).bonuses].join(' | ') : '')}">${it ? esc(itemName(this.s, it)) : '<span class="muted">–</span>'}</span>${it ? `<button data-action="unequip" data-slot="${slot}">Ablegen</button>` : '<span></span>'}`;
      }
      html += `</div><div class="section">Rucksack (${p.inventory.length})</div>`;
      html += p.inventory.length ? p.inventory.map((it) => `<div class="item">${this.itemHtml(it, true)}</div>`).join('') : '<div class="muted">Leer.</div>';
    }
    html += `<div class="section">Lootboxen (${p.boxes.length})</div>`;
    html += p.boxes.length
      ? p.boxes.map((b) => `<div class="small" style="color:${BOX_TIER_COLORS[b.box!.tier]}">${esc(b.name)}</div>`).join('') + '<div class="muted small" style="margin-top:4px">Öffnen nur in einem Safe Room.</div>'
      : '<div class="muted">Keine. Achievements bringen Boxen!</div>';
    return html;
  }

  private skillsTab(): string {
    const s = this.s;
    const p = s.player;
    let html = '';
    if (!hasUnlock(s, 'skills')) html += '<div class="locked" style="margin-bottom:8px">Gesperrt: Die Skill-Übersicht gibt’s nach dem Tutorial. Gelernt wird trotzdem schon!</div>';
    html += `<div class="section">Gelernte Skills</div>`;
    if (!p.skills.length) html += '<div class="muted">Noch keine. Kämpfe – der Dungeon beobachtet dich.</div>';
    for (const st of p.skills) {
      const def = SKILLS.find((d) => d.id === st.id)!;
      const need = skillXpNeeded(st.level);
      html += `<div class="skill"><div class="top"><b>${esc(def.name)}</b><span>Stufe ${st.level}/${def.maxLevel}</span></div>
        <div class="muted small">${esc(def.description)}</div>
        ${hasUnlock(s, 'skills') ? `<div class="progress"><div style="width:${(100 * st.xp) / need}%"></div></div>` : ''}</div>`;
    }
    const dyn = p.dynSkills ?? [];
    html += `<div class="section">Vom Beobachter entdeckt</div>`;
    if (!dyn.length) html += '<div class="muted small">Noch nichts. Die Systemstimme beobachtet, gegen wen, wie und in welcher Lage du kämpfst, und formt daraus eigene Skills.</div>';
    for (const k of dyn) {
      const need = dynXpNeeded(k.level);
      html += `<div class="skill"><div class="top"><b>${esc(k.name)}</b><span>Stufe ${k.level}/10</span></div>
        <div class="muted small">${esc(k.description)}</div>
        <div class="progress"><div style="width:${(100 * k.xp) / need}%"></div></div></div>`;
    }
    const dynHints = skillHints(s);
    if (dynHints.length) {
      html += `<div class="section">Die Systemstimme beobachtet …</div>`;
      for (const h of dynHints) {
        html += `<div class="skill"><div class="top"><span>${esc(h.name)}</span><span class="muted">${h.progress}/${h.needed}</span></div><div class="progress"><div style="width:${(100 * h.progress) / h.needed}%"></div></div></div>`;
      }
    }
    const hints = SKILLS.filter((d) => !p.skills.some((k) => k.id === d.id) && d.unlockAt < 9999)
      .map((d) => ({ d, prog: skillProgress(s, d) }))
      .filter((x) => x.prog > 0)
      .sort((a, b) => b.prog / b.d.unlockAt - a.prog / a.d.unlockAt);
    if (hints.length) {
      html += `<div class="section">Du spürst Fortschritt…</div>`;
      for (const { d, prog } of hints) {
        html += `<div class="skill"><div class="top"><span>${esc(d.name)}</span><span class="muted">${prog}/${d.unlockAt}</span></div><div class="progress"><div style="width:${(100 * prog) / d.unlockAt}%"></div></div></div>`;
      }
    }
    const uses = Object.entries(p.techniqueUses)
      .filter(([k]) => !k.startsWith('_'))
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8);
    if (uses.length) {
      html += `<div class="section">Dein Kampfstil</div>`;
      const total = uses.reduce((a, [, v]) => a + v, 0);
      for (const [k, v] of uses) {
        const [part, move] = k.split('+') as [AttackPart, AttackMove];
        html += `<div class="small row"><span style="flex:1">${esc(techniqueName({ part, move }))}</span><span class="muted">${v}× · ${Math.round((100 * v) / total)} %</span></div>`;
      }
    }
    return html;
  }

  private achievementsTab(): string {
    const s = this.s;
    const done = ACHIEVEMENTS.filter((a) => s.achievements.includes(a.id));
    const everOnly = ACHIEVEMENTS.filter((a) => !s.achievements.includes(a.id) && this.meta.achievementsEver.includes(a.id));
    const patterns = s.dynAchievements ?? [];
    let html = `<div class="muted small">Diese Staffel: ${done.length + patterns.length} · Karriere insgesamt: ${this.meta.achievementsEver.length}</div>`;
    if (patterns.length) {
      html += `<div class="section">Entdeckte Muster</div>`;
      html += patterns
        .slice()
        .reverse()
        .map((a) => `<div class="achv"><div class="n">${esc(a.name)}</div><div class="small">${esc(a.description)}</div><div class="muted small"><i>${esc(a.comment)}</i></div></div>`)
        .join('');
      html += `<div class="section">Feste Achievements</div>`;
    }
    html += done
      .slice()
      .reverse()
      .map((a) => `<div class="achv"><div class="n">${esc(a.name)}</div><div class="small">${esc(a.description)}</div><div class="muted small"><i>${esc(a.comment)}</i></div></div>`)
      .join('');
    if (everOnly.length) {
      html += `<div class="section">Aus früheren Staffeln</div>`;
      html += everOnly.map((a) => `<div class="achv locked-a"><div class="n">${esc(a.name)}</div><div class="small">${esc(a.description)}</div></div>`).join('');
    }
    const hidden = ACHIEVEMENTS.length - done.length - everOnly.length;
    if (hidden > 0) html += `<div class="muted small" style="margin-top:8px">…und ${hidden} geheime Achievements, die noch niemand von dir gesehen hat.</div>`;
    return html;
  }

  private refreshActions() {
    const s = this.s;
    const el = this.root.querySelector('.actionbar') as HTMLElement;
    const thr = throwables(s).reduce((a, i) => a + (i.menge ?? 1), 0);
    const ability = currentAbility(s);
    const cd = s.player.abilityCooldown ?? 0;
    const partBtn = (part: AttackPart) => {
      const disabled = (part === 'waffe' && !currentWeapon(s)) || (part === 'wurf' && thr === 0);
      const label = part === 'wurf' ? `Wurf (${thr})` : part === 'waffe' ? (currentWeapon(s)?.name ?? 'Waffe') : PART_NAMES[part];
      return `<button class="${this.part === part ? 'sel' : ''}" data-action="part" data-part="${part}" ${disabled ? 'disabled' : ''} title="Taste ${PART_KEYS[part]}">${esc(label)}<span class="key">${PART_KEYS[part]}</span></button>`;
    };
    const moveBtn = (move: AttackMove) => {
      const cost = attackCost({ part: this.part, move });
      return `<button class="${this.move === move ? 'sel' : ''}" data-action="move" data-move="${move}" ${this.part === 'wurf' && move !== 'normal' ? 'disabled' : ''} title="Taste ${MOVE_KEYS[move]} · kostet ${cost} Ausdauer">${MOVE_NAMES[move]}<span class="key">${MOVE_KEYS[move]}</span></button>`;
    };
    el.innerHTML = `
      <div class="grp">${ATTACK_PARTS.map(partBtn).join('')}</div>
      <div class="grp">${ATTACK_MOVES.map(moveBtn).join('')}</div>
      ${ability ? `<div class="grp"><button class="ability" data-action="ability" ${cd ? 'disabled' : ''} title="Taste F · ${esc(ability.description)}"Fähigkeit: ${esc(ability.name)}${cd ? ` (${cd})` : ''}<span class="key">F</span></button></div>` : ''}
      <div class="grp"><button data-action="wait" title="Leertaste">Warten</button><button data-action="pickup" title="G">Aufheben</button></div>
      ${this.spellBar()}
      <span class="muted small">Gewählt: <b style="color:var(--accent)">${esc(techniqueName(this.technique()))}</b> · ${attackCost(this.technique())} Ausdauer</span>`;
    bindActions(el, {
      part: (b) => {
        this.part = b.dataset.part as AttackPart;
        if (this.part === 'wurf') this.move = 'normal';
        if (this.part !== 'tritt' && this.move === 'stampfen') this.move = 'normal';
        this.refreshActions();
      },
      move: (b) => {
        this.move = b.dataset.move as AttackMove;
        if (this.move === 'stampfen') this.part = 'tritt';
        this.refreshActions();
      },
      wait: () => this.act(() => wait(s)),
      pickup: () => this.act(() => pickup(s)),
      ability: () => this.act(() => useAbility(s, this.technique())),
      spell: (b) => {
        const id = b.dataset.spell!;
        const def = SPELL_BY_ID[id];
        if (def.target === 'selbst') {
          this.pendingSpell = null;
          this.act(() => cast(s, id));
          return;
        }
        this.pendingSpell = this.pendingSpell === id ? null : id;
        this.refreshActions();
      },
      mana: (b) => {
        this.missileMana = Number(b.dataset.mana);
        this.refreshActions();
      },
    });
  }

  /** Neue Log-Zeilen werden angehängt und Zeichen für Zeichen getippt. */
  /** Zauberleiste: jeder bekannte Zauber als Knopf, mit Kosten und Abklingzeit. */
  private spellBar(): string {
    const p = this.s.player;
    if (!p.spells?.length) return '';
    const btns = p.spells.map((k) => {
      const def = SPELL_BY_ID[k.id];
      const cd = p.spellCooldowns?.[k.id] ?? 0;
      const cost = spellCost(k.id, this.missileMana);
      const pending = this.pendingSpell === k.id;
      const disabled = cd > 0 || (p.mp ?? 0) < cost;
      return `<button class="spell ${pending ? 'sel' : ''}" data-action="spell" data-spell="${k.id}" ${disabled && !pending ? 'disabled' : ''} title="${esc(def.description)}">${esc(def.name)} (${cost} MP)${cd ? ` – ${cd}` : ''}</button>`;
    });
    const missile = p.spells.some((k) => k.id === 'geschoss')
      ? `<span class="muted small">Geschoss-Mana:</span>${[3, 4, 5, 6].map((m) => `<button class="${this.missileMana === m ? 'sel' : ''}" data-action="mana" data-mana="${m}">${m}</button>`).join('')}`
      : '';
    const hint = this.pendingSpell ? `<span class="small" style="color:var(--accent)">Klicke auf ${SPELL_BY_ID[this.pendingSpell].target === 'feld' ? 'ein freies Feld' : 'einen Gegner'} (Esc bricht ab)</span>` : '';
    return `<div class="grp spells">${btns.join('')}${missile}${hint}</div>`;
  }

  private refreshLog() {
    const el = this.root.querySelector('.log') as HTMLElement;
    const entries = this.s.log;
    const firstRender = this.lastLogId < 0;
    const fresh = entries.filter((l) => (l.id ?? 0) > this.lastLogId);
    if (!fresh.length && !firstRender) return;
    const toShow = firstRender ? entries.slice(-120) : fresh;
    for (const l of toShow) {
      const p = document.createElement('p');
      p.className = l.kind;
      const time = document.createElement('span');
      time.className = 't';
      time.textContent = formatTime(l.turn);
      const text = document.createElement('span');
      p.append(time, text);
      el.append(p);
      if (firstRender) text.textContent = l.text;
      else this.typer.push(text, esc(l.text));
    }
    this.lastLogId = entries[entries.length - 1]?.id ?? this.lastLogId;
    while (el.childElementCount > 150) el.firstElementChild?.remove();
    el.scrollTop = el.scrollHeight;
  }
}
