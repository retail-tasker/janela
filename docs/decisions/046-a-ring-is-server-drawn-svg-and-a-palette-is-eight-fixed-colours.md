---
Date: 2026-09-29
Status: Accepted
Related: ADR 016, ADR 018, ADR 024, ADR 026, ADR 036, ADR 037, ADR 042
Triggers:
  - adding a renderer, or a colour a renderer draws with
  - adding a custom property to janela.css or documenting one in docs/theming.md
  - drawing a part-to-whole split, a doughnut or a pie
  - deciding what a chart does with more categories than it has colours
  - a chart pane that must be readable, printable or operable without JavaScript
Topics: rendering, styling, theming, charts, accessibility, roadmap
---

# ADR 046: A Ring Is Server Drawn SVG, and a Palette Is Eight Fixed Colours

## Context

#30, raised from a real install: a two-category split has to be drawn as
two bars, and a ring reads better for a part-to-whole. It asks for
`doughnut` and `pie` renderers, a categorical palette to make them
readable, and two smaller fixes to the chart controller. It assumes
Chart.js, because the controller already hands its type straight to
it. ADR 037 puts it in 1.0 and #30 is the only item there that adds to
what a pane can be drawn as.

Measured against the demo before deciding:

- `renderer: "doughnut"` raises `Janela::BadRequest` today. The whitelist
  is `Janela::Query::RENDERERS` (`%w[table bar line]`). The issue says
  `Pane::RENDERERS`, which does not exist. The pane form, `Janela.renderers`,
  the `janela.renderers.*` locale keys, the gallery and stored pane rows
  all read that one constant.
- Chart.js is vendored with its doughnut and pie controllers, so the
  canvas route needs no dependency.
- Switching a live bar chart's config to `doughnut` with the controller's
  own options gives a ring in one colour: `backgroundColor` holds one
  distinct value across four segments, so the boundaries are hairlines.
  The unconditional `y` scale is configured on it too. Both complaints in
  the issue are real.
- `--janela-accent` is the only colour Janela publishes
  (`docs/theming.md`). Vitral's `--vitral-pane-1..5` are translucent glass
  tints for backgrounds, not colours to draw data in.
- The demo's dimensions have four, two and three values (one of them the
  `(none)` group). A categorical dimension is bounded only by 1000
  (ADR 025), so a palette will meet more categories than it has colours.
- The dataviz palette validator (a fixed-order eight colour categorical
  set) passes on adjacent pairs in light mode with the accent as slot 1:
  worst adjacent colour vision separation 9.1, normal vision 19.6, against
  targets of 8 and 15. It warns that four slots (accent, aqua, yellow,
  pink) fall under 3:1 contrast against a light surface, which obliges
  visible labels or a table view. The same eight hues stepped for a dark
  surface pass too (8.4, 19.3, contrast all 3:1 or better).

### What was considered

**Chart.js `doughnut` and `pie`, as the issue proposes.** The smallest
change: a whitelist entry, a palette, and conditionals around the scale
and legend. Rejected. ADR 026 makes server rendered HTML and CSS the
default, a library earning its place by doing what the document cannot,
and a ring is inline SVG arcs, which the document can do. A canvas is
blank without JavaScript, does not print as text, has nothing focusable
behind it (ADR 024 already says as much of bars) and puts the labels
inside a bitmap. It would also leave the issue's two "smaller things" as
work: the scale and legend switches exist only because the canvas has to
be told what it is.

**A CSS `conic-gradient` ring.** Also HTML and CSS, and shorter than SVG.
Rejected. A gradient is one element, so a slice has no hit target, no
native tooltip and no way to take a gap or a dimmed state of its own.
Every one of those would have to be rebuilt from the legend alone.

**Cycle the palette.** #30 says "N distinct colours cycling". Rejected.
The 9th slice reusing the 1st colour draws two different categories the
same, next to a legend that says they are different. The rule is fixed
order and a neutral past the last slot.

**Leave bars on the one accent.** The recommendation put to the
maintainer, to avoid changing panes people have already themed.
Overridden: the palette applies to bars as well. See Consequences for
what that changes and what a host does.

## Decision

**`doughnut` and `pie` are renderers drawn on the server as inline SVG
with a legend that is a table of buttons, and Janela publishes a
categorical palette of eight fixed colours that bars, doughnuts and pies
draw with.**

**The ring is SVG, and its legend is the control.** Each slice is a `path`
carrying the same `janela--frame#toggle` action a table button does, a
`<title>` child so a hover names it, and a gap between slices so no
boundary depends on colour alone. A doughnut is a pie with a hole. The
pane is a `figure` with a `figcaption` title (ADR 042), the SVG points to
it, and beside the ring is a legend of real buttons, each with a swatch,
the label and the measure's formatted value (ADR 020). The legend is what a
keyboard, a screen reader and a touch user operate, and it is the visible
labelling the palette's contrast warning obliges. Ctrl and Cmd add and
remove as in ADR 024, because they are the same buttons. It works,
printed and unstyled, with no JavaScript, and the engine's own frame page
draws it (ADR 026, rule 3).

