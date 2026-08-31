# Architecture

```
        WKWebView (login)          WKWebView (Portal tab)
               │                            │
               │ cookies                    │ userscript injected
               ▼                            ▼
       HTTPCookieStorage.shared   ────►  same session
               │
               ▼
          SPHClient (actor)  ── GET/POST ──►  start.schulportal.hessen.de
               │
               ▼
          PortalService          fetch + parse, one method per page
               │
     ┌─────────┴──────────┐
     ▼                    ▼
MeinUnterrichtParser  StundenplanParser        (SwiftSoup)
     │                    │
     └─────────┬──────────┘
               ▼
          AppModel  (@MainActor @Observable)   ← the single source of truth
               │                    │
     SnapshotStore (actor)     CalendarSync (EventKit)
       JSON on disk                 │
                                    ▼
                          "Stundenplan (Schulportal)"
```

## Layers

**`Networking/SPHClient`** — an actor wrapping one `URLSession` that shares
`HTTPCookieStorage.shared` with the web views. It knows three things beyond
plain HTTP: how to decode the portal's occasional Latin-1 pages, how to
recognise being bounced to the login wall (`SPHError.notLoggedIn`), and — when
the user stored credentials — how to answer that bounce itself: it speaks the
login form's own POST (`user`/`user2`/`password`, then
`connect.schulportal.hessen.de` hands out the `sid`) and retries once, exactly
the way `MensaClient` does. Only without stored credentials, or when the portal
rejects them (`SPHError.invalidCredentials`), does the signal propagate all the
way up to showing the login screen again.

**`Networking/SchoolDirectory`** — the public school list behind the login
page's own picker, so a school can be chosen by name instead of by number. The
one call that happens before there is a session, and therefore the one that must
*not* go through `SPHClient`: that client turns a redirect to the login host
into `.notLoggedIn`, which is exactly the state the caller is trying to leave.
Its own ephemeral session, no shared cookies, cached for the app's lifetime.

**`Networking/PortalService`** — the seam between "HTTP" and "domain". One
method per portal page; swapping a parser or adding a page touches nothing else.

**`Parsing/`** — pure functions, `String` in, model out. No networking, no state,
no side effects, so they can be exercised against saved HTML. `HTMLText`
exists because `Element.text()` collapses newlines and homework blocks are
multi-line.

**`Storage/AppModel`** — `@MainActor @Observable`. Owns the `Snapshot`, decides
what "done" means (see below), and is the only thing views talk to.

**`Storage/SnapshotStore`** — an actor doing atomic JSON writes into Application
Support. A decoding failure after a schema change resets rather than crashes.

**`CalendarSync`** — EventKit. Deliberately isolated: it is the only code that
writes outside the app's own container.

## The mensa is a second, parallel stack

`menuebestellung.de` is a different company, a different account and a different
session. It gets its own column rather than a corner of the existing one:

```
        MensaLoginView                    MensaKeychain
             │                          (device-only, no iCloud)
             │ username + password              │
             ▼                                  ▼
        MensaClient (actor)  ── ephemeral URLSession, private cookie jar ──►
             │                                     www.menuebestellung.de
             │  signs itself back in on .notLoggedIn, once, silently
             ▼
        MensaService          fetch + parse, one method per page
             │
     ┌───────┴────────┐
     ▼                ▼
SpeiseplanParser   MensaStatementParser    (SwiftSoup / MensaJSON)
     │                ▼
     └───────┬────────┘
             ▼
        MensaModel  (@MainActor @Observable)   ← nothing persisted to disk
```

Four decisions worth knowing:

* **Its own cookie jar.** The configuration is `ephemeral`, so the session lives
  in a private in-memory store. `SPHCookies.clearAll()` wipes
  `HTTPCookieStorage.shared` wholesale on Schulportal sign-out, and it must not
  take the mensa session with it.
* **It holds a password.** The site has no SSO and no login page worth
  embedding, so a web view would buy nothing and cost a login screen every time
  the session dropped. The credentials go into the Keychain as
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and `MensaClient` re-signs
  in on its own. Only a *rejected credential* reaches `MensaModel` and sends
  the user back to the login screen; an expired session never does. (This was
  the mensa's invention; the Schulportal side has since adopted the same
  pattern as its optional native login, with the browser login remaining the
  password-free route for SSO/2FA accounts.)
* **Nothing is cached to disk.** The plan changes weekly and the balance changes
  hourly. A stale balance read out of a snapshot would be worse than an empty
  screen, so there is no `SnapshotStore` equivalent here.
* **The two halves of the tab fail separately.** `speiseplan.php` carries the
  menu *and* the balance, so it alone fills the screen; the account statement is
  the extra detail behind „Kontoauszug“. `MensaModel` therefore keeps
  `weekErrorMessage` and `statementErrorMessage` apart — only the first earns a
  banner over the tab. A warning on a screen that is otherwise correct, about
  something the reader cannot act on, only teaches them to ignore warnings.

It is read-only. `speiseplan.php` would take a `POST` with `csrftoken`,
`submit_bestellung` and one `menue_<DAY>_0` per day — that is how an order is
placed — and the app deliberately does not send it.

## The one interesting decision: who owns "done"

Two sources disagree constantly — the portal's own flag, and what the user just
tapped. The rule is:

```
isDone(homework) = doneOverrides[homework.id]?.isDone ?? homework.isDoneOnPortal
```

The local override always wins in the UI, so a tap is instant and survives a
dead network, a rejected POST, or an entry the portal exposes no ids for. Every
override records `syncedToPortal`.

On each refresh (`reconcileOverrides`):

* override synced **and** the portal now agrees → drop the override, the portal
  has caught up;
* override synced but the portal **disagrees** and the override is older than a
  week → drop it, someone changed it in the browser since;
* override not synced → keep it and retry the POST.

Overrides for homework nobody can see any more are pruned so the file cannot
grow forever.

## Why homework is archived

*Mein Unterricht* only lists roughly the last two weeks. Homework that falls out
of that window while still open would simply vanish — the worst possible failure
for the one feature the app exists for. So on every refresh, previously known
open homework that is no longer in the scrape is moved to
`Snapshot.archivedHomework` (pruned after 90 days) and keeps showing up in the
list.

## Why the timetable is written as individual events

A recurrence rule is smaller but wrong: timetables change during the year, and
untangling exceptions from a rule is far more code than rewriting a four-week
window. Every sync deletes the app's events in the window and rewrites them, so
the calendar always matches the last scrape.

## Ids must be stable

Anything persisted (homework overrides, archived items) is keyed by an id that
must survive app restarts. Where the portal gives one (`data-entry`) it is used.
Otherwise the id is an FNV-1a hash of course + date + text — **not**
`String.hashValue`, which is seeded per process and would silently lose every
tick on relaunch.
