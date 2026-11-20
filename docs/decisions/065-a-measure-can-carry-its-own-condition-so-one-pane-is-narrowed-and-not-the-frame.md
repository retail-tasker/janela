---
Date: 2026-11-20
Status: Proposed
Related: ADR 002, ADR 003, ADR 020, ADR 025, ADR 040, ADR 043, ADR 051, ADR 062, ADR 064
Triggers:
  - narrowing one pane without narrowing the frame around it
  - two panes over the same model where only one is filtered
  - a measure of only some rows, such as new products or one channel
  - adding a where to a pane, or a filter column to janela_panes
Topics: DSL, query layer, measures, cross-filtering, frames
---

# ADR 065: A Measure Can Carry Its Own Condition, So One Pane Is Narrowed and Not the Frame

## Context

#98. Every narrowing a host can apply today is frame-wide. A host's
`where:` (ADR 040) narrows every pane a `janela_frame` draws, and a
frame's `default_where` (ADR 043) narrows every pane over its model. A
frame cannot hold "sales" beside "sales of new products" over the same
model. The only way today is a second model or a second database view per
condition, which turns a one-word difference into a schema change.

Read against the code on `ced8ea9`: `Definition#query` and
`Definition#series` both start from `filter(on || model.all, where)`, and
`Definition#narrow` already applies a fixed set of Ransack conditions
under ADR 025's bounds (declared dimensions, allowed predicates, the value
limit), raising with its reason. A condition has one obvious place to go
in: the relation, before the grouping, in the two methods every pane
passes through.

### What was considered

**A `where:` on the pane.** The obvious reading of "fix a filter on one
pane". Rejected for its cost and for what it says. It is a new column on
`janela_panes`, a new parameter in the pane URL (ADR 037 counts both as
public surface), a field on the pane form and an attribute in
`Janela::Tools`, and it has to be told how it composes with the reader's
`q[...]` on the same key. And it puts the meaning in the wrong place:
"sales of new products" is a thing being measured, which a host names once
on the model, not a property of where a pane happens to sit. Two pages
wanting it would each write it again.

**A `filter:` beside the frame's `where:` that names a pane.** Rejected:
a hand-written frame has no pane identities to name, and a stored one
would need its own column anyway.

**A conditional aggregate in SQL**, `SUM(CASE WHEN ... THEN x END)`.
Rejected: Ransack builds `WHERE` conditions, not `CASE` expressions, so
this would be a second condition language beside Ransack's, which ADR 002
exists to avoid. It would also keep every group in a category pane with a
zero where it has no matching rows, which reads as a measured zero rather
than an absence.

## Decision

**A measure may carry `where:`, a hash of Ransack conditions on the
model's declared dimensions, and it measures only the rows that meet
them.**

```ruby
janela do
  measure :sales,              sum: :amount
  measure :new_product_sales,  sum: :amount, where: { new_product_eq: true }
  measure :online_orders,      count: true,  where: { channel_in: %w[web app] }

  dimension :new_product
  dimension :channel
end
```

```erb
<%= janela_frame do %>
  <%= janela_pane Sale, :sales, by: :region, as: :bar %>
  <%= janela_pane Sale, :new_product_sales, by: :region, as: :bar %>
<% end %>
```

**It is applied as one more narrowing, before the grouping,** through
`Definition#narrow`, in `query` and `series`. So it composes with every
other narrowing the same way they compose with each other: a frame's
default, a host's `where:`, the reader's selection and the measure's own
condition are all ANDed. A reader's click that contradicts it (`no` on
`new_product` for a pane of new product sales) leaves that pane empty,
which is the true answer to the question asked.

**It is checked when the `janela` block ends,** against the dimensions the
block declared and ADR 025's predicate bounds, and a wrong condition raises
at boot with the same sentence a bad request would get. The check waits for
the end of the block because a measure is usually declared before the
dimensions it names.

**It travels with the measure.** A pane, a series (ADR 062), a stored
pane, a snapshot, a companion column's facts (ADR 051) and
`Janela::Tools` name the measure and get its condition. Nothing about a
pane, its URL or its form changes.

**A pane's own dimension is not exempt.** A measure narrowed to two
channels drawn `by: :channel` shows those two. The cross-filtering rule
(ADR 003) sets aside the reader's selection on a pane's own dimension;
the measure's condition is part of what the pane measures, not a
selection.

## Consequences

- A frame can hold a measure and a narrowed version of it side by side
  with no new model, view or pane setting.
- A category pane of a narrowed measure shows only groups that have
  matching rows, not every group with a zero. A host wanting every group
  listed puts the unnarrowed measure beside it.
- The condition is the host's own code, read at boot, so it is not part
  of ADR 025's request bounds in the sense of arriving over HTTP. It is
  still held to them, because a typo in it would otherwise be a silently
  unfiltered measure, the failure this library is built to refuse.
- The measure's name is the only label a reader sees, so it has to say
  what is narrowed ("New product sales", not "Sales 2"). That is the
  host's naming, as it is for every measure (ADR 020).
- Works with ADR 064's measures unchanged: a ratio over a condition is a
  ratio of the rows that meet it, and `min_rows` counts those rows.
- What would change this decision: a host needing the narrowing chosen
  per page rather than per measure, such as an analyst picking a filter
  for one stored pane at run time. That is a pane-level `where:`, and it
  would need its own ADR on the URL and the form.
