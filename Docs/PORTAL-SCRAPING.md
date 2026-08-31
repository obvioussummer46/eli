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
npm install && npx playwright install chromium
npm run capture -- --school <Schulnummer>
```

(Identical on macOS and Linux. `samples/README.md` has the step-by-step version
for someone who has not used a terminal before, plus the no-terminal route via
the Safari userscript button.)

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
| `.homework .done` | always-present `erledigt` label; `hidden` while open | portal done-state |
| `.homework .undone` | the "als erledigt markieren" button | portal done-state |
| `a[href*=sus_download]` | attachments | detail sheet |
| `.teacher .btn` | teacher shorthand | course metadata |

These are exactly the selectors the Safari userscript already targets, so if the
userscript still works, the parser should too — and vice versa.

**Done-state detection** has to read *two* renderings of the same flag,
depending on whose account is looking.

The **pupil view** is a *class* test, not a text test. The portal ships both
labels on every entry and switches between them with `hidden`:

```html
<span class="done label label-default hidden">erledigt</span>
<span class="undone"><span class="label label-warning change">als "erledigt" markieren</span></span>
```

So `.done` is present and reads `erledigt` whether or not the homework is done —
it carries `hidden` while the entry is still open. `.undone` is the visible one.
Verified against a live page: all six open entries render exactly this way.
Match the class as a whole token — the portal also uses `hidden-print`, which a
substring test would wrongly read as `hidden`. No pupil label ever reads
`offen`, and `label-success` sits on the *"Hausaufgabe"* title span rather than
on the state.

The **parent view** (Eltern-Konten see their child's Kurshefte read-only) has
no `.undone` button at all, and `.done` is an always-visible status label whose
*text* is the state — verified live:

```html
<span class="done label label-warning">offen</span>
```

Read the two together as: `.done` with `hidden` → open; `.done` whose text
contains `offen` → open; any other visible `.done` → done; no `.done` at all →
fall back to a hidden `.undone`. Applying the pupil rule alone to a parent page
ticks off every homework in the house.

### Pushing a tick back

```
POST https://start.schulportal.hessen.de/meinunterricht.php
Content-Type: application/x-www-form-urlencoded
X-Requested-With: XMLHttpRequest

a=sus_homeworkDone&id=<data-book>&entry=<data-entry>
```

These three fields are the whole payload — taken from the portal's own
`module/meinunterricht/js/sus_start.js`, which posts
`{a: 'sus_homeworkDone', id: book, entry: entry}`. There is no `b` parameter.

**The route is one-way.** That script binds the POST to the "als erledigt
markieren" button and offers nothing to undo it, so un-ticking cannot reach the
portal at all. `PortalService.setHomeworkDone` returns `.localOnly` for that case
instead of throwing, so the entry does not sit in the retry queue forever.

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

> Neither `#own` nor `#all` existed on the one live plan checked (a `?a=detail_klasse`
> view reached by a server-side redirect from bare `stundenplan.php`) — the third
> fallback is what actually carried it. Treat the ids as optional, not as the
> primary hook.
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

## `menuebestellung.de` → `SpeiseplanParser`

A different site entirely — the school's caterer — behind the **Essen** tab. It
is half modern and half legacy, and the split matters: the login and the account
pages are a Next.js front end over a JSON API, while the menu itself is still a
server-rendered PHP page.

**Login** — `POST /asb-heserv/login_api.php?loginWithUsernameAndPassword`,
body `{"username":…,"password":…}`, answer
`{"success":bool,"secondFactorRequired":bool,"redirectUrl":"","errors":[…]}`.
`errors[0]` is shown verbatim, because the site words it better than we could. A
lost session shows up as a redirect to `/asb-heserv/login?next=…`, or as an HTML
error page under a `200` where JSON was promised — both mean "sign in again",
which `MensaClient` does by itself.

Both account calls go out with `X-Requested-With: XMLHttpRequest`, a `Referer`
under `/asb-heserv/` and (on `POST`) an `Origin`. Without them the endpoints
answer with the site's HTML page under a `200`, which the client can only read
as a dead session.

