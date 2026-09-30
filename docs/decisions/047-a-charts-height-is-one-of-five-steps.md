---
Date: 2026-09-30
Status: Accepted
Related: ADR 005, ADR 012, ADR 016, ADR 029, ADR 036, ADR 037, ADR 042, ADR 046
Triggers:
  - giving a chart pane a height, an aspect ratio or any size of its own
  - adding a parameter to the pane URL, or a column to janela_panes
  - adding a class to the scale in janela.css, or a wrapper inside a chart pane
  - a chart that is too tall, too short or squashed in a stored frame
  - deciding what a renderer does with a setting that is not meant for it
Topics: charts, css, layout, styling, public-api, panes, frames, urls
---

# ADR 047: A Chart's Height Is One of Five Steps, and Unset Changes Nothing

## Context

#24: a chart draws with Chart.js's defaults, `responsive` and
`maintainAspectRatio: true` at 2:1, and a host cannot correct it from
outside. A second report widened it: a stored frame has no height
vocabulary at all. Its layout is width only, `columns`, `gap` and `span`
(ADR 012), so an analyst with a three-row frame of charts could make it
shorter only by swapping the charts for tables, which changes what the
dashboard says to change how tall it is.

Measured in a browser against the demo before deciding, and two things the
issue assumed turned out to be wrong.

**A chart is not enormous today.** A full width line in a 1020px column
renders 1020 by 320 and a bar in one column of three renders 301 by 150.
`canvas.janela-chart { max-height: 20rem }` already caps it at 320px, and
the canvas bitmap and its CSS size agree.

**A host can lower a chart from outside and cannot set one.** A host's
`max-height: 120px !important` took the line to 1020 by 120, redrawn
rather than squashed, so it does not "fight the resize loop". But
`height: 240px !important` on the bar is ignored (still 150, because the
height is derived from the width), and `min-height: 240px` stretches the
bitmap: the box is 240 and the chart inside it is 150, so it is drawn
distorted. Exactly N tall, or taller than 2:1, cannot be said from outside.

**What works is a box of fixed height around the canvas.** Built fresh with
`maintainAspectRatio: false` inside a `position: relative` box, a chart
takes the box's height exactly, redraws when the box is resized, and does
the same in a 300px column. (Patching the option onto a chart that was
built with the aspect ratio on gave unreliable readings, so a height has
to be known when the chart is made.) Five heights derived from the spacing
unit, `--janela-space` at its default of 0.25rem, measured at 96, 160, 224,
320 and 448 pixels and each came out exactly. The fifth is squashed to 320
by the existing `max-height: 20rem` unless that rule is lifted inside the
box.

### What was considered

**Pixels, `height: 240`, as the issue proposed.** Works for the helper and
not for a row. ADR 016 keeps an analyst's number out of CSS: a stored
integer selects a class that is already written, and a pane row taking
pixels would be the first place an analyst's number reaches a style. A
scale is the vocabulary `span`, `columns` and `gap` already speak.

**`aspect:` instead of, or beside, `height`.** An aspect ratio means the
height still follows the width, so it does not help a stored frame whose
panes sit in different columns, and it would be a second way to say what a
height says. Not needed, and the issue itself said one of the two was
probably enough.

**A frame-level maximum.** It sizes every pane at once but is a second way
to say what per pane heights already say, and it cannot make one chart
shorter than its neighbours. Not needed once panes have a height.

**`rows`, a grid row span.** A different thing: a tall pane beside two
short ones. It is worth having and is kept apart, since folding it into a
chart height would make one field mean two things.

**Lift the 20rem cap for everyone.** Changes every existing chart. Unset
must change nothing.

## Decision

**A pane may carry a `height` of 1 to 5, drawn as a box of that fixed
height around a bar or line chart. Unset is exactly what it is today.**

| height | box | default size |
| --- | --- | --- |
| 1 | `calc(var(--janela-space) * 24)` | 96px |
| 2 | `calc(var(--janela-space) * 40)` | 160px |
| 3 | `calc(var(--janela-space) * 56)` | 224px |
| 4 | `calc(var(--janela-space) * 80)` | 320px |
| 5 | `calc(var(--janela-space) * 112)` | 448px |

