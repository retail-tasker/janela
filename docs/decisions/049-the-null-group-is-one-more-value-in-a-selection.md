---
Date: 2026-09-30
Status: Accepted
Related: ADR 008, ADR 024, ADR 025, ADR 028, ADR 037, ADR 040, ADR 043
Triggers:
  - selecting the (none) group together with a value
  - a filter that carries both _in and _null for one dimension
  - changing what a pair of filter parameters means, or how they combine
  - the frame controller's handling of the null group in toggle
  - a host's where: or default_where naming a value and the null group
Topics: cross-filtering, ransack, urls, dsl, accessibility, roadmap
---

# ADR 049: The Null Group Is One More Value in a Selection

## Context

#69: with a chart of A, B and (none) you can select A and B together but not
A and (none). This is ADR 024 working as written. It made the null group
exclusive within its dimension, because a click writes `channel_in[]=web` for
a value and `channel_null=1` for the group, Ransack ANDs its conditions, and
the pair asks for rows whose channel is both null and web. That returns zero
rows without saying so, and the ADR chose to refuse the combination over
rendering an empty dashboard. What it could not offer was a way to say "web
or none", and a reader now wants exactly that.

Measured against the demo (channel is nil on one row, `phone` on one and
`web` on two), through Janela's own filter path:

| Filter | Rows |
| --- | --- |
| `channel_in: [web]` and `channel_null: 1` | 0 |
| `channel_in: [web, nil]` | 2 (Ransack drops the nil: no null rows) |
| `channel_in: [web, ""]` | 2 (same) |
| `channel_eq_any: [web, nil]` | refused, not an allowed predicate (ADR 025) |
| `g[]` with `m: or` | refused, and ADR 024 rejected it for an unreadable URL |
| `channel_not_in: [phone]` | 2 (SQL drops the null rows) |

So nothing Ransack offers through Janela's allowed predicates says "A or none".

**But Ransack can say it if Janela asks for it.** Given Ransack's own
grouping, built by Janela and never appearing in a URL:

- `g: [{ m: "or", channel_in: ["web"], channel_null: "1" }]` returns 3, as
  `WHERE channel IN ('web') OR channel IS NULL`.
- Merged with another filter it combines as AND:
  `status IN ('paid') AND (channel IN ('web') OR channel IS NULL)`, 2 rows.
- Through an association it keeps the join:
  `LEFT OUTER JOIN customers ... WHERE (customers.region IN ('APAC') OR
  customers.region IS NULL)`.

So the union is expressible without a new predicate, a new grammar, or
anything in the URL a person has to learn.

### What was considered

**A new predicate, `in_or_null`.** `q[channel_in_or_null][]=web`. Rejected.
It is a second way to spell a selection that Janela already spells with two
keys it already reads, it would be a new entry in ADR 025's list for a
question that list already answers, and the frame controller would have to
translate between the two forms when a value is added to a selection that
held the null group.

**The null inside the `_in` list, as a token such as `(none)`.** Rejected.
It collides with a real value that is spelled `(none)`, and Ransack drops the
nil it would have to become.

**`g[]` grouping in the URL.** Still rejected, for ADR 024's reason: the URL
is one a person reads and edits (ADR 008). Using the grouping *inside* Janela
is a different thing; nothing in the URL changes.

**Leave it exclusive.** The present state. It costs a question a dashboard
plainly has ("web or unknown") that can be answered by no gesture.

## Decision

**The null group is one more member of a selection. A dimension that carries
`_in` (or `_eq`) and `_null` means the union, and the frame controller adds
and removes the null group like any other value.**

**At the server.** `Definition#filter`, the one choke point every filter
passes through (ADR 025), validates the parameters exactly as it does now:
declared dimensions, the allowed predicates, the value ceiling. It then builds
the result with each such pair for one dimension taken out of the AND and
applied as an OR of the two, merged back with everything else. The URL is
what it was:

```
q[channel_in][]=web&q[channel_null]=1
```

This applies to a reader's `q[...]`, a host's `where:` (ADR 040) and a
frame's `default_where` (ADR 043) alike, because they share the choke point.
Today that pair returns zero rows, so no working link or stored filter depends
on it.

**It is the inclusions that union, and the exclusions stay an intersection.**
"A or none" is two ways of being selected, so they OR. `not_in` with
`not_null` is two ways of being ruled out ("anything but A, and not none"),
so they AND, as they do now. `_null` with `_not_null` remains a contradiction
and returns nothing.

**At the frame controller.** `toggle` stops treating the null key as
exclusive. The gestures are ADR 024's, unchanged:

| Gesture | Result |
| --- | --- |
| Click (none) | (none) alone is selected |
| Click a value while (none) is selected | that value alone replaces it |
| Ctrl or Cmd click (none) | (none) is added to, or removed from, the selection |
| Ctrl or Cmd click a value while (none) is selected | the value is added, (none) stays |

`clearDimension` still clears the dimension's keys when a plain click replaces
the selection. The highlight needs nothing: a pane already marks `(none)`
among the selected values (`Query#selected_values`).

## Consequences

- A dashboard can answer "A or none", which nothing could before, and a
  selection of A, B and (none) is three ordinary members of one set.
- **ADR 024's exclusivity paragraph is superseded.** Its measurement of the
  AND stands and is why the union is built explicitly. The rest of 024, the
  gestures, `_in`, the keyboard, stands. ADR 024's status line says so.
- **The meaning of a documented pair of parameters changes**, which ADR 037
  counts as public surface, and is why this belongs before 1.0. It is
  narrowly breaking: the pair returned no rows before, so the only thing that
  could depend on it is a link or a stored filter that always showed an empty
  pane. `CHANGELOG.md` says so under Changed, and no `UPGRADING.md` entry is
  needed because there is nothing to change.
- The chart and the table need no change of their own: the null group is
  already a label with a filter, and the selection highlight already includes
  it.
- A snapshot taken under the pair stores its filters as it does any others
  (ADR 009), and a snapshot taken before this holds the zero rows it always
  did. Stored results are never re-run.
- Build must test the choke point for `_in` and `_eq` each with `_null`,
  through an association, alongside a filter on another dimension, with the
  value ceiling still enforced, with `not_in` and `not_null` still
  intersecting, and the frame controller in a browser for the four gestures
  above.
- What would change this decision: a host needing the union for a *range* on
  a time dimension, which is an OR of two ranges and a different feature
  (ADR 045), or a dimension where "none" is not a value at all but an error.
