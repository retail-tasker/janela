---
Date: 2026-09-15
Status: Accepted
Related: ADR 001, ADR 002, ADR 005, ADR 008
Triggers:
  - publishing a dashboard or pane for an audience that must not see live data or slicers
  - adding a database table, migration or model to the engine
  - scheduling anything with ActiveJob
  - changing what a snapshot stores or how a stored pane is addressed
  - anything called static mode, publish, report history or as-of
Topics: snapshots, static-mode, publishing, persistence, activejob, urls
---

# ADR 009: Snapshots

## Context

The founding brief describes two modes over one definition: a dynamic
dashboard for analysts, with slicers and cross-filtering, and the same
dashboard published as a locked, static view for an audience that
should see exactly what was signed off and nothing else. Everything
built so far is the dynamic mode. This ADR is the static one.

The brief also settled the shape in principle: publishing spawns a
frozen record through ActiveJob rather than toggling the live
dashboard, so an analyst editing tomorrow cannot silently change what a
client saw today. What remained open was what exactly is frozen, how a
frozen pane is addressed, and how much new surface the engine grows.

This is the first thing Janela writes to a database. Until now the
engine was read-only over the host's own tables.

The incumbent's vocabulary is a useful check. Power BI Report Server
calls this a report snapshot, "a report that contains layout
information and query results retrieved at a specific point in time",
accumulates them as report history, and keeps saved filter state
(bookmarks) as a separate concept. That separation matches ADR 008.

## Decision

**A snapshot freezes results, not HTML.** Each pane's result, the
label-to-value hash or the single value, is stored as JSON together
with what produced it: model route key, measure, dimension,
granularity, limit. Rendering stays live code, so a snapshot taken
today is drawn with tomorrow's chart improvements, stays a few
kilobytes, and cannot freeze a rendering bug into history. The
renderer is not stored; a stored pane can be shown as a table or a
chart by whoever renders it, because the renderer is a viewing choice,
not part of the data.

**One row is one taking.** "Publish this dashboard as of today" means
several panes frozen at the same instant under the same filters, so a
`Janela::Snapshot` row holds a name, `taken_at`, the filters, and an
array of pane results. There is no Dashboard model and no dashboard
DSL: the host's page is the dashboard, and the host names the panes to
freeze. If the host renders its live page from the same list it passes
here, nothing is declared twice.

```ruby
Janela::Snapshot.take(name: "September 2026", filters: { status_eq: "paid" }) do |take|
  take.pane Order, :revenue,                                on: policy_scope(Order)
  take.pane Order, :revenue, by: :status,                   on: policy_scope(Order)
  take.pane Order, :revenue, by: :placed_on, granularity: :week
end
```

`on:` is per pane, since a snapshot may span models and a relation
cannot be serialised. It defaults to the model's `all`.

**A stored pane has a URL, and it says as of.** Following ADR 005's
naming table, an analyst says "orders revenue by status *as of* the
September snapshot":

```
/dashboards/snapshots/42/orders/revenue/status
/dashboards/snapshots/42/orders/revenue/status?as=bar
```

Same grammar as a live pane with a `snapshots/:id/` prefix. A pane the
snapshot does not contain is a 404, and `q` is ignored: the filters
were fixed when it was taken. The naming table gains a row: *as of* is
`/snapshots/:id/`.

**Static mode is what a stored pane is, not a switch.** It has no
filter key, no click action, no dashboard controller, no `q`. Tables
render values without buttons; charts ignore clicks. That is the
"no slicers, no surprises" mode from the README, and it costs nothing
new because time panes already taught the code to be non-clickable.
The host renders one with `janela_snapshot_pane snapshot, Order,
:revenue, by: :status, as: :bar`, the same shape as `janela_pane`.

**Taking is a Ruby method; the job is a thin wrapper.**
`Snapshot.take` is the API and runs wherever it is called. A
`Janela::SnapshotJob` wraps it for ActiveJob so a host can schedule it
with whatever it already uses, taking serialisable arguments (name,
filters, a list of pane hashes). Because a job cannot receive a
relation, the shipped job uses each model's default scope. A tenanted
host writes its own job around `take`, passing `on:` from whatever
identifies the tenant. This is documented rather than solved: tenancy
is the host's, as ADR 002 decided.

**One table, named by convention.** `janela_snapshots` with `name`,
`taken_at`, `filters` (JSON), `panes` (JSON) and timestamps, installed
with the standard `rails janela:install:migrations`. The `janela_`
prefix is the Rails engine convention that keeps an engine's tables
from colliding with the host's, as `active_storage_blobs` and
`solid_queue_jobs` do. It is not configurable: the host never types
the table name, only `Janela::Snapshot`, and a knob for a name nobody
types is exactly what ADR 001 declines to add. Snapshots are
immutable; deleting them is host policy.

**Who may see a snapshot is the host's decision.** Snapshot panes are
served through the same controllers, so the host's authentication
applies by default. An external audience with no accounts is the case
that motivates snapshots, and it is served by the host building its
own page over `janela_snapshot_pane` behind whatever share tokens or
signed links it already trusts. Janela stays out of access control,
per ADR 002 and ADR 004.

## Consequences

- Janela gains a migration, a model and a job: its first write
  surface. Hosts that never take a snapshot never need the migration;
  live dashboards remain read-only over the host's tables.
- Result JSON is small for category panes and bounded by `limit`
  (ADR 007). A time pane over a long range at fine granularity is the
  one way a snapshot gets large, and that is visible at take time.
- Storing the renderer's inputs rather than its output means a
  snapshot cannot reproduce an old rendering exactly. Accepted: the
  numbers are the record, not the pixels.
- Per-pane `on:` is more typing than one scope for the whole taking.
  It is also the only honest option once a snapshot spans models, and
  it keeps the tenancy question where ADR 002 put it.
- The shipped job is deliberately naive. If most hosts turn out to
  write their own, the job should be removed rather than grown.
- Snapshots are additive to the public API. Whether they ship in the
  next release or the one after is a release decision, not a design
  one.
- Not decided here: comparing two snapshots, an "other" bucket for
  limited panes, retention, or an index page listing snapshots. Each
  is its own ADR if a host needs it.
