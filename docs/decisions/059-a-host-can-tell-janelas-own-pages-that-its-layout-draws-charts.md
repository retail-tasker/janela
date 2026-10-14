---
Date: 2026-10-14
Status: Proposed
Related: ADR 011, ADR 018, ADR 023, ADR 046
Triggers:
  - a chart pane renders as a table on one of the engine's own pages
  - changing what the engine's frame page passes to janela_frame
  - adding a setting that says what a host's layout loads
  - a host gives Janela's own pages its own layout
Topics: rendering, charts, layouts, engines, host-integration, dogfooding, settings
---

# ADR 059: A Host Can Tell Janela's Own Pages That Its Layout Draws Charts

## Context

The demo's Site visits dashboard had bar charts, and the page people reach
from the Dashboards list showed them as tables. That page is the engine's own
frame page, which passes `charts: false` to `janela_frame` because its minimal
layout loads no chart runtime (ADR 018). The maintainer looked at it three
times and called it trash each time. The data was right and the page was
doing exactly what ADR 018 says, which is the trouble: a decision written for
a host with no layout of its own was applied to a host that has one.

ADR 018 closed with its own condition: "If the engine ever gains a way to
know a host's asset setup, this decision is worth revisiting, because the
better answer is a chart that draws everywhere."

### Measured

Against the live demo, 2026-10-14.

**The demo gives the engine's frame page its own layout, and that layout
loads the runtime.** `Janela::FramesController.layout` is overridden (ADR 011,
ADR 022), the page carries the `janela--frame` Stimulus controller and has no
console errors, and `/visits`, which renders the same frame through the host's
own page, draws both bar charts. The only difference between the two pages is
the `charts: false` in the engine's view.

**The engine cannot tell.** Whether a layout loads Chart.js is a fact about the
host's bundler and importmap. A layout other than Janela's own may load
nothing, and Janela cannot read it.

### What was considered

**Detect a host layout and assume it draws charts.** Rejected for ADR 018's
reason: it would guess. A host layout that loads Turbo and no Chart.js would
get empty holes where tables were, which is the failure ADR 018 was written
to remove.

**Detect JavaScript at runtime and swap.** Rejected. The page is meant to be
correct before any JavaScript, and a swap would flash a table first.

**Always draw charts on the engine's pages.** Rejected. The default install,
with Janela's own minimal layout, has no runtime.

## Decision

**A host says so, once.**

```ruby
# config/initializers/janela.rb
Janela.charts_on_own_pages = true
```

It defaults to `false`, so a host that sets nothing renders exactly what it
does today. When it is `true` the engine's frame page passes `charts: true`,
and a bar or line pane draws. It is a setting and not a convention because it
is the one thing the engine cannot see and cannot guess, which is what ADR 021
says a setting is for. A host turns it on when it has given Janela's own pages
a layout that registers the Stimulus controllers and loads Chart.js, and not
before.

The demo sets it, because its layout is such a layout.

## Consequences

- **Nothing changes for an existing host.** The default is ADR 018's behaviour.
- **A host that sets it without the runtime gets empty chart holes** on the
  engine's pages. The README says what the setting promises, and the doctor
  does not check it, because what a layout loads is not something it can read
  (ADR 035).
- **ADR 018 is superseded in part**: the engine's frame page is no longer
  always table-only. Its rule for a page with no runtime stands.
- **The pane page opened directly is unchanged.** It is not given a setting
  here, and a host that wants a chart there still uses a layout and a frame of
  its own, as README says. This covers the frame page, which is where the
  Dashboards list leads.
- **What would change this decision:** the engine gaining a reliable way to
  read a host's asset setup, at which point the setting is removed and the
  chart simply draws.
