# Plan — everything discussed on 31.08.2026 and not yet built

One document, for review before the next session. Adjust freely; nothing
below is started. Context lines reference what was verified live that day
(portal recon, school-website recon, the simulator sessions) — re-verify
anything that smells stale before building on it.

**Already shipped that day, for orientation:** native login (both account
dialects, session self-heal, stored credentials), Kontoauszug CSRF fix,
Vertretungsplan + Kalender parsing, deadlines/badge/sorting, notifications
(17:00 reminder, 18:00 digest, low balance), three widgets + App Group
snapshot, background refresh, parent-account support, quote launch screen,
Termine → calendar sync, course-scoped homework ids.

---

## Wave 1 — "one app, every school": registry, links, mensa

The architectural decision behind this wave (settled): **one
Hessen-generic app, no Eli fork.** Everything school-specific becomes
*data, not code* — a small bundled JSON registry keyed by Schulnummer,
with Elisabethenschule (5102) as the first fully configured school and a
"configure your own" path for everyone else. Another school = a one-entry
PR, not a fork.

Two product rules, decided 01.09.2026, that govern this wave and every
feature after it:

1. **Hidden, not broken.** A feature ships only if a school with zero
   configuration sees *nothing* — no tab, no card, no placeholder, no
   error. Unconfigured features don't exist; the app never *tries*
   anything the registry doesn't vouch for. (The mensa toggle in 1.2 is
   the reference implementation.)
2. **Parse standards, never websites.** The app may parse standardized
   formats (RSS/Atom); it never scrapes individual school websites with
   hand-written selectors — not even Eli's. A school without a feed gets
   a link to its site instead. This is the permanent defense against the
   per-CMS parser treadmill, where one school redesign silently breaks
   the app.

Build order: **1.1 registry → 1.2 quick links → 1.3 mensa optional.**
News-as-a-parsed-feed was demoted out of Wave 1 (see "Deferred" below).

**Wave 1 shipped 01.09.2026** (all three items below, plus lesson end
times in the Heute-widget rows). Also shipped same day, from review:
the Heute tab and both lesson widgets roll over to the **next school
day once today's last lesson has ended** (weekend → Monday), with the
labels travelling along („Morgen · …", „Am Montag als Erstes") —
deliberately *not* a fixed 18:00 flip, so tab and widgets flip on one
shared rule. Still worth doing when convenient:
Eli's Jahresterminplan link — left out of the registry because the plan
never recorded its URL and a guessed link would be a dead one; verify
the real address on the site, then add the entry to `schools.json`.

### 1.1 Per-school configuration registry  *(foundation — build first)*

- [x] `Resources/schools.json`: `{ "5102": { mensaTenant, newsSource, links } }`
- [x] `SchoolConfig` loader: registry entry for `settings.schoolID`,
      falling back to user-entered values, falling back to nothing.
- [x] Settings UI: show what the registry provided; allow overrides.
- Effort: small. No network, no parsing — plumbing and one JSON file.

### 1.2 „Meine Schule" quick links  *(the v1 answer to school news)*

- [x] Configurable link list in Mehr — Eli's registry entry ships
      Elternbeirat (`schulelternbeirat.html`), Förderverein
      (`foerderverein.html`), Termine (`termine.html`),
      **and „Neues von der Schule" (`eli-news.html`)**; users can add
      their own (Hort, Schulwohnung …). (Jahresterminplan: URL still to
      verify, see above.)
- [x] Opens in an in-app browser (`SFSafariViewController` — school
      sites are not the portal and get no restyle injected).
- Why this replaces the news parser: school sites post 1–3×/month; news
  is a nice-to-have, not a retention feature. A link delivers ~90 % of
  the value for ~5 % of the work and zero maintenance risk.
- Effort: small.

### 1.3 Mensa optional + tenant from registry

- [x] `MensaEndpoints.tenant` comes from the registry (Eli:
      `asb-heserv`), user-overridable for other menuebestellung.de
      schools; the old hard-coded value stays as last fallback for
      pre-registry installs.
- [x] "Essen-Tab anzeigen" toggle (default: on when a tenant is known,
      off otherwise) — a school without a caterer must not have a
      permanently dead tab that makes the app feel broken.
- [x] Widgets + digest degrade cleanly when mensa is off (balance/dish
      fields cleared from the shared snapshot; scene-active and
      background refreshes gated on the toggle too).
- Effort: small-medium. Watch: `MensaEndpoints` is currently `enum` with
  statics — becomes config-driven.

