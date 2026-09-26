import type { GameEvent, GameState, Item, Monster } from '../engine/types';
import type { AchievementDef } from './achievements';

// Zweite Welle an Achievements: Monster, Bosse, Kampfstile, Mode, Wirtschaft.

const killed = (s: GameState, ids: string[]) => ids.reduce((sum, id) => sum + (s.counters.killsByDef[id] ?? 0), 0);
const kill = (e: GameEvent): Monster | null => (e.type === 'kill' ? e.monster : null);
const killOf = (e: GameEvent, id: string) => kill(e)?.defId === id;
const partKills = (s: GameState, part: string) =>
  Object.entries(s.player.techniqueKills).filter(([k]) => k.startsWith(part + '+')).reduce((a, [, v]) => a + v, 0);
const moveKills = (s: GameState, move: string) =>
  Object.entries(s.player.techniqueKills).filter(([k]) => k.endsWith('+' + move)).reduce((a, [, v]) => a + v, 0);
const equipped = (s: GameState) => Object.values(s.player.equipment).filter((i): i is Item => !!i);
const wears = (s: GameState, baseId: string) => equipped(s).some((i) => i.baseId === baseId);
const weaponId = (s: GameState) => s.player.equipment.waffe?.baseId ?? (s.player.hand?.slot === 'waffe' ? s.player.hand.baseId : null);
const isBoss = (m: Monster) => m.rank === 'nachbarschaftsboss' || m.rank === 'boroughboss';
const weaponKill = (e: GameEvent, s: GameState, id: string) => e.type === 'kill' && e.technique?.part === 'waffe' && weaponId(s) === id;
const gotItem = (e: GameEvent, rarities: string[]) =>
  (e.type === 'boxOpened' && e.contents.some((c) => rarities.includes(c.rarity))) ||
  (e.type === 'pickup' && rarities.includes(e.item.rarity));

const UNDEAD = ['ghul', 'moorleiche', 'knochenratte', 'kellermeister', 'ghulhund'];
const FLYERS = ['fledermaus', 'poltergeist', 'irrlicht', 'grey_drohne', 'nachtmahr', 'mottenmann', 'taubenschwarm'];
const MIMICS = ['muellsack_mimic', 'toaster_mimic', 'waschmaschine_mimic'];
const UNARMED = ['faust', 'tritt', 'knie', 'ellbogen', 'kopf'];

const bossAchievement = (id: string, bossId: string, name: string, comment: string): AchievementDef => ({
  id, name, tier: 'gold', box: 'boss',
  description: `Besiege ${bossNames[bossId]}.`,
  comment,
  check: (e) => killOf(e, bossId),
});

const bossNames: Record<string, string> = {
  die_sammlerin: 'Die Sammlerin', der_hausmeister: 'den Hausmeister', koenig_kanalratte: 'den König der Kanalratten',
  muttis_mixer: 'Muttis Mega-Mixer', kammerjaeger: 'den Kammerjäger', mottenmutter: 'die Mutter aller Motten',
  pfandbaron: 'den Pfandflaschen-Baron', heizungsbestie: 'die Heizungsbestie', hausverwalter: 'den Hausverwalter',
  kanalkoenigin: 'die Kanalkönigin', kommandant_schlamm: 'Kommandant Klärschlamm', schwarzmarkt_oger: 'den Schwarzmarkt-Oger',
  nixe: 'die Nixe vom Überlauf', rattenkaiser: 'den Rattenkaiser', kesselkoenigin: 'Oma Gulasch',
};