Multiples of the base unit, so a theme that sets `--janela-space` moves the
whole scale with the rest (ADR 016), and step 4 is today's cap exactly, so
"tall" means what a chart already is at full width. The class names follow
ADR 016's `janela-{property}-{scale}`: `janela-h-1` to `janela-h-5`, on a
`div.janela-chart-box` that wraps the canvas inside the figure, between the
`figcaption` and the canvas, so ADR 042's structure otherwise stands.
A host that wants an exact pixel value sets it against the class in its own
CSS. Inside the box the canvas takes the box's height and the 20rem cap
does not apply to it; the chart controller builds the chart with
`maintainAspectRatio: false` when the pane carries a height.

**With no height there is no box.** The markup, the classes, the cap and
the 2:1 rule are unchanged, so nothing that renders today renders
differently and `//figure[...]/canvas` still finds a canvas.

**One vocabulary in three places.**

```erb
<%= janela_pane Order, :revenue, by: :placed_on, as: :line, height: 2 %>
```

- `Janela::Pane#height`, an integer column that is null when unset,
  validated to `1..5` the way `span` is to `1..12`, and offered as a
  select on the pane form (blank is "Automatic").
- `janela_pane` and `janela_snapshot_pane` take `height:`.
- The pane URL carries it as `?height=2`, because the pane's content is
  rendered by the server from that URL, lazily and again on every
  cross-filter, and a height left out of the URL would be lost on the first
  refresh. A stored pane already refreshes from its row, which supplies it.

**Height is not part of the pane's identity.** ADR 029 identifies a frame
by who it is and not what it shows, and a height is a matter of drawing, not
of which query this is. It stays out of `Query.turbo_frame_id`, which is
also what lets a host change a pane's height in place without Turbo
reconciling into a different frame. Two helper panes over an identical query
that differ only in height still need an `id:`, exactly as two identical
panes do now.

**A height on a renderer that does not draw a canvas is ignored, not an
error.** A ring is SVG that scales to its width to a maximum of 16rem
(ADR 046), a table and a single value have no chart, and a snapshot pane
draws as its own renderer says. A pane whose renderer is switched from bar
to doughnut and back keeps the height it had, and a row is not made invalid
by a setting that is meaningless for what it now shows. What a ring's size
should be is left open.

## Consequences

- An analyst can shorten or lengthen a chart in a stored frame without
  changing what it says, and a host can do the same in the helper, from one
  vocabulary. Nothing about pixels reaches CSS.
- **A migration for stored frames.** `janela_panes` gains a nullable
  `height`, additive, so every existing pane is unset and unchanged. A
  host that uses stored frames runs `bin/rails janela:install:migrations`
  and `db:migrate`, in `UPGRADING.md` and the post install message
  (ADR 015). A host that does not use stored frames has nothing to do.
- **The pane URL grammar grows by one optional query parameter,** which
  ADR 037 counts as public surface, so it belongs before 1.0 and not after.
  `docs/theming.md` gains `janela-h-1` to `janela-h-5` and
  `janela-chart-box` (ADR 036), and the README documents `height:`.
- The chart controller reads one new value, which says whether a height was
  set. A height changes when the chart is *built*, so `repoint` to a URL
  with a different height replaces the pane content and the chart is made
  again, which Turbo already does on every replacement.
- A pane can now look too small to read: step 1 is 96px, tall enough for
  a sparkline and not for a chart with a legend and axis labels. That is the
  analyst's choice and the scale's lowest rung is deliberately that small.
- Vitral, the optional theme, does not touch heights: it has no rule for
  chart sizing and does not set `--janela-space`, so the scale reads the
  same under it. Sizing is structure and belongs to `janela.css` (ADR 023),
  and because the classes join the published contract a theme may override
  them; none has to.
- Not covered: rings, `rows`, a frame level maximum, and the gallery's
  configuration form, which offers renderer, granularity and limit and can
  offer height in a later change without a decision.
- What would change this decision: a real need for a height between two
  steps, which is an argument for a sixth step or for a host's own class
  and not for pixels; or a need for the height to follow a container rather
  than be fixed, which is a different feature.
