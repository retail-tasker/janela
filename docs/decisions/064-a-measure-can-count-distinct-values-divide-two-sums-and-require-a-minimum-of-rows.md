---
Date: 2026-11-20
Status: Proposed
Related: ADR 002, ADR 007, ADR 009, ADR 020, ADR 038, ADR 054, ADR 055, ADR 062
Triggers:
  - adding a measure kind, or a sixth aggregate to the DSL
  - counting distinct values rather than rows
  - dividing one sum by another, or a rate against a target
  - hiding or dashing a value worked out from too few rows
  - a ratio that can be above 100%
Topics: DSL, query layer, measures, formatting, ordering
---

# ADR 064: A Measure Can Count Distinct Values, Divide Two Sums, and Require a Minimum of Rows

## Context

#97, from a host building reporting frames over fact views. A measure
today is one of five aggregates, or `ratio:` of one boolean column
(ADR 038). Three things a reporting page needs cannot be declared:

- **A count of distinct values.** "Stores visited" is not "visits".
- **One sum over another.** Visits against target, or ranged lines against
  lines expected. It reads as a percentage, and it can rightly be above
  100%: a store that beat its target did not make an error.
- **A minimum sample.** A ratio over three rows is noise that looks like a
  finding. The host's own rule is fifty observations before a rate is
  shown.

Measured against the demo on `3a41a64` (Rails main, SQLite), with
`Order` grouped by `status`:

- `relation.distinct.count(:customer_id)` answers a hash per group,
  through Groupdate per month too, and its grouped alias is
  `count_customer_id`, the same alias ADR 007 already orders a count by.
  Nothing new is needed for grouping, ordering or gap filling.
- A ratio of two sums cannot be one `relation.<aggregate>(expression)`
  call: `SUM(a) / SUM(b)` is not an argument to any one aggregate, and
  wrapping it nests aggregates. Two sums read separately and divided per
  key are right, and Groupdate fills both with zero, so an empty bucket is
  `0 / 0`, which has to be no value rather than an error. Ordering by the
  expression itself, `SUM(a) * 1.0 / NULLIF(SUM(b), 0)`, works in an
  `ORDER BY` beside a `GROUP BY`, which is how ADR 038 already orders a
  ratio.
- `HAVING COUNT(*) >= 2` on a category pane returns only the groups that
  qualify, before `limit`. On a time pane the same `HAVING` through
  Groupdate returned `{}` where every day had one row: Groupdate fills
  between the first and last bucket it is given, so with none it draws
  nothing, and with some it draws a shorter axis. A minimum on a time
  pane cannot be a `HAVING`.

### What was considered

**A free SQL expression measure** (`measure :x, sql: "..."`) would cover
all three and every future ask. Rejected: it is a second query language
beside Ransack (ADR 001, ADR 002), it cannot be checked at declaration,
and a forker reading it learns nothing about what it means.

**A ratio of sums as a new key, `divide: [:a, :b]`.** Rejected for the
name. A boolean ratio already is a division, the true rows over the known
rows, and reading the two as one idea with one name is simpler than two
words for it.

**`min_rows` drawing a dash in a category pane.** A table row reading
"–" was the first shape asked for. Rejected for how it meets `limit` and
`sort`: on `sort: :asc, limit: 10`, the bottom ten would be chosen from
groups that include the suppressed ones, so either the dashes take the
places of real values or they are sorted out of the limit and never seen
anyway. Leaving them out before the limit is the version that answers the
question a bottom ten asks.

**Clamping a ratio of sums at 100%.** Rejected. Over 100% is a real
answer, and a clamped one is a wrong number that looks right.

## Decision

**A measure can be `count_distinct:` a column, `ratio:` one column `over:`
another, and any measure that does not add up can require `min_rows:`.**

```ruby
janela do
  measure :visits,         count: true
  measure :stores_visited, count_distinct: :place_id
  measure :to_target,      ratio: :visits, over: :target
  measure :in_stock_rate,  ratio: :in_stock, min_rows: 50
end
```

**`count_distinct:`** is `COUNT(DISTINCT column)`, a sixth aggregate. It
reads as a count (no decimal places, ADR 020) and orders by its count
alias. It is not additive: two months' distinct stores do not sum to the
quarter's, so `cumulative` refuses it as it refuses an average (ADR 062),
and a bucket with no rows is zero.

**`ratio: :a, over: :b`** is `SUM(a) / SUM(b)`, read by two sums and
divided per group. Both columns must be numeric, checked at declaration
the way ADR 038 checks a boolean. Without `over:`, `ratio:` is what it
is today. It is stored as the fraction and read as a percentage, exactly
as ADR 038 says, and is never clamped: 1.25 reads `125.0%`, and the
axis follows the data (#96). A group whose denominator sums to zero has
no value, as an empty bucket of a boolean ratio has none today. It
orders by the expression. It does not add up, so `cumulative` refuses it.

**`min_rows:`** is a whole number of rows a group needs before its value
is shown. It is allowed on an average, a minimum, a maximum and either
ratio, and refused on a sum, a count or a count distinct, which are
true however few rows they are over. Rows are the group's rows after
every filter, `COUNT(*)`.

- On a category pane a group under the minimum is **left out before**
  `sort` and `limit`, as `HAVING COUNT(*) >= n`, so a bottom ten is ten
  groups that qualified.
- On a time pane, a series (ADR 062) and a single value, a bucket under
  the minimum **has no value**: read beside a count of its rows and set to
  none after the read, so the axis is the same with or without it. It is
  a gap on a line, no bar, and `–` in a table or a single value.
- A snapshot stores what the query returned, so a frozen value under the
  minimum stays without one (ADR 009).

**No pane or URL changes.** All three are declarations on the model, the
same way every measure option is (ADR 020). A stored pane names the
measure and gets them.

## Consequences

- A reporting host can declare the three it asked for without a view per
  question or a second model.
- `Measure` grows from five aggregates and a ratio to six and a ratio
  with an optional denominator, plus one option. `Definition#query` reads
  a ratio of sums in two queries, and a time pane with `min_rows` in two.
  Both are bounded: the second query has the same `GROUP BY` as the first.
- A category pane with `min_rows` can show fewer rows than its `limit`
  with nothing on the page saying why. That is the honest cost of leaving
  groups out. A note under the pane saying how many were left out is a
  later question, not decided here.
- **`–` for no value.** Today an empty bucket of a ratio formats as an
  empty string. A suppressed value and an empty one should read the same,
  so both become `–`. That is a visible change to every host with a ratio
  over empty buckets, small, and listed in the changelog.
- `Janela::Tools` and `describe_vocabulary` need nothing new: they list
  measures by name (ADR 053).
- What would change this decision: a host needing a running ratio of
  sums, which is meaningful (the running numerator over the running
  denominator) and could be allowed later without changing these names;
  or one needing the left-out groups listed, which would argue for the
  dash again.
