---
Date: 2026-09-16
Status: Accepted
Related: ADR 001, ADR 002, ADR 004, ADR 007, ADR 009
Triggers:
  - proposing a data store, warehouse, cache or copy of a host's data
  - a pane or a frame being measurably slow on a real host
  - adding a database adapter or a second connection
  - anything that would query outside ActiveRecord and therefore outside the host's scope
Topics: performance, columnar, storage, authorisation, scope, dependencies
---

# ADR 017: Janela Owns No Data Store

## Context

Commercial BI tools mostly answer performance by taking a copy: extract
the host's data into a columnar store the vendor owns, and query that.
Columnar storage is genuinely the right shape for what Janela does, a
`SUM` or a `COUNT` grouped by one dimension over many rows, and the
motivation for keeping that store local rather than in someone else's
cloud is the same instinct that made this project worth starting.

The Postgres ecosystem has caught up in a way that matters here.
[`pg_duckdb` reached 1.0](https://motherduck.com/blog/pg-duckdb-release/)
with over a million downloads by its own account,
[`pg_ducklake` became production ready in January 2026](https://github.com/duckdb/pg_duckdb),
and Citus has had a columnar access method for years. Each of these
puts a vectorised columnar engine **inside** Postgres rather than
beside it, which is the distinction this ADR turns on. Read those
before reopening the question: they are the reason it is worth
reopening at all, and they are also the reason it does not need to be
reopened yet.

ADR 001 already declined a separate data warehouse and ETL. This ADR
records why that holds even now that a local columnar store is
practical, and what Janela does instead.

## Decision

**Janela never holds a copy of a host's data.** No warehouse, no
extract, no second connection, no adapter of its own.

The reason is not performance, it is authorisation. Everything safe
about this gem rests on `on: policy_scope(Order)`, an ActiveRecord
relation carrying the host's Pundit scope and whatever tenancy it
uses (ADR 002, ADR 004). A copy has no relation, no policy and no
tenant filter, so a copy means reimplementing row level security
against it. That is the subsystem ADR 001 refused, and getting it
subtly wrong shows one tenant's numbers to another, which is a far
worse failure than a slow pane.

**Janela stays fast by generating SQL a columnar engine can
accelerate, and by getting out of the way.** A host that needs
analytical speed converts the table it reports on, with
[`pg_duckdb`](https://github.com/duckdb/pg_duckdb), `pg_ducklake`,
Citus columnar or whatever its own database offers. The
table stays addressable by ActiveRecord, so Pundit, tenancy and every
part of Janela's query path keep working, and **Janela gets faster
with no change to the gem at all**. That is a page of documentation
rather than an architecture, and it is the right division: the host
owns its storage, the gem owns the question.

It follows that the gem's obligation is to emit plain, grouped,
aggregate SQL and not to outsmart the planner. ADR 007's ordering and
limit are the whole of the performance surface Janela owns.

**Snapshots are already the useful part of a warehouse.** ADR 009
persists frozen results with no extract, no staleness question and no
authorisation problem, because a snapshot was taken *under* a scope
and stores only what that scope returned. Anything that wants
precomputed aggregates should reach for a snapshot before it reaches
for a store.

**No measured problem exists.** The demo runs on 600 rows, the
commercial host's largest reported table on about 1,100, the personal
host's on four. Nothing is slow, and ADR 001 is explicit about not
building for hypothetical futures.

**What would change this.** A pane, measured on a real host, that is
too slow to use after its table has been made columnar and after
ADR 007's limit has been applied. At that point the question is
whether Janela should read a host-owned materialised view or
continuous aggregate, which is still the host's data under the host's
scope, and not whether Janela should own a store. That distinction is
the thing this ADR is really protecting.

## Consequences

- A host with genuinely large tables must do something about its own
  storage, and the gem can only document the options rather than solve
  it. That is a real limitation and it is the correct one: the
  alternative is a copy whose access control Janela cannot honestly
  guarantee.
- The README gains a short performance section naming the columnar
  extensions and pointing at snapshots. It must be honest that the
  gem has not been tested against a large columnar table, because it
  has not.
- Refusing a second connection also refuses a whole category of
  feature: querying anything that is not an ActiveRecord model in the
  host. Reporting across two applications, or over a CSV, or over a
  warehouse the business already has, is out of scope for the same
  reason.
- [`activerecord-duckdb`](https://rubygems.org/gems/activerecord-duckdb)
  is at 0.1.0 and describes itself as incomplete, so even the tempting
  version of this would be built on something immature today. That is
  a timing observation rather than a reason, and it will stop being
  true, which is why it is recorded as an observation.
- This is the third time a scope question has been settled by asking
  where authorisation lives (ADR 002's `on:`, ADR 012's persisted
  panes, now this). It is worth naming as the project's actual test:
  **if a feature cannot be expressed as a scoped ActiveRecord
  relation, it is probably not Janela's to build.**