### Deferred: Schul-News as a parsed feed  *(RSS-only, if ever)*

Demoted from Wave 1 on 01.09.2026. The original spec included a Contao
selector-scraper for Eli's site — that violates rule 2 above (one school
website redesign silently breaks the news card) and was the single
highest-maintenance item in the wave, for a feature school sites update
1–3×/month and few parents actively read.

If a news card on Heute ever earns its way back:

- **RSS/Atom autodiscovery only** (covers WordPress school sites for
  free via `/feed`). No per-CMS scraping under any circumstances.
- Schools without a feed — including Eli (Contao, no RSS) — get the
  quick link from 1.2 instead. That is not a degraded experience; it is
  the product decision.
- Own ephemeral fetch like `SchoolDirectory`, never through `SPHClient`;
  feed URL from the registry, manual entry for unlisted schools.
- Revisit only after Wave 1 ships and there's a real signal people want
  news *in* the app rather than one tap away.

---

## Wave 2 — daily-life features

Focus decided 01.09.2026: **widgets (2.1) and Unterstützer (2.4)**, with
the Sunday mensa warning (2.2) alongside. Manual homework is *pending* —
Dima is unconvinced; the PM case is recorded under 2.3 and awaits his
verdict, so don't build it without one.

### 2.1 Widget deep links — SHIPPED 01.09.2026

- [x] `schulportalmobile://tab/<name>` via `widgetURL` + tab selection in
      `RootView`: Heute-widget → Aufgaben, Mensa-widget → Essen,
      Nächste-Stunde-widget → Plan. The scheme is deliberately *not*
      registered in the Info.plist — WidgetKit hands `widgetURL` straight
      to the containing app, and nothing external should steer tabs.
      A link to the hidden Essen tab is ignored. **Verify on a real
      device**: widget taps can't be exercised in a fresh simulator.

### 2.2 Mensa „nichts bestellt" warning — SHIPPED 01.09.2026

- [x] Sunday 17:00, about the coming week's published-but-unordered
      days; a refresh landing Sunday 17:00–20:30 warns shortly after
      instead of skipping a week. Off by default; the toggle lives with
      the other Mitteilungen and hides with the Essen tab.
- [x] Fri–Sun the mensa refresh also fetches the *next* week
      (harvested for the snapshot only, never shown) — which also feeds
      Monday's dish into the Sunday digest, silently missing before.
- Why: prevents the real failure mode — a hungry kid.
- The per-day lock *time* on `speiseplan.php` remains unverified; the
  Sunday cadence was chosen so it doesn't matter for this warning.

### 2.3 Own tasks (manual homework) — PAUSED (Dima, 01.09.2026)

Dima is not convinced this earns its place. The PM case, for the
record: the Aufgaben list is only trustworthy if it is *complete*, and
teachers put maybe 80 % of obligations into SPH — the "2 € für den
Ausflug", "Sportbeutel!" items live in the parent group chat and on
paper slips. A list that is almost complete still forces a second
system (memory, Post-its), and the app's core promise — "tick this list
and you're done" — quietly breaks. Counter-argument (Dima's bloat
concern): Reminders/Notes already exist for this. The differentiator is
*one* list with the same deadline logic, badge, widget and digest —
a task in Reminders doesn't show up in the 17:00 reminder.

- [ ] If approved: plus button on Aufgaben, subject picker, text,
      optional deadline; stored in `Snapshot` beside `doneOverrides`;
      same tick-off/widget/digest path. **Never** pushed to the portal.
- Effort: medium.

### 2.4 Unterstützer (the chosen monetisation — decided, awaiting go)

All utility — widgets, notifications, digest — stays free forever;
paying is gratitude, not access.

- [ ] "Unterstützer werden" screen: pay-what-you-want consumable IAP
      tiers (3/5/10 €, optionally yearly), StoreKit 2.
- [ ] Gratitude bundle: alternate app icons, accent-colour themes,
      supporter quote pack, confetti when the last homework is ticked.
- [ ] Alternate app icons (Dima, 01.09.2026): wanted regardless of the
      supporter bundle — e.g. an Eli icon instead of the generic school
      cap. Free vs. supporter split to be decided when built. Note: the
      school's actual logo needs the school's okay before shipping it in
      an app store binary; a school-coloured original design needs
      nobody's.
