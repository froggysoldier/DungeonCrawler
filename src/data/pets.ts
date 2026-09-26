/** Haustierarten: aus Eiern, durch Zähmen, oder aus dem Interview. */
export interface PetSpecies {
  id: string;
  name: string;
  hp: number;
  dmg: [number, number];
  flavor: string;
}

export const PET_SPECIES: Record<string, PetSpecies> = {
  Katze: { id: 'Katze', name: 'Katze', hp: 12, dmg: [1, 3], flavor: 'Deine Katze. Sie hält dich für ihr Personal.' },
  Hund: { id: 'Hund', name: 'Hund', hp: 16, dmg: [2, 3], flavor: 'Dein Hund. Er hält dich für den Anführer.' },
  Kellerraptor: { id: 'Kellerraptor', name: 'Kellerraptor', hp: 22, dmg: [3, 6], flavor: 'Ein kleiner, schnappender Raubsaurier. Er wird größer. Und hungriger.' },
  Minidrache: { id: 'Minidrache', name: 'Minidrache', hp: 18, dmg: [3, 5], flavor: 'Faustgroß, schuppig, feuerspeiend. Hauptsächlich auf deine Schuhe.' },
  Wolpertinger: { id: 'Wolpertinger', name: 'Wolpertinger', hp: 14, dmg: [2, 4], flavor: 'Gezähmt. Also: weniger wütend. Ein bisschen.' },
  Fledermaus: { id: 'Fledermaus', name: 'Fledermaus', hp: 8, dmg: [1, 3], flavor: 'Hängt kopfüber an deiner Schulter. Findet dich super.' },
  Ratte: { id: 'Ratte', name: 'Ratte', hp: 10, dmg: [1, 3], flavor: 'Deine eigene Ratte. Sie hat Freunde. Viele Freunde.' },
  Spinne: { id: 'Spinne', name: 'Kellerspinne', hp: 10, dmg: [2, 3], flavor: 'Acht Beine, acht Augen, ein Herz. Für dich.' },
};

export const EGG_SPECIES: Record<string, string> = {
  ei_raptor: 'Kellerraptor',
  ei_drache: 'Minidrache',
};

/** Welche Monster man zähmen kann (Monster-ID → Haustierart). */
export const TAMEABLE: Record<string, string> = {
  wolpertinger: 'Wolpertinger',
  fledermaus: 'Fledermaus',
  kellerratte: 'Ratte',
  kellerspinne: 'Spinne',
};

export const HATCH_TURNS = 160;
