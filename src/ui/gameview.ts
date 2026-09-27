import { ACHIEVEMENTS, ACHIEVEMENT_CATEGORIES } from '../data/achievements';
import { nextGoals } from '../data/achievement_families';
import { RARITY_COLORS, RARITY_NAMES, SLOT_NAMES } from '../data/items';
import { SKILLS, SKILL_BY_ID, SKILL_CATEGORY_NAMES, skillXpNeeded, type SkillCategory } from '../data/skills';
import { BOX_TIER_COLORS, FLOORS, RESTAURANT_HOSTS, RESTAURANT_MENU, SHOW_NAME } from '../data/world';
import { monsterAt } from '../engine/ai';
import { ABILITIES, ARCHETYPE_NAMES, CLASS_BY_ID } from '../data/classes';
import { SPECIAL_TEXT } from '../data/specials';
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
  ATTACK_MOVES, ATTACK_PARTS, HIT_ZONES, MOVE_NAMES, ZONES, attackCost, hitChance, isInSafeRoom, techniqueBlocker, techniqueName,
} from '../engine/combat';
import { chebyshev } from '../engine/fov';
import { disarmableTraps, disarmChance, knownTrapAt, trapName } from '../engine/traps';
import { allRecipes, hasWorkbench } from '../engine/crafting';
import { crawlerAt, describeCrawler, joinChance, party, population, talkableCrawlers } from '../engine/crawlers';
import { PERSONALITIES } from '../data/crawlers';
import { SPONSOR_BY_ID } from '../data/sponsors';
import { sponsorStates } from '../engine/sponsors';
import { evolveOptions, petFormName } from '../engine/petevo';
import { MOUNTS } from '../data/mounts';
import { PET_ABILITIES, type PetAbility } from '../data/pets';
import { activeQuests, canTurnIn, hint, questOf, quests } from '../engine/quests';
import type { Quest } from '../engine/types';
import {
  allocateStat, attack, buyMeal, currentRoom, descend, drainToasts, dropItem, equip, hasUnlock, itemsAt,
  buyOffer, cast, haggleOffer, moveStep, sellItem, onStairs, openBox, pickup, planPath, sleep, takeFreebie, timeLeft, toilet, unequip, useItem, wait,
  isLairDoor, chooseThrowable, craftItem, disarmTrap, placeTrap, closeDoor, adjacentOpenDoors,
  drainFx, drainSfx, defend, askCrawlerTip, dismissCrawler, healCrawler, inviteCrawler, talkCrawler, answerTalkShow, acceptSponsorOffer, declineSponsorOffer, acceptQuestOffer, declineQuestOffer, turnInQuest, evolvePetTo, petGearOn, petGearOff, rideToggle, refuelMount,
  type ActionResult,
} from '../engine/game';
import { furnitureAt, idx, isWalkable, tileAt } from '../engine/mapgen';
import { saveRun, syncMeta, saveMeta } from '../engine/meta';
import { canStep } from '../engine/path';
import {
  ausweichen, currentWeapon, effectiveStats, lichtradius, maxAusdauer, maxHp, throwables, totalBonuses, xpToNext,
} from '../engine/player';
import { skillEffectText, skillProgress } from '../engine/skills';
import { stat } from '../engine/stats';
import { CONDITIONS, CONDITION_IDS, conditionList, playerHas } from '../engine/conditions';
import { monsterDefById } from '../engine/monsters';
import type { AttackMove, AttackPart, EquipSlot, GameState, HitZone, Item, MetaState, Pos, StatKey, Technique } from '../engine/types';
import { bindActions, esc, formatTime } from './dom';
import { confirmBox, isModalOpen, showCustom, showDialog, showHtml, showToast } from './modal';
import { TILE, render, renderMinimap, tileFromMouse, zoom, zoomBounds, type View } from './render';
import { TypeQueue, typeText, type Typing } from './typewriter';
import { Animator, STEP_MS } from './animator';
import { drawHero, drawSprite, spriteFor } from './sprites';
import { playCombatEnd, playCombatStart, playSfx, playVersus, setSoundEnabled, setTypingSoundEnabled, soundEnabled, typeClick, typingSoundEnabled } from './sound';
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
const ZONE_KEYS: Record<HitZone, string> = { kopf: 'Y', koerper: 'X', arme: 'C', beine: 'V' };

const DIR_KEYS: Record<string, Pos> = {
  ArrowUp: { x: 0, y: -1 }, ArrowDown: { x: 0, y: 1 }, ArrowLeft: { x: -1, y: 0 }, ArrowRight: { x: 1, y: 0 },
  Numpad8: { x: 0, y: -1 }, Numpad2: { x: 0, y: 1 }, Numpad4: { x: -1, y: 0 }, Numpad6: { x: 1, y: 0 },
  Numpad7: { x: -1, y: -1 }, Numpad9: { x: 1, y: -1 }, Numpad1: { x: -1, y: 1 }, Numpad3: { x: 1, y: 1 },
};

export class GameView {
  private tab: Tab = 'crawler';
  private showAllBoxes = false;
  private minimap!: HTMLCanvasElement;
  private minimapKey = '';
  private minimapBig = false;
  /** Erfolge-Tab: Übersicht oder Statistik, aufgeklappte Kategorien. */
  private achvView: 'erfolge' | 'statistik' = 'erfolge';
  private achvOpen = new Set<string>();
  private part: AttackPart = 'faust';
  /** Zauber, der auf ein Ziel wartet (nächster Klick auf die Karte). */
  private pendingSpell: string | null = null;
  private missileMana = 4;
  private move: AttackMove = 'normal';
  private zone: HitZone = 'koerper';
  /** Im Kampf ausgewähltes Ziel (UID). */
  private targetUid: string | null = null;
  private hover: Pos | null = null;
  /** Werte beim Kampfbeginn – für die Zusammenfassung am Ende. */
  private fight: { kills: number; xp: number; turn: number; hp: number } | null = null;
  /** Per Klick untersuchtes Feld: erst ansehen, beim zweiten Klick hingehen. */
  private inspected: Pos | null = null;
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
  private keyUpHandler = (e: KeyboardEvent) => this.onKeyUp(e);
  private anim = new Animator();
  private raf = 0;
  /** Gehaltene Richtungstaste: außerhalb von Kämpfen läuft man flüssig weiter. */
  private held: { code: string; dir: Pos } | null = null;
  private lastStep = 0;
  private pathCache: { key: string; path: Pos[] | null } = { key: '', path: null };

  constructor(
    private root: HTMLElement,
    private s: GameState,
    private meta: MetaState,
    private onEnd: (s: GameState) => void,
  ) {
    // Klänge vom Spielstart nicht nachträglich abspielen
    drainSfx(this.s);
    drainFx(this.s);
    this.build();
    document.addEventListener('keydown', this.keyHandler);
    document.addEventListener('keyup', this.keyUpHandler);
    window.addEventListener('blur', () => (this.held = null));
    this.refresh();
    const loop = (now: number) => {
      if (this.ended && !this.anim.busy(now)) return;
      this.tick(now);
      this.raf = requestAnimationFrame(loop);
    };
    this.raf = requestAnimationFrame(loop);
  }

  /** Ein Bild der Animationsschleife: gehaltene Tasten bewegen, dann zeichnen. */
  private tick(now: number) {
    if (this.held && !isModalOpen() && this.s.status === 'playing' && now - this.lastStep >= STEP_MS) {
      if (this.inCombat()) {
        // Im Kampf zählt jeder Schritt einzeln – nichts läuft automatisch weiter
        this.held = null;
      } else {
        this.lastStep = now;
        this.stepDir(this.held.dir);
      }
    }
    this.draw(now);
  }

  /** Kampf läuft, sobald ein wacher Gegner, der dich bemerkt hat, in Sicht ist. */
  inCombat(): boolean {
    return this.s.monsters.some((m) => m.aware && !m.asleep && this.visible.has(idx(this.s.map, m.pos.x, m.pos.y)));
  }

