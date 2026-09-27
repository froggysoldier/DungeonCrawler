import type { AchievementCategory, AchievementDef } from './achievements';
import { RECIPES } from './crafting';
import { MONSTERS } from './monsters';
import type { BoxTier, BoxType, GameState } from '../engine/types';

/**
 * Gestufte Achievements: Für fast alles, was man tun kann, gibt es eine
 * Familie mit mehreren Stufen. Die Werte kommen aus der Statistik
 * (engine/stats.ts) oder direkt aus dem Spielzustand.
 *
 * Stufen ohne Box-Stufe (tier: null) bringen nur Ruhm beim Publikum.
 */
interface Stage {
  n: number;
  name: string;
  tier: BoxTier | null;
  comment?: string;
}

interface Family {
  id: string;
  category: AchievementCategory;
  box: BoxType;
  /** Beschreibung; {n} wird durch den Schwellwert ersetzt. */
  text: string;
  value: (s: GameState) => number;
  stages: Stage[];
}

/** Wert aus der Statistik; der Schlüssel hängt an der Funktion (für den Godot-Export). */
const st = (key: string) => Object.assign((s: GameState) => s.stats?.[key] ?? 0, { statKey: key });

const COMMENTS: Record<AchievementCategory, string[]> = {
  kampf: [
    'Die Systemstimme führt Buch. Die Seite mit deinem Namen wird dicker.',
    'Die Monster haben eine Gewerkschaft gegründet. Du bist Thema der nächsten Sitzung.',
    'Blut, Schweiß und Statistik. Vor allem Statistik.',
    'Irgendwo in der Galaxis wettet jemand auf dich. Er gewinnt gerade.',
  ],
  technik: [
    'Übung macht den Meister. Und den Gegner platt.',
    'Die Zuschauer erkennen deinen Stil schon am Geräusch.',
    'Du hast eine Handschrift. Sie ist rot und klebrig.',
  ],
  bestiarium: [
    'Ein neuer Eintrag im Bestiarium. Die Art findet das weniger lustig.',
    'Die Systemstimme ergänzt die Akte. Vermerk: gefährlich, aber nicht für dich.',
    'Die Naturkundler der Galaxis danken für die Feldforschung.',
  ],
  erkundung: [
    'Neugier ist eine Tugend. Bis sie Zähne hat.',
    'Die Karte wächst. Deine Füße schmerzen.',
    'Irgendwo hinter der nächsten Ecke wartet etwas. Du gehst trotzdem.',
  ],
  beute: [
    'Das Inventar platzt aus allen Nähten. Die Systemstimme ist stolz.',
    'Glänzende Dinge! Deine Elstergene melden sich.',
  ],
  wirtschaft: [
    'Die Wirtschaft des Dungeons dankt für deine Mitarbeit.',
    'Geld stinkt nicht. Im Gegensatz zu allem anderen hier unten.',
  ],
  ueberleben: [
    'Du lebst noch. Das ist die einzige Statistik, die wirklich zählt.',
    'Dein Körper ist ein Flickenteppich. Ein sehr zäher Flickenteppich.',
  ],
  magie: [
    'Die Magie mag dich. Oder sie hat Angst vor dir.',
    'Deine Finger riechen nach Ozon und Selbstüberschätzung.',
  ],
  handwerk: [
    'Aus Müll wird Ausrüstung. Die Systemstimme nennt das Nachhaltigkeit.',
    'Werkbank, Klebeband, Wahnsinn. Die heilige Dreifaltigkeit des Kellers.',
  ],
  sozial: [
    'Du bist nicht allein da unten. Das ist gut. Meistens.',
    'Freundschaften im Dungeon halten ewig. Also bis zum nächsten Kobold.',
  ],
  show: [
    'Die Einschaltquote steigt. Deine Überlebenschance nicht zwingend.',
    'Die Galaxis schaut hin. Lächeln!',
  ],
  fortschritt: [
    'Du wirst besser. Die Monster auch. Es bleibt spannend.',
    'Stufe um Stufe nach oben, Etage um Etage nach unten.',
  ],
  momente: ['Manche Dinge passieren nur einmal. Zum Glück.'],
};

/** Eigene Namen für das erste Herstellen eines Rezepts. */
const RECIPE_NAMES: Record<string, string> = {
  verband: 'Sani-Kasten', brandflasche: 'Cocktailstunde', nagelbombe: 'Doseninhalt: Ärger', stachelfalle: 'Spitze Idee',
  schlingfalle: 'Die Schlaufe', sprengfalle: 'Überraschungsei', waffe_naegel: 'Nagelprobe',
};

