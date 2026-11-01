---
Topics: charts, renderers, panes, time, series, cumulative
---

# Charts and Their Options

A pane is a measure, sometimes over a dimension, drawn one way. This page
is the reference for the drawing: which renderer suits which question, the
options that change how it reads, and how to put more than one measure on
a chart. Each option is written the same three ways, in `janela_pane`, as a
column on a stored pane, and in the pane's URL, so a hand written page, an
analyst's row and a link all say the same thing.

The short version: pick the renderer from the shape of the question, pass
the option you need, and let the others stay unset. Every option is off
until a pane asks for it, and a pane that sets none is drawn as it always
was.

## Choosing a renderer

`as:` is `:table` unless the pane says otherwise.

| Renderer | The question it answers | Needs |
| --- | --- | --- |
| `:table` | what are the exact numbers | anything |
| `:bar` | how do the values of a category compare | a category dimension |
| `:line` | how does a measure move over time | a time dimension |
| `:doughnut`, `:pie` | how is a whole split between a handful of values | a category dimension, no negatives |
| none, with no `by:` | what is the single figure | a measure alone |

```erb
<%= janela_pane Order, :revenue %>
<%= janela_pane Order, :revenue, by: :status, as: :bar %>
<%= janela_pane Order, :revenue, by: :placed_on, as: :line, granularity: :week %>
<%= janela_pane Order, :orders, by: :region, as: :doughnut, limit: 8 %>
```

A table is also what any chart becomes where there is no chart runtime, so
the numbers are always readable. Bars and lines are drawn in the browser
with Chart.js. A doughnut or a pie is drawn on the server as SVG with a
legend of buttons beside it, so it is in the page before any JavaScript
runs and can be operated from the keyboard. A ring cannot show a negative
value, so a pane with one is drawn as a table and says so.

Clicking a bar, a slice or a table value narrows the other panes on the
frame. A click on a line's bucket narrows them to that range.

## Shaping one chart

These options apply to a single measure over a single dimension.

| Option | Does | Applies to |
| --- | --- | --- |
| `limit:` | keeps the top rows or bars | table, bar, ring |
| `sort:` | `:asc`, `:label`, `:label_desc`; the default is largest first | a category pane |
| `granularity:` | `:hour` to `:year`; the bucket size | a time pane |
| `height:` | `1` to `5`, from about 96px to about 448px | bar, line |
| `prominence:` | `1` to `3`, the size of a single figure | a single value |
| `value_labels:` | writes the value on the chart | bar, line |
| `companions:` | up to three more columns | table |

A bar or line chart is drawn at twice its width, up to 20rem, unless it
is given a height. Heights and prominences are steps rather than lengths,
so a stored pane takes them from its form. `value_labels` on a bar is all
or none: if any label is wider than its bar's share of the chart, none is
drawn. The README has the detail of each; ADRs 046, 047, 050, 051, 054
and 055 have the reasons.

## A running total

A time pane reads per period by default: orders placed each month.
`cumulative: true` reads the same buckets as a total to date.

```erb
<%= janela_pane Order, :orders, by: :placed_on, as: :line, granularity: :month, cumulative: true %>
```

The total is summed after the read, so the buckets, the filters and a
click on a bucket are exactly what they were. It is refused, with its
reason, on a category pane, on a single value, and on a measure that does
not add up: an average, a minimum, a maximum or a ratio. A running sum of
averages would be a number, but not the average to date. Per period and to
date are two different answers that can share a page, so a pane that sets
`cumulative` has its own frame id.

## More than one series

A time pane can carry up to three more measures over the same buckets.
Each is a hash led by its measure.

```erb
<%= janela_pane Order, :orders, by: :placed_on, as: :line, granularity: :month, cumulative: true,
      series: [
        { measure: :orders, by: :shipped_on, cumulative: true, title: "Orders shipped to date" },
        { measure: :orders, as: :bar, axis: :right, title: "Orders per month" }
      ] %>
```

That is orders placed and orders shipped, both to date, as two lines on
the left axis, with orders per month as bars on a right one.

| Key | Means | Left out |
| --- | --- | --- |
| `measure` | a measure the model declares | required |
| `by` | a time dimension of the same model | the pane's own |
| `cumulative` | a running total | per period |
| `as` | `line` or `bar` | the pane's renderer if it is one of those, else `line` |
| `axis` | `left` or `right` | `left` |
| `title` | the legend's name for it | one Janela writes, such as `Orders shipped to date` |

**What the chart does.** Every series' buckets are joined into one axis,
from the first bucket any series has to the last. A series with no row in
a bucket reads zero there, so a total to date is flat across a month
nothing shipped. For a measure that has no value in an empty bucket (an
average, a minimum, a maximum or a ratio) the bucket is a gap instead. A
chart with series shows a legend and colours by series rather than by
category: `--janela-series-1` for the pane's own, the rest in order. Bars
are drawn behind lines. A right axis exists only when a series asks for
one, and then both axes are titled with the series on them. A right axis
that holds only bars is scaled so the tallest reaches about a third of the
plot, which keeps them from covering the lines.

**What it does not do.** Series belong to a time pane. A category pane,
a ring and a single value refuse them or ignore them, and a stored
snapshot holds none. A series cannot have its own granularity or filter,
or come from another model, and nothing stacks. With `value_labels`, each
line writes its latest value at its end and a bar writes nothing.

**Where to set it.** The same keys are rows on the pane form, `cumulative`
and `series` in `Janela::Tools`, and `?cumulative=1&series[][measure]=orders&series[][by]=shipped_on`
in the pane URL. Put `measure` first in a series in a URL, because that is
what starts a new one. A table draws each series as a column after the
measure's, which is also what a page with no chart runtime shows.

## Colours

Bars, slices and series are drawn from eight colours by position, and every
position after the eighth in one neutral. They are `--janela-series-1` to
`--janela-series-8` and `--janela-series-other`, and [Theming
Janela](theming) says how to change them.

## What this page is not

It is not the list of what can be asked of a model; that is the model's
own `janela` block, and `Janela::Definition` answers it. It is not the
layout around a pane either, which is [Composing a Page Around
Panes](composing). The decisions behind the options are the ADRs: 062 for
running totals and series, and the README for the rest.
