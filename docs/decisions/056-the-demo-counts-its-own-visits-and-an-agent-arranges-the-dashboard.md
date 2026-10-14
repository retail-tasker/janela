---
Date: 2026-10-13
Status: Accepted
Related: ADR 001, ADR 012, ADR 032, ADR 053
Triggers:
  - changing what the demo records about a visitor
  - adding a model to the demo that Janela reads
  - arranging a demo frame by hand rather than through the tools
  - the demo reset or its seeds
Topics: demo, dogfooding, privacy, agents, mcp, frames
---

# ADR 056: The Demo Counts Its Own Visits, and an Agent Arranges the Dashboard

## Context

The demo's data is a year of invented orders. A dashboard over real traffic
is a better proof that Janela works on rows nobody planted, and it is the
first thing here that an agent can arrange through `Janela::Tools` (ADR 053)
against a model that was not written for the tools. A real application had
just done the same for its own pages, with a `PageView` model, a concern and
a seeded frame, and that shape is small enough to copy unchanged.

## Decision

**One `PageView` row per full HTML page opened.** `page` is
`controller#action`, `path` is the URL without its query string, and
`viewed_on` is a stored date. Nothing says who the visitor was: no cookie,
no address, no user agent. A Turbo Frame request (every pane), a prefetch,
a robot, a non-HTML response, a redirect and a non-GET are not page views,
and a failure to record is reported and never breaks the page.

**The frame is rows, and an agent arranges it.** `test/dummy/bin/janela-mcp`
registers the tools with the official SDK, writes enabled, scoped as the
demo's own `policy_scope` is, and refuses to run outside development. The
repository's `.mcp.json` points at it. The frame itself is made by the host,
since there is no `create_frame` tool, and the panes are added with
`add_pane`. The result is frozen as rows in `db/seeds.rb`, because the hourly
reset deletes every frame and seeds are what bring one back.

**`PageView` is not reset.** `demo:reset` puts the invented orders and the
frames back and leaves the visits alone, so the numbers stay real.

## Consequences

- The dashboard starts empty on a fresh deploy and fills as people use the
  site. That is honest, and is not seeded with invented history.
- Counting a visit costs one insert per page. Fine for a demo on SQLite, and
  not a pattern to take to a busy host.
- A change to the dashboard is made through the tools and copied into the
  seeds. If the two drift, the seeds win after the next reset.
