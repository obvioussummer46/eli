# App Store Connect — everything to paste

Ready-to-paste texts and settings for the first release. Character limits
are Apple's; `Tools/check-app-store-texts.py` verifies every text in this
file against them, so run it after editing:

```sh
python3 Tools/check-app-store-texts.py
```

Primary language: **German (Germany)**. No other localisation — the app
itself is German only.

## Products to create (Features › In-App Purchases / Subscriptions)

Reference name and product id must match `Shared/Entitlements.swift`.
Family Sharing on for every non-consumable and the subscription.

| Reference name | Product id | Type | Price (DE) | Family |
|---|---|---|---|---|
| Tip Kaffee | `de.schulportalmobile.app.tip.small` | Consumable | 1,99 € | — |
| Tip Mittagessen | `de.schulportalmobile.app.tip.medium` | Consumable | 4,99 € | — |
| Tip Mensa-Woche | `de.schulportalmobile.app.tip.large` | Consumable | 9,99 € | — |
| Widget-Paket | `de.schulportalmobile.app.widgets.pack` | Non-consumable | 3,99 € | on |
| Icons Klassisch | `de.schulportalmobile.app.icons.classic` | Non-consumable | 1,99 € | on |
| Icons Saison | `de.schulportalmobile.app.icons.seasonal` | Non-consumable | 1,99 € | on |
| Pro Lifetime | `de.schulportalmobile.app.pro.lifetime` | Non-consumable | 7,99 € | on |
| Pro Jahr | `de.schulportalmobile.app.pro.yearly` | Auto-renewable, group „Ranzen Pro“, 1 year, 7-day free trial | 2,99 € | on |

Localised display names (max 30) and descriptions (max 45), German:

| Product | Display name | Description |
|---|---|---|
| tip.small | Kaffee | Ein Kaffee für die Weiterentwicklung. |
| tip.medium | Mittagessen | Ein Mittagessen für die Weiterentwicklung. |
| tip.large | Mensa-Woche | Eine Mensa-Woche für die Weiterentwicklung. |
| widgets.pack | Widget-Paket | Aufgaben-, Tagesplan- und Countdown-Widget. |
| icons.classic | Symbole: Klassisch | Sechs Farbvarianten des App-Symbols. |
| icons.seasonal | Symbole: Saison | Saisonale App-Symbole, jedes Jahr mehr. |
| pro.lifetime | Ranzen Pro | Alle Widgets, Symbole und Extras. Für immer. |
| pro.yearly | Ranzen Pro (Jahr) | Alle Widgets, Symbole und Extras. Jährlich. |

Subscription group display name: **Ranzen Pro**. Subscription
localisation „Ranzen Pro (Jahr)“.

Review screenshot for each product: the paywall (Pro), the tip screen
(tips), the icon picker (icon packs), the widget gallery (widget pack).
Every product must be attached to the version before it is submitted —
a product submitted on its own is reviewed on its own, without the app.

## App information

- **Name (30):** Schulportal: Aufgaben & Plan
- **Subtitle (30):** Hausaufgaben, Plan & Mensa
- **Bundle id:** `de.schulportalmobile.app` — SKU: `schulportalmobile-ios`.
- **Category:** Education. Secondary: Productivity.
- **Content rights:** does not contain, show or access third-party
  content (the portal pages are the user's own account, not licensed
  content).
- **Age rating** (the 2025 questionnaire): no violence, no sexual
  content, no profanity, no horror, no gambling, no contests, no drugs,
  no medical content. Unrestricted web access: **No** (the browser only
  opens the portal and the school links the app or the user configured).
  User-generated content: No. Messaging/chat: No. Advertising: No.
  Result: **4+**.
- **Privacy policy URL:**
  `https://github.com/obvioussummer46/eli/blob/main/Docs/DATENSCHUTZ.md`
  (the same URL as `StoreLinks.privacy`; the repo is public).
- **Support URL:** `https://github.com/obvioussummer46/eli#readme`
- **Marketing URL:** leave empty.
- **Copyright:** `2026 Dmitry Baklashev` (the LICENSE holder; use
  `2026 Bittel UG (haftungsbeschränkt)` if the company publishes).
- **Version:** 1.0, build from `CURRENT_PROJECT_VERSION` (bump the
  build number for every upload; Xcode › target › General, or
  `agvtool new-version -all N`).
- **Sign-in required:** yes — see App Review notes below.

### On the name

