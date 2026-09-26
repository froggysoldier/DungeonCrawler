/**
 * Reittiere und Fahrzeuge. Alle frei erfunden. Wer reitet, bewegt sich
 * schneller (mehrere Schritte pro Zug) und kann Gegner mit Anlauf rammen.
 * Fahrzeuge brauchen Treibstoff, Tiere nicht.
 */
export interface MountDef {
  id: string;
  name: string;
  kind: 'tier' | 'fahrzeug';
  hp: number;
  /** Schritte pro Zug. */
  speed: number;
  /** Zusatzschaden beim Rammen (Anlauf). */
  ram: number;
  /** Treibstoff in Schritten (nur Fahrzeuge). */
  fuel?: number;
  /** Rüstung für den Reiter. */
  ruestung?: number;
  flavor: string;
}

export const MOUNTS: Record<string, MountDef> = {
  einkaufswagen: { id: 'einkaufswagen', name: 'Motorisierter Einkaufswagen', kind: 'fahrzeug', hp: 25, speed: 2, ram: 6, fuel: 160, flavor: 'Ein Einkaufswagen mit Rasenmähermotor. Quietscht in jeder Kurve. Die Zuschauer lieben ihn.' },
  rasentraktor: { id: 'rasentraktor', name: 'Aufsitzrasenmäher', kind: 'fahrzeug', hp: 45, speed: 2, ram: 10, fuel: 220, ruestung: 1, flavor: 'Grün, laut, unaufhaltsam. Mäht Gras. Und anderes.' },
  bobbycar: { id: 'bobbycar', name: 'Raketen-Bobbycar', kind: 'fahrzeug', hp: 15, speed: 3, ram: 8, fuel: 90, flavor: 'Ein rotes Bobbycar mit einer Feuerwerksrakete hinten dran. Sicherheitsbewertung: nein.' },
  kellerpony: { id: 'kellerpony', name: 'Kellerpony', kind: 'tier', hp: 30, speed: 2, ram: 5, flavor: 'Klein, zottelig, stur. Hat beschlossen, dass du ihm gehörst.' },
  sattelschnecke: { id: 'sattelschnecke', name: 'Sattelschnecke', kind: 'tier', hp: 70, speed: 1, ram: 4, ruestung: 3, flavor: 'Nicht schnell. Aber du sitzt in einem Schleimpanzer, und nichts kommt richtig an dich heran.' },
  kampfeber: { id: 'kampfeber', name: 'Kampfeber', kind: 'tier', hp: 45, speed: 2, ram: 12, flavor: 'Hauer wie Säbel, Laune wie ein Montagmorgen. Perfekt zum Rammen.' },
};

/** Gegenstand, der ein Reittier bringt (Basis-ID → Reittier). */
export const MOUNT_ITEMS: Record<string, string> = {
  zuendschluessel_wagen: 'einkaufswagen',
  zuendschluessel_traktor: 'rasentraktor',
  zuendschluessel_bobbycar: 'bobbycar',
  pfeife_pony: 'kellerpony',
  pfeife_schnecke: 'sattelschnecke',
  pfeife_eber: 'kampfeber',
};
