# Upgrading Janela

What to do, in order, when a release needs you to act. For what
changed and why, see [CHANGELOG.md](CHANGELOG.md); for why it was
decided, see [docs/decisions](docs/decisions/INDEX.md).

After any upgrade, run:

```bash
bin/rails janela:doctor
```

It reads your application and lists what still needs changing.

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
yarn add github:retail-tasker/janela#v0.3.0   # or bump your version range
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
