---
Date: 2026-09-29
Status: Accepted
Related: ADR 024, ADR 025, ADR 028, ADR 040, ADR 043
Triggers:
  - adding not_eq or not_in to a dimension's allowed predicates
  - a frame's default filter, a host's fixed filter or a reader's q[...]
    needing to say "not this value" rather than listing every other one
  - widening CATEGORICAL_PREDICATES or TIME_PREDICATES
  - reasoning about which dashboard question justifies a new predicate
Topics: security, ransack, dsl, frames, cross-filtering
---

# ADR 044: A Categorical Dimension Can Say What It Excludes, Not Only What It Includes

## Context

#64: a categorical dimension's allowed predicates (ADR 025, corrected by
ADR 028) are `eq`, `in`, `null` and `not_null`. There is no way to say
"not this one." Reproduced against the demo:

```ruby
Order.janela.narrow(Order.all, "status_not_eq" => "refunded")
# => Janela::BadRequest: Order does not allow status_not_eq. This
#    dimension allows status_eq, status_in, status_null, status_not_null.
```

`Definition#narrow`/`#filter` is the single choke point every filter
source goes through (ADR 025), so a reader's `q[...]`, a host's `where:`
(ADR 040) and a frame's `default_where` (ADR 043) all hit the same wall.

**The question is not whether the list is wrong, the way ADR 028 found
it.** ADR 028 restored `not_null` because it was already shipped, tested
behaviour that a first-principles list had missed. `not_eq`/`not_in` are
not already shipped anywhere; nothing measured today shows them working.
This is a request for new capability, and ADR 028 already set the bar for
that: *"a predicate belongs there if a dashboard produces it, or if it is
a boolean test of presence rather than a way to phrase a match."*
`not_eq`/`not_in` fail both readings as ADR 028 wrote them: ADR 024 says
a click only ever writes `eq`/`in`, and excluding a value is not a
presence test the way `not_null` is.

**But a dashboard question that needs it already exists, and it is the
one that motivated #63.** ADR 043 built a frame's permanent
`default_where` for exactly this sentence: "this queue never counts an
archived row." That sentence can be typed today only as `status_in` with
every value except `archived`, and #64's own point stands: that
inclusion list silently stops covering the dashboard the day a new
status value is added, which is the same quiet wrongness ADR 024, ADR
032 and ADR 034 all already refuse elsewhere. An exclusion degrades
differently from an inclusion when the data shape changes under it, and
"never" is a more honest word for what `default_where` is for than a
list that has to be kept in sync with every value a column might hold.

### What was considered

**Leave it, and require `_in` naming every value but the excluded one.**
Rejected for the reason above: it is not equivalent, it is a
maintenance trap that looks correct until a new value appears.

**Allow `not_eq`/`not_in` only through `where:`/`default_where`, not
through the reader's `q[...]`.** Considered, because the motivating case
is a frame's own permanent filter, not something a reader asks for.
Rejected: `narrow` is deliberately the one choke point every caller
shares (ADR 025), and splitting it into a predicate list parameterised
by which caller is asking is new configurability of exactly the kind
ADR 021 and ADR 023's test rejects, to protect nothing. ADR 040 already
says a fixed filter is a view filter, not an authorisation boundary: a
reader who can edit a pane URL can already ask for anything the
dimension allows, so refusing the reader `not_eq` while allowing a host
the same predicate on the same attribute buys no security, only a
second thing to explain.

**A fourth verb in the DSL, "exclude," alongside ADR 025's "select" and
"range" groupings.** Rejected. Nothing about `not_eq`/`not_in` needs a
name Ransack does not already give it; the project keeps the DSL a thin
layer over Ransack rather than a query language of its own (CLAUDE.md's
forkability vision), and "select"/"range" were never a formal surface,
only informal shorthand for reading ADR 025. Two more entries in the
existing list cost nothing that a new grouping would justify.

**Time dimensions get their own decision about whether they need it.**
Considered, and rejected as unnecessary work: no dashboard question
measured here or in #63 asks to exclude a single instant from a time
range, so nothing argues for building it. But `TIME_PREDICATES` is
`CATEGORICAL_PREDICATES + %w[gteq gt lteq lt]` (`lib/janela/dimension.rb`),
the same way it already inherits `not_null` without a time-specific
argument for that either. Carving `not_eq`/`not_in` out of the inherited
half would be a special case with nothing behind it. It stays inherited.

## Decision

**A categorical dimension's allowed predicates gain `not_eq` and
`not_in`, for the same reason `not_null` is already there: a real
dashboard question, already built on top of this list (ADR 043),
cannot be phrased any other way that survives a new value being added.**

```ruby
# lib/janela/dimension.rb
CATEGORICAL_PREDICATES = %w[eq in not_eq not_in null not_null].freeze
```

`TIME_PREDICATES` inherits both, unchanged in its own definition. No new
DSL vocabulary is introduced: `not_eq` and `not_in` are exactly Ransack's
own predicate names, entries in the same flat list every other allowed
predicate already sits in.

This predicate is reachable through `where:` (ADR 040), `default_where`
(ADR 043) and a hand-built or shared `q[...]` link, the same as every
other allowed predicate. It is not reachable through a click: ADR 024
writes only `eq`/`in`, and toggling a value never produces an exclusion.
Worth saying plainly wherever this is documented, so nobody goes looking
in the frame UI for a gesture that was never built.

## Consequences

- #63's motivating sentence, "this queue never counts an archived row,"
  becomes expressible as `default_where: { "status_not_eq" => "archived" }`
  and stays true when a new status value is added, which the `_in`
  workaround could not.
- **Additive, not breaking.** Nothing that worked before is refused now;
  the list only widens. No `UPGRADING.md` entry is needed on that
  account (ADR 015), though the release notes should say the predicate
  exists, the same way a new capability is always announced.
- The README and any documentation listing a dimension's allowed
  predicates needs the two new entries alongside the existing four, kept
  in sync with `CATEGORICAL_PREDICATES` rather than restated by hand.
- `reject_oversized_filters!` (ADR 025) already bounds any predicate
  whose `Ransack::Predicate#wants_array` is true, which includes
  `not_in`, so the 1000 value ceiling applies to it without a code
  change.
- Test coverage belongs in `definition_query_test.rb` (the choke point
  itself), `fixed_filter_test.rb` and `frame_default_filter_test.rb` (the
  two callers ADR 040 and ADR 043 built), so all three layers are proven
  rather than only the one that motivated this. Not built here.
- What would change this decision: a host with a measured need to
  exclude a specific instant from a time dimension, which nothing today
  shows evidence of. The answer then is the same rule ADR 025 already
  set: add it to the list in an ADR that names the dashboard question,
  not by making the list configurable.
