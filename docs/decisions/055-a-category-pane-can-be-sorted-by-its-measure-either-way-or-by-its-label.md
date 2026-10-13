---
Date: 2026-10-13
Status: Accepted
Related: ADR 005, ADR 006, ADR 007, ADR 020, ADR 037, ADR 046, ADR 047, ADR 049, ADR 050, ADR 053, ADR 054
Triggers:
  - adding a sort direction, or sorting a pane by something other than its measure
  - asking for the bottom N, the lowest values, or a chart in label order
  - a dimension whose labels are the natural order, such as a period code
  - adding a parameter to the pane URL, or a column to janela_panes
  - deciding where the NULL group sits in a pane's order
Topics: ordering, limit, panes, urls, query-layer, public-api, frames
---

# ADR 055: A Category Pane Can Be Sorted by Its Measure Either Way, or by Its Label

## Context

ADR 007 ordered every category pane by its measure, largest first, with no
way to turn that off, and named what it left for later: "an 'other' bucket
that sums what the limit cut off, ascending order, sorting by label, and
paging. Each is plausible; none is needed by the first host." Two hosts
have now needed one each.

#75: a pane with a `limit` shows the top N and cannot show the bottom N, the
lowest scores rather than the highest. Reversing the result in the view
does not help, because the limit is applied in SQL before the host sees any
rows, so a reversed top ten is still the top ten. The host that raised it
carries a patch that gives each pane an ascending or descending order, and
that patch broke across releases because it copied method bodies.

#80: a chart of a measure by a dimension whose labels are the natural order,
such as `202603 March Grocery Independents`, where the leading `YYYYMM` makes
alphabetical order chronological, comes out largest first and not oldest
first, so a trend is unreadable. The host worked round it with a database
column that holds the month as a time dimension, because a time dimension is
the one exemption ADR 007 makes. That costs a column, and it merges any two
cycles that fall in the same month.

These are one decision. Both are "which end of which ordering does the pane
start from", they share every open question below, and building either alone
risks making the other's shape wrong.

### What was measured

Against the demo, on SQLite, before deciding.

**The ordering is one line.** `Definition#query` groups by the dimension and
orders by `measure.order_by` descending, then limits. Reversing the
direction and ordering by the dimension's own column both work with a
change to that line, and the limit follows the order: ascending by measure
with a limit of two returned the two smallest groups.

**A database sorts a column by the column's type.** Ordering in SQL puts a
numeric column in numeric order and a date column in date order, and sorts a
text column as text. A text label such as `202603 ...` sorts correctly
because its prefix is fixed width, and a text column holding `10` and `9`
sorts `10` before `9`, as any text sort does. The question #80 left open,
whether label sorting compares as text or follows the column's type, is
answered by letting the database do it: it follows the column's type,
because the column is what is being sorted.

**Text order is the database's collation, and it differs.** On SQLite
`B` sorts before `a`. Other databases sort case insensitively by default.
Janela does not read the collation and does not try to make them agree.

**The NULL group is placed differently by different databases.** SQLite sorts
NULL first in an ascending order. PostgreSQL, from its documentation and
not measured here, sorts it last. Left alone, a label ordered pane would
show `(none)` at the top on one host and at the bottom on another.
`ORDER BY column IS NULL, column` puts it last everywhere, and measured on
SQLite it did: `10, 202603 x, 9, B, a, b, (none)`.

**Ties have no order today.** Two groups with the same measure come out in
whatever order the database produces, and with a limit the choice between
them decides which one is shown at all. That is harmless for a top ten of
distinct sums and arbitrary for a bottom five of counts, where ties are the
norm.

### What was considered

**Order on the measure.** ADR 020 put formatting there, and the reasoning
does not carry over. Formatting is a fact about the number, true wherever it
is shown. Order is a choice about one view of it: the same revenue measure is
sensibly largest first in one pane, smallest first in another and in label
order in a third on the same page. A measure that carries an order would
force two measures for one number, which is the workaround ADR 002 offers
for variation and the wrong one here. The limit is already on the pane for
the same reason (ADR 007), and order and limit are read together.

**Two settings, a field and a direction** (`sort: :label, dir: :desc`). Two
columns and two URL parameters to say one of four things, with combinations
that mean nothing for a time pane. One setting with four values is the
vocabulary `height` and `prominence` already speak (ADR 047, ADR 050).

**Sorting in Ruby after the fetch.** Cannot work. The limit is applied in
SQL, so a Ruby sort of ten rows sorts the wrong ten.

**A natural or numeric aware text sort.** Not portable across databases and
a second query language to document. A host whose labels need it can sort by
a column that holds the sortable form, which is what the one host already
does, and which the label order now makes unnecessary for the common case.

