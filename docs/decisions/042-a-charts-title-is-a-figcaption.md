---
Date: 2026-09-28
Status: Accepted
Related: ADR 016, ADR 018, ADR 024, ADR 026, ADR 036
Triggers:
  - adding a title, caption or visible label to any renderer
  - changing what a chart pane's markup contains, or what carries its classes
  - extending or reading `.janela-own-headings`
  - deciding what a theme may target in `janela.css` (ADR 036)
  - a chart type that cannot sit inside a figure the way bar and line do
Topics: rendering, charts, accessibility, styling, public-api, theming
---

# ADR 042: A Chart's Title Is a Figcaption, and the Canvas Points to It

## Context

#61 found that a chart pane (`renderer: bar` or `renderer: line`) never
shows its title to a sighted reader. `janela/queries/_query.html.erb`
renders it as a bare `<canvas role="img" aria-label="<%= query.title
%>">`, and `chart_controller.js` passes the same string only into the
dataset's `label`, with the legend that would draw it turned off. A
table pane's `<caption>` and a single value pane's `<span
class="janela-value-label">` both render the same `query.title` as
visible text. A chart pane is the one renderer that does not.

This is not new. #26's own investigation, closed and shipped in 0.8.0,
already found and recorded the same fact while building
`.janela-own-headings`:

> The table's and the single value's are visible ... The chart's is
> not ... A chart pane is already announced without being seen.

#26 used that as the *model* the other two renderers should be brought
into line with for hiding purposes, not as a gap to close, and the
comment above `.janela-own-headings` in `janela.css` still says so:
"a chart pane needs nothing: its title was only ever an aria-label."
That sentence is accurate about the code and wrong about the design.
Nobody decided a chart should be the one renderer with no visible
title; it fell out of `legend: { display: false }` turning off the
only thing that would have drawn it.

### Why the issue's own fix does not hold up

#61 proposes `plugins.title: { display: true, text: this.titleValue }`,
Chart.js's own title option. It works, and it was rejected, for three
reasons that all come from the same place: the text would live inside
the canvas bitmap rather than in the document.

