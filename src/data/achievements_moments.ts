import type { GameState } from '../engine/types';
import type { AchievementCategory, AchievementDef } from './achievements';

/**
 * Besondere Momente: einmalige Situationen, die das System bemerkt.
 * Die Umstände werden in engine/stats.ts erfasst (z. B. „boss.makellos“),
 * hier wird nur noch nachgesehen.
 */

const st = (s: GameState, key: string) => s.stats?.[key] ?? 0;
/** Schwelle auf einem Statistik-Wert; Schlüssel und Schwelle hängen an der Funktion (für den Godot-Export). */
const once = (key: string, n = 1) => Object.assign((_e: unknown, s: GameState) => st(s, key) >= n, { statKey: key, n });

type Moment = Omit<AchievementDef, 'check' | 'category'> & { check: AchievementDef['check'] };

const MOMENTS: Moment[] = [
  // ------------------------------------------------------------ Kampf
  {
    id: 'mo_einschlag', name: 'Ein Schlag, ein Grab', tier: 'silber', box: 'brawler',
    description: 'Besiege einen Gegner mit einem Treffer, der mindestens so viel Schaden macht, wie er Lebenspunkte hat.',
    comment: 'Kein Vorgeplänkel, kein zweiter Versuch. Die Regie hat die Zeitlupe gleich dreimal abgespielt.',
    check: once('kills.einschlag'),
  },
  {
    id: 'mo_einschlag10', name: 'Kurzer Prozess', tier: 'gold', box: 'brawler',
    description: 'Besiege 10 Gegner mit jeweils einem einzigen Treffer.',
    comment: 'Zehnmal ein Schlag. Die Monster haben angefangen, dir aus dem Weg zu gehen. Klug von ihnen.',
    check: once('kills.einschlag', 10),
  },
  {
    id: 'mo_anatomie', name: 'Anatomiestunde', tier: 'silber', box: 'brawler',
    description: 'Triff denselben Gegner an Kopf, Armen und Beinen, bevor er fällt.',
    comment: 'Gründlich. Sehr gründlich. Die Systemstimme schickt dir ein Diplom in Humanmedizin. Monstermedizin. Egal.',
    check: once('kills.anatomie'),
  },
  {
    id: 'mo_erschoepft', name: 'Auf dem Zahnfleisch', tier: 'bronze', box: 'ueberlebens',
    description: 'Besiege einen Gegner mit deinem allerletzten Ausdauerpunkt.',
    comment: 'Keine Luft mehr, aber noch ein Schlag. Die Zuschauer haben mitgekeucht.',
    check: once('kills.erschoepft'),
  },
  {
    id: 'mo_toedlich', name: 'Unmöglich ist nur ein Wort', tier: 'platin', box: 'brawler',
    description: 'Besiege einen Gegner, der als tödlich eingestuft ist (mindestens sechs Stufen über dir).',
    comment: 'Die Wettbüros der Galaxis haben heute sehr viel Geld verloren. Sie sind nicht erfreut.',
    check: once('kills.toedlich'),
  },
  {
    id: 'mo_elite_staerker', name: 'Elite? Pah!', tier: 'gold', box: 'waffen',
    description: 'Besiege einen Elite-Gegner, der mindestens drei Stufen über dir steht.',
    comment: 'Elite heißt übersetzt: nicht gut genug für dich.',
    check: once('kills.elite.staerker'),
  },
  {
    id: 'mo_riese', name: 'Je größer sie sind', tier: 'silber', box: 'brawler',
    description: 'Besiege einen riesigen Gegner.',
    comment: '... desto lauter fallen sie. Der Boden hat noch eine Weile nachgezittert.',
    check: once('kills.riesig'),
  },
  {
    id: 'mo_unbekannt', name: 'Was war das eigentlich?', tier: 'silber', box: 'abenteurer',
    description: 'Besiege einen Gegner, den du nicht einschätzen konntest.',
    comment: 'Du weißt nicht, was es war. Du weißt nur, dass es jetzt tot ist. Reicht auch.',
    check: once('kills.unbekannt'),
  },
  {
    id: 'mo_tuer', name: 'Türsteher', tier: 'bronze', box: 'abenteurer',
    description: 'Besiege einen Gegner, der gerade in einer Tür steht.',
    comment: 'Hier kommt keiner rein. Und der da kommt auch nicht mehr raus.',
    check: once('kills.tuer'),
  },
  {
    id: 'mo_umzingelt', name: 'Rücken frei? Fehlanzeige.', tier: 'silber', box: 'brawler',
    description: 'Besiege 10 Gegner, während du von mindestens drei Gegnern umringt bist.',
    comment: 'Umzingelt ist nur ein anderes Wort für: viele Ziele in Reichweite.',
    check: once('kills.umzingelt', 10),
  },
  {
    id: 'mo_nackt', name: 'Nacktkampf', tier: 'silber', box: 'kleidung',
    description: 'Besiege 10 Gegner, ohne irgendetwas angelegt zu haben.',
    comment: 'Keine Rüstung, keine Hose, keine Scham. Die Zensurabteilung hat Überstunden gemacht.',
    check: once('kills.nackt', 10),
  },
  {
    id: 'mo_barfuss', name: 'Barfußpfad', tier: 'bronze', box: 'schuh',
    description: 'Besiege 25 Gegner barfuß.',
    comment: 'Deine Fußsohlen sind inzwischen härter als die meisten Rüstungen hier unten.',
    check: once('kills.barfuss', 25),
  },
  {
    id: 'mo_bademantel', name: 'Frottee-Terror', tier: 'silber', box: 'kleidung',
    description: 'Besiege 25 Gegner im Bademantel.',
    comment: 'Der gefürchtetste Bademantel der Galaxis. Es gibt schon Fanartikel.',
    check: once('kills.bademantel', 25),
  },
  {
    id: 'mo_angetrunken', name: 'Kneipenschlägerei', tier: 'bronze', box: 'brawler',
    description: 'Besiege 5 Gegner, während du angetrunken bist.',
    comment: 'Dein Kampfstil ist unvorhersehbar. Für alle Beteiligten, dich eingeschlossen.',
    check: once('kills.angetrunken', 5),
  },
  {
    id: 'mo_feuertaufe', name: 'Feuertaufe', tier: 'silber', box: 'ueberlebens',
    description: 'Besiege einen Gegner, während du selbst in Flammen stehst.',
    comment: 'Du brennst, und trotzdem hast du zuerst an ihn gedacht. Das nennt man Prioritäten.',
    check: once('kills.selbstbrennend'),
  },
  {
    id: 'mo_blindflug', name: 'Blindflug', tier: 'silber', box: 'brawler',
    description: 'Besiege einen Gegner, während du geblendet bist.',
    comment: 'Du hast nichts gesehen. Der Gegner leider schon.',
    check: once('kills.geblendet'),
  },
  {
    id: 'mo_mut', name: 'Mut ist, wenn man trotzdem zuschlägt', tier: 'silber', box: 'fan',
    description: 'Besiege einen Gegner, während du verängstigt bist.',
    comment: 'Die Knie haben gezittert. Die Faust nicht.',
    check: once('kills.veraengstigt'),
  },
  // ------------------------------------------------------------ Bosse
  {
    id: 'mo_boss_makellos', name: 'Makellos', tier: 'gold', box: 'boss',
    description: 'Besiege einen Boss, während du volle Lebenspunkte hast.',
    comment: 'Nicht ein Kratzer. Der Boss hat sich beim Management beschwert. Abgelehnt.',
    check: once('boss.makellos'),
  },
  {
    id: 'mo_boss_zauber', name: 'Abrakadabra', tier: 'gold', box: 'boss',
    description: 'Besiege einen Boss mit einem Zauber.',
    comment: 'Ein Fingerschnippen, ein Boss weniger. Die Magieabteilung ist stolz auf dich.',
    check: once('boss.zauber'),
  },
  {
    id: 'mo_boss_falle', name: 'In die Falle gelockt', tier: 'gold', box: 'boss',
    description: 'Besiege einen Boss mit einer Falle oder einem Sprengsatz.',
    comment: 'Planung schlägt Muskeln. Und Sprengstoff schlägt beides.',
    check: once('boss.falle'),
  },
  {
    id: 'mo_boss_haustier', name: 'Braves Tier!', tier: 'gold', box: 'haustier',
    description: 'Lass dein Haustier den letzten Treffer gegen einen Boss landen.',
    comment: 'Du hast die Vorarbeit gemacht. Die Zuschauer jubeln trotzdem nur dem Tier zu.',
    check: once('boss.haustier'),
  },
  {
    id: 'mo_boss_party', name: 'Gemeinsam stark', tier: 'silber', box: 'boss',
    description: 'Lass ein Party-Mitglied den letzten Treffer gegen einen Boss landen.',
    comment: 'Teamarbeit. Der Ruhm wird geteilt. Die Beute nicht.',
    check: once('boss.party'),
  },
  {
    id: 'mo_boss_sprung', name: 'Todessprung', tier: 'gold', box: 'schuh',
    description: 'Besiege einen Boss mit einem Sprungangriff.',
    comment: 'Aus der Luft, mit vollem Gewicht. Die Kamera hat es aus sieben Winkeln.',
    check: once('boss.sprung'),
  },
  {
    id: 'mo_boss_kopf', name: 'Kopf ab, Krone weg', tier: 'gold', box: 'boss',
    description: 'Besiege einen Boss mit einem gezielten Kopftreffer.',
    comment: 'Genau zwischen die Augen. Oder wo auch immer dieses Ding seine Augen hatte.',
    check: once('boss.kopf'),
  },
  {
    id: 'mo_boss_gerammt', name: 'Vorfahrt missachtet', tier: 'platin', box: 'boss',
    description: 'Besiege einen Boss, indem du ihn mit deinem Reittier rammst.',
    comment: 'Der Unfallbericht ist eindeutig. Der Boss hätte nicht auf der Fahrbahn stehen sollen.',
    check: once('boss.gerammt'),
  },
  {
    id: 'mo_boss_konter', name: 'Der Spieß umgedreht', tier: 'gold', box: 'brawler',
    description: 'Besiege einen Boss mit einem Konter.',
    comment: 'Er hat angegriffen. Du hast geantwortet. Das Gespräch ist beendet.',
    check: once('boss.konter'),
  },
  {
    id: 'mo_boss_schlafend', name: 'Gute-Nacht-Geschichte', tier: 'gold', box: 'boss',
    description: 'Besiege einen Boss, der noch schläft.',
    comment: 'Er ist nie aufgewacht. Die Zuschauer finden das unfair. Die Wettquoten fanden es großartig.',
    check: once('boss.schlafend'),
  },
  // ------------------------------------------------------------ Sprengstoff und Fallen
  {
    id: 'mo_explosion3', name: 'Drei auf einen Streich', tier: 'gold', box: 'wurf',
    description: 'Besiege drei Gegner mit einer einzigen Explosion.',
    comment: 'Effizienz ist das neue Schwarz. Oder das neue Verkohlt.',
    check: once('max.explosionkills', 3),
  },
  {
    id: 'mo_eigentor', name: 'Eigentor', tier: 'bronze', box: 'ueberlebens',
    description: 'Werde von deinem eigenen Sprengsatz getroffen.',
    comment: 'Die Druckwelle kennt keine Freunde. Das steht auch klein gedruckt auf der Packung.',
    check: once('explosion.selbst'),
  },
  {
    id: 'mo_befreit_kampf', name: 'Entfesselungskunst', tier: 'silber', box: 'ueberlebens',
    description: 'Befreie dich aus einer Falle, während ein Gegner direkt auf dich zukommt.',
    comment: 'Genau im richtigen Moment. Die Musik der Regie hat perfekt gepasst.',
    check: once('befreit.kampf'),
  },
  {
    id: 'mo_weitwurf', name: 'Weitwurf', tier: 'bronze', box: 'wurf',
    description: 'Besiege einen Gegner mit einem Wurf aus mindestens fünf Feldern Entfernung.',
    comment: 'Die Flugbahn war perfekt. Das Ziel war es danach nicht mehr.',
    check: once('kills.weitwurf'),
  },
  // ------------------------------------------------------------ Überleben
  {
    id: 'mo_ein_lp', name: 'Ein einziger Lebenspunkt', tier: 'gold', box: 'ueberlebens',
    description: 'Überlebe einen Treffer mit genau einem Lebenspunkt.',
    comment: 'Eins. Ein Punkt. Die Systemstimme hatte den Nachruf schon angefangen.',
    check: once('ueberlebt.einlp'),
  },
  {
    id: 'mo_trank_knapp', name: 'Rettung aus der Flasche', tier: 'silber', box: 'ueberlebens',
    description: 'Trinke einen Trank mit weniger als 10 % deiner Lebenspunkte.',
    comment: 'Ein Schluck zwischen dir und dem Jenseits. Er hat geschmeckt wie Hustensaft.',
    check: once('traenke.knapp'),
  },
  {
    id: 'mo_rettung_haustier', name: 'Gerettet von der Fellnase', tier: 'silber', box: 'haustier',
    description: 'Dein Haustier besiegt einen Gegner, während du fast tot bist.',
    comment: 'Das Tier hat dir das Leben gerettet. Es wird dich nie wieder vergessen lassen.',
    check: once('rettung.haustier'),
  },
  {
    id: 'mo_rettung_party', name: 'Rückendeckung', tier: 'silber', box: 'abenteurer',
    description: 'Ein Party-Mitglied besiegt einen Gegner, während du fast tot bist.',
    comment: 'Freunde sind Leute, die im richtigen Moment zuschlagen. Diesmal wörtlich.',
    check: once('rettung.party'),
  },
  {
    id: 'mo_saferoom_knapp', name: 'Rettendes Ufer', tier: 'silber', box: 'ueberlebens',
    description: 'Betritt einen Safe Room, während ein Gegner direkt hinter dir ist.',
    comment: 'Der Türsteher hat nur kurz genickt. Dein Verfolger durfte draußen bleiben.',
    check: once('saferoom.knapp'),
  },
  {
    id: 'mo_tuer_zu', name: 'Tür zu, es zieht!', tier: 'bronze', box: 'abenteurer',
    description: 'Schließe eine Tür, während ein wacher Gegner ganz in der Nähe ist.',
    comment: 'Monster können Türen öffnen. Aber es ist die Geste, die zählt.',
    check: once('tueren.zugeschlagen'),
  },
  {
    id: 'mo_schlaflos', name: 'Schlaflos im Keller', tier: 'silber', box: 'ueberlebens',
    description: 'Halte 24 Stunden durch, ohne zu schlafen.',
    comment: 'Deine Augenringe haben eigene Augenringe. Die Zuschauer sind trotzdem begeistert.',
    check: once('max.wach', 480),
  },
  {
    id: 'mo_umzingelt_aufstieg', name: 'Aufstieg unter Druck', tier: 'silber', box: 'brawler',
    description: 'Steige eine Stufe auf, während dich mindestens zwei Gegner bedrängen.',
    comment: 'Du hast gelevelt. Die Monster nicht. Das wird ihnen gleich leidtun.',
    check: once('aufstieg.umzingelt'),
  },
  {
    id: 'mo_doppelaufstieg', name: 'Doppelter Aufstieg', tier: 'gold', box: 'abenteurer',
    description: 'Steige mit einem einzigen Kill zwei Stufen auf einmal auf.',
    comment: 'So viel Erfahrung auf einmal. Dein Kopf brummt, aber auf die gute Art.',
    check: once('max.aufstiege.zug', 2),
  },
  // ------------------------------------------------------------ Alltag im Dungeon
  {
    id: 'mo_snack', name: 'Snack zwischendurch', tier: 'bronze', box: 'ueberlebens',
    description: 'Iss etwas, während ein Gegner direkt neben dir steht.',
    comment: 'Hunger kennt keinen Waffenstillstand. Der Gegner war ehrlich gesagt beeindruckt.',
    check: once('essen.imkampf'),
  },
  {
    id: 'mo_toilette_kampf', name: 'Es war dringend', tier: 'silber', box: 'kleidung',
    description: 'Benutze eine Toilette, während ein wacher Gegner in der Nähe ist.',
    comment: 'Manche Dinge können nicht warten. Die Regie hat diskret weggeblendet. Fast.',
    check: once('toilette.imkampf'),
  },
  {
    id: 'mo_unfall', name: 'Malheur', tier: 'bronze', box: 'kleidung',
    description: 'Schaffe es nicht mehr rechtzeitig zur Toilette.',
    comment: 'Das haben ungefähr vier Milliarden Zuschauer gesehen. Die Wiederholung läuft in Endlosschleife.',
    check: once('unfall'),
  },
  {
    id: 'mo_boxen_horten', name: 'Lieber später auspacken', tier: 'bronze', box: 'abenteurer',
    description: 'Horte 10 ungeöffnete Boxen gleichzeitig.',
    comment: 'Vorfreude ist die schönste Freude. Oder du hast einfach vergessen, sie zu öffnen.',
    check: (_e, s) => s.player.boxes.length >= 10,
  },
  {
    id: 'mo_goldbad', name: 'Goldbad', tier: 'gold', box: 'abenteurer',
    description: 'Besitze 2.000 Gold auf einmal.',
    comment: 'Du könntest darin baden. Bitte tu es nicht. Die Zuschauer haben schon genug gesehen.',
    check: once('max.gold', 2000),
  },
  // ------------------------------------------------------------ Handel und Glück
  {
    id: 'mo_feilschen_max', name: 'Halsabschneider', tier: 'silber', box: 'abenteurer',
    description: 'Handle mindestens 25 % Rabatt heraus.',
    comment: 'Hinter der Theke wird leise geweint. Du hast kein Mitleid.',
    check: once('feilschen.maximal'),
  },
  {
    id: 'mo_feilschen_pleiten', name: 'Beratungsresistent', tier: 'bronze', box: 'fan',
    description: 'Scheitere dreimal hintereinander beim Feilschen.',
    comment: 'Die Preise sind jetzt höher als vorher. Das nennt man wohl Verhandlungsgeschick.',
    check: once('max.feilschpleiten', 3),
  },
  {
    id: 'mo_ausverkauf', name: 'Alles muss raus', tier: 'gold', box: 'abenteurer',
    description: 'Kaufe einen Laden komplett leer.',
    comment: 'Das Regal ist leer, die Kasse ist voll. Der Laden macht heute früher zu.',
    check: once('laden.leergekauft'),
  },
  {
    id: 'mo_jackpot', name: 'Drei goldene Kronen', tier: 'gold', box: 'fan',
    description: 'Knacke den Jackpot eines Rubbelloses.',
    comment: 'Die Chancen standen schlecht. Die Systemstimme prüft gerade, ob du geschummelt hast.',
    check: once('lose.jackpot'),
  },
  {
    id: 'mo_nieten', name: 'Dauerpech', tier: 'bronze', box: 'fan',
    description: 'Ziehe 10 Nieten beim Rubbellos.',
    comment: 'Zehn Nieten. Das Glücksspiel ist nicht dein Freund. Die Losbude sieht das anders.',
    check: once('lose.nieten', 10),
  },
  {
    id: 'mo_kettenzauber', name: 'Kettenreaktion', tier: 'gold', box: 'abenteurer',
    description: 'Besiege drei Gegner mit einem einzigen Zauber.',
    comment: 'Ein Zauber, drei Beerdigungen. Die Magieabteilung verlangt eine Gebühr für die Nutzung.',
    check: (e) => e.type === 'spellCast' && e.kills >= 3,
  },
  // ------------------------------------------------------------ Andere Crawler
  {
    id: 'mo_gerettet_party', name: 'Vom Retter zum Freund', tier: 'gold', box: 'abenteurer',
    description: 'Nimm einen Crawler in die Party auf, den du vorher versorgt hast.',
    comment: 'Freundschaft beginnt mit einem Heiltrank. So steht es in keinem Buch, aber es stimmt.',
    check: once('party.gerettet'),
  },
  {
    id: 'mo_auftrag_verpatzt', name: 'Versprochen ist versprochen', tier: 'bronze', box: 'fan',
    description: 'Lass einen Auftrag scheitern.',
    comment: 'Die Enttäuschung im Gesicht deines Auftraggebers war sehenswert. Die Zuschauer haben es genossen.',
    check: once('auftraege.verpatzt'),
  },
  // ------------------------------------------------------------ Etagen
  {
    id: 'mo_etage2_frueh', name: 'Mut zur Lücke', tier: 'silber', box: 'ueberlebens',
    description: 'Erreiche Etage 2 mit Stufe 3 oder weniger.',
    comment: 'Unterlevelt, aber optimistisch. Die Systemstimme hat die Sterbeversicherung schon mal angefragt.',
    check: (e, s) => e.type === 'descend' && e.floor === 2 && s.player.level <= 3,
  },
  {
    id: 'mo_etage3_frueh', name: 'Ins kalte Wasser', tier: 'gold', box: 'ueberlebens',
    description: 'Erreiche Etage 3 mit Stufe 6 oder weniger.',
    comment: 'Die Kanalisation erwartet dich. Sie hat Hunger, und du bist sehr klein.',
    check: (e, s) => e.type === 'descend' && e.floor === 3 && s.player.level <= 6,
  },
];

