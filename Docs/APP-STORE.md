# App Store Connect — everything to paste

Ready-to-paste texts and settings for the paid release. Character limits
are Apple's; every text below is under them.

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

## App information

- **Name (30):** Schulportal — Hausaufgaben & Plan
- **Subtitle (30):** Aufgaben, Stundenplan, Mensa
- **Category:** Education. Secondary: Productivity.
- **Age rating:** 4+. No ads, no user content, no web access beyond the
  in-app browser for the portal and school links (declare "Unrestricted
  Web Access: No" — the browser is limited to the portal and configured
  school links).
- **Privacy policy URL:** `Docs/DATENSCHUTZ.md` on GitHub (repo must be
  public, or host the file elsewhere).
- **Support URL:** the GitHub repo or a mailto page.

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
Ruhe lässt.

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

## What's new (first paid release)

Neu: Ranzen Pro — Aufgaben-Widget mit Abhaken, Tagesplan-Widget,
Ferien-Countdown, App-Symbole, eigene Erinnerungszeiten, Export und
Siri. Die App bleibt kostenlos; wer mag, gibt unter „Mehr“ einen Kaffee
aus.

## App Review notes

```
Demo account
  School: [Schulname, Schulnummer]
  Username: [demo user]
  Password: [password]
  (The account is a real pupil account provided with consent; it sees
  Mein Unterricht, Stundenplan, Vertretungsplan and Kalender.)

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
  (Mehr › Ranzen Pro freischalten).

Alternate icons
  Mehr › App-Symbol. "Eli" is our own design in the school's colours,
  not the school's crest.

Background
  Uses BGAppRefreshTask to refresh the same pages the user sees; no
  push, no server.
```

## Privacy nutrition label (App Privacy)

Answer "Do you or your third-party partners collect data from this
app?" with **No**. Rationale: everything stays on device; the portal and
the caterer are services the user logs into themselves, not the
developer's collection; StoreKit purchase data is Apple's. If Apple's
questionnaire pushes back, the only category that could apply is
*Purchases → Purchase History*, "used for app functionality, not linked
to identity, not used for tracking".

## Before submitting

- [ ] App Store Small Business Program enrolled.
- [ ] Paid Applications agreement signed, tax and banking filled.
- [ ] `StoreLinks.privacy` resolves publicly.
- [ ] Contact details filled in `Docs/DATENSCHUTZ.md` §1 and §8.
- [ ] Demo account in review notes works from outside the school network.
