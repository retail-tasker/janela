# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- A request for a model, measure, dimension or stored pane that does not exist is a 404; a renderer, granularity, limit or filter the request may not use is a 400. The response is a plain sentence, inside the requesting Turbo Frame when there is one, and the detail goes to the log instead of the client. `Janela::NotFound` and `Janela::BadRequest` subclass `Janela::Error`.

## [0.2.0] - 2026-09-15

Breaking. Renames and a new URL scheme while the only installation is the author's own (ADR 005).

### Changed

- `janela_visual` is now `janela_pane`; `Janela::Visual` is `Janela::Pane`; CSS hooks are `janela-pane`, `janela-chart`, `janela-value`, `janela-empty`.
- A pane's URL is `/<mount>/<model route key>/<measure>[/<dimension>]?as=bar&q[...]` instead of `/<mount>/visual?model=...`. Frame ids follow the same shape.
- The gem no longer ships its Rakefile, which referenced the unshipped dummy application.
- The helper finds the engine's mount in the host's routes, so `mount Janela::Engine => "/reports", as: :reports` works. Documentation and the dummy application mount at `/dashboards`.

### Added

- A pane with no dimension renders the measure's single total.
- Time dimensions: `dimension :placed_on, granularity: :month` buckets with Groupdate (`hour` to `year`), gap-filled, labelled in Ruby. Override per pane with `?granularity=week` or `janela_pane ..., granularity: :week`. Time panes re-scope with the dashboard but are not yet click sources (ADR 006).
- `as: :line` renderer for time series.
- Groupdate is a runtime dependency.
- Published to rubygems.org through trusted publishing; a public demo of `test/dummy` deploys from `main`.
- Snapshots: `Janela::Snapshot.take` freezes several panes' results at one instant under one set of filters; `janela_snapshot_pane` renders a stored pane, static by nature, at `/snapshots/:id/<model>/<measure>[/<dimension>]`. `Janela::SnapshotJob` for scheduling. First migration: `rails janela:install:migrations` (ADR 009).
- Dashboard filters live in the page URL as `q[...]`; a reload keeps them and a filtered dashboard is shareable. The server renders the initial state from `params[:q]` (ADR 008).
- Category panes are ordered by their measure, largest first, in SQL. `?limit=N` / `janela_pane ..., limit: N` keeps the top N (ADR 007).
- `dimension :customer, through: :customer, column: :name` names a dimension for its meaning while reading another column.


## [0.1.0] - 2026-09-15

First alpha, installed from GitHub for testing in a single host application.

### Added

- `janela do ... end` on an ActiveRecord model declares measures (`sum`, `count`, `average`, `minimum`, `maximum`) and dimensions, including dimensions reached through an association.
- `Model.janela.query(measure, by:, where:, on:)`. Filters are Ransack params; `on:` accepts any relation such as `policy_scope(Model)`.
- Declaring a dimension defines the model's Ransack allowlist. A filter Ransack would silently drop raises instead.
- Rails engine with `janela_dashboard` and `janela_visual` helpers. Each visual is a Turbo Frame; a Stimulus controller cross-filters them by rewriting frame `src`.
- Bar charts via Chart.js (`as: :bar`). A click on a bar is the same filter toggle as a click on a table value.
- The selected value on a visual's own dimension is marked `aria-pressed` on tables and highlighted on charts.
- npm package `@retail-tasker/janela` exposing the two Stimulus controllers for jsbundling hosts; importmap pins for importmap hosts, with a vendored Chart.js.
- Only models that declare a `janela` block are addressable over HTTP.
- ADRs 001 to 004 in `docs/decisions/`, shipped inside the gem.

[0.2.0]: https://github.com/retail-tasker/janela/releases/tag/v0.2.0
[0.1.0]: https://github.com/retail-tasker/janela/releases/tag/v0.1.0