- [ ] Family Sharing ON — one parent purchase covers the kid's phone.
- Prerequisites (Dima's call): paid developer account ($99/yr), App
  Store Connect banking/tax setup. A Ko-fi/GitHub-Sponsors link in the
  README costs nothing and needs no approval — do anytime.
- Explicitly rejected, with reasons, so this is not re-discussed:
  paid/sponsor-gated widgets (paywalls a child's timetable; creates
  paying customers on the most breakage-prone surface) and
  subscriptions (maximum parental resistance, minimum money).

---

## Wave 3 — the big lifts

### 3.1 Nachrichten (portal messages) — PAUSED (Dima, 01.09.2026), case on file

Dima's challenge (01.09.2026): "people are already in WhatsApp." The
answer for the record: WhatsApp is where *parents talk to parents*.
Teacher→parent and school→parent communication legally and practically
runs through SPH Nachrichten — teachers are generally not allowed to
use WhatsApp with pupils' families (data-protection rules), so the
messages that actually matter (teacher is ill, trip details changed,
grade conference) land in the portal, unread until someone remembers to
log in. The feature's value is one thing only: a push notification when
a teacher writes. Until then the portal browser under Mehr covers
reading them. Biggest lift on the list (E2E AES handshake,
reverse-engineered in lanis-mobile's `cryptor.dart`) — so it needs a
felt pain, not just an argument, before it's worth the build.

### 3.2 Fehlzeiten / attendance — v1 SHIPPED 01.09.2026

Turned out cheaper than planned: the *summary* (counts per course —
fehlend/entschuldigt/unentschuldigt, categories are per-school data)
sits in the `#anwesend` table on `meinunterricht.php`, which the app
already fetches — zero extra requests. Structure confirmed against
lanis-mobile's `student_parser.dart` (reads identical markup) and a
fixture test; **not yet verified against a live Eli page** — after the
next refresh, „Mehr" should show a „Fehlzeiten" row; if it doesn't or
shows nonsense, capture a masked dump of `meinunterricht.php`
(`Tools/dump-structure.user.js`) and fix the selectors against it.
The row is hidden until the portal reports any attendance data.

Not built (deliberately): the per-*date* detail on the per-course
`sus_view` pages — that would multiply requests by the number of
courses. If the counts ever aren't enough, that's the follow-up, loaded
on demand per course, and it starts with a masked `sus_view` dump.

### 3.3 Live Activity — maybe (unchanged)

Current lesson ticking through the school day. Fun, low practical value;
needs ActivityKit in the widget target. Only after the widgets have
proven themselves on real devices. Dima 01.09.2026: "maybe" — stays
parked behind the widget focus of Wave 2.

---

## Decided against (kept here so the discussion is not re-had)

- **Flohmarkt in the app**: children's user-generated content needs a
  server, accounts, moderation duty and GDPR-for-minors machinery — the
  exact things this deliberately serverless, read-only app must not
  grow. If the school community wants one, the Förderverein's channels
  are the right home; the app at most links to it (see 1.2).
- **A separate Eli app**: double maintenance through every Hessen HTML
  change, zero user-visible gain over the registry (Wave 1).
- **Paid widgets / subscriptions**: see 2.4.
- **Multi-account switching** (Dima, 01.09.2026): not needed for this
  household. The old rationale (per-account cookie jars would prevent
  the SPH one-session-per-account fights in
  `SPHClient.looksLikeErrorPage`) is noted in case the pain ever
  returns, but the feature is off the roadmap.
- **Scraping school websites** (01.09.2026): the news feature as
  originally speced — per-CMS selectors, Contao parser for Eli. Breaks
  silently on any school-site redesign, scales into a parser-request
  treadmill, and the audience (school sites post 1–3×/month) doesn't
  justify the risk. Replaced by a quick link (1.2); an RSS-only card may
  return later (see "Deferred" in Wave 1).

## Open questions for the review

1. ~~Wave 1 order?~~ Settled 01.09.2026: registry → quick links →
   mensa-optional; news parser deferred (RSS-only, if ever).
2. ~~Is the paid developer account happening?~~ Answered 01.09.2026:
   not yet, planned soon. 2.4 stays parked until it exists; the free
   Ko-fi/Sponsors README link can happen anytime. Nothing else waits.
3. ~~Digest and reminder times fixed (18:00 / 17:00)?~~ Settled
   01.09.2026: make them configurable — but only opportunistically,
   next time that notification code is open (e.g. the 2.2 mensa
   warning), never as its own task. Two time pickers in settings,
   current times as defaults. Rationale: timing varies per family, and
   a wrong-time notification gets notifications disabled wholesale.
4. ~~News card also tracking Elternbeirat/Förderverein page changes?~~
   Moot for now — news is a quick link in v1; revisit only if the RSS
   card ever ships.
