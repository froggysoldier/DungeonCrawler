// Exportiert alle Inhalte aus src/data als JSON nach godot/data.
// Solange beide Versionen existieren, bleibt src/data die einzige Quelle:
// Inhalte dort ändern, dann `npm run export:godot` ausführen.
// Funktionen (z. B. Bedingungen von Achievements) lassen sich nicht als JSON
// speichern; sie werden weggelassen und im Bericht aufgeführt, damit sie in
// GDScript nachgebaut werden.
import { createServer } from 'vite';
import { mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const OUT = 'godot/data';
mkdirSync(OUT, { recursive: true });
const server = await createServer({ server: { middlewareMode: true }, appType: 'custom', logLevel: 'error' });
const report = [];
const files = readdirSync('src/data').filter((f) => f.endsWith('.ts')).sort();

/** Entfernt Funktionen und merkt sich, wo welche waren. */
function clean(value, path, dropped, seen = new WeakSet()) {
  if (typeof value === 'function') {
    dropped.add(path.replace(/\[\d+\]/g, '[]').replace(/\.[a-z0-9_]+\./gi, (m) => (/^\.[A-Z]/.test(m) ? m : '.*.')));
    return undefined;
  }
  if (value === null || typeof value !== 'object') return value;
  if (value instanceof Set) return clean([...value], path, dropped, seen);
  if (value instanceof Map) return clean(Object.fromEntries(value), path, dropped, seen);
  if (seen.has(value)) return value;
  seen.add(value);
  if (Array.isArray(value)) return value.map((v, i) => clean(v, `${path}[${i}]`, dropped, seen)).filter((v) => v !== undefined);
  const out = {};
  for (const [k, v] of Object.entries(value)) {
    const c = clean(v, `${path}.${k}`, dropped, seen);
    if (c !== undefined) out[k] = c;
  }
  return out;
}

/**
 * Vergleichswerte für die Godot-Tests: Die portierten Bausteine müssen bei
 * gleichem Seed exakt dasselbe liefern wie die TypeScript-Version.
 */
async function writeFixtures() {
  const FIX = 'godot/tests/fixtures';
  mkdirSync(FIX, { recursive: true });
  const R = await server.ssrLoadModule('/src/engine/rng.ts');
  const rng = [1, 42, 123456, -99, 2147483647].map((seed) => {
    const h = { rng: seed };
    const words = Array.from({ length: 20 }, () => Math.round(R.next(h) * 4294967296));
    const ints = Array.from({ length: 20 }, () => R.int(h, -5, 17));
    const shuffled = R.shuffle(h, Array.from({ length: 10 }, (_, i) => i));
    const weighted = Array.from({ length: 10 }, () => R.weighted(h, [['a', 1], ['b', 3], ['c', 6]]));
    return { seed, words, ints, shuffled, weighted, state: h.rng };
  });
  writeFileSync(join(FIX, 'rng.json'), JSON.stringify(rng) + '\n');

  const G = await server.ssrLoadModule('/src/engine/game.ts');
  const M = await server.ssrLoadModule('/src/engine/meta.ts');
  const F = await server.ssrLoadModule('/src/engine/fov.ts');
  const P = await server.ssrLoadModule('/src/engine/path.ts');
  const maps = [7, 8].map((seed) => {
    const s = G.newGame({ name: 'Test', answers: { beruf: 1 }, seed, meta: M.emptyMeta() });
    const m = s.map;
    const from = s.player.pos;
    const fov = [...F.computeFov(m, from, 7)].sort((a, b) => a - b);
    const stairs = m.tiles.indexOf('stairs');
    const to = { x: stairs % m.width, y: Math.floor(stairs / m.width) };
    const path = P.findPath(m, from, to, () => true, 20000, true);
    return { seed, width: m.width, height: m.height, tiles: m.tiles, from, fov, to, path };
  });
  writeFileSync(join(FIX, 'maps.json'), JSON.stringify(maps) + '\n');
  const RP = await server.ssrLoadModule('/scripts/godot-replay.ts');
  const reps = RP.replays();
  writeFileSync(join(FIX, 'replays.json'), JSON.stringify(reps) + '\n');
  console.log(`Replays: ${reps.map((r) => `Seed ${r.seed}: ${r.actions.length} Aktionen`).join(', ')}`);
}

try {
  for (const f of files) {
    const mod = await server.ssrLoadModule(`/src/data/${f}`);
    const name = f.replace(/\.ts$/, '');
    const dropped = new Set();
    const data = {};
    for (const [k, v] of Object.entries(mod)) {
      // Nachschlage-Tabellen (…_BY_ID) baut Godot beim Laden selbst auf
      if (/_BY_ID$/.test(k)) continue;
      // Funktionen, die eine Tabelle für den Export liefern (z. B. familyTable)
      if (typeof v === 'function' && /Table$/.test(k) && v.length === 0) {
        data[k] = clean(v(), k, dropped);
        continue;
      }
      const c = clean(v, k, dropped);
      if (c !== undefined) data[k] = c;
      else dropped.add(k);
    }
    writeFileSync(join(OUT, `${name}.json`), JSON.stringify(data, null, 1) + '\n');
    report.push(`## ${name}\nExporte: ${Object.keys(data).join(', ') || '–'}\n${dropped.size ? `Nicht exportierbar (Funktionen, in GDScript nachbauen):\n${[...dropped].sort().map((d) => `- ${d}`).join('\n')}\n` : ''}`);
  }
  writeFileSync(join(OUT, 'EXPORT_REPORT.md'), `# Datenexport für Godot\n\nErzeugt von \`npm run export:godot\`. Nicht von Hand bearbeiten.\n\n${report.join('\n')}`);
  console.log(`${files.length} Dateien nach ${OUT} exportiert.`);
  await writeFixtures();
} finally {
  await server.close();
}