**An "other" bucket and paging.** Still not needed by anyone. Left where
ADR 007 left them.

## Decision

**A category pane may carry a `sort`, one of four values, and unset is
exactly what a pane does today.**

| sort | order | reads as |
| --- | --- | --- |
| `desc` (default) | measure, largest first | top N |
| `asc` | measure, smallest first | bottom N |
| `label` | the dimension's own value, ascending | alphabetical, oldest first |
| `label_desc` | the dimension's own value, descending | newest first |

```erb
<%= janela_pane Order, :revenue, by: :customer, limit: 5, sort: :asc %>
<%= janela_pane Order, :revenue, by: :cycle, as: :bar, sort: :label %>
```

**It is the pane's, in the three places the pane's other options are.**

- `Janela::Pane#sort`, a nullable string column validated to the four
  values and offered as a select on the pane form (blank is "Largest
  first").
- `janela_pane` and `janela_snapshot_pane` take `sort:`.
- The pane URL carries it as `?sort=asc`, so the server-rendered content
  keeps it on every cross-filter and lazy load, the same reasoning as
  `height` (ADR 047).

The column is named `sort` and not `order`, which is a reserved word in SQL
and the name of a relation method, and not `order_by`, which already means
the SQL expression on a measure.

**The database does the work, and the limit comes after.** For `label` and
`label_desc` the query orders by the dimension's column, so a number, a date
and a string each sort as themselves, and the limit then cuts that order:
`sort: :label, limit: 10` is the first ten labels. For `asc` it orders by the
measure ascending, so `limit: 5` is the bottom five.

**The `(none)` group is always last,** in all four orders, by ordering on
`column IS NULL` first. It is a group like any other for the measure orders,
and where its measure falls it falls. For the label orders it has no
position in the label's own order, so it goes to the end in a way that is
the same on every database.

**Ties are broken by the label, ascending,** in every order, so the same
data always draws the same pane and a limit between tied groups always
shows the same one. Unset panes were arbitrary in ties and are now fixed,
which changes nothing anyone could have relied on.

**A time pane ignores `sort`.** A time series is ordered by time and shows
its whole range (ADR 007), and that stands. A `sort` on one is ignored and
not an error, as a height is on a ring, so a row whose dimension is changed
to a time dimension is not made invalid and keeps its value if it is changed
back. Newest first on a time pane is a different question, left open below.

**A ring and a table take it unchanged.** Both draw the result in order: a
ring's slices and its legend follow it, a table's rows follow it. Nothing
special is built for either. A ring of the bottom five by `asc` is the caller's
choice, as a ring of the top five already is, and ADR 046's remark that a
ring suits few slices stands.

**It is part of the pane's identity when set,** the way `limit` is (ADR 007),
because "top five" and "bottom five" of one breakdown are two different
answers and may share a page. It is added to `Query.turbo_frame_id` only when
it is not the default, so every existing frame id is unchanged. This differs
from `height`, which is drawing and not identity (ADR 047).

## Consequences

- **A migration for stored frames.** `janela_panes` gains a nullable `sort`,
  additive, so every existing pane is unset and unchanged. A host that uses
  stored frames runs `bin/rails janela:install:migrations` and `db:migrate`,
  written in `UPGRADING.md` and the post install message (ADR 015). The
  doctor's `unmigrated-columns` check (ADR 035) is taught the column.
- **`Janela::Tools` has to learn the attribute,** in the same change as the
  column, or an agent could arrange every part of a pane except how it is
  ordered (ADR 053). Its vocabulary names the four values.
- **The pane URL grammar grows by one optional parameter,** which ADR 037
  counts as public surface and is why this belongs before 1.0. ADR 005's
  naming table gains a row: *bottom N* is `?sort=asc&limit=N`.
- **Snapshots record it.** A snapshot's lookup key includes the sort, as it
  includes the limit, so a frozen "bottom five" is not found for a request
  for "top five" (ADR 009).
- **Text labels sort by the host database's collation.** Documented, not
  smoothed over. A host that needs a different text order sorts on a column
  that holds it.
- Companion columns follow the primary measure's order and limit, as they do
  today (ADR 051).
- The demo's playground gets a control for it, shown only for a category
  pane, with the declaration rewriting itself as for the others (ADR 027).
- A pane ordered by label no longer puts the largest value first, so a chart
  in label order can bury the biggest bar. That is the analyst's choice and
  the reason for asking.
- Not decided here: newest first on a time pane; an "other" bucket; paging;
  a host's own ordering by an arbitrary column. Each starts from this
  table.
- What would change this decision: a need for an ordering by something that
  is neither the measure nor the label, such as a second measure, which is an
  argument for companion columns driving an order (ADR 051) and not for more
  values here; or a database where `column IS NULL` is not portable.
