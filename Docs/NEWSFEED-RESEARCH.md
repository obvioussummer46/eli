# Schul-News: auto-configuration research (31.08.2026)

Research for Plan item **1.3 Schul-News** — can the news source for the
"Neues von der Schule" card be configured *automatically* for any school,
or does every school need a hand-made entry that breaks whenever a
webmaster redesigns their site?

**Verdict up front: it is not one or the other — it is three tiers.**

1. **~⅔ of school websites can be configured automatically and stably.**
   Of the 49 surveyed schools whose CMS could be identified, 31 (63 %)
   run WordPress, where a standards-compliant RSS feed exists at `/feed/`
   *by default* — no per-school selectors, no HTML parsing, nothing that a
   redesign can break short of a full CMS migration. Jimdo and Wix (not
   seen in the sample, common among small schools) also ship feeds by
   default at fixed URLs.
2. **The discovery chain itself can be automatic.** The Schulnummer the
   app already stores is the state-wide canonical school id: the
   Hessische Schuldatenbank exposes a labeled **Homepage** field at
   `schul-db.bildung.hessen.de/schul_db.html/details/?school_no=<NR>`,
   and the jedeschule.de project republishes exactly that scrape as a
   weekly CSV/API (`jedeschule.codefor.de`, `website` column). From the
   homepage, standard RSS autodiscovery (`<link rel="alternate"
   type="application/rss+xml">` in the HTML head) finds the feed for
   *every* CMS that has one enabled — including TYPO3/Contao sites whose
   feed URLs are otherwise unguessable. So `Schulnummer → homepage →
   feed` needs **zero manual settings** for the RSS tier.
3. **The rest needs parsing, but per-*CMS*, not per-school.** Joomla
   (9/49), Contao (3/49, including the Eli itself), TYPO3 (2/49) and a
   few static/hand-made sites have no feed unless the operator enabled
   one. These need HTML parsing of the news list page — but Joomla and
   Contao emit standardized markup (`com_content` views;
   `mod_newslist`/`layout_latest` classes), so one parser dialect per
   CMS covers the tier. Only truly hand-made sites (~8 % of the sample)
   are per-school work, and they degrade gracefully: no news card, or a
   user-pasted URL.

So the planned architecture (registry preconfigured for the Eli, RSS
autodiscovery for everyone else, manual URL as the floor) is confirmed —
with one upgrade: the registry does not have to be hand-grown one PR at a
time. It can be **generated** by a script joining the SPH school list
with the Schuldatenbank homepage column and probing each site once.

---

## Method — and what this research is *not*

The research environment's network policy blocked all direct fetching
(both `curl` and the sandbox fetch tool were denied by the egress proxy
for every school domain). Everything below therefore comes from
**search-index evidence**: `site:` queries, indexed URLs, and page
snippets — plus source-code reading of nine open-source Schulportal
clients for the endpoint facts. Consequences:

* CMS identification is from URL fingerprints (`wp-content/…` asset hits,
  `/index.php?id=NNN`, `com_content`, `…html` news slugs), each row
  carries a `cms_confidence`, and `high` means an unambiguous fingerprint
  was indexed — not that the site was fetched.
* Every `feed_url_candidate` is an **unverified guess** derived from the
  CMS default. Nothing here was confirmed live.
* Before building on this, run a one-evening probe from a normal network:
  for each row in the dataset below, fetch the homepage, read the real
  autodiscovery links, and record the actual feed URL and HTTP status.
  That turns this document's *expected* tiers into *known* ones.

Sample: 60 schools across all six Schulamt regions — Frankfurt (10),
Wiesbaden + Darmstadt (10), Nordhessen incl. rural Kreise (10),
Mittelhessen/Osthessen (10), Südhessen suburbs/rural (10), and an
under-represented-types slice (4 Grundschulen, 3 berufliche Schulen,
3 Förderschulen). Selection was "real schools verifiable by search", not
random — small schools with weak websites are likely *under*-represented,
so treat the automatic-tier share as an upper bound for the long tail.

## Schulnummer → website: the data sources

| Source | What it gives | Access | Caveats |
|---|---|---|---|
| `startcache.schulportal.hessen.de/exporteur.php?a=schoollist` | Every SPH school: `Id` (= Schulnummer) + `Name` + `Ort`, grouped by Schulamt | JSON, no auth — the app already uses it (`SchoolDirectory`) | **No homepage field.** Enumeration + validation only |
| `schul-db.bildung.hessen.de/schul_db.html/details/?school_no=<NR>` | Address, email (`poststelle<NR>@schule.hessen.de`), **Homepage**, Schulform, Träger | HTML page per school; same Schulnummer keying confirmed (Eli = 5102 in both systems) | Scraping HTML; the Homepage field can be **stale** — Eli's entry still lists `elisabethen.frankfurt.schule.hessen.de`, not `elisabethenschule.net` |
| `jedeschule.codefor.de` (`/csv-data/schools.csv`, API at `/docs`) | The Schuldatenbank already scraped: `website` column keyed by state-prefixed id (Hessen rows expected as `HE-<school_no>`) | CSV updated weekly + HTTP API, redistributable | Third-party project; freshness inherits the Schuldatenbank's staleness; `HE-` prefix format inferred from docs, not spot-checked |

Practical shape: a **build-time script** (not the phone) joins schoollist
× Schuldatenbank/jedeschule, validates each homepage (follow redirects —
the stale `*.schule.hessen.de` entries often redirect to the current
domain), probes for a feed, and emits `Resources/schools.json` rows. The
app never scrapes the Schuldatenbank itself; unlisted schools fall back
to in-app autodiscovery from a user-entered homepage.

## CMS landscape and what each means for the feed

Share figures: this survey's 49 CMS-identified schools; feed behavior
verified against each platform's current documentation.

| Platform | Sample share | Feed by default? | URL pattern | Detection |
|---|---|---|---|---|
| **WordPress** | 31/49 (63 %) | **Yes, always on** | `/feed/` (or `/?feed=rss2` on query-string permalinks) + head autodiscovery link | `wp-content`/`wp-json` anywhere in markup or asset URLs |
| **Joomla** | 9/49 (18 %) | Capability yes, surfaced no — per list view | append `?format=feed&type=rss` to the news/category list URL | `com_content`, `index.php?option=`, `Itemid=` in URLs |
| **Contao** | 3/49 | **Off by default**, opt-in per news archive | generated under `/share/<operator-chosen-name>.xml` — not guessable, only autodiscovery finds it | `….html` page aliases, `news-lesen/`-style detail slugs; news list markup `mod_newslist`/`layout_latest` |
| **TYPO3** | 2/49 | **Off by default**, needs the `news` extension + operator TypoScript | no fixed pattern (`?type=<num>`), only autodiscovery | `typo3conf/`, `typo3temp/`, `index.php?id=NNN` |
| Static / hand-made / Bildungsserver platform | 4/49 | No | — | `*.schule.hessen.de` hosting = the Bildungsserver's free Schulhomepage service (one shared platform → one parser could cover all of them); otherwise nested `.html` with no CMS artifacts |
| Jimdo / Wix | 0 in sample, common nationally | Yes (blog) | `/rss/blog/` (Jimdo), `/blog-feed.xml` (Wix) | `jimdo`/`wixstatic` asset hosts |
| IServ homepage module | 0 in sample | Off by default, per category, may be key-protected | admin-configured, no public pattern | `/iserv/` paths |

Context numbers: SPH claims **1 800+ schools**; schulhomepage.de's
webmaster survey (757 self-selected respondents nationally) reports
**33 % of school sites run no CMS at all** — a reminder that the long
tail of tiny schools is worse than this Gymnasium-heavy sample.

## Survey result

Of 60 schools: 49 CMS identified, 11 unknown (search-budget limits or
thin indexing — flagged per row, not evidence of absence).

| Tier | Count | Meaning |
|---|---|---|
| `rss-auto` | 13 | WordPress with pretty permalinks and (in several cases) an actually indexed `/feed/` — highest confidence |
| `wordpress-likely` | 18 | WordPress confirmed, feed expected at default URL but not seen in the index |
| `custom-parser-needed` | 22 | Joomla/Contao/TYPO3/static — no default feed; needs the probe (`?format=feed`) or a per-CMS list parser |
| `unknown` | 7 | Site found but CMS unresolved; needs the live probe |

Notable single findings:

* **Elisabethenschule (5102)** — Contao, and a targeted search for any
  feed on `elisabethenschule.net` found none. The plan's assumption
  holds: the Eli needs the Contao list-page dialect
  (`eli-news.html` → `eli-news-lesen/<slug>.html`). The one comfort:
  Contao's news list markup is module-generated, so the dialect can key
  on Contao's own classes instead of Eli-specific selectors.
* Two sampled schools live on the Bildungsserver's own hosting
  (`goethe.kassel.schule.hessen.de`, `gs.ahnatal.schule.hessen.de`) —
  one shared platform, so one parser (or a polite "no news card") covers
  every school on it.
* WordPress is not always at the domain root: `grimmels.de/wordpress/`,
  `kks-offenbach.de` under `/wpdata/`, `musterschule.de` serving posts
  from `infos.musterschule.de` — autodiscovery from the *homepage HTML*
  handles all of these; guessing `<domain>/feed/` alone does not.
* Städtische Träger (Frankfurt, Wiesbaden, …) run **directories, not
  hosting** — there is no city-wide CMS to exploit; every school picks
  its own platform.

## Recommended configuration cascade

Ordered so that each step is strictly cheaper and more stable than the
next; stop at the first hit. Steps 1–3 need no per-school data at all.

```text
newsSource(for schulnummer, homepage?):
  0. Registry entry in schools.json  ................... curated, wins always
  1. homepage ← registry / Schuldatenbank / user input
     (validate: follow redirects, upgrade to https, reject dead hosts)
  2. GET homepage → <link rel="alternate" type="application/rss+xml"
     or atom+xml> in <head>  .......................... covers WP, Jimdo, Wix,
                                                        and TYPO3/Contao/Joomla
                                                        sites that enabled feeds
  3. Probe well-known paths (HEAD/GET, accept only real XML feeds):
     /feed/ · /?feed=rss2 · /rss/blog/ · /blog-feed.xml
  4. Find the news list page (nav links matching Aktuelles|News|
     Neuigkeiten|Nachrichten) and:
       a. Joomla fingerprint → retry list URL + ?format=feed&type=rss
       b. Contao fingerprint → mod_newslist/layout_latest list parser
       c. TYPO3 fingerprint  → news-extension list parser (best effort)
  5. Nothing → no news card; Settings offers manual URL entry
     (a pasted URL re-enters the cascade at step 1).
```

Design notes:

* **Feed-first is also break-resistant.** RSS/Atom is a frozen format;
  a WordPress feed survives every theme change. The fragile tier is only
  step 4 — and even there, a dialect keyed to CMS module markup breaks
  far less often than per-school CSS selectors.
* **Self-healing:** cache the *resolved* feed URL but re-run the cascade
  whenever it starts failing (404, HTML instead of XML). A redesign that
  moves the feed then fixes itself on the next refresh instead of
  needing a registry PR.
* Fetching stays exactly as planned: public pages, ephemeral session,
  never through `SPHClient`; be polite (conditional GET / `ETag`, one
  refresh per app-refresh, not per view).
* `schools.json` rows stay tiny: `newsSource` can be
  `{"type":"rss","url":…}` or `{"type":"contao-list","listURL":…}` —
  the cascade only runs when the registry has nothing.

## What can break, and how badly

| Failure | Tier hit | Blast radius | Mitigation |
|---|---|---|---|
| School redesigns site, same CMS | RSS tier: none. Parser tier: likely | one school | cascade re-run (self-heal); dialect parsers key on CMS markup |
| School migrates CMS (e.g. Joomla → WP) | any | one school | cascade re-run usually *improves* the tier |
| Homepage domain changes | discovery | one school | Schuldatenbank refresh + redirect following; user override |
| Schuldatenbank stale / wrong (seen: Eli) | discovery | per school | validate at generation time; never trust without a 200 + redirect chain |
| jedeschule project dies | build tooling | none at runtime | it is a convenience mirror; the Schuldatenbank itself remains |
| Contao/Joomla major version changes list markup | parser tier | all schools of that CMS | one dialect fix, shipped as data/app update — same maintenance class as the SPH parsers the app already owns |

## Dataset

The full survey data, one object per school. Reminder: `cms` is inferred
from search-index fingerprints (`cms_confidence`, `cms_evidence`);
`feed_url_candidate` is the *expected* URL per CMS defaults, unverified;
`auto_configurable` is the tier estimate under the cascade above.
Suitable as the seed/test-fixture list for the registry generation
script — after the live probe pass.

