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

Janela is pre-release and installed from GitHub. It has two halves, a gem and an npm package, installed the same way:

```ruby
# Gemfile
gem "janela", github: "retail-tasker/janela"
```

```ruby
# config/routes.rb
mount Janela::Engine => "/janela"
```

Then register the two Stimulus controllers. How depends on how your app ships JavaScript.

**With jsbundling (esbuild, bun, webpack):**

```bash
yarn add github:retail-tasker/janela   # or: npm install github:retail-tasker/janela
```

```js
// app/javascript/controllers/index.js
import JanelaDashboardController from "@retail-tasker/janela/dashboard_controller"
import JanelaChartController from "@retail-tasker/janela/chart_controller"
application.register("janela--dashboard", JanelaDashboardController)
application.register("janela--chart", JanelaChartController)
```

The chart controller imports `chart.js`, which is a peer dependency: add `chart.js` to your own `package.json` if it is not there already.

**With importmap-rails:**

Nothing to install. The engine pins `janela/dashboard_controller`, `janela/chart_controller` and a vendored `chart.js` for you (your own `chart.js` pin wins if you have one). Register the controllers:

```js
// app/javascript/application.js
import JanelaDashboardController from "janela/dashboard_controller"
import JanelaChartController from "janela/chart_controller"
application.register("janela--dashboard", JanelaDashboardController)
application.register("janela--chart", JanelaChartController)
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
  end
end
```

Then query them:

```ruby
Order.janela.query(:revenue)                  # => 375
Order.janela.query(:revenue, by: :status)     # => { "paid" => 300, "refunded" => 50, "pending" => 25 }
Order.janela.query(:revenue, by: :region)     # => { "APAC" => 150, "EU" => 225 }
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

Compose visuals on any page. Each visual is a Turbo Frame; clicking a value in one re-scopes the others:

```erb
<%= janela_dashboard do %>
  <button type="button" data-action="janela--dashboard#clear">Clear filters</button>

  <%= janela_visual Order, :revenue, by: :status, as: :bar %>
  <%= janela_visual Order, :revenue, by: :region %>
  <%= janela_visual Order, :orders,  by: :region %>
<% end %>
```

`as:` is `:table` by default or `:bar` for a Chart.js bar chart. A chart fills its container's width at Chart.js's default aspect ratio, so wrap it in an element with the width you want. Clicking a bar does exactly what clicking a table value does.

A visual ignores filters on its own dimension, so clicking a value re-scopes the rest of the dashboard rather than collapsing the visual you clicked. The selected value is marked `aria-pressed="true"` on tables and drawn solid against faded siblings on charts, so it can be styled and read. A visual with no matching rows renders a `.janela-empty` paragraph. Only models that declare a `janela` block can be requested over HTTP.

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

## Design

Janela ships the load-bearing core of a BI tool and nothing else. The reasoning is recorded in [`docs/decisions/`](docs/decisions/INDEX.md), starting with ADR 001.

- **Measures and dimensions are a Ruby DSL on the model**, config-as-code like `routes.rb`. No drag-and-drop designer.
- **Querying rides on [Ransack](https://github.com/activerecord-hackery/ransack)'s association-path traversal.** Janela does not invent a query language.
- **Cross-filtering is a Stimulus controller plus Turbo Frames.** Click a value in one visual, shared filter state updates, every other frame on the page re-renders.
- **Charts are [Chart.js](https://www.chartjs.org)**, driven by one small Stimulus controller from the same values the tables show. Not a charting engine.
- **Publishing creates a Snapshot.** An ActiveJob freezes the result set into a new record; the live dashboard stays editable and the published view is a point-in-time fork, not a toggle on the same record. Not built yet.

Deliberately out of scope: report designer UI, natural-language query, a separate data warehouse, a row-level-security subsystem (use your app's Pundit/CanCanCan), refresh-scheduling UI (schedule the Snapshot job with whatever you already use), embedding SDK, mobile app, print/paginated reports. If you need one of those, the codebase is meant to be small enough to fork and add your own.

## Status

**v0.1.0 alpha.** The measures/dimensions DSL, cross-filtering, and bar charts work and are covered by unit and real-browser tests. Not yet built: time-granularity dimensions, other chart types, filter state in the page URL, published snapshots. Open work is in [GitHub Issues](https://github.com/retail-tasker/janela/issues).

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
