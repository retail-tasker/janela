---
Date: 2026-10-06
Status: Accepted
Related: ADR 004, ADR 020, ADR 029, ADR 037, ADR 038, ADR 046, ADR 047, ADR 050, ADR 053
Triggers:
  - a chart's axis showing a number the tooltip shows differently
  - drawing text on a chart canvas, or adding a Chart.js plugin
  - adding a boolean to a pane, a column to janela_panes, or a parameter to the pane URL
  - a ratio, a currency or a percentage on a chart
  - a chart too dense to label every bar
Topics: charts, formatting, measures, public-api, panes, urls
---

# ADR 054: A Chart Reads Numbers the Way Its Measure Formats Them

## Context

#72 and #76, raised from a real install building a client report: a share
of rows by category, drawn as bars, with the percentage on each bar. Two
things stood in the way, and both are the same gap. A chart is the one
place a number reaches a reader without the measure's format applied
(ADR 020), except the tooltip, which a reader has to hover to see.

Both were reproduced against the demo on `main` (Chart.js 4.5.1), with the
chart built live and the drawn scale read from it.

**The axis is raw.** A bar chart of a ratio drew ticks `0, 0.1 ... 1.0`
beside tooltips reading `0.0%`. Revenue drew `0, 50,000 ... 500,000` beside
tooltips reading `$469,097.85`. `chart_controller.js` sets
`scales: { y: { beginAtZero: true } }` and formats only the tooltip.

