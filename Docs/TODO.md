# Ideas parked for later

Review each before building — the context below is from the September 2026
debugging sessions and may age.

## Unterstützer: cosmetics for supporters (the chosen monetisation, if any)

Decided, not yet built. All utility — widgets, notifications, digest —
stays free forever; paying is gratitude, not access. One "Unterstützer
werden" screen with pay-what-you-want consumable IAP tiers (3/5/10 €,
optionally a yearly), unlocking a gratitude bundle: alternate app icons,
accent-colour themes, maybe a supporter quote pack and confetti when the
last homework is ticked. Family Sharing ON so one parent purchase covers
the kid's phone. Requires the paid developer account + App Store Connect
banking/tax setup; Apple's small-business rate is 15 %. Explicitly
rejected: paid/sponsor-gated widgets (paywalling a child's timetable, and
it creates paying customers for the most breakage-prone surface) and
subscriptions (maximum parental resistance for minimum money). A
Ko-fi/GitHub-Sponsors link belongs in the README regardless — outside the
app, Apple has no say.

## Schul-News (Elternbeirat, Förderverein, Aktuelles)

Parse the school website's news into the app — public pages, no login, so
an ephemeral fetch like `SchoolDirectory`. Recon (Sept 2026): the
Elisabethenschule site runs **Contao CMS**, no RSS, but cleanly
structured: `eli-news.html` is the list, articles live under
`eli-news-lesen/<slug>.html`, and `schulelternbeirat.html` /
`foerderverein.html` / `termine.html` exist as stable pages. Build it
generically: a per-school "news source" (URL + parser hint, WordPress
`/feed` autodiscovery for the many schools that have it, a Contao list
parser as the second dialect), surfaced as a card on Heute ("Neues von
der Schule") or a section in Mehr. School-specific knowledge goes into
the per-school config registry below, not into code.

## Quick links per school (Hort, Elternbeirat, Förderverein …)

The cheap sibling of Schul-News: a configurable "Meine Schule" link list
in Mehr (Hort info page, Elternbeirat, Förderverein, Jahresterminplan),
opening in the styled in-app browser. Ship Eli's links as the first
registry entry; let users add their own.

## Per-school configuration registry (the one-app decision)

Decision: **one Hessen-generic app, no Eli fork.** Everything
school-specific becomes *data, not code*: a small bundled JSON keyed by
Schulnummer — mensa tenant, news source, quick links — with Eli (5102) as
the first fully configured school and a "configure your own" path for
everyone else. A separate Eli app would double maintenance for zero gain;
the registry gives Eli families the tailored experience inside the
general app, and other schools can be added by a one-entry PR.

## Flohmarkt — recommended against (in this app)

A kids' marketplace needs what this app deliberately does not have: a
server, accounts, and content between children — which means moderation
duty, GDPR for minors, and liability, run from a private repo. That is a
product, not a feature. If the school community wants a Flohmarkt, the
Förderverein's existing channels (or a moderated Elternbrief board) are
the right home; the most this app should ever do is *link* to one.

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

## Make the Essen tab optional
The tab is hardwired to the ASB tenant on menuebestellung.de
(`MensaEndpoints.tenant`). A school with a different caterer — or none —
gets a permanently useless tab that makes the whole app feel broken.
Needed: a setting to hide the tab entirely, and ideally a tenant picker
(the tenant list is public on menuebestellung.de's Systemauswahl page) so
other ASB-style schools work too. Widgets/digest must degrade with it.

## Widget deep links
`widgetURL` → open the matching tab (Aufgaben from the Heute widget, Essen
from the Mensa widget). Needs a tiny URL scheme + tab selection state in
`RootView` — the tabs currently have no programmatic selection.
