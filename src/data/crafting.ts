/**
 * Handwerk: aus Kram, den man im Dungeon findet, entstehen Sprengsätze,
 * Fallen und Verbände. Aufwendige Rezepte brauchen eine Werkbank
 * (Werkstatt- und Schmiederäume oder eine Klappwerkbank im Inventar).
 */
export interface Ingredient {
  /** Eine dieser Basis-IDs genügt. */
  ids: string[];
  n: number;
  label: string;
}

export interface Recipe {
  id: string;
  name: string;
  description: string;
  ingredients: Ingredient[];
  /** Ergebnis (Basis-ID und Menge). Fehlt bei Sonderrezepten. */
  result?: { id: string; n: number };
  /** Verbessert die ausgerüstete Waffe statt ein neues Item zu erzeugen. */
  upgradeWeapon?: boolean;
  workbench: boolean;
  /** Sprengsätze profitieren vom Skill „Handwerk“. */
  explosive?: boolean;
}

export const RECIPES: Recipe[] = [
  {
    id: 'verband', name: 'Verband', workbench: false,
    description: 'Zwei Lappen in Streifen reißen. Heilt 10 HP (kein Trank, keine Abklingzeit).',
    ingredients: [{ ids: ['lappen'], n: 2, label: 'Lappen' }],
    result: { id: 'verband', n: 1 },
  },
  {
    id: 'brandflasche', name: 'Brandflasche', workbench: false, explosive: true,
    description: 'Wurfobjekt, das beim Aufprall in Flammen aufgeht und alles im Umkreis von einem Feld trifft.',
    ingredients: [
      { ids: ['flasche', 'bierkrug'], n: 1, label: 'Flasche' },
      { ids: ['lappen'], n: 1, label: 'Lappen' },
      { ids: ['hochprozentiges'], n: 1, label: 'Hochprozentiges' },
    ],
    result: { id: 'brandflasche', n: 1 },
  },
  {
    id: 'nagelbombe', name: 'Nagelbombe', workbench: true, explosive: true,
    description: 'Starker Sprengsatz zum Werfen. Trifft alles im Umkreis von einem Feld – auch dich, wenn du zu nah stehst.',
    ingredients: [
      { ids: ['dose'], n: 1, label: 'Ravioli-Dose' },
      { ids: ['naegel', 'schraubenmutter'], n: 2, label: 'Nägel oder Schraubenmuttern' },
      { ids: ['schwarzpulver'], n: 1, label: 'Schwarzpulver' },
    ],
    result: { id: 'nagelbombe', n: 2 },
  },
  {
    id: 'stachelfalle', name: 'Stachelfalle', workbench: false,
    description: 'Eigene Falle. Aufstellen, weglaufen, Monster hinterherlocken.',
    ingredients: [
      { ids: ['fallenteile'], n: 1, label: 'Fallenteile' },
      { ids: ['naegel', 'dachlatte'], n: 1, label: 'Nägel oder Dachlatte' },
    ],
    result: { id: 'stachelfalle', n: 1 },
  },
  {
    id: 'schlingfalle', name: 'Schlingfalle', workbench: false,
    description: 'Eigene Falle, die einen Gegner mehrere Züge lang am Boden festhält.',
    ingredients: [
      { ids: ['fallenteile'], n: 1, label: 'Fallenteile' },
      { ids: ['lappen', 'klebeband'], n: 2, label: 'Lappen oder Panzertape' },
    ],
    result: { id: 'schlingfalle', n: 1 },
  },
  {
    id: 'sprengfalle', name: 'Sprengfalle', workbench: true, explosive: true,
    description: 'Eigene Falle mit Sprengladung. Trifft alles im Umkreis von einem Feld.',
    ingredients: [
      { ids: ['fallenteile'], n: 1, label: 'Fallenteile' },
      { ids: ['schwarzpulver'], n: 1, label: 'Schwarzpulver' },
      { ids: ['naegel', 'schraubenmutter'], n: 1, label: 'Nägel oder Schraubenmuttern' },
    ],
    result: { id: 'sprengfalle', n: 1 },
  },
  {
    id: 'waffe_naegel', name: 'Waffe benageln', workbench: true, upgradeWeapon: true,
    description: 'Schlägt Nägel in die ausgerüstete Waffe und umwickelt alles mit Panzertape: +2 Waffenschaden. Bis zu dreimal pro Waffe.',
    ingredients: [
      { ids: ['naegel'], n: 2, label: 'Nägel' },
      { ids: ['klebeband'], n: 1, label: 'Panzertape' },
    ],
  },
];

export const RECIPE_BY_ID: Record<string, Recipe> = Object.fromEntries(RECIPES.map((r) => [r.id, r]));
