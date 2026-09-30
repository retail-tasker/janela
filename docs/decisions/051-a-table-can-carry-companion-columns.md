---
Date: 2026-09-30
Status: Accepted
Related: ADR 002, ADR 005, ADR 007, ADR 009, ADR 020, ADR 025, ADR 029, ADR 032, ADR 037, ADR 038, ADR 047
Triggers:
  - a table pane that needs a second number or a second fact beside its label
  - a rate whose sample size decides whether to trust it
  - adding a column to janela_panes, or a parameter to the pane URL
  - changing the shape of what a query returns
  - reading a column that is not the pane's dimension or measure
Topics: dsl, query layer, measures, tables, snapshots, public-api, performance
---

# ADR 051: A Table Can Carry Companion Columns, and a Fact Is Shown Only When It Is Shared

## Context

#34, raised from a real install: a table pane renders exactly two cells per
row, the label and the value, and that runs out the moment the label needs
context to be read. A top ten of words by times right, "quero 21", is really
asking which words *and of what kind*. The other half is worth more: a
"worst" list by error rate cannot say whether 75% came from four reviews or
forty, which is exactly what decides whether to act on it. #27's ratio makes
that case more common, not less.

Investigated against the demo's fixtures, and the way the issue proposes to
resolve "the attribute on the same row" does not survive contact with data.

**Nothing in the code can carry a second number today.** A table is a
`<caption>` and a `<tbody>` of two cells with no header row, and
`Definition#query` returns a hash of label to value from which the table, a
chart's arrays, a ring's slices and a stored snapshot are all built. This is
not a view change.

**A dimension attribute has three obvious implementations and two are wrong.**
Measured, with customer names and their regions, and with statuses and regions
(`paid` orders come from two regions):

| Approach | by customer, region (one each) | by status, region (`paid` has two) |
| --- | --- | --- |
| group by both | correct | `paid` appears twice: the two dimension grouping the issue rejected |
| `MAX(attr)` | correct | `paid` reads `EU`, silently: an arbitrary value shown as fact |
| `CASE WHEN MIN(attr) = MAX(attr) THEN MIN(attr) END` | correct | `paid` is blank, the others right |

A bare column is not an option on a strict database. The third form is one
expression, works on SQLite, PostgreSQL and MySQL, and is the only one that
cannot be silently wrong: a value that differs across the rows of a group is
not shown as though it were one thing.

**A second measure is cheap.** A second grouped calculation merged on the group
key, or one `pluck`, gives `{"paid" => [1.0, 2], ...}` for a rate and the row
count behind it. Ordering and the limit belong to the primary measure and are
untouched: the extras are fetched for the keys already chosen.

### What was considered

**Group by both.** Rejected, above: it multiplies the rows whenever the
attribute is not determined by the label, which is not a case a declaration can
rule out ahead of the data.

**`MAX` or `MIN`.** Rejected: an arbitrary value presented as fact is this
library's worst failure, a wrong number that looks right.

**A second dimension in `by:`.** Rejected: it answers a different question and
multiplies the rows, which the issue itself said.

**A concatenated generated column, or a SQL fragment option.** Rejected: it puts
presentation in the schema, gives up filtering on either part, and a SQL string
in a declaration is the second query language ADR 002 refused.

**Calling it `attributes`.** Rejected as a name: `attributes` is an
`ActiveRecord::Base` method on a `Pane` row, and a column of that name would
shadow it.

## Decision

**A table pane may carry up to three companions: a measure or a dimension of the
same model, drawn as a column beside its label. A measure is its own
aggregate, formatted as it declares, and a dimension is shown only when every
row of the group shares one value.**

```erb
<%= janela_pane Order, :expedited_rate, by: :customer, as: :table, companions: [:orders, :region] %>
```

```
Customer    Expedited rate   Orders   Region
Acme        75.0%            4        APAC
Globex      50.0%            40       EU
```

**What may be named.** A companion is a declared measure or a declared
dimension of the pane's model, by the name the model declared it under, and
nothing else: no column, no expression, no string that becomes SQL (ADR 025,
ADR 032). The pane's own measure and dimension cannot be repeated, and a time
dimension cannot be a companion, since a bucket is not a fact about a label.
A time pane may carry measures. An unknown name is a `BadRequest` that names
the pane's declared measures and dimensions, as an unknown filter does.

**A measure companion** is a second grouped calculation merged on the group key,
one query each, formatted by its own declaration (ADR 020, ADR 038) so a
ratio beside a count reads `75.0%` beside `4`.

**A dimension companion** is `CASE WHEN MIN(col) = MAX(col) THEN MIN(col) END` in
one query for all of a pane's dimension companions. A group whose rows disagree
shows nothing, not a guess. A group whose rows are all null shows nothing too.

**Nothing about the primary changes.** The pane's measure orders and limits it
(ADR 007), the label is the click target, filters and cross-filtering read as
they always did, and the returned hash is still label to value. The
companions are a separate answer keyed by label, so a chart, a ring and a
stored snapshot are built exactly as before.

**Only a table draws them.** A chart, a ring and a single value ignore
companions, so a pane switched between renderers keeps them (ADR 047, ADR 050).

**A table with companions has a header row.** Three unlabelled columns are
unreadable. The `<thead>` carries the label's dimension name and each
companion's name, and a table with no companions is exactly what it is now: no
header row, nothing added.

**Bounded at three, because each is a query.** ADR 025 bounds what one query
may ask for; this bounds how many a pane may run. Four is a refusal that says
so.

**One vocabulary in three places,** as height does:

- `Janela::Pane#companions`, a JSON array of names, validated against the
  model's declared measures and dimensions when the row is saved (ADR 043
  validates a default filter the same way), and a multiple select on the pane
  form.
- `janela_pane` and `janela_snapshot_pane` take `companions:`.
- The pane URL carries `companions[]=orders&companions[]=region`, because the
  server draws the pane again from that URL on every cross-filter.

It is not part of the pane's identity (ADR 029).

## Consequences

- A rate can sit beside the count behind it, which is the more valuable half of
  the issue, and a label can sit beside the fact that gives it its meaning.
- **A dimension companion can be blank where the data disagrees.** That is the
  price of never being wrong, and it is visible: a blank cell in a column that
  should be full is a prompt to look, where a guessed value is not.
- **A stored snapshot shows the base table only.** ADR 009 freezes the result
  a pane had; the companions are not part of what is stored, so a snapshot pane
  with companions renders as if it had none. Storing them is a separate change
  to the stored shape and is left until someone needs a frozen comparison.
- **Up to three more queries per table pane.** The rate at which a page asks
  is the host's (ADR 048); the count each pane makes is bounded here.
- **A migration for stored frames:** `janela_panes` gains a nullable
  `companions` JSON column, additive, taken with `height` and `prominence`
  in one migration step for a host using stored frames.
- **The pane URL grammar grows by an array parameter and the theming contract by
  a header row and the classes on the extra cells,** named in the build and
  documented in `docs/theming.md`. Both are surface ADR 037 freezes, which is why
  this belongs before 1.0.
- What would change this decision: a companion that needs to be a *filter*, not
  only a column, which is a different feature; or a frozen comparison that
  needs the companions stored, which changes ADR 009's shape.
