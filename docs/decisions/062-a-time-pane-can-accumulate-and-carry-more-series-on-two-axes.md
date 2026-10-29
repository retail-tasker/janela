---
Date: 2026-10-29
Status: Proposed
Related: ADR 002, ADR 005, ADR 006, ADR 007, ADR 009, ADR 018, ADR 020, ADR 029, ADR 037, ADR 045, ADR 046, ADR 047, ADR 051, ADR 054, ADR 055
Triggers:
  - a running total, a cumulative line, a to-date figure over time
  - drawing two measures on one chart, or a bar beside a line
  - a second value axis, a right axis, or two scales on one plot
  - a series bucketed by a different date column than the pane's
  - adding a column to janela_panes, or a parameter to the pane URL
  - choosing the colour of a series rather than of a category
  - a chart legend, or a title on an axis
Topics: charts, time, dsl, query layer, panes, urls, public-api, frames, styling
---

# ADR 062: A Time Pane Can Accumulate, and Carry More Series on Two Axes

## Context

#90, raised from a real install building an adoption chart: sign-ups to
date and activations to date as two lines on the left axis, new sign-ups
per week as bars on a right axis, one chart, filtered by the panes around
it. The host built it as a partial pane (ADR 039) holding its own Chart.js
controller and its own query. It draws, and it is wrong in three ways that
matter: it does not change when the reader clicks another pane, it is not a
row an analyst can edit, and it is a second chart implementation the host
has to keep in step with the gem's.

Four gaps stand between a pane and that chart, measured against `main`
before deciding.

**Nothing accumulates.** `Definition#series` returns one value per bucket
and `Query#result` hands it on. A chart of orders per month cannot be a
chart of orders to date without a column on the model that stores the
running count, which is presentation in the schema.

**One measure, one dimension.** `Query` holds exactly one of each. The
chart partial hands the controller one `labels` and one `values` array,
and `chart_controller.js` builds one dataset over one `y` scale. Two
measures over the same weeks are two panes, which cannot share an axis.

**The renderer is the pane's.** A pane is bars or a line, never both.

**A second value axis does not exist.** A count of five beside a total of
five hundred is a line on the floor.

Three facts shape the answer.

**Groupdate's keys differ by column type.** A date column's week buckets
come back as `Date` (`Mon, 31 Aug 2026`), a timestamp's as `Time` in the
zone. Two series over two columns can only share an x axis if their keys
are made the same kind first; `in_time_zone` gives the same instant for
both, and `Dimension#span` already reads a bucket that way.

**A list of hashes survives a URL if each starts with the same key.**
Rack's nested query parser opens a new hash in `series[][...]` when a key
repeats and otherwise adds to the last one, so `a[][x]=1&a[][y]=4&a[][x]=3`
gives the first hash the `y` meant for the second. Rails' `to_query`
leaves keys in their given order inside a `[]` namespace rather than
sorting them, measured: `{ series: [{ measure: "m", by: "d" }, { measure:
"n", as: "bar" }] }` writes `measure` first in each and parses back whole.
A series led by its measure is unambiguous; one that is not may not be.

**Chart.js draws a mixed chart from a type per dataset** and a second
scale from a second entry in `scales`, so the canvas needs nothing new
shipped (ADR 004).

### What was considered

**A stored column for the running total.** The host's workaround today.
Rejected: ADR 051 refused presentation in the schema for companions, and
a running total is the measure's own numbers added up, which is one line
of Ruby after the read.

**A `combo` renderer.** A fifth renderer whose dataset shape is its own.
Rejected: it would be a renderer that means "several of the other two",
and a table could not be its fallback without learning the same shape
anyway (ADR 018). The series are what is new; which of two existing
renderers each one uses is one word on it.

**A second pane that is told to share an axis with the first.** Two
panes, two queries, one canvas somehow. Rejected: a pane is one turbo
frame with one URL (ADR 005, ADR 029), and two of them cannot be one
`<figure>`.

**Series on a categorical pane.** Revenue and orders by status as grouped
bars. Not built, and not refused for ever: a categorical pane colours by
position in the result (ADR 046), a series needs colour by series, and
which rule wins is a decision of its own. The one host that needs this
needs it over time.

**A series with its own granularity.** Rejected: the point of a series is
that it shares the pane's buckets, and a week beside a month is two x
axes.

