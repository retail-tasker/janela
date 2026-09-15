---
Date: 2026-09-15
Status: Accepted
Related: ADR 003, ADR 005
Triggers:
  - changing which layout a pane renders in
  - a host reporting NameError from its own layout when a pane loads
  - adding anything to the engine's own layout
  - making the dummy application unrepresentative of a real host
Topics: layouts, engines, panes, urls, install
---

# ADR 011: Panes Do Not Render in the Host Layout

## Context

ADR 005 promised that a pane opened directly "gets that pane alone
inside the host's layout". Dogfooding 0.2.0 in a second application
showed that promise is a bug. `Janela::ApplicationController` inherits
the host's `ApplicationController` and therefore the host's layout,
but the engine is `isolate_namespace`d, so a route helper written in
that layout resolves against Janela's routes and raises `NameError`.
Almost every real application layout has a nav, so almost every host
is broken on install, and a whole dashboard of frames goes blank.

The gem's own dummy application has no route helper in its layout,
which is exactly why the suite, the demo and the first host install
never saw it. The first host squeaked through because its only layout
helpers were an Active Storage URL and a PWA manifest path rather
than nav links.

## Decision

**A pane requested inside a Turbo Frame renders with no layout.**
Turbo extracts the matching frame from the response and discards
everything around it, so a layout was never doing any work there. This
alone fixes every dashboard, which is how panes are almost always
requested.

**A pane requested directly renders in Janela's own layout.** A
minimal layout in the engine, carrying only a charset, a viewport, the
CSRF and CSP tags and a `yield`. It keeps ADR 005's shareable pane
alive and cannot depend on anything the host has not got.

```ruby
layout -> { turbo_frame_request? ? false : "janela/application" }
```

**A directly opened pane is therefore unstyled, and that is
documented.** Janela ships no CSS (issue #15), and the engine layout
deliberately loads none of the host's assets, because it cannot know
their names or whether the host bundles or uses importmap. A host that
wants its own styling on direct pane URLs sets
`Janela::ApplicationController.layout "application"` in an
initializer, and is told the condition: that layout must not call a
bare host route helper, since inside an engine those need a
`main_app.` prefix.

**The dummy application's layout gains a route helper.** The dummy is
the gem's stand in for a real host, and a stand in that omits the most
common thing a layout contains is not doing its job. A `link_to` to
the dashboard makes the suite fail if a pane ever renders in the host
layout again.

## Consequences

- ADR 005's sentence about the host layout is superseded by this ADR.
  The rest of ADR 005, the URL grammar and the naming table, stands.
- Direct pane URLs render a table but not a chart, because no
  JavaScript is loaded. Shareable pane links are therefore honest for
  data and plain for visuals until a host opts its own layout in.
  Acceptable: the pane URL's job is to show a number to someone, and
  the dashboard is where charts live.
- The engine now owns a view that a host might want to override.
  `app/views/layouts/janela/application.html.erb` is overridable by
  the usual Rails precedence, which is the Rails answer and needs no
  configuration of Janela's own.
- The lesson generalises beyond layouts: the dummy application should
  resemble a real host in the ways hosts actually vary. Each time a
  host finds something the dummy could not, the dummy gains that
  characteristic rather than the fix being verified only by hand.