// ------------------------------------------------------------ Improvisierte Waffen
const WEAPON_MOMENTS: [string, string, string, string][] = [
  ['bratpfanne', 'Gut durch', 'Besiege 5 Gegner mit einer Bratpfanne.', 'Das Geräusch einer Bratpfanne auf einem Schädel ist Musik. Sagt die Tonabteilung.'],
  ['handtasche', 'Handtaschen-Hieb', 'Besiege 5 Gegner mit einer schweren Handtasche.', 'Was da wohl drin ist? Niemand wagt es zu fragen.'],
  ['regenschirm', 'Bei jedem Wetter', 'Besiege 5 Gegner mit einem Regenschirm.', 'Hier unten regnet es nie. Der Schirm hat trotzdem seinen Zweck gefunden.'],
  ['nudelholz', 'Ausgerollt', 'Besiege 5 Gegner mit einem Nudelholz.', 'Flach wie ein Pizzateig. Die Kochshow des Senders hat angefragt.'],
  ['golfschlaeger', 'Einlochen', 'Besiege 5 Gegner mit einem Golfschläger.', 'Ein sauberer Abschlag. Das Loch war allerdings ein Monster.'],
  ['tischtennis', 'Rückhand', 'Besiege 5 Gegner mit einem Tischtennisschläger.', 'Niemand hat das kommen sehen. Wirklich niemand.'],
  ['kettensaege', 'Auch ohne Benzin', 'Besiege 5 Gegner mit der Kettensäge ohne Benzin.', 'Sie läuft nicht. Sie ist trotzdem schwer. Das reicht.'],
  ['schoepfkelle', 'Nachschlag', 'Besiege 5 Gegner mit Omas Schöpfkelle.', 'Es gibt noch Nachschlag. Für jeden. Ob er will oder nicht.'],
];

