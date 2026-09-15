# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A dashboard can be data. `Janela::Frame` holds a name and a grid (`columns` 1 to 12, `gap` 0 to 8), `Janela::Pane` holds one visual (`position`, `span` 1 to 12, model, measure, dimension, renderer, granularity, limit and an optional title of its own), and `janela_frame @frame` renders one. The block form is unchanged, so nothing already built has to move (ADR 012, ADR 014). Run `bin/rails janela:install:migrations && bin/rails db:migrate` for the two new tables.
- A pane row is rendered by its own nested route, `<mount>/:frame_id/panes/:id`, and identified in the DOM as `janela_pane_<id>`, so two rows showing the same measure by the same dimension do not share a turbo frame. The ad hoc pane grammar from ADR 005 is unchanged.
- A frame renders every pane inline on the first response, so a shared link is a correct dashboard before any JavaScript runs and a page load makes no request per pane. Filters in the page URL apply to every pane either way.
- A pane row is validated against the registry on save: the model must have a `janela` block, the measure, dimension, renderer and granularity must be declared or supported, a granularity only applies to a time dimension, and a limit is 1 to 1000. A bad row is rejected with a readable message rather than rendering as a missing pane later.
- `Janela::Frame belongs_to :owner, polymorphic: true, optional: true`. Janela sets nothing there and reads nothing from it; it exists so a multi tenant host's Pundit `Scope` has a column to filter on. Every lookup of a frame or a pane row goes through that scope, so another tenant's frame is a 404 (ADR 014).
- A stylesheet, `app/assets/stylesheets/janela.css`, which a host includes with `stylesheet_link_tag "janela"`. It defines the grid classes for every value the records allow, styles the existing `janela-pane`, `janela-chart`, `janela-value` and `janela-empty` hooks so a pane is legible on install (#15), and collapses to one column on a narrow screen. Set `--janela-space` to move the whole spacing scale. The engine never injects it into a layout it does not own (ADR 016).
- `bin/rails janela:doctor` reads a host application and lists what it still needs to do: identifiers from an earlier version, unregistered Stimulus controllers, a `through:` dimension whose associated model has no allowlist, an unmounted engine, and whether anything authenticates the endpoints. Exits non-zero on an error so it can run in CI (ADR 015).
- `UPGRADING.md`, shipped inside the gem, with the steps for each release that needs a host to act. The changelog says what changed; the upgrade guide says what to do.

### Changed

- The frame controller no longer rewrites pane `src` attributes when it connects, only when the filters actually change. A pane rendered inline would otherwise be fetched again immediately and its first render thrown away.
- A frame or a pane a host's scope cannot see now answers with Janela's own sentence inside the requesting turbo frame, rather than the host's error page. Still a 404.
- Breaking rename, no behaviour change (ADR 014). A host must act on all of these:
  - The Stimulus controller `janela--dashboard` is now `janela--frame`, and its file is `frame_controller.js`. Change `application.register("janela--dashboard", ...)` to `application.register("janela--frame", ...)`, and the import path from `@retail-tasker/janela/dashboard_controller` to `@retail-tasker/janela/frame_controller` on npm, or `janela/dashboard_controller` to `janela/frame_controller` on importmap.
  - Any `data-action="janela--dashboard#clear"` (or `#toggle`), `data-janela--dashboard-*-param` and `data-janela--dashboard-target` in the host's own markup becomes `janela--frame`.
  - The helper `janela_dashboard do ... end` is now `janela_frame do ... end`. `janela_pane` and `janela_snapshot_pane` are unchanged.
  - The helper module `Janela::DashboardHelper` is now `Janela::FramesHelper`, which only matters to a host that includes or overrides it.
  - `Janela::Pane` is now `Janela::Query`, and its `frame_id` is `turbo_frame_id`. `Pane` is reserved for a future record. Frame unqualified now means the dashboard; the DOM element is always spelled turbo frame.
  - `Janela::PanesController` is now `Janela::QueriesController` and `Janela::SnapshotPanesController` is now `Janela::SnapshotQueriesController`, with their views at `app/views/janela/queries/`. A host that overrides the view moves its copy.
  - `test/query_test.rb` is now `definition_query_test.rb`, since `query_test` read as a test of `Janela::Query` rather than of `Definition#query`.
  - Unchanged on purpose: the pane URLs, the route helpers `pane_path` and `snapshot_pane_path`, the turbo frame ids, and the CSS hooks `janela-pane`, `janela-chart`, `janela-value` and `janela-empty`.
- The README's advice on styling a directly opened pane was wrong: it suggested pointing Janela at the host's application layout, which is the thing that raises `NameError` inside an isolated engine. It now shows a small asset-only layout instead, the pattern a real host arrived at.

## [0.2.1] - 2026-09-15

Fixes found by dogfooding 0.2.0 in a second application. 0.2.0 is unusable in any host whose layout contains a route helper, which is most of them.

### Fixed

- Panes rendered in the host's application layout, so any route helper in it raised `NameError` inside the isolated engine and every pane 500'd. A pane in a Turbo Frame now carries no layout; opened directly it uses Janela's own minimal layout (ADR 011, #19).
- `average:` or `sum:` over a boolean column returned `true` instead of a ratio, because ActiveRecord casts an aggregate back through the column's type. Declaring one now raises and points at `dimension` instead (#20).
- A group whose dimension is null rendered as a blank label and filtered on an empty string. It is now labelled `(none)` and toggles Ransack's null predicate (#21).
- The README claimed time buckets follow `Time.zone`; on SQLite they are UTC, which silently shifts daily buckets by the host's offset (#22).

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

[0.2.1]: https://github.com/retail-tasker/janela/releases/tag/v0.2.1
[0.2.0]: https://github.com/retail-tasker/janela/releases/tag/v0.2.0
[0.1.0]: https://github.com/retail-tasker/janela/releases/tag/v0.1.0
