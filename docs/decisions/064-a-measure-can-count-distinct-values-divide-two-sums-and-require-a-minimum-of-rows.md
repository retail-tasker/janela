---
Date: 2026-11-20
Status: Accepted
Related: ADR 002, ADR 007, ADR 009, ADR 020, ADR 038, ADR 054, ADR 055, ADR 062, ADR 063
Triggers:
  - adding a measure kind, or a sixth aggregate to the DSL
  - counting distinct values rather than rows
  - dividing one sum by another, or a rate against a target
  - hiding or dashing a value worked out from too few rows
  - choosing whether a pane lists the groups a minimum suppressed
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
- Groups under the minimum can be kept and still sorted after every
  group that qualifies. `ORDER BY CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1
  END, SUM(amount)` with `LIMIT 2` on the demo's three statuses (`paid`
  with two rows, `pending` and `refunded` with one) put `paid` first in
  both directions, then `pending` ascending or `refunded` descending. The
  `HAVING` version of the same query returned `paid` alone.

### What was considered

**A free SQL expression measure** (`measure :x, sql: "..."`) would cover
all three and every future ask. Rejected: it is a second query language
beside Ransack (ADR 001, ADR 002), it cannot be checked at declaration,
and a forker reading it learns nothing about what it means.

**A ratio of sums as a new key, `divide: [:a, :b]`.** Rejected for the
name. A boolean ratio already is a division, the true rows over the known
rows, and reading the two as one idea with one name is simpler than two
words for it.

**`min_rows` always drawing a dash in a category pane.** A table row
reading "–" was the first shape asked for. Rejected as the only
behaviour, for how it meets `limit` and `sort`: sorted among the real
values, the dashes either take the places of real ones in a bottom ten
or fall out of the limit unseen. Rejected as the default too, because a
ranking is the commoner category pane and leaving the groups out is what
a ranking wants. Kept as a pane option, sorted last, below.

**Leaving the groups out, always.** Rejected because the same measure
answers two questions on two panes. A bottom ten wants the low-sample
groups gone. A table of every store wants them listed with "–", because
which stores lack the data is itself the finding. The measure cannot know
which pane it is on, so the choice is the pane's. A BI tool makes the
same split per visual ("show items with no data").

**`min_rows` on the pane rather than the measure.** Rejected. Fifty rows
is the rule for when the rate means anything, and it has to hold on every
pane, snapshot and agent read of that measure. A pane that could lower it
would show the noise the rule exists to hide. A pane chooses only whether
to list what the measure suppressed.

**A setting for what an empty value reads as.** Rejected. Formatting
belongs to the measure (ADR 020), and a blank cell against a dash is not
a judgement any pane needs to make differently.

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
- A category pane can ask to **keep them**, with `show_under_min_rows:
  true` (`janela_pane Fact, :in_stock_rate, by: :store,
  show_under_min_rows: true`), a checkbox on the pane form,
  `?show_under_min_rows=1` in the pane URL and a key in `Janela::Tools`.
  A kept group has no value, reads `–`, and **sorts after every group
  that qualified, whichever way the pane sorts**, so `limit` fills with
  real values first and a dash is seen only when fewer groups qualify
  than the limit allows. Among themselves they sort by label. A time
  pane, a series and a single value ignore the option, since they
  already keep a bucket under the minimum as a gap, and so does a pane
  whose measure has no `min_rows`.
- On a time pane, a series (ADR 062) and a single value, a bucket under
  the minimum **has no value**: read beside a count of its rows and set to
  none after the read, so the axis is the same with or without it. It is
  a gap on a line, no bar, and `–` in a table or a single value.
- A snapshot stores what the query returned, so a frozen value under the
  minimum stays without one (ADR 009).

**One pane option, and otherwise none.** All three are declarations on
the model, the same way every measure option is (ADR 020), and a stored
pane names the measure and gets them. `show_under_min_rows` is the one
setting, and it earns itself the way `ignore_unknown_filters` did (ADR
063): it is a judgement about what one pane is for, which neither the
measure nor a convention can make for it.

## Consequences

- A reporting host can declare the three it asked for without a view per
  question or a second model.
- `Measure` grows from five aggregates and a ratio to six and a ratio
  with an optional denominator, plus one option. `Definition#query` reads
  a ratio of sums in two queries, and a time pane with `min_rows` in two.
  Both are bounded: the second query has the same `GROUP BY` as the first.
- A category pane with `min_rows` can show fewer rows than its `limit`
  with nothing on the page saying why. That is the honest cost of leaving
  groups out, and `show_under_min_rows` is the answer where it matters. A
  note under the pane saying how many were left out is a later question,
  not decided here.
- Kept groups cost a category pane a second read: the `HAVING` cannot be
  used, so the order carries the minimum instead, and a count beside the
  read says which groups to set to no value.
- `show_under_min_rows` is a column on `janela_panes`, so a host with
  stored frames runs a migration, which makes the release that ships it
  a minor one. `UPGRADING.md` carries the step and the doctor's
  `unmigrated-columns` check learns the column, as it did for
  `ignore_unknown_filters`.
- **`–` for no value.** Today an empty bucket of a ratio formats as an
  empty string. A suppressed value and an empty one should read the same,
  so both become `–`. That is a visible change to every host with a ratio
  over empty buckets, small, and listed in the changelog.
- `Janela::Tools` and `describe_vocabulary` need nothing new: they list
  measures by name (ADR 053).
- What would change this decision: a host needing a running ratio of
  sums, which is meaningful (the running numerator over the running
  denominator) and could be allowed later without changing these names;
  or a host whose panes nearly all set `show_under_min_rows`, which would
  argue for keeping as the default.
