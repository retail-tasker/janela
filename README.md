# Janela

PowerBI-style dashboards and cross-filtering slicers, native to Rails and ActiveRecord. Define a dashboard on your models and associations, get a live, sliceable view for internal use -- or publish the same definition as a locked, static view for an external audience.

## First principle

Janela is a PowerBI-style library built on Ruby and Stimulus, meant to drop onto any Ruby on Rails application. No JS framework, no build step, no separate frontend app -- just a gem you add to an existing Rails app's Gemfile and a set of Stimulus controllers that ship with it.

## Why

Every Rails BI option today is one of:

- **SQL-first** (Blazer) -- powerful, but the query is a black box to your models and associations.
- **Admin-panel-first** (RailsAdmin, ActiveAdmin, Motor Admin, Avo) -- association-aware filtering, but built for CRUD, not for composing multiple charts that filter each other.
- **A dead end for cross-filtering** -- none of the above let clicking one chart re-scope every other chart on the page. That's the actual PowerBI/Tableau slicer experience, and nothing in the Rails ecosystem does it as a first-class citizen.

Janela's bet: the same dashboard definition should serve two audiences without being two systems --

- **Dynamic mode** -- internal analysts get live slicers, cross-filtering, free exploration.
- **Static mode** -- the same dashboard, published, is frozen and locked for client-facing consumption. No slicers, no surprises, opinionated.

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

Declaring a dimension makes that attribute filterable, so Janela defines the model's Ransack allowlist for you. A `through:` dimension also needs the **associated** model to allow the attribute, because Ransack's allowlist is per-class:

```ruby
class Customer < ApplicationRecord
  def self.ransackable_attributes(_auth_object = nil) = %w[region]
  def self.ransackable_associations(_auth_object = nil) = []
end
```

### Dashboards

Mount the engine, then compose visuals on any page. Each visual is a Turbo Frame; clicking a value in one re-scopes the others:

```erb
<%= janela_dashboard do %>
  <button type="button" data-action="janela--dashboard#clear">Clear filters</button>

  <%= janela_visual Order, :revenue, by: :status %>
  <%= janela_visual Order, :revenue, by: :region %>
  <%= janela_visual Order, :orders,  by: :region %>
<% end %>
```

```ruby
# config/routes.rb
mount Janela::Engine => "/janela"
```

Register the Stimulus controller once:

```js
// app/javascript/application.js
import JanelaDashboardController from "janela/dashboard_controller"
application.register("janela--dashboard", JanelaDashboardController)
```

A visual ignores filters on its own dimension, so clicking a value re-scopes the rest of the dashboard rather than collapsing the visual you clicked. Only models that declare a `janela` block can be requested over HTTP. Janela's controllers inherit from your `ApplicationController`, so your authentication applies, and scoping uses `policy_scope` automatically if you have Pundit.

## Design

Janela ships the load-bearing core of a BI tool and nothing else. The reasoning is recorded in [`docs/decisions/`](docs/decisions/INDEX.md) -- start with ADR 001.

- **Measures and dimensions are a Ruby DSL on the model**, config-as-code like `routes.rb`. No drag-and-drop designer.
- **Querying rides on [Ransack](https://github.com/activerecord-hackery/ransack)'s association-path traversal.** Janela does not invent a query language.
- **Cross-filtering is a Stimulus controller plus Turbo Frames.** Click a value in one visual, shared filter state updates, every other frame on the page re-renders. Drill-down is the same mechanism narrowing dimension granularity.
- **Publishing creates a Snapshot.** An ActiveJob freezes the result set into a new record; the live dashboard stays editable and the published view is a point-in-time fork, not a toggle on the same record.
- **Charts wrap an existing open library**, rendered from server-supplied JSON. Not a charting engine.

Deliberately out of scope: report designer UI, natural-language query, a separate data warehouse, a row-level-security subsystem (use your app's Pundit/CanCanCan), refresh-scheduling UI (schedule the Snapshot job with whatever you already use), embedding SDK, mobile app, print/paginated reports. If you need one of those, the codebase is meant to be small enough to fork and add your own.

## Status

Pre-alpha, not yet released. The measures/dimensions DSL and cross-filtering both work; charts, time-granularity dimensions and published snapshots do not exist yet.

## Installation

Not yet released. Once it's on RubyGems:

```bash
bundle add janela
```

## Development

Janela is a Rails engine. It ships with a minimal host application in `test/dummy` that mounts the engine at `/janela`, so the gem is always developed and tested against a real Rails app with a real (SQLite) database.

After checking out the repo, run `bin/setup` to install dependencies. Then:

```bash
bin/rails test        # run the test suite
bundle exec rake      # tests + RuboCop, what CI runs
bin/rails console     # console inside the dummy app, engine loaded
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/retail-tasker/janela. Pull requests are reviewed on the merits of the diff, whether a person or an agent wrote them. Contributors are expected to adhere to the [code of conduct](https://github.com/retail-tasker/janela/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