export const MORE_ACHIEVEMENTS: AchievementDef[] = [
  // ------------------------------------------------------------ Monster
  {
    id: 'spinnen', name: 'Arachnophobie überwunden', tier: 'bronze', box: 'abenteurer',
    description: 'Töte 5 Kellerspinnen.',
    comment: 'Acht Beine weniger. Mal fünf. Die Systemstimme hat mitgezählt: 40 Beine.',
    check: (e, s) => killOf(e, 'kellerspinne') && killed(s, ['kellerspinne']) === 5,
  },
  {
    id: 'fledermaus', name: 'Flugabwehr', tier: 'silber', box: 'wurf',
    description: 'Töte 10 fliegende Gegner.',
    comment: 'Was fliegt, kann fallen. Du hast nachgeholfen.',
    check: (e, s) => !!kill(e) && FLYERS.includes(kill(e)!.defId) && killed(s, FLYERS) === 10,
  },
  {
    id: 'kroete_fern', name: 'Sicherheitsabstand', tier: 'silber', box: 'wurf',
    description: 'Töte eine Blähkröte mit einem Wurf.',
    comment: 'Aus sicherer Entfernung. Klug. Langweilig, aber klug.',
    check: (e) => killOf(e, 'blaehkroete') && e.type === 'kill' && e.technique?.part === 'wurf',
  },
  {
    id: 'knall', name: 'Knallfrosch', tier: 'bronze', box: 'ueberlebens',
    description: 'Werde von einer Explosion erwischt und überlebe.',
    comment: 'Du riechst jetzt nach Kröte. Innen und außen.',
    check: (e) => e.type === 'explosion',
  },
  {
    id: 'bestohlen', name: 'Opfer eines Taschendiebs', tier: 'bronze', box: 'ueberlebens',
    description: 'Lass dir Gold stehlen.',
    comment: 'Selbst in der Apokalypse: Achte auf deine Wertsachen. Die Systemstimme hat es gesehen und nichts gesagt.',
    check: (e) => e.type === 'robbed',
  },
  {
    id: 'rache', name: 'Wer zuletzt lacht', tier: 'silber', box: 'abenteurer',
    description: 'Töte einen Dieb, der dich bestohlen hat.',
    comment: 'Rache ist süß. Und klimpert.',
    check: (e) => !!kill(e)?.stolenGold,
  },
  {
    id: 'pleite', name: 'Pleite', tier: 'bronze', box: 'fan',
    description: 'Lass dir dein letztes Gold klauen.',
    comment: 'Null Gold. Die Zuschauer haben Mitleid. Ein bisschen.',
    check: (e, s) => e.type === 'robbed' && s.player.gold === 0,
  },
  {
    id: 'vergiftet', name: 'Das war wohl nicht vegan', tier: 'bronze', box: 'ueberlebens',
    description: 'Werde vergiftet.',
    comment: 'Grün im Gesicht steht dir. Nein, eigentlich nicht.',
    check: (e) => e.type === 'poisoned',
  },
  {
    id: 'geheilt', name: 'Chemie-Leistungskurs', tier: 'bronze', box: 'ueberlebens',
    description: 'Neutralisiere eine Vergiftung.',
    comment: 'Gift raus, Leben bleibt. Deine Lehrer wären stolz.',
    check: (e) => e.type === 'cured',
  },
  {
    id: 'giftschlucker', name: 'Giftschlucker', tier: 'silber', box: 'ueberlebens',
    description: 'Erleide insgesamt 30 Giftschaden.',
    comment: 'Deine Leber schreibt gerade eine Kündigung.',
    check: (e, s) => e.type === 'damageTaken' && s.counters.poisonDamage >= 30,
  },
  {
    id: 'zwerge', name: 'Rasenpflege', tier: 'bronze', box: 'waffen',
    description: 'Zerschlage 5 belebte Gartenzwerge.',
    comment: 'Der Vorgarten deiner Nachbarn ist gerächt.',
    check: (e, s) => killOf(e, 'gartenzwerg') && killed(s, ['gartenzwerg']) === 5,
  },
  {
    id: 'heinzel', name: 'Nachtschicht beendet', tier: 'bronze', box: 'abenteurer',
    description: 'Erwische ein Heinzelmännchen.',
    comment: 'Die sind echt schnell. Du warst schneller. Oder es war müde.',
    check: (e) => killOf(e, 'heinzelmann'),
  },
  {
    id: 'kryptozoologe', name: 'Kryptozoologe', tier: 'gold', box: 'abenteurer',
    description: 'Töte einen Wolpertinger, einen Tatzelwurm und einen Chupacabra.',
    comment: 'Die Wissenschaft hätte sie gern lebend gehabt. Die Wissenschaft ist aber tot.',
    check: (e, s) => !!kill(e) && ['wolpertinger', 'tatzelwurm', 'chupacabra'].every((id) => (s.counters.killsByDef[id] ?? 0) > 0),
  },
  {
    id: 'erstkontakt', name: 'Erstkontakt', tier: 'silber', box: 'abenteurer',
    description: 'Töte einen außerirdischen Späher.',
    comment: 'Die Menschheit hat endlich Aliens getroffen. Und sofort verprügelt. Typisch.',
    check: (e) => killOf(e, 'grauer_spaeher') || killOf(e, 'grey_drohne'),
  },
  {
    id: 'mimic', name: 'Nicht alles ist, wie es scheint', tier: 'silber', box: 'abenteurer',
    description: 'Besiege einen Mimic.',
    comment: 'Ab jetzt wirst du jeden Müllsack misstrauisch ansehen. Zu Recht.',
    check: (e) => !!kill(e) && MIMICS.includes(kill(e)!.defId),
  },
  {
    id: 'toaster', name: 'Frühstück ist fertig', tier: 'bronze', box: 'kleidung',
    description: 'Besiege einen Rauchenden Toaster.',
    comment: 'Leicht angebrannt. Wie immer.',
    check: (e) => killOf(e, 'toaster_mimic'),
  },
  {
    id: 'friedhof', name: 'Friedhofsruhe', tier: 'silber', box: 'waffen',
    description: 'Töte 10 Untote.',
    comment: 'Tot, untot, wieder tot. Der Kreislauf des Lebens, Kellerversion.',
    check: (e, s) => !!kill(e) && UNDEAD.includes(kill(e)!.defId) && killed(s, UNDEAD) === 10,
  },
  {
    id: 'verstaerkung', name: 'Verstärkung abgelehnt', tier: 'silber', box: 'brawler',
    description: 'Töte einen Gegner, der bereits Verstärkung gerufen hat.',
    comment: 'Er hat seine Freunde angerufen. Jetzt können sie gemeinsam auf der Beerdigung sein.',
    check: (e) => (kill(e)?.summoned ?? 0) > 0,
  },
  {
    id: 'dosenoeffner', name: 'Dosenöffner', tier: 'silber', box: 'schuh',
    description: 'Töte einen gepanzerten Gegner mit einem Tritt.',
    comment: 'Fäuste prallen ab. Füße nicht. Lektion gelernt.',
    check: (e) => e.type === 'kill' && !!e.monster.abilities?.includes('gepanzert') && e.technique?.part === 'tritt',
  },
  {
    id: 'elite5', name: 'Elitejäger', tier: 'gold', box: 'abenteurer',
    description: 'Besiege 5 Elite-Mobs.',
    comment: 'Die Elite hat Angst vor dir. Die Elite hat recht.',
    check: (e, s) => kill(e)?.rank === 'elite' && s.counters.eliteKills === 5,
  },
  {
    id: 'hundert', name: 'Hundert!', tier: 'gold', box: 'abenteurer',
    description: 'Töte 100 Mobs.',
    comment: 'Dreistellig. Die Galaxis applaudiert. Die Mobs weniger.',
    check: (e, s) => e.type === 'kill' && s.counters.kills === 100,
  },

  // ------------------------------------------------------------ Bosse
  bossAchievement('b_sammlerin', 'die_sammlerin', 'Entrümpelung', 'Das Viertel ist aufgeräumt. Die Handtaschen gehören jetzt dir.'),
  bossAchievement('b_hausmeister', 'der_hausmeister', 'Fristlose Kündigung', 'Er wollte nur, dass niemand läuft. Jetzt läuft er nicht mehr.'),
  bossAchievement('b_rattenkoenig', 'koenig_kanalratte', 'Königsmord', 'Sieben Köpfe, sieben Beerdigungen, eine Krone.'),
  bossAchievement('b_mixer', 'muttis_mixer', 'Stecker gezogen', 'Mutti wird enttäuscht sein. Mutti ist aber nicht hier.'),
  bossAchievement('b_kammerjaeger', 'kammerjaeger', 'Der Jäger wird zum Gejagten', 'Ungeziefer 1, Kammerjäger 0.'),
  bossAchievement('b_motten', 'mottenmutter', 'Mottenkugel', 'Deine Wollpullover sind sicher. Du hast keine, aber trotzdem.'),
  bossAchievement('b_pfand', 'pfandbaron', 'Pfand zurück', 'Er war 25 Cent wert. Mehr nicht.'),
  bossAchievement('b_heizung', 'heizungsbestie', 'Wartung überfällig', 'Endlich hat sich jemand um die Heizung gekümmert. Mit Gewalt.'),
  bossAchievement('b_verwalter', 'hausverwalter', 'Mietminderung', 'Die Nebenkostenabrechnung ist hiermit hinfällig.'),
  bossAchievement('b_kanalkoenigin', 'kanalkoenigin', 'Machtwechsel im Abfluss', 'Die Rohre haben eine neue Herrschaft. Dich. Glückwunsch?'),
  bossAchievement('b_schlamm', 'kommandant_schlamm', 'Unehrenhaft entlassen', 'Seine Armee hat sich aufgelöst. Buchstäblich.'),
  bossAchievement('b_oger', 'schwarzmarkt_oger', 'Geschäftsaufgabe', 'Alles muss raus! Vor allem seine Zähne.'),
  bossAchievement('b_nixe', 'nixe', 'Falscher Ton', 'Ihr letztes Lied war das schönste. Und das kürzeste.'),
  bossAchievement('b_rattenkaiser', 'rattenkaiser', 'Revolution!', 'Das Imperium ist gefallen. Die Ratten suchen einen neuen Kaiser. Sie schauen dich an.'),
  {
    id: 'boss_haende', name: 'Mit bloßen Händen', tier: 'gold', box: 'brawler',
    description: 'Besiege einen Boss mit einem unbewaffneten Angriff.',
    comment: 'Keine Waffe. Nur du und deine Körperteile. Die Galaxis ist beeindruckt und leicht verstört.',
    check: (e) => e.type === 'kill' && isBoss(e.monster) && !!e.technique && UNARMED.includes(e.technique.part),
  },
  {
    id: 'boss_stein', name: 'Goliath, Teil zwei', tier: 'gold', box: 'wurf',
    description: 'Besiege einen Boss mit einem Wurf.',
    comment: 'Ein Stein. Ein Riese. Eine sehr alte Geschichte, neu erzählt.',
    check: (e) => e.type === 'kill' && isBoss(e.monster) && e.technique?.part === 'wurf',
  },
  {
    id: 'boss_stampf', name: 'Bodenständig', tier: 'platin', box: 'schuh',
    description: 'Besiege einen Boss durch Stampfen.',
    comment: 'Du hast einen Boss plattgetreten. Die Regie hat die Szene dreimal wiederholt.',
    check: (e) => e.type === 'kill' && isBoss(e.monster) && e.technique?.move === 'stampfen',
  },
  {
    id: 'weltkarte', name: 'Weltkarte', tier: 'gold', box: 'abenteurer',
    description: 'Sammle alle vier Gebietskarten einer Etage.',
    comment: 'Du kennst jetzt jeden Winkel. Jeden feuchten, stinkenden Winkel.',
    check: (e, s) => e.type === 'mapPicked' && s.map.hoods.every((h) => h.mapFound),
  },

  // ------------------------------------------------------------ Kampfstile
  {
    id: 'kopf10', name: 'Dickschädel', tier: 'silber', box: 'kleidung',
    description: 'Töte 10 Gegner mit Kopfstößen.',
    comment: 'Dein Kopf ist jetzt offiziell eine Waffe. Dein Gehirn hat Einwände eingereicht.',
    check: (e, s) => e.type === 'kill' && e.technique?.part === 'kopf' && partKills(s, 'kopf') === 10,
  },
  {
    id: 'waffe10', name: 'Handwerker des Todes', tier: 'silber', box: 'waffen',
    description: 'Töte 10 Gegner mit Waffen.',
    comment: 'Werkzeug ist, was man daraus macht.',
    check: (e, s) => e.type === 'kill' && e.technique?.part === 'waffe' && partKills(s, 'waffe') === 10,
  },
  {
    id: 'wurf10', name: 'Steinewerfer', tier: 'silber', box: 'wurf',
    description: 'Töte 10 Gegner mit Würfen.',
    comment: 'Wer im Glashaus sitzt… ach, hier gibt es keine Glashäuser mehr.',
    check: (e, s) => e.type === 'kill' && e.technique?.part === 'wurf' && partKills(s, 'wurf') === 10,
  },
  {
    id: 'anlauf10', name: 'Stier', tier: 'silber', box: 'brawler',
    description: 'Töte 10 Gegner mit Sturmangriffen.',
    comment: 'Kopf runter, losrennen, nicht nachdenken. Eine Lebensphilosophie.',
    check: (e, s) => e.type === 'kill' && e.technique?.move === 'anlauf' && moveKills(s, 'anlauf') === 10,
  },
  {
    id: 'tritt50', name: 'Das Bein der Apokalypse', tier: 'gold', box: 'schuh',
    description: 'Töte 50 Gegner mit Tritten.',
    comment: 'Fünfzig. Mit dem Fuß. Deine Schuhe haben mehr erlebt als die meisten Menschen.',
    check: (e, s) => e.type === 'kill' && e.technique?.part === 'tritt' && partKills(s, 'tritt') === 50,
  },
  {
    id: 'faust50', name: 'Die Faust der Apokalypse', tier: 'gold', box: 'brawler',
    description: 'Töte 50 Gegner mit Faustschlägen.',
    comment: 'Deine Knöchel sind jetzt härter als die Wände. Die Wände haben Angst.',
    check: (e, s) => e.type === 'kill' && e.technique?.part === 'faust' && partKills(s, 'faust') === 50,
  },
  {
    id: 'allrounder', name: 'Schweizer Taschenmesser', tier: 'gold', box: 'brawler',
    description: 'Töte Gegner mit allen sieben Angriffsarten.',
    comment: 'Faust, Fuß, Knie, Ellbogen, Kopf, Waffe, Wurf. Du bist ein wandelndes Kampfsport-Lehrbuch.',
    check: (e, s) => e.type === 'kill' && ['faust', 'tritt', 'knie', 'ellbogen', 'kopf', 'waffe', 'wurf'].every((p) => partKills(s, p) > 0),
  },
  {
    id: 'krit25', name: 'Präzisionsarbeit', tier: 'silber', box: 'waffen',
    description: 'Lande 25 kritische Treffer.',
    comment: 'Immer genau da, wo es wehtut. Du hast ein Talent. Ein verstörendes.',
    check: (e, s) => e.type === 'attack' && e.crit && s.counters.crits === 25,
  },
  {
    id: 'umgehauen', name: 'Umgehauen', tier: 'silber', box: 'schuh',
    description: 'Wirf 15 Gegner zu Boden.',
    comment: 'Die Schwerkraft ist dein bester Freund. Du bist ihr bester Kunde.',
    check: (e, s) => e.type === 'attack' && s.counters.knockdowns === 15,
  },
  {
    id: 'pulverisiert', name: 'Pulverisiert', tier: 'gold', box: 'waffen',
    description: 'Füge mit einem einzigen Angriff 50 Schaden zu.',
    comment: 'Da ist nichts mehr übrig. Die Reinigungskräfte sind verzweifelt.',
    check: (e) => e.type === 'attack' && e.damage >= 50,
  },
  {
    id: 'letzte_kraft', name: 'Mit letzter Kraft', tier: 'gold', box: 'ueberlebens',
    description: 'Töte einen Gegner, während du vergiftet bist und höchstens 5 HP hast.',
    comment: 'Grün, blutend, siegreich. Das ist Fernsehen.',
    check: (e, s) => e.type === 'kill' && s.player.hp <= 5 && s.player.buffs.some((b) => b.name === 'Vergiftet'),
  },
  {
    id: 'klobuerste', name: 'Hygienefachkraft', tier: 'silber', box: 'waffen',
    description: 'Töte einen Gegner mit einer Klobürste.',
    comment: 'Die unwürdigste Art zu sterben. Für ihn. Für dich ein Achievement.',
    check: (e, s) => weaponKill(e, s, 'klobuerste'),
  },
  {
    id: 'selfie', name: 'Content Creator', tier: 'silber', box: 'fan',
    description: 'Töte einen Gegner mit einem Selfie-Stick.',
    comment: 'Das Foto ist fantastisch geworden. Der Gegner eher nicht.',
    check: (e, s) => weaponKill(e, s, 'selfiestick'),
  },
  {
    id: 'baguette', name: 'Französische Revolution', tier: 'silber', box: 'waffen',
    description: 'Töte einen Gegner mit einem versteinerten Baguette.',
    comment: 'Liberté, Égalité, Kopfnuss mit Brot.',
    check: (e, s) => weaponKill(e, s, 'baguette'),
  },
  {
    id: 'bowling', name: 'Strike!', tier: 'silber', box: 'wurf',
    description: 'Wirf eine Bowlingkugel auf einen Gegner und triff.',
    comment: 'Alle Neune. Oder zumindest einer.',
    check: (e) => e.type === 'attack' && e.hit && e.thrown?.baseId === 'bowlingkugel',
  },

  // ------------------------------------------------------------ Mode & Ausrüstung
  {
    id: 'fussringe', name: 'Doppelt beringte Füße', tier: 'gold', box: 'schmuck',
    description: 'Trage zwei Fußringe gleichzeitig.',
    comment: 'Klimper, klimper. Jeder Tritt ein Konzert.',
    check: (e, s) => e.type === 'equip' && !!s.player.equipment.fussring1 && !!s.player.equipment.fussring2,
  },
  {
    id: 'vierfach', name: 'Vierfach beringt', tier: 'platin', box: 'schmuck',
    description: 'Trage zwei Ringe und zwei Fußringe gleichzeitig.',
    comment: 'Du glitzerst. Die Monster sehen dich schon von Weitem. Die Zuschauer auch.',
    check: (e, s) => e.type === 'equip' && ['ring1', 'ring2', 'fussring1', 'fussring2'].every((k) => !!s.player.equipment[k as 'ring1']),
  },
  {
    id: 'komplett', name: 'Komplettpaket', tier: 'platin', box: 'kleidung',
    description: 'Belege alle 17 Ausrüstungsplätze.',
    comment: 'Kopf bis Fuß, Ring bis Unterhose. Du bist jetzt ein wandelnder Kleiderschrank.',
    check: (e, s) => e.type === 'equip' && equipped(s).length >= 17,
  },
  {
    id: 'crocs', name: 'Modeverbrechen', tier: 'bronze', box: 'kleidung',
    description: 'Trage Crocs.',
    comment: 'Die Galaxis hat kurz weggesehen. Aus Respekt vor den Toten.',
    check: (e, s) => e.type === 'equip' && wears(s, 'crocs'),
  },
  {
    id: 'aluhut', name: 'Die Wahrheit ist irgendwo da unten', tier: 'bronze', box: 'kleidung',
    description: 'Trage einen Aluhut.',
    comment: 'Du hattest recht. Aliens haben die Erde übernommen. Hilft dir jetzt aber auch nicht.',
    check: (e, s) => e.type === 'equip' && wears(s, 'aluhut'),
  },
  {
    id: 'zirkus', name: 'Zirkusreif', tier: 'silber', box: 'fan',
    description: 'Trage Clownsnase und Partyhut gleichzeitig.',
    comment: 'Wenn schon untergehen, dann mit Stil. Mit sehr fragwürdigem Stil.',
    check: (e, s) => e.type === 'equip' && wears(s, 'clownsnase') && wears(s, 'partyhut'),
  },
  {
    id: 'stoeckel', name: 'Hohe Absätze, tiefe Wunden', tier: 'silber', box: 'schuh',
    description: 'Töte einen Gegner per Tritt, während du Stöckelschuhe trägst.',
    comment: 'Zwölf Zentimeter Absatz, null Gnade.',
    check: (e, s) => e.type === 'kill' && e.technique?.part === 'tritt' && wears(s, 'stoeckelschuhe'),
  },
  {
    id: 'legendaer', name: 'Legendär!', tier: 'gold', box: 'abenteurer',
    description: 'Finde einen legendären Gegenstand.',
    comment: 'Orange! Es ist orange! Alle Gamer der Galaxis kreischen gerade.',
    check: (e) => gotItem(e, ['legendaer', 'himmlisch']),
  },
  {
    id: 'himmlisch', name: 'Himmlische Fügung', tier: 'legendaer', box: 'abenteurer',
    description: 'Finde einen himmlischen Gegenstand.',
    comment: 'Es gibt davon nur eine Handvoll in der Geschichte der Show. Und du hast eins. Die Systemstimme ist neidisch.',
    check: (e) => gotItem(e, ['himmlisch']),
  },

  // ------------------------------------------------------------ Leben im Dungeon
  {
    id: 'gold100', name: 'Dagobert-Syndrom', tier: 'silber', box: 'fan',
    description: 'Besitze 100 Gold auf einmal.',
    comment: 'Hundert Goldstücke. Du könntest darin baden. Bitte nicht.',
    check: (e, s) => e.type === 'goldGained' && s.player.gold >= 100,
  },
  {
    id: 'gold500', name: 'Kapitalist', tier: 'gold', box: 'fan',
    description: 'Verdiene insgesamt 500 Gold.',
    comment: 'Die Wirtschaft ist zusammengebrochen. Deine nicht.',
    check: (e, s) => e.type === 'goldGained' && s.counters.goldEarned >= 500,
  },
  {
    id: 'drei_gaenge', name: 'Drei-Gänge-Menü', tier: 'silber', box: 'ueberlebens',
    description: 'Iss dreimal in einem Restaurant.',
    comment: 'Vorspeise, Hauptgang, Monster. Guten Appetit.',
    check: (e, s) => e.type === 'eat' && s.counters.mealsEaten === 3,
  },
  {
    id: 'winterschlaf', name: 'Winterschlaf', tier: 'silber', box: 'ueberlebens',
    description: 'Schlafe fünfmal in Safe Rooms.',
    comment: 'Du verschläfst die Apokalypse. Respekt.',
    check: (e, s) => e.type === 'sleep' && s.counters.sleeps === 5,
  },
  {
    id: 'trankjunkie', name: 'Trank-Junkie', tier: 'silber', box: 'ueberlebens',
    description: 'Trinke 10 Tränke.',
    comment: 'Kirsche, Kreide, Verzweiflung. Du kennst alle Geschmacksrichtungen.',
    check: (e, s) => e.type !== 'moved' && s.counters.potionsDrunk === 10,
  },
  {
    id: 'boxen25', name: 'Schatzsucher', tier: 'gold', box: 'fan',
    description: 'Öffne 25 Lootboxen.',
    comment: 'Du hast ein Problem. Ein glänzendes, belohnendes Problem.',
    check: (e, s) => e.type === 'boxOpened' && s.counters.boxesOpened === 25,
  },
  {
    id: 'haustier5', name: 'Tierischer Aufstieg', tier: 'gold', box: 'haustier',
    description: 'Bringe dein Haustier auf Stufe 5.',
    comment: 'Dein Haustier ist jetzt gefährlicher als du. Merk dir das.',
    check: (e, s) => e.type === 'kill' && (s.player.pet?.level ?? 0) >= 5,
  },
  {
    id: 'level10', name: 'Zweistellig', tier: 'gold', box: 'abenteurer',
    description: 'Erreiche Level 10.',
    comment: 'Level 10. Jetzt bist du offiziell kein Futter mehr. Nur noch Vorspeise.',
    check: (e) => e.type === 'levelUp' && e.level === 10,
  },
  {
    id: 'level15', name: 'Veteran', tier: 'platin', box: 'abenteurer',
    description: 'Erreiche Level 15.',
    comment: 'Die meisten Crawler sterben lange vorher. Du bist nicht wie die meisten. Leider für die Monster.',
    check: (e) => e.type === 'levelUp' && e.level === 15,
  },
  {
    id: 'skill10', name: 'Meisterklasse', tier: 'gold', box: 'brawler',
    description: 'Bringe einen Skill auf Stufe 10.',
    comment: 'Zehntausend Stunden Übung? Hier reichen ein paar hundert Kämpfe.',
    check: (e) => e.type === 'skillUp' && e.level === 10,
  },
  {
    id: 'vielseitig', name: 'Vielseitig', tier: 'silber', box: 'abenteurer',
    description: 'Lerne 5 Skills durch Übung.',
    comment: 'Du kannst ein bisschen von allem. Die Systemstimme nennt das „unentschlossen“.',
    check: (e, s) => e.type === 'skillLearned' && s.player.skills.filter((k) => !['erste_hilfe', 'kochen', 'spielerfahrung'].includes(k.id)).length === 5,
  },
  {
    id: 'streber', name: 'Streber', tier: 'silber', box: 'abenteurer',
    description: 'Schließe das Tutorial in der ersten Stunde ab.',
    comment: 'Direkt zur Gilde. Keine Umwege. Deine Lehrer hätten dich geliebt.',
    check: (e, s) => e.type === 'tutorialDone' && s.turn <= 20,
  },
  {
    id: 'anleitung', name: 'Wer braucht schon Anleitungen?', tier: 'silber', box: 'brawler',
    description: 'Schließe das Tutorial erst mit Level 4 oder höher ab.',
    comment: 'Erst prügeln, dann lesen. Eine Strategie, die in keinem Handbuch steht. Weil du keins gelesen hast.',
    check: (e, s) => e.type === 'tutorialDone' && s.player.level >= 4,
  },
  {
    id: 'etage3', name: 'Ab in die Kanalisation', tier: 'gold', box: 'abenteurer',
    description: 'Erreiche Etage 3.',
    comment: 'Es riecht. Es riecht wirklich sehr. Willkommen auf Etage 3.',
    check: (e) => e.type === 'descend' && e.floor === 3,
  },
];
