# Upgrading Janela

What to do, in order, when a release needs you to act. For what
changed and why, see [CHANGELOG.md](CHANGELOG.md); for why it was
decided, see [docs/decisions](docs/decisions/INDEX.md).

After any upgrade, run:

```bash
bin/rails janela:doctor
```

It reads your application and lists what still needs changing.

## 0.6.0 to 0.7.0

Janela has stopped guessing what may be read, in the two places it used
to default to every row: a pane in a request (ADR 032) and a scheduled
snapshot (ADR 034). Three steps, and most applications have already
taken the first.

**1. Say what may be read, if you have not.**

If your `ApplicationController` defines `policy_scope`, nothing changes.
If you use Pundit, nothing changes. If neither is true, every dashboard,
pane and inline frame now raises `Janela::Unscoped` where it previously
totalled every row:

```ruby
 class ApplicationController < ActionController::Base
+  private
+    def policy_scope(model) = model.all
 end
```

That line is an assertion, not a formality: it says every visitor who can
reach a dashboard may read every row of every model on it. "One tenant"
and "nothing here is worth hiding from staff" are different claims, and
only the second one licenses `model.all`. If it is not true of your
application, return something narrower.
`docs/multi-tenancy.md` has the wiring for acts_as_tenant, CanCanCan and
the rest.

Find it before a visitor does:

```bash
bin/rails janela:doctor
```

`unscoped-reads` reports the absence as an error and prints the line to
add.

**2. Take the snapshot owner migration, if you use snapshots.**

`janela_snapshots` gains a nullable polymorphic owner so your policy can
filter a snapshot the way it already filters a frame:

```bash
bin/rails janela:install:migrations
bin/rails db:migrate
```

Existing snapshots keep a nil owner and keep working. Pass `owner:` when
you take new ones, and add `Janela::Snapshot` to whatever your policy
already does for `Janela::Frame`:

```ruby
- Janela::Snapshot.take(name: "September") { |take| ... }
+ Janela::Snapshot.take(name: "September", owner: Current.account) { |take| ... }
```

The owner says who a snapshot belongs to. What the numbers inside it
cover is the next step.

**3. Tell `Janela::SnapshotJob` what rows to freeze, if you schedule
snapshots.**

The job used to take every pane over the model's default scope, which is
your tenant's rows if your tenancy is enforced on your models and every
row if it lives in your policies. Janela cannot tell which application it
is in, so it has stopped choosing (ADR 034). It now raises
`Janela::Unscoped` unless you answer.

If your tenancy is on your models, or you have one tenant, say so:

```ruby
- Janela::SnapshotJob.perform_later(name: "September", panes: [...])
+ Janela::SnapshotJob.perform_later(name: "September", scope: :model_default, panes: [...])
```

If your scoping lives in your policies, `model.all` is every row and no
symbol can carry the relation you want. Answer in Ruby instead, and
schedule your own job:

```ruby
class TenantSnapshotJob < Janela::SnapshotJob
  private def scope_for(model) = model.where(account: owner)
end
```

Override `scope_for` and the `scope:` argument is not consulted, because
the method that reads it is the one you replaced. `name`, `owner` and
`filters` are readable beside it, so there is no need to override
`perform`. This replaces the old advice to write a job around
`Snapshot.take` from scratch, which still works and is now one method
longer than it needs to be.

**Drain the queue, or expect the retries.** A `SnapshotJob` enqueued
before you deploy was serialised without `scope:` and will raise when it
performs. Nothing in the diff shows you this. Let the queue empty before
deploying, or re-enqueue what fails afterwards.

**What did not change.** `Order.janela.query(:revenue)` called from your
own Ruby still runs over `Order.all`, because you wrote that call and the
scope was yours to choose. Only what Janela decides on your behalf inside
a request has stopped guessing. Frames, pane rows and snapshots are read
through the same scope they always were.

## 0.5.0 to 0.6.0

How single table inheritance is handled changed (ADR 031). Nothing here
applies unless your application has STI subclasses under a model that
declares a `janela` block. If it does not, upgrade and read no further.

**1. A named subclass is now registered and addressable.**

Before, only a class with its own `janela` block answered at a URL. Now
every named subclass of one does, on its own route key:

```
  /insights/orders/revenue              as before
+ /insights/wholesale_orders/revenue    new in 0.6.0
```

