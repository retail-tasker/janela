---
Date: 2026-09-13
Status: Accepted
Related: ADR 001, ADR 002
Triggers:
  - changing how filter state is shared between visuals
  - adding a visual type, or changing what a visual renders
  - exposing a model or query over HTTP
  - adding authentication or authorisation to dashboards
  - deciding whether a behaviour needs a browser test
Topics: cross-filtering, stimulus, turbo, security, authorisation, testing
---

# ADR 003 -- Cross-filtering with Turbo Frames

## Context

Cross-filtering is the reason Janela exists. No gem in the Rails
ecosystem lets clicking a value in one visual re-scope every other
visual on the page, and ADR 001 named it one of the two things worth
building.

The obvious implementations all pull in machinery Janela does not
want: a JS framework holding client state, Turbo Streams broadcasting
updates, or a WebSocket. Each would contradict the first principle of
no JS framework and no build step.

Exposing visuals over HTTP also raises a question the DSL did not.
A visual is identified by a model, a measure and a dimension, and
those arrive as request parameters -- so something has to stop a
parameter naming an arbitrary class.

## Decision

**A visual is a Turbo Frame whose `src` carries the filters.** Turbo
reloads a frame whenever its `src` attribute changes, so a Stimulus
controller holding shared filter state only has to rewrite each
frame's `src`:

```js
filtersValueChanged() {
  this.visualTargets.forEach((visual) => {
    const url = new URL(visual.dataset.janelaSrc, window.location.origin)
    for (const [key, value] of Object.entries(this.filtersValue)) {
      url.searchParams.set(`q[${key}]`, value)
    }
    if (visual.src !== url.href) visual.src = url.href
  })
}
```

No streams, no sockets, no state library. Filters are Ransack params
per ADR 002, so they stay readable and shareable in the URL. Clicking
a value already applied removes it.

**A visual ignores filters on its own dimension.** Otherwise clicking
"paid" in a revenue-by-status visual collapses that visual to the
single bar that was clicked. The rule is per-dimension rather than
per-visual: a visual grouped by region ignores region filters even
when a different visual originated them, so region totals stay
comparable. This is one line in `Janela::Visual` and needs no
tracking of which visual a filter came from.

**Only models that declare a `janela` block are addressable.**
Declaring the block registers the model's name, and the registry is
a strict allowlist -- a request parameter can never constantize an
arbitrary class. Names are stored rather than class objects so a
reloaded model leaves nothing stale behind. A lookup that misses in
development calls `eager_load!` rather than constantizing the
parameter to find out whether it is valid.

**Authorisation needs no configuration.** `Janela::ApplicationController`
inherits from `Janela.parent_controller` (the host's
`ApplicationController` by default), so the host's authentication
filters already apply. Scoping calls `policy_scope` when the host
defined it and falls back to `model.all`, which means Pundit users
get authorisation automatically without Janela depending on Pundit.

**Cross-filtering gets a browser test.** Request tests cannot prove
that clicking re-renders other frames, and that behaviour is the
product. `test/system/cross_filtering_test.rb` drives real Chrome;
CI runs it as a separate job so the unit matrix stays fast.

## Consequences

- Each filter change refetches every visual, one request per frame.
  Fine at the scale a dashboard page renders; a page with many
  visuals will want debouncing or a combined endpoint later. Do not
  optimise before a real dashboard shows the problem.
- Filter state lives in frame `src` attributes, not in the page URL,
  so the browser back button does not step through filter changes and
  a filtered dashboard cannot yet be shared as a link. Promoting
  filter state to the page URL is the obvious next step and was left
  out deliberately.
- The host registers the Stimulus controller explicitly
  (`application.register("janela--dashboard", JanelaDashboardController)`).
  One documented line, rather than Janela reaching into the host's
  Stimulus instance.
- Visuals render as tables. Charts wrap an existing library off the
  same server-supplied values and change nothing about the mechanism.
- `turbo-rails` and `stimulus-rails` become runtime dependencies,
  which is what "built on Ruby and Stimulus" already implied.
- CI now needs Chrome for one job. Accepted because the alternative
  is that the product's central claim is only ever verified by hand.
