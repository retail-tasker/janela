# Janela

PowerBI-style dashboards and cross-filtering slicers, native to Rails and ActiveRecord. Define a dashboard on your models and associations, get a live, sliceable view for internal use, or publish the same definition as a locked, static view for an external audience.

**[See it running](https://demo.janela.winontheshelf.com)**, with a year of demo orders. Click any value and the rest of the dashboard re-scopes. The demo is this repository's own test fixture with seed data, so what you click is what ships.

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
gem "janela", "~> 0.8"
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

### Vitral, the optional theme

A *vitral* is a stained glass window, which is what it makes of a dashboard: each pane holds its own colour, dark leading runs between them, and the light comes from behind. It is a second stylesheet, not a replacement, and it is entirely optional. `janela.css` is structure and `vitral.css` is taste, because taste is the first thing you will want to change (ADR 023):

```erb
<%= stylesheet_link_tag "janela" %>
<%= stylesheet_link_tag "vitral" %>
```

```erb
<body class="vitral">
```

The class is what carries the light, so nothing is repainted until you ask. Three public classes let your own page join in: `vitral-pane` puts a sheet of the same glass on any element, `vitral-panes` on a container cycles its children through the five colours, and `vitral-button` is a control made of it. Everything else is a custom property, so `--vitral-came`, `--vitral-glass` and the five `--vitral-pane-*` hues retheme the lot from your own stylesheet without touching the gem's.

For Janela's own pages, name the theme once and the engine's layout wears it:

```ruby
# config/initializers/janela.rb
Janela.theme = "vitral"
```

The leadlight can also answer the pointer, with every node leaning toward the cursor. That part is a Stimulus controller and therefore optional twice over, since Janela's own pages load no JavaScript at all (ADR 011):

```js
import VitralController from "@retail-tasker/janela/vitral_controller"  // or "janela/vitral_controller" on importmap
application.register("vitral", VitralController)
```

```erb
<body class="vitral" data-controller="vitral">
```

Anyone who has asked for reduced motion, reduced transparency or more contrast gets a still, solid window instead. A browser with no `backdrop-filter` gets plain panels.

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

### A subclass inherits

Declaring is what a family of classes does once. A subclass of a model with a `janela` block has the same measures and dimensions and its own pane URLs, with nothing to declare:

```ruby
class WholesaleOrder < Order
end
```

`/dashboards/wholesale_orders/revenue` totals the wholesale orders and `/dashboards/orders/revenue` totals all of them. Janela knows nothing about single table inheritance: the query runs on the subclass and ActiveRecord adds the type condition itself. A subclass is read through your scope like any other model, so if you authorise per class, the subclass needs an answer of its own.

A subclass that wants a different dashboard declares its own `janela` block, which replaces its parent's rather than adding to it. Either way, the Ransack allowlist Janela generates is the allowlist of the definition that class reports, so the two cannot disagree.

Every subclass is a definition, so a model with a dozen STI types offers a dozen of them wherever Janela lists what it can draw, such as the form for adding a pane (ADR 031).

### How numbers read

A measure says what its own number means, and every renderer asks it, so a table cell, a single value and a chart tooltip cannot disagree (ADR 020):

```ruby
measure :revenue, sum: :amount, prefix: "$"                      # $1,234.50
measure :pass_rate, average: :score, precision: 1, suffix: "%"   # 66.7%
measure :orders, count: true                                     # 1,234
```

Precision defaults to what the schema already says. Counting rows has no decimal places, a `decimal(10, 2)` column reads to the cent, and summing an integer column stays whole. Declare `precision:` where the schema has nothing to say, such as averaging an integer, or where you want something else. Thousands are delimited with your app's locale.

Formatting is rendering, never rounding. The number itself reaches a snapshot and an order clause at full precision, so a snapshot taken last month reads back under a format you declare today.

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

A filter is bound to what kind of dimension it names, not to every predicate Ransack knows (ADR 025). A categorical dimension takes `eq`, `in`, `null` and `not_null`; a time dimension additionally takes `gteq`, `gt`, `lteq` and `lt`, so a range still narrows it. Anything else, such as `_cont` or `_matches`, raises `Janela::BadRequest` naming what is allowed. A grouped query with no `limit` gets one anyway, capped at 1000, and a single filter may carry at most 1000 values.

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

**Reconfiguring a pane in place**, a renderer toggle, a granularity switcher, a "show top 20" control, takes two things: name the pane with `id:`, then ask the frame to repoint it.

```erb
<%= janela_pane Order, :revenue, by: :status, as: :bar, id: "revenue-by-status" %>
```

```js
const pane = document.getElementById("revenue-by-status")
pane.dispatchEvent(new CustomEvent("janela--frame:repoint", {
  bubbles: true, detail: { url: "/dashboards/orders/revenue/status?limit=20" }
}))
```

`id:` gives the frame a name you chose rather than a fingerprint of its own query, which would move every time that query changed and leave Turbo nothing to reconcile into. That is necessary and it is not enough on its own: a pane's `src` belongs to Turbo, which writes it back whenever a response lands, so writing `src` yourself has the request cancelled and the pane put back where it was, with no error and the old numbers still on screen. The event is how you say what you want instead. `janela_frame` listens for it, so anything inside a frame can dispatch it, from a Stimulus controller (`this.dispatch("repoint", { prefix: "janela--frame", target: pane, detail: { url } })`) or from plain JavaScript as above.

Say the query and nothing about filters: the frame reapplies whatever it is currently filtered to, so a repointed pane still agrees with the panes beside it, and any `q[...]` on the URL you pass is dropped in favour of them (ADR 029, ADR 030).

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

A frame may belong to an owner, `belongs_to :owner, polymorphic: true, optional: true`. Janela sets nothing there and reads nothing from it: it exists so a multi tenant host's Pundit `Scope` has a column to filter on. Set it to whatever your tenant is, and leave it null if you have one tenant.

**Words beside the numbers.** A pane can hold a heading, a paragraph and a link instead of a query, so an analyst can label the frame they own without a deploy (ADR 039):

```ruby
frame.panes.create!(kind: "text", heading: "Refunds are excluded",
                    body: "Figures are in the store's own currency.", link: "/orders", span: 3)
frame.panes.create!(kind: "partial", partial: "overview_heading", heading: "Project overview", span: 3)
```

What an analyst writes is escaped, never rendered as markup, and a `link` must be a path on your own site. Anything that needs markup, an icon, an image, a layout, is a partial you write under `app/views/janela_content/`; the analyst places it by name and it receives `heading`, `body` and `link` as locals. The directory is the allowlist: a row cannot name any other template. It sits outside `app/views/janela/` on purpose, since a view of yours at an engine's path would replace the engine's own. The engine's pages offer both kinds when adding a pane. A content pane takes no part in cross-filtering and is not in a snapshot, because it has no query.

**A frame narrowed to the record whose page it is on.** Pass `where:` and every pane of the frame is filtered by it before anything the reader selects:

```erb
<%= janela_frame @frame, where: { queue_id_eq: @queue.id } %>

<%= janela_frame where: { queue_id_eq: @queue.id } do %>
  <%= janela_pane Ticket, :count, by: :status %>
<% end %>
```

It travels in each pane's URL as `where[...]`, apart from the reader's `q[...]`, so Clear filters, Escape and a click on the same dimension cannot take it off, and the reader's selection can only narrow inside it. It is bounded like any filter: declared dimensions only, and the predicates ADR 025 allows. It is a view filter, not a permission: it is visible in the pane URL, and a reader who edits it out sees only what your `policy_scope` already allows them to. Keep a record out of reach in the scope, not here. Putting the same filter in the page URL's `q[...]` instead does not hold, because `q[...]` is the reader's to clear (ADR 040).

### Janela's own pages

The engine serves an index and a page per frame at the mount root, so you can install the gem and navigate the same day:

```
/dashboards                       every frame your scope returns
/dashboards/3                     one frame
/dashboards/orders/revenue/status an ad hoc pane, grammar unchanged
```

No model's route key is all digits, so a frame id and a pane URL cannot be confused. Both pages read through `policy_scope(Janela::Frame)`, so a frame your scope does not return is a 404 rather than a page, and so is a pane row under it.

These pages render in Janela's own minimal layout, which loads the gem's stylesheet and nothing else. It does not load Turbo or Stimulus, because those come from your bundler and the engine cannot name them. So Janela's own pages are correct, styled, **static** dashboards: every pane is rendered inline and the numbers are right, filters in the URL apply, and nothing cross-filters when you click. A chart pane needs Chart.js, so on these pages it draws nothing; put a frame on your own page, where your JavaScript is, for the interactive version.

The noun in the headings is `Janela::Frame.model_name.human`, so rename it in your own locale file rather than in a setting:

```yaml
en:
  activerecord:
    models:
      janela/frame:
        one: "Dashboard"
        other: "Dashboards"
```

A host that wants a different index writes its own page over `Janela::Frame` and never routes to ours.

### Editing a dashboard

The same pages are the analyst's editing surface, as conventional Rails CRUD:

```
/dashboards/new        name it and choose its grid
/dashboards/3/edit     rename it, rearrange it, add and remove panes
/dashboards/3/panes/new
```

Everything there works with nothing but HTML, because those pages load no JavaScript. Adding a pane is therefore two steps: the first picks a model, the second offers exactly the measures and dimensions that model's `janela` block declares, so a choice that would be rejected is never offered. Granularity appears when the dimension can take one. A pane moves with Up and Down buttons rather than a position field, because arranging the window is the point, and positions stay contiguous. There is no drag and drop and no canvas; a visual editor is its own decision, not built.

**Tell Janela what a new frame belongs to.** If your `ApplicationController` defines `janela_frame_owner`, the engine assigns its return value as the owner of a frame it creates. Without it, a host whose `policy_scope` filters frames by owner would hide the analyst's new dashboard the instant it was saved:

```ruby
class ApplicationController < ActionController::Base
  def janela_frame_owner
    Current.account
  end
end
```

A host with no tenancy defines nothing, gets a nil owner, and is correct: nothing is filtering on it. Every editing action reads through `policy_scope(Janela::Frame)` as well, so another tenant's frame is a 404 to change as much as to read. The [multi tenancy guide](docs/multi-tenancy.md) has the wiring for each of the common setups.

### Filters and clicks

The dashboard's filters live in the page URL as the same `q[...]` parameters, so a reload keeps them and a filtered dashboard is a link you can send: `/reports/orders?q[status_in][]=paid` renders filtered before any JavaScript runs. A pane ignores filters on its own dimension, so clicking a value re-scopes the rest of the dashboard rather than collapsing the pane you clicked. Time panes re-scope with the others but are not click sources yet; drill-down is the next decision. Every selected value is marked `aria-pressed="true"` on tables and drawn solid against faded siblings on charts, so it can be styled and read.

**Selecting more than one.** Ctrl or Cmd click adds a value to the selection and takes it out again, leaving the rest alone, which is how every list in every operating system already behaves. A plain click selects one value and replaces whatever was selected, or clears the dimension if that value was the only one. It works the same on a chart. All of it works from the keyboard too: a value is a real `<button>`, so Enter is a click and Ctrl or Cmd with Enter adds. `Escape` clears the frame's filters, and those are the only two keys Janela binds, both only while focus is inside the frame, because a single letter belongs to your application and to any text field on the page (ADR 024). A pane with no matching rows renders a `.janela-empty` paragraph. A group whose dimension is null is labelled `(none)` and filters with Ransack's null predicate rather than an empty string. Only models that declare a `janela` block can be requested over HTTP.

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

**Sending an existing pane to one of these URLs takes both halves of Reconfiguring a pane in place, above: name it with `id:`, and repoint it through the frame.** Without the `id:` the response wears an id the frame never had and Turbo has nothing to reconcile, so the pane keeps its old numbers with no error at all. Without the event, `src` is not yours to write and the request is cancelled, with the same silence (ADR 029, ADR 030).

### What Janela can draw

`Janela.renderers`, `Janela.granularities` and `Janela.offered_limits` answer what a pane can be drawn as, without reaching into `Janela::Query::RENDERERS`, `Janela::Dimension::GRANULARITIES` or `Janela::Pane::OFFERED_LIMITS`. `Janela.definitions` answers the other half: every model that declares a `janela` block, with its own measures and dimensions. A gallery of every renderer, live against your own data, is a page you build from those four calls and `janela_pane`, not one the engine serves (ADR 026, ADR 027):

```erb
<% Janela.definitions.each do |definition| %>
  <h2><%= definition.model.model_name.human %></h2>
  <%= janela_pane definition.model, definition.measures.keys.first %>
<% end %>
```

`test/dummy`'s `/gallery` is the reference: every renderer, per model, with the declaration that produced it beside it. A renderer a model cannot demonstrate, for want of a suitable dimension, shows as unavailable rather than disappearing, and a model with no `janela` block anywhere yet gets told so rather than an empty page.

### Snapshots

A snapshot freezes the results of several panes at one instant, under one set of filters, so an audience sees exactly what was signed off while the live dashboard stays editable. Results are stored, not HTML; a stored pane can still be drawn as a table or a chart. It needs the same migrations frames do.

```ruby
Janela::Snapshot.take(name: "September 2026", owner: Current.account, filters: { status_eq: "paid" }) do |take|
  take.pane Order, :revenue,                                on: policy_scope(Order)
  take.pane Order, :revenue, by: :status,                   on: policy_scope(Order)
  take.pane Order, :revenue, by: :placed_on, granularity: :week
end
```

`owner:` is optional and Janela reads nothing from it: it is there so your policy has the same column to filter a snapshot on that it has for a frame. It is an argument rather than a controller hook because a snapshot is never taken in a request, so there is nothing to ask (ADR 033).

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

`Janela::SnapshotJob` takes one from serialisable arguments so you can schedule it with whatever runs your jobs, carrying the owner across the queue through its GlobalID. It asks you one question and will not answer it for you: what rows does each pane freeze?

```ruby
Janela::SnapshotJob.perform_later(name: "September 2026", owner: Current.account, scope: :model_default,
                                  panes: [ { "model" => "orders", "measure" => "revenue", "by" => "status" } ])
```

`scope: :model_default` says each pane is taken over its model's default scope. That is already your tenant's rows if your tenancy is enforced on the models themselves, through acts_as_tenant, a `default_scope`, a connection or a schema. If your scoping lives in your policies instead, it is every row of every model, and no symbol can carry the relation you want, so answer in Ruby and schedule your own job:

```ruby
class TenantSnapshotJob < Janela::SnapshotJob
  private def scope_for(model) = model.where(account: owner)
end
```

`scope_for` is the whole extension point. Override it and the `scope:` argument is not consulted, because the method that reads it is the one you replaced; `name`, `owner` and `filters` are readable beside it, so you never have to override `perform`. Pass neither and the job raises `Janela::Unscoped` rather than freezing a scope nobody chose, which is the same refusal `policy_scope` gets in a request (ADR 034).

Who may see a snapshot is your decision. Stored panes go through the same controllers as live ones, so your authentication applies; an external audience gets a page you build over `janela_snapshot_pane` behind whatever share tokens you already trust. ADR 009 has the reasoning.

### Securing dashboards

Janela's controllers inherit from your `ApplicationController`, so they are exactly as public as it is. If your app authenticates per controller rather than globally, add this once:

```ruby
# config/initializers/janela.rb
Rails.application.config.to_prepare do
  Janela::ApplicationController.prepend_before_action do
    redirect_to new_session_path unless user_signed_in?
  end
end
```

It is *prepended* so it runs before any filter on your `ApplicationController` that assumes a signed-in user (tenant lookups, audit logging).

Your own route helpers work in there. Janela is an isolated engine, so a bare `new_session_path` would normally resolve against Janela's routes and raise, and this bites any host code that generates a URL while inside the engine: an authentication concern, a `rescue_from` that redirects, an `after_action`. Janela forwards the route helpers it does not define itself to your application, so they behave as they do everywhere else (ADR 022). Two things to know. A name Janela also uses means Janela's in here, and `main_app.frames_path` says yours. And `url_for(@record)` resolves polymorphically with no name to forward, so that one still needs `main_app.`.

Scoping is automatic when you use Pundit: `Janela::ApplicationController` calls `policy_scope(model)` if your `ApplicationController` defines it, and raises `Janela::Unscoped` if it does not, rather than reading everything on the strength of an omission (ADR 032). An application with nothing to hide answers `def policy_scope(model) = model.all` once and is done; `bin/rails janela:doctor` reports the absence as `unscoped-reads` before a visitor finds it. Every model you put on a dashboard needs a policy with a `Scope`, and so do `Janela::Frame` and `Janela::Snapshot`: frames, pane rows and stored panes are all read through the scope, never around it. The doctor checks that by making the call rather than by looking for the method, because Pundit defines `policy_scope` the moment it is included and raises only when the model has no policy, so the two are different questions (ADR 035). `test/dummy/app/controllers/application_controller.rb` is the smallest honest example of the wiring.

**Multi tenancy** has its own guide: [docs/multi-tenancy.md](docs/multi-tenancy.md). It covers what goes through your scope, worked wiring for Pundit, acts_as_tenant and CanCanCan, what owns a frame the analyst creates, and what rows a scheduled snapshot freezes.

### The pages Janela serves

Mounting the engine gives you an index of frames and a page per frame with no
work at all, which is enough to navigate on the day you install it:

```
/insights      every frame your policy scope returns
/insights/3    one frame
```

Both go through your `policy_scope`, so a frame another tenant owns is a 404. Each page carries a link back to your application's root, so they are not a dead end; rename it in your own locale file under `janela.actions.home`, or override the engine's layout if you want your whole navigation there.

These pages load Janela's own stylesheet and nothing of yours, because the gem
cannot know your asset names or bundler. Two consequences worth knowing. They
do not cross-filter, since that needs Stimulus. And a pane whose row asks for a
chart renders as its **table** here, because there is no chart runtime on the
page and a table needs nothing: the same frame rendered in your own page with
`janela_frame(@frame)` draws the chart. A renderer is a viewing choice, not part
of the pane (ADR 018).

### Checking an installation

```bash
bin/rails janela:doctor
```

Reads your application and lists what still needs doing: identifiers left over
from an earlier version, Stimulus controllers you have not registered, tables
you have not migrated, a `through:` dimension whose associated model does not
allowlist the attribute, a controller that defines no `policy_scope` at all, a
policy that scopes frames by an owner you never supply, snapshots stored with
no owner under a policy that filters on one, and whether the engine is mounted
and authenticated. It exits non-zero when it finds an error, so it works in
CI. It only reads and reports.

Every finding names the check that produced it:

```
WARNING (unauthenticated-endpoints): no authentication filter found on ApplicationController
```

One check cannot be certain: Janela reads your controller's filters to guess
whether the endpoints are authenticated, so if you authenticate another way it
is a false alarm every run. Silence one you have judged, by name:

```ruby
# config/initializers/janela.rb
Janela.silenced_checks = %w[unauthenticated-endpoints]
```

Silenced checks are named in the output every run, because a silence nobody
remembers is how a real finding goes unread (ADR 021).

Run it after installing and after any upgrade. Steps for a specific version
upgrade are in [UPGRADING.md](UPGRADING.md).

## Design

Janela ships the load-bearing core of a BI tool and nothing else. The reasoning is recorded in [`docs/decisions/`](docs/decisions/INDEX.md), starting with ADR 001.

- **Measures and dimensions are a Ruby DSL on the model**, config-as-code like `routes.rb`. Developers define what can be asked.
- **Composition is data.** A frame and its panes are records, so analysts arrange what is shown without a deploy (ADR 012). A visual, drag-and-drop editor is not built and is a decision of its own.
- **Querying rides on [Ransack](https://github.com/activerecord-hackery/ransack)'s association-path traversal.** Janela does not invent a query language.
- **Cross-filtering is a Stimulus controller plus Turbo Frames.** Click a value in one pane, shared filter state updates, every other frame on the page re-renders.
- **Charts are [Chart.js](https://www.chartjs.org)**, driven by one small Stimulus controller from the same values the tables show. Not a charting engine.
- **Publishing creates a Snapshot.** An ActiveJob freezes the result set into a new record; the live dashboard stays editable and the published view is a point-in-time fork, not a toggle on the same record. The job will not freeze a scope you have not named (ADR 034).

Deliberately out of scope: natural-language query, a separate data warehouse, a row-level-security subsystem (use your app's Pundit/CanCanCan), refresh-scheduling UI (schedule the Snapshot job with whatever you already use), embedding SDK, mobile app, print/paginated reports. If you need one of those, the codebase is meant to be small enough to fork and add your own.

## Status

**v0.8.0 alpha.** The measures/dimensions DSL, time dimensions, cross-filtering with multi-selection, bar and line charts, pane URLs, shareable dashboard URLs, snapshots, database-backed frames, STI subclasses, the engine's own pages for reading and editing them and the optional vitral theme work and are covered by unit and real-browser tests, with the classes a theme may target documented in [Theming Janela](docs/theming.md). Not yet built: a visual editor, drill-down on time panes, other chart types. [Vista](docs/roadmap.md), the roadmap, says what 1.0 means and which of these are in it; open work is in [GitHub Issues](https://github.com/retail-tasker/janela/issues).

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
