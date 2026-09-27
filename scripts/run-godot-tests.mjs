// Startet die Godot-Tests und wertet auch Laufzeitfehler als Fehlschlag:
// GDScript bricht bei SCRIPT ERROR nicht ab, sondern macht weiter.
import { spawn } from 'node:child_process';

const godot = process.env.GODOT || 'godot';
const args = ['--headless', '--path', 'godot', '-s', 'res://tests/run_tests.gd', ...process.argv.slice(2).flatMap((a) => ['--', a])];
const child = spawn(godot, args, { stdio: ['ignore', 'pipe', 'pipe'] });
let errors = 0;
const watch = (stream, out) => {
  let buf = '';
  stream.on('data', (d) => {
    out.write(d);
    buf += d.toString();
    const lines = buf.split('\n');
    buf = lines.pop();
    for (const l of lines) if (l.includes('SCRIPT ERROR')) errors += 1;
  });
};
watch(child.stdout, process.stdout);
watch(child.stderr, process.stderr);
child.on('close', (code) => {
  if (errors) console.error(`\n${errors} Laufzeitfehler (SCRIPT ERROR) im Godot-Test.`);
  process.exit(code || (errors ? 1 : 0));
});
