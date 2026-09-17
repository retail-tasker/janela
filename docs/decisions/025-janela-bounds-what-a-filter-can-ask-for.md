---
Date: 2026-09-17
Status: Accepted
Related: ADR 002, ADR 005, ADR 006, ADR 007, ADR 008, ADR 015, ADR 024
Triggers:
  - a filter reaching Ransack from a URL
  - adding a predicate, or widening what a filter may contain
  - a query with no LIMIT, or a grouped query over a high cardinality dimension
  - deciding whether a bound belongs to Janela or to the host
Topics: security, ransack, urls, performance, cross-filtering
---

# ADR 025: Janela Bounds What a Filter Can Ask For

## Context

ADR 002 chose Ransack so that a host's filters are the Ransack params a
Rails developer already reads, and made a dimension declaration the
allowlist of attributes. That part holds. What it left open is which
*predicates* may be used on an allowed attribute, and issue #8 asked the
question.

Measured against the demo before writing this:

| Filter passed | Result today |
| --- | --- |
| `status_eq: "paid"` | 300.0 |
| `status_cont: "pai"` | 300.0 |
| `status_start: "p"` | 325.0 |
| `status_matches: "%aid"` | 300.0 |
| `customer_name_cont: "cm"` | 150.0 |
| `amount_gt: 60` | `BadRequest`, `amount` is not a dimension |
| `status_frobnicate: "x"` | `BadRequest`, no such predicate |

So the attribute allowlist works, and every predicate Ransack knows is
reachable on an allowed attribute, including through an association.
`Ransack::Predicate.names` has 62 entries. The sharpest is `_matches`,
which takes an arbitrary `LIKE` pattern, so a leading wildcard scan of an
indexed column is one URL edit away, in a page a host has already
authorised someone to read.

Two other bounds are missing. A grouped query with no `limit` carries no
`LIMIT` in SQL at all, so a breakdown by a high cardinality dimension
returns a row per value. And a single filter can carry any number of
values: `status_in` with 5001 of them was answered rather than refused,
which matters more since ADR 024 made `_in` the shape a click writes.

**The question worth deciding is whose job this is.** ADR 002
deliberately spent Ransack's familiarity on the host, and the obvious
objection to bounding anything here is that a host can restrict filtering
itself by defining `ransackable_attributes`. That objection is false, and
the measurement above is why: `ransackable_attributes` allows *columns*,
and Ransack has no per-attribute predicate allowlist. Once a host allows
a column for equality, it has allowed `_matches` on that column too.
There is nowhere else for this bound to live.

Options considered and rejected:

- **Leave it, and document it.** A dashboard is often the first page a
  company exposes to people it would not give SQL to, and the library
  hands them a pattern scan. Documenting a sharp edge is not the same as
  not having one.
- **Restrict to `_eq` and `_in`,** as issue #8 proposed. It would delete
  documented behaviour: ADR 006 allows `placed_on_gteq` and
  `placed_on_lt` so a host can narrow a time range, and the README says
  so. A range filter on a time dimension is a dashboard's ordinary
  question, not an escape hatch.
- **A setting listing the allowed predicates.** Rejected on the test
  ADR 021 and ADR 023 set: a setting earns itself when the judgement is
  made once about the whole application and cannot be inferred. This one
  can be inferred, from what kind of dimension is being filtered.

## Decision

**Janela allows only the predicates a dashboard asks in, bounds what a
grouped query returns, and bounds how many values one filter may carry.**

**Predicates are allowed by the kind of dimension.** A categorical
dimension takes `eq`, `in` and `null`, which is exactly what a click
produces (ADR 024). A time dimension additionally takes `gteq`, `gt`,
`lteq` and `lt`, because narrowing a range is how a time dimension is
filtered (ADR 006). Anything else raises `Janela::BadRequest` naming the
attribute and the predicates that are allowed, the way a disallowed
attribute already does.

The check belongs beside the existing one in `Definition#filter`, which
already raises for a filter Ransack silently dropped. `Ransack::Predicate
.detect_from_string` splits a key into attribute and predicate, so this
is a comparison, not a parser.

**One ceiling, 1000, in both places.** A grouped query with no `limit`
gets `LIMIT 1000`, and a single filter may carry at most 1000 values.
1000 is not a new number: ADR 007 already fixed it as the maximum a host
may ask for, so the ceiling is the existing maximum applied by default
rather than a second constant to reason about. A pane that hits the
ceiling is unreadable long before it is reached, so this is a bound on
harm, not on usefulness.

**Time panes keep their exemption.** ADR 007 exempted them from `limit`
because a time series shows its whole range, and gap filled buckets are
generated rather than returned by the database. The ceiling does not
apply to them. A host that wants fewer buckets narrows the range or
coarsens the granularity, which ADR 006 already allows.

**No setting is added.** A host that genuinely needs a pattern search
already has the documented way in: pass a pre-filtered relation through
`on:`, where it writes the condition itself in its own code, under its
own authorisation, rather than accepting one from a URL.

## Consequences

- The reachable filter surface goes from 62 predicates to three on a
  categorical dimension and seven on a time dimension. That is the point.
- **Breaking for a host that passes anything else.** A `_cont` or
  `_matches` filter that works today raises `BadRequest` after this. It
  needs an `UPGRADING.md` entry naming the allowed predicates and the
  `on:` alternative, and the release carrying it is minor (ADR 015).
  The doctor cannot find this one by reading source, because the filter
  is usually built at runtime; the upgrade note is the whole mitigation.
- A stored snapshot holds the filters it was taken under (ADR 009). One
  taken with a now disallowed predicate would raise when read. Whether to
  refuse those at read time or leave stored results alone is not decided
  here and should be settled while building this.
- The default ceiling changes a number a host can see: a breakdown over
  more than 1000 values silently showed all of them and will now show
  1000. It is ordered by the measure, so what is cut is the smallest, and
  a host that wants a different cut passes `limit`.
- What would change this: a host with a real need for a predicate not on
  the list. The answer is to add that predicate to the list for that kind
  of dimension, in an ADR that says which dashboard question needed it,
  not to make the list configurable.
