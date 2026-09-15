---
Date: 2026-09-15
Status: Accepted
Related: ADR 001, ADR 002, ADR 003, ADR 004
Triggers:
  - changing the URL of a pane or how a dashboard frame addresses one
  - mounting the engine anywhere other than the default, or with as:
  - renaming a model that has a janela block
  - adding a renderer, a parameter or a response format to panes
  - adding a second dimension, a sort or a limit to a pane
  - anything that turns a pane into a shareable link
Topics: routes, urls, mount, panes, naming, public-api
---

# ADR 005: Pane URLs and the Mount Path

## Context

A dashboard is a window onto a model, and each visual in it is one
pane of that window. Until now a pane was addressed as
`/janela/visual?model=Order&measure=revenue&by=status&as=bar`: the
engine's own name in the path, and every identifying fact spelled out
as a query parameter in whatever order the helper happened to emit
them. That URL was an implementation detail that leaked, not a design.

Two things were wrong with it. The path segment `janela` is the
project's name, not a word a host application would choose for its
own reports, and the documentation and dummy application made it look
mandatory. And a pane had no address a person would want to bookmark,
share, or open on its own, even though the controller already rendered
one perfectly well when hit directly.

A related bug: the `janela_visual` helper built its frame `src` through
the `janela` route proxy, so mounting the engine with a different `as:`
broke every dashboard (#13).

## Decision

**The mount path is the host's, chosen in `config/routes.rb`.**

```ruby
mount Janela::Engine => "/dashboards"
```

This is the one obvious way Rails engines are placed, it is what
Blazer does, and a separate `Janela.configure` setting for the same
fact would duplicate it. Documentation and the dummy application use
`/dashboards`, and say plainly that the path is whatever the host
wants. The helper finds the engine's mount by looking it up in the
host's route table rather than assuming a proxy name, so `as:` works
and #13 is closed.

**A pane's URL is the sentence an analyst would say, with the small
words replaced by URL syntax.**

```
/dashboards/orders/revenue                      orders revenue
/dashboards/orders/revenue/status               orders revenue by status
/dashboards/orders/revenue/status?as=bar        ... as a bar chart
/dashboards/orders/revenue/region?q[status_eq]=paid
                                                orders revenue by region where status is paid
```

Path: the model's route key, the measure, and optionally the
dimension. Query: `as` for the renderer (default `table`), `q` for
Ransack filters exactly as ADR 002 defined them. One route serves both
uses: a Turbo Frame in a dashboard loads it, and a person opens it
directly and gets that pane alone inside the host's layout.

The naming convention, recorded so future URL decisions start from it:

| An analyst says     | The URL says            |
|---------------------|-------------------------|
| *by*                | `/`                     |
| *where*, *for*, *only* | `?q[...]`            |
| *as a bar chart*    | `?as=bar`               |
| nothing after the measure | no dimension segment: the total |

There is no literal `by` segment. It carried nothing the router
needed, since segment count and the model's declared dimensions
already disambiguate, and it kept `/orders/revenue` from being a
complete sentence. Rails paths are nouns without prepositions;
`/posts/1/comments`, not `/posts/1/with/comments`.

**A pane with no dimension is a single value.** `/orders/revenue` is
the measure's total under the current filters, rendered as one number.
It is the KPI tile every dashboard has, and it falls out of the
grammar rather than being a separate feature. It is a pane like any
other: it lives in a Turbo Frame, it re-scopes when other panes are
clicked, and it has nothing of its own to click.

The renderer is a query parameter rather than a format extension
(`status.bar`) because Rails treats an extension as a MIME format and
`bar` is not one; it would also spend the extension that a future
`.json` response of the same pane's data should have.

The model appears as its `model_name.route_key` (`orders`,
`sales_orders`), the same identifier the host's own resource routes
use. The registry from ADR 003 keys on route key instead of class
name and remains the allowlist: a request for a key no model declared
is refused before anything is constantized.

**The concept is a pane, and the code says so.** `Janela::Visual`
becomes `Janela::Pane`, `VisualsController` becomes `PanesController`,
`janela_visual` becomes `janela_pane`, and the CSS hooks become
`janela-pane`, `janela-chart`, `janela-value` and `janela-empty`.
"Visual" was a placeholder borrowed from BI vendors; "pane" is the
word that fits a project named for a window, and it is the word its
author reached for unprompted.

## Consequences

- This breaks the 0.1.0 API: helper name, class names, frame ids, CSS
  classes and the route. Acceptable now, while the only installation
  is the author's own, and impossible to do cheaply later. Ships as
  0.2.0 with the CHANGELOG saying exactly what to rename.
- A model's route key becomes part of a public URL. Renaming the model
  changes the URL, which is how every other Rails resource already
  behaves.
- A pane opened directly has no dashboard controller around it, so
  clicking a value does nothing there. That is correct: the click
  would only ever filter other panes, and there are none. Filters in
  the query string still apply, so a filtered pane is a shareable
  link. This delivers #1 for a single pane; a whole dashboard's
  filter state in the URL remains open.
- The grammar has one open slot: a second path segment after the
  dimension. Whether that means a second dimension (a matrix), a sort,
  or is refused is a decision for the ADR that adds it, and it should
  start from the naming table above: an analyst would say "by status
  *and* region", which suggests another `/`.
- A time dimension with a granularity (#3) is still "by placed_on";
  the granularity is a modifier, so it is a query parameter, not a new
  word in the path.
- Looking up the mount in the host's route table means the helper
  finds the first mount of the engine. Mounting Janela twice is
  unsupported and not a goal.
