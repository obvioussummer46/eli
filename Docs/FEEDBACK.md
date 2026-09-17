# Feedback

How the app collects feedback, and why it is one mail address and not a
form, a server or an SDK.

## The channel

- **Mehr › Über › „Feedback senden“** opens Mail with a draft to
  `hello@bittel.app` (`Feedback.address`). Subject and body are prefilled;
  the user reads the draft and decides whether to send it.
- **Mehr › Meine Schule › „Inhalte für meine Schule ergänzen“** appears
  only for schools without a profile in the registry
  (`Resources/schools.json`, bundled with the app).
  Same address, a subject that sorts on its own, and a body that asks for
  what a profile needs — website, mensa tenant, pages worth linking — and
  says every field is optional. It never says the school is *missing*:
  every Hessen school logs in and gets its timetable; a profile only adds
  mensa, links and icon. (A beta tester once read the old „Meine Schule
  fehlt“ mail as „the app cannot find my school“ — it could.)
- **TestFlight** carries its own screenshot feedback into App Store
  Connect. Nothing in the app needs to change for that.

## What the draft carries

Every draft ends with four lines the user can delete before sending:

```
Schule: Elisabethenschule Frankfurt (Schulnummer 5102)
Schulprofil hinterlegt: ja
App: 1.0 (7)
iOS: 26.0, iPhone15,2
```

„Schulprofil hinterlegt“ is `SchoolRegistry.entry(for:) != nil` — whether
the registry has an entry for the Schulnummer, nothing more. Today that is
one school; every other school in the directory says „nein“, and that is
the normal state, not a bug.

No account name, no timetable, no credentials. The builder is
`Feedback.body(for:context:)`, covered by `FeedbackTests`.

## Why not more

- No feedback SDK: the privacy promise is "the developer receives no data
  from you", and a mail the user sends themselves keeps that literally true.
- No in-app form: it would need a backend, and Mail already has a Sent
  folder both sides can rely on.
- No automatic diagnostics: anything the four lines cannot explain is a
  conversation, and a reply-to address is exactly that.

## Turning mail into registry entries

An „Inhalte für meine Schule“ mail is the input for a one-entry PR to
`schools.json` (see `Docs/SCHULPAKET.md` for what a school may get and
`Docs/SCHULLOGO-EINWILLIGUNG.md` before shipping a school's icon). Once
merged to `main` the entry is live: the app fetches
`SchoolRegistry.remoteURL` at launch, caches the file in Application
Support and falls back to the bundled copy. No release needed — the icon
is the one exception, because an appiconset must ship in the binary.
