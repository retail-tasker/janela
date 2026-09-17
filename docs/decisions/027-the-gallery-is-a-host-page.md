---
Date: 2026-09-18
Status: Accepted
Related: ADR 011, ADR 016, ADR 018, ADR 023, ADR 026
Triggers:
  - building or changing the gallery
  - adding a renderer
  - exposing what Janela can draw to a host
  - anything that would put JavaScript on the engine's own pages
Topics: rendering, host-integration, layouts, styling
---

# ADR 027: The Gallery Is a Host Page, Built from the Gem's Helpers

## Context

ADR 026 decided that a gallery of renderers belongs in the gem rather
than in the demo, because vitral reaches into the visualisation and a
host should see its own data drawn its own way. It did not say what "in
the gem" means, and investigating #39 showed that the obvious reading is
the one that cannot work.

The obvious reading is a page the engine serves, at the mount path,
alongside the frames index. ADR 018 rules it out in its own words: "the
engine's own pages deliberately load no Stimulus and no Chart.js." That
is why a chart pane renders as a table there, and `frames_test.rb`
asserts exactly that. A gallery of every renderer served by the engine
would render table as a table, bar as a table and line as a table. It
could not demonstrate the thing it exists to demonstrate.

The same constraint takes the live configuration panel with it. The
two-step form for adding a pane exists because, as the comment on
`panes/new.html.erb` puts it, "the engine's pages run no JavaScript, so
one select cannot refill another". A panel where changing a select
re-renders the pane beside it is that, exactly.

The way out is already built. `janela_pane(model, measure, by:, as:,
granularity:, limit:)` renders any pane into a host's own page, where
that host's JavaScript, layout and theme already are. ADR 011 sent panes
there deliberately. A gallery is a page of panes.

## Decision

**The gallery is a page the host owns, built from helpers and
enumerations the gem provides. The engine serves no gallery, and no
JavaScript is added to the engine's own pages.**

1. The gem's job is to make the page trivial to build: rendering a pane
   into a host page already works, and what can be drawn becomes a
   public enumeration rather than something a host reads out of a
   constant. A gallery has to ask what renderers exist, what
   granularities and limits are offered, and what a host's models
   declare, and each of those is a supported question.
2. The page itself is the host's: its route, its layout, its words. That
   is the same trade ADR 011 made and the reason a host's theme and
   assets are present at all.
3. The demo carries the reference implementation, and it is the one we
   look at. It is a host page like any other, so what works there works
   for a host that copies it.
4. Anything interactive in it is the host's JavaScript, which means the
   gem's own Stimulus controllers are available there as they already
   are for frames and charts. Nothing changes on the engine's pages,
   and ADR 011 and ADR 018 stand untouched.

## Consequences

A host gets a gallery by mounting a page rather than by installing the
gem, which is a real cost: it is not there on day one the way the frames
index is (ADR 013). We accept it, because a gallery that cannot draw a
chart would be worse than no gallery, and because the page is small when
the helpers and enumerations are right.

What the gem owes the page is now the work: an enumeration of renderers
and their options that does not require reaching into
`Janela::Query::RENDERERS`, and an answer for a host whose models
declare nothing yet, since a gallery with no data to draw still has to
say something useful.

There are three renderers today, table, bar and line, one of which is
the fallback the others degrade to. The gallery is therefore mostly a
frame for what comes next rather than a showcase of what exists, which
is the point of ADR 026 and worth saying plainly so nobody builds it
expecting a wall of charts.

If a gallery a host gets for free ever matters more than the engine's
pages staying JavaScript free, this is the decision to supersede, and
ADR 018 goes with it.
