---
Date: 2026-09-15
Status: Accepted
Related: ADR 001, ADR 003
Triggers:
  - changing how Janela's JavaScript reaches a host application
  - adding or changing a chart type or the chart controller
  - adding a JavaScript dependency
  - a host reporting that no Janela controller connects
  - securing or authenticating dashboard endpoints
Topics: javascript, npm, importmap, jsbundling, charts, chart.js, authorisation, packaging
---

# ADR 004: Charts and JavaScript Delivery

## Context

ADR 003 delivered Janela's Stimulus controller through the engine's
`config/importmap.rb`. Installing the gem into a real host application
for the v0.1.0 alpha showed that this reaches only importmap hosts. A
host that bundles JavaScript with esbuild, bun or webpack (jsbundling)
has no importmap, so the engine's pin is silently skipped and none of
Janela's JavaScript loads. The Turbo Frames still render, so the
failure is quiet: everything looks right and nothing cross-filters.

The alpha also required charts. Two questions had to be settled at
once: how a chart library reaches both kinds of host, and how a click
on a chart element becomes the same filter toggle a table button
already emits.

A third finding came from the same install. `Janela::ApplicationController`
inherits from the host's `ApplicationController`, which is only as
authenticated as the host makes it. In a host that authenticates per
controller, Janela's endpoints were public, and a host filter that
redirected to the sign-in page resolved its route against the engine's
route set rather than the host's.

## Decision

**Janela ships as a gem and an npm package, from the same repository.**
The gem carries the engine; a root `package.json` exposes the same
Stimulus controllers as `@retail-tasker/janela` with `exports` for
`./dashboard_controller` and `./chart_controller`. Both halves install
from GitHub with no registry publish:

```ruby
gem "janela", github: "retail-tasker/janela"
```

```bash
yarn add github:retail-tasker/janela
```

The package name is scoped because `janela` is already taken on npm,
and because that is the convention Rails-adjacent packages follow
(`@hotwired/turbo-rails`, `@rails/actiontext`). The engine's importmap
pins stay for importmap hosts and for `test/dummy`.

**Charts are Chart.js, driven by one Stimulus controller.** The
`janela--chart` controller builds a chart on `connect` from data
attributes the view already renders (`labels`, `values`, the filter
key, the selected value) and destroys it on `disconnect`, which is
what makes a chart survive Turbo replacing its frame on every
cross-filter. `Chart.register(...registerables)` is called explicitly:
importing `{ Chart }` alone yields a Chart with no controllers and
`"bar" is not a registered controller` at runtime.

Chart.js reaches each host the way its other JavaScript does. Bundler
hosts declare it as a peer dependency and resolve it from their own
`node_modules`. Importmap hosts get a vendored, self-contained ESM
bundle at `app/assets/javascripts/janela/vendor/chart.js`, pinned as
`chart.js` unless the host already pins its own. The vendored file is
self-contained on purpose: Chart.js's own `dist/chart.js` imports a
`./chunks/` sibling that Propshaft digesting breaks, and the UMD
build sets a global instead of exporting.

**A chart click is a table click.** The chart controller's `onClick`
maps the hit element's index to its label and dispatches
`janela--chart:toggle` with `{ key, value }` in `detail`. The dashboard
controller's `toggle` reads `{ ...event.detail, ...event.params }`, so
a table button (params) and a chart (detail) arrive identically and the
dashboard cannot tell them apart.

**Renderer is a helper option and part of the frame identity.**
`janela_visual Order, :revenue, by: :status, as: :bar`. The renderer is
whitelisted (`table`, `bar`) and included in the frame id, so a table
and a chart of the same measure can share a page.

**Selection state is rendered by the server.** The filter on a
visual's own dimension is not applied to its query, but it is what the
user clicked, so the view marks it: `aria-pressed` on the table button,
a solid bar against faded siblings on the chart. Because the frame
reloads on every filter change, server-rendered state needs no
re-application in JavaScript.

**Securing endpoints is a documented host pattern, not a knob.**

```ruby
Rails.application.config.to_prepare do
  Janela::ApplicationController.prepend_before_action do
    redirect_to main_app.new_session_path unless user_signed_in?
  end
end
```

Prepended, so it runs before filters on the host's `ApplicationController`
that assume a user (tenant lookup was the one that raised). Through
`main_app`, because inside an isolated engine a bare host route helper
resolves against the engine's routes. Blazer documents the same
`main_app` requirement.

## Consequences

- The npm package's `files` glob excludes `vendor/`, so registry or
  `github:` installs do not ship the vendored Chart.js. yarn 1's
  `file:` protocol copies the whole directory regardless; harmless,
  only relevant during local development against a sibling checkout.
- An importmap host with its own `chart.js` pin keeps it. The check is
  `packages.key?("chart.js")` in the engine's `config/importmap.rb` and
  depends on the host's importmap being evaluated first, which is the
  order importmap-rails uses.
- Bar is the only chart type. Adding another is a new value in
  `Visual::RENDERERS` and a `type` the controller passes through;
  nothing about delivery or the click contract changes.
- Propshaft in development rescans assets only when the Rails
  reloader fires, so a JavaScript-only change in an engine can appear
  stale until a Ruby or view file changes or the server restarts.
  Stale `public/assets` from an earlier `assets:precompile` shadows
  `app/assets/builds` entirely. Both are host development gotchas
  worth knowing when a controller "does not connect".
- A host whose sign-in route is not `new_session_path` adapts the one
  line. If the pattern proves awkward across hosts, the Blazer-style
  `Janela.before_action = :method_name` configuration is the fallback.
- CanCanCan hosts still get `model.all` silently (ADR 002). Unchanged
  here and tracked as a pre-public issue.
