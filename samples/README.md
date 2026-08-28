# Struktur-Dumps

Hier liegen die maskierten HTML-Gerüste echter Portalseiten, gegen die die
Parser angepasst werden.

Erzeugen:

```sh
npm install playwright && npx playwright install chromium
node Tools/capture-samples.mjs --school <deine Schulnummer>
```

Der Browser geht auf, **du** meldest dich von Hand an, danach sammelt das Skript
die Seiten ein. Das Passwort steht in keinem Skript und wird nirgends
gespeichert.

Alternativ einzeln über den Safari-Userscript `Tools/dump-structure.user.js`
(blauer Knopf unten rechts).

Was in diesen Dateien steht und was nicht: `Docs/PORTAL-SCRAPING.md`,
Abschnitt „Capturing a sample safely“. Kurz: Struktur ja, Texte maskiert,
Namen/Noten/Nachrichten/Session nein. Trotzdem vor dem Commit einmal
überfliegen.