const FAMILIES: Family[] = [
  // ============================================================ Kampf
  {
    id: 'kills', category: 'kampf', box: 'abenteurer', text: 'Besiege insgesamt {n} Gegner.', value: st('kills'),
    stages: [
      { n: 250, name: 'Vierteltausend', tier: 'silber' },
      { n: 500, name: 'Kellerplage', tier: 'gold', comment: 'Fünfhundert. Die Monsterversicherung hat dich als Naturkatastrophe eingestuft.' },
      { n: 1000, name: 'Tausend und kein Ende', tier: 'platin' },
    ],
  },
  {
    id: 'krits', category: 'kampf', box: 'brawler', text: 'Lande {n} kritische Treffer.', value: st('krits'),
    stages: [
      { n: 100, name: 'Präzisionsuhrwerk', tier: 'silber' },
      { n: 300, name: 'Chirurgie des Chaos', tier: 'gold' },
    ],
  },
  {
    id: 'schaden', category: 'kampf', box: 'brawler', text: 'Teile insgesamt {n} Schaden aus.', value: st('schaden.ausgeteilt'),
    stages: [
      { n: 500, name: 'Schadensbilanz', tier: 'bronze' },
      { n: 2500, name: 'Abrissunternehmen', tier: 'silber' },
      { n: 10000, name: 'Naturgewalt', tier: 'gold' },
    ],
  },
  {
    id: 'maxtreffer', category: 'kampf', box: 'brawler', text: 'Richte mit einem einzigen Treffer {n} Schaden an.', value: st('max.treffer'),
    stages: [
      { n: 50, name: 'Einschlag', tier: 'silber' },
      { n: 100, name: 'Abrissbirne', tier: 'gold' },
      { n: 200, name: 'Weltuntergang im Kleinen', tier: 'platin', comment: 'Zweihundert Schaden. Mit einem Schlag. Die Physikabteilung der Show hat gekündigt.' },
    ],
  },
  {
    id: 'killserie', category: 'kampf', box: 'brawler', text: 'Besiege {n} Gegner kurz hintereinander.', value: st('max.killserie'),
    stages: [
      { n: 2, name: 'Doppelschlag', tier: 'bronze' },
      { n: 3, name: 'Hattrick', tier: 'silber' },
      { n: 5, name: 'Schlachtfest', tier: 'gold', comment: 'Fünf in Folge. Die Putzkolonne hat Überstunden beantragt.' },
    ],
  },
  {
    id: 'sauber', category: 'kampf', box: 'ueberlebens', text: 'Besiege {n} Gegner, ohne zwischendurch getroffen zu werden.', value: st('max.sauber'),
    stages: [
      { n: 5, name: 'Unberührt', tier: 'bronze' },
      { n: 15, name: 'Unantastbar', tier: 'silber' },
      { n: 30, name: 'Kein Kratzer', tier: 'gold' },
    ],
  },
  {
    id: 'staerker', category: 'kampf', box: 'brawler', text: 'Besiege {n} Gegner, die mindestens drei Stufen über dir stehen.', value: st('kills.staerker'),
    stages: [
      { n: 10, name: 'Goliath-Serie', tier: 'silber' },
      { n: 50, name: 'Gegen den Strom', tier: 'gold' },
    ],
  },
  {
    id: 'harmlos', category: 'kampf', box: 'abenteurer', text: 'Besiege {n} Gegner, die weit unter deiner Stufe stehen.', value: st('kills.harmlos'),
    stages: [
      { n: 25, name: 'Mobbing', tier: null, comment: 'Die Kleinen verprügeln. Sehr heldenhaft. Die Zuschauer buhen leise.' },
      { n: 100, name: 'Kleinkrieg', tier: null, comment: 'Erfahrung gibt das keine mehr. Nur schlechte Presse.' },
    ],
  },
  {
    id: 'schlafend', category: 'kampf', box: 'abenteurer', text: 'Besiege {n} schlafende Gegner.', value: st('kills.schlafend'),
    stages: [
      { n: 1, name: 'Gute Nacht', tier: 'bronze' },
      { n: 10, name: 'Sandmännchen', tier: 'silber' },
      { n: 40, name: 'Schlafende Hunde', tier: 'gold', comment: 'Man soll sie nicht wecken. Du weckst sie auch nicht. Nie wieder.' },
    ],
  },
  {
    id: 'fliehend', category: 'kampf', box: 'wurf', text: 'Besiege {n} fliehende Gegner.', value: st('kills.fliehend'),
    stages: [
      { n: 1, name: 'Kein Entkommen', tier: 'bronze' },
      { n: 10, name: 'Kopfgeldjagd', tier: 'silber' },
    ],
  },
  {
    id: 'liegend', category: 'kampf', box: 'schuh', text: 'Besiege {n} Gegner, die am Boden liegen.', value: st('kills.liegend'),
    stages: [
      { n: 10, name: 'Nachtreten', tier: 'bronze' },
      { n: 50, name: 'Bodenpersonal', tier: 'silber' },
      { n: 150, name: 'Wer liegt, der liegt', tier: 'gold' },
    ],
  },
  {
    id: 'fasttot', category: 'kampf', box: 'ueberlebens', text: 'Besiege {n} Gegner mit weniger als 20 % deiner Lebenspunkte.', value: st('kills.fasttot'),
    stages: [
      { n: 5, name: 'Mit dem Rücken zur Wand', tier: 'silber' },
      { n: 25, name: 'Todesmutig', tier: 'gold' },
    ],
  },
  {
    id: 'umwerfen', category: 'kampf', box: 'schuh', text: 'Wirf {n} Gegner zu Boden.', value: (s) => s.counters.knockdowns,
    stages: [
      { n: 50, name: 'Fallobst', tier: 'silber' },
      { n: 150, name: 'Schwerkraftbehörde', tier: 'gold' },
    ],
  },
  // ============================================================ Technik
  ...partFamily('faust', 'Faustschlägen', 'brawler', ['Knöchelknacken', 'Faustrecht', 'Die Faust im Keller'], [25, 100, 300]),
  ...partFamily('tritt', 'Tritten', 'schuh', ['Fußarbeit', 'Spann und Spitze', 'Der Tritt des Jahrhunderts'], [25, 100, 300]),
  ...partFamily('knie', 'Kniestößen', 'brawler', ['Kniebeuge', 'Kniescheibenreich', 'Das Knie des Schicksals'], [25, 100, 250]),
  ...partFamily('ellbogen', 'Ellbogenchecks', 'brawler', ['Spitze Argumente', 'Ellbogenmentalität', 'Ellbogen aus Stahl'], [25, 100, 250]),
  ...partFamily('kopf', 'Kopfstößen', 'kleidung', ['Stirnrunzeln', 'Harter Schädel', 'Der Kopf ist rund'], [25, 100, 250]),
  ...partFamily('waffe', 'Waffenhieben', 'waffen', ['Werkzeugkasten', 'Improvisationstalent', 'Waffenkammer'], [25, 100, 300]),
  ...partFamily('wurf', 'Würfen', 'wurf', ['Wurfarm', 'Artillerie', 'Katapult auf zwei Beinen'], [25, 100, 250]),
  ...partFamily('zauber', 'Zaubern', 'abenteurer', ['Zauberlehrling', 'Hexerei', 'Arkaner Albtraum'], [5, 25, 100]),
  ...partFamily('falle', 'eigenen Fallen', 'ueberlebens', ['Stolperfalle', 'Fallenstellerei', 'Hohe Schule der Hinterlist'], [3, 15, 50]),
  ...partFamily('bombe', 'Sprengsätzen', 'wurf', ['Feuerwerk', 'Sprengkommando', 'Zündfreudig'], [3, 15, 50]),
  ...partFamily('haustier', 'deinem Haustier', 'haustier', ['Kleine Hilfe', 'Rudeltier', 'Bestie an der Leine'], [5, 25, 100]),
  ...partFamily('blutung', 'Blutungen', 'waffen', ['Aderlass', 'Blutspur', 'Rote Flut'], [5, 25, 75]),
  ...partFamily('feuer', 'Flammen', 'wurf', ['Lagerfeuer', 'Flächenbrand', 'Inferno'], [5, 25, 75]),
  ...partFamily('gift', 'Gift', 'ueberlebens', ['Giftschrank', 'Schleichendes Ende', 'Giftküche'], [5, 25, 75]),
  {
    id: 'furcht', category: 'technik', box: 'fan', text: 'Jage Gegnern {n}-mal Angst ein.', value: st('zustand.furcht'),
    stages: [
      { n: 10, name: 'Gruselfaktor', tier: 'bronze' },
      { n: 50, name: 'Schreckgespenst', tier: 'silber' },
    ],
  },
  {
    id: 'blenden', category: 'technik', box: 'wurf', text: 'Blende Gegner {n}-mal.', value: st('zustand.blind'),
    stages: [
      { n: 10, name: 'Sand in die Augen', tier: 'bronze' },
      { n: 50, name: 'Blendwerk', tier: 'silber' },
    ],
  },
  {
    id: 'aufschlitzen', category: 'technik', box: 'waffen', text: 'Füge Gegnern {n}-mal eine Blutung zu.', value: st('zustand.blutung'),
    stages: [
      { n: 25, name: 'Schnittmuster', tier: 'bronze' },
      { n: 100, name: 'Metzgerei', tier: 'silber' },
    ],
  },
  {
    id: 'anzuenden', category: 'technik', box: 'wurf', text: 'Setze Gegner {n}-mal in Brand.', value: st('zustand.brennen'),
    stages: [
      { n: 10, name: 'Zündler', tier: 'bronze' },
      { n: 50, name: 'Feuerteufel', tier: 'silber' },
    ],
  },
  ...partFamily('party', 'deiner Party', 'abenteurer', ['Teamwork', 'Truppführung', 'Kommandostab'], [5, 25, 100]),
  {
    id: 'konter', category: 'technik', box: 'brawler', text: 'Besiege {n} Gegner mit einem Konter.', value: st('kills.konter'),
    stages: [
      { n: 3, name: 'Retourkutsche', tier: 'silber' },
      { n: 15, name: 'Konterkunst', tier: 'gold' },
    ],
  },
  ...moveFamily('sprung', 'Sprungangriffen', ['Luftnummer', 'Adlerschwinge', 'Kellerkomet'], [10, 50, 150]),
  ...moveFamily('stampfen', 'Stampfern', ['Trampelpfad', 'Dampfwalze'], [50, 150]),
  ...moveFamily('anlauf', 'Sturmangriffen', ['Rammbock', 'Güterzug'], [25, 100]),
  {
    id: 'zone_kopf', category: 'technik', box: 'kleidung', text: 'Besiege {n} Gegner mit einem gezielten Kopftreffer.', value: st('kills.zone.kopf'),
    stages: [
      { n: 5, name: 'Kopfsache', tier: 'bronze' },
      { n: 25, name: 'Kopfjagd', tier: 'silber' },
      { n: 100, name: 'Kopfgeld eingetrieben', tier: 'gold' },
    ],
  },
  {
    id: 'zone_beine', category: 'technik', box: 'schuh', text: 'Besiege {n} Gegner mit einem Treffer auf die Beine.', value: st('kills.zone.beine'),
    stages: [
      { n: 5, name: 'Beinarbeit', tier: 'bronze' },
      { n: 25, name: 'Kniescheibenjagd', tier: 'silber' },
    ],
  },
  {
    id: 'zone_arme', category: 'technik', box: 'brawler', text: 'Besiege {n} Gegner mit einem Treffer auf die Arme.', value: st('kills.zone.arme'),
    stages: [
      { n: 5, name: 'Armdrücken', tier: 'bronze' },
      { n: 25, name: 'Entwaffnend', tier: 'silber' },
    ],
  },
  {
    id: 'benommen', category: 'technik', box: 'brawler', text: 'Mache Gegner {n}-mal benommen.', value: st('zonen.benommen'),
    stages: [
      { n: 5, name: 'Sternchen sehen', tier: 'bronze' },
      { n: 25, name: 'Glockenläuten', tier: 'silber' },
      { n: 100, name: 'Knockout-Kunst', tier: 'gold' },
    ],
  },
  {
    id: 'humpeln', category: 'technik', box: 'schuh', text: 'Lass Gegner {n}-mal humpeln.', value: st('zonen.humpelt'),
    stages: [
      { n: 10, name: 'Humpelnde Horde', tier: 'bronze' },
      { n: 50, name: 'Orthopädie', tier: 'silber' },
    ],
  },
  {
    id: 'schwaechen', category: 'technik', box: 'brawler', text: 'Schwäche Gegner {n}-mal durch Armtreffer.', value: st('zonen.geschwaecht'),
    stages: [
      { n: 10, name: 'Schwächling!', tier: 'bronze' },
      { n: 50, name: 'Armenhaus', tier: 'silber' },
    ],
  },
  // ============================================================ Bestiarium
  {
    id: 'bestiarium', category: 'bestiarium', box: 'abenteurer', text: 'Besiege {n} verschiedene Monsterarten.', value: st('bestiarium.arten'),
    stages: [
      { n: 10, name: 'Hobby-Zoologie', tier: 'bronze' },
      { n: 20, name: 'Feldforschung des Grauens', tier: 'silber' },
      { n: 30, name: 'Kellerbiologie', tier: 'gold' },
      { n: 45, name: 'Wandelndes Monsterlexikon', tier: 'platin', comment: 'Die Systemstimme hat dir eine Kopie des Bestiariums geschickt. Du kennst es schon auswendig.' },
    ],
  },
  {
    id: 'elite_viel', category: 'bestiarium', box: 'waffen', text: 'Besiege {n} Elite-Gegner.', value: st('kills.elite'),
    stages: [
      { n: 10, name: 'Elitetruppe', tier: 'gold' },
      { n: 25, name: 'Elitenschreck', tier: 'platin' },
    ],
  },
  // ============================================================ Erkundung
  {
    id: 'raeume', category: 'erkundung', box: 'abenteurer', text: 'Betritt {n} verschiedene Räume.', value: st('raeume.entdeckt'),
    stages: [
      { n: 10, name: 'Neugierig', tier: null },
      { n: 25, name: 'Stadtrundgang', tier: 'bronze' },
      { n: 60, name: 'Kellerkunde', tier: 'silber' },
      { n: 120, name: 'Wandelnde Karte', tier: 'gold' },
    ],
  },
  {
    id: 'erkundet', category: 'erkundung', box: 'abenteurer', text: 'Erkunde {n} % einer Etage.', value: st('max.erkundet'),
    stages: [
      { n: 50, name: 'Halbe Sachen', tier: 'bronze' },
      { n: 75, name: 'Gründlich', tier: 'silber' },
      { n: 95, name: 'Jeder Winkel', tier: 'gold', comment: 'Jede Ecke, jede Nische, jede tote Ratte. Kartografen weinen vor Rührung.' },
    ],
  },
  {
    id: 'tueren', category: 'erkundung', box: 'abenteurer', text: 'Öffne {n} Türen.', value: st('tueren.geoeffnet'),
    stages: [
      { n: 1, name: 'Klinkenputzen', tier: null },
      { n: 10, name: 'Türöffner', tier: 'bronze' },
      { n: 30, name: 'Schlüsseldienst', tier: 'silber' },
    ],
  },
  {
    id: 'schritte', category: 'erkundung', box: 'schuh', text: 'Lege {n} Schritte zurück.', value: (s) => s.counters.steps,
    stages: [
      { n: 1000, name: 'Spaziergang', tier: 'bronze' },
      { n: 5000, name: 'Wanderschuhe', tier: 'silber' },
      { n: 20000, name: 'Marathon im Keller', tier: 'gold' },
    ],
  },
  {
    id: 'saferooms', category: 'erkundung', box: 'ueberlebens', text: 'Entdecke {n} Safe Rooms.', value: st('saferooms.entdeckt'),
    stages: [
      { n: 3, name: 'Stammgast', tier: 'bronze' },
      { n: 10, name: 'Ruhepol', tier: 'silber' },
    ],
  },
  // ============================================================ Beute
  {
    id: 'aufheben', category: 'beute', box: 'abenteurer', text: 'Hebe {n} Gegenstände auf.', value: st('gegenstaende.aufgehoben'),
    stages: [
      { n: 60, name: 'Sammelleidenschaft', tier: 'bronze' },
      { n: 200, name: 'Messie', tier: 'silber' },
      { n: 500, name: 'Hamster des Untergangs', tier: 'gold' },
    ],
  },
  {
    id: 'boxen', category: 'beute', box: 'abenteurer', text: 'Öffne {n} Lootboxen.', value: st('boxen.geoeffnet'),
    stages: [
      { n: 50, name: 'Kistenstapel', tier: 'silber' },
      { n: 100, name: 'Unboxing-Profi', tier: 'gold' },
    ],
  },
  ...boxTierFamily(),
  {
    id: 'episch', category: 'beute', box: 'waffen', text: 'Finde {n} epische Gegenstände.', value: st('fund.episch'),
    stages: [
      { n: 1, name: 'Episches Fundstück', tier: 'silber' },
      { n: 5, name: 'Epische Sammlung', tier: 'gold' },
    ],
  },
  // ============================================================ Wirtschaft
  {
    id: 'ausgegeben', category: 'wirtschaft', box: 'abenteurer', text: 'Gib {n} Gold in Läden aus.', value: st('gold.ausgegeben'),
    stages: [
      { n: 100, name: 'Konsumrausch', tier: 'bronze' },
      { n: 500, name: 'Stammkundschaft', tier: 'silber' },
      { n: 2000, name: 'Wirtschaftsmotor', tier: 'gold' },
    ],
  },
  {
    id: 'verkauft', category: 'wirtschaft', box: 'abenteurer', text: 'Verkaufe {n} Gegenstände.', value: st('verkauft'),
    stages: [
      { n: 10, name: 'Flohmarkt', tier: 'bronze' },
      { n: 50, name: 'Händlerseele', tier: 'silber' },
      { n: 150, name: 'Ramschparadies', tier: 'gold' },
    ],
  },
  {
    id: 'gekauft', category: 'wirtschaft', box: 'abenteurer', text: 'Kaufe {n} Gegenstände.', value: st('gekauft'),
    stages: [
      { n: 5, name: 'Kundenkarte', tier: 'bronze' },
      { n: 25, name: 'Shoppingtour', tier: 'silber' },
    ],
  },
  {
    id: 'feilschen', category: 'wirtschaft', box: 'abenteurer', text: 'Gewinne {n} Preisverhandlungen.', value: st('feilschen.gewonnen'),
    stages: [
      { n: 3, name: 'Handeln lernen', tier: 'bronze' },
      { n: 15, name: 'Basarfuchs', tier: 'silber' },
      { n: 40, name: 'Rabattschlacht', tier: 'gold' },
    ],
  },
  {
    id: 'lose', category: 'wirtschaft', box: 'fan', text: 'Versuche dein Glück {n}-mal mit einem Rubbellos.', value: st('lose'),
    stages: [
      { n: 5, name: 'Glücksspiel', tier: 'bronze' },
      { n: 25, name: 'Rubbelfinger', tier: 'silber' },
    ],
  },
  {
    id: 'gold_verdient', category: 'wirtschaft', box: 'abenteurer', text: 'Verdiene insgesamt {n} Gold.', value: (s) => s.counters.goldEarned,
    stages: [
      { n: 1500, name: 'Goldader', tier: 'silber' },
      { n: 5000, name: 'Schatzkammer', tier: 'gold' },
    ],
  },
  // ============================================================ Überleben
  {
    id: 'erlitten', category: 'ueberleben', box: 'ueberlebens', text: 'Stecke insgesamt {n} Schaden ein.', value: st('schaden.erlitten'),
    stages: [
      { n: 500, name: 'Nehmerqualitäten', tier: 'bronze' },
      { n: 2000, name: 'Prellbock', tier: 'silber' },
      { n: 5000, name: 'Unkaputtbar', tier: 'gold' },
    ],
  },
  {
    id: 'ausweichen', category: 'ueberleben', box: 'schuh', text: 'Weiche {n} Angriffen aus.', value: st('ausgewichen'),
    stages: [
      { n: 25, name: 'Flink', tier: 'bronze' },
      { n: 100, name: 'Aalglatt', tier: 'silber' },
      { n: 300, name: 'Schwer zu fassen', tier: 'gold' },
    ],
  },
  {
    id: 'knapp', category: 'ueberleben', box: 'ueberlebens', text: 'Überlebe {n}-mal einen Treffer mit weniger als 10 % Lebenspunkten.', value: st('knapp.ueberlebt'),
    stages: [
      { n: 3, name: 'Dem Tod von der Schippe', tier: 'silber' },
      { n: 15, name: 'Dauerkarte beim Sensenmann', tier: 'gold' },
    ],
  },
  {
    id: 'traenke', category: 'ueberleben', box: 'ueberlebens', text: 'Trinke {n} Tränke.', value: (s) => s.counters.potionsDrunk,
    stages: [
      { n: 30, name: 'Tränkeparade', tier: 'silber' },
      { n: 100, name: 'Wandelnde Hausapotheke', tier: 'gold' },
    ],
  },
  {
    id: 'mahlzeiten', category: 'ueberleben', box: 'ueberlebens', text: 'Iss {n} Mahlzeiten.', value: (s) => s.counters.mealsEaten,
    stages: [
      { n: 20, name: 'Guter Appetit', tier: 'bronze' },
      { n: 50, name: 'Vielfraß', tier: 'silber' },
    ],
  },
  {
    id: 'toilette', category: 'ueberleben', box: 'kleidung', text: 'Benutze {n}-mal eine Toilette.', value: st('toilette'),
    stages: [
      { n: 1, name: 'Geschäftsbesuch', tier: null },
      { n: 10, name: 'Stammgast der Kacheln', tier: 'bronze' },
      { n: 25, name: 'Porzellanthron', tier: 'silber', comment: 'Die Regel ist dir heilig. Die Systemstimme ist beeindruckt und ein bisschen besorgt.' },
    ],
  },
  {
    id: 'fallen_gefunden', category: 'ueberleben', box: 'ueberlebens', text: 'Entdecke {n} Fallen.', value: (s) => s.counters.trapsFound,
    stages: [
      { n: 5, name: 'Spürnase', tier: 'bronze' },
      { n: 20, name: 'Fallensuche', tier: 'silber' },
      { n: 50, name: 'Minensuche', tier: 'gold' },
    ],
  },
  {
    id: 'fallen_entschaerft', category: 'ueberleben', box: 'ueberlebens', text: 'Entschärfe {n} Fallen.', value: (s) => s.counters.trapsDisarmed,
    stages: [
      { n: 5, name: 'Ruhige Hände', tier: 'bronze' },
      { n: 20, name: 'Kampfmittelräumdienst', tier: 'silber' },
    ],
  },
  {
    id: 'fallen_ausgeloest', category: 'ueberleben', box: 'ueberlebens', text: 'Löse {n} Fallen selbst aus.', value: (s) => s.counters.trapsTriggered,
    stages: [
      { n: 3, name: 'Pechsträhne', tier: null },
      { n: 10, name: 'Fallenmagnet', tier: 'bronze', comment: 'Zehn Fallen. Mit dem eigenen Körper. Die Systemstimme hat dir eine Taschenlampe geschickt. Aus Mitleid.' },
    ],
  },
  {
    id: 'verbandszeug', category: 'ueberleben', box: 'ueberlebens', text: 'Überstehe {n} Zustände wie Blutung, Brennen, Furcht oder Blindheit.', value: st('zustand.erlitten'),
    stages: [
      { n: 10, name: 'Hart im Nehmen', tier: 'bronze' },
      { n: 50, name: 'Wandelndes Lazarett', tier: 'silber' },
    ],
  },
  {
    id: 'befreit', category: 'ueberleben', box: 'ueberlebens', text: 'Befreie dich {n}-mal aus einer Falle.', value: st('befreit'),
    stages: [{ n: 5, name: 'Houdini', tier: 'silber' }],
  },
  // ============================================================ Magie
  {
    id: 'gezaubert', category: 'magie', box: 'abenteurer', text: 'Wirke {n} Zauber.', value: st('zauber.gewirkt'),
    stages: [
      { n: 10, name: 'Fingerübungen', tier: 'bronze' },
      { n: 50, name: 'Zauberkundig', tier: 'silber' },
      { n: 200, name: 'Magieverschwendung', tier: 'gold' },
    ],
  },
  {
    id: 'zauber_gelernt', category: 'magie', box: 'abenteurer', text: 'Beherrsche {n} verschiedene Zauber.', value: (s) => s.player.spells?.length ?? 0,
    stages: [
      { n: 2, name: 'Bücherwurm', tier: 'bronze' },
      { n: 5, name: 'Zauberbibliothek', tier: 'silber' },
      { n: 9, name: 'Allwissend', tier: 'gold' },
    ],
  },
  // ============================================================ Handwerk
  {
    id: 'gebaut', category: 'handwerk', box: 'wurf', text: 'Stelle {n} Dinge her.', value: (s) => s.counters.crafted,
    stages: [
      { n: 5, name: 'Heimwerken', tier: 'bronze' },
      { n: 25, name: 'Tüftelei', tier: 'silber' },
      { n: 75, name: 'Meisterwerkstatt', tier: 'gold' },
    ],
  },
  ...recipeFamilies(),
  {
    id: 'aufgestellt', category: 'handwerk', box: 'ueberlebens', text: 'Stelle {n} eigene Fallen auf.', value: st('fallen.aufgestellt'),
    stages: [
      { n: 5, name: 'Hinterhältig', tier: 'bronze' },
      { n: 20, name: 'Minenfeld', tier: 'silber' },
    ],
  },
  // ============================================================ Sozial
  {
    id: 'crawler', category: 'sozial', box: 'fan', text: 'Sprich mit {n} anderen Crawlern.', value: st('crawler.getroffen'),
    stages: [
      { n: 5, name: 'Kontaktfreudig', tier: 'bronze' },
      { n: 15, name: 'Netzwerk', tier: 'silber' },
      { n: 40, name: 'Kellergespräche', tier: 'gold' },
    ],
  },
  {
    id: 'party', category: 'sozial', box: 'abenteurer', text: 'Nimm {n} Crawler in deine Party auf.', value: st('party.beigetreten'),
    stages: [
      { n: 3, name: 'Personalabteilung', tier: 'silber' },
      { n: 8, name: 'Rekrutierungsbüro', tier: 'gold' },
    ],
  },
  {
    id: 'auftraege', category: 'sozial', box: 'abenteurer', text: 'Erledige {n} Aufträge.', value: st('auftraege.erledigt'),
    stages: [
      { n: 10, name: 'Tagelohn', tier: 'silber' },
      { n: 25, name: 'Für alles zu haben', tier: 'gold' },
    ],
  },
  {
    id: 'tipps', category: 'sozial', box: 'abenteurer', text: 'Frage {n} Crawler nach Tipps.', value: st('tipps'),
    stages: [{ n: 5, name: 'Neugierige Nase', tier: 'bronze' }],
  },
  {
    id: 'samariter', category: 'sozial', box: 'ueberlebens', text: 'Versorge {n} verletzte Crawler.', value: st('crawler.geheilt'),
    stages: [
      { n: 1, name: 'Erste-Hilfe-Kasten', tier: 'bronze' },
      { n: 5, name: 'Barmherzigkeit', tier: 'silber' },
    ],
  },
  {
    id: 'crawlerjagd', category: 'sozial', box: 'brawler', text: 'Besiege {n} Crawler, die dich ausrauben wollten.', value: st('kills.crawler'),
    stages: [
      { n: 3, name: 'Selbstjustiz', tier: 'silber' },
      { n: 10, name: 'Sheriff', tier: 'gold' },
    ],
  },
  {
    id: 'haustier_stufe', category: 'sozial', box: 'haustier', text: 'Bring dein Haustier auf Stufe {n}.', value: (s) => s.player.pet?.level ?? 0,
    stages: [
      { n: 10, name: 'Alpha-Tier', tier: 'gold' },
      { n: 15, name: 'Monster an der Leine', tier: 'platin' },
    ],
  },
  // ============================================================ Show
  {
    id: 'follower', category: 'show', box: 'fan', text: 'Erreiche {n} Follower.', value: (s) => s.viewers.follower,
    stages: [
      { n: 2500, name: 'Aufsteigender Stern', tier: 'silber' },
      { n: 25000, name: 'Quotenrekord', tier: 'gold' },
      { n: 100000, name: 'Galaktische Legende', tier: 'platin' },
    ],
  },
  {
    id: 'sponsorwuensche', category: 'show', box: 'fan', text: 'Erfülle {n} Wünsche deiner Sponsoren.', value: st('sponsor.wuensche'),
    stages: [
      { n: 3, name: 'Werbegesicht', tier: 'silber' },
      { n: 10, name: 'Markenbotschaft', tier: 'gold' },
    ],
  },
  {
    id: 'fangeschenke', category: 'show', box: 'fan', text: 'Erhalte {n} Geschenke aus dem Publikum.', value: st('fangeschenke'),
    stages: [
      { n: 1, name: 'Fanpost', tier: null },
      { n: 5, name: 'Geschenkeflut', tier: 'silber' },
    ],
  },
  {
    id: 'reiten', category: 'show', box: 'abenteurer', text: 'Lege {n} Schritte auf einem Reittier zurück.', value: st('reittier.schritte'),
    stages: [
      { n: 100, name: 'Sonntagsausflug', tier: 'bronze' },
      { n: 1000, name: 'Kurierdienst', tier: 'silber' },
    ],
  },
  {
    id: 'rammkills', category: 'show', box: 'brawler', text: 'Besiege {n} Gegner durch Rammen.', value: st('reittier.kills'),
    stages: [
      { n: 10, name: 'Verkehrsrowdy', tier: 'silber' },
      { n: 30, name: 'Fahrerflucht ausgeschlossen', tier: 'gold' },
    ],
  },
  // ============================================================ Fortschritt
  {
    id: 'stufe', category: 'fortschritt', box: 'abenteurer', text: 'Erreiche Stufe {n}.', value: (s) => s.player.level,
    stages: [
      { n: 3, name: 'Kein Grünschnabel mehr', tier: 'bronze' },
      { n: 7, name: 'Gestandener Crawler', tier: 'silber' },
      { n: 12, name: 'Dutzend voll', tier: 'gold' },
      { n: 20, name: 'Zwanzig und kein bisschen weise', tier: 'platin' },
    ],
  },
  {
    id: 'skills_gelernt', category: 'fortschritt', box: 'abenteurer', text: 'Lerne {n} Skills.', value: (s) => s.player.skills.length,
    stages: [
      { n: 3, name: 'Lernwillig', tier: 'bronze' },
      { n: 8, name: 'Vielseitig begabt', tier: 'silber' },
      { n: 15, name: 'Tausendsassa', tier: 'gold' },
      { n: 25, name: 'Kann alles, außer sterben', tier: 'platin' },
    ],
  },
  {
    id: 'skill_stufe', category: 'fortschritt', box: 'abenteurer', text: 'Bring einen Skill auf Stufe {n}.', value: (s) => Math.max(0, ...s.player.skills.map((k) => k.level)),
    stages: [
      { n: 5, name: 'Fortgeschritten', tier: 'bronze' },
      { n: 15, name: 'Großmeisterlich', tier: 'platin', comment: 'Stufe fünfzehn. Mehr geht nicht. Die Systemstimme überlegt, ob sie nachbessern muss.' },
    ],
  },
  {
    id: 'entdeckte_skills', category: 'fortschritt', box: 'abenteurer', text: 'Lass den Beobachter {n} eigene Skills für dich entdecken.', value: (s) => s.player.dynSkills?.length ?? 0,
    stages: [
      { n: 1, name: 'Beobachtet', tier: 'bronze' },
      { n: 5, name: 'Fallstudie', tier: 'silber' },
      { n: 10, name: 'Forschungsobjekt', tier: 'gold' },
    ],
  },
  {
    id: 'wert', category: 'fortschritt', box: 'brawler', text: 'Steigere einen Grundwert auf {n}.', value: (s) => Math.max(...Object.values(s.player.stats)),
    stages: [
      { n: 12, name: 'Überdurchschnittlich', tier: 'bronze' },
      { n: 16, name: 'Außergewöhnlich', tier: 'silber' },
      { n: 20, name: 'Übermensch', tier: 'gold' },
    ],
  },
];