**#72 said this was never decided. It was.** ADR 020 closes its Decision
with "The chart still plots raw numbers, because an axis is a scale and not
a label." That sentence is wrong for a reader, who reads the axis as labels
whatever it is to Chart.js. A ratio's axis at 0.5 against a tooltip at 50.0%
reads as two different numbers (ADR 038 keeps the stored value a fraction
for the data's sake, which is not a reason for the axis to show one). The
rest of ADR 020 stands: the number is never rounded or transformed, and the
measure is the layer that owns its format.

**Tick precision does not need a rule of Janela's own.** The worry in #72
was that ticks fall between data points, so the precision that suits a
value (`25.0%`) is wrong for a tick (`25%`). Chart.js's own numeric tick
formatter already derives its decimals from the spacing between ticks.
Calling it with a ratio's ticks scaled by 100 and appending `%` gave, on the
live chart:

| ratio data up to | ticks |
| --- | --- |
| 0.53 | `0%, 10% ... 60%` |
| 0.03 | `0%, 0.5%, 1% ... 3%` |
| 1 | `0% ... 100%` |

Whole percentages where the spacing is whole, half percentages only where
the ticks really are half a percent apart. One catch: scaling by 100 leaves
float noise (`3.5000000000000004%`), so the scaled value has to be rounded
before it is formatted.

**A bar label has to fit, and nothing guarantees it does.** Measured with a
label drawn at each bar's end:

- The tallest bar of a default chart touches the top of the plot area, so a
  label above it is clipped. `scales.y.grace = "10%"` left 30px of
  headroom in a 300px chart, and Chart.js 4.5.1 supports it.
- A label inside the bar was never an option: the shortest bars are about
  2px tall.
- With 30 bars in a 600px chart a bar was 13px wide and a label such as
  `$88,000.00` was 60px, so neighbouring labels overlap several deep.
  Hiding only the ones that collide would label some bars and not others
  for a reason a reader cannot see.
- A negative bar ends below its base, so a label placed above the end would
  sit on the bar.
- A plugin cannot be added to a chart after it is built, so the drawing has
  to be handed over when the controller constructs the chart, as
  `maintainAspectRatio` is for a height (ADR 047).

### What was considered

**Formatted tick strings from the server.** The server formats a value
(ADR 020), but the client chooses the ticks, where they fall depends on the
chart's size and data, and the server cannot know them. It would have to
format values it is never asked about.

**A `precision` of the measure's own for ticks.** A measure's precision is
what one value means. A scale spanning `$0` to `$500,000` in steps of
50,000 does not want cents, and a ratio at one decimal place would print
`20.0%` at every tick. It is the answer to a different question.

**A host-supplied tick callback.** A setting, to do what one formatter
already does for every measure. ADR 001 prefers one obvious way, and ADR 021
and ADR 023 only allow a setting where a judgement is made once at boot.

**`chartjs-plugin-datalabels` for the bar labels.** A dependency, and a
second way to format a number on a chart. ADR 004 keeps Chart.js the one
thing the engine ships, and an inline plugin that draws a string the server
already produced is about twenty lines.

**Labels on by default.** Changes every bar chart that exists, and a chart
of thirty bars gains nothing from it. Unset must change nothing, as it does
for height and prominence.

**A setting for where the label sits, or whether it fits.** Outside the end
is the only place that works for every bar, including the shortest and the
negative, and a fit that is a judgement per chart is a decision a reader of
the dashboard cannot see made.

**Labels on a line, or on a ring.** A line has a point per bucket, often
sixty or more, and a ring already prints every value beside it (ADR 046).
Neither gains from it.

## Decision

**A chart's axis is formatted by the measure, always, and a bar chart can
be asked to draw each bar's value as a label.** The first supersedes the one
sentence in ADR 020 above and nothing else in it. The second is opt in.

### The axis

The server sends what a tick needs as one more data attribute on the canvas:
the measure's `prefix`, its `suffix`, and whether it is a ratio.

```erb
data-janela--chart-tick-format-value='{"prefix":"$","suffix":"","ratio":false}'
```

The controller formats each tick with Chart.js's own numeric formatter and
adds those. A ratio's ticks are scaled by 100, rounded to remove float
noise, and given a `%`. The measure's `precision` is not used: the tick's
decimals come from the spacing between ticks, which is what answers "25%,
not 25.0%". It applies to a bar and a line, both of which have a value axis,
and it is not a setting: it is what the axis always was, now correct.

A measure with no prefix, suffix or ratio draws what it draws today.

### The labels

**A pane may carry `value_labels`, a boolean. Unset is exactly what it is
today.** When set on a bar chart, each bar's formatted string, the same one
the tooltip shows, is drawn beyond the end of the bar, above for a positive
value and below for a negative one. The value axis is given 10% of grace so
the tallest bar keeps its label in the plot.

**All or none.** The labels are drawn only if every one of them fits within
its category's slot, the chart area's width divided by the number of bars.
If any does not, none is drawn and the chart is what it was without the flag.
A chart never labels some bars and not others, and a host that wants the
labels on a dense chart makes the chart wider or the pane a bar chart of
fewer categories (`limit:`, ADR 007).

**One vocabulary in three places,** as height and prominence do:

```erb
<%= janela_pane Order, :expedited_rate, by: :status, as: :bar, value_labels: true %>
```

- `Janela::Pane#value_labels`, a nullable boolean, offered on the pane form
  as a checkbox.
- `janela_pane` and `janela_snapshot_pane` take `value_labels:`.
- The pane URL carries it as `?value_labels=1`, because the server draws the
  pane again from that URL on every cross-filter.

**The name avoids `labels`.** In this codebase a chart's labels are its
categories: the controller's `labels` value is the x axis. `value_labels`
says which labels, and `values` would collide the same way with the
controller's `values`. It is the one name that reads the same at the helper,
the column, the URL and the controller (ADR 037).

**It is not part of the pane's identity.** ADR 029 identifies a frame by who
it is, and whether its bars carry numbers does not say which query it is. It
stays out of `Query.turbo_frame_id`.

**On anything that is not a bar chart it is ignored, not an error.** A
table, a single value, a line and a ring keep what they have, and a pane
switched between renderers keeps the flag, as height does on a ring
(ADR 047).

## Consequences

- **Every existing chart's axis can change.** A revenue chart gains a `$`
  on its ticks and a ratio chart reads in percentages. Nothing else about it
  moves, and a measure with no prefix, suffix or ratio is untouched. It is
  in `CHANGELOG.md` under Changed as a visible correction, with no action for
  a host; it is not an `UPGRADING.md` step (ADR 015), because nothing a host
  wrote has to change. A host that overrode the tick callback on its own
  chart is unaffected, since Janela does not set one for it.
- A ratio chart is readable end to end: a percentage on the axis, in the
  tooltip, and on the bars if asked.
- **A migration for stored frames.** `janela_panes` gains a nullable
  boolean `value_labels`, additive, so every existing pane is unset and
  unchanged. A host using stored frames runs `bin/rails
  janela:install:migrations` and `db:migrate`, as it did for `height`,
  `prominence` and `companions`. The doctor's `unmigrated-columns` check
  (ADR 035) is taught the new column, so a host that upgrades and skips the
  migration is told rather than meeting an error on the pane form. A host that
  does not use stored frames has nothing to do.
- **`Janela::Tools` has to learn the attribute.** Its `PANE_ATTRIBUTES` is the
  list of a pane's own attributes an agent may set (ADR 053), and an
  attribute not on it is refused. `value_labels` joins it in the same change as
  the column, or an agent could arrange every other part of a pane and not
  this one.
- **The pane URL grammar grows by one optional parameter.** ADR 037 counts
  that as public surface, which is why this belongs before 1.0.
- **Ticks use the browser's number locale, and the tooltip uses the host's
  delimiter** (ADR 020). A host whose `number.format.delimiter` differs from
  its readers' browsers would see two styles on one chart. This is from how
  Chart.js formats and is not something measured here; if it turns up in
  practice the answer is to pass the delimiter in the same attribute, not to
  stop using Chart.js's formatter.
- The all or none rule means the flag can do nothing on a dense chart, and
  the pane form cannot say so. That is a real cost, accepted because the
  alternative is a chart that labels bars selectively.
- Drawn pixels are not available to a screen reader. That is as true of the
  bars themselves, which ADR 042 answers with the figure's caption and the
  table beside it, and this decision does not change it.
- Tests read what the code produced: the drawn tick labels, and the position
  and text of each drawn bar label, not the attribute that asked for them
  (ADR 035).
- What would change this decision: a need for a label on a line or a ring,
  which is an argument about those renderers and not about this one; or a
  host that needs the labels to survive on a dense chart, which would be a
  case for a step in how they are thinned and not for a placement setting.