- **It cannot be hidden by `.janela-own-headings`.** That rule hides
  the table's `<caption>` and the value's `<span>` visually while
  leaving them in the accessibility tree, by targeting real elements
  with CSS (#26). A host with its own heading above a chart pane would
  have no way to suppress the canvas-drawn one short of reconfiguring
  Chart.js, so the one mechanism #26 shipped for this exact problem
  would not cover the one renderer it was modelled on.
- **It contradicts ADR 026 directly**, not just in spirit. That
  decision's third numbered point is "every renderer degrades to
  something readable with no JavaScript, because a pane is rendered on
  the server before anything runs." A title Chart.js paints is not
  there until the chart runtime has loaded and `connect()` has run;
  server-rendered text is there in the same response that draws the
  rest of the pane.
- **It is not text.** Not selectable, not found by the browser's find
  bar, not sized by the vitral theme's typography, not read by a
  screen reader that has switched off image descriptions but still
  reads a page's headings.

None of that is a knock on Chart.js. It is the same argument ADR 026
already settled for the chart itself: a renderer draws in HTML unless
it genuinely cannot, and a caption is not a case a canvas is needed for.

### Where the title should live

A table pane already pairs a `<table>` with a `<caption>`. HTML has the
matching pair for an image with a caption: `<figure>` and
`<figcaption>`. Wrapping the existing canvas in one costs nothing Chart.js
cares about, since `new Chart(this.element, ...)` still receives the
canvas itself, unchanged.

One thing about that pairing had to be checked rather than assumed:
`<figcaption>` gives its text to the `<figure>` as a description, not
to an arbitrary element nested inside it. A screen reader is not
guaranteed to treat the figcaption as the canvas's own accessible name
just because it sits beside it. The canvas needs an explicit
`aria-labelledby` pointing at the figcaption's id; the implicit
figure/figcaption pairing is not enough on its own and this record
does not lean on it.

### What was considered

**Chart.js's `plugins.title`**, #61's own suggestion. Rejected above.

**A bare sibling, `<div class="janela-chart-title">` before an
unwrapped canvas.** Considered and rejected only because HTML already
has the element built for exactly this pairing, and using it costs
nothing: a chart pane on its own page already reads as a captioned
figure to a browser's own outline, not just to Janela's CSS.

**Leaving `aria-label` on the canvas alongside the new visible text.**
Rejected: two independent strings for the same title can drift, and
`aria-labelledby` pointing at the one that is now visible cannot.

## Decision

**A chart pane's title is a `<figcaption>` inside a `<figure>` that
wraps the canvas, and the canvas's accessible name is
`aria-labelledby` pointing at it.**

```erb
<figure class="janela-pane">
  <figcaption class="janela-chart-title" id="<%= title_id %>"><%= query.title %></figcaption>
  <canvas class="janela-chart"
          data-controller="janela--chart"
          ...
          role="img" aria-labelledby="<%= title_id %>"></canvas>
</figure>
```

**`janela-pane` moves from the canvas to the figure; `janela-chart`
stays on the canvas.** The figure is now the grid item and the thing a
theme styles as a pane, the same job `<table class="janela-pane">` and
`<p class="janela-pane janela-value">` already do for the other two
renderers. The canvas keeps `janela-chart` because that is what
`canvas.janela-chart { width: 100% !important; max-height: 20rem; }`
and the Stimulus controller both already target, and because #61's own
system test selects `canvas.janela-chart` directly; nothing that
selects the canvas by that class alone stops matching. What stops
matching is anything that selected `.janela-pane.janela-chart` as one
element, which is the breaking part of this change.

**`janela-chart-title` joins the pane primitives on the contract**
(ADR 036), the same group `janela-value-label` and a table's `caption`
selector are already in. Its base legibility rule (size, weight,
spacing) goes in `janela.css` next to the other two, not in vitral,
for the same reason theirs does: a pane has to be legible with no
theme installed.

**`.janela-own-headings` gets a third rule.** It already hides the
table's caption and the value's label visually while keeping them in
the accessibility tree; `figcaption.janela-chart-title` joins that
selector, and the comment above it that says a chart pane needs
nothing is corrected to say why it no longer does.

**Chart.js's dataset `label` and the disabled legend are unchanged.**
The visible title no longer depends on either, which is the point:
it is there whether or not the chart runtime ever finishes loading.

## Consequences

- A chart pane finally shows its title the way the other two renderers
  do, closing #61 and the half of #26 that was left standing on
  purpose.
- Breaking change: `janela-pane` is no longer on the `<canvas>`, and
  `aria-label` is replaced by `aria-labelledby`. Anything a host wrote
  against either goes in `UPGRADING.md` (ADR 015), and the doctor's
  list of things to check for an old release is worth a line.
- `docs/theming.md` gains `janela-chart-title` in the pane primitives
  table (ADR 036), and `janela.css` gains its rule and its line in
  `.janela-own-headings`.
- The system test in `test/system/chart_test.rb` asserts
  `canvas.janela-chart[aria-label='...']` today; it moves to asserting
  the figcaption's text and the `aria-labelledby` wiring, which is
  build work, not a decision.
- Chart.js keeps drawing bar and line exactly as it does today; nothing
  about `chart_controller.js`'s own options needs to change for this,
  only the markup around it.
- What would change this decision: a chart type that cannot sit inside
  a figure the way bar and line do, or a case where wrapping the canvas
  measurably breaks Chart.js's own sizing against its parent. Neither
  is expected, since the canvas already sits one level inside a turbo
  frame today and gains only one more ordinary block-level ancestor,
  but it is exactly the kind of assumption to re-check against the demo
  before the build lands rather than after.