function partFamily(part: string, label: string, box: BoxType, names: string[], stages: number[]): Family[] {
  return [{
    id: `teil_${part}`, category: 'technik', box, text: `Besiege {n} Gegner mit ${label}.`, value: st(`kills.teil.${part}`),
    stages: stages.map((n, i) => ({ n, name: names[i], tier: (['bronze', 'silber', 'gold'] as BoxTier[])[i] })),
  }];
}

function moveFamily(move: string, label: string, names: string[], stages: number[]): Family[] {
  return [{
    id: `bewegung_${move}`, category: 'technik', box: 'schuh', text: `Besiege {n} Gegner mit ${label}.`, value: st(`kills.bewegung.${move}`),
    stages: stages.map((n, i) => ({ n, name: names[i], tier: (['bronze', 'silber', 'gold'] as BoxTier[])[i + (stages.length < 3 ? 1 : 0)] })),
  }];
}

function boxTierFamily(): Family[] {
  const tiers: [BoxTier, string, BoxTier][] = [
    ['gold', 'Goldrausch', 'silber'],
    ['platin', 'Platinstatus', 'gold'],
    ['legendaer', 'Legenden sind aus Kisten gemacht', 'platin'],
    ['himmlisch', 'Himmlische Verpackung', 'legendaer'],
  ];
  return tiers.map(([tier, name, reward]) => ({
    id: `boxstufe_${tier}`, category: 'beute', box: 'fan', text: `Öffne eine Box der Stufe ${tier === 'legendaer' ? 'Legendär' : tier === 'himmlisch' ? 'Himmlisch' : tier.charAt(0).toUpperCase() + tier.slice(1)}.`,
    value: st(`boxen.stufe.${tier}`), stages: [{ n: 1, name, tier: reward }],
  }));
}