```json
{
 "surveyed": "2026-08-31",
 "method": "search-index evidence only (no live fetches); see NEWSFEED-RESEARCH.md",
 "schools": [
  {
   "region": "Frankfurt",
   "name": "Elisabethenschule",
   "city": "Frankfurt am Main",
   "school_type": "Gymnasium",
   "website": "https://www.elisabethenschule.net/",
   "cms": "contao",
   "cms_confidence": "medium",
   "cms_evidence": "News pages use '.html' file-style URLs (e.g. kollegium.html, termine.html) and a Contao-typical archive URL 'news-archiv-lesen.html?month=202006' on the sibling elisabethenschule.de domain; matches the task's Contao heuristic ('news-lesen/...html'). No wp-content, no ?id= TYPO3 pattern found.",
   "news_url": "https://www.elisabethenschule.net/",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "Two related domains surfaced: elisabethenschule.net (homepage branded 'Eli News', has Kollegium/Termine pages) and elisabethenschule.de (hosts news-archiv-lesen.html). The Hessen state directory instead points to elisabethen.frankfurt.schule.hessen.de, a thinner official mirror. Likely all controlled by the same school; the .net/.de site is the richer public-facing news source. Recommend a manual check to confirm the canonical domain before shipping a parser."
  },
  {
   "region": "Frankfurt",
   "name": "Musterschule",
   "city": "Frankfurt am Main",
   "school_type": "Gymnasium",
   "website": "https://www.musterschule.de/ (content served from https://infos.musterschule.de/)",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Confirmed wp-content/uploads paths (PDFs, mp3/mp4/m4a files) plus classic WP query URLs ?p=NNNNNN and ?page_id=NNN across infos.musterschule.de.",
   "news_url": "https://infos.musterschule.de/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://infos.musterschule.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Site does not use WP pretty permalinks (still on ?p=/?page_id= query form), so /feed/ should still work as the default WordPress feed endpoint, but this should be verified once network access is available."
  },
  {
   "region": "Frankfurt",
   "name": "Ziehenschule",
   "city": "Frankfurt am Main",
   "school_type": "Gymnasium",
   "website": "https://www.ziehenschule.de/",
   "cms": "contao",
   "cms_confidence": "medium",
   "cms_evidence": "URL pattern is folder/category + slug + '.html' (e.g. /schule/schulgemeinde/verein-der-freunde-und-foerderer.html, /news/unterwegs-im-rechtschreibdschungel.html, /unterricht.html) with no ?p= or index.php?id= — classic Contao alias+.html structure, not WordPress or TYPO3.",
   "news_url": "https://www.ziehenschule.de/schule.html",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "Main school site is Contao-style static-looking pages; a separate WordPress-powered student newspaper blog exists at schuelerzeitung.ziehenschule.de (has its own /feed) but that is student journalism content, not the official school news feed."
  },
  {
   "region": "Frankfurt",
   "name": "Lessing-Gymnasium",
   "city": "Frankfurt am Main",
   "school_type": "Gymnasium",
   "website": "https://lessing-frankfurt.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Direct wp-content/uploads/2025/02/... PDF found, plus WP-style hierarchical pretty-permalink slugs (/unterricht/faecher/fb-i/englisch/, /zeitzeugenbericht-von-eva-szepesi-am-04-11-2024/).",
   "news_url": "https://lessing-frankfurt.de/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://lessing-frankfurt.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Note: search results also surfaced an older/alternate domain www.lessing-ffm.de and the Hessen mirror lessing-gym.frankfurt.schule.hessen.de; lessing-frankfurt.de is the actively updated WordPress site with 2024-2026 posts."
  },
  {
   "region": "Frankfurt",
   "name": "Helene-Lange-Schule",
   "city": "Frankfurt am Main",
   "school_type": "Gymnasium",
   "website": "https://hela-frankfurt.de/",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Only a clean trailing-slash URL was confirmed (/fuer-schueler/unterrichtszeiten/), which is compatible with WordPress pretty permalinks, TYPO3 realurl, or a custom CMS. Web-search budget was exhausted before a wp-content or index.php?id= check could confirm which.",
   "news_url": "https://hela-frankfurt.de/",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "unknown",
   "notes": "School also runs a separate history microsite at damals.hela-frankfurt.de. CMS identification incomplete — needs a follow-up site: query for wp-content/index.php?id= once search budget resets."
  },
  {
   "region": "Frankfurt",
   "name": "Carl-Schurz-Schule",
   "city": "Frankfurt am Main",
   "school_type": "Gymnasium",
   "website": "https://carl-schurz-schule.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Flat WP-style post slugs (/vorschau-2/, /sortie-annuelle-au-cinema-cinefete-2024/, /wettbewerb-der-fachschaft-powi/, /informatik-abseits-der-klischees/) and a search hit explicitly noting wp-content theme resources.",
   "news_url": "https://carl-schurz-schule.de/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://carl-schurz-schule.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "An additional/legacy CMS backend was referenced at cms.carl-schurz-schule.de; the public-facing carl-schurz-schule.de is the WordPress front end to target."
  },
  {
   "region": "Frankfurt",
   "name": "IGS Nordend",
   "city": "Frankfurt am Main",
   "school_type": "Integrierte Gesamtschule (IGS)",
   "website": "https://igs-nordend.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Confirmed wp-content/uploads/2025/01/... PDF plus clean pretty-permalink page (/unsereschule/). Older indexed URLs use a Joomla-style index.php/quicklinks/NNN-slug pattern, indicating the site was migrated to WordPress from a prior Joomla installation and old URLs are still indexed/cached.",
   "news_url": "https://igs-nordend.de/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://igs-nordend.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Legacy Joomla-pattern URLs (e.g. index.php/quicklinks/227-...) still appear in search results and likely 404 or redirect; the live site is WordPress."
  },
  {
   "region": "Frankfurt",
   "name": "Schule am Ried",
   "city": "Frankfurt am Main",
   "school_type": "Kooperative Gesamtschule mit gymnasialer Oberstufe",
   "website": "https://www.schule-am-ried.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Date-based permalink structure typical of default WordPress post URLs (/2020/03/die-jugendhilfe-ist-fuer-euch-da/, /2014/07/schule-am-ried-verabschiedet-erfolgreiche-abiturienten/, /2022/07/der-besuch-des-zeitzeugens-sonny-sonneberg-...).",
   "news_url": "https://www.schule-am-ried.de/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://www.schule-am-ried.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Long-running WP blog with posts spanning at least 2014-2026, good candidate for straightforward RSS ingestion."
  },
  {
   "region": "Frankfurt",
   "name": "Liebigschule",
   "city": "Frankfurt am Main",
   "school_type": "Gymnasium",
   "website": "https://www.liebigschule-frankfurt.de/",
   "cms": "joomla",
   "cms_confidence": "high",
   "cms_evidence": "index.php/ID-alias URL pattern is the classic Joomla com_content signature (/index.php/55-aktuelles, /unsere-schule/fachbereiche/fachbereich-iii/biologie/613-liebigschueler-uebergeben-968-50-...).",
   "news_url": "https://liebigschule-frankfurt.de/index.php/55-aktuelles",
   "feed_expected": "unknown",
   "feed_url_candidate": "https://liebigschule-frankfurt.de/index.php?format=feed&type=rss",
   "auto_configurable": "custom-parser-needed",
   "notes": "Joomla ships with per-category/site RSS feeds via ?format=feed, but site admins frequently disable the feed plugin; needs a live check. A custom HTML-list parser targeting the /55-aktuelles category page is the safer fallback."
  },
  {
   "region": "Frankfurt",
   "name": "Heinrich-von-Gagern-Gymnasium",
   "city": "Frankfurt am Main",
   "school_type": "Gymnasium",
   "website": "https://hvgg.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Recent (2025-2026) posts use WP date-based permalinks (/2026/02/podiumsdiskussion-zur-kommunalwahl-2026/, /2025/10/die-neue-nachhilfeboerse-powered-by-i-n-t-a-l-ist-da/, /2026/05/das-gagern-besucht-den-dfb-campus-...) and a 'Blog Multi Author' page typical of WP multi-author blog themes/plugins.",
   "news_url": "https://hvgg.de/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://hvgg.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Older indexed URLs use a legacy ?id=NNNN&mode=article&navid=NN scheme, suggesting a past migration from an older custom/portal CMS to the current WordPress site; the WP permalinks are the active ones (2022-2026 posts)."
  },
  {
   "region": "Hessen-gap-fill",
   "name": "Riedhofschule",
   "city": "Frankfurt am Main (Sachsenhausen)",
   "school_type": "Grundschule",
   "website": "https://riedhofschule.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "wp-content/uploads PDF indexed (riedhofschule.de/wp-content/uploads/Anlage-2-Merkblatt-fuer-Eltern-4.pdf); category archive at /category/aktuelles/ typical of WP taxonomy. Note: older static /YYYY-YYYY/slug/index.html pages also indexed, suggesting a migration from an earlier static/custom site to WordPress.",
   "news_url": "https://riedhofschule.de/category/aktuelles/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://riedhofschule.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Confirmed WordPress via indexed wp-content path and /category/aktuelles/ archive. Feed URL not independently verified (no network fetch available) but standard WP /feed/ endpoint is a safe default guess."
  },
  {
   "region": "Hessen-gap-fill",
   "name": "Textorschule",
   "city": "Frankfurt am Main (Sachsenhausen)",
   "school_type": "Grundschule",
   "website": "https://www.textorschule.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Multiple wp-content/uploads PDFs indexed (MEDIENKONZEPT-Textorschule.pdf, Lernzeit.pdf); /category/schulleben/ taxonomy archive present.",
   "news_url": "https://www.textorschule.de/category/schulleben/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://www.textorschule.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Bilingual (German-French) European/UNESCO project school. News lives under 'Schulleben' category rather than a dedicated 'Aktuelles' label; no single dedicated news page confirmed, /category/schulleben/ is the closest news stream."
  },
  {
   "region": "Hessen-gap-fill",
   "name": "Mühlbergschule",
   "city": "Frankfurt am Main (Sachsenhausen)",
   "school_type": "Grundschule",
   "website": "https://muehlbergschule.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "URL params ?dlm_download_tag= (Download Monitor plugin) and /tag/, /category/allgemein/ archives; also ?us_page_block= query param indicating the 'US' (UpSolution/WPBakery-family) WordPress theme.",
   "news_url": "https://muehlbergschule.de/neu/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://muehlbergschule.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Dedicated news/updates page at /neu/ (acts as the 'Aktuelles' page) shows frequent dated posts through Jan 2026, so the feed is actively maintained. Also publishes a separate parent newsletter archive at /eltern/elternbriefe/."
  },
  {
   "region": "Hessen-gap-fill",
   "name": "Grundschule Heckershausen",
   "city": "Ahnatal (Landkreis Kassel, Nordhessen)",
   "school_type": "Grundschule",
   "website": "https://gs.ahnatal.schule.hessen.de",
   "cms": "custom",
   "cms_confidence": "medium",
   "cms_evidence": "Hosted on a *.schule.hessen.de subdomain, which is the free 'Schulhomepage' hosting service run by the Hessischer Bildungsserver / Schulportal Hessen (info.schulportal.hessen.de/das-sph/sph-bs/schulhomepage-2/). Clean extension-less paths (/infos, /datenschutz) with no wp-content, ?p=, or /index.php?id= patterns found, consistent with the Bildungsserver's own lightweight CMS rather than WordPress/TYPO3/Joomla.",
   "news_url": "https://gs.ahnatal.schule.hessen.de/infos",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "Interesting case per instructions: one of two Grundschulen in the Ahnatal municipality (the other, Helfensteinschule in Ahnatal-Weimar, is a separate school). Hosted on the state-run Hessen Bildungsserver free school-homepage platform rather than a commercial/self-hosted CMS -- likely representative of many small-town Hessen Grundschulen. No evidence of RSS/Atom; would need a bespoke HTML scraper for the /infos page."
  },
  {
   "region": "Hessen-gap-fill",
   "name": "Charles-Hallgarten-Schule",
   "city": "Frankfurt am Main (Bornheim)",
   "school_type": "Förderschule",
   "website": "https://www.charles-hallgarten-schule.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "wp-content/uploads PDF indexed (Schulwegweiser_Schuljahr2022-23_CHS_Final.pdf); dedicated /news/ and /aktuelles/ style pages consistent with WP page/post structure.",
   "news_url": "https://www.charles-hallgarten-schule.de/news/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://www.charles-hallgarten-schule.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Förderschwerpunkt Lernen; regional advisory/support center (rBFZ-Ost) for Frankfurt-East. Building designed by Ernst May (Bornheimer Hang settlement), under monument protection -- not relevant to CMS but a notable identifier."
  },
  {
   "region": "Hessen-gap-fill",
   "name": "Pestalozzischule Kassel",
   "city": "Kassel (Oberzwehren)",
   "school_type": "Förderschule",
   "website": "https://www.pestalozzischule-kassel.de",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "No wp-content, ?p=, or /index.php?id= pattern surfaced across repeated site: searches. URL paths are capitalized, extension-less folders (/Aktuelles/, /Downloads/, /Schulhunde/) which is not a strong signal for any specific CMS. A second, distinct site also exists at pestalozzi.kassel.schule.hessen.de (Bildungsserver-hosted), so it's unclear which is the canonical/current site or whether they are mirrors.",
   "news_url": "https://www.pestalozzischule-kassel.de/Aktuelles/",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "unknown",
   "notes": "Förderschwerpunkt Lernen. Two candidate domains found (pestalozzischule-kassel.de and pestalozzi.kassel.schule.hessen.de) -- needs a direct fetch (blocked in this environment) to determine which is authoritative and what CMS powers it before an integration can be built."
  },
  {
   "region": "Hessen-gap-fill",
   "name": "Albert-Schweitzer-Schule",
   "city": "Wiesbaden",
   "school_type": "Förderschule",
   "website": "https://www.albert-schweitzer-schule-wiesbaden.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "URL permalink pattern /index.php/YYYY/MM/slug/ (e.g. /index.php/2026/05/08/mitteilung-des-foerderkreises/) is the classic WordPress 'index.php' permalink structure used when pretty permalinks run without a rewritten /%postname%/ base -- a strong, unambiguous WordPress fingerprint.",
   "news_url": "https://www.albert-schweitzer-schule-wiesbaden.de/index.php/foerderschule/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://www.albert-schweitzer-schule-wiesbaden.de/index.php/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Förderschwerpunkt Lernen with a branch for geistige Entwicklung; ~90-100 students. Site is actively posted to (items dated into June 2026 indexed), good candidate for reliable feed polling once /feed/ path is confirmed reachable."
  },
  {
   "region": "Mittelhessen",
   "name": "Landgraf-Ludwigs-Gymnasium Gießen",
   "city": "Gießen",
   "school_type": "Gymnasium",
   "website": "https://www.llg-giessen.de",
   "cms": "joomla",
   "cms_confidence": "high",
   "cms_evidence": "URLs use index.php?option=com_content&view=article/category&Itemid=NNN — the core Joomla 'com_content' component signature seen across multiple indexed pages.",
   "news_url": null,
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "No dedicated 'Aktuelles' landing page surfaced in search; found Joomla category pages like 'LLG am Nachmittag' (id=275, layout=blog). Joomla natively supports RSS via '&format=feed' appended to a category URL, but no live feed link was confirmed. Site also runs an IServ instance at /iserv/ for internal communication."
  },
  {
   "region": "Mittelhessen",
   "name": "Liebigschule Gießen",
   "city": "Gießen",
   "school_type": "Gymnasium",
   "website": "https://www.liebigschule-giessen.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Multiple /wp-content/uploads/ asset references and clean WordPress-style slug permalinks (e.g. /ein-neuer-weg-beginnt/, /learning-by-doing/) with posts dated through Aug 2026.",
   "news_url": null,
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://www.liebigschule-giessen.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Legacy Joomla-pattern URLs (?option=com_docman) are still indexed, indicating a past Joomla-to-WordPress migration. News posts sit at flat top-level slugs rather than under a /aktuelles/ or /category/ prefix — confirm the actual list/archive page and that /feed/ is enabled."
  },
  {
   "region": "Mittelhessen",
   "name": "Herderschule Gießen",
   "city": "Gießen",
   "school_type": "Gymnasium",
   "website": "https://www.herderschule-giessen.de",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Clean slug URLs (/schule/oberstufe, /ueber-uns/zertifikate-1) with no wp-content, wp-json, TYPO3 fileadmin, or Joomla component strings appearing in any search snippet; the site is thinly indexed.",
   "news_url": null,
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "unknown",
   "notes": "Domain migrated from herder.giessen.schule.hessen.de to herderschule-giessen.de (old host now points to the new site). Search budget was exhausted before a dedicated aktuelles/feed query could be run — needs a direct page-source or HTTP-header check to fingerprint the CMS."
  },
  {
   "region": "Mittelhessen",
   "name": "Gymnasium Philippinum Marburg",
   "city": "Marburg",
   "school_type": "Gymnasium",
   "website": "https://philippinum.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Date-based permalink structure /2026/05/04/slug/ plus a /category/aktuelles/ archive — the canonical WordPress default permalink and category-archive pattern.",
   "news_url": "https://philippinum.de/category/aktuelles/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://philippinum.de/category/aktuelles/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Strong, clean WordPress fingerprint with an active, dated 'Aktuelles' category — best rss-auto candidate in this sample. Older content lives separately on archiv.philippinum.de (prior site)."
  },
  {
   "region": "Mittelhessen",
   "name": "Elisabethschule Marburg",
   "city": "Marburg",
   "school_type": "Gymnasium",
   "website": "https://elisabethschule.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "/wp-content/uploads/2024/02/*.pdf assets served directly from the primary domain (not only the archiv subdomain), plus clean WordPress-style slugs (/ganztag/, /ohnepunktundkomma/).",
   "news_url": null,
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://elisabethschule.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "No explicit /aktuelles/ or /news/ list page surfaced in snippets — the homepage may serve as the news stream, or news could live under an unindexed path. archiv.elisabethschule.de holds the pre-redesign site; also runs a separate lernen.elisabethschule.de learning-platform subdomain."
  },
  {
   "region": "Mittelhessen",
   "name": "Goetheschule Wetzlar",
   "city": "Wetzlar",
   "school_type": "Gymnasium (Oberstufengymnasium)",
   "website": "https://www.goetheschule-wetzlar.de",
   "cms": "joomla",
   "cms_confidence": "high",
   "cms_evidence": "URLs use Joomla's classic SEF 'mainmenu' aliasing with numeric IDs, e.g. /startseite-mainmenu-1/, /goetheschule-mainmenu-45/112-uncategorised/36-goetheschule-kurz, /kollegium-364/schervertretung-mainmenu-53.",
   "news_url": "https://www.goetheschule-wetzlar.de/informationen",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "Classic Joomla install; no dedicated 'Aktuelles' category was confirmed in results (the 'Informationen' section is the closest news-adjacent page found). If RSS is enabled per-category, Joomla feeds are typically reachable by appending '&format=feed' to a category URL — unverified here."
  },
  {
   "region": "Mittelhessen",
   "name": "Alexander-von-Humboldt-Schule Lauterbach",
   "city": "Lauterbach (Vogelsbergkreis)",
   "school_type": "Gymnasium",
   "website": "https://www.avh-lauterbach.de",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Multiple staff and event pages reference /wp-content/uploads/ (e.g. flat slugs /big_challenge_2022/, /markus-siebert/), consistent with a WordPress install using flat top-level permalinks.",
   "news_url": null,
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://www.avh-lauterbach.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "News-like posts (e.g. 'Hessische Umweltschule' award, 'Big Challenge 2022') live at flat top-level slugs rather than under /aktuelles/ or /category/ — confirm the real news archive/list page and that /feed/ is not disabled."
  },
  {
   "region": "Mittelhessen",
   "name": "Freiherr-vom-Stein-Gymnasium Fulda",
   "city": "Fulda",
   "school_type": "Gymnasium",
   "website": "https://www.stein.schule",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Flat .html-suffixed slugs (/die-stein.html, /anmeldung.html, /die-freiherr-vom-stein-schule.html) with no wp-content, TYPO3 fileadmin, or Joomla component strings surfaced in search snippets.",
   "news_url": null,
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "unknown",
   "notes": "Uses the .schule TLD; a separate archiv.stein.schule (legacy site) and projekt.stein.schule (project-selection tool) subdomain both exist, suggesting a fairly recent relaunch on unidentified software — needs a direct page-source check to fingerprint the CMS."
  },
  {
   "region": "Mittelhessen",
   "name": "Winfriedschule Fulda",
   "city": "Fulda",
   "school_type": "Gymnasium",
   "website": "https://winfriedschule-fulda.de",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Clean WordPress-style slugs (/unterrichtszeiten/, /schulprofil/, /nachrichten/) are consistent with WordPress, but a wp-content/wp-json reference could not be confirmed before this run's search budget was exhausted.",
   "news_url": "https://winfriedschule-fulda.de/nachrichten/",
   "feed_expected": "unknown",
   "feed_url_candidate": "https://winfriedschule-fulda.de/feed/",
   "auto_configurable": "custom-parser-needed",
   "notes": "Explicit 'Nachrichten' news landing page confirmed — a solid scrape target regardless of CMS. archiv.winfriedschule-fulda.de holds the legacy site. Re-verify the CMS fingerprint (e.g. via view-source or a wp-json probe) once direct network access is available; feed_url_candidate is an unconfirmed guess pending that check."
  },
  {
   "region": "Mittelhessen",
   "name": "Marianum Fulda",
   "city": "Fulda",
   "school_type": "Realschule mit gymnasialer Oberstufe (privat, Marianisten)",
   "website": "https://www.marianum-fulda.de",
   "cms": "typo3",
   "cms_confidence": "high",
   "cms_evidence": "URLs follow the canonical unrewritten TYPO3 pattern index.php?id=NNN (id=184 'Aktuelles', id=810 'Infosystem (Ticker)', id=979 'Unsere Wurzeln', id=820 'Arbeitsgemeinschaften').",
   "news_url": "https://www.marianum-fulda.de/index.php?id=184",
   "feed_expected": "no",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "TYPO3 without clean-URL/RealURL rewriting and no visible news-extension RSS output. Also runs a separate 'Infosystem (Ticker)' page (id=810) that may be a simpler scrape target than the general Aktuelles page (id=184)."
  },
  {
   "region": "Nordhessen",
   "name": "Friedrichsgymnasium Kassel",
   "city": "Kassel",
   "school_type": "Gymnasium",
   "website": "https://fg-kassel.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Clean post-slug permalinks (e.g. /das-fg-online-orchester-mit-musikalischen-gruessen/), /page/33/ pagination, and wp-content/uploads/ media paths (mp3, mp4, pdf) all confirmed via search.",
   "news_url": "https://fg-kassel.de/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://fg-kassel.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Posts appear at root-level slugs, not under an /aktuelles/ prefix, so news reads as the front-page blog stream. Old static archive still resolves at archiv.fg-kassel.de (pre-WordPress site, ignore for feed config)."
  },
  {
   "region": "Nordhessen",
   "name": "Albert-Schweitzer-Schule Kassel",
   "city": "Kassel",
   "school_type": "Gymnasium (Europagymnasium)",
   "website": "https://ass-kassel.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "/aktuelles/ with /aktuelles/page/7/ pagination (WP core pagination pattern), wp-content media references, and an indexed /feed/ URL found directly.",
   "news_url": "https://ass-kassel.de/aktuelles/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://ass-kassel.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Best-confirmed case in this sample: the /feed/ endpoint itself showed up in search results with recent post content, so the standard WordPress RSS feed can likely be consumed as-is."
  },
  {
   "region": "Nordhessen",
   "name": "Goethe-Gymnasium Kassel",
   "city": "Kassel",
   "school_type": "Gymnasium",
   "website": "https://goethe.kassel.schule.hessen.de/",
   "cms": "custom",
   "cms_confidence": "medium",
   "cms_evidence": "Static-looking .html paths under /aktuell/ and /aktuell/terminkalender/index.html on a schule.hessen.de subdomain; no wp-content, no query-string CMS markers (?id=, ?p=) seen — consistent with the shared static template many Hessen school sites use rather than a mainstream CMS.",
   "news_url": "https://goethe.kassel.schule.hessen.de/aktuell/",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "An older alternate domain (goethegymnasium-kassel.de) was also referenced in search results; goethe.kassel.schule.hessen.de looks like the actively maintained one. No news items were indexed at search time (page may render client-side or be currently empty), so structure should be re-verified before building a parser."
  },
  {
   "region": "Nordhessen",
   "name": "Herderschule Kassel",
   "city": "Kassel",
   "school_type": "Gymnasiale Oberstufe / Gymnasium",
   "website": "https://herderschule-kassel.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "/category/aktuelles/ and /aktuelles/page/20/ pagination are canonical WordPress category-archive patterns; legacy pre-WP site still resolves at www.herderschule-kassel.de/ct-menu-item-1/... (older CMS, superseded).",
   "news_url": "https://herderschule-kassel.de/category/aktuelles/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://herderschule-kassel.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Herderschule is an Oberstufe (upper-level gymnasium) serving feeder Gesamtschulen/Gymnasien in the Kassel-Ost area, not a standalone Sek-I school."
  },
  {
   "region": "Nordhessen",
   "name": "Alte Landesschule Korbach",
   "city": "Korbach",
   "school_type": "Gymnasium",
   "website": "https://www.alte-landesschule.de/",
   "cms": "joomla",
   "cms_confidence": "medium",
   "cms_evidence": "Homepage pagination via ?start=60 (classic Joomla com_content/list pagination) plus a /news/aktuelles menu-item-style path typical of Joomla SEF URLs.",
   "news_url": "https://www.alte-landesschule.de/news/aktuelles",
   "feed_expected": "unknown",
   "feed_url_candidate": "https://www.alte-landesschule.de/?format=feed&type=rss",
   "auto_configurable": "custom-parser-needed",
   "notes": "Joomla ships a native RSS feed (?format=feed) per category, but it is frequently disabled by site admins in German school installs — needs a live check before relying on it. Alternate short domain als-korbach.de also appears in search results."
  },
  {
   "region": "Nordhessen",
   "name": "Gustav-Stresemann-Gymnasium Bad Wildungen",
   "city": "Bad Wildungen",
   "school_type": "Gymnasium",
   "website": "https://www.stresemanngymnasium.de/",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Search returned no indexed subpages under stresemanngymnasium.de beyond the homepage; the school is also mirrored at gustav-stresemann.bad-wildungen.schule.hessen.de (a schule.hessen.de subdomain, same family as Goethe-Gymnasium Kassel's site), suggesting the same static/custom Hessen template, but this is unconfirmed.",
   "news_url": null,
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "unknown",
   "notes": "Two candidate domains exist (stresemanngymnasium.de and the .schule.hessen.de subdomain); which one is canonical/current needs a manual visit — search budget was exhausted before this could be resolved further."
  },
  {
   "region": "Nordhessen",
   "name": "Schwalm-Gymnasium Schwalmstadt",
   "city": "Schwalmstadt (Treysa), Schwalm-Eder-Kreis",
   "school_type": "Gymnasium",
   "website": "https://www.schwalmgymnasium.de/",
   "cms": "joomla",
   "cms_confidence": "high",
   "cms_evidence": "Direct index.php?option=com_content&view=article&catid=8:aktuelles&id=NNN URL indexed, plus SEF variants like /aktuelles/neuigkeiten/305-slug.html and /aktuelles.html?start=24 pagination — unambiguous Joomla com_content signature.",
   "news_url": "https://www.schwalmgymnasium.de/aktuelles.html",
   "feed_expected": "unknown",
   "feed_url_candidate": "https://www.schwalmgymnasium.de/aktuelles.html?format=feed",
   "auto_configurable": "custom-parser-needed",
   "notes": "Runs its own Moodle instance at moodle.schwalmgymnasium.de. Joomla category feed URL is a reasonable candidate but must be verified live before shipping."
  },
  {
   "region": "Nordhessen",
   "name": "Gesamtschule Melsungen",
   "city": "Melsungen, Schwalm-Eder-Kreis",
   "school_type": "Integrierte Gesamtschule (Gymnasium/Realschule/Hauptschule-Zweige)",
   "website": "https://gs-melsungen.de/",
   "cms": "joomla",
   "cms_confidence": "high",
   "cms_evidence": "URLs like /index.php/startseite/aktuelles/item/693-slug and /index.php/startseite/k2-tags/aktuelles are the Joomla + K2 component signature (item/ID-slug, k2-tags taxonomy).",
   "news_url": "https://gs-melsungen.de/index.php/startseite/aktuelles",
   "feed_expected": "unknown",
   "feed_url_candidate": "https://gs-melsungen.de/index.php/startseite/aktuelles?format=feed",
   "auto_configurable": "custom-parser-needed",
   "notes": "Multiple domains found in search (gs-melsungen.de, gesamtschule-melsungen.de, gsm-melsungen.de, plus a gs.melsungen.schule.hessen.de state mirror) — gs-melsungen.de is the one with actively indexed, current content and was treated as canonical here."
  },
  {
   "region": "Nordhessen",
   "name": "Modellschule Obersberg Bad Hersfeld",
   "city": "Bad Hersfeld, Landkreis Hersfeld-Rotenburg",
   "school_type": "Gymnasiale Oberstufe / Berufliche Schule (mixed upper-level + vocational)",
   "website": "https://www.mso-hef.de/",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Only the homepage was confirmed via search before the session's search budget ran out; no subpage URL patterns (news, feed, wp-content) were gathered.",
   "news_url": null,
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "unknown",
   "notes": "Needs a follow-up pass (site:mso-hef.de aktuelles / wp-content / feed) once search budget resets — not yet investigated beyond identifying the official domain."
  },
  {
   "region": "Nordhessen",
   "name": "Oberstufengymnasium Eschwege",
   "city": "Eschwege, Werra-Meißner-Kreis",
   "school_type": "Gymnasiale Oberstufe (Gymnasium)",
   "website": "https://og-eschwege.de/",
   "cms": "custom",
   "cms_confidence": "medium",
   "cms_evidence": "Main site has an /aktuelles/ page, but search also surfaced a parallel og-eschwege.chayns.site presence with a /ticker page — chayns is a proprietary German platform (Tobit.Software) used by many schools as a news/info ticker widget, distinct from mainstream CMS platforms.",
   "news_url": "https://og-eschwege.de/aktuelles/",
   "feed_expected": "no",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "The only general-education Oberstufe (upper-level-only) school in Werra-Meißner-Kreis, so it has no Sek-I news of its own — coverage is upper-level/Abitur-track news only. The chayns ticker, if actually used for news, would need a bespoke integration (no standard RSS)."
  },
  {
   "region": "Hessen-other-types",
   "name": "Werner-von-Siemens-Schule",
   "city": "Wetzlar",
   "school_type": "berufliche Schule (kaufmännisch-technisch)",
   "website": "https://www.siemensschule-wetzlar.de/",
   "cms": "contao",
   "cms_confidence": "high",
   "cms_evidence": "Indexed article URLs follow Contao's default news-module structure, e.g. /aktuelles/nachrichten/details/article/siemensschule-hat-neues-schulsprecherteam.html and /aktuelles/nachrichten/details/article/siemensschule-on-tour.html, alongside alias-style static pages like /impressum/ and /schulentw.html - a mixed pattern characteristic of Contao routing.",
   "news_url": "https://www.siemensschule-wetzlar.de/aktuelles/nachrichten.html",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "School has TWO web presences: a legacy static site on the Hessen state subdomain (werner-von-siemens.wetzlar.schule.hessen.de, plain index.html, no CMS fingerprint found) and a newer, actively-updated site at siemensschule-wetzlar.de (Contao CMS pattern) which carries the actual news items. Use the siemensschule-wetzlar.de domain for feed/news harvesting. Contao does not enable RSS by default, so a feed cannot be assumed - would need direct verification or an HTML scraper against the /aktuelles/nachrichten/ list page."
  },
  {
   "region": "Hessen-other-types",
   "name": "Friedrich-Ebert-Schule",
   "city": "Wiesbaden",
   "school_type": "berufliche Schule (Metall-, Elektro-, Informations- und Veranstaltungstechnik)",
   "website": "https://fes-wiesbaden.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Multiple indexed asset URLs under /wp-content/uploads/YYYY/MM/... (e.g. /wp-content/uploads/2025/08/2025-Info-Berufsschulenglisch.pdf), the standard WordPress media-library path.",
   "news_url": null,
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://fes-wiesbaden.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Search snippets confirmed WordPress via /wp-content/uploads paths but did not surface an explicit 'Aktuelles' or blog listing page - site may present news mainly via a homepage widget or a page named differently (e.g. /aktuelles, /news). Recommend confirming the exact news-listing slug and that pretty permalinks expose /feed/ before wiring up auto-config."
  },
  {
   "region": "Hessen-other-types",
   "name": "Käthe-Kollwitz-Schule",
   "city": "Offenbach am Main",
   "school_type": "berufliche Schule (Ernährung/Hauswirtschaft, Textiltechnik, Sozialwesen)",
   "website": "https://www.kks-offenbach.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Dedicated 'Aktuelles' page found at /aktuelles/, and asset URLs under /wpdata/wp-content/uploads/... confirm a WordPress install (running from a non-default 'wpdata' subpath rather than webroot).",
   "news_url": "https://www.kks-offenbach.de/aktuelles/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://www.kks-offenbach.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "WordPress core is installed under a /wpdata/ subdirectory rather than the site root; if the install isn't rewritten to the root, the working feed URL may instead be https://www.kks-offenbach.de/wpdata/?feed=rss2 - verify both candidates."
  },
  {
   "region": "Suedhessen",
   "name": "Goethe-Gymnasium Bensheim",
   "city": "Bensheim (Kreis Bergstraße)",
   "school_type": "Gymnasium",
   "website": "https://www.goethe-bensheim.de",
   "cms": "joomla",
   "cms_confidence": "high",
   "cms_evidence": "URLs use index.php?Itemid=167, index.php?start=48, and index.php/component/dpcalendar/calendar — Itemid and the dpcalendar component are Joomla-specific signatures.",
   "news_url": "https://www.goethe-bensheim.de/index.php/aktuelles/vertretungsplan",
   "feed_expected": "unknown",
   "feed_url_candidate": "https://www.goethe-bensheim.de/index.php?format=feed&type=rss",
   "auto_configurable": "custom-parser-needed",
   "notes": "Confirmed Joomla via Itemid/component URL params. Joomla can expose per-category RSS via format=feed&type=rss but this was not verified as enabled; a dedicated Joomla content-API parser is the safer bet. Search budget ran out before a feed-specific query could be run."
  },
  {
   "region": "Suedhessen",
   "name": "Altes Kurfürstliches Gymnasium Bensheim",
   "city": "Bensheim (Kreis Bergstraße)",
   "school_type": "Gymnasium",
   "website": "https://akg-bensheim.de",
   "cms": "wordpress",
   "cms_confidence": "medium",
   "cms_evidence": "Clean flat slugs (/kollegium/, /gebaude-und-geschichte/) and a page titled \"Aktuelles Archives\" — the \"<Term> Archives\" title format is WordPress's default category-archive convention. Not confirmed via a wp-content hit (search budget exhausted before that query ran).",
   "news_url": "https://akg-bensheim.de/service/aktuelles/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://akg-bensheim.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "Also has a subdomain abilisten.akg-bensheim.de (alumni list, unrelated to news). Recommend a live check of /feed/ before shipping."
  },
  {
   "region": "Suedhessen",
   "name": "Martin-Luther-Schule Rimbach",
   "city": "Rimbach (Kreis Bergstraße)",
   "school_type": "Gymnasium (musisch)",
   "website": "https://mls-rimbach.de",
   "cms": "wordpress",
   "cms_confidence": "medium",
   "cms_evidence": "Post URLs are long descriptive flat slugs directly off root (e.g. /froehlicher-schulstart-an-der-mls-fuer-die-neuen-5-klassen/), matching WordPress's default \"postname\" permalink structure. wp-content confirmation query could not be run (budget exhausted).",
   "news_url": "https://mls-rimbach.de/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://mls-rimbach.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "No dedicated /aktuelles/ or /news/ index URL surfaced in search results; posts appear to be surfaced on the homepage itself (blog-style front page), so the homepage is the best news_url guess pending manual check."
  },
  {
   "region": "Suedhessen",
   "name": "Gymnasium Michelstadt",
   "city": "Michelstadt (Odenwaldkreis)",
   "school_type": "Gymnasium",
   "website": "https://www.gymnasium-michelstadt.de",
   "cms": "joomla",
   "cms_confidence": "high",
   "cms_evidence": "A mirror URL (gy-mi.de) exposes index.php?option=com_content&view=article&id=73 and the primary domain uses index.php?view=category&id=194 — com_content/view=category/view=article are Joomla component signatures.",
   "news_url": "https://www.gymnasium-michelstadt.de/",
   "feed_expected": "unknown",
   "feed_url_candidate": "https://www.gymnasium-michelstadt.de/index.php?format=feed&type=rss",
   "auto_configurable": "custom-parser-needed",
   "notes": "Two live domains for the same school (gymnasium-michelstadt.de and gy-mi.de/gy-mi.de) — pick gymnasium-michelstadt.de as canonical. No dedicated Aktuelles/Neuigkeiten URL confirmed; homepage likely shows a Joomla front-page blog layout of recent articles."
  },
  {
   "region": "Suedhessen",
   "name": "Prälat-Diehl-Schule Groß-Gerau",
   "city": "Groß-Gerau (Kreis Groß-Gerau)",
   "school_type": "Gymnasium",
   "website": "https://www.praelat-diehl-schule.de",
   "cms": "wordpress",
   "cms_confidence": "medium",
   "cms_evidence": "Clean hierarchical slugs including /deutsch-2/ — the \"-2\" suffix is WordPress's default behavior for de-duplicating a slug against an existing page/menu item of the same name. wp-content query not run before budget ran out.",
   "news_url": null,
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://www.praelat-diehl-schule.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "No Aktuelles/news index URL surfaced directly in results (found /unsere-schule/, /mittelstufe/, /oberstufe/, /home-kontakt/); needs a manual site visit to confirm the news landing page before wiring up a feed."
  },
  {
   "region": "Suedhessen",
   "name": "Grimmelshausen-Gymnasium Gelnhausen",
   "city": "Gelnhausen (Main-Kinzig-Kreis)",
   "school_type": "Gymnasium",
   "website": "https://grimmels.de/wordpress/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "URL path literally contains \"/wordpress/\" segment (grimmels.de/wordpress/...) — direct, unambiguous evidence of the CMS.",
   "news_url": "https://grimmels.de/wordpress/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://grimmels.de/wordpress/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "School also runs a separate student-newspaper WordPress/blog at spektrum.grimmels.de — do not confuse with the main school news feed."
  },
  {
   "region": "Suedhessen",
   "name": "Hohe Landesschule Hanau",
   "city": "Hanau (Main-Kinzig-Kreis)",
   "school_type": "Gymnasium",
   "website": "https://hola-gymnasium.de",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "site: query returned no indexed pages (likely sparse indexing or search-budget cutoff). Only clean slugs known from a generic search: /home/, /sekretariat/, /profile/ — too thin to fingerprint a CMS.",
   "news_url": null,
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "unknown",
   "notes": "School also maintains an official hessen.de subdomain (hohe-landesschule.hanau.schule.hessen.de) as a secondary/legacy site — worth checking whether that one is Hessen's Schulportal-integrated template instead of hola-gymnasium.de. Needs a follow-up direct fetch (blocked in this environment) or additional searches once budget resets."
  },
  {
   "region": "Suedhessen",
   "name": "Adolf-Reichwein-Schule Neu-Anspach",
   "city": "Neu-Anspach (Hochtaunuskreis)",
   "school_type": "Integrierte Gesamtschule mit gymnasialer Oberstufe",
   "website": "https://ars-hochtaunus.de",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Hierarchical clean slugs (/aktuelles/schuelerzeitung/, /schulgemeinde/schulseelsorge/projekte/, /info/gymnasiale-oberstufe/termine/) plus a /login/ page. Pattern is consistent with WordPress (hierarchical pages) but also with several custom Hessen school-CMS templates; no wp-content or generator confirmation obtained.",
   "news_url": "https://ars-hochtaunus.de/aktuelles/",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "Substituted for the task's suggested 'Adolf-Reichwein-Schule Neu-Isenburg', which does not appear to exist — searches turned up no such school; the only Hessian Adolf-Reichwein-Schule near the target Kreise is this one, in Neu-Anspach (Hochtaunuskreis), a kooperative/integrierte Gesamtschule — also serves the requested school-type diversity. School runs a separate student blog at ars-blogdown.de."
  },
  {
   "region": "Suedhessen",
   "name": "Main-Taunus-Schule Hofheim",
   "city": "Hofheim am Taunus (Main-Taunus-Kreis)",
   "school_type": "Gymnasium",
   "website": "https://www.main-taunus-schule.de",
   "cms": "wordpress",
   "cms_confidence": "medium",
   "cms_evidence": "Dated news post under /unsere-schule/news/schulstart-2026/ and a duplicate-slug pattern at /unsere-schule/organisation-2/ (the \"-2\" suffix is WordPress's default de-duplication behavior) both point to WordPress. wp-content confirmation not obtained (budget exhausted).",
   "news_url": "https://www.main-taunus-schule.de/unsere-schule/news/",
   "feed_expected": "yes (WP default)",
   "feed_url_candidate": "https://www.main-taunus-schule.de/feed/",
   "auto_configurable": "wordpress-likely",
   "notes": "News lives under a nested path (/unsere-schule/news/) rather than site root; if root /feed/ doesn't include these posts, may need a category-specific feed URL instead."
  },
  {
   "region": "Suedhessen",
   "name": "Brüder-Grimm-Schule Neu-Isenburg",
   "city": "Neu-Isenburg (Kreis Offenbach)",
   "school_type": "Haupt- und Realschule mit Förderstufe",
   "website": "https://b-g-s.de",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Only clean slugs seen (/herzlich-willkommen/, /schulgemeinde/kollegium/) plus a generic WP-style tagline in the title (\"Homepage der Brüder-Grimm-Schule – voneinander lernen – miteinander leben – füreinander da sein\"); suggestive of WordPress but not confirmed via wp-content or generator meta.",
   "news_url": null,
   "feed_expected": "unknown",
   "feed_url_candidate": "https://b-g-s.de/feed/",
   "auto_configurable": "custom-parser-needed",
   "notes": "Substituted for the task's suggested 'Prälat-Diehl-Schule'-adjacent Haupt-/Realschule slot in Kreis Offenbach; chosen specifically to cover the Haupt-/Realschule type requested. News/Aktuelles index URL not located in results — needs manual confirmation. Uses Microsoft Teams as its learning platform per search snippet, separate from the public website."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Gutenbergschule",
   "city": "Wiesbaden",
   "school_type": "Gymnasium",
   "website": "https://www.gutenbergschule.org/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Multiple /wp-content/uploads/YYYY/MM/ PDF paths indexed (e.g. Fachcurriculum-Sport-GBS.pdf, Liste-Kollegium.pdf); clean flat slug pages typical of WP permalinks (/fachbereiche/sprachen/, /gbsgeschichte/, /ehemalige/).",
   "news_url": "https://www.gutenbergschule.org/neuigkeiten/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://www.gutenbergschule.org/feed/",
   "auto_configurable": "rss-auto",
   "notes": "MINT-EC school with AbiBac (French Baccalauréat) track. Dedicated /neuigkeiten/ (news) page found; WP default feed should work at /feed/ or /neuigkeiten/feed/."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Oranienschule",
   "city": "Wiesbaden",
   "school_type": "Gymnasium (mit gymnasialer Oberstufe)",
   "website": "https://www.oranienschule.de/",
   "cms": "custom",
   "cms_confidence": "medium",
   "cms_evidence": "URL structure is nested static-style .html pages (/seiten/faecher/musik.html, /mediendesign/impressum.html, /seiten/aktuelles/archiv/Juli_Dezember_2019.html, /archiv_alt.html). No wp-content, typo3conf, or Joomla index.php artifacts found in any indexed query.",
   "news_url": "https://oranienschule.de/seiten/aktuelles/archiv/",
   "feed_expected": "no",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "News is distributed as a periodic newsletter ('Oranienschule aktuell') archived in half-year-dated .html pages rather than via a blog engine. A custom scraper targeting the aktuelles/archiv index would be required; also has a legacy hessen.de mirror at oranien.wiesbaden.schule.hessen.de."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Elly-Heuss-Schule",
   "city": "Wiesbaden",
   "school_type": "Gymnasium (bilingual)",
   "website": "https://www.elly-heuss-schule-wiesbaden.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "Numerous /wp-content/uploads/ PDF paths confirmed (schulordnung.pdf, gesamtbrief.pdf, notenpapier.pdf, etc.); hierarchical pretty-permalink pages typical of WP (/neues-aus-dem-schulleben/schulleitung/, /schueler-eltern/foerderverein/).",
   "news_url": "https://www.elly-heuss-schule-wiesbaden.de/aktuelles/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://www.elly-heuss-schule-wiesbaden.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Confirmed WordPress via direct wp-content/uploads hits; dedicated /aktuelles/ news page found."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Diltheyschule",
   "city": "Wiesbaden",
   "school_type": "Gymnasium (humanistisch, altsprachlich/neusprachlich)",
   "website": "https://www.diltheyschule.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "wp-content/uploads paths confirmed on image-bearing pages; flat post-slug URLs at domain root are classic WP %postname% permalinks (/weihnachtsbrief-2016/, /lego-roboter-minikurs/, /zeitungsfruehstueck-der-klasse-8c/, /kinder-helfen-kindern/).",
   "news_url": "https://www.diltheyschule.de/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://www.diltheyschule.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "News items are published as individual WP posts directly at site root; no separate '/aktuelles/' index page surfaced in search, so homepage or /feed/ is the best aggregation point. Also has a /calendar/anstehende_termine/ events page."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Helene-Lange-Schule Wiesbaden",
   "city": "Wiesbaden",
   "school_type": "Integrierte Gesamtschule (IGS)",
   "website": "https://www.helene-lange-schule.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "wp-content/uploads confirmed (Literaturliste PDF, Fachtag flyer PDF); date-based post URLs (/2020/09/23/slug/, /2021/11/22/slug/) and /category/news/page/3/ pagination are classic WordPress defaults.",
   "news_url": "https://www.helene-lange-schule.de/category/news/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://www.helene-lange-schule.de/category/news/feed/",
   "auto_configurable": "rss-auto",
   "notes": "UNESCO project school and Club-of-Rome school; dedicated 'news' category confirmed with multiple paginated archive pages."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Ludwig-Georgs-Gymnasium",
   "city": "Darmstadt",
   "school_type": "Gymnasium (altsprachlich/humanistisch)",
   "website": "https://lgg-darmstadt.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "wp-content/uploads/YYYY/MM/ PDFs confirmed (ShS_Dokumente_Infos.pdf, LGG-Anmeldung-2024-2025.pdf, Jahresterminplan.pdf); flat WP-style slug pages (/das-lgg/, /aktuelles/, /schulleben/, /menschen-am-lgg/).",
   "news_url": "https://lgg-darmstadt.de/aktuelles/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://lgg-darmstadt.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Dedicated /aktuelles/ page also offers a downloadable/subscribable calendar (iCal) alongside news items."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Georg-Büchner-Schule",
   "city": "Darmstadt",
   "school_type": "Gymnasium",
   "website": "https://gbs-darmstadt.de/",
   "cms": "wordpress",
   "cms_confidence": "high",
   "cms_evidence": "wp-content/uploads confirmed (including a 2026/08 video upload); dedicated /aktuelles/ page found on the non-www apex domain.",
   "news_url": "https://gbs-darmstadt.de/aktuelles/",
   "feed_expected": "yes",
   "feed_url_candidate": "https://gbs-darmstadt.de/feed/",
   "auto_configurable": "rss-auto",
   "notes": "Legacy pages under www.gbs-darmstadt.de still use old capitalized .htm URLs (e.g. /Angebote/Erasmus-/-Comenius/E1076.htm, /Lehrkraefte/E1021.htm) from a prior CMS, suggesting a past migration to WordPress; auto-parser should target the current non-www WP site."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Lichtenbergschule Darmstadt (LuO)",
   "city": "Darmstadt",
   "school_type": "Oberstufengymnasium (europäische Schule)",
   "website": "https://luo-darmstadt.de/home/",
   "cms": "joomla",
   "cms_confidence": "medium",
   "cms_evidence": "URLs follow the /home/index.php/<section>/<subsection> Joomla SEF pattern; individual news articles use ID-prefixed aliases typical of Joomla com_content (e.g. /die-luo/mint-news/812-tag-der-mathematik-2026, /die-luo/mint-news/665-mint-camps-start).",
   "news_url": "https://luo-darmstadt.de/home/index.php/die-luo/mint-news",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "News indexed by search is mostly MINT-subject-specific ('mint-news'); a general school-wide Aktuelles/news list page was not confirmed within the search budget. A separate WordPress sub-blog 'SchreibKunst' exists at /schreibkunst/ (literature project, WP pagination /aktuelles/page/N/) but is not the main school news feed — do not confuse the two."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Justus-Liebig-Schule",
   "city": "Darmstadt",
   "school_type": "Gymnasium (mit gymnasialer Oberstufe)",
   "website": "https://www.lio-darmstadt.de/",
   "cms": "typo3",
   "cms_confidence": "high",
   "cms_evidence": "typo3conf/ paths directly indexed (l10n language files, ext/typo3_console, ext/layerslider, ext/realurl); /faq/anmeldung/?no_cache=1 uses the classic TYPO3 no_cache query parameter; news detail pages follow /startseite/newsdetails/<slug>/, typical of the TYPO3 'news' extension.",
   "news_url": "https://www.lio-darmstadt.de/startseite/",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "TYPO3's news extension can expose an RSS feed if the integrator configured one, but no concrete feed URL surfaced in search results; would need direct site inspection (e.g. a type=rss GET parameter) to confirm."
  },
  {
   "region": "Wiesbaden+Darmstadt",
   "name": "Bertolt-Brecht-Schule",
   "city": "Darmstadt",
   "school_type": "Oberstufengymnasium",
   "website": "https://www.brechtschule.de/",
   "cms": "unknown",
   "cms_confidence": "low",
   "cms_evidence": "Homepage title snippet reads 'Aktuell / wp 6 / 19 Feb 2024 -' (ambiguous - 'wp' here plausibly means 'Wochenplan', not WordPress). No wp-content, typo3conf, or Joomla index.php artifacts were found for this exact domain across several targeted queries; the domain is thinly indexed and searches kept surfacing unrelated Brecht schools in Hamburg/Nürnberg/Bonn instead.",
   "news_url": "https://www.brechtschule.de/",
   "feed_expected": "unknown",
   "feed_url_candidate": null,
   "auto_configurable": "custom-parser-needed",
   "notes": "Homepage title suggests it doubles as the 'Aktuell' (current) page. Could not fingerprint the CMS confidently via WebSearch alone (direct fetch is blocked in this environment) - flag for manual/direct verification before building a parser."
  }
 ]
}
```

