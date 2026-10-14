---
Date: 2026-10-14
Status: Proposed
Related: ADR 010, ADR 052, ADR 056
Triggers:
  - changing what the demo tells a search engine or a link preview
  - adding a call from the demo to a service outside it
  - showing a number in the demo that the demo did not count itself
  - adding a page to the demo that should or should not be indexed
Topics: demo, seo, marketing, privacy, dependencies, dogfooding
---

# ADR 060: The Demo Tells Search Engines What It Is, and Shows Its Own Adoption

## Context

The demo is Janela's front door, and a search for it is how most hosts will meet
the gem. The maintainer wants to measure how well it is found, and the first
thing that measuring needs is that there is something to find.

### Measured

Against the live demo, 2026-10-14.

| Thing | State |
| --- | --- |
| `/robots.txt`, `/sitemap.xml` | both 404 |
| meta description, canonical link, Open Graph tags | none on any page |
| `lang` on the `html` element | absent |
| `<h1>` on `/name` | none |
| titles | one per page, though `Gallery` and `Vitral` say nothing a search result could use |
| RubyGems | the gem answers `api/v1/gems/janela.json`: 8,315 downloads, 147 on the current version |
| GitHub | the repository answers `api.github.com/repos/...`: 1 star |

The Dashboards, snapshot and frame pages are the engine's own, and they take any
filter as a query string, so a crawler that follows their links meets an
unbounded number of URLs that all show the same page.

## Decision

**The demo says what each page is, in the head of the page, and keeps crawlers
off the pages that are only filters.**

- Every page has a `lang`, a title, a meta description, a canonical link to its
  own path with no query string, and Open Graph and Twitter tags. A page with
  nothing of its own to say gets the site's description rather than none.
- A documentation page's description is its first paragraph, read from the
  document, so it cannot drift from what ships in the gem (ADR 010).
- `robots.txt` names the sitemap and disallows `/dashboards`, `/snapshots` and
  `/frames`, the pages that are one dashboard under unbounded filters.
  `sitemap.xml` lists the pages worth finding: the home page, the guides, the
  decisions, the gallery, the name, the example and the visits page. One
  mechanism for keeping a page out, and it is the robots file.

**The footer shows RubyGems downloads and GitHub stars, fetched by the server
and cached for an hour.** They link to the gem's page and the repository. A
failed fetch shows the plain links as before and is not retried for five
minutes, so a service being down costs the page nothing and the demo does not
hammer it. The numbers are fetched, not stored: Janela owns no data store, and a
count that is only ever read from its source cannot disagree with it.

**Nothing is fetched in the test suite.** The footer is on every page, so a call
from it would put the network in every test. It is switched on in development
and production, and a test that wants it says so.

## Consequences

- **The demo makes two outbound calls**, at most one pair an hour. They carry no
  information about a visitor, because the server makes them and not the
  browser, so no visitor's address reaches either service.
- **A visitor's first view after the cache expires waits for the fetch**, up to
  the timeout. That is accepted for a demo, and the stale-while-refresh answer
  is for when it is not.
- **This is the baseline, not the measuring.** Search Console and page speed
  data, a referrer on the visits recorder and the adoption numbers as stored
  history are separate decisions, and the first of them needs `PageView` to
  change, which ADR 056 keeps cookie free.
- **What would change this decision:** the counts being wanted as history, which
  is the day they stop being fetched and become rows.