**Colour by category on a multi-series bar.** ADR 046 draws a bar in the
colour of its position. Rejected for a pane with series: a bar series over
thirty weeks in eight colours and a grey, beside a legend that names one
series, is a wrong picture. A pane with series colours by series.

**Formatted labels on every point of a line.** ADR 054 refused this and
the refusal stands. What a running total wants is its latest value, once,
at the end of the line.

**A per-series `title` left out, naming by measure alone.** Considered,
because a measure is already named for what it means on the dashboard
(ADR 002) and a host can declare `measure :sign_ups, count: true` beside
`measure :activations, count: true` for the same aggregate. Not enough on
its own: the same measure over the same dimension, once to date and once
per week, is the first chart anyone draws with this, and two legend
entries reading `Orders` is a wrong picture. A series may carry a title,
and the one Janela writes says what it is.

## Decision

**A time pane may carry `cumulative`, a running total of its measure
across its buckets, and `series`, up to three more measures of the same
model over the same buckets, each drawn as a line or as bars, each on the
left axis or a right one. Unset is exactly what a pane is today.**

```erb
<%= janela_pane Order, :orders, by: :placed_on, as: :line, granularity: :month,
      cumulative: true,
      series: [
        { measure: :orders, by: :shipped_on, cumulative: true, title: "Orders shipped to date" },
        { measure: :orders, as: :bar, axis: :right, title: "Orders per month" }
      ] %>
```

**`cumulative` is a yes or a no, and a time pane's.** The running total
is summed in Ruby after the read, so the SQL, the buckets, the filters and
the click on a bucket are what they always were (ADR 045). A stored
snapshot keeps per-bucket numbers and a cumulative view of it is summed
the same way on read, so nothing about what is stored changes (ADR 009).
On a categorical pane or a single value it is refused with its reason,
not ignored: a running total over categories sorted by their measure is a
different chart that nobody has asked for, and a row whose dimension is
changed to a category is told so on the form rather than quietly drawing
something else.

**A series is a hash of up to six words, and the first is `measure`.**

| key | takes | unset means |
| --- | --- | --- |
| `measure` | a measure the model declares | required |
| `by` | a time dimension the model declares | the pane's own dimension |
| `cumulative` | `1` or `0` | `0` |
| `as` | `line` or `bar` | the pane's renderer when it is one of those, else `line` |
| `axis` | `left` or `right` | `left` |
| `title` | words for the legend and the table header | Janela writes one |

Only what the model declared, by the name it declared it under, as
companions are bounded (ADR 025, ADR 051). A series by a different time
dimension shares the pane's granularity: its buckets are read with the
same `week_start`, every series' buckets are joined into one sorted set
through `in_time_zone`, and a bucket a series has no row in is zero, so
`Orders shipped to date` is flat across a month nothing shipped rather
than absent. Two series that name the same measure, dimension and
`cumulative` are refused as one series drawn twice. Four series are a
refusal that says three.

