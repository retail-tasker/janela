---
Date: 2026-09-16
Status: Accepted
Related: ADR 009, ADR 011, ADR 013, ADR 016
Triggers:
  - rendering a pane where the chart runtime may be absent
  - adding a renderer, or changing what a renderer means
  - a pane rendering as something other than its row says
  - the engine serving a page of its own
Topics: rendering, renderers, charts, progressive-enhancement, engines
---

# ADR 018: A Table Is the Universal Renderer

## Context

ADR 013 promised a host could install the gem and navigate its own
dashboards the same day, which is why the engine serves an index and a
frame page of its own. ADR 011 established that those pages render in
the engine's minimal layout, which loads none of the host's assets
because the engine cannot know their names or bundler. ADR 014 then
had a frame render its panes inline so that the page is correct before
any JavaScript.

Correct, but not complete. A chart pane is a `canvas` the Stimulus
chart controller fills in, and the engine's own pages deliberately
load no Stimulus and no Chart.js. So a frame with two chart panes
served by the engine shows two empty holes the height of a chart. The
claim that those pages are a correct static dashboard was not true.

The engine could not fix this by loading a chart runtime: emitting a
working module graph needs the host's importmap or bundle, which is
exactly what ADR 011 said the engine cannot assume.

## Decision

**Where no chart runtime exists, a chart pane renders as a table.**

The engine's own frame page passes `charts: false` to `janela_frame`,
and a pane whose renderer is `bar` or `line` renders its table instead.
A host's own page renders charts normally, because a host that
registered the Stimulus controllers has the runtime.

This is not JavaScript detection and it is not a fallback that guesses.
The engine's pages deterministically have no chart renderer, so they
deterministically use the one that needs nothing.

**A renderer is a viewing choice, not part of the pane.** ADR 009
already decided this when it made a snapshot store results rather than
markup, and this follows from it: the row records that a pane is best
seen as a bar chart, and a surface that cannot draw one shows the same
numbers another way. Nothing about the data changes.

**A table is the renderer that always works**, needing no JavaScript,
no canvas and no measurement, which is why it is the one to fall back
to rather than an error or an empty space.

## Consequences

- The engine's own pages are now what ADR 013 promised: a host mounts
  the engine and reads a real dashboard the same day, with no
  JavaScript wiring at all.
- The same frame can look different in two places: a bar chart on a
  host's page and a table on the engine's. That is the cost, it will
  surprise someone, and the README says so plainly rather than leaving
  them to discover it.
- Cross-filtering is still absent from the engine's pages, because
  that genuinely needs Stimulus. They are for reading, and a host that
  wants interaction renders the frame in its own page, which is one
  helper call.
- `charts:` is a rendering option rather than a stored column, so no
  migration and nothing for an analyst to get wrong.
- If the engine ever gains a way to know a host's asset setup, this
  decision is worth revisiting, because the better answer is a chart
  that draws everywhere.