**Balance** — `GET /asb-heserv/berichte_api.php?getPageData` →
`{"balance":"31.85","totalBalance":"31.85","lowBalanceThreshold":{"minimumBalance":"15.00"}}`.
Every money field is a **string**; keep it that way until `Decimal`, never
through a `Double`.

**Statement** — `POST /asb-heserv/berichte_api.php?searchTransactions` with
`{"type":"","direction":"","dateFrom":"YYYY-MM-DD","dateTo":…,"valutaFrom":"","valutaTo":"","orderBy":{"column":"t.id","orderType":"DESC"},"page":1,"pageSize":100}`.
Empty `type`/`direction` is the site's own "Alle" preset. Entries whose `value`
is `"0.00"` are pick-up confirmations, not money moving.

The answers to those two are **not** decoded strictly, and that is deliberate —
`Parsing/MensaJSON.swift` walks them as plain values and reads each field by
meaning:

* Money and ids arrive as a string on one route and a number on the next; a
  timestamp comes as ISO 8601, as `2026-08-28 12:30:00`, as `28.08.2026`, as a
  Unix number or as PHP's `{"date":…,"timezone_type":3}` object. A strict
  `Codable` model throws on the first surprise and loses the whole list.
* The record list has been seen under `data`, but the finder also accepts
  `transactions`/`entries`/`rows`/… and a bare array, and only accepts an array
  when its objects actually look like bookings. A defaulted `data: [Entry] = []`
  turns "the wrapper key moved" into a confident "no bookings", which is the bug
  this replaced.
* **An empty statement and an unreadable one must never look alike.** Zero rows
  is printed as „Keine Buchungen“ *only* when the answer contained a record list
  at all; otherwise the tab reports that the statement could not be read.

