# Janela

PowerBI-style dashboards and cross-filtering slicers, native to Rails and ActiveRecord. Define a dashboard on your models and associations, get a live, sliceable view for internal use, or publish the same definition as a locked, static view for an external audience.

## First principle

Janela is a PowerBI-style library built on Ruby and Stimulus, meant to drop onto any Ruby on Rails application. No JS framework, no build step of its own, no separate frontend app. Just a gem you add to an existing Rails app's Gemfile and two Stimulus controllers that ship with it.

## Why

Every Rails BI option today is one of:

- **SQL-first** (Blazer). Powerful, but the query is a black box to your models and associations.
- **Admin-panel-first** (RailsAdmin, ActiveAdmin, Motor Admin, Avo). Association-aware filtering, but built for CRUD, not for composing multiple charts that filter each other.
- **A dead end for cross-filtering**. None of the above let clicking one chart re-scope every other chart on the page. That's the actual PowerBI/Tableau slicer experience, and nothing in the Rails ecosystem does it as a first-class citizen.

Janela's bet: the same dashboard definition should serve two audiences without being two systems.

- **Dynamic mode**. Internal analysts get live slicers, cross-filtering, free exploration.
- **Static mode**. The same dashboard, published, is frozen and locked for client-facing consumption. No slicers, no surprises, opinionated.

## Installation

