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

A rename with no behaviour change. Janela's own words are frames and
panes: a frame is the dashboard, a pane is one visual in it. Work
through these in any order; `janela:doctor` will tell you what you
have missed.

**1. Rename the Stimulus controller you register.**

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

**2. Rename the helper that wraps your panes.**

```erb
- <%= janela_dashboard do %>
+ <%= janela_frame do %>
    <%= janela_pane Order, :revenue %>
  <% end %>
```

`janela_pane` and `janela_snapshot_pane` are unchanged.

**3. Rename any Janela data attributes in your own markup.**

Anything you wrote by hand, most likely a clear button:

```erb
- <button data-action="janela--dashboard#clear">Clear filters</button>
+ <button data-action="janela--frame#clear">Clear filters</button>
```

The same applies to `data-janela--dashboard-target` and
`data-janela--dashboard-*-param` if you built your own controls.

**4. Rename the constants, if you reference them.**

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

**5. Nothing else changed.**

Pane URLs, the route helpers `pane_path` and `snapshot_pane_path`,
turbo frame ids, and the CSS hooks `janela-pane`, `janela-chart`,
`janela-value` and `janela-empty` are all as they were. Your measures,
dimensions and snapshots are untouched.
