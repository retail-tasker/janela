---
Date: 2026-09-16
Status: Accepted
Related: ADR 002, ADR 009, ADR 012, ADR 018
Triggers:
  - a number rendering with more precision than it means
  - adding an option to a pane, a frame or a pane URL
  - units, currency or percentages
  - a chart and a table showing the same number differently
Topics: dsl, rendering, charts, snapshots, configuration
---

# ADR 020: Formatting Belongs to the Measure

## Context

An averaged measure rendered as `928.8767833333333`. Tables ran
values through `number_with_delimiter`, which handles thousands and
nothing else, and a chart tooltip showed whatever the database
returned. Nothing anywhere said how many decimal places a number
means, or that it is money, or a percentage.

There are four layers that could say, and each was a real candidate.

The **pane** is where an analyst works, so it is the tempting answer:
this chart in thousands, that one to the cent. But a pane is a
database row and a form field, so every knob there is a migration, a
validation and another decision put to someone who should not have to
know that `amount` is a decimal with a scale of two. Worse, the same
measure on two frames could disagree about itself.

The **pane URL** would make it ad hoc, `?precision=0`. That widens the
grammar ADR 005 fixed, and it lets anyone holding a link change what a
number appears to say. Precision is not a question a reader asks.

The **frame** is the wrong shape. One frame holds panes from different
models, so a single setting would be right for the currency and wrong
for the count sitting next to it.

The **measure** is the only one of the four that knows what the number
*is*. The other three know where it appears.

## Decision

**A measure declares its own format, and every renderer asks the
measure.**

```ruby
janela do
  measure :revenue, sum: :amount, prefix: "$"
  measure :pass_rate, average: :score, precision: 1, suffix: "%"
  measure :orders, count: true
end
```

**Almost nothing needs declaring, because the schema already knows.**
Precision is the measure's own if it declares one, otherwise the
column's: counting rows has no decimal places, a `decimal(10, 2)`
column has two, summing an integer column stays whole. Only where
neither says anything, such as averaging an integer, does it fall back
to two places. Thousands are delimited with the host's own locale.

`prefix` and `suffix` carry the unit, which no amount of rounding can
say. They are two plain strings rather than a currency vocabulary,
because a string is the thing a forker can read and replace in a
minute.

**Formatting is rendering, never rounding.** The number itself reaches
a snapshot, an order clause and a comparison at full precision. A
stored pane is data (ADR 009), so a snapshot taken last month reads
back under a format declared today.

**One formatter serves every renderer.** A table cell, a single value
and a chart tooltip all show the string the measure produced, and the
chart is handed those strings rather than formatting a second time in
JavaScript. The chart still plots raw numbers, because an axis is a
scale and not a label.

## Consequences

- The common measures read correctly with nothing declared, which is
  the test this had to pass: money as money, counts as counts.
- A host changes how every one of its numbers reads by editing its
  model, not by touching a dashboard, a URL or a template.
- A measure that wants two formats is two measures. That is a real
  limit, and it is the same answer ADR 002 gives to every other
  variation: declare what you mean and name it.
- The chart controller now takes a `formatted` value alongside
  `values`. A host that renders its own chart from Janela's data has
  the strings available and is not obliged to use them.
- If per pane formatting ever proves necessary, the measure's format
  is the default it would override, not something to be undone first.
  This is the layer to add it to, and the reason to think twice.
