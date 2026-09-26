// Fügt den Vite-Build zu einer einzigen HTML-Datei zusammen (für den Web-Link).
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';

const assets = readdirSync('dist/assets');
const css = readFileSync(`dist/assets/${assets.find((f) => f.endsWith('.css'))}`, 'utf8');
const js = readFileSync(`dist/assets/${assets.find((f) => f.endsWith('.js'))}`, 'utf8');
if (js.includes('</script')) throw new Error('Bundle enthält </script – kann nicht inline eingebettet werden.');

const html = `<title>Der Große Abstieg</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Montserrat:ital,wght@0,400;0,500;0,700;0,800;1,400&display=swap">
<style>${css}</style>
<div id="app"></div>
<div id="toasts"></div>
<div id="modal-root"></div>
<script type="module">${js}</script>
`;
mkdirSync('dist-artifact', { recursive: true });
writeFileSync('dist-artifact/der-grosse-abstieg.html', html);
console.log(`dist-artifact/der-grosse-abstieg.html (${Math.round(html.length / 1024)} KB)`);