The numbers are the subclass's own rows, because the query runs on the
subclass and ActiveRecord adds the type condition itself. There is
nothing to declare and nothing to register.

Scoping is unchanged: a subclass reads through `janela_scope` like every
other model, so an application authorising with `policy_scope` already
covers the new addresses. One that instead gates on the request path now
has paths it has not listed, and should list them.

**2. `Janela.definitions` returns one entry per subclass.**

A family of a dozen STI types is a dozen entries, where a form offering a
choice of model previously showed one. If you want only the classes that
declared a dashboard:

```ruby
- Janela.definitions
+ Janela.definitions.select { |definition| definition.model.base_class == definition.model }
```

**3. A subclass's Ransack allowlist now matches the dashboard it reports.**

This was wrong before rather than merely different. A subclass inherited
the allowlist Janela generated on its parent, because those are singleton
methods and singleton methods inherit, while `.janela` returned nil and
nothing was registered. So `WholesaleOrder.ransack(...)` in your own code
filtered on dimensions no definition behind that class had declared. The
allowlist is now the allowlist of the definition a class reports,
whichever class declared it.

Janela also no longer replaces an allowlist you wrote yourself on a
parent class when a subclass declares its own block.

**What did not change.** A model that declares its own `janela` block, an
application with no STI, every `janela_frame` and `janela_pane` call you
have already written, and every filter already in a URL. An anonymous
subclass is still not registered, having no route key to be addressed by.

## 0.4.1 to 0.5.0

A filter is now bound to what kind of dimension it names (ADR 025). Most
hosts do nothing: a click already writes `_eq` or `_in`, both still
allowed. Three things need you only if you have gone further than that.

**1. A predicate outside a dimension's allowlist now raises.**

A categorical dimension (`dimension :status`) allows `eq`, `in`, `null`
and `not_null`. A time dimension (`dimension :placed_on, granularity:
:day`) additionally allows `gteq`, `gt`, `lteq` and `lt`. Anything else,
most often `_cont`, `_matches`, `_start` or `_end`, now raises
`Janela::BadRequest` instead of quietly filtering:

```ruby
- Order.janela.query(:revenue, where: { status_cont: params[:q] })
+ Order.janela.query(:revenue, where: { status_eq: params[:q] })
```

If you need a real pattern search, pass a relation you have already
filtered through `on:`, where you write the condition yourself, under
your own authorisation, rather than accepting one from a URL:

```ruby
Order.janela.query(:revenue, on: Order.where("status LIKE ?", "%#{params[:q]}%"))
```

Run `bin/rails janela:doctor` after upgrading: it finds a disallowed
predicate hardcoded in your own source, the same way it finds a stale
identifier. It cannot find one built from a URL param at request time;
there is nothing in your source to read.

**2. A grouped query with no `limit` now gets one anyway.**

A breakdown over more than 1000 values used to return all of them and
now returns the top 1000, ordered by the measure (ADR 007). Pass
`limit:` yourself if you want a different cut:

```ruby
- Order.janela.query(:revenue, by: :customer)
+ Order.janela.query(:revenue, by: :customer, limit: 1000)  # unchanged
```

Nothing to do if your dashboard already has fewer than 1000 groups, or
already passes `limit:`.

**3. A single filter may not carry more than 1000 values.**

`status_in` (or any other array predicate) with more than 1000 values
now raises `Janela::BadRequest` instead of being answered. Nothing to
do unless you build a filter with more values than that yourself; a
click never does.

## 0.3.0 to 0.4.0

Selecting more than one value in a dimension (ADR 024). Most hosts do
nothing: the gesture, the predicate and the keys all arrive on their
own. Two things need you only if you have reached into Janela's own
markup.

**1. `selected_value` is now `selected_values`.**

Only if you overrode a pane view. It returns an array, because a
dimension can now hold more than one value, and the null group is in
it like any other label:

```erb
- <% if label.to_s == query.selected_value.to_s %>
+ <% if query.selected?(label) %>
```

**2. A click now writes `_in` rather than `_eq`.**

A shared link is `?q[status_in][]=paid` instead of `?q[status_eq]=paid`.
Links you sent before keep working, because Ransack reads both and
Janela still marks an `_eq` value as selected. You only need to act if
something of yours parses Janela's URLs or asserts on them, such as a
test:

```ruby
- assert_includes page.current_url, "q[status_eq]=paid"
+ assert_includes page.current_url, "q[status_in][]=paid"
```