**The date range is the trap.** The endpoint is German-facing PHP and answers a
range it cannot parse with "nothing found" rather than an error. So an empty
answer is retried with `dd.MM.yyyy` and then with the fields left empty (the
site's "Alle" preset) before it is believed. Only the first request happens when
things work.

**The plan** — `GET /asb-heserv/speiseplan.php?week=YYYY_WW`. This one page
carries the week's dishes, what is ordered *and* the balance, so the tab fills
from a single request:

| Selector | Meaning | Used for |
|---|---|---|
| `span.username` | who is logged in | the balance card |
| `#guthaben` | the balance, `31,85` | the balance card |
| `select[name=week] option` | every offered week, `value="2026_36"` | the week pager |
| `option[selected]` | the week on screen | the heading |
| `div.tab-pane.day` | one school day | the day loop |
| `@id` | `day-MO` | the day key |
| `@name` | `2026-08-31` | the date |
| `input.hiddenmenuefield` `@value` | the ordered menu id, `""` if none | "Bestellt" |
| `div.panel.menue` | one dish | the cards |
| `@rel` | menu id | matching against the hidden field |
| `.panel-title` | dish name | the card |
| `.badge` | price, `3,00 €` | the card |
| `.panel-body p` | description | the card |
| `.panel-body p small` | allergen codes, `1, GL, LA` | the card |
| `@data-content` | the same codes spelled out | accessibility, long-press |
| `.disabled` | past the ordering deadline | the greyed-out state |
| `.colorflag-dge` | DGE quality seal | the badge |

Two traps:

* **The hidden field, not the `active` class, is what is ordered.** `active`
  also comes and goes with the site's own client-side selection handling; the
  hidden field is what the form would actually submit.
* **`<br>` is the only real line break.** The caterer writes
  `Gericht<br>\nBeilage<br>\n<br>\nDessert`, so `HTMLText.multiline` — which
  honours source newlines too, correctly, for the portal — doubles every break
  and destroys the difference between a new line and a blank one.
  `SpeiseplanParser.brSeparatedLines` ignores source whitespace and lets the
  tags decide.

**Ordering is deliberately not implemented.** It would be a `POST` to the same
`speiseplan.php?week=…` with `csrftoken` (also readable from the
`csrftoken_asb_heserv` cookie), `submit_bestellung=submit` and one
`menue_<DAY>_0=<menuId>` per day. It spends real money, so the app reads and
leaves the choosing to the website.

## The school directory → `SchoolDirectory`

The one route here that needs no session, and the only one that is real JSON
rather than scraped HTML:

```
GET https://startcache.schulportal.hessen.de/exporteur.php?a=schoollist
```

```json
[{"Id": "7", "Name": "Bergstraße/Odenwaldkreis",
  "Schulen": [{"Id": "3354", "Name": "Adam-Karrillon-Schule", "Ort": "Wald-Michelbach"}]}]
```

One array of *Schulämter*, each with its schools; ~2000 entries, ~140 KB, 17
districts. `Id` is exactly the number `login.schulportal.hessen.de/?i=…` wants,
which is the only reason the app reads this at all — so nobody has to find it in
a URL.

Load-bearing: the top-level array, `Schulen`, and `Id`/`Name`/`Ort` on a school.
`Ort` is what tells the eighteen „Albert-Schweitzer-Schule“ apart, so it is
shown alongside every result. Ids arrive as strings here and as numbers elsewhere in
the portal, so both are accepted.

Two things worth knowing when this breaks:

* **A wrong route name fails as bad JSON, not as a 404.** `?a=schoolonline` — an
  older spelling that the app shipped with at first — now `302`s to a generic
  HTML page under a `200`. Check the final URL before suspecting the parser.
* It runs **before** anyone is signed in, so it must not go through `SPHClient`:
  that client reports a redirect to the login host as `.notLoggedIn`, which is
  the very state the user is trying to leave. `SchoolDirectory` has its own
  ephemeral session and never touches `HTTPCookieStorage.shared`.

The whole thing is optional. Without a school the portal simply shows its own
picker, and the app is no worse off than before.

## `vertretungsplan.php`

Two shapes, because the portal has two. The page itself is a shell: day
buttons carrying `data-tag="dd.MM.yyyy"`. Each of those days is fetched the
way the page's own script does it — `POST vertretungsplan.php?a=my` with form
fields `tag=<dd.MM.yyyy>` and `ganzerPlan=true` — and answered with a JSON
array of rows keyed `Stunde`, `Art`, `Klasse`, `Fach`, `Fach_alt`, `Lehrer`,
`Vertreter`, `Raum`, `Raum_alt`, `Hinweis` (a bare `-1` means "nothing that
day"). This JSON, not any HTML, is the load-bearing contract; the approach and
the key list follow the lanis-mobile project, which runs it statewide.

Schools that disable "Zugriff auf den gesamten Plan" render classic
server-side tables instead: `#tagDD_MM_YYYY` panels, a `table[id^=vtable]`
inside, and every header cell naming its column in `data-field` — which is
what keeps that fallback layout-independent. Load-bearing there: the panel id
pattern, `data-field` (with `Stunde` present), and `td[colspan]` marking the
"keine Einträge" placeholder row.

Failures are deliberately quiet: schools that publish no plan are normal, so
`AppModel` treats an error as "no data" rather than as a banner.

Day-level *Hinweise* live only in the shell, whichever way the rows arrive:
a `table.infos` per day panel, header rows carrying class `header`, the
announcement lines as plain rows beneath.

## `kalender.php`

`POST kalender.php?f=getEvents` (form fields `f`, `start`, `end` as
`yyyy-MM-dd`, empty `s`) answers with a plain JSON array of events — keys
`Id`, `title`, `description`, `Ort`, `category`, `allDay`, and the dates
twice: German `Anfang`/`Ende` (`yyyy-MM-dd HH:mm:ss`) and FullCalendar ISO
`start`/`end`. Only the category list (name + colour per id) has to be fished
out of the page HTML, where the page's own script pushes them as loose JS:
`categories.push({id: 1, name: '…', color: '#…'})`. Load-bearing: the array
shape, `Anfang`/`start`, `title` — a row missing those is dropped alone.

## Not parsed natively

*Nachrichten* is encrypted client-side by the portal and opens in the
built-in portal browser with the userscript applied. `PortalService` is the
right place to add anything further — one method, one parser, no other layer
changes.