**A ring draws only what a ring can.** A slice with a zero value is left
out of the ring and stays in the legend. A pane with a negative value is
drawn as the table renderer's markup instead, since a part of a whole
cannot be negative, and the pane says so in words rather than drawing
something wrong. Nothing raises.

**The palette is eight ordered custom properties and a neutral.**

```css
:root {
  --janela-series-1: var(--janela-accent);
  --janela-series-2: #eb6834;
  --janela-series-3: #1baf7a;
  --janela-series-4: #eda100;
  --janela-series-5: #e87ba4;
  --janela-series-6: #008300;
  --janela-series-7: #4a3aa7;
  --janela-series-8: #e34948;
  --janela-series-other: #8c8c8c;
}
```

Slot 1 is the accent, so a host that has set `--janela-accent` still has
its own colour on the first bar. The set is the reference instance of the
validated palette with the accent standing in for its blue, and it was
run through the validator in that form. A colour is chosen by a
category's position in the result, first to eighth, and every category
past the eighth takes `--janela-series-other`. Never cycled. A host
that wants a longer pane says `limit: 8` (ADR 007), which is the honest
answer for a ring anyway, and the documentation says a ring suits few
slices. Lines are one series and keep the accent.

**The selected state is the existing one, over each slice's own colour.**
With nothing selected every slice and bar is solid. With a selection the
unselected ones dim to the same reduced opacity a bar already uses
(`colours()` in `chart_controller.js`) and the selected ones stay solid.
A dimmed set of eight colours stays distinguishable because opacity is
applied to the slice, not the palette.

**Published, and therefore frozen at 1.0.** `--janela-series-1..8`,
`--janela-series-other` and the ring's and legend's class names join the
contract in `docs/theming.md` in the same change (ADR 036). The class
names are chosen in the build and documented there, not here. The dark
values that passed the validator are recorded in `docs/theming.md` for a
theme to use. `janela.css` ships no dark scheme today (ADR 023 leaves that
to a theme), and adding one is not this decision.

**The chart controller changes only for bars.** It draws bar and line, so
the two conditionals in the issue (`beginAtZero` on an axis-less chart and
the hidden legend) do not arise and are not added. Bars read their
per-bar colours from the palette on the element, the way `accentColour`
already reads `--janela-accent`.

## Consequences

- A part-to-whole split has a renderer, and it is a table to a screen
  reader, a picture to everyone else, and a link on a slice to anyone with
  a mouse.
- `Query::RENDERERS` becomes `table bar line doughnut pie`. `Janela
  .renderers`, the pane form, the locale keys (`janela.renderers.doughnut`
  and `.pie`), the gallery and its tests follow from that one constant and
  need entries. A model with no suitable dimension shows the renderer as
  unavailable, as the gallery does for any other. Additive.
- **Bars change appearance, in a minor release.** Every existing bar pane
  goes from one accent colour to one colour per bar. A host that themed
  bars through `--janela-accent` keeps that colour on the first bar and
  the accent for selection and hover, and gets new colours on the rest.
  A host that wants the old look sets `--janela-series-2` to
  `--janela-series-8` to the accent. It needs an `UPGRADING.md` entry
  saying exactly that, in the release that carries it (ADR 015). The
  doctor cannot see this from source.
- **Colour follows position, not the category.** A filter on another
  pane can reorder this pane's categories, and a colour then moves with
  its rank. The dataviz rule that colour follows the entity, so a filter
  never repaints the survivors, is not met, because Janela has no registry
  of what a category is. The label is always beside the colour (legend or
  axis), which is the reason this is acceptable, and the cost is real. What
  would change it: a host declaring a colour for a dimension value,
  which is a new piece of DSL and its own ADR.
- Four slots fall under 3:1 contrast on a light surface. The legend is the
  visible labelling the validator asks for, and a bar has its axis.
  Adjacent colour vision separation is 9.1 and above, but only the first
  three slots pass when every pair is compared, and a ring with a fifth
  slice puts colours side by side that are not adjacent in the palette.
  That is why the gap and the legend exist and why the documentation
  recommends few slices.
- A slice's hit target is small when it is a small share. The legend row
  is always the full target.
- The demo proves it. The home page's "This one is live" frame gains a
  doughnut pane (revenue by status), the gallery shows both new renderers
  through `Janela.renderers`, and a system test clicks a slice and a legend
  button and sees the other panes re-scope. The copy that says how many
  panes there are changes with it, once, together with the time pane from
  ADR 045.
- What would change this decision: a chart that needs what SVG cannot do,
  such as animation or many thousands of marks, is the case ADR 026 keeps
  the library for, and this one does not fit it. A host that needs a
  category to keep its colour across filters is the case above.