„Schulportal“ is the portal's own name. The description says in the
first and last paragraph that the app is unofficial, which is what App
Review looks for (guideline 4.1 / 5.2.1). If review still objects, the
fallback name is **Ranzen: Schulportal Hessen** (28 characters) — the
Pro tier already trades under „Ranzen“, so nothing else changes.

## Promotional text (170)

Hausaufgaben abhaken, Stundenplan im Kalender, Vertretungen und Mensa —
alles vom Schulportal Hessen, nur schneller. Kostenlos, ohne Werbung.

## Description (4000)

Die schnelle App fürs Schulportal Hessen — für Schülerinnen, Schüler und
Eltern.

HAUSAUFGABEN
Alle offenen Aufgaben aus „Mein Unterricht“ auf einer Liste. Ein Tipp
zum Abhaken, das landet auch im Portal. Nichts geht verloren, auch
offline nicht.

STUNDENPLAN
Als Tagesliste oder Wochenraster — und mit einem Tipp in deinen
iOS-Kalender, in einen eigenen Kalender, der deine anderen Termine in
Ruhe lässt. Eigene AGs und Kurse trägst du einmal ein, dann stehen sie
überall mit im Plan.

HEUTE
Vertretungen, die aktuelle Stunde, fällige Aufgaben und die nächsten
Schultermine auf einen Blick. Nach der letzten Stunde zeigt die App
schon den nächsten Schultag.

MENSA
Speiseplan, bestellte Gerichte und Guthaben deiner Mensakarte (für
Schulen mit menuebestellung.de). Nur lesen — bestellt wird weiter auf
der Website.

WIDGETS UND ERINNERUNGEN
Nächste Stunde, Tagesüberblick und Mensa-Guthaben als Widget. Die
laufende Stunde als Live-Aktivität. Abends ein Überblick für morgen und
eine Erinnerung an fällige Aufgaben — alles lokal auf dem Gerät.

DEINE DATEN BLEIBEN DEINE
Kein eigener Server, keine Werbung, kein Tracking. Zugangsdaten liegen
im Schlüsselbund deines Geräts. Die App liest genau die Seiten, die du
auch im Browser siehst.

RANZEN PRO (optional)
Ein Aufgaben-Widget mit Abhaken direkt auf dem Homescreen, ein großes
Tagesplan-Widget, ein Ferien-Countdown, alle App-Symbole, eigene
Erinnerungszeiten, Aufgaben-Export und die Siri-Abfrage „Was habe ich
morgen?“. Einmal kaufen oder jährlich, mit Familienfreigabe. Die App
selbst bleibt kostenlos.

Inoffizielle App. Kein Angebot des Hessischen Kultusministeriums oder
des Schulportals Hessen. Du brauchst ein Schulportal-Konto deiner
Schule.

## Keywords (100)

schulportal,hessen,hausaufgaben,stundenplan,vertretungsplan,mensa,schule,lanis,schüler,eltern

## What's new (1.0)

Erste Version: Hausaufgaben abhaken, Stundenplan als Tag und Woche und
im iOS-Kalender, Vertretungen, Termine, Mensa, drei Widgets und
Erinnerungen. Optional: Ranzen Pro mit mehr Widgets, App-Symbolen,
eigenen Erinnerungszeiten, Export und Siri. Die App bleibt kostenlos.

## Screenshots

Generated from the app's own screenshot mode, never from a real account
(`SchulportalMobile/App/DemoMode.swift`: invented school, invented
pupil, invented teachers). `Tools/screenshots.sh` documents the capture;
the finished images are in `Docs/AppStore/screenshots/`, the raw
captures in `Docs/AppStore/raw/`.

| Slot in App Store Connect | Device captured | Size | Files |
|---|---|---|---|
| iPhone 6.9" (covers every iPhone) | iPhone 17 Pro Max simulator | 1320 × 2868 | `iphone-01…05` |
| iPad 13" (covers every iPad) | iPad Pro 13" (M5) simulator | 2064 × 2752 | `ipad-01…05` |

Order and captions (the headline is on the image; nothing to type):

1. **Heute** — Alles für morgen auf einen Blick
2. **Aufgaben** — Hausaufgaben abhaken
3. **Plan** (week grid) — Der Stundenplan, endlich lesbar
4. **Essen** — Mensa und Guthaben
5. **Mehr** — Deine Schule, deine Links