Janela is an alpha on [rubygems.org](https://rubygems.org/gems/janela). It has two halves, a gem and an npm package:

```ruby
# Gemfile
gem "janela", "~> 0.2"
```

```ruby
# config/routes.rb
mount Janela::Engine => "/dashboards"   # or /reports, or wherever you like
```

Then register the two Stimulus controllers. How depends on how your app ships JavaScript.

**With jsbundling (esbuild, bun, webpack):**

```bash
yarn add github:retail-tasker/janela   # or: npm install github:retail-tasker/janela
```

```js
// app/javascript/controllers/index.js
import JanelaFrameController from "@retail-tasker/janela/frame_controller"
import JanelaChartController from "@retail-tasker/janela/chart_controller"
application.register("janela--frame", JanelaFrameController)
application.register("janela--chart", JanelaChartController)
```

The chart controller imports `chart.js`, which is a peer dependency: add `chart.js` to your own `package.json` if it is not there already.

**With importmap-rails:**

Nothing to install. The engine pins `janela/frame_controller`, `janela/chart_controller` and a vendored `chart.js` for you (your own `chart.js` pin wins if you have one). Register the controllers:

```js
// app/javascript/application.js
import JanelaFrameController from "janela/frame_controller"
import JanelaChartController from "janela/chart_controller"
application.register("janela--frame", JanelaFrameController)
application.register("janela--chart", JanelaChartController)
```

Include the stylesheet in whichever layout renders dashboards. It is small, it is the grid, and it is meant to be overridden:

```erb
<%= stylesheet_link_tag "janela" %>
```

Requires Rails 8.0+ and Ruby 3.3+. If your app is on Rails 8.1.x with the `json` gem at 3.x, encrypted cookie reads raise inside ActiveSupport and every Turbo Frame request will 500 in the browser; pin `gem "json", "< 3"` until Rails ships the fix.

## Usage

Declare measures and dimensions on the model:

```ruby
class Order < ApplicationRecord
  belongs_to :customer

  janela do
    measure :revenue, sum: :amount
    measure :orders, count: true

    dimension :status
    dimension :region, through: :customer
    dimension :placed_on, granularity: :month
  end
end
```

A dimension with a `granularity` is a time dimension. Groupdate buckets it (`hour`, `day`, `week`, `month`, `quarter`, `year`), fills empty buckets with zero, and uses your app's `Time.zone` and week start. **On SQLite, buckets are UTC**, because SQLite cannot convert time zones: with a non-UTC `Time.zone` a daily bucket is shifted by your offset, and an early-morning row lands in the previous day. Coarser granularities blunt the shift without removing it. If you need local-day buckets on SQLite, store a local date column and use it as a plain dimension.

Then query them:

```ruby
Order.janela.query(:revenue)                  # => 375
Order.janela.query(:revenue, by: :status)     # => { "paid" => 300, "refunded" => 50, "pending" => 25 }
Order.janela.query(:revenue, by: :region)     # => { "APAC" => 150, "EU" => 225 }
Order.janela.query(:revenue, by: :placed_on)  # => { "Sep 2026" => 375 }
Order.janela.query(:revenue, by: :placed_on, granularity: :day)
                                              # => { "2026-09-01" => 100, "2026-09-02" => 50, ... }
```

Filters are [Ransack](https://github.com/activerecord-hackery/ransack) params, so a slicer built with `search_form_for` can pass `params[:q]` straight through:

```ruby
Order.janela.query(:revenue, by: :region, where: { status_in: %w[paid pending] })
```

Scope a query to whatever the current user is allowed to see with `on:`:

```ruby
Order.janela.query(:revenue, by: :status, on: policy_scope(Order))
```

Declaring a dimension makes that attribute filterable, so Janela defines the model's Ransack allowlist for you. A model that already defines its own keeps it. A `through:` dimension also needs the **associated** model to allow the attribute, because Ransack's allowlist is per-class:

```ruby
class Customer < ApplicationRecord
  def self.ransackable_attributes(_auth_object = nil) = %w[region]
  def self.ransackable_associations(_auth_object = nil) = []
end
```

### Dashboards

Compose panes on any page. Each pane is a Turbo Frame; clicking a value in one re-scopes the others. `janela_frame` wraps them: a frame is Janela's own word for the dashboard, so the gem's vocabulary never dictates what you call one (ADR 014).

```erb
<%= janela_frame do %>
  <button type="button" data-action="janela--frame#clear">Clear filters</button>

  <%= janela_pane Order, :revenue %>
  <%= janela_pane Order, :revenue, by: :status, as: :bar %>
  <%= janela_pane Order, :revenue, by: :region %>
  <%= janela_pane Order, :orders,  by: :region %>
<% end %>
```

A pane with no `by:` is the measure's single total, the KPI tile. `limit: 10` keeps the top ten rows or bars. `as:` is `:table` by default, `:bar` for a Chart.js bar chart, or `:line`, which suits a time dimension: `janela_pane Order, :revenue, by: :placed_on, as: :line, granularity: :week`. A chart fills its container's width at Chart.js's default aspect ratio, so wrap it in an element with the width you want. Clicking a bar does exactly what clicking a table value does.

### Frames

A dashboard does not have to be written in ERB. A frame is a record, so the person who decides which panes a dashboard has and how wide each one is does not need a deploy to change it (ADR 012):

```bash
bin/rails janela:install:migrations && bin/rails db:migrate
```

```ruby
frame = Janela::Frame.create!(name: "Orders", columns: 3, gap: 4)
frame.panes.create!(model: "orders", measure: "revenue")
frame.panes.create!(model: "orders", measure: "revenue", dimension: "placed_on",
                    renderer: "line", granularity: "month", span: 3)
frame.panes.create!(model: "orders", measure: "revenue", dimension: "status",
                    renderer: "bar", span: 2, title: "Money by status")
```

```erb
<%= janela_frame @frame %>
```

Same helper, two ways to supply the panes. A row names a model by its route key, and only a measure, dimension, renderer and granularity the model's `janela` block declares: a row that names anything else is rejected on save, so an analyst arranges what is shown and cannot invent a query or reach a model nobody exposed. `position` orders the panes and is set for you when you leave it out. `title` is optional and replaces the title Janela would write itself.

The layout is CSS Grid's own vocabulary as small integers: `columns` 1 to 12 and `gap` 0 to 8 on the frame, `span` 1 to 12 on a pane. Each one picks a class the shipped stylesheet already defines, `janela-cols-3`, `janela-gap-4`, `janela-span-2`, so nothing an analyst types reaches CSS. Set `--janela-space` once, anywhere, to move the whole spacing scale; the grid collapses to a single column on a narrow screen. ADR 016 has the reasoning.

A frame renders each pane inline on the first response, so the page is a correct dashboard before any JavaScript runs and there is no request per pane on load. Cross-filtering then works exactly as it does for hand written panes. Every pane of a frame goes through your Pundit scope if you have one, the same as every other Janela query.

The engine ships no pages of its own for frames yet, and no forms: composing a frame is ActiveRecord, and your page renders it.

### Filters and clicks

The dashboard's filters live in the page URL as the same `q[...]` parameters, so a reload keeps them and a filtered dashboard is a link you can send: `/reports/orders?q[status_eq]=paid` renders filtered before any JavaScript runs. A pane ignores filters on its own dimension, so clicking a value re-scopes the rest of the dashboard rather than collapsing the pane you clicked. Time panes re-scope with the others but are not click sources yet; drill-down is the next decision. The selected value is marked `aria-pressed="true"` on tables and drawn solid against faded siblings on charts, so it can be styled and read. A pane with no matching rows renders a `.janela-empty` paragraph. A group whose dimension is null is labelled `(none)` and filters with Ransack's null predicate rather than an empty string. Only models that declare a `janela` block can be requested over HTTP.

### Pane URLs

Every pane has its own URL under the mount, and a Turbo Frame in a dashboard loads exactly the same URL a person can open directly:

```
/dashboards/orders/revenue                      orders revenue
/dashboards/orders/revenue/status               orders revenue by status
/dashboards/orders/revenue/status?as=bar        ... as a bar chart
/dashboards/orders/revenue/region?q[status_eq]=paid
                                                orders revenue by region where status is paid
/dashboards/orders/revenue/placed_on?granularity=week&as=line
                                                orders revenue by placed_on, per week, as a line
```

The model is its route key (`orders`, `sales_orders`), then the measure, then optionally the dimension. Where an analyst would say *by*, the URL has a `/`; *where* is a `q` filter; *as a bar chart* is `?as=bar`; *top ten* is `?limit=10`; *as of* a snapshot is `/snapshots/:id/` in front. Category panes are always ordered by the measure, largest first; time panes are chronological. A pane opened on its own renders with its filters applied, so a filtered pane is a link you can send someone. ADR 005 has the grammar, ADR 011 the layout it renders in.

### Snapshots

A snapshot freezes the results of several panes at one instant, under one set of filters, so an audience sees exactly what was signed off while the live dashboard stays editable. Results are stored, not HTML; a stored pane can still be drawn as a table or a chart. It needs the same migrations frames do.

```ruby
Janela::Snapshot.take(name: "September 2026", filters: { status_eq: "paid" }) do |take|
  take.pane Order, :revenue,                                on: policy_scope(Order)
  take.pane Order, :revenue, by: :status,                   on: policy_scope(Order)
  take.pane Order, :revenue, by: :placed_on, granularity: :week
end
```

Render a stored pane the same way you render a live one:

```erb
<%= janela_snapshot_pane @snapshot, Order, :revenue, by: :status, as: :bar %>
```

Inside a dashboard a pane is a Turbo Frame and carries no layout at all. Opened directly it renders in Janela's own minimal layout, which deliberately loads no assets, because the gem cannot know your asset names or whether you bundle. A direct pane link therefore shows its numbers unstyled, and a chart pane shows nothing, since the chart needs Stimulus.

To make direct pane links styled and chart-capable, give Janela a small layout of your own that loads your assets and nothing else:

```erb
<%# app/views/layouts/janela.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "Insights" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag :app %>
    <%= javascript_importmap_tags %>
  </head>
  <body><%= yield %></body>
</html>
```

```ruby
# config/initializers/janela.rb
Rails.application.config.to_prepare { Janela::ApplicationController.layout "janela" }
```

Do not point Janela at your **application** layout. Janela is an isolated engine, so a bare route helper anywhere in that layout, a nav link for instance, resolves against Janela's routes and raises `NameError`. Keep the layout above small and asset-only.

Stored panes are static by nature: no filter buttons, charts ignore clicks, and the URL says *as of*: `/dashboards/snapshots/42/orders/revenue/status`. Request filters are ignored because the snapshot's were fixed when it was taken.

`Janela::SnapshotJob.perform_later(name:, panes: [{ "model" => "orders", "measure" => "revenue", "by" => "status" }])` takes one from serialisable arguments so you can schedule it with whatever runs your jobs. The job uses each model's default scope; if you scope by tenant, write your own job around `Snapshot.take` and pass `on:`.

Who may see a snapshot is your decision. Stored panes go through the same controllers as live ones, so your authentication applies; an external audience gets a page you build over `janela_snapshot_pane` behind whatever share tokens you already trust. ADR 009 has the reasoning.

### Securing dashboards

Janela's controllers inherit from your `ApplicationController`, so they are exactly as public as it is. If your app authenticates per controller rather than globally, add this once:

```ruby
# config/initializers/janela.rb
Rails.application.config.to_prepare do
  Janela::ApplicationController.prepend_before_action do
    redirect_to main_app.new_session_path unless user_signed_in?
  end
end
```

Two details matter. It is *prepended* so it runs before any filter on your `ApplicationController` that assumes a signed-in user (tenant lookups, audit logging). It redirects through `main_app` because Janela is an isolated engine, so a bare `new_session_path` inside it resolves against Janela's own routes and fails.

Scoping is automatic when you use Pundit: `Janela::ApplicationController` calls `policy_scope(model)` if your `ApplicationController` defines it, and falls back to `model.all` otherwise. Every model you put on a dashboard needs a policy with a `Scope`.

### Checking an installation

```bash
bin/rails janela:doctor
```

Reads your application and lists what still needs doing: identifiers left over
from an earlier version, Stimulus controllers you have not registered, a
`through:` dimension whose associated model does not allowlist the attribute,
and whether the engine is mounted. It exits non-zero when it finds an error, so
it works in CI. It only reads and reports.

Run it after installing and after any upgrade. Steps for a specific version
upgrade are in [UPGRADING.md](UPGRADING.md).

## Design

Janela ships the load-bearing core of a BI tool and nothing else. The reasoning is recorded in [`docs/decisions/`](docs/decisions/INDEX.md), starting with ADR 001.

- **Measures and dimensions are a Ruby DSL on the model**, config-as-code like `routes.rb`. Developers define what can be asked.
- **Composition is data.** A frame and its panes are records, so analysts arrange what is shown without a deploy (ADR 012). A visual, drag-and-drop editor is not built and is a decision of its own.
- **Querying rides on [Ransack](https://github.com/activerecord-hackery/ransack)'s association-path traversal.** Janela does not invent a query language.
- **Cross-filtering is a Stimulus controller plus Turbo Frames.** Click a value in one pane, shared filter state updates, every other frame on the page re-renders.
- **Charts are [Chart.js](https://www.chartjs.org)**, driven by one small Stimulus controller from the same values the tables show. Not a charting engine.
- **Publishing creates a Snapshot.** An ActiveJob freezes the result set into a new record; the live dashboard stays editable and the published view is a point-in-time fork, not a toggle on the same record. Not built yet.

Deliberately out of scope: natural-language query, a separate data warehouse, a row-level-security subsystem (use your app's Pundit/CanCanCan), refresh-scheduling UI (schedule the Snapshot job with whatever you already use), embedding SDK, mobile app, print/paginated reports. If you need one of those, the codebase is meant to be small enough to fork and add your own.

## Status

**v0.2.1 alpha.** The measures/dimensions DSL, time dimensions, cross-filtering, bar and line charts, pane URLs, shareable dashboard URLs, snapshots and database-backed frames work and are covered by unit and real-browser tests. Not yet built: the engine's own pages for frames, forms for editing one, drill-down on time panes, other chart types. Open work is in [GitHub Issues](https://github.com/retail-tasker/janela/issues).

## Development

Janela is a Rails engine. It ships with a minimal host application in `test/dummy` that mounts the engine at `/janela`, so the gem is always developed and tested against a real Rails app with a real (SQLite) database.

After checking out the repo, run `bin/setup` to install dependencies. Then:

```bash
bin/rails test        # unit tests
bundle exec rake      # unit tests + RuboCop, what CI runs
bundle exec rake system   # cross-filtering and charts in headless Chrome
bin/rails console     # console inside the dummy app, engine loaded
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/retail-tasker/janela. Pull requests are reviewed on the merits of the diff, whether a person or an agent wrote them. Contributors are expected to adhere to the [code of conduct](https://github.com/retail-tasker/janela/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
