---
Date: 2026-09-13
Status: Accepted
Related: ADR 001
Triggers:
  - adding or changing the measures/dimensions DSL
  - deciding how a dashboard filter reaches the query layer
  - adding a dependency to the query path
  - wiring authorisation around a dashboard query
  - adding time-granularity or drill-down dimensions
Topics: dsl, query-layer, ransack, dependencies, authorisation
---

# ADR 002 -- Measures and Dimensions over Ransack

## Context

ADR 001 committed to shipping the load-bearing core: declarative
measures/dimensions, and cross-filtering. This ADR covers the first
half, spiked against real ActiveRecord models in `test/dummy`.

Two questions had to be answered by building rather than arguing.

**What sits under the DSL?** The spike first hid Ransack behind
Janela's own filter vocabulary (`where: { region: "EU" }`), translating
dimension names into Ransack predicates. That worked, but the
familiarity a Rails developer gets from Ransack was spent entirely
inside Janela -- the host still inherited Ransack's constraints while
touching none of its API. Plain ActiveRecord was the obvious
alternative, since every Janela filter is only ever "dimension in
values".

**How does authorisation get in?** The brief already ruled out
building a row-level-security subsystem. The open question was whether
to depend on Pundit directly.

A survey of the filtering ecosystem informed the first question.
Ransack has roughly 115M downloads against 1.9M for the next
most-used option, so it is the only filter gem that a Rails developer
can be assumed to already know. Notably, none of the filter gems do
aggregation -- the `GROUP BY` half of Janela is Janela's own code
regardless of what sits underneath the filter half.

## Decision

**The DSL is a `janela` block on the model.**

```ruby
class Order < ApplicationRecord
  belongs_to :customer

  janela do
    measure :revenue, sum: :amount
    measure :orders, count: true
    dimension :status
    dimension :region, through: :customer
  end
end
```

A measure takes exactly one aggregate of `sum`, `count`, `average`,
`minimum`, `maximum`. A dimension is a column on the model, or a
column on an association via `through:`.

**Filters are Ransack params, passed through rather than translated.**

```ruby
Order.janela.query(:revenue, by: :status, where: { customer_region_in: %w[APAC EU] })
```

The host can hand `params[:q]` from a standard `search_form_for`
slicer straight to Janela with no translation layer, and the
cross-filter controller emits predicate names every Rails developer
already reads fluently. Ransack is a runtime dependency.

**Dimensions define the Ransack allowlist.** Declaring a dimension is
declaring that the attribute is filterable, so Janela generates
`ransackable_attributes` and `ransackable_associations` on the model.
A model that already declares its own keeps it.

**A dropped filter raises.** Ransack silently discards conditions its
allowlist does not permit. For a BI tool that means quietly returning
unfiltered numbers that look filtered, so Janela verifies every
supplied filter was applied and raises `Janela::Error` otherwise.

**Authorisation is a hook, not a dependency.** `query` accepts `on:`,
any relation, defaulting to `model.all`:

```ruby
Order.janela.query(:revenue, on: policy_scope(Order))
```

Pundit users recognise that line; CanCanCan users pass
`Order.accessible_by(current_ability)`. Janela does not depend on
either.

## Consequences

- Janela's public filter API is coupled to Ransack's predicate naming.
  Replacing the filter engine later is a breaking change. Accepted
  deliberately: ADR 001 prefers one obvious way, and Ransack is the
  obvious Rails way to filter.
- **A `through:` dimension requires the associated model to allowlist
  the attribute itself.** Ransack's allowlist is per-class, so Janela
  can only own the allowlist of the model the dimensions are declared
  on. Associated models need both `ransackable_attributes` and
  `ransackable_associations` defined or Ransack raises. This must be
  documented prominently; it is the most likely source of confusion
  for a first-time user.
- Filtering and grouping on the same association produces a redundant
  aliased join, because Ransack builds its own join regardless of one
  already being present. Results are correct; the cost will compound
  as dashboards add through-dimensions. Revisit if it shows up in real
  query plans, not before.
- Aggregation stays Janela's own code. No filter gem offers it, so
  nothing in this decision reduces the surface area Janela maintains
  for measures.
- Time-granularity dimensions (`granularity: :day`) are not built.
  When they are, Groupdate is the conventional answer and should be
  evaluated then -- time-zone-correct bucketing is genuinely fiddly
  and worth a dependency in a way filtering was not.
- Active Search, the search framework 37signals is introducing at
  Rails World 2026, is text search across swappable engines and does
  not overlap this decision. Worth revisiting only if it ships facet
  counts, which are adjacent to slicer counts.
