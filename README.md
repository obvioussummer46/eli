# Schulportal Hessen — native iOS App

A native SwiftUI app that turns [start.schulportal.hessen.de](https://start.schulportal.hessen.de/index.php)
into something usable on a phone: **open homework on one list, one tap to tick
off**, and a **timetable that goes straight into the iOS calendar**.

It is the next step after the Safari userscript in `userscript/` — that script
still lives here, and the exact same code is bundled into the app's built-in
browser tab so the pages the app does not parse natively (Nachrichten,
Vertretungsplan, Kalender) still look right.

## What it does

| Tab | |
|---|---|
| **Heute** | What's on right now, the rest of today's lessons, and the open homework digest. |
| **Aufgaben** | Every open homework from *Mein Unterricht*, grouped, searchable, filterable by subject. Tap the circle or swipe to mark done — the flag is pushed back to the portal and kept locally either way. |
| **Plan** | The weekly timetable as a day list or a week grid, and the button that writes it into a dedicated iOS calendar. |
| **Essen** | This week's mensa menu and what is left on the lunch card, from `menuebestellung.de`. Read-only. |
| **Portal** | The real portal in a web view, restyled by the bundled userscript. |
| **Mehr** | Account, refresh behaviour, calendar options. |

### Homework, marked done properly

* The local flag is **always** what the UI shows, so a tap is instant and never
  lost — even offline, and even for entries the portal gives no id for.
* In the background the app posts the same `sus_homeworkDone` form the portal's
  own page uses, so the tick shows up in the browser and for teachers.
* If that fails, the item is marked "not yet synced" and retried on the next
  refresh.
* Homework that scrolls out of the portal's two-week window but was never
  ticked off is kept in a local archive instead of silently disappearing.

### Mensa and lunch balance

A second, unrelated service: the school's caterer runs on `menuebestellung.de`,
with its own account. The **Essen** tab shows the week's menu, which dish is
already ordered, the card balance and the last month of bookings.

* **Read-only on purpose.** Choosing a menu spends real money, so the app shows
  the selection the website holds and never changes it. Ordering stays on
  `menuebestellung.de`.
* Unlike the Schulportal, this site offers nothing but a username/password API —
  no SSO, no login page worth embedding. So the credentials go into the **iOS
  Keychain** (device-only, never synchronised) and the app signs itself back in
  when the session expires, instead of putting a login screen in front of a
  child every few hours. They are verified against the site before they are
  stored.
* Its session is kept in a private cookie jar, so signing out of the Schulportal
  cannot take the mensa session with it, and vice versa.

### Timetable → iOS calendar

* Creates one dedicated calendar, `Stundenplan (Schulportal)`, and only ever
  writes there. Your own calendars are untouched.
* Materialises real events for the next *n* weeks (default 4) instead of a
  recurring rule, and rewrites that window on every sync — so a mid-year plan
  change lands correctly.
* Optionally adds homework as all-day events.
* Events carry room, period and teacher in the notes.

## Building

Requirements: **Xcode 16 or newer**, iOS 17 deployment target.

```sh
open SchulportalMobile.xcodeproj
```

Then set your own signing team on the `SchulportalMobile` target and run on a
device. The only dependency is [SwiftSoup](https://github.com/scinfu/SwiftSoup)
(HTML parsing), resolved automatically by Swift Package Manager on first build.

The project uses Xcode 16 file-system-synchronized groups: **files added to
`SchulportalMobile/` on disk are picked up automatically**, no project edits
needed. If the project file ever gets damaged, regenerate it:

```sh
brew install xcodegen && xcodegen generate
```

## How login works

The app **never handles your Schulportal password**. Signing in opens the
portal's real login page in a `WKWebView`; SSO, two-factor and school-specific
identity providers therefore all keep working. Once the portal hands out a
session cookie, that cookie is copied into the app's `URLSession` and everything
after that is plain native fetching. Nothing leaves the device.

Choosing your school is optional and happens by **name**: the app loads the same
public directory the portal's own login page uses (all ~2000 Hessen schools) and
searches it by school name or town, so nobody has to dig the `?i=…` number out
of a URL. The number can still be typed in directly. Either way it only
preselects the school on the login page.

(The **Essen** tab is the exception to "no password": `menuebestellung.de` has
no SSO and offers nothing but a username/password API, so those credentials —
and only those — go into the iOS Keychain, device-only. See above.)

## Repository layout

```
SchulportalMobile/
  App/            app entry, tab shell
  Auth/           web-view login, school picker
  Networking/     session, endpoints, school directory, fetch + push
  Parsing/        HTML → model (SwiftSoup)
  Models/         Course, Homework, Timetable, School, Subject catalogue
  Storage/        observable app state, JSON snapshot, settings
  CalendarSync/   EventKit writer
  Features/       Today, Homework, Timetable, Mensa, Portal, Settings
  Resources/      bundled restyle script
userscript/       the original Safari userscript (source of truth)
Tools/            sync-userscript.sh, dump-structure.user.js, capture-samples.mjs
samples/          masked structure dumps used to tune the parsers (see samples/README.md)
Docs/             architecture and the scraping contract
```

## Caveats, honestly

* This is a **scraper**. The portal is not a public API; when Hessen changes its
  HTML, parsing breaks. `Docs/PORTAL-SCRAPING.md` lists exactly which selectors
  are load-bearing and where to fix them, and `Tools/dump-structure.user.js`
  exports a page's structure with all personal text masked — so a parser fix
  never requires handing over portal credentials.
* The `sus_homeworkDone` round-trip is reconstructed from the portal's own page
  behaviour. If your school's portal rejects it, the app degrades to local-only
  ticking and tells you so in the homework detail sheet — nothing breaks.
* Timetable layouts differ between schools. The parser walks the grid generically
  (colspan/rowspan aware) and falls back to standard Hessen bell times when a
  plan omits the time column, but an exotic layout may need a tweak.
* Messages (*Nachrichten*) are end-to-end encrypted in the portal and are not
  parsed natively; they open in the Portal tab.
* The **Essen** tab is a scraper too, against a different site. The balance and
  the account statement come from `menuebestellung.de`'s own JSON API, but the
  menu itself is parsed out of `speiseplan.php` — the one page that carries the
  week's dishes, the current order *and* the balance in a single request.
* Unofficial and unaffiliated with the Land Hessen, the ASB or OPAL Catering.
