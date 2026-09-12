// Copies the deployable site into www/ for Capacitor (tests, tools and native code are left out).
import { cpSync, rmSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'www');
if (existsSync(out)) rmSync(out, { recursive: true });
mkdirSync(out);
for (const f of ['index.html', 'widget.html', 'manifest.webmanifest', 'sw.js', 'css', 'js', 'icons']) {
  cpSync(join(root, f), join(out, f), { recursive: true });
}
console.log('www/ ready');
