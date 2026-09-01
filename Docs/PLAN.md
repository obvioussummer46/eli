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

### 1.1 Per-school configuration registry  *(foundation — build first)*

- [ ] `Resources/schools.json`: `{ "5102": { mensaTenant, newsSource, links } }`
- [ ] `SchoolConfig` loader: registry entry for `settings.schoolID`,
      falling back to user-entered values, falling back to nothing.
- [ ] Settings UI: show what the registry provided; allow overrides.
- Effort: small. No network, no parsing — plumbing and one JSON file.

### 1.2 „Meine Schule" quick links  *(the v1 answer to school news)*

- [ ] Configurable link list in Mehr — Eli's registry entry ships
      Elternbeirat (`schulelternbeirat.html`), Förderverein
      (`foerderverein.html`), Termine (`termine.html`),
      Jahresterminplan, **and „Neues von der Schule" (`eli-news.html`)**;
      users can add their own (Hort, Schulwohnung …).
- [ ] Opens in the styled in-app browser — the school's own site is
      always correctly rendered and can never break in the app.
- Why this replaces the news parser: school sites post 1–3×/month; news
  is a nice-to-have, not a retention feature. A link delivers ~90 % of
  the value for ~5 % of the work and zero maintenance risk.
- Effort: small.

### 1.3 Mensa optional + tenant from registry

- [ ] `MensaEndpoints.tenant` comes from `SchoolConfig` (Eli's entry:
      `asb-heserv`), user-overridable for other menuebestellung.de schools
      (tenant list is public on the Systemauswahl page).
- [ ] "Essen-Tab anzeigen" toggle (default: on when a tenant is known,
      off otherwise) — a school without a caterer must not have a
      permanently dead tab that makes the app feel broken.
- [ ] Widgets + digest degrade cleanly when mensa is off (balance/dish
      fields simply absent from the shared snapshot).
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

### 2.1 Own tasks (manual homework)

- [ ] Plus button on Aufgaben: subject picker (from known subjects +
      free text), text, optional deadline.
- [ ] Stored in `Snapshot` beside `doneOverrides`; same tick-off, same
      deadline logic, same widget/digest inclusion. **Never** pushed to
      the portal.
- Why: teachers don't put everything in SPH ("2 € für den Ausflug
  mitbringen", "Sportbeutel!").
- Effort: medium.

### 2.2 Mensa „nichts bestellt" warning

- [ ] `MenuDay` already knows order state and `isLocked`; find the actual
      lock *time* per day on `speiseplan.php` first.
- [ ] Notification the evening before the ordering deadline: „Für
      Donnerstag ist nichts bestellt." Off by default, like all
      notifications.
- Why: prevents the real failure mode — a hungry kid.
- Effort: small once the deadline time is understood.

### 2.3 Widget deep links

- [ ] Tiny URL scheme + programmatic tab selection in `RootView` (tabs
      currently have no selection state), `widgetURL` per widget:
      Heute-widget → Aufgaben, Mensa-widget → Essen.
- Effort: small.

### 2.4 Unterstützer (the chosen monetisation — decided, awaiting go)

All utility — widgets, notifications, digest — stays free forever;
paying is gratitude, not access.

- [ ] "Unterstützer werden" screen: pay-what-you-want consumable IAP
      tiers (3/5/10 €, optionally yearly), StoreKit 2.
- [ ] Gratitude bundle: alternate app icons, accent-colour themes,
      supporter quote pack, confetti when the last homework is ticked.
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

### 3.1 Nachrichten (portal messages)

E2E-encrypted, but the AES handshake is reverse-engineered and shipped in
lanis-mobile (`liblanis/lib/src/session/cryptor.dart` + conversations
parser) — provably doable, largest item on this list. Parents get teacher
messages natively, with notifications.

### 3.2 Fehlzeiten / attendance

The per-course pages (`meinunterricht.php?a=sus_view&id=…`) carry
attendance records the app doesn't read. Exactly what a parent account is
for. First step: a masked structure dump of one `sus_view` page
(`Tools/dump-structure.user.js`).

### 3.3 Multi-account switching

Pupil + parent (or two kids) in one app: per-account cookie jars,
keychain entries, snapshots. Also *prevents* the SPH
one-session-per-account fights documented in
`SPHClient.looksLikeErrorPage`. Model on lanis-mobile's account switcher.

### 3.4 Live Activity

Current lesson ticking through the school day. Fun, low practical value;
needs ActivityKit in the widget target. Only after the widgets have
proven themselves on real devices.

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
