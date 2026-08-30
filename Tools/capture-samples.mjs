#!/usr/bin/env node
//
// Öffnet einen echten Browser auf DEINEM Rechner, wartet, bis du dich von Hand
// am Schulportal angemeldet hast, klappert dann die relevanten Seiten ab und
// legt von jeder einen maskierten Struktur-Dump ab.
//
// Das Passwort tippst du ins echte Login-Formular. Es steht nirgends im Skript,
// wird nicht abgefragt, nicht gespeichert und nicht verschickt.
//
//   npm install playwright && npx playwright install chromium
//   node Tools/capture-samples.mjs --school 5182
//
// Optionen:
//   --school <nr>   Schulnummer, wählt die Schule auf der Loginseite vor
//   --out <pfad>    Zielordner (Standard: samples/)
//   --profile <p>   Browserprofil, damit die Sitzung zwischen Läufen hält
//   --headless      ohne Fenster (nur sinnvoll mit bestehender Sitzung)
//   --base <url>    anderer Ausgangspunkt (für Tests gegen eine lokale Kopie)
//   --skip-login    nicht auf die Anmeldung warten (für Tests)

import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, '..');

const PAGES = [
  'meinunterricht.php',
  'stundenplan.php',
  'vertretungsplan.php',
  'kalender.php',
  'nachrichten.php',
  'startseite.php'
];

// Sieht nach Schlüssel/Token aus: lange zusammenhängende Hex- oder Base64-Ketten.
const SECRET_SHAPES = [/\b[0-9a-f]{24,}\b/i, /\b[A-Za-z0-9+/]{40,}={0,2}\b/];

function parseArgs(argv) {
  const args = { out: 'samples', profile: '.schulportal-profile', headless: false, skipLogin: false };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--school') args.school = argv[++i];
    else if (flag === '--out') args.out = argv[++i];
    else if (flag === '--profile') args.profile = argv[++i];
    else if (flag === '--base') args.base = argv[++i];
    else if (flag === '--headless') args.headless = true;
    else if (flag === '--skip-login') args.skipLogin = true;
    else if (flag === '--help' || flag === '-h') args.help = true;
    else throw new Error(`Unbekannte Option: ${flag}`);
  }
  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(await fs.readFile(fileURLToPath(import.meta.url), 'utf8')
      .then((t) => t.split('\n').filter((l) => l.startsWith('//')).join('\n')));
    return;
  }

  const base = args.base ?? 'https://start.schulportal.hessen.de/';
  const outDir = path.resolve(REPO, args.out);
  await fs.mkdir(outDir, { recursive: true });

  // Dieselbe Maskierung wie der Safari-Userscript — eine Quelle, keine Kopie.
  const dumper = await fs.readFile(path.join(HERE, 'dump-structure.user.js'), 'utf8');

  const context = await chromium.launchPersistentContext(path.resolve(REPO, args.profile), {
    headless: args.headless,
    viewport: { width: 1280, height: 900 }
  });
  const page = context.pages()[0] ?? await context.newPage();

  if (!args.skipLogin) {
    const loginURL = args.school
      ? `https://login.schulportal.hessen.de/?i=${encodeURIComponent(args.school)}`
      : 'https://login.schulportal.hessen.de/';
    await page.goto(loginURL, { waitUntil: 'domcontentloaded' });

    console.log('\n  Melde dich im geöffneten Fenster an (inkl. zweitem Faktor, falls nötig).');
    console.log('  Sobald das Portal geladen ist, geht es hier von allein weiter.\n');
    await page.waitForURL(/start\.schulportal\.hessen\.de/, { timeout: 15 * 60 * 1000 });
    console.log('  Angemeldet. Sammle Seiten …\n');
  }

  const written = [];
  const warnings = [];

  for (const name of PAGES) {
    const url = new URL(name, base).toString();
    try {
      const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      if (response && !response.ok()) throw new Error(`HTTP ${response.status()}`);
      if (/login\.schulportal\.hessen\.de/.test(page.url())) {
        throw new Error('Sitzung abgelaufen — bitte neu anmelden');
      }
      await page.waitForTimeout(1200);          // dem Portal Zeit fürs Nachladen geben

      await page.evaluate(dumper);
      const dump = await page.evaluate(() => window.__schulportalDump?.() ?? null);
      if (!dump) throw new Error('Dump-Funktion nicht verfügbar');
      // Eine Fehler- oder Platzhalterseite ist als Vorlage wertlos — lieber
      // gar keine Datei als eine leere, die später Zeit kostet.
      if (!/<(table|div|form)\b/.test(dump)) throw new Error('Seite ohne verwertbaren Inhalt');

      const hits = SECRET_SHAPES.filter((shape) => shape.test(dump));
      if (hits.length) warnings.push(name);

      const file = path.join(outDir, `${name.replace('.php', '')}-struktur.html`);
      await fs.writeFile(file, dump, 'utf8');
      written.push([path.relative(REPO, file), Buffer.byteLength(dump)]);
      console.log(`  ✓ ${name.padEnd(22)} ${(Buffer.byteLength(dump) / 1024).toFixed(0)} kB`);
    } catch (error) {
      console.log(`  – ${name.padEnd(22)} übersprungen (${error.message.split('\n')[0]})`);
    }
  }

  await context.close();

  console.log(`\n  ${written.length} Datei(en) in ${path.relative(REPO, outDir)}/`);
  if (warnings.length) {
    console.log('\n  ACHTUNG: lange Zeichenketten gefunden, die wie ein Token aussehen, in:');
    for (const name of warnings) console.log(`    - ${name}`);
    console.log('  Bitte vor dem Weitergeben nachsehen und ggf. löschen.');
  }
  console.log('\n  Texte sind maskiert. Trotzdem einmal überfliegen, bevor du sie teilst.\n');
}

main().catch((error) => {
  console.error(`\n  Fehlgeschlagen: ${error.message}\n`);
  process.exit(1);
});
