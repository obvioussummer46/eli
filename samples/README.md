# Struktur-Dumps

Maskierte HTML-Gerüste echter Portalseiten. Daran werden die Parser der App
angepasst. Was drinsteht und was nicht: `Docs/PORTAL-SCRAPING.md`, Abschnitt
„Capturing a sample safely“. Kurz: Struktur ja, Texte maskiert,
Namen/Noten/Nachrichten/Session nein.

Es gibt zwei Wege. Der erste braucht kein Terminal.

## 1. Safari-Userscript (am einfachsten)

1. `Tools/dump-structure.user.js` öffnen, auf **Raw** klicken, alles kopieren.
2. Im Userscript-Manager als neues Skript einfügen (wie beim Mobile-Skript,
   der `@match` fürs Portal steht schon drin).
3. Angemeldet `meinunterricht.php` öffnen.
4. Unten rechts auf den blauen Knopf **⬇︎ Struktur** tippen — die Datei wird
   gesichert und liegt zusätzlich in der Zwischenablage.
5. Für `stundenplan.php` wiederholen.

Funktioniert auf dem Mac genauso wie auf dem iPhone.

## 2. Alle Seiten auf einmal (Terminal, macOS)

Die Befehle sind auf macOS und Linux identisch. Terminal öffnen mit
⌘ + Leertaste → „Terminal“, dann Zeile für Zeile:

```sh
node -v                     # zeigt z. B. v22.x — wenn "command not found":
                            # nodejs.org öffnen, LTS-Installer laden, dann neu starten

cd ~/Desktop                # oder wohin du magst
git clone https://github.com/obvioussummer46/eli.git
cd eli
git checkout claude/schulportal-hessen-ios-ro0hzn

npm install                 # holt Playwright
npx playwright install chromium

npm run capture -- --school 5182     # deine Schulnummer eintragen
```

Ein Browserfenster geht auf. **Du** meldest dich dort von Hand an, auch mit
zweitem Faktor. Danach klappert das Skript die Seiten ab und legt die Dumps
hier in `samples/` ab.

Das Passwort tippst du ins echte Login-Formular. Es wird nirgends abgefragt,
gespeichert oder verschickt — im Skript steht kein einziger Zugangsdaten-Handler.

Beim nächsten Mal reicht `npm run capture`, die Sitzung bleibt im Profil
`.schulportal-profile/` liegen.

### Wenn etwas klemmt

| Meldung | Grund |
|---|---|
| `command not found: node` | Node fehlt → nodejs.org, LTS-Installer |
| `command not found: git` | Xcode-Kommandozeilentools: `xcode-select --install` |
| `HTTP 404` / `übersprungen` | Die Seite gibt es an deiner Schule nicht — unkritisch |
| `Sitzung abgelaufen` | Neu anmelden, Skript nochmal starten |

## Vor dem Weitergeben

Einmal überfliegen. Die Maskierung ist eine gute Voreinstellung, keine Garantie.