function recipeFamilies(): Family[] {
  return RECIPES.map((r) => ({
    id: `rezept_${r.id}`, category: 'handwerk', box: 'wurf', text: `Stelle zum ersten Mal her: ${r.name}.`, value: st(`hergestellt.${r.id}`),
    stages: [{ n: 1, name: RECIPE_NAMES[r.id] ?? `Rezept: ${r.name}`, tier: 'bronze' }],
  }));
}

// ================================================================ Bestiarium je Monsterart

const BEAST_STAGES: { n: number; label: (name: string) => string; tier: BoxTier | null; comment: string }[] = [
  { n: 1, label: (n) => `Neu im Bestiarium: ${n}`, tier: null, comment: 'Neuer Eintrag im Bestiarium. Die Art ist wenig begeistert.' },
  { n: 10, label: (n) => `Routine: ${n}`, tier: 'bronze', comment: 'Zehn Stück. Du erkennst sie inzwischen am Geruch.' },
  { n: 30, label: (n) => `Plage beseitigt: ${n}`, tier: 'silber', comment: 'Dreißig. Irgendwo schreibt jemand einen Artenschutzantrag. Zu spät.' },
];

function beastFamilies(): AchievementDef[] {
  const out: AchievementDef[] = [];
  for (const m of MONSTERS) {
    if (!m.floors.length || m.weight <= 0) continue;
    for (const [i, stage] of BEAST_STAGES.entries()) {
      out.push({
        id: `art_${m.id}_${i + 1}`,
        name: stage.label(m.name),
        description: stage.n === 1 ? `Besiege zum ersten Mal: ${m.name}.` : `Besiege ${stage.n}-mal: ${m.name}.`,
        comment: stage.comment,
        tier: stage.tier ?? 'bronze',
        box: stage.tier ? 'abenteurer' : null,
        category: 'bestiarium',
        // Erst wenn die Art erkannt wurde (siehe identify.ts), taucht ihr Name hier auf.
        check: (_e, s) => (s.stats?.[`kills.art.${m.id}`] ?? 0) >= stage.n && !!s.stats?.[`bekannt.${m.id}`],
      });
    }
  }
  return out;
}

