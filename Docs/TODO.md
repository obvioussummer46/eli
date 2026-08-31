# Ideas parked for later

Review each before building — the context below is from the September 2026
debugging sessions and may age.

## Own tasks (manual homework)
Teachers don't put everything in SPH ("bring 2 € for the trip",
"Sportbeutel!"). A plus button on the Aufgaben tab for manual entries with
subject + deadline, living alongside scraped homework with the same
tick-off. Store in `Snapshot` next to `doneOverrides`; they must never be
pushed to the portal.

## Mensa "nichts bestellt" warning
`MenuDay` already knows which days have no order and when the deadline
locks (`isLocked`). A notification the evening before the ordering deadline
("Für Donnerstag ist nichts bestellt") prevents the actual failure mode: a
hungry kid. Needs the deadline *time* — check `speiseplan.php` for when a
day flips to locked.

## Nachrichten (portal messages)
End-to-end encrypted, but the AES handshake is reverse-engineered and
shipped in lanis-mobile (`liblanis/lib/src/session/cryptor.dart`). The
biggest lift on this list; parents would get teacher messages natively,
with notifications. Start from liblanis's cryptor + conversations parser.

## Fehlzeiten / attendance for parents
The per-course pages (`meinunterricht.php?a=sus_view&id=…`) carry
attendance records the app doesn't read. A quiet "Anwesenheit" section is
exactly what a parent account is for. Capture a masked structure dump of a
`sus_view` page first (Tools/dump-structure.user.js).

## Multi-account switching
One app, two profiles: pupil and parent account (or two kids). Needs
per-account cookie jars, keychain entries and snapshots — and it would
*prevent* the SPH one-session-per-account fights documented in
`SPHClient.looksLikeErrorPage`. Model on lanis-mobile's account switcher.

## Live Activity
Current lesson as a Live Activity ticking through the school day. Fun, low
practical value; needs ActivityKit plumbing in the widget target. Do after
the widgets have proven themselves.

## Widget deep links
`widgetURL` → open the matching tab (Aufgaben from the Heute widget, Essen
from the Mensa widget). Needs a tiny URL scheme + tab selection state in
`RootView` — the tabs currently have no programmatic selection.
