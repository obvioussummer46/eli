# Monetization — App Store strategy

Short, decision-oriented. Constraints first, then the four revenue lines,
then the build order. Numbers are starting points, not research.

## Hard constraints (read before pricing anything)

- **Audience is mostly minors.** No ad SDKs, no tracking, no "buy now"
  pressure. Apple reviews apps aimed at students strictly (Guideline 1.3,
  5.1.4). Everything below is IAP-only and works without an account.
- **Digital goods = Apple IAP, 30 %/15 % cut.** A "Buy me a coffee" link
  that leads to Ko-fi/PayPal *inside the app* is a Guideline 3.1.1
  rejection. Tips for the app must be consumable IAPs. External links
  are fine on the website, README and App Store description only.
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

## 1. Support the app (tip jar)

Consumable IAPs, shown once in Mehr › „App unterstützen", never as a
popup. Thank-you state stored locally, no receipt server needed.

| Product ID | Name | Price |
|---|---|---|
| `tip.small` | Kaffee ☕ | 1,99 € |
| `tip.medium` | Mittagessen 🥪 | 4,99 € |
| `tip.large` | Mensa-Woche 🍝 | 9,99 € |

- Copy: "Kein Abo, keine Werbung, kein Tracking. Die App bleibt kostenlos."
- After a tip: small badge in Mehr, optional "Unterstützer" alt-icon
  (free bonus, this is allowed and drives tips).
- Expected: ~1–2 % of MAU tip once. It funds the developer account, not
  a salary. Treat it as goodwill, not a revenue line.

## 2. Paid widgets

Rule: **existing three widgets + Live Activity stay free.** Sell *new*
widgets as one non-consumable "Widget-Paket", not per widget (per-widget
IAP means 6 products to review and users buying the wrong one).

Premium widget candidates, in build order:
1. **Lock-screen widgets** (accessoryCircular/Rectangular): next lesson,
   open homework count, mensa balance. Cheapest to build, highest wow.
2. **Interactive homework widget** (iOS 17 `AppIntent` button): tick
   homework from the home screen. Reuses the existing sync path.
3. **StandBy / large widget**: full-day plan with substitutions.
4. **Countdown widget**: next holiday / next Klausur from Termine.
5. **Apple Watch complications** (if a watch target ever ships).

| Product ID | Type | Price |
|---|---|---|
| `widgets.pack` | non-consumable | 3,99 € |

Included in Pro (below). Family Sharing on — parents buy once for
siblings.

## 3. Paid icon packs

Two tiers, because of the trademark issue above:

**Generic packs (sell freely):**
- `icons.classic` — 6–8 colour variants of the current icon (dark, mint,
  purple, mono, "Notizbuch", pixel).
- `icons.seasonal` — Weihnachten, Sommerferien, Abi; add one per year,
  same product ID, buyers get new ones free (good review magnet).
- Price 1,99 € each, or both in Pro.

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

**4a. One "Pro" unlock instead of many small products (recommended core).**
A single non-consumable `pro.lifetime` at **7,99 €** plus a yearly
`pro.yearly` at **2,99 €/Jahr** with 7-day trial. Contains: widget pack,
all generic icon packs, and the features below. One paywall, one
restore button, one thing to explain in reviews. Lifetime sells better
than subscriptions to parents; yearly exists for people who refuse
lifetime. Do not offer monthly (churn + support load).

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
| Tips ×3 | consumable | 1,99 / 4,99 / 9,99 € | — |
| Widget-Paket | non-consumable | 3,99 € | yes |
| Icon pack (each) | non-consumable | 1,99 € | yes |
| Pro lifetime | non-consumable | 7,99 € | — |
| Pro yearly | auto-renew, 7-day trial | 2,99 €/Jahr | — |
| Schulpaket | invoice, outside App Store | 150–300 €/Jahr | code batch |

Launch order: **tips → Pro (with widgets + icons inside) → school packs
on request → Schulpaket once 3+ schools are in the registry.**

## Build TODO

**Foundation**
- [ ] Enrol in App Store Small Business Program.
- [ ] Pick the paid-tier brand name (not "Schulportal …").
- [ ] Add `StoreKit` framework + `Products.storekit` config for local testing.
- [ ] `Store` actor (StoreKit 2): load products, purchase, `Transaction.currentEntitlements`, restore, observe `Transaction.updates`.
- [ ] `Entitlements` model (`isPro`, `hasWidgetPack`, `ownedIconPacks`, `hasTipped`) persisted in the App Group so widgets can read it.
- [ ] Paywall view (one screen, features list, lifetime + yearly, restore, Terms/Privacy links — required by 3.1.2).
- [ ] "App unterstützen" screen in Mehr with the three tips + thank-you state.
- [ ] Privacy nutrition label update (purchases are "Purchase history", not linked to identity).

**Widgets**
- [ ] Lock-screen widgets (3 families).
- [ ] Interactive homework widget (`AppIntent` toggle → existing `sus_homeworkDone` path).
- [ ] Gate premium widgets on the App Group entitlement; show a "Pro" placeholder that opens the paywall, never an empty widget.

**Icons**
- [ ] Draw 6 generic variants + 2 seasonal at 1024 px; add to asset catalog + `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in `project.yml`.
- [ ] Icon picker in Mehr, gated per pack; school icon auto-unlocked by `schoolID`.
- [ ] One-page consent template for school crests (DE), stored in `Docs/`.
- [ ] Add `iconName` field to `schools.json` entries.

**Pro features (pick 2 for launch)**
- [ ] Multi-account switcher.
- [ ] Custom notification times / quiet hours.
- [ ] Homework export.
- [ ] Shortcuts actions.

**Schulpaket**
- [ ] One-page offer (DE) + price, link from README.
- [ ] Generate offer codes in App Store Connect per school batch.

**Release**
- [ ] App Review notes: demo account, explain what is free, that tips are voluntary.
- [ ] Test: purchase, restore, Family Sharing, refund (sandbox `Transaction.updates` revocation), widgets after entitlement change.