## Sources

* SPH school list endpoint: `startcache.schulportal.hessen.de/exporteur.php?a=schoollist` (shape confirmed in the sources of lanis-mobile/lanis, Peasplayer/SPH-API, joan-code6/lanis_api, a.o.)
* Schuldatenbank: <https://schul-db.bildung.hessen.de/schul_db.html> — detail pages `…/details/?school_no=<NR>` with the Homepage field (checked: 5102, 4318, 5138, 5214)
* jedeschule scraper & data: <https://github.com/Datenschule/jedeschule-scraper> (`jedeschule/spiders/hessen.py` maps the Schuldatenbank `homepage` field to `website`), <https://jedeschule.codefor.de/docs>, weekly CSV `…/csv-data/schools.csv`
* Bildungsserver Schulhomepage hosting: <https://djaco.bildung.hessen.de/schulhomepage/>, <https://dms-portal.bildung.hessen.de/einfuehrung/angebot/schule/schulhomepage/>
* SPH scale ("über 1 800 Schulen"): <https://info.schulportal.hessen.de/das-sph/sph-ueberblick/>
* CMS survey among school webmasters (757 ratings, 33 % no CMS): <https://www.schulhomepage.de/cms/cms-vergleich>
* Feed behavior per platform: WordPress core feeds (`/feed/`), Contao manual "News-Feed" (<https://docs.contao.org/manual/en/site-structure/news-feed/>), TYPO3 georgringer/news RSS docs, Joomla `?format=feed` forum/docs, Jimdo `/rss/blog/`, Wix `/blog-feed.xml`, IServ News module docs (<https://iserv.de/doc/manage/modules/news/>)
* Per-school evidence: `site:`-scoped web searches per school domain, 31.08.2026. All direct fetches were blocked by the research environment; nothing in the dataset was verified live.
