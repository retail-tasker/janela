---
Date: 2026-09-24
Status: Proposed
Related: ADR 001, ADR 002, ADR 007, ADR 020, ADR 025
Triggers:
  - adding a measure kind, or a sixth aggregate to the DSL
  - deciding how a measure's value is scaled or formatted
  - changing how a grouped pane is ordered
  - a host wanting a rate or a percentage over a boolean column
  - wondering whether a measure option belongs on the measure or on a pane
Topics: DSL, query layer, measures, formatting, ordering
---

# ADR 038: A Ratio Is a Measure of Its Own, Stored as a Fraction and Read as a Percentage

## Context

A boolean column is how an application stores a yes or no fact, and
averaging one is how a person asks what share of rows are yes. Janela
refuses that today, correctly, and the refusal leaves nowhere to go
(#20, #27).

Four things were measured against the demo on `c6922da`, Rails 8.1.3.1
and SQLite, with `orders.expedited` as a real boolean column.

**The cast is total, not partial.** `Order.average(:expedited)` returns
`true` where the true ratio is `0.333`, and returns `true` again where
the true ratio is `0.0`, because Rails' boolean cast does not read a
float `0.0` as false. There is no value of the ratio that renders as
anything other than `true`. #20 described this as a cast losing
information; it loses all of it.

**The existing machinery already carries the fix.**
`relation.average(Arel.sql("CASE WHEN ... THEN 1.0 ELSE 0.0 END"))`
answers `0.3333333333333333` as a Float ungrouped, and grouped it
answers a hash per bucket. Nothing new is needed for grouping,
gap filling, cross filtering or snapshots, because the ratio goes
through the same `Measure#apply` every other measure goes through.

**Ordering breaks, which #27 did not mention.** `Definition` orders a
grouped query with `order(Arel.sql("#{measure.sql_alias} DESC"))`, and
`sql_alias` is `"#{aggregate}_#{column}"`, the alias ADR 007 names.
There is no such alias for an expression: the string becomes
`average_CASE WHEN orders.expedited THEN 1.0 ELSE 0.0 END DESC` and
raises `ActiveRecord::StatementInvalid`. Ordering by the expression
itself works and sorts correctly.

**The null claim in #27 is backwards.** On one true, one false and one
null row:

| expression | result |
| --- | --- |
| `AVG(CASE WHEN f THEN 1.0 ELSE 0.0 END)`, null as false | 0.333 |
| the same with a `WHEN f IS NULL THEN NULL` arm | 0.5 |
| `AVG(f)`, plain | 0.5 |

#27 says excluding null "differs from `AVG` in SQL". Excluding null is
exactly what `AVG` does. The naive `CASE` is the form that differs, and
it counts every unknown as a failure, which is this library's worst
failure mode: a wrong number that looks like a right one.

### Fraction or percentage, and where that choice lives

The formatter does not scale. `format(0.6667)` with `suffix: "%"`
renders `"0.7%"`, wrong by a hundred; `format(66.67)` renders
`"66.7%"`. ADR 020's own example, `measure :pass_rate, average: :score,
precision: 1, suffix: "%"`, only reads correctly if the value is
already on a nought to a hundred scale.

Three positions were considered.

**Storing nought to a hundred** was rejected. ADR 020 holds that the
number itself reaches a snapshot, an order clause and a comparison at
full precision. Storing a presentation scale puts a display choice into
a frozen snapshot and into an `ORDER BY`, where it is no longer a
display choice at all. A ratio is a proportion, and a proportion is
nought to one.

**Leaving the scale to each pane** was rejected, and ADR 020 had
already rejected it: `janela_panes` carries `model`, `measure`,
`dimension`, `renderer`, `granularity`, `limit` and `position`, and no
formatting columns, deliberately. Two panes of one measure could
otherwise freeze different numbers into different snapshots and serve
both as fact. ADR 020's consequences say per pane formatting, if it
ever arrives, overrides the measure's format rather than replacing the
idea, and calls that the reason to think twice.

**A fraction with an opt in percentage**, such as `percent: true` or a
remembered `suffix: "%"`, was considered and is the option this
decision narrows rather than takes. A proportion shown to a person is a
percentage; making that a flag means every host that declares a rate
also remembers a second thing, and a host that forgets gets `0.31` on a
dashboard where `31.2%` was meant. ADR 001 prefers one obvious way over
a knob.

## Decision

**A ratio is a measure kind of its own. It computes a fraction, and it
renders as a percentage.**

```ruby
janela do
  measure :expedited_rate, ratio: :expedited   # a boolean column
end
```

**The kind sits beside the five aggregates rather than inside them.**
ADR 002 says a measure takes exactly one aggregate of `sum`, `count`,
`average`, `minimum`, `maximum`. `ratio:` is a sixth option in that
position and not a sixth aggregate, because it names a column and an
intent rather than an SQL function. `Measure::AGGREGATES` is unchanged
and the error a host already sees when it declares two of them is
unchanged.

**It requires a boolean column, which is the mirror of the refusal it
answers.** `average:` rejects a boolean column and names `ratio:`;
`ratio:` rejects anything that is not one. Both look the column up
through `model.type_for_attribute`, so the expression is built from a
column the model has confirmed, never from a string that arrived over
HTTP. ADR 025 bounds what a filter may ask for; this is the same
principle one layer down.

**Null is excluded, so a ratio agrees with `AVG`.**

```sql
AVG(CASE WHEN col IS NULL THEN NULL WHEN col THEN 1.0 ELSE 0.0 END)
```

An unknown is not a failure. A host that wants unknowns counted as
failures says so in its own schema with a `NOT NULL` default, which is
a decision about the data rather than about the dashboard.

**A condition form is not included.** `ratio: { status: "paid" }` was
considered and rejected: it is a second query language growing inside
the measure, it needs the same bounding ADR 025 gives filters, and the
case it serves is already served. Where a column is not already a yes
or no fact, the split is the honest answer and cross filters better,
which is what #20's refusal says and what ADR 002 says to every other
variation. The boolean case earns its own kind precisely because the
split cannot answer it: "the share that passed, over time" is one
series, and a dimension gives two.

**The stored number is the fraction. The rendered string is the
percentage.** The value that reaches a snapshot, an `ORDER BY`, a chart
axis and a comparison is `0.3119`. The string a table cell, a single
value and a chart tooltip show is `31.2%`. This follows ADR 020 rather
than bending it: that decision forbids transforming the number, and a
ratio's number is never transformed. Only the string is.

Precision defaults to one decimal place for a ratio rather than ADR
020's fallback of two, because a percentage carries two more significant
figures than the fraction it came from and `31.19%` is noise. A measure
may still declare its own.

**Declaring `prefix:` or `suffix:` on a ratio raises.** The kind already
says what unit it is, and a host that writes `suffix: "%"` out of habit
would otherwise render `31.2%%`. Raising names the conflict rather than
guessing which was meant, which is what this library does everywhere
else it is given two answers.

**A measure answers what it is ordered by, rather than what its column
alias is.** `Measure#sql_alias` becomes `Measure#order_by`: for an
aggregate it returns the alias ActiveRecord already gives, unchanged,
and for a ratio it returns the `AVG(CASE ...)` expression. ADR 007's
decision is untouched, since a category pane is still ordered by its
measure, largest first, with no way to turn it off. Only the mechanism
it named has to widen, because that ADR assumed every measure is an
aggregate with an alias and a ratio is not.

## Consequences

- A host with a boolean column declares one line and gets a rate that
  cross filters, gap fills, snapshots and orders like any other measure.
- `rails janela:doctor` has nothing to add. The declaration either
  raises at boot or is correct, so there is no silent state for a check
  to find.
- **A measure that wants the fraction rather than the percentage cannot
  have it.** That is the cost of refusing the flag, and it is a real
  one: a host wanting `0.31` on a dashboard has to use `average:` over
  a numeric column of its own. If that turns up in practice, the answer
  is a format on the measure, not on the pane, and ADR 020 already says
  which layer that is.
- `Measure#sql_alias` is gone. It is internal rather than documented
  surface, with one call site in the gem, but a fork that reached for it
  will not find it, so it needs a line in `CHANGELOG.md` under Changed
  rather than an `UPGRADING.md` step (ADR 015): nothing a host declares
  changes.
- #20's error message names `ratio:`, which closes the loop the refusal
  opened. That string is what a host actually meets, so it is part of
  the work rather than a nicety.
- What would change this decision: a host that needs a rate over
  something that is not a boolean column and for which the split is
  genuinely wrong. That is the case the condition form was rejected for,
  and one real report of it is better evidence than the argument above.