**Nothing else changed.** Ctrl or Cmd click adds a value to a
selection, Escape clears the frame's filters, and both work from the
keyboard because a value is a real button and Enter carries the same
modifier. A chart highlights every selected bar.

## 0.2.1 to 0.3.0

Two things arrive together. Janela's own words settle on frames and
panes, which is a rename across your application: a frame is the
dashboard, a pane is one visual in it. And a dashboard can now be a
database record rather than only ERB, which is what the new tables and
the engine's own pages are for.

Step 1 is the one that breaks a page if you skip it. The renames after
it can be done in any order, and `janela:doctor` will tell you what you
have missed.

**1. Run the migrations.**

```bash
bin/rails janela:install:migrations
bin/rails db:migrate
```

Required if you mount the engine, even if you never intend to store a
dashboard. From this release the mount root serves an index of frames,
so without the tables `/dashboards` raises where it used to work.

**2. Rename the Stimulus controller you register.**

```js
// app/javascript/controllers/index.js, or wherever you register it
- import JanelaDashboardController from "@retail-tasker/janela/dashboard_controller"
- application.register("janela--dashboard", JanelaDashboardController)
+ import JanelaFrameController from "@retail-tasker/janela/frame_controller"
+ application.register("janela--frame", JanelaFrameController)
```

On importmap the path is `janela/frame_controller` rather than
`janela/dashboard_controller`. On npm, reinstall so the new export
path resolves:

```bash
yarn add github:retail-tasker/janela#v0.4.0   # or bump your version range
```

**3. Rename the helper that wraps your panes.**

```erb
- <%= janela_dashboard do %>
+ <%= janela_frame do %>
    <%= janela_pane Order, :revenue %>
  <% end %>
```

`janela_pane` and `janela_snapshot_pane` are unchanged.

**4. Rename any Janela data attributes in your own markup.**

Anything you wrote by hand, most likely a clear button:

```erb
- <button data-action="janela--dashboard#clear">Clear filters</button>
+ <button data-action="janela--frame#clear">Clear filters</button>
```

The same applies to `data-janela--dashboard-target` and
`data-janela--dashboard-*-param` if you built your own controls.

**5. Rename the constants, if you reference them.**

Most applications do not.

| Was | Now |
| --- | --- |
| `Janela::Pane` | `Janela::Query` |
| `Janela::Pane#frame_id` | `Janela::Query#turbo_frame_id` |
| `Janela::DashboardHelper` | `Janela::FramesHelper` |
| `Janela::PanesController` | `Janela::QueriesController` |
| `Janela::SnapshotPanesController` | `Janela::SnapshotQueriesController` |

`Janela::Pane` is reserved for a database record in a later release,
which is why the runtime object had to give the name up.

If you override Janela's view, move your copy from
`app/views/janela/panes/` to `app/views/janela/queries/`.

**6. Tell Janela what a new frame belongs to, if your policy asks.**

Only for a multi tenant host. If your Pundit scope filters
`Janela::Frame` by an owner, a frame created through Janela's own form
would be saved with no owner and hidden by that scope the instant it
was saved. Define the hook on the controller Janela inherits from:

```ruby
class ApplicationController < ActionController::Base
  def janela_frame_owner
    Current.account # whatever your scope filters frames by
  end
end
```

`janela:doctor` reports this one for you: it asks your policy for a
scope and looks for an owner in it. `docs/multi-tenancy.md`, shipped
in the gem, has the wiring for Pundit, acts_as_tenant and CanCanCan.

**7. Link the stylesheet, if you have not.**

```erb
<%= stylesheet_link_tag "janela" %>
```

Optional. It is the grid and enough style to read a pane, and Janela's
own pages load it themselves either way.

**Numbers read differently, and you need do nothing.** A measure now
renders to the precision it means rather than to whatever the database
returned, so a sum of a `decimal(10, 2)` column that read as `375.0`
reads as `375.00`. Declare `precision:`, `prefix:` or `suffix:` on the
measure to say otherwise. Nothing is rounded before it is stored or
compared.

**Nothing else changed.** Pane URLs, the route helpers `pane_path` and
`snapshot_pane_path`, turbo frame ids, and the CSS hooks
`janela-pane`, `janela-chart`, `janela-value` and `janela-empty` are
all as they were. Your measures, dimensions and snapshots are
untouched.
