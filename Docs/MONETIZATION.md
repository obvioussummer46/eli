# Monetization — App Store strategy

Short, decision-oriented. Constraints first, then the revenue lines,
then the build order. Numbers are starting points, not research.

**Decided 18.09.2026, before the first paid build:** two lanes plus the
Schulpaket. Pro (yearly with a free week, or lifetime) carries every
feature and every icon pack; single icon packs are the à-la-carte step
below it. The tip jar and the separate widget pack were retired — see
§1 and §2 for why. Line-up: Pro Jahr 4,99 €, Pro Lifetime 14,99 €,
four icon packs à 1,99 €, Schulpaket on invoice.

## Hard constraints (read before pricing anything)

- **Audience is mostly minors.** No ad SDKs, no tracking, no "buy now"
  pressure. Apple reviews apps aimed at students strictly (Guideline 1.3,
  5.1.4). Everything below is IAP-only and works without an account.
- **Digital goods = Apple IAP, 30 %/15 % cut.** A "Buy me a coffee" link
  that leads to Ko-fi/PayPal *inside the app* is a Guideline 3.1.1
  rejection. External links are fine on the website, README and App
  Store description only.
- **App must stay complete for free.** Login, homework, timetable,
  calendar sync, mensa, the three existing widgets: never paywall these.
  Taking away shipped features triggers 1-star reviews and refunds.