  /** Kampfmodus: klarer Einstieg (Banner, roter Rahmen, Klang) und Ausstieg mit Bilanz. */
  private updateCombatMode() {
    const s = this.s;
    const now = s.status === 'playing' && this.inCombat();
    const wrap = this.root.querySelector('.mapwrap') as HTMLElement | null;
    wrap?.classList.toggle('combat', now);
    if (now && !this.fight) {
      this.fight = { kills: s.stats?.kills ?? 0, xp: s.stats?.['xp.gesamt'] ?? 0, turn: s.turn, hp: s.player.hp };
      this.traveling = false;
      this.held = null;
      const foes = this.combatTargets().filter((m) => m.aware);
      const names = [...new Set(foes.map((m) => describeMonster(s, m).name))];
      const who = names.length > 2 ? `${names.slice(0, 2).join(', ')} und weitere` : names.join(' und ');
      s.log.push({ turn: s.turn, text: `Kampf! ${who} ${foes.length > 1 ? 'haben' : 'hat'} dich entdeckt. Ab jetzt zählt jeder Zug einzeln.`, kind: 'gefahr' });
      // Beim Betreten einer Boss-Kammer übernimmt der Versus-Bildschirm den Auftritt
      if (!s.pendingVersus) {
        this.banner('Kampf', who, 'start');
        playCombatStart();
      }
    } else if (!now && this.fight) {
      const f = this.fight;
      this.fight = null;
      if (s.status !== 'playing') return;
      const kills = (s.stats?.kills ?? 0) - f.kills;
      const xp = (s.stats?.['xp.gesamt'] ?? 0) - f.xp;
      const turns = s.turn - f.turn;
      const lost = Math.max(0, f.hp - s.player.hp);
      const bits = [`${turns} ${turns === 1 ? 'Zug' : 'Züge'}`];
      if (kills) bits.push(`${kills} besiegt`);
      if (xp) bits.push(`+${xp} Erfahrung`);
      if (lost) bits.push(`${lost} Lebenspunkte verloren`);
      s.log.push({ turn: s.turn, text: `Kampf vorbei: ${bits.join(', ')}.`, kind: 'kampf' });
      this.banner(kills ? 'Sieg' : 'Kampf vorbei', bits.join(' · '), 'end');
      playCombatEnd();
    }
  }

  private banner(title: string, sub: string, kind: 'start' | 'end') {
    const wrap = this.root.querySelector('.mapwrap');
    if (!wrap) return;
    wrap.querySelector('.fightbanner')?.remove();
    const el = document.createElement('div');
    el.className = `fightbanner ${kind}`;
    el.innerHTML = `<div class="fb-title">${esc(title)}</div>${sub ? `<div class="fb-sub">${esc(sub)}</div>` : ''}`;
    wrap.appendChild(el);
    setTimeout(() => el.remove(), kind === 'start' ? 1700 : 2200);
  }

  private stepDir(dir: Pos) {
    const s = this.s;
    const to = { x: s.player.pos.x + dir.x, y: s.player.pos.y + dir.y };
    const mon = monsterAt(s, to);
    if (mon) this.attackMonster(mon.uid);
    else this.act(() => moveStep(s, to));
  }

  private onKeyUp(e: KeyboardEvent) {
    if (this.held?.code === e.code) this.held = null;
  }

  get state() {
    return this.s;
  }

  destroy() {
    cancelAnimationFrame(this.raf);
    document.removeEventListener('keyup', this.keyUpHandler);
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
          <div class="minimapwrap" hidden><canvas class="minimap"></canvas><span class="minihint">Karte · K</span></div>
          <div class="zoomctl"><button data-zoom="-1" title="Herauszoomen (Taste -)">−</button><button data-zoom="1" title="Hineinzoomen (Taste +)">+</button></div>
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
    this.minimap = this.root.querySelector('.minimap') as HTMLCanvasElement;
    this.root.querySelector('.minimapwrap')!.addEventListener('click', () => this.toggleMinimap());
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
    this.canvas.addEventListener('wheel', (e) => {
      e.preventDefault();
      this.zoomMap(e.deltaY < 0 ? 1 : -1);
    }, { passive: false });
    this.root.querySelectorAll<HTMLButtonElement>('.zoomctl button').forEach((b) =>
      b.addEventListener('click', () => this.zoomMap(Number(b.dataset.zoom))),
    );
  }

  /** Karte vergrößern oder verkleinern. */
  private zoomMap(delta: number) {
    if (!zoom(delta)) return;
    const bounds = zoomBounds();
    const [out, inn] = this.root.querySelectorAll<HTMLButtonElement>('.zoomctl button');
    if (out) out.disabled = bounds.min;
    if (inn) inn.disabled = bounds.max;
    this.draw();
  }

  // ---------------------------------------------------------------- Aktionen

  /** Führt eine Engine-Aktion aus und kümmert sich um alles danach. */
  private act(fn: () => ActionResult | { ok: boolean; message?: string }): boolean {
    if (this.s.status !== 'playing' || isModalOpen()) return false;
    const before = this.anim.snapshot(this.s);
    const floor = this.s.floor;
    if (this.inspected) {
      this.inspected = null;
      (this.root.querySelector(".tooltip") as HTMLElement).hidden = true;
    }
    const res = fn();
    if (this.s.floor !== floor) this.anim.reset();
    else this.anim.after(this.s, before, drainFx(this.s));
    playSfx(drainSfx(this.s));
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
    const reveal = this.s.pendingReveal;
    if (reveal) {
      this.s.pendingReveal = undefined;
      this.revealItems(reveal.title, reveal.items);
    }
    this.maybeVersus();
    this.maybeSelect();
  }

