# Feedback

How the app collects feedback, and why it is one mail address and not a
form, a server or an SDK.

## The channel

- **Mehr › Über › „Feedback senden“** opens Mail with a draft to
  `catchr@icloud.com`. Subject and body are prefilled; the user reads the
  draft and decides whether to send it.
- **Mehr › Meine Schule › „Meine Schule eintragen lassen“** appears only
  for schools the bundled registry (`Resources/schools.json`) does not
  know. Same address, a subject that sorts on its own, and a body that
  asks for exactly what a registry entry needs: the school's website, the
  mensa tenant, the pages worth linking.
- **TestFlight** carries its own screenshot feedback into App Store
  Connect. Nothing in the app needs to change for that.

## What the draft carries

Every draft ends with four lines the user can delete before sending:

```
Schule: Elisabethenschule Frankfurt (Schulnummer 5102)
In der App eingetragen: ja
App: 1.0 (7)
iOS: 26.0, iPhone15,2
```

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

A „Meine Schule fehlt“ mail is the input for a one-entry PR to
`schools.json` (see `Docs/SCHULPAKET.md` for what a school may get and
`Docs/SCHULLOGO-EINWILLIGUNG.md` before shipping a school's icon).