No app preview video. Uploading the raw captures instead of the framed
ones is also allowed — same sizes, no alpha channel either way.

## App Review notes

```
Demo account
  Hessen issues no test accounts for its school portal, so the app
  ships a fully featured demo mode instead (guideline 2.1):
    Username: apple-review
    Password: Demo-Schulportal-2026
  On the login screen choose "Bildungsserver" (no school needed), enter
  the credentials, tap "Anmelden". The app then shows an invented
  school with a full week of data — timetable, homework, substitutions,
  calendar, mensa — entirely on device; no request leaves the phone.
  Every feature behaves as with a real account, except that ticking a
  homework off is not sent to the portal (there is none). "Abmelden"
  under Mehr returns to the login screen.

Mensa tab
  Only appears for schools with a configured caterer. Demo school has
  one; mensa login: [username / password] — read-only, no orders.

Purchases
  All purchases are optional. The complete app (login, homework,
  timetable, calendar sync, mensa, three widgets, notifications) works
  without buying anything. Tips are voluntary consumables with no
  functional unlock beyond an alternate app icon. Pro unlocks three
  additional widgets, icon packs, custom reminder times, homework
  export and a Siri shortcut. Restore Purchases is on the paywall
  (Mehr › Ranzen Pro freischalten). Terms and privacy are linked on
  the paywall.

Alternate icons
  Mehr › App-Symbol. "Eli" is our own design in the school's colours,
  not the school's crest.

Background
  Uses BGAppRefreshTask to refresh the same pages the user sees; no
  push, no server. Calendar access is only requested when the user
  taps "In den Kalender schreiben" under Plan.

Unofficial
  The app is not affiliated with Hessisches Kultusministerium; the
  description says so. Users log in with their own school account.
```

Contact for review: catchr@icloud.com, phone number as in the Apple
developer account.

The review credentials are constants in `DemoMode` and deliberately
long: they are compared exactly, and no real portal account can be
called `apple-review`. Changing them means changing this file too.

## Privacy nutrition label (App Privacy)

Answer "Do you or your third-party partners collect data from this
app?" with **No**. Rationale: everything stays on device; the portal and
the caterer are services the user logs into themselves, not the
developer's collection; StoreKit purchase data is Apple's. If Apple's
questionnaire pushes back, the only category that could apply is
*Purchases → Purchase History*, "used for app functionality, not linked
to identity, not used for tracking".

The privacy manifests (`SchulportalMobile/PrivacyInfo.xcprivacy`,
`SchulportalWidgets/PrivacyInfo.xcprivacy`) say the same: no tracking,
no collected data, `UserDefaults` declared with reason `CA92.1`.

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in both Info.plists: the app
uses nothing beyond HTTPS, which is exempt. App Store Connect will not
ask on upload.

## Before submitting

Account and agreements:

- [ ] Paid Applications agreement signed, tax and banking filled (the
      tip jar alone needs it).
- [ ] App Store Small Business Program enrolled (15 % instead of 30 %).
- [ ] App record created with bundle id `de.schulportalmobile.app`; the
      App Group `group.de.schulportalmobile.app` and the widget bundle id
      `de.schulportalmobile.app.widgets` exist in the developer portal
      (Xcode's automatic signing creates them on the first archive).

Content:

- [ ] `Docs/DATENSCHUTZ.md` §1 names Bittel UG, Rendeler Straße 44,
      60385 Frankfurt — the same Verantwortlicher as the Impressum on
      bittelecom.de. Change it if the App Store account is the personal
      one rather than the company's.
- [ ] The review login (username `apple-review`) still opens the demo
      data on a fresh install — try it once on the TestFlight build.
- [ ] All eight products created, localised, priced, and attached to
      the version.
- [ ] Screenshots uploaded to the 6.9" and 13" slots.

Build:

- [ ] Build number bumped.
- [ ] Product › Archive on a device destination (any iOS device,
      arm64), then Distribute › App Store Connect › Upload.
- [ ] The archive contains `PrivacyInfo.xcprivacy` in both bundles
      (Xcode's synchronized folders pick the files up automatically;
      check the archive's Privacy Report under Window › Organizer).
- [ ] TestFlight: one internal tester run on a real device — widgets,
      calendar write, a sandbox purchase and Restore Purchases, the
      Siri shortcut (App Shortcuts only work signed with the team id,
      not in the simulator).
- [ ] Version submitted with "Manually release this version" so the
      release can wait for the products' approval.
