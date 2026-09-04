# Schulpaket — the offer for schools

*What it is, why it exists, and the one-page text to send. Sold by
invoice, outside the App Store: no Apple cut, no IAP review.*

## Why

The registry makes schools "data, not code": mensa tenant, links, icon.
That configuration is the product. A school (Förderverein, SV or
Schulleitung) pays a small yearly amount to be fully set up and to give
its pupils Pro — instead of hundreds of parents buying it one by one.
Ten schools cover more than the tip jar ever will, and every school in
the registry makes the app better for the next one.

## What the school gets

| Included | How |
|---|---|
| Entry in the registry: name, mensa, links, Jahresterminplan | `schools.json` |
| Own app icon (own design in school colours, or the crest with consent) | `iconName` + consent form |
| Ranzen Pro for all pupils and parents of the school | App Store **offer codes**, one batch per school year, handed out by the school |
| Named contact for problems ("the app broke after the portal update") | e-mail, 2 working days |
| Mention on the school's page in the app ("Ermöglicht durch den Förderverein") | optional, registry field |

Not included: any change to what the app does for that school alone.
One app, every school — a feature ships for all or not at all.

## Price

| Size | Price / school year |
|---|---|
| bis 500 Schüler | 150 € |
| bis 1 200 Schüler | 250 € |
| darüber | 300 € |

Invoice once a year, in September. First year cancellable within 30
days. No auto-renewal: a reminder in June, the school decides.

Offer codes: one-time codes for the yearly Pro subscription, 12 months
free, generated in App Store Connect (Subscriptions › Offer Codes,
custom codes or one-time codes). Apple allows 150 000 codes per app per
quarter — plenty. Pupils redeem at apps.apple.com/redeem or in the App
Store. Family Sharing then covers siblings.

## The page to send (German)

---

**Schulpaket für [Schulname]**

Die Schulportal-App für iOS macht aus dem Schulportal Hessen eine
Hausaufgaben-Liste zum Abhaken, einen Stundenplan im Kalender, Vertretungen
und Termine auf einen Blick — und bei Schulen mit menuebestellung.de auch
Speiseplan und Guthaben. Kostenlos, ohne Werbung, ohne Tracking, alle Daten
bleiben auf dem Gerät.

Mit dem Schulpaket ist Ihre Schule in der App vollständig eingerichtet:

- **Ihre Schule, fertig konfiguriert:** Mensa, Links zu Elternbeirat,
  Förderverein, Terminen und Neuigkeiten — direkt in der App.
- **Ihr eigenes App-Symbol** in den Schulfarben (oder mit Ihrem Logo,
  mit Ihrer Einwilligung).
- **Ranzen Pro für alle:** Codes für alle Schülerinnen, Schüler und
  Eltern — Aufgaben-Widget mit Abhaken, Tagesplan, Ferien-Countdown,
  Siri-Abfrage, eigene Erinnerungszeiten.
- **Ein Ansprechpartner,** wenn etwas nicht funktioniert.
- Auf Wunsch: „Ermöglicht durch den Förderverein der [Schule]“ in der App.

**Preis:** [150 / 250 / 300] € pro Schuljahr, per Rechnung. Keine
automatische Verlängerung, im ersten Jahr 30 Tage Rücktrittsrecht.

Die App ist ein privates, inoffizielles Angebot und kein Produkt des
Hessischen Kultusministeriums. Sie nutzt ausschließlich die Zugänge, die
Ihre Schülerinnen und Schüler ohnehin haben.

Kontakt: Dmitry Baklashev, *[E-Mail]*

---

## Internal checklist per school

- [ ] Registry entry (`schools.json`) — name, mensaTenant, links, iconName.
- [ ] Icon: own design, or crest with signed `SCHULLOGO-EINWILLIGUNG.md`.
- [ ] Offer code batch in App Store Connect, valid 12 months, count = pupils + parents.
- [ ] Invoice sent, paid.
- [ ] Release with the entry; tell the school the version number.
- [ ] June: renewal mail.
