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

The app **never handles your password**. Signing in opens the portal's real
login page in a `WKWebView`; SSO, two-factor and school-specific identity
providers therefore all keep working. Once the portal hands out a session
cookie, that cookie is copied into the app's `URLSession` and everything after
that is plain native fetching. Nothing leaves the device.

Entering your school number (the `?i=…` in the portal URL) is optional — it just
preselects your school on the login page.

## Repository layout

```
SchulportalMobile/
  App/            app entry, tab shell
  Auth/           web-view login
  Networking/     session, endpoints, fetch + push
  Parsing/        HTML → model (SwiftSoup)
  Models/         Course, Homework, Timetable, Subject catalogue
  Storage/        observable app state, JSON snapshot, settings
  CalendarSync/   EventKit writer
  Features/       Today, Homework, Timetable, Portal, Settings
  Resources/      bundled restyle script
userscript/       the original Safari userscript (source of truth)
Tools/            sync-userscript.sh, dump-structure.user.js
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
* Unofficial and unaffiliated with the Land Hessen.