for (const [weapon, name, description, comment] of WEAPON_MOMENTS) {
  MOMENTS.push({
    id: `mo_waffe_${weapon}`, name, description, comment, tier: 'bronze', box: 'waffen',
    check: once(`kills.waffe.${weapon}`, 5),
  });
}

/** Wo die Momente in der Übersicht stehen; alles andere landet unter „Besondere Momente“. */
const CATEGORY: Record<string, AchievementCategory> = {
  mo_einschlag: 'kampf', mo_einschlag10: 'kampf', mo_erschoepft: 'kampf', mo_toedlich: 'kampf', mo_riese: 'kampf',
  mo_umzingelt: 'kampf', mo_anatomie: 'technik', mo_weitwurf: 'technik', mo_elite_staerker: 'bestiarium', mo_unbekannt: 'bestiarium',
  mo_boss_makellos: 'bestiarium', mo_boss_zauber: 'magie', mo_boss_falle: 'handwerk', mo_boss_haustier: 'sozial', mo_boss_party: 'sozial',
  mo_boss_sprung: 'technik', mo_boss_kopf: 'technik', mo_boss_gerammt: 'bestiarium', mo_boss_konter: 'technik', mo_boss_schlafend: 'bestiarium',
  mo_explosion3: 'handwerk', mo_eigentor: 'handwerk', mo_befreit_kampf: 'ueberleben', mo_ein_lp: 'ueberleben', mo_trank_knapp: 'ueberleben',
  mo_rettung_haustier: 'sozial', mo_rettung_party: 'sozial', mo_saferoom_knapp: 'ueberleben', mo_tuer_zu: 'erkundung', mo_schlaflos: 'ueberleben',
  mo_doppelaufstieg: 'fortschritt', mo_boxen_horten: 'beute', mo_goldbad: 'wirtschaft', mo_feilschen_max: 'wirtschaft',
  mo_feilschen_pleiten: 'wirtschaft', mo_ausverkauf: 'wirtschaft', mo_jackpot: 'wirtschaft', mo_nieten: 'wirtschaft', mo_kettenzauber: 'magie',
  mo_feuertaufe: 'ueberleben', mo_blindflug: 'kampf', mo_mut: 'kampf', mo_gerettet_party: 'sozial', mo_auftrag_verpatzt: 'sozial', mo_etage2_frueh: 'erkundung', mo_etage3_frueh: 'erkundung',
};

export const MOMENT_ACHIEVEMENTS: AchievementDef[] = MOMENTS.map((m) => ({
  ...m,
  category: CATEGORY[m.id] ?? (m.id.startsWith('mo_waffe_') ? 'technik' : 'momente'),
}));

/** Moment-Achievements mit Statistik-Schwelle (für den Godot-Export). */
export function momentTable() {
  return MOMENTS.map((m) => ({ id: m.id, stat: (m.check as { statKey?: string }).statKey ?? null, n: (m.check as { n?: number }).n ?? null }));
}