**The title Janela writes** is the measure's name, then `by` and the
dimension's name when the series is over a dimension other than the
pane's, then `to date` when it is cumulative: `Orders`, `Orders by
Shipped on to date`. The same rule names the pane's own series, so a
cumulative pane's legend and table header read `Orders to date`. A
`title` replaces all of it and is escaped like any other string.

**The pane's own measure is the first series, and it is the left axis.**
The pane's measure, dimension, renderer and `cumulative` are what they
were. What a click writes is the pane's dimension's range (ADR 045), and
the x axis is the pane's buckets. Filters are applied to every series the
same way: the reader's selection on the pane's own dimension is set aside
for all of them, because the pane shows the alternatives to it, and a
selection on any other dimension, including a series' own, narrows that
series as it narrows every pane.

**A bar and a line draw the series as datasets. A table draws them as
columns. A ring and a single value ignore them,** as a ring ignores a
height (ADR 047) and every renderer but a table ignores companions (ADR
051), so a pane switched between renderers keeps them. The table is the
fallback on a surface with no chart runtime (ADR 018), with a header row
as a table with companions has, the series' columns after the measure's
and before any companions. A stored snapshot holds no series, as it holds
no companions, so a snapshot pane with them shows the base table.

**With series, the chart shows a legend and colours by series.** The
pane's own series is `--janela-series-1`, the next `--janela-series-2`,
and so on, in the order given (ADR 046's palette, by series rather than by
category). Bars are drawn behind lines. A selected bucket is solid and the
rest faded, in every dataset, as a single series is today. Without series
nothing about a chart's colour, legend or interaction changes.

**A right axis exists when a series asks for it, and then both axes are
titled.** A right axis draws no grid lines across the plot, so the left
axis's grid is the only one. Each axis's title is the titles of the
series on it, in order, because an untitled second scale is the way two
scales mislead. When every series on the right axis is bars, that axis is
scaled so the tallest bar reaches about a third of the plot, so bars sit
under the lines rather than fighting them. A line on the right axis is
scaled to its own data like any line.

**`value_labels` on a line writes its latest value at the end of the
line, in text ink.** One label, not one per point, which is what ADR 054
refused. It applies to every line series on a pane that asks for it. Bars
on a pane with series draw no labels: their slots are shared and the all
or none rule of ADR 054 would almost always say none. A single-series bar
chart is unchanged. This supersedes the sentence in ADR 054 that a line
ignores the flag, and nothing else in it.

**One vocabulary in three places,** as height and companions are:

- `Janela::Pane#cumulative`, a nullable boolean, and `Janela::Pane#series`,
  a nullable JSON array of hashes, validated on save against the model's
  declared measures and dimensions through the same `Query` that would
  refuse the request. The pane form offers a checkbox and one blank
  series slot beyond those filled, each a group of plain selects since
  the engine's pages have no JavaScript (ADR 018), wherever it offers a
  granularity: on a pane over a time dimension, or one with no dimension
  chosen yet.
- `janela_pane` and `janela_snapshot_pane` take `cumulative:` and
  `series:`.
- The pane URL carries `?cumulative=1` and `series[][measure]=orders&
  series[][by]=shipped_on&series[][cumulative]=1`, each series led by its
  measure, because the server draws the pane again from that URL on every
  cross-filter.

**`cumulative` is part of the pane's identity when set; `series` is not.**
A measure to date and the same measure per period are two answers that
may share a page, as top five and bottom five are (ADR 055), so a set
`cumulative` joins `Query.turbo_frame_id` and an unset one leaves every
existing id alone. Series are columns beside the same answer, as
companions are, and stay out of it (ADR 029, ADR 051).

## Consequences

- The adoption chart is a row, or one `janela_pane`, and it cross-filters,
  falls back to a table, and is edited on the pane form like any other.
- **A migration for stored frames.** `janela_panes` gains a nullable
  boolean `cumulative` and a nullable JSON `series`, additive, in one
  migration. A host using stored frames runs `bin/rails
  janela:install:migrations` and `db:migrate`, written in `UPGRADING.md`.
  The doctor's `unmigrated-columns` check is taught both.
- **`Janela::Tools` learns both attributes** in the same change, with the
  series' keys in its schema (ADR 053).
- **The pane URL grammar grows by one parameter and one array of hashes.**
  ADR 037 counts that as public surface. The array of hashes is the first
  structured parameter in the grammar, and it is readable because each
  hash is a short sentence led by its measure.
- **A chart with series carries three more data attributes** (`series`,
  `label`, `axes`), and `labels`, `values` and `formatted` keep meaning
  the pane's own series, so a host that subclasses the controller and
  reads `datasets[0]` sees what it saw.
- The running total is summed from the buckets Groupdate returned, so it
  starts at the first bucket with a row, not at the beginning of time. A
  host that fixes the frame's range with `where:` starts the count there.
  That is the right answer for a filtered dashboard and the surprising one
  for a chart meant to begin at zero on launch day; a `where:` from the
  launch date is the way to say so.
- A series by a different time dimension counts rows where that column
  falls in the bucket, so a null is not counted anywhere. That is what
  makes `Orders by Shipped on` the orders that shipped, with no filter.
- Up to three more queries per pane, bounded as companions are (ADR 051).
- Text labels on a canvas are not available to a screen reader, which is
  as true of the lines themselves (ADR 042) and is why the table is
  always there.
- Not decided here: series on a categorical pane; a series with its own
  granularity or its own filter; stacking; a legend a keyboard can
  operate; a second axis for a single series. Each starts from the table
  above.
- What would change this decision: a host that needs a grouped bar over
  categories, which reopens the colour rule and is the first thing to
  revisit; or a dashboard whose series come from two models, which is an
  argument about what a pane is and not about this.
