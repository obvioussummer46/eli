# What we scrape, and how to fix it when it breaks

The portal is not an API. This file lists every piece of HTML the app depends
on, so that a break is a five-minute fix rather than an investigation.

## Capturing a sample safely

Never hand anyone portal credentials to "have a look" — not a developer, not an
assistant. What a parser fix needs is the *markup*, not access, and the two are
easy to separate.

`Tools/dump-structure.user.js` does the separating. Install it alongside the
restyle userscript, open the page you want (Mein Unterricht, Stundenplan, …) and
tap the blue **⬇︎ Struktur** button; the result is copied to the clipboard and
saved as `<seite>-struktur.html`.

| | |
|---|---|
| **Kept** | tags, nesting, `class`, `id`, `data-*`, `style`, `rowspan`/`colspan`, numbers, dates, times, `offen`/`erledigt`, portal action names (`a=sus_homeworkDone`) |
| **Masked** | every other text — letters become `x`/`X`, length and punctuation survive, so `Vokabeln lernen` becomes `Xxxxxxxx xxxxxx` |
| **Removed** | `<script>`, `<style>`, `title`/`alt`/`value`/`placeholder`/`aria-*`, `on*` handlers, attachment filenames, and `sid`/`token`/`auth` in every URL |

That is enough to fix any selector in this document and reveals no names, marks,
messages or session. It doubles as a test fixture. Read it over once before
sending it anywhere — automated redaction is a good default, not a guarantee.

### All pages at once

`Tools/capture-samples.mjs` does the same thing for every page in one go, on
your own machine:

```sh
npm install playwright && npx playwright install chromium
node Tools/capture-samples.mjs --school <Schulnummer>
```

A real browser window opens on the portal's login page. **You** sign in there by
hand — the script never asks for, stores or transmits a password, and there is
no credential handling in it to audit. Once the portal loads it walks
`meinunterricht.php`, `stundenplan.php`, `vertretungsplan.php`, `kalender.php`,
`nachrichten.php` and `startseite.php`, applies the masking above, and writes
`samples/<page>-struktur.html`. Pages that error, 404 or bounce to the login are
skipped rather than written out empty, and anything token-shaped that survives
masking is flagged at the end. `--profile` keeps the session between runs.

If you would rather do it by hand: Safari on a Mac → Develop → Show Page Source,
save, then delete anything personal yourself.

### Why not just hand over a login

Because it buys nothing. A password grants *access*; fixing a selector needs
*markup*, and the dumps above carry all of the markup and none of the access.
Credentials pasted into a chat also persist in its transcript, and a portal
account is a real pupil's record — grades, messages, absences — not a test
fixture. There is no parser problem in this repository that a login solves and a
masked dump does not.

## `meinunterricht.php` → `MeinUnterrichtParser`

Each lesson entry is a table row carrying the portal's own ids:

| Selector | Meaning | Used for |
|---|---|---|
| `tr[data-book]` | one lesson entry | the row loop |
| `@data-book` | course/"Kursmappe" id | `sus_homeworkDone` `id` |
| `@data-entry` | entry id | `sus_homeworkDone` `entry`, stable homework id |
| `.name` (or `h3 a`) | course title, e.g. `M 07c GYM` | subject resolution |
| `a[href*=sus_view]` → `?id=` | course id | grouping |
| `b.thema` | lesson topic | detail sheet |
| `span.datum` | date of the lesson | sorting, "aufgegeben am" |
| `.inhalt` | collapsed lesson content | detail sheet |
| `.homework` | homework container | — |
| `.homework .realHomework` | the actual assignment text | the list |
| `.homework .done` | label reading `offen` / `erledigt` | portal done-state |
| `a[href*=sus_download]` | attachments | detail sheet |
| `.teacher .btn` | teacher shorthand | course metadata |

These are exactly the selectors the Safari userscript already targets, so if the
userscript still works, the parser should too — and vice versa.

**Done-state detection** reads the label text first (`erledigt` → done, `offen`
→ open) and only falls back to the CSS class (`label-success` → done). Text is
more stable than Bootstrap classes here.

### Pushing a tick back

```
POST https://start.schulportal.hessen.de/meinunterricht.php
Content-Type: application/x-www-form-urlencoded
X-Requested-With: XMLHttpRequest

a=sus_homeworkDone&entry=<data-entry>&id=<data-book>&b=done      # or b=undone
```

The portal answers `1` on success. This is reconstructed from the page's own
behaviour rather than documented, so it is treated as best-effort: a failure
never blocks the UI, it only leaves the item flagged as "not yet synced"
(`AppModel.isPendingSync`) and it is retried on the next refresh. If your school
returns something else, capture the real request in Safari's network inspector
and adjust `PortalService.setHomeworkDone`.

## `stundenplan.php` → `StundenplanParser`

The plan is a table: one row per period, one column per weekday, double lessons
expressed with `rowspan`.

| Selector | Meaning |
|---|---|
| `table#own`, `table#all`, or the first table containing `.stunde` | the plan |
| header `th` text | weekday, matched on the first two letters (`Mo`, `Montag`, …) |
| first cell of each row | period number and `span.VonBis` times (`07:45 - 08:30`) |
| `.stunde` inside a day cell | one lesson block (several = parallel courses) |
| `b` inside `.stunde` | course title |
| `small` inside `.stunde` | teacher |
| remaining text | room |

The grid is walked like a spreadsheet with a per-column rowspan countdown, so
merged cells land on the right day and a double lesson becomes a single entry
with `firstPeriod…lastPeriod`.

**Fallbacks:** if the header has no recognisable weekdays, Mon–Fri is assumed;
if a row carries no times, standard Hessen bell times are used
(`StundenplanParser.fallbackTimes`). Both are the places to adjust for an
unusual school layout.

## Subject codes → names and colours

`Models/Subject.swift`, a direct port of the userscript's `SUBJECTS` and
`CHIP_COLORS` tables. Unknown codes fall back to a deterministic hue derived
from the name, so an unmapped subject still gets a stable colour. Adding a
subject is one line in `Subject.names` (plus optionally `Subject.colors`).

## Not parsed natively

*Nachrichten* is encrypted client-side by the portal, and *Kalender* /
*Vertretungsplan* vary a lot between schools. All three open in the Portal tab
with the userscript applied. `PortalService` is the right place to add them
later — one method, one parser, no other layer changes.
