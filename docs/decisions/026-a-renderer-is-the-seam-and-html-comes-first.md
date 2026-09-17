---
Date: 2026-09-18
Status: Accepted
Related: ADR 016, ADR 023, ADR 001, ADR 012
Triggers:
  - adding a visualisation or a renderer
  - reaching for a charting library
  - anything that would make how a pane is drawn configurable
  - building the gallery
Topics: rendering, styling, configuration, host-integration
---

# ADR 026: A Renderer Is the Seam, and HTML Comes First

## Context

Janela draws bar and line panes with Chart.js today, tables with plain
HTML, and a value pane with a number in a div. That mix happened rather
than being decided, and the next visualisation makes the question
unavoidable: is Janela a wrapper around a charting library, or something
that draws with whatever suits and reaches for a library only when it
has to?

Three things are being asked at once, and they have one answer between
them.

**Where a charting library sits.** A pane already names its renderer, so
`renderer: "bar"` is a name on a record and the code behind it is ours.
Nothing about Chart.js is in that name. Treating the renderer as the
seam means a visualisation can change how it is drawn without any host
noticing, and a host that wants a different bar chart replaces one small
piece rather than the library.

**Whether a visualisation needs JavaScript at all.** Most do not. A bar
chart is a div with a percentage width. A ranked list is a table with a
bar behind each row. A sparkline is inline SVG the server can render
whole. Drawn that way the pane is in the HTML: it is there before any
JavaScript loads, it prints, a screen reader can read it, and a click to
cross-filter is a real button, which is already how the table renderer
behaves and already how ADR 024's keyboard support works. A canvas can
do none of that without being taught each one.

The engine's own frame page already proves the point from the other
side: it loads no chart runtime, so it renders a chart pane as a table,
and the pane is still useful.

**Whether a host should choose the charting library.** A setting for
this is the obvious idea and the wrong one. It would mean every renderer
written against an interface wide enough for any library, an adapter per
library, and a test matrix multiplied by the number of libraries anyone
has configured. ADR 001 kept Janela to a load bearing 5%, and the
project's stance is that forking a small piece is a normal way to use
this library, not a fallback. A renderer small enough to read in one
sitting is worth more than a plugin system.

## Decision

**A renderer is the seam. Server rendered HTML and CSS are the default,
a JavaScript library is an implementation detail of the renderers that
need one, and there is no setting for choosing it.**

1. A pane's `renderer` names a way of drawing, not a technology. What is
   behind that name can change without a host changing anything.
2. A new visualisation is built in HTML and CSS unless it cannot be. A
   library earns its place by doing something the document cannot:
   dense data, animation, interaction a button cannot express.
3. Every renderer degrades to something readable with no JavaScript,
   because a pane is rendered on the server before anything runs.
4. No `Janela.chart_library` or equivalent. A host that wants a
   different chart replaces a renderer, and the renderers stay small
   enough that this is reasonable.
5. Vitral reaches into the visualisation, not only the page around it.
   The palette a bar takes, how a pane is framed and how a selection is
   shown are part of the theme (ADR 023), which is what makes a
   visualisation gallery a property of the gem rather than of the demo.

## Consequences

The gallery becomes gem work: a mountable page listing every renderer as
a live pane against whatever data the host has, with the declaration
that produced it beside it, and the theme applied. It is documentation
that cannot go stale, because it is the real thing rendering. It is also
the roadmap, since a renderer that does not exist yet is a visible gap
rather than a line in a backlog.

Chart.js stays for bar and line until a renderer that does not need it
is written and measured against it. Nothing here asks a host to change
anything today.

The cost is that some visualisations are more work in HTML and CSS than
in a library, and we accept that where the result stays readable without
JavaScript. Where it does not, the library is the right answer and the
renderer says so.