- **School logos are not ours.** A school's crest is the school's (or
  the Land's) mark. Selling it as an icon pack without written consent
  is a trademark and a 5.2.1 problem. Generic designs are safe; real
  crests only with a signed OK from the school.
- **"Schulportal Hessen" is the Kultusministerium's name.** Monetising
  under that name raises the chance they object. Own brand for the paid
  tier (e.g. "Pausenhof Pro" — placeholder, pick one) and keep the
  portal name descriptive only.
- **Small-business program.** Enrol at appstoreconnect → 15 % instead of
  30 % under $1 M/year. Do this before the first paid build.

## 1. Tip jar — retired

Three consumable tips (1,99 / 4,99 / 9,99 €) shipped on 04.09.2026 and were
removed again on 18.09.2026, before any paid build reached the store.
Reasons, so nobody re-adds it:

- The users are pupils; the payer is a parent. A parent who wants to
  support the app now has a better way — Pro yearly — and a tip competes
  with it for the same impulse.
- Tip jars in utility apps convert well under 1 % even with adults.
- Consumables leave no entitlement behind, so the thank-you state was a
  local flag that could not be restored. One less special case.
- Three fewer products in App Store Connect, review notes and screenshots.

The "Unterstützer" icon stayed and now comes with Pro. Adults who need
nothing from Pro can use GitHub Sponsors on the website (§4d).

All product ids live in `Shared/Entitlements.swift` (`ProductID`); the
local test config is `Config/Products.storekit`, wired into the run
scheme.

## 2. Paid widgets — Pro only

Rule: **existing three widgets + Live Activity stay free.** *New*
widgets are a Pro feature. A separate non-consumable "Widget-Paket"
(3,99 €) was defined but never had a buy button, and was retired on
18.09.2026: widgets are functionality, and functionality lives in Pro.
Cosmetics (icon packs) are the only thing sold à la carte.

Premium widget candidates, in build order:
1. **Lock-screen widgets** (accessoryCircular/Rectangular): next lesson,
   open homework count, mensa balance. Cheapest to build, highest wow.
2. **Interactive homework widget** (iOS 17 `AppIntent` button): tick
   homework from the home screen. Reuses the existing sync path.
3. **StandBy / large widget**: full-day plan with substitutions.
4. **Countdown widget**: next holiday / next Klausur from Termine.
5. **Apple Watch complications** (if a watch target ever ships).

Family Sharing is on for Pro — parents buy once for siblings.

## 3. Paid icon packs

Two tiers, because of the trademark issue above:

**Generic packs (sell freely):**
- `icons.classic` — 6–8 colour variants of the current icon (dark, mint,
  purple, mono, "Notizbuch", pixel).
- `icons.seasonal` — Weihnachten, Sommerferien, Abi; add one per year,
  same product ID, buyers get new ones free (good review magnet).
- `icons.styles1` — the satchel in eight drawing styles (Comic, Manga,
  Pixel, Neon, Kawaii, Graffiti, Handheld, Holo).
- `icons.styles2` — Sechs-Sieben, Heldencomic, Farbe, Geigenkasten, Noten,
  Kreide. Genre styling only: no character likeness, logotype or name from
  any existing franchise goes into an icon.
- Price 1,99 € each, or all of them in Pro.

**School packs (only with consent):**
- Do **not** pre-draw crests for every Hessen school. 1 700+ schools,
  and each icon must be *bundled* in the binary (alternate icons cannot
  be downloaded), so every school adds ~200 KB and a review cycle.
- Flow instead: school (Förderverein, SV, or Schulleitung) asks → signs
  a one-page consent → icon added to `schools.json` entry + asset
  catalog → shipped in next release. Eli's `AppIconEli` is the prototype.
- Price: **free for the school's students** (unlocked by `schoolID`),
  because charging for the school's own crest annoys both the school
  and the parents. The school pack is the *hook*, the Pro tier is the
  revenue. Alternatively the school pays (see 4c).

Implementation note: alt icons need `CFBundleIcons` entries, 1024 px
source, and `UIApplication.setAlternateIconName`. Selling them is fine
(non-consumable), just restore-purchases must work.

## 4. Suggested additional strategies

**4a. One "Pro" unlock instead of many small products (the core).**
A yearly `pro.yearly` at **4,99 €/Jahr** with a 7-day free trial, and a
non-consumable `pro.lifetime` at **14,99 €**. Contains: the premium
widgets, all generic icon packs (current and future), and the features
below. One paywall, one restore button, one thing to explain in reviews.

Why yearly is the default and lifetime the expensive option (repriced
18.09.2026 from 2,99 €/7,99 €): a pupil starts in Klasse 5 and stays up
to eight years, so a yearly plan earns several times what a cheap
lifetime does, and the free week is the one way to *test* Pro. Lifetime
is priced at about three years for the parent who refuses subscriptions.
No monthly plan (churn, forgotten renewals, support mail — and school
runs in years anyway). Yearly goes first on the paywall.

Pro-only features worth building (each is small, each is "nice, not
needed", which is exactly what a paywall may gate):
- Multiple children / accounts side by side (parent use case; the
  parent-account support already exists).
- Noten/Klausuren tracker with average, if the portal exposes grades.
- Homework export (PDF/CSV) and Shortcuts/Siri actions ("Was habe ich
  morgen?").
- Custom notification times per subject, quiet hours.
- Themes (accent colour, app-wide dark variants) — pairs with icon packs.
- iCloud sync of the local homework archive between iPhone and iPad.

**4b. Family Sharing on every non-consumable.** Free to enable, halves
refund requests from households with two kids.

**4c. School sponsorship (B2B, outside the App Store).**
The registry makes schools "data, not code". Offer schools/Fördervereine
a yearly **Schulpaket** (e.g. 150–300 €/Jahr, invoiced, no Apple cut):
their crest as icon, their links preconfigured, mensa tenant set up,
optional Pro for all their students via a redeem code batch (Apple
offer codes / promo codes are allowed here). One school covers the
developer account; ten schools are a real side income. This is the
only line here that scales without Apple's 15–30 %.

**4d. GitHub Sponsors / Ko-fi — website and README only.** Adults who
want to support recurring will use it. Never link from the app.

**4e. Things to explicitly not do.**
- Ads (minors, GDPR, App Review, and they pay ~nothing at this scale).
- Selling data or "analytics to schools".
- Consumable "credits" or anything gamified.
- Gating notifications or the calendar sync — those are the retention
  features; paywalling them kills growth.

## Pricing summary

| Product | Type | Price | In Pro? |
|---|---|---|---|
| Pro yearly | auto-renew, 7-day trial | 4,99 €/Jahr | — |
| Pro lifetime | non-consumable | 14,99 € | — |
| Icon pack (each, 4 today) | non-consumable | 1,99 € | yes |
| Schulpaket | invoice, outside App Store | 150–300 €/Jahr | code batch |

Retired: tips ×3 (consumable), Widget-Paket (3,99 €). Never re-create
those ids.

Anchor for the paywall: four packs singly are 7,96 €, Pro yearly is
4,99 € and adds the widgets and the features. Keep the pack count at
four; if more cosmetics come, ship them inside existing packs (the
seasonal pack grows every year) rather than as new products.

Launch order: **Pro (with widgets + icons inside) → school packs on
request → Schulpaket, pitched to every school as it joins the registry.**

## Picking the paid-tier name

The paid tier needs its own name because "Schulportal Hessen" belongs to
the Kultusministerium and "Pro" alone is not a brand. Rules, in order:

1. **Not a portal name.** No "Schulportal", "SPH", "Hessen", "Lanis".
   The free app can keep describing itself as "für das Schulportal
   Hessen"; the paid thing must not look official.
2. **A German school word, one or two syllables, that a 12-year-old
   says without embarrassment.** It appears in the App Store receipt on
   the parents' phone and in the widget gallery.
3. **Free on the App Store, free at DPMA.** Search apps.apple.com and
   register.dpma.de (Klasse 9 and 42) for the exact word. A domain is
   nice, not required.
4. **Works as "X" and "X Pro".** The app itself can later be renamed to
   X; the tier is X Pro. Do not name the tier something the app is not.
5. **Unambiguous when spoken.** Test: say it on the phone to a
   grandparent buying a gift card.

Shortlist to check (none verified yet):

| Name | Why | Risk |
|---|---|---|
| **Ranzen** | The bag every pupil carries. Short, warm. | Common word, check trademarks in Klasse 9. |
| **Pausenhof** | Where school actually happens. | Three syllables, long on a widget. |
| **Tafel** | Blackboard. Very short. | Generic, harder to own. |
| **Schulheft** | Notebook, fits the Notizbuch icon. | Two existing apps use it in some form. |
| **Klingel** | The bell, and the app rings you. | Sounds like a doorbell app. |
| **Hefter** | Folder for homework. | Regional word. |

Recommendation: shortlist two, run the DPMA and App Store checks, then
pick the one that still looks fine as an icon label at 11 pt.


### Wider brainstorm (04.09.2026)

**Hessian flavour** — unique, no generic-word problem:
- ★ **Gude** — the Hessian "hi". Kids say it daily, parents smile, "Gude Pro" works. App is Hessen-only, so the regionalism is a feature.
- Ei Gude — playful, too long for an icon label.

**Kids' slang** — feels like their app, not the school's:
- ★ **Hausi** — what every pupil calls Hausaufgaben. Likely taken; check first.
- Spicker — cheat sheet. Kids love it, teachers do not. Risky.
- Freistunde — great promise, three syllables.

**Sounds of school:**
- ★ **Gong** — one syllable, "Gong Pro". Check class 42 (a US software company).
- Klingel — reads like a doorbell app.
- Pause — perfect meaning, impossible to own.

**Objects:**
- Ranzen (still solid), Kreide (chalk, short, probably free), Mäppchen
  (umlaut hurts in URLs and ids), Tornister (distinctive, slightly
  military), Zettel (neutral, generic).

**Invented, only if every real word fails:** Schulio, Stundo, Plani, Ranzo.

**Narrowing:** shortlist Gude, Hausi, Gong, Ranzen, Kreide → App Store,
DPMA, `name.app` domain → ask ten pupils which they would say out loud.

## Build TODO

**Foundation**
- [ ] Enrol in App Store Small Business Program.
- [x] Pick the paid-tier brand name — **Ranzen Pro** for now (`Shared/Brand.swift`, one place to change).
- [x] Add `StoreKit` framework + `Products.storekit` config for local testing.
- [x] `Store` (StoreKit 2): load products, purchase, `Transaction.currentEntitlements`, restore, observe `Transaction.updates`.
- [x] `Entitlements` model (`isPro`, `ownedIconPacks`) persisted in the App Group so widgets can read it.
- [x] Paywall view (one screen, features list, yearly first + lifetime, restore, Terms/Privacy links — required by 3.1.2).
- [x] ~~"App unterstützen" screen in Mehr with the three tips~~ — retired 18.09.2026 (§1).
- [x] Retire the widget pack product (§2); premium widgets are Pro only.
- [x] Reprice: Pro Jahr 4,99 €, Pro Lifetime 14,99 € (§4a).
- [x] Privacy nutrition label answers, App Store texts and review notes: `Docs/APP-STORE.md`. Privacy policy: <https://bittel.app/de/ranzen-datenschutz.html> (source in the `obvioussummer46/bittel` repository).

**Widgets**
- [x] Lock-screen widgets — Aufgaben and Countdown in circular, rectangular and inline; the three free widgets keep theirs.
- [x] Interactive homework widget (`AppIntent` toggle → existing `sus_homeworkDone` path).
- [x] Gate premium widgets on the App Group entitlement; show a "Pro" placeholder that opens the paywall, never an empty widget.

**Icons**
- [x] Draw 6 generic variants + 2 seasonal (+ Unterstützer), generated by `Tools/make-icons.py` at 1024 px; add to asset catalog + `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `project.yml`.
- [x] Icon picker in Mehr, gated per pack; school icon auto-unlocked by `schoolID`.
- [x] One-page consent template (`Docs/SCHULLOGO-EINWILLIGUNG.md`) for school crests (DE), stored in `Docs/`.
- [x] Add `iconName` field to `schools.json` entries.

**Pro features (two shipped for launch)**
- [ ] Multi-account switcher.
- [x] Custom notification times (digest and homework reminder; Pro).
- [x] Homework export (text and CSV, share sheet; Pro).
- [x] Siri shortcut „Was habe ich morgen?“ (`Shortcuts/TomorrowIntent.swift`, Pro).

**Schulpaket** (`Docs/SCHULPAKET.md`)
- [x] One-page offer (DE) + price, link from README.
- [ ] Generate offer codes in App Store Connect per school batch.

**Release**
- [x] App Review notes drafted in `Docs/APP-STORE.md` — fill in the demo account.
- [ ] Test: purchase, restore, Family Sharing, refund (sandbox `Transaction.updates` revocation), widgets after entitlement change.
