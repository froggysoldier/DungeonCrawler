import { MORE_ACHIEVEMENTS } from './achievements_more';
import { SOCIAL_ACHIEVEMENTS } from './achievements_social';
import type { BoxTier, BoxType, GameEvent, GameState } from '../engine/types';

export interface AchievementDef {
  id: string;
  name: string;
  description: string;
  /** Sarkastischer Kommentar der Systemstimme. */
  comment: string;
  tier: BoxTier;
  box: BoxType;
  check: (e: GameEvent, s: GameState) => boolean;
}

const killsWithPart = (s: GameState, part: string) =>
  Object.entries(s.player.techniqueKills)
    .filter(([k]) => k.startsWith(part + '+'))
    .reduce((sum, [, v]) => sum + v, 0);
const hasEquipped = (s: GameState) => Object.keys(s.player.equipment).length;

const BASE_ACHIEVEMENTS: AchievementDef[] = [
  // ----------------------------------------------------------- Start
  {
    id: 'willkommen', name: 'Willkommen im Abstieg!', tier: 'bronze', box: 'abenteurer',
    description: 'Betritt den Dungeon.',
    comment: 'Herzlichen Glückwunsch! Du hast überlebt, dass deine Welt zerstört wurde. Das ist mehr, als 99 % deiner Spezies geschafft haben. Genieß es. Es wird nicht besser.',
    check: (e) => e.type === 'start',
  },
  {
    id: 'katzenlady', name: 'Komische Katzenlady', tier: 'silber', box: 'haustier',
    description: 'Betritt den Dungeon zusammen mit einer Katze.',
    comment: 'Die Welt geht unter, und das Erste, woran du denkst, ist die Katze. Die Zuschauer lieben dich bereits. Die Katze eher nicht.',
    check: (e, s) => e.type === 'start' && s.player.pet?.species === 'Katze',
  },
  {
    id: 'hundemensch', name: 'Bester Freund des Menschen', tier: 'silber', box: 'haustier',
    description: 'Betritt den Dungeon zusammen mit einem Hund.',
    comment: 'Ein treuer Begleiter. Er wird dich bis in den Tod begleiten. Bei eurem Tempo: bald.',
    check: (e, s) => e.type === 'start' && s.player.pet?.species === 'Hund',
  },
  {
    id: 'bademantel', name: 'Mode-Ikone der Apokalypse', tier: 'bronze', box: 'kleidung',
    description: 'Betritt den Dungeon im Bademantel.',
    comment: 'Die Galaxis sieht zu. Die GANZE Galaxis. Und du trägst einen Bademantel.',
    check: (e, s) => e.type === 'start' && s.player.equipment.brust?.baseId === 'bademantel',
  },

  // ----------------------------------------------------------- Kampf allgemein
  {
    id: 'erstes_blut', name: 'Erstes Blut', tier: 'bronze', box: 'abenteurer',
    description: 'Töte deinen ersten Mob.',
    comment: 'Ein Leben weniger im Dungeon. Nur noch etwa 40 Millionen.',
    check: (e, s) => e.type === 'kill' && s.counters.kills === 1,
  },
  {
    id: 'zehn_kills', name: 'Schädlingsbekämpfung', tier: 'bronze', box: 'abenteurer',
    description: 'Töte 10 Mobs.',
    comment: 'Du bist jetzt offiziell gefährlicher als ein Kammerjäger. Knapp.',
    check: (e, s) => e.type === 'kill' && s.counters.kills === 10,
  },
  {
    id: 'fuenfzig_kills', name: 'Serienkiller (im Rahmen der Spielregeln)', tier: 'silber', box: 'abenteurer',
    description: 'Töte 50 Mobs.',
    comment: 'Auf der Erde hätte man dich dafür eingesperrt. Hier gibt es eine Box.',
    check: (e, s) => e.type === 'kill' && s.counters.kills === 50,
  },
  {
    id: 'rattenfaenger', name: 'Rattenfänger von Hameln (ohne Flöte)', tier: 'silber', box: 'abenteurer',
    description: 'Töte 20 Ratten jeglicher Art.',
    comment: 'Die Ratten haben einen Namen für dich. Er ist nicht nett.',
    check: (e, s) =>
      e.type === 'kill' &&
      (s.counters.killsByDef['kellerratte'] ?? 0) + (s.counters.killsByDef['rattenmensch'] ?? 0) === 20,
  },
  {
    id: 'david', name: 'David gegen Goliath', tier: 'silber', box: 'wurf',
    description: 'Töte einen Mob, der mindestens 3 Level über dir ist.',
    comment: 'Statistisch hättest du sterben müssen. Die Statistikabteilung ist verärgert.',
    check: (e, s) => e.type === 'kill' && e.monster.level >= s.player.level + 3,
  },
  {
    id: 'multitasker', name: 'Kampf-Multitasking', tier: 'silber', box: 'brawler',
    description: 'Töte einen Gegner, nachdem du ihn mit 4 verschiedenen Techniken getroffen hast.',
    comment: 'Faust, Fuß, Knie, Kopf. Du hast einfach alles an ihm ausprobiert. Wie ein Kleinkind mit einem Gummihammer.',
    check: (e) => e.type === 'kill' && new Set(e.monster.hitBy ?? []).size >= 4,
  },
  {
    id: 'ruepel', name: 'Rüpel', tier: 'bronze', box: 'brawler',
    description: 'Töte einen fliehenden Gegner.',
    comment: 'Er wollte doch nur weg. Du Monster. Die Zuschauer sind begeistert.',
    check: (e) => e.type === 'kill' && !!e.monster.fleeing,
  },
  {
    id: 'hinterhalt', name: 'Buh!', tier: 'bronze', box: 'brawler',
    description: 'Töte einen Gegner mit einem einzigen Schlag, bevor er dich bemerkt.',
    comment: 'Er hat dich nicht kommen sehen. Er wird auch sonst nichts mehr sehen.',
    check: (e) => e.type === 'kill' && !e.monster.aware && (e.monster.hitBy?.length ?? 0) <= 1,
  },
  {
    id: 'knapp_daneben', name: 'Knapp daneben ist auch vorbei', tier: 'bronze', box: 'ueberlebens',
    description: 'Verfehle 5-mal hintereinander.',
    comment: 'Die Zuschauer haben ein Trinkspiel erfunden. Es heißt „Wann trifft er endlich?“.',
    check: (e, s) => e.type === 'attack' && !e.hit && s.counters.missStreak === 5,
  },
  {
    id: 'sandsack', name: 'Menschlicher Sandsack', tier: 'bronze', box: 'ueberlebens',
    description: 'Werde 8-mal hintereinander getroffen.',
    comment: 'Du hast eine beeindruckende Fähigkeit, im Weg zu stehen.',
    check: (e, s) => e.type === 'damageTaken' && s.counters.hitTakenStreak === 8,
  },
  {
    id: 'haaresbreite', name: 'Um Haaresbreite', tier: 'silber', box: 'ueberlebens',
    description: 'Überlebe einen Treffer mit 1–2 HP übrig.',
    comment: 'Die Wettquoten auf deinen Tod sind gerade eingebrochen. Viele sind sehr enttäuscht.',
    check: (e, s) => e.type === 'damageTaken' && s.player.hp > 0 && s.player.hp <= 2,
  },
  {
    id: 'crit', name: 'Volltreffer!', tier: 'bronze', box: 'waffen',
    description: 'Lande einen kritischen Treffer.',
    comment: 'Genau da, wo es wehtut. Die Systemstimme hat es in Zeitlupe gesehen. Mehrmals.',
    check: (e) => e.type === 'attack' && e.crit,
  },
  {
    id: 'overkill', name: 'Overkill', tier: 'silber', box: 'brawler',
    description: 'Füge mit einem einzigen Angriff 25 Schaden zu.',
    comment: 'Man hätte ihn auch einfach… nein, schon gut. Genau so.',
    check: (e) => e.type === 'attack' && e.damage >= 25,
  },

  // ----------------------------------------------------------- Kampfstile
  {
    id: 'faust10', name: 'Hände wie Schaufeln', tier: 'bronze', box: 'brawler',
    description: 'Töte 10 Gegner mit Faustschlägen.',
    comment: 'Deine Knöchel sehen aus wie Hackfleisch. Stolz darf man trotzdem sein.',
    check: (e, s) => e.type === 'kill' && killsWithPart(s, 'faust') === 10,
  },
  {
    id: 'tritt10', name: 'Barfuß-Rambo', tier: 'bronze', box: 'schuh',
    description: 'Töte 10 Gegner mit Tritten.',
    comment: 'Dein Fuß hat jetzt mehr Kills als die meisten Crawler. Das ist traurig. Für die anderen.',
    check: (e, s) => e.type === 'kill' && killsWithPart(s, 'tritt') === 10,
  },
  {
    id: 'stampf1', name: 'Plattgemacht!', tier: 'bronze', box: 'schuh',
    description: 'Töte einen Gegner durch Stampfen.',
    comment: 'Er lag schon am Boden. Du hast trotzdem draufgetreten. Die Zuschauer: Standing Ovations.',
    check: (e) => e.type === 'kill' && e.technique?.move === 'stampfen',
  },
  {
    id: 'stampf15', name: 'Podophilie', tier: 'gold', box: 'schuh',
    description: 'Töte 15 Gegner durch Stampfen.',
    comment: 'Du hast ein Problem. Ein Fußproblem. Die Systemstimme urteilt nicht. Die Systemstimme urteilt ein bisschen.',
    check: (e, s) =>
      e.type === 'kill' &&
      Object.entries(s.player.techniqueKills).filter(([k]) => k.endsWith('+stampfen')).reduce((a, [, v]) => a + v, 0) === 15,
  },
  {
    id: 'kopf1', name: 'Kopf durch die Wand', tier: 'bronze', box: 'kleidung',
    description: 'Töte einen Gegner mit einem Kopfstoß.',
    comment: 'Beide Köpfe haben gelitten. Nur einer lebt noch.',
    check: (e) => e.type === 'kill' && e.technique?.part === 'kopf',
  },
  {
    id: 'stein1', name: 'Steinzeit', tier: 'bronze', box: 'wurf',
    description: 'Töte einen Gegner mit einem geworfenen Stein.',
    comment: 'Hunderttausende Jahre Evolution, und am Ende ist es doch wieder ein Stein.',
    check: (e) => e.type === 'kill' && e.technique?.part === 'wurf',
  },
  {
    id: 'wurf25', name: 'Wurfmaschine', tier: 'silber', box: 'wurf',
    description: 'Wirf 25 Gegenstände auf Gegner.',
    comment: 'Du wirfst mit allem, was nicht festgeschraubt ist. Und manchmal mit Schrauben.',
    check: (e, s) => e.type === 'attack' && e.technique.part === 'wurf' && s.counters.throws === 25,
  },
  {
    id: 'sprung5', name: 'Sprungbrett', tier: 'bronze', box: 'schuh',
    description: 'Töte 5 Gegner mit Sprungangriffen.',
    comment: 'Hoch, runter, tot. Einfache Choreografie.',
    check: (e, s) =>
      e.type === 'kill' &&
      Object.entries(s.player.techniqueKills).filter(([k]) => k.endsWith('+sprung')).reduce((a, [, v]) => a + v, 0) === 5,
  },
  {
    id: 'meteor', name: 'Meteoriteneinschlag', tier: 'silber', box: 'schuh',
    description: 'Töte einen Gegner mit einem Sprungtritt.',
    comment: 'Du bist durch die Luft geflogen und mit dem Fuß voran gelandet. Auf einem Gesicht. Kunst.',
    check: (e) => e.type === 'kill' && e.technique?.part === 'tritt' && e.technique.move === 'sprung',
  },
  {
    id: 'ellbogen10', name: 'Ellbogengesellschaft', tier: 'bronze', box: 'brawler',
    description: 'Töte 10 Gegner mit dem Ellbogen.',
    comment: 'So hast du dich früher auch im Supermarkt an der Kasse vorgedrängelt, oder?',
    check: (e, s) => e.type === 'kill' && killsWithPart(s, 'ellbogen') === 10,
  },
  {
    id: 'knie10', name: 'Kniefall', tier: 'bronze', box: 'brawler',
    description: 'Töte 10 Gegner mit dem Knie.',
    comment: 'Vor dir gehen die Gegner in die Knie. Also eigentlich eher: in dein Knie.',
    check: (e, s) => e.type === 'kill' && killsWithPart(s, 'knie') === 10,
  },
  {
    id: 'waffe1', name: 'Heimwerkerkönig', tier: 'bronze', box: 'waffen',
    description: 'Töte einen Gegner mit einer improvisierten Waffe.',
    comment: 'Das war mal ein Möbelstück. Jetzt ist es ein Mordwerkzeug. Nachhaltig!',
    check: (e) => e.type === 'kill' && e.technique?.part === 'waffe',
  },
  {
    id: 'anlauf1', name: 'Mit Anlauf!', tier: 'bronze', box: 'brawler',
    description: 'Töte einen Gegner mit einem Sturmangriff.',
    comment: 'Zehn Meter Anlauf für einen Schlag. Effizienz sieht anders aus. Unterhaltung nicht.',
    check: (e) => e.type === 'kill' && e.technique?.move === 'anlauf',
  },
  {
    id: 'nackter_boss', name: 'Die nackte Wahrheit', tier: 'gold', box: 'kleidung',
    description: 'Besiege einen Boss ohne angelegte Ausrüstung.',
    comment: 'Keine Rüstung. Keine Waffe. Kaum Kleidung. Nur Wut. Die Einschaltquoten explodieren.',
    check: (e, s) => e.type === 'kill' && e.monster.rank !== 'normal' && e.monster.rank !== 'elite' && hasEquipped(s) === 0,
  },

  // ----------------------------------------------------------- Bosse & Erkundung
  {
    id: 'elite1', name: 'Nicht mehr ganz so normal', tier: 'bronze', box: 'abenteurer',
    description: 'Besiege einen Elite-Mob.',
    comment: 'Er war etwas größer, etwas stärker und etwas hässlicher. Jetzt ist er vor allem: tot.',
    check: (e) => e.type === 'kill' && e.monster.rank === 'elite',
  },
  {
    id: 'hoodboss1', name: 'Nachbarschaftshilfe', tier: 'silber', box: 'boss',
    description: 'Besiege einen Nachbarschafts-Boss.',
    comment: 'Das Viertel ist jetzt sicherer. Es ist auch leerer. Beides deine Schuld.',
    check: (e) => e.type === 'kill' && e.monster.rank === 'nachbarschaftsboss',
  },
  {
    id: 'hoodboss4', name: 'Bürgermeister der Ruinen', tier: 'gold', box: 'boss',
    description: 'Besiege alle vier Nachbarschafts-Bosse einer Etage.',
    comment: 'Vier Viertel, vier Bosse, vier Beerdigungen. Du solltest ein Bestattungsunternehmen gründen.',
    check: (e, s) => e.type === 'kill' && e.monster.rank === 'nachbarschaftsboss' && s.map.hoods.every((h) => !h.bossAlive),
  },
  {
    id: 'boroughboss', name: 'Oma ist satt', tier: 'gold', box: 'boss',
    description: 'Besiege den Borough-Boss.',
    comment: 'Du hast eine riesige Oma verprügelt. Deine eigene Oma wäre… eigentlich stolz. Sie war ja auch so.',
    check: (e) => e.type === 'kill' && e.monster.rank === 'boroughboss',
  },
  {
    id: 'lebensmuede', name: 'Lebensmüde', tier: 'gold', box: 'ueberlebens',
    description: 'Besiege einen Boss, der mindestens 5 Level über dir ist.',
    comment: 'Die Systemstimme hat bereits deinen Nachruf geschrieben. Jetzt muss sie ihn löschen. Danke für nichts.',
    check: (e, s) => e.type === 'kill' && e.monster.rank !== 'normal' && e.monster.rank !== 'elite' && e.monster.level >= s.player.level + 5,
  },
  {
    id: 'kartograph', name: 'Kartograph', tier: 'bronze', box: 'abenteurer',
    description: 'Hebe eine Gebietskarte auf.',
    comment: 'Ein Stück Papier, das dir sagt, wo du bist. Luxus.',
    check: (e) => e.type === 'mapPicked',
  },
  {
    id: 'treppe', name: 'Treppenwitz', tier: 'bronze', box: 'abenteurer',
    description: 'Finde ein Treppenhaus.',
    comment: 'Der Weg nach unten. Hier bedeutet „nach unten“ übrigens „schlimmer“.',
    check: (e) => e.type === 'stairsFound',
  },
  {
    id: 'safe1', name: 'Zuhause ist, wo einen keiner haut', tier: 'bronze', box: 'ueberlebens',
    description: 'Betritt einen Safe Room.',
    comment: 'Keine Gewalt erlaubt. Ungewohnt, oder?',
    check: (e) => e.type === 'enterRoom' && e.room.kind === 'safe',
  },
  {
    id: 'gilde', name: 'Hausaufgaben gemacht', tier: 'bronze', box: 'abenteurer',
    description: 'Schließe das Tutorial in der Gilde ab.',
    comment: 'Du hast dir die Anleitung durchgelesen. Die Systemstimme ist schockiert. Das macht sonst niemand.',
    check: (e) => e.type === 'tutorialDone',
  },
  {
    id: 'pazifist', name: 'Pazifist (vorläufig)', tier: 'silber', box: 'ueberlebens',
    description: 'Schließe das Tutorial ab, ohne etwas getötet zu haben.',
    comment: 'Du hast noch niemanden umgebracht. Die Systemstimme gibt dir etwa zehn Minuten.',
    check: (e, s) => e.type === 'tutorialDone' && s.counters.kills === 0,
  },
  {
    id: 'wanderer', name: 'Ich bin dann mal weg', tier: 'bronze', box: 'schuh',
    description: 'Laufe 1000 Schritte.',
    comment: 'Tausend Schritte durch einen Keller voller Monster. Deine Fitness-App wäre stolz. Wenn es sie noch gäbe.',
    check: (e, s) => e.type === 'moved' && s.counters.steps === 1000,
  },

  // ----------------------------------------------------------- Loot & Leben
  {
    id: 'klepto', name: 'Kleptomane', tier: 'bronze', box: 'abenteurer',
    description: 'Hebe 20 Gegenstände auf.',
    comment: 'Du nimmst einfach alles mit. Die Systemstimme fühlt sich an ihre Ex erinnert.',
    check: (e, s) => e.type === 'pickup' && s.counters.itemsPicked === 20,
  },
  {
    id: 'unboxing', name: 'Unboxing-Influencer', tier: 'bronze', box: 'fan',
    description: 'Öffne deine erste Lootbox.',
    comment: 'Die Zuschauer lieben Unboxing. Mach beim nächsten Mal ein überraschtes Gesicht.',
    check: (e, s) => e.type === 'boxOpened' && s.counters.boxesOpened === 1,
  },
  {
    id: 'unboxing10', name: 'Glücksspielsucht', tier: 'silber', box: 'fan',
    description: 'Öffne 10 Lootboxen.',
    comment: 'Das ist keine Sucht. Das ist ein Hobby. Mit Entzugserscheinungen.',
    check: (e, s) => e.type === 'boxOpened' && s.counters.boxesOpened === 10,
  },
  {
    id: 'modeopfer', name: 'Modeopfer', tier: 'silber', box: 'kleidung',
    description: 'Trage gleichzeitig 8 Ausrüstungsteile.',
    comment: 'Nichts davon passt zusammen. Aber du siehst aus wie jemand, der überleben will.',
    check: (e, s) => e.type === 'equip' && hasEquipped(s) === 8,
  },
  {
    id: 'feinschmecker', name: 'Feinschmecker', tier: 'bronze', box: 'ueberlebens',
    description: 'Iss in einem Safe-Room-Restaurant.',
    comment: 'Die Welt ist untergegangen, aber das Schnitzel ist gut. Prioritäten.',
    check: (e) => e.type === 'eat' && e.item.baseId.startsWith('menue_'),
  },
  {
    id: 'schlafmuetze', name: 'Schlafmütze', tier: 'bronze', box: 'ueberlebens',
    description: 'Schlafe in einem Safe Room.',
    comment: 'Acht Stunden Schlaf während einer Apokalypse. Gesund. Und völlig irre.',
    check: (e) => e.type === 'sleep',
  },
  {
    id: 'level5', name: 'Aufsteiger', tier: 'silber', box: 'abenteurer',
    description: 'Erreiche Level 5.',
    comment: 'Level 5! Auf der Erde wärst du damit… nichts. Hier bist du damit etwas weniger nichts.',
    check: (e) => e.type === 'levelUp' && e.level === 5,
  },
  {
    id: 'skill1', name: 'Autodidakt', tier: 'bronze', box: 'abenteurer',
    description: 'Lerne deinen ersten Skill durch Übung.',
    comment: 'Du hast etwas durch Wiederholung gelernt. Deine Eltern hatten doch recht.',
    check: (e) => e.type === 'skillLearned',
  },
  {
    id: 'skill5', name: 'Spezialist', tier: 'silber', box: 'brawler',
    description: 'Bringe einen Skill auf Stufe 5.',
    comment: 'Du bist jetzt richtig gut in genau einer Sache. Das ist mehr, als die meisten Menschen je waren.',
    check: (e) => e.type === 'skillUp' && e.level === 5,
  },
  {
    id: 'haustier_kill', name: 'Wer ist ein guter Killer?', tier: 'silber', box: 'haustier',
    description: 'Dein Haustier tötet einen Gegner.',
    comment: 'Dein Haustier hat getötet. Es hat keine Reue gezeigt. Du auch nicht. Ihr passt zusammen.',
    check: (e) => e.type === 'kill' && !!e.byPet,
  },
  {
    id: 'zweite_chance', name: 'Kleingedrucktes gelesen', tier: 'gold', box: 'ueberlebens',
    description: 'Entkomme dem Tod durch die Zweite-Chance-Klausel.',
    comment: 'Du warst tot. Jetzt bist du es nicht mehr. Die Buchhaltung ist verwirrt.',
    check: (e) => e.type === 'revived',
  },
  {
    id: 'geist', name: 'Vergangenheitsbewältigung', tier: 'gold', box: 'abenteurer',
    description: 'Besiege den Geist eines deiner früheren Crawler.',
    comment: 'Du hast dich selbst verprügelt. Also, eine frühere Version. Therapeuten würden das begrüßen. Glaube ich.',
    check: (e) => e.type === 'kill' && e.monster.rank === 'geist',
  },
  {
    id: 'fruehaufsteher', name: 'Frühaufsteher', tier: 'gold', box: 'schuh',
    description: 'Steige in den ersten 24 Stunden einer Etage hinab.',
    comment: 'So schnell? Die Zuschauer haben nicht mal ihr Popcorn fertig.',
    check: (e, s) => e.type === 'descend' && s.turn - s.floorStartTurn <= 480,
  },
  {
    id: 'last_minute', name: 'Auf den letzten Drücker', tier: 'silber', box: 'ueberlebens',
    description: 'Erreiche die Treppe in der letzten Stunde vor dem Einsturz.',
    comment: 'Das war knapp. Die Systemstimme hatte schon die Einsturz-Animation geladen.',
    check: (e, s) => e.type === 'descend' && s.collapseAt - s.turn <= 20,
  },
  {
    id: 'absteiger', name: 'Absteiger des Jahres', tier: 'silber', box: 'abenteurer',
    description: 'Steige auf die nächste Etage hinab.',
    comment: 'Tiefer, dunkler, tödlicher. Willkommen in deiner Zukunft.',
    check: (e) => e.type === 'descend',
  },
];

export const ACHIEVEMENTS: AchievementDef[] = [...BASE_ACHIEVEMENTS, ...MORE_ACHIEVEMENTS, ...SOCIAL_ACHIEVEMENTS];

export const ACHIEVEMENT_BY_ID: Record<string, AchievementDef> = Object.fromEntries(ACHIEVEMENTS.map((a) => [a.id, a]));