  /** Versus-Bildschirm beim Betreten einer Boss-Kammer: Crawler gegen Boss. */
  private maybeVersus() {
    const s = this.s;
    const uid = s.pendingVersus;
    if (!uid) return;
    s.pendingVersus = undefined;
    const boss = s.monsters.find((m) => m.uid === uid);
    if (!boss) return;
    const info = describeMonster(s, boss);
    const p = s.player;
    const klass = p.klass ? CLASS_BY_ID[p.klass]?.name : null;
    const race = p.race ? RACE_BY_ID[p.race]?.name.replace(' (bleiben, wie du bist)', '') : null;
    const rank = boss.rank === 'boroughboss' ? 'Borough-Boss' : 'Nachbarschafts-Boss';
    playVersus();
    showCustom(
      `<div class="versus">
        <div class="vs-side vs-left"><canvas class="vs-hero" width="220" height="220"></canvas>
          <div class="vs-name">${esc(p.name)}</div>
          <div class="vs-sub">${esc([race, klass].filter(Boolean).join(' · ') || 'Crawler')} · Level ${p.level}</div>
          <div class="vs-sub">HP ${Math.max(0, p.hp)} / ${maxHp(s)}</div></div>
        <div class="vs-mid">VS</div>
        <div class="vs-side vs-right"><canvas class="vs-boss" width="220" height="220"></canvas>
          <div class="vs-name">${esc(info.name)}</div>
          <div class="vs-sub">${rank} · ${esc(info.level)}</div>
          <div class="vs-sub" style="color:${info.challenge.color}">${esc(info.challenge.name)}</div></div>
      </div>
      ${info.flavor ? `<div class="vs-flavor">${esc(info.flavor)}</div>` : ''}
      <div class="foot"><span class="muted small">Die Tür ist verriegelt, bis einer von euch am Boden liegt.</span><button class="primary ok">Kampf!</button></div>`,
      (root, close) => {
        root.querySelector('.modal')!.classList.add('versus-modal');
        const draw = (sel: string, fn: (c: CanvasRenderingContext2D) => void) => {
          const cv = root.querySelector(sel) as HTMLCanvasElement;
          const dpr = window.devicePixelRatio || 1;
          cv.width = 220 * dpr;
          cv.height = 220 * dpr;
          const c = cv.getContext('2d')!;
          c.scale(dpr, dpr);
          fn(c);
        };
        draw('.vs-hero', (c) => drawHero(c, 110, 120, 190));
        draw('.vs-boss', (c) => drawSprite(c, spriteFor(boss.defId), boss.color, 110, 120, 200, { crown: true, flip: true, unknown: info.insight >= 3 }));
        const btn = root.querySelector('.ok') as HTMLButtonElement;
        btn.focus();
        btn.addEventListener('click', () => {
          close();
          this.refresh();
        });
      },
    );
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

  private technique(): Technique {
    return { part: this.part, move: this.move, zone: this.zone };
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
    for (let k = 0; k < path.length; k++) {
      const step = path[k];
      if (!this.traveling || this.s.status !== 'playing' || isModalOpen()) break;
      // Tür auf dem Weg: erst öffnen, dann hindurch
      if (tileAt(this.s.map, step.x, step.y) === 'door') {
        if (!this.act(() => moveStep(this.s, step))) break;
        k -= 1;
        await new Promise((r) => setTimeout(r, STEP_MS));
        continue;
      }
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
      await new Promise((r) => setTimeout(r, STEP_MS));
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
    const onPlayer = t.x === s.player.pos.x && t.y === s.player.pos.y;
    const wasInspected = this.inspected && this.inspected.x === t.x && this.inspected.y === t.y;
    if (!onPlayer && !wasInspected && this.worthInspecting(t)) {
      this.inspected = t;
      this.draw();
      this.showCard(t);
      return;
    }
    this.inspected = null;
    if (onPlayer) {
      if (itemsAt(s, t).length) this.act(() => pickup(s));
      else if (onStairs(s)) this.askDescend();
      else this.act(() => wait(s));
      return;
    }
    const isClosedDoor = tileAt(s.map, t.x, t.y) === 'door';
    if (chebyshev(t, s.player.pos) === 1 && (canStep(s.map, s.player.pos, t) || isClosedDoor)) {
      this.act(() => moveStep(s, t));
      return;
    }
    const path = planPath(s, t);
    if (!path?.length) this.say('Dorthin kennst du keinen Weg.');
    // Im Kampf geht es nur Schritt für Schritt voran
    else if (this.inCombat()) this.act(() => moveStep(s, path[0]));
    else this.travel(path);
  }

  /** Felder, die man per Klick erst ansieht, statt sofort loszulaufen. */
  private worthInspecting(t: Pos): boolean {
    const s = this.s;
    const i = idx(s.map, t.x, t.y);
    if (t.x < 0 || t.y < 0 || t.x >= s.map.width || t.y >= s.map.height || !s.map.explored[i]) return false;
    if (!this.visible.has(i)) return false;
    const fu = furnitureAt(s.map, t);
    if (fu) return chebyshev(t, s.player.pos) > 1;
    if (itemsAt(s, t).length || knownTrapAt(s, t) || s.map.tiles[i] === 'stairs') return true;
    return (s.map.tiles[i] === 'door' || s.map.tiles[i] === 'dooropen') && isLairDoor(s, t) && chebyshev(t, s.player.pos) > 1;
  }

  /** Feste Info-Karte am untersuchten Feld. */
  private showCard(t: Pos) {
    const tip = this.root.querySelector('.tooltip') as HTMLElement;
    const html = this.tooltipFor(t, true);
    if (!html || !this.view) return;
    tip.innerHTML = `${html}<div class="tipfoot">Nochmal klicken, um hinzugehen</div>`;
    tip.hidden = false;
    const r = this.canvas.getBoundingClientRect();
    const px = (t.x - this.view.ox + 1) * TILE + 8;
    const py = (t.y - this.view.oy) * TILE;
    const x = px + 290 > r.width ? px - TILE - 300 : px;
    const y = py + tip.offsetHeight > r.height ? r.height - tip.offsetHeight - 8 : py;
    tip.style.left = `${Math.max(4, x)}px`;
    tip.style.top = `${Math.max(4, y)}px`;
  }

  private onHover(e: MouseEvent) {
    if (!this.view) return;
    const t = tileFromMouse(this.view, this.canvas, e);
    if (this.hover && this.hover.x === t.x && this.hover.y === t.y) return;
    this.hover = t;
    this.draw();
    if (this.inspected && (this.inspected.x !== t.x || this.inspected.y !== t.y)) this.inspected = null;
    if (!this.inspected) this.updateTooltip(e);
  }

  private tooltipFor(t: Pos, detail = false): string | null {
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
      parts.push(`Herausforderung: <b style="color:${info.challenge.color}">${esc(info.challenge.name)}</b> <span class="muted small">(${esc(info.challenge.hint)})</span>`);
      parts.push(`${esc(info.health)}${mon.downed > 0 ? ' · <span style="color:#7cc4ff">am Boden</span>' : ''}${mon.asleep ? ' · <span style="color:#6ee07a">schläft</span>' : !mon.aware ? ' · <span style="color:#6ee07a">ahnungslos</span>' : ''}`);
      const conds = conditionList(mon);
      if (conds.length) parts.push(conds.map((c) => `<span style="color:${c.color}">${esc(c.state)} (${c.turns})</span>`).join(' · '));
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
    if (items.length)
      parts.push(items.map((e) => {
        const d = detail ? describeItem(s, e.item) : null;
        const extra = d ? [d.bonuses.join(', '), d.note ?? d.flavor].filter(Boolean).join(' – ') : null;
        return `<span style="color:${RARITY_COLORS[e.item.rarity]}">${esc(itemName(s, e.item))}</span>${extra ? `<br><span class="muted small">${esc(extra)}</span>` : ''}`;
      }).join('<br>'));
    const room = s.map.roomAt[i] >= 0 ? s.map.rooms[s.map.roomAt[i]] : null;
    const fu = furnitureAt(s.map, t);
    if (fu) {
      const FT: Record<string, string> = {
        automat: 'Gratis-Automat – ein Gegenstand pro Crawler', haendler: 'Händler – kaufen, verkaufen, feilschen', wirt: 'Wirt – Essen und ein Zimmer zum Schlafen',
        bett: 'Bett – acht Stunden Schlaf', toilette: 'Toilette – die Regel gilt',
      };
      parts.push(`<b style="color:#9fd0ff">${esc(FT[fu.kind])}</b><br><span class="muted small">Hineinlaufen zum Benutzen</span>`);
    }
    if (s.map.tiles[i] === 'stairs') parts.push('<b style="color:#ffcc33">Treppenhaus nach unten</b>');
    if ((s.map.tiles[i] === 'door' || s.map.tiles[i] === 'dooropen') && isLairDoor(s, t)) parts.push('<b style="color:#ff7a6a">Tür zur Boss-Kammer</b><br><span class="muted small">Sie verriegelt sich hinter dir, bis der Boss besiegt ist.</span>');
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
      const conds = conditionList(mon).map((c) => c.state).join(', ');
      return this.say([`${info.name} (${info.level}, ${INSIGHT_NAMES[info.insight]})`, info.health, conds, info.combat, info.abilities, info.flavor].filter(Boolean).join('. '));
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
      if (e.repeat) return; // Weiterlaufen übernimmt die Animationsschleife
      this.held = { code: e.code, dir };
      this.lastStep = performance.now();
      this.stepDir(dir);
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
    const zone = (Object.entries(ZONE_KEYS) as [HitZone, string][]).find(([, k]) => k.toLowerCase() === e.key.toLowerCase())?.[0];
    if (zone) {
      this.zone = zone;
      this.refreshActions();
      return;
    }
    if (e.key === 'Tab' && this.inCombat()) {
      e.preventDefault();
      const list = this.combatTargets();
      const i = list.findIndex((m) => m.uid === this.targetUid);
      this.targetUid = list[(i + 1) % Math.max(1, list.length)]?.uid ?? null;
      this.refreshActions();
      return;
    }
    if (e.key === 'Enter' && this.inCombat() && this.targetUid && !onStairs(s)) {
      e.preventDefault();
      this.strike(this.targetUid);
      return;
    }
    if (e.code === 'Space' || e.code === 'Numpad5') {
      e.preventDefault();
      this.act(() => wait(s));
    } else if ((e.key === 'f' || e.key === 'F') && currentAbility(s)) {
      this.act(() => useAbility(s, this.technique()));
    } else if ((e.key === 'm' || e.key === 'M') && s.player.mount) {
      this.act(() => rideToggle(s));
    } else if (e.key === 'g' || e.key === 'G') {
      this.act(() => pickup(s));
    } else if (e.key === 'Enter' && onStairs(s)) {
      this.askDescend();
    } else if (e.key === 'k' || e.key === 'K') {
      this.toggleMinimap();
    } else if (e.key === 'h' || e.key === 'H' || e.key === '?') {
      this.showHelp();
    } else if (e.key === '+' || e.key === '=' || e.code === 'NumpadAdd') {
      this.zoomMap(1);
    } else if (e.key === '-' || e.code === 'NumpadSubtract') {
      this.zoomMap(-1);
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
    this.updateCombatMode();
    this.refreshTop();
    this.refreshHere();
    this.refreshSide();
    this.refreshActions();
    this.refreshLog();
  }

  private draw(now = performance.now()) {
    const pathTarget = this.hover;
    let path: Pos[] | null = null;
    if (pathTarget && !this.traveling && !this.held && !monsterAt(this.s, pathTarget) && this.s.status === 'playing') {
      const key = `${pathTarget.x},${pathTarget.y}|${this.s.player.pos.x},${this.s.player.pos.y}|${this.s.turn}`;
      if (this.pathCache.key !== key) {
        const i = idx(this.s.map, pathTarget.x, pathTarget.y);
        const inside = pathTarget.x >= 0 && pathTarget.y >= 0 && pathTarget.x < this.s.map.width && pathTarget.y < this.s.map.height;
        const ok = inside && this.s.map.explored[i] && (isWalkable(this.s.map, pathTarget.x, pathTarget.y) || tileAt(this.s.map, pathTarget.x, pathTarget.y) === 'door');
        this.pathCache = { key, path: ok ? planPath(this.s, pathTarget) : null };
      }
      path = this.pathCache.path;
    }
    const res = render(this.s, this.canvas, { hover: this.hover, path, selected: this.inspected }, this.anim.frame(this.s, now));
    this.view = res.view;
    this.visible = res.visible;
    const room = currentRoom(this.s);
    (this.root.querySelector('.roomlabel') as HTMLElement).textContent = room ? room.name : 'Gang';
    this.drawMinimap();
  }

  /** Übersichtskarte (ab dem Tutorial): nur neu zeichnen, wenn sich Zug oder Größe ändern. */
  private drawMinimap() {
    const wrap = this.root.querySelector('.minimapwrap') as HTMLElement;
    const on = hasUnlock(this.s, 'minimap');
    wrap.hidden = !on;
    if (!on) return;
    wrap.classList.toggle('big', this.minimapBig);
    const key = `${this.s.floor}|${this.s.turn}|${this.s.player.pos.x},${this.s.player.pos.y}|${this.minimapBig}`;
    if (key === this.minimapKey) return;
    this.minimapKey = key;
    renderMinimap(this.s, this.minimap);
  }

  private toggleMinimap() {
    this.minimapBig = !this.minimapBig;
    this.minimapKey = '';
    this.drawMinimap();
  }

  /** Alle Tasten und Bedienhinweise auf einen Blick. */
  private showHelp() {
    const rows: [string, string][] = [
      ['Laufen', 'Klick auf ein bekanntes Feld · Pfeiltasten oder Ziffernblock (gedrückt halten = weiterlaufen)'],
      ['Angreifen', 'Klick auf einen Gegner oder in ihn hineinlaufen · im Kampf Enter'],
      ['Körperteil', '1 Faust · 2 Tritt · 3 Knie · 4 Ellbogen · 5 Kopfstoß · 6 Waffe · 7 Wurf'],
      ['Ausführung', 'Q Normal · W Sprung · E Stampfen · R Anlauf'],
      ['Trefferzone', 'Y Kopf · X Körper · C Arme · V Beine'],
      ['Ziel wechseln', 'Tab'],
      ['Warten', 'Leertaste (wer brennt, wälzt sich am Boden)'],
      ['Aufheben', 'G'],
      ['Treppe nehmen', 'Enter auf der Treppe'],
      ['Klassenfähigkeit', 'F (ab Etage 3)'],
      ['Reittier', 'M'],
      ['Zoom', 'Mausrad · Plus und Minus'],
      ['Übersichtskarte', 'K oder Klick auf die kleine Karte'],
      ['Untersuchen', 'Rechtsklick auf Feld, Gegner oder Gegenstand'],
      ['Text sofort zeigen', 'Klick auf den Text oder das Log'],
      ['Hilfe', 'H'],
    ];
    showHtml('Steuerung', `<div class="helpgrid">${rows.map(([a, b]) => `<b>${esc(a)}</b><span>${esc(b)}</span>`).join('')}</div>`);
  }

  private refreshTop() {
    const s = this.s;
    const def = FLOORS.find((f) => f.floor === s.floor);
    const left = timeLeft(s);
    const p = s.player;
    const pet = p.pet;
    (this.root.querySelector('.topbar') as HTMLElement).innerHTML = `
      <span class="show">${esc(SHOW_NAME)}</span>
      <span class="muted opt">Staffel ${s.season}</span>
      <span>Etage <b>${s.floor}</b>: ${esc(def?.name ?? '')}</span>
      <span class="timer ${left <= 120 ? 'warn' : ''}" title="Zeit bis zum Einsturz">Einsturz in ${formatTime(left)}</span>
      <span class="spacer"></span>
      <span>${esc(p.name)} · Lv <b>${p.level}</b></span>
      ${hasUnlock(s, 'zuschauer') ? `<span class="viewers">Zuschauer ${liveViewers(s).toLocaleString('de-DE')} · Follower ${s.viewers.follower.toLocaleString('de-DE')} · Hype ${Math.round(s.viewers.hype)}</span>` : ''}
      ${hasUnlock(s, 'inventar') ? `<span class="muted opt" title="Lebende Crawler laut letzter Zählung">Crawler übrig ${population(s).alive.toLocaleString('de-DE')}</span>` : ''}
      <span style="color:#ffd700">Gold ${p.gold}</span>
      <button class="soundtoggle" data-action="help" title="Alle Tasten (H)">Hilfe</button>
      <button class="soundtoggle" data-action="sound" title="Klänge für Lootboxen, Level-Aufstieg und Achievements">Ton: ${soundEnabled() ? 'an' : 'aus'}</button>
      <button class="soundtoggle" data-action="typing" title="Weiches Tastenklicken, wenn Texte getippt werden" ${soundEnabled() ? '' : 'disabled'}>Tippen: ${typingSoundEnabled() ? 'an' : 'aus'}</button>
      <span>Lootboxen ${p.boxes.length}</span>
      ${pet ? `<span style="color:#ffb3e6">Haustier ${esc(pet.name)} ${pet.alive ? `${pet.hp}/${pet.maxHp}` : '(bewusstlos)'}</span>` : ''}`;
    bindActions(this.root.querySelector('.topbar') as HTMLElement, {
      sound: () => {
        setSoundEnabled(!soundEnabled());
        if (soundEnabled()) playSfx([{ kind: 'skill' }]);
        this.refreshTop();
      },
      help: () => this.showHelp(),
      typing: () => {
        setTypingSoundEnabled(!typingSoundEnabled());
        if (typingSoundEnabled()) typeClick('taste');
        this.refreshTop();
      },
    });
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
    const doors = adjacentOpenDoors(s);
    if (doors.length) {
      blocks.push(`<div class="row" style="margin:6px 0;gap:4px">${doors.map((d) => `<button data-action="closedoor" data-x="${d.x}" data-y="${d.y}">Tür schließen</button>`).join('')}</div>`);
    }
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
      const furn = room.furniture ?? [];
      const near = (kind: string) => furn.some((f) => f.kind === kind && chebyshev(f.pos, s.player.pos) <= 1);
      const legacy = !furn.length;
      const any = furn.some((f) => chebyshev(f.pos, s.player.pos) <= 1);
      if (inside && !legacy && !any) {
        const names: Record<string, string> = { automat: 'Gratis-Automat', haendler: `Händler (${room.shop?.keeper.split(',')[0] ?? 'Laden'})`, wirt: 'Wirt an der Theke', bett: 'Bett', toilette: 'Toilette' };
        html += `<div class="muted small">Hier gibt es: ${furn.map((f) => esc(names[f.kind])).join(' · ')}. Lauf hinein oder klicke zweimal darauf, um sie zu benutzen.</div>`;
      }
      if (legacy || near('automat')) {
        html += `<div class="subhead">Gratis-Automat</div><div class="row" style="margin-bottom:6px"><button data-action="freebie" ${room.freebieTaken ? 'disabled' : ''}>${room.freebieTaken ? 'Gratis-Gegenstand abgeholt' : 'Gratis-Gegenstand ziehen'}</button></div>`;
      }
      if (room.safeVariant === 'restaurant' && (legacy || near('wirt'))) {
        const host = RESTAURANT_HOSTS[room.id % RESTAURANT_HOSTS.length];
        html += `<div class="subhead">${esc(host.name)} (${esc(host.race)}) serviert</div>`;
        html += RESTAURANT_MENU.map(
          (m) => `<div class="row" style="margin:3px 0"><span style="flex:1">${esc(m.name)} <span class="muted small">${esc(m.effekt.buff?.name ?? '')}</span></span><button data-action="meal" data-id="${m.id}" ${s.player.gold < m.price ? 'disabled' : ''}>${m.price} G</button></div>`,
        ).join('');
        html += `<div class="row" style="margin-top:6px"><button data-action="sleep">Zimmer nehmen und schlafen (8 Std.)</button></div>`;
      }
      if (inside) {
        if (legacy || near('bett')) html += `<div class="row" style="margin-top:6px"><button data-action="sleep">Schlafen (8 Std.)</button></div>`;
        if (legacy || near('toilette')) html += `<div class="row" style="margin-top:6px"><button data-action="toilet">Toilette benutzen</button></div>`;
        if (room.shop && (legacy || near('haendler'))) {
          html += `<div class="subhead">Laden</div><div class="muted small">${esc(room.shop.keeper)}${room.shop.mood < 70 ? ' – wirkt verstimmt' : ''}</div>`;
          html += room.shop.offers
            .map((o, i) => {
              const total = offerPrice(o.price, o.item, s);
              return `<div class="row shoprow"><span style="flex:1;color:${RARITY_COLORS[o.item.rarity]}" title="${esc(describeItem(s, o.item).bonuses.join(', '))}">${esc(itemName(s, o.item))}${o.item.menge && o.item.menge > 1 ? ` ×${o.item.menge}` : ''}</span><span class="muted small">${total} G</span><button data-action="buy" data-i="${i}" ${s.player.gold < total ? 'disabled' : ''}>Kaufen</button><button data-action="haggle" data-i="${i}" ${o.haggled ? 'disabled' : ''}>Feilschen</button></div>`;
            })
            .join('');
          html += '<div class="muted small">Verkaufen: im Inventar-Tab beim Gegenstand.</div>';
          html += this.questHtml(questOf(s, String(room.id)));
        }
        if (s.player.boxes.length) {
          const boxes = s.player.boxes;
          const shown = this.showAllBoxes ? boxes : boxes.slice(0, 3);
          html += `<div class="boxhead"><span>Lootboxen <b>${boxes.length}</b></span>${boxes.length > 1 ? `<button class="primary" data-action="boxall">Alle öffnen</button>` : ''}</div>`;
          html += shown
            .map((b) => `<div class="row boxrow"><span style="flex:1;color:${BOX_TIER_COLORS[b.box!.tier]}">${esc(b.name)}</span><button data-action="box" data-uid="${b.uid}">Öffnen</button></div>`)
            .join('');
          if (boxes.length > 3) html += `<button class="linkbtn" data-action="boxmore">${this.showAllBoxes ? 'Weniger anzeigen' : `${boxes.length - 3} weitere anzeigen`}</button>`;
        }
      }
      blocks.push(html);
    }
    el.innerHTML = blocks.length ? `<div style="padding:4px 12px 8px;border-bottom:1px solid var(--line)">${blocks.join('')}</div>` : '';
    bindActions(el, {
      pick: (b) => this.act(() => pickup(s, b.dataset.uid)),
      disarm: (b) => this.act(() => disarmTrap(s, b.dataset.uid!)),
      closedoor: (b) => this.act(() => closeDoor(s, { x: Number(b.dataset.x), y: Number(b.dataset.y) })),
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
      boxmore: () => {
        this.showAllBoxes = !this.showAllBoxes;
        this.refreshHere();
      },
      boxall: () => {
        const opened: { name: string; items: Item[] }[] = [];
        for (const box of [...s.player.boxes]) {
          let contents: Item[] | undefined;
          const ok = this.act(() => {
            const res = openBox(s, box.uid);
            contents = res.contents;
            return res;
          });
          if (!ok || !contents) break;
          opened.push({ name: box.name, items: contents });
        }
        if (opened.length) this.revealBoxes(opened);
      },
    });
  }

  /** Mehrere Boxen auf einmal: Inhalt nach Box gruppiert. */
  private revealBoxes(list: { name: string; items: Item[] }[]) {
    const html = list
      .map((b, bi) => `<div class="section">${esc(b.name)}</div><div class="reveal">${b.items.map((it, i) => `<div style="animation-delay:${Math.min(2, bi * 0.15 + i * 0.08)}s" class="item">${this.itemHtml(it, false)}</div>`).join('')}</div>`)
      .join('');
    showHtml(`${list.length} Lootboxen geöffnet`, html, 'Super!');
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
      if (from === 'inv' && currentRoom(this.s)?.kind === 'safe' && it.kind !== 'box' && !it.questId) actions.push(`<button data-action="sell" data-uid="${it.uid}">Verkaufen (${sellPrice(it, this.s)} G)</button>`);
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
      ride: () => this.act(() => rideToggle(this.s)),
      refuel: () => this.act(() => refuelMount(this.s)),
      evolve: (b) => this.act(() => evolvePetTo(this.s, b.dataset.id!)),
      'petgear-on': (b) => this.act(() => petGearOn(this.s, b.dataset.uid!)),
      'petgear-off': () => this.act(() => petGearOff(this.s)),
      'sponsor-yes': (b) => this.act(() => acceptSponsorOffer(this.s, b.dataset.id!)),
      'sponsor-no': (b) => this.act(() => declineSponsorOffer(this.s, b.dataset.id!)),
      craft: (b) => this.act(() => craftItem(this.s, b.dataset.id!)),
      throwpick: (b) => this.act(() => chooseThrowable(this.s, b.dataset.id || null)),
      'achv-view': (b) => {
        this.achvView = b.dataset.id === 'statistik' ? 'statistik' : 'erfolge';
        this.refreshSide();
      },
      'achv-cat': (b) => {
        const id = b.dataset.id!;
        if (this.achvOpen.has(id)) this.achvOpen.delete(id);
        else this.achvOpen.add(id);
        this.refreshSide();
      },
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
    const ailments = CONDITION_IDS.filter((id) => playerHas(s, id)).map((id) => CONDITIONS[id].state);
    let html = `<div class="bars">
      <div class="bar hp ${poisoned ? 'poison' : ''}"><div style="width:${(100 * Math.max(0, p.hp)) / mh}%"></div><span>HP ${Math.max(0, p.hp)} / ${mh}${ailments.length ? ` · ${ailments.join(', ')}` : ''}</span></div>
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
    if (p.klass) {
      const k = CLASS_BY_ID[p.klass];
      const r = p.race ? RACE_BY_ID[p.race] : null;
      const specials = [...(r?.specials ?? []), ...(k?.specials ?? [])];
      html += `<div class="section">Klasse und Rasse</div>`;
      if (k) html += `<div class="small"><b>${esc(k.name)}</b> <span class="muted">(${esc(ARCHETYPE_NAMES[k.archetype])})</span> · Fähigkeit: ${esc(ABILITIES[k.ability].name)}</div>`;
      if (p.classSkills?.length) html += `<div class="small muted">Klassenskills: ${p.classSkills.map((id) => esc(SKILL_BY_ID[id]?.name ?? id)).join(', ')}</div>`;
      for (const sp of specials) html += `<div class="small"><b>${esc(SPECIAL_TEXT[sp]?.name ?? sp)}:</b> <span class="muted">${esc(SPECIAL_TEXT[sp]?.text ?? '')}</span></div>`;
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
    if (p.mount) {
      const md = MOUNTS[p.mount.id];
      html += `<div class="section">Reittier</div><div class="small"><b>${esc(p.mount.name)}</b> · ${p.mount.down ? 'erholt sich (schlafen)' : `HP ${p.mount.hp}/${p.mount.maxHp}`}${p.mount.fuel !== undefined ? ` · Tank ${p.mount.fuel}/${md.fuel}` : ''} · Tempo ${md.speed} Schritte pro Zug · Rammen +${md.ram} Schaden${md.ruestung ? ` · +${md.ruestung} Rüstung` : ''}</div>
        <div class="muted small">Beritten: Anlauf rammt ohne Anlauf zu Fuß und kostet nur 1 Ausdauer. Ein Teil der Treffer geht auf das Reittier.</div>
        <div class="row" style="gap:4px;margin:4px 0"><button data-action="ride">${p.riding ? 'Absteigen (M)' : 'Aufsitzen (M)'}</button>${md.kind === 'fahrzeug' ? '<button data-action="refuel">Tanken</button>' : ''}</div>`;
    }
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
    const byCat = new Map<SkillCategory, typeof p.skills>();
    for (const st of p.skills) {
      const def = SKILL_BY_ID[st.id];
      if (!def) continue;
      byCat.set(def.category, [...(byCat.get(def.category) ?? []), st]);
    }
    for (const [cat, list] of byCat) {
      html += `<div class="muted small" style="margin:8px 0 3px;text-transform:uppercase;letter-spacing:1px">${esc(SKILL_CATEGORY_NAMES[cat])}</div>`;
      for (const st of list) {
        const def = SKILL_BY_ID[st.id];
        const need = skillXpNeeded(st.level);
        const max = st.level >= def.maxLevel;
        const cls = p.classSkills?.includes(st.id) ? ' <span class="small" style="color:var(--accent-2)">Klassenskill</span>' : '';
        html += `<div class="skill"><div class="top"><b>${esc(def.name)}</b>${cls}<span>Stufe ${st.level}/${def.maxLevel}</span></div>
          <div class="small" style="color:var(--ok)">Jetzt: ${esc(skillEffectText(def, st.level))}</div>
          ${max ? '<div class="muted small">Gemeistert.</div>' : `<div class="muted small">Nächste Stufe: ${esc(skillEffectText(def, st.level + 1))}</div>`}
          ${hasUnlock(s, 'skills') && !max ? `<div class="progress" title="${Math.floor(st.xp)} von ${need}"><div style="width:${(100 * st.xp) / need}%"></div></div>` : ''}</div>`;
      }
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
    const patterns = s.dynAchievements ?? [];
    const view = this.achvView;
    let html = `<div class="muted small">Diese Staffel: ${done.length + patterns.length} Achievements · Karriere insgesamt: ${this.meta.achievementsEver.length}</div>`;
    html += `<div class="row achvnav"><button data-action="achv-view" data-id="erfolge" class="${view === 'erfolge' ? 'primary' : ''}">Erfolge</button><button data-action="achv-view" data-id="statistik" class="${view === 'statistik' ? 'primary' : ''}">Statistik</button></div>`;
    if (view === 'statistik') return html + this.statsView();

    const card = (a: { name: string; description: string; comment: string; tier?: string }, locked = false) =>
      `<div class="achv${locked ? ' locked-a' : ''}"><div class="n"${a.tier && !locked ? ` style="color:${BOX_TIER_COLORS[a.tier as keyof typeof BOX_TIER_COLORS]}"` : ''}>${esc(a.name)}</div><div class="small">${esc(a.description)}</div>${locked ? '' : `<div class="muted small"><i>${esc(a.comment)}</i></div>`}</div>`;

    // Zuletzt erreicht
    const recent = s.achievements.slice(-4).reverse().map((id) => ACHIEVEMENTS.find((a) => a.id === id)).filter((a): a is (typeof ACHIEVEMENTS)[number] => !!a);
    if (recent.length) html += `<div class="section">Zuletzt erreicht</div>${recent.map((a) => card(a)).join('')}`;

    if (patterns.length) {
      const open = this.achvOpen.has('muster');
      html += `<button class="achvcat" data-action="achv-cat" data-id="muster"><span>${open ? '−' : '+'} Entdeckte Muster</span><span class="muted">${patterns.length}</span></button>`;
      if (open) html += patterns.slice().reverse().map((a) => card(a)).join('');
    }

    const goals = nextGoals(s);
    for (const c of ACHIEVEMENT_CATEGORIES) {
      const all = ACHIEVEMENTS.filter((a) => a.category === c.id);
      const got = all.filter((a) => s.achievements.includes(a.id));
      const open = this.achvOpen.has(c.id);
      html += `<button class="achvcat" data-action="achv-cat" data-id="${c.id}"><span>${open ? '−' : '+'} ${esc(c.name)}</span><span class="muted">${got.length} / ${all.length}</span></button>`;
      html += `<div class="progress" style="margin:-2px 0 6px"><div style="width:${all.length ? (100 * got.length) / all.length : 0}%"></div></div>`;
      if (!open) continue;
      const next = goals
        .filter((g) => g.category === c.id && g.value < g.target)
        .sort((a, b) => b.value / b.target - a.value / a.target)
        .slice(0, 6);
      if (next.length) {
        html += `<div class="muted small" style="margin:4px 0">Nächste Ziele</div>`;
        html += next
          .map((g) => `<div class="skill small"><div class="top"><span>${esc(g.description)}</span><span class="muted goalcount">${g.value.toLocaleString('de-DE')} / ${g.target.toLocaleString('de-DE')}</span></div><div class="progress"><div style="width:${Math.min(100, (100 * g.value) / g.target)}%"></div></div></div>`)
          .join('');
      }
      html += got.slice().reverse().map((a) => card(a)).join('');
      const ever = all.filter((a) => !s.achievements.includes(a.id) && this.meta.achievementsEver.includes(a.id));
      if (ever.length) html += `<div class="muted small" style="margin:4px 0">Aus früheren Staffeln</div>${ever.map((a) => card(a, true)).join('')}`;
      const hidden = all.length - got.length - ever.length;
      if (hidden > 0) html += `<div class="muted small" style="margin:2px 0 8px">Noch ${hidden} geheime Achievements in dieser Kategorie.</div>`;
    }
    return html;
  }

  /** Alles, was der Dungeon über dich mitzählt. */
  private statsView(): string {
    const s = this.s;
    const v = (k: string) => stat(s, k);
    const n = (x: number) => Math.round(x).toLocaleString('de-DE');
    const rows = (title: string, list: [string, string | number][]) => {
      const shown = list.filter(([, x]) => x !== 0 && x !== '0');
      if (!shown.length) return '';
      return `<div class="section">${title}</div>${shown.map(([k, x]) => `<div class="small row statrow"><span style="flex:1">${esc(k)}</span><span class="muted">${typeof x === 'number' ? n(x) : esc(x)}</span></div>`).join('')}`;
    };
    const hits = v('treffer');
    const tries = hits + v('fehlschlaege');
    let html = rows('Kampf', [
      ['Besiegte Gegner', v('kills')],
      ['Treffer', hits],
      ['Trefferquote', tries ? `${Math.round((100 * hits) / tries)} %` : 0],
      ['Kritische Treffer', v('krits')],
      ['Schaden ausgeteilt', v('schaden.ausgeteilt')],
      ['Höchster Einzeltreffer', v('max.treffer')],
      ['Längste Killserie', v('max.killserie')],
      ['Kills ohne erlittenen Treffer (Rekord)', v('max.sauber')],
      ['Gegner zu Boden geworfen', s.counters.knockdowns],
      ['Benommen gemacht', v('zonen.benommen')],
      ['Humpeln lassen', v('zonen.humpelt')],
      ['Geschwächt', v('zonen.geschwaecht')],
      ['Kills durch Konter', v('kills.konter')],
      ['Blutungen zugefügt', v('zustand.blutung')],
      ['Gegner in Brand gesetzt', v('zustand.brennen')],
      ['Gegner vergiftet', v('zustand.gift')],
      ['Gegnern Angst eingejagt', v('zustand.furcht')],
      ['Gegner geblendet', v('zustand.blind')],
      ['Kills an stärkeren Gegnern (3+ Stufen)', v('kills.staerker')],
      ['Kills an schlafenden Gegnern', v('kills.schlafend')],
      ['Kills an fliehenden Gegnern', v('kills.fliehend')],
    ]);
    const PART_LABELS: Record<string, string> = {
      ...PART_NAMES, zauber: 'Zauber', falle: 'Fallen', bombe: 'Sprengsätze', haustier: 'Haustier', party: 'Party', sonstiges: 'Sonstiges',
      blutung: 'Blutung', feuer: 'Feuer', gift: 'Gift',
    };
    const byKey = (prefix: string, label: (id: string) => string) =>
      Object.entries(s.stats ?? {})
        .filter(([k]) => k.startsWith(prefix))
        .sort((a, b) => b[1] - a[1])
        .map(([k, x]) => [label(k.slice(prefix.length)), x] as [string, number]);
    html += rows('Kills nach Angriffsart', byKey('kills.teil.', (id) => PART_LABELS[id] ?? id));
    html += rows('Kills nach Ausführung', byKey('kills.bewegung.', (id) => MOVE_NAMES[id as AttackMove] ?? id));
    html += rows('Kills nach Trefferzone', byKey('kills.zone.', (id) => ZONES[id as HitZone]?.name ?? id));
    // Bestiarium: Namen nur für Arten, die man erkannt hat
    const beasts = byKey('kills.art.', (id) => (v(`bekannt.${id}`) ? monsterDefById(id)?.name ?? id : 'Unbekannte Art')).slice(0, 12);
    html += rows('Bestiarium', [
      ['Verschiedene Arten besiegt', v('bestiarium.arten')],
      ['Elite-Gegner', v('kills.elite')],
      ['Bosse', v('kills.boss')],
      ['Nicht einschätzbare Gegner besiegt', v('kills.unbekannt')],
      ...beasts,
    ]);
    html += rows('Überleben', [
      ['Schaden eingesteckt', v('schaden.erlitten')],
      ['Ausgewichen', v('ausgewichen')],
      ['Knapp überlebt (unter 10 %)', v('knapp.ueberlebt')],
      ['Zustände überstanden', v('zustand.erlitten')],
      ['Tränke getrunken', s.counters.potionsDrunk],
      ['Mahlzeiten', s.counters.mealsEaten],
      ['Geschlafen', v('geschlafen')],
      ['Längste Zeit ohne Schlaf', v('max.wach') ? `${Math.floor((v('max.wach') * 3) / 60)} Std.` : 0],
      ['Toilettenbesuche', v('toilette')],
    ]);
    html += rows('Erkundung', [
      ['Schritte', s.counters.steps],
      ['Räume entdeckt', v('raeume.entdeckt')],
      ['Safe Rooms entdeckt', v('saferooms.entdeckt')],
      ['Türen geöffnet', v('tueren.geoeffnet')],
      ['Türen geschlossen', v('tueren.geschlossen')],
      ['Beste Erkundung einer Etage', v('max.erkundet') ? `${v('max.erkundet')} %` : 0],
      ['Schritte auf dem Reittier', v('reittier.schritte')],
    ]);
    html += rows('Beute und Handel', [
      ['Gegenstände aufgehoben', v('gegenstaende.aufgehoben')],
      ['Boxen geöffnet', v('boxen.geoeffnet')],
      ['Gold verdient', s.counters.goldEarned],
      ['Höchster Goldstand', v('max.gold')],
      ['Gekauft', v('gekauft')],
      ['Gold ausgegeben', v('gold.ausgegeben')],
      ['Verkauft', v('verkauft')],
      ['Preisverhandlungen gewonnen', v('feilschen.gewonnen')],
      ['Rubbellose', v('lose')],
      ['Davon Nieten', v('lose.nieten')],
    ]);
    html += rows('Handwerk und Fallen', [
      ['Hergestellt', s.counters.crafted],
      ['Eigene Fallen aufgestellt', v('fallen.aufgestellt')],
      ['Fallen entdeckt', s.counters.trapsFound],
      ['Fallen entschärft', s.counters.trapsDisarmed],
      ['Selbst in Fallen getreten', s.counters.trapsTriggered],
      ['Aus Fallen befreit', v('befreit')],
      ['Zauber gewirkt', v('zauber.gewirkt')],
    ]);
    html += rows('Andere Crawler und Show', [
      ['Crawler angesprochen', v('crawler.getroffen')],
      ['Party-Beitritte', v('party.beigetreten')],
      ['Party-Mitglieder verloren', v('party.verloren')],
      ['Verletzte Crawler versorgt', v('crawler.geheilt')],
      ['Aufträge erledigt', v('auftraege.erledigt')],
      ['Aufträge verpatzt', v('auftraege.verpatzt')],
      ['Sponsorenwünsche erfüllt', v('sponsor.wuensche')],
      ['Geschenke aus dem Publikum', v('fangeschenke')],
      ['Talkshow-Auftritte', v('talkshows')],
      ['Follower', s.viewers.follower],
    ]);
    return html;
  }

  /** Gegner, die gerade zu sehen sind – nach Entfernung sortiert. */
  private combatTargets() {
    const s = this.s;
    return s.monsters
      .filter((m) => this.visible.has(idx(s.map, m.pos.x, m.pos.y)))
      .sort((a, b) => chebyshev(a.pos, s.player.pos) - chebyshev(b.pos, s.player.pos));
  }

  /**
   * Die Kampfsequenz: 1. womit, 2. wie, 3. wohin, 4. wen. Jede Wahl zeigt,
   * was sie kostet und bewirkt; das Ziel zeigt die Trefferchance für genau
   * diese Kombination.
   */
  private renderCombat(el: HTMLElement) {
    const s = this.s;
    const p = s.player;
    const targets = this.combatTargets();
    if (!targets.some((m) => m.uid === this.targetUid)) this.targetUid = targets[0]?.uid ?? null;
    const tech = this.technique();
    const weapon = currentWeapon(s);
    const throwList = new Map<string, { name: string; n: number; explosive: boolean }>();
    for (const it of throwables(s)) {
      const e = throwList.get(it.baseId) ?? { name: itemName(s, it), n: 0, explosive: !!it.explosion };
      e.n += it.menge ?? 1;
      throwList.set(it.baseId, e);
    }
    const nextThrow = throwables(s)[0]?.baseId;
    const partBtn = (part: Exclude<AttackPart, 'wurf'>) => {
      const disabled = part === 'waffe' && !weapon;
      const label = part === 'waffe' ? weapon?.name ?? 'Waffe' : PART_NAMES[part];
      const sel = this.part === part && !this.pendingSpell;
      return `<button class="${sel ? 'sel' : ''}" data-action="part" data-part="${part}" ${disabled ? 'disabled' : ''}>${esc(label)}<span class="key">${PART_KEYS[part]}</span></button>`;
    };
    const throwBtns = [...throwList.entries()]
      .map(([id, e]) => `<button class="${this.part === 'wurf' && nextThrow === id && !this.pendingSpell ? 'sel' : ''}" data-action="throwsel" data-id="${id}">${esc(e.name)} ×${e.n}${e.explosive ? ' (explodiert)' : ''}</button>`)
      .join('');
    const spells = (p.spells ?? []).map((k) => {
      const def = SPELL_BY_ID[k.id];
      const cd = p.spellCooldowns?.[k.id] ?? 0;
      const cost = spellCost(k.id, this.missileMana);
      const disabled = cd > 0 || (p.mp ?? 0) < cost;
      return `<button class="spell ${this.pendingSpell === k.id ? 'sel' : ''}" data-action="spell" data-spell="${k.id}" ${disabled ? 'disabled' : ''} title="${esc(def.description)}">${esc(def.name)} (${cost} MP)${cd ? ` – ${cd}` : ''}</button>`;
    }).join('');
    const potion = p.inventory.find((i) => i.kind === 'verbrauch' && (i.effekt?.heal || i.effekt?.healPct));
    const ability = currentAbility(s);
    const cd = p.abilityCooldown ?? 0;

    const moveBtn = (move: AttackMove) => {
      const probe = { ...tech, move };
      const target = targets.find((m) => m.uid === this.targetUid);
      const blocker = target ? techniqueBlocker(s, target, probe) : null;
      const disabled = this.part === 'wurf' && move !== 'normal';
      return `<button class="${this.move === move ? 'sel' : ''}" data-action="move" data-move="${move}" ${disabled ? 'disabled' : ''} title="${esc(blocker ?? '')}">${MOVE_NAMES[move]}<span class="key">${MOVE_KEYS[move]}</span> <span class="muted small">· ${attackCost(probe)} Ausdauer</span></button>`;
    };
    const zoneBtn = (zone: HitZone) =>
      `<button class="zone ${this.zone === zone ? 'sel' : ''}" data-action="zone" data-zone="${zone}" title="${esc(ZONES[zone].effekt)}"><b>${ZONES[zone].name}</b><span class="key">${ZONE_KEYS[zone]}</span><br><span class="muted small">${esc(ZONES[zone].effekt)}</span></button>`;

    const targetRows = targets.map((m) => {
      const info = describeMonster(s, m);
      const d = chebyshev(m.pos, p.pos);
      let chance = '';
      let blocker: string | null = null;
      if (this.pendingSpell) {
        const def = SPELL_BY_ID[this.pendingSpell];
        blocker = def.target !== 'gegner' ? 'Dieser Zauber braucht kein Ziel.' : d > (def.range ?? 6) ? 'Zu weit weg für den Zauber.' : null;
        chance = blocker ? '' : 'Zauber trifft sicher';
      } else {
        blocker = techniqueBlocker(s, m, tech);
        chance = blocker ? '' : info.showHitChance ? `${hitChance(s, m, tech)} % Treffer` : 'Trefferchance unklar';
      }
      const state = [m.asleep ? 'schläft' : !m.aware ? 'ahnungslos' : '', m.downed > 0 ? 'am Boden' : '', m.stunned ? 'benommen' : '', m.slowed ? 'humpelt' : '', m.weakened ? 'geschwächt' : ''].filter(Boolean).join(', ');
      const conds = conditionList(m).map((c) => `<span style="color:${c.color}">${esc(c.state)}</span>`).join(', ');
      const sel = m.uid === this.targetUid;
      return `<div class="target ${sel ? 'sel' : ''}" data-action="target" data-uid="${m.uid}">
        <div><b style="color:${info.insight >= 3 ? '#b0a898' : m.color}">${esc(info.name)}</b> <span class="muted small">${esc(info.level)} · ${d} ${d === 1 ? 'Feld' : 'Felder'}</span> <span class="small" style="color:${info.challenge.color}">${esc(info.challenge.name)}</span></div>
        <div class="small">${esc(info.health)}${state ? ` · <span style="color:#7cc4ff">${esc(state)}</span>` : ''}${conds ? ` · ${conds}` : ''}</div>
        <div class="row" style="gap:6px;align-items:center"><span class="small" style="flex:1;color:${blocker ? 'var(--muted)' : 'var(--ok)'}">${esc(blocker ?? chance)}</span>
        <button class="primary" data-action="strike" data-uid="${m.uid}" ${blocker ? 'disabled' : ''}>${this.pendingSpell ? 'Zaubern' : 'Angreifen'}</button></div>
      </div>`;
    }).join('');

    el.innerHTML = `<div class="combat">
      <div class="col"><div class="h">1 · Womit?</div>
        <div class="btns">${(['faust', 'tritt', 'knie', 'ellbogen', 'kopf', 'waffe'] as const).map(partBtn).join('')}</div>
        ${throwBtns ? `<div class="sub">Werfen <span class="key">7</span></div><div class="btns">${throwBtns}</div>` : ''}
        ${spells ? `<div class="sub">Zauber (${p.mp ?? 0} MP)</div><div class="btns spells">${spells}</div>` : ''}
        <div class="sub">Sonstiges</div><div class="btns">
          <button data-action="defend" title="Bis zum nächsten Zug +20 % Ausweichen, +2 Rüstung, +2 Ausdauer">Deckung</button>
          ${potion ? `<button data-action="use" data-uid="${potion.uid}">${esc(itemName(s, potion))} trinken</button>` : ''}
          ${ability ? `<button class="ability" data-action="ability" ${cd ? 'disabled' : ''} title="${esc(ability.description)}">${esc(ability.name)}${cd ? ` (${cd})` : ''}<span class="key">F</span></button>` : ''}
          <button data-action="wait">Warten</button>
        </div>
      </div>
      <div class="col"><div class="h">2 · Wie?</div><div class="btns vert">${ATTACK_MOVES.map(moveBtn).join('')}</div>
        <div class="muted small" style="margin-top:6px">Ausdauer ${p.ausdauer}/${maxAusdauer(s)}</div></div>
      <div class="col"><div class="h">3 · Wohin?</div><div class="btns vert">${HIT_ZONES.map(zoneBtn).join('')}</div></div>
      <div class="col targets"><div class="h">4 · Wen? <span class="muted small">(Tab wechselt, Enter greift an)</span></div>${targetRows || '<div class="muted small">Kein Gegner in Sicht.</div>'}</div>
    </div>
    <div class="combat-summary small">KAMPF · Gewählt: <b style="color:var(--accent)">${esc(this.pendingSpell ? SPELL_BY_ID[this.pendingSpell].name : techniqueName(tech))}</b>${this.pendingSpell ? '' : ` · ${attackCost(tech)} Ausdauer`} · Bewegen mit Pfeiltasten oder Klick auf die Karte</div>`;
    bindActions(el, {
      part: (b) => {
        this.pendingSpell = null;
        this.part = b.dataset.part as AttackPart;
        if (this.part !== 'tritt' && this.move === 'stampfen') this.move = 'normal';
        this.refreshActions();
      },
      throwsel: (b) => {
        this.pendingSpell = null;
        chooseThrowable(s, b.dataset.id!);
        this.part = 'wurf';
        this.move = 'normal';
        this.refreshActions();
      },
      move: (b) => {
        this.move = b.dataset.move as AttackMove;
        if (this.move === 'stampfen') this.part = 'tritt';
        this.refreshActions();
      },
      zone: (b) => {
        this.zone = b.dataset.zone as HitZone;
        this.refreshActions();
      },
      spell: (b) => {
        const id = b.dataset.spell!;
        if (SPELL_BY_ID[id].target === 'selbst') {
          this.pendingSpell = null;
          this.act(() => cast(s, id));
          return;
        }
        this.pendingSpell = this.pendingSpell === id ? null : id;
        this.refreshActions();
      },
      target: (b) => {
        this.targetUid = b.dataset.uid!;
        this.refreshActions();
      },
      strike: (b) => this.strike(b.dataset.uid!),
      defend: () => this.act(() => defend(s)),
      use: (b) => this.act(() => useItem(s, b.dataset.uid!)),
      ability: () => this.act(() => useAbility(s, this.technique())),
      wait: () => this.act(() => wait(s)),
    });
  }

  /** Angriff (oder Zauber) auf ein Ziel aus der Kampfsequenz. */
  private strike(uid: string) {
    this.targetUid = uid;
    if (this.pendingSpell) {
      const sp = this.pendingSpell;
      this.pendingSpell = null;
      const m = this.s.monsters.find((x) => x.uid === uid);
      this.act(() => cast(this.s, sp, { targetUid: uid, pos: m?.pos, mana: this.missileMana }));
      return;
    }
    this.attackMonster(uid);
  }

  private refreshActions() {
    const s = this.s;
    const el = this.root.querySelector('.actionbar') as HTMLElement;
    el.classList.toggle('in-combat', this.inCombat());
    if (this.inCombat()) {
      this.renderCombat(el);
      return;
    }
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
      ${ability ? `<div class="grp"><button class="ability" data-action="ability" ${cd ? 'disabled' : ''} title="Taste F · ${esc(ability.description)}">Fähigkeit: ${esc(ability.name)}${cd ? ` (${cd})` : ''}<span class="key">F</span></button></div>` : ''}
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
      else {
        p.classList.add('pending');
        this.typer.push(text, esc(l.text));
      }
    }
    this.lastLogId = entries[entries.length - 1]?.id ?? this.lastLogId;
    while (el.childElementCount > 150) el.firstElementChild?.remove();
    el.scrollTop = el.scrollHeight;
  }
}
