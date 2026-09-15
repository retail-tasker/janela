---
Date: 2026-09-15
Status: Accepted
Related: ADR 003, ADR 005
Triggers:
  - changing where dashboard filter state lives or how it is serialised
  - making a dashboard, not just a pane, shareable or bookmarkable
  - touching browser history from the dashboard controller
  - rendering a dashboard page that arrives with filters already applied
Topics: cross-filtering, urls, stimulus, turbo, progressive-enhancement
---

# ADR 008: Dashboard Filters in the Page URL

## Context

ADR 003 kept a dashboard's filter state in the Stimulus controller and
in each Turbo Frame's `src`, and named the cost: a reload lost every
filter, and a filtered dashboard could not be shared as a link. ADR 005
gave each pane a URL that carries its filters, which made a single
pane shareable but not the dashboard around it.

The host application's page URL is the natural home. It is what a
browser bookmarks, what a person pastes into a message, and what Rails
already parses into `params[:q]` on the way in.

## Decision

**The page URL carries the dashboard's filters as `q[...]`, the same
Ransack parameters every pane already accepts.**

```
/reports/orders?q[customer_region_eq]=APAC&q[status_eq]=paid
```

**The server renders the initial state.** `janela_dashboard` reads
`params[:q]` from the page request and sets it as the controller's
starting filters; `janela_pane` bakes the same filters into each
frame's initial `src`. A dashboard opened from a shared link is
therefore correct before any JavaScript runs, and the controller's
first pass over the frames changes nothing, so nothing loads twice.

**The controller keeps the URL current.** Whenever filters change it
rewrites the page URL's `q[...]` parameters with `history.replaceState`,
preserving whatever else is in the query string and Turbo's own
history state. Filter keys are written in sorted order on both sides
so the server and the browser serialise identically.

**Replace, not push.** Every click does not become a history entry.
The back button leaves the dashboard, as it does in every BI tool;
undoing a filter is clicking it again or clearing. Pushing each toggle
would trap the user in their own click history.

## Consequences

- A reload keeps the filters. A pasted dashboard URL opens filtered.
  Issue #1 is closed.
- A pane URL and a dashboard URL now share the same `q` vocabulary, so
  a filter copied from one works in the other. That is the payoff of
  ADR 002 making Ransack parameters the contract rather than a Janela
  vocabulary.
- The host page's other query parameters survive untouched. Janela
  only owns the `q` namespace on that URL, which a host using Ransack
  for a search form on the same page would also want. Documented: put
  a dashboard and a Ransack search form on different pages, or expect
  them to share filters.
- Two dashboards on one page would share one URL and one `q`. Not
  supported and not a goal; one dashboard per page is the shape.