function hashIndex(id: string, n: number): number {
  let h = 0;
  for (const c of id) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return h % n;
}

/** Familien ohne Funktionen: Statistik-Schlüssel oder Familien-ID (für den Godot-Export). */
export function familyTable() {
  return FAMILIES.map((f) => ({
    id: f.id, stat: (f.value as { statKey?: string }).statKey ?? null, stages: f.stages.map((x) => x.n),
  }));
}

/** Alle gestuften Achievements als normale Achievement-Definitionen. */
export function familyAchievements(): AchievementDef[] {
  const out: AchievementDef[] = [];
  for (const f of FAMILIES) {
    for (const stage of f.stages) {
      const pool = COMMENTS[f.category];
      out.push({
        id: `fam_${f.id}_${stage.n}`,
        name: stage.name,
        description: f.text.replace('{n}', stage.n.toLocaleString('de-DE')),
        comment: stage.comment ?? pool[hashIndex(`${f.id}${stage.n}`, pool.length)],
        tier: stage.tier ?? 'bronze',
        box: stage.tier ? f.box : null,
        category: f.category,
        check: (_e, s) => f.value(s) >= stage.n,
      });
    }
  }
  return [...out, ...beastFamilies()];
}

export interface Goal {
  category: AchievementCategory;
  description: string;
  value: number;
  target: number;
}

/**
 * Das jeweils nächste offene Ziel jeder Familie – für die Übersicht.
 * Arten erscheinen erst, wenn man sie erkannt und besiegt hat.
 */
export function nextGoals(s: GameState): Goal[] {
  const out: Goal[] = [];
  for (const f of FAMILIES) {
    const stage = f.stages.find((st) => !s.achievements.includes(`fam_${f.id}_${st.n}`));
    if (!stage) continue;
    out.push({ category: f.category, description: f.text.replace('{n}', stage.n.toLocaleString('de-DE')), value: f.value(s), target: stage.n });
  }
  for (const m of MONSTERS) {
    const kills = s.stats?.[`kills.art.${m.id}`] ?? 0;
    if (!kills || !s.stats?.[`bekannt.${m.id}`]) continue;
    const i = BEAST_STAGES.findIndex((_st, k) => !s.achievements.includes(`art_${m.id}_${k + 1}`));
    if (i < 0) continue;
    const n = BEAST_STAGES[i].n;
    out.push({ category: 'bestiarium', description: `Besiege ${n}-mal: ${m.name}.`, value: kills, target: n });
  }
  return out;
}
