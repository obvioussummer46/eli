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

## Wave 1 — "one app, every school": the per-school registry trio

The architectural decision behind this wave (settled): **one
Hessen-generic app, no Eli fork.** Everything school-specific becomes
*data, not code* — a small bundled JSON registry keyed by Schulnummer,
with Elisabethenschule (5102) as the first fully configured school and a
"configure your own" path for everyone else. Another school = a one-entry
PR, not a fork.

### 1.1 Per-school configuration registry  *(foundation — build first)*

- [ ] `Resources/schools.json`: `{ "5102": { mensaTenant, newsSource, links } }`
- [ ] `SchoolConfig` loader: registry entry for `settings.schoolID`,
      falling back to user-entered values, falling back to nothing.
- [ ] Settings UI: show what the registry provided; allow overrides.
- Effort: small. No network, no parsing — plumbing and one JSON file.

### 1.2 Mensa optional + tenant from registry

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

### 1.3 Schul-News („Neues von der Schule")

- [ ] Public pages, no login → own ephemeral fetch like `SchoolDirectory`,
      never through `SPHClient`.
- [ ] Two parser dialects:
      **WordPress**: `/feed` RSS autodiscovery (covers many school sites
      for free). **Contao list page**: Eli's site
      (www.elisabethenschule.net, Contao CMS, no RSS) — list at
      `eli-news.html`, articles under `eli-news-lesen/<slug>.html`;
      capture the list page's structure before writing selectors.
- [ ] Surface: "Neues von der Schule" card on Heute (top 2–3, tap →
      styled in-app browser), full list behind it.
- [ ] News source comes from the registry (Eli preconfigured); manual URL
      entry for unlisted schools.
- Effort: medium. The parser is the only real work; everything else is
  existing patterns.

### 1.4 „Meine Schule" quick links

- [ ] Configurable link list in Mehr — Eli's registry entry ships
      Elternbeirat (`schulelternbeirat.html`), Förderverein
      (`foerderverein.html`), Termine (`termine.html`),
      Jahresterminplan; users can add their own (Hort, Schulwohnung …).
- [ ] Opens in the styled in-app browser.
- Effort: small. The cheap sibling of 1.3 — 90 % of the value for 5 % of
  the work; could even ship before it.

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
  are the right home; the app at most links to it (see 1.4).
- **A separate Eli app**: double maintenance through every Hessen HTML
  change, zero user-visible gain over the registry (Wave 1).
- **Paid widgets / subscriptions**: see 2.4.

## Open questions for the review

1. Wave 1 in the proposed order (registry → mensa-optional → links →
   news), or pull 1.4 links forward as the quick win?
2. Is the paid developer account happening? (Gates 2.4 and clean device
   installs/TestFlight for the family; everything else works without it.)
3. Digest and reminder times are fixed (18:00 / 17:00) — good enough, or
   make them configurable while in that code anyway?
4. Should the Heute tab's news card (1.3) also show Elternbeirat/
   Förderverein page *changes*, or is school news enough for v1?
