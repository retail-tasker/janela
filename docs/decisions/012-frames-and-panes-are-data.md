---
Date: 2026-09-15
Status: Accepted
Related: ADR 001, ADR 002, ADR 005, ADR 009
Supersedes: part of ADR 001
Triggers:
  - changing what a frame or a pane stores, or how either is rendered
  - adding an editing surface for dashboards
  - anything that would let a persisted row widen what can be queried
  - deciding whether a dashboard belongs in git
  - adding layout vocabulary, or a layer between a frame and its panes
  - naming anything "frame"
Topics: frames, panes, persistence, layout, css-grid, naming, authorisation, scope
---

# ADR 012: Frames and Panes Are Data

## Context

ADR 001 put a drag and drop report designer out of scope and made
dashboards code. A dashboard was an ERB page in the host application
calling `janela_pane` helpers, which kept it in git, reviewable and
identical across environments. Everything since has been built on that
assumption.

Dogfooding found the assumption wrong, and the reason is ownership
rather than convenience. **The author of a dashboard is the analyst.**
In the commercial application this gem was extracted from, the people
who decide which panes a dashboard has, in what order and at what
size, are the people reading it, and they cannot deploy. A composition
that lives in ERB is a file held by the wrong owner. One install
measured a fourteen minute round trip, edit, test, lint, CI, deploy,
poll, to add a single pane; the cost is real, but the ownership is the
argument.

The gem was already half of the way there, and the asymmetry was
visible once pointed at. A pane is a real URL accepting `as`,
`granularity`, `limit` and Ransack `q[...]`, so what a pane *shows*
changes live for anyone with the link (ADR 005, ADR 007, ADR 008).
Only *composition* was frozen in code.

## Decision

**A frame is a dashboard, and it is data.** Two records, created at
runtime, with no requirement to be declared or seeded in code first:

- `Janela::Frame`, one dashboard. A name, a slug, and its grid: how
  many columns and what gap.
- `Janela::Pane`, one visual in one frame. Its position, how many
  columns it spans, and what it shows: model, measure, dimension,
  renderer, granularity, limit, and an optional title of its own.

**The data definition drives the HTML.** Janela renders a frame from
its rows and the host composes nothing:

```erb
<%= janela_frame @frame %>
```

Grid, order, spans and each pane's Turbo Frame all derive from the
data. This is the point of the change: the library is data driven and
the markup fits the definition, rather than the definition being
markup.

**Layout uses CSS Grid's vocabulary, not a new one.** `columns` and
`gap` on the frame, `span` on a pane. Every Rails developer knows
these words, they map directly onto what renders with no translation
layer, and ADR 001 argues against inventing a glossary when a shared
one exists.

**The names come from window anatomy, one level each.** Janela is
Portuguese for window, so the gem name already carries the metaphor
and a class called `Window` would stutter. In a window the frame is
the fixed outer structure, the sash is the movable assembly inside it,
and the panes are the glass. The frame holds the panes, so `Frame` is
the container and `Pane` is the visual. `Sash`, a band of panes within
a frame, is deliberately **not** built: `columns` on the frame plus
`span` on a pane already express a row of single values, a full width
time series and a row of breakdowns, which is the dashboard shape this
project recommends. A sash would be a layer the layout does not need,
and it stays available if nested bands ever earn one.

**"Frame" now means two things, and the rule is written down rather
than discovered.** `Janela::Frame` is a dashboard. A `<turbo-frame>`
is the mechanism each pane is rendered inside. They sit one level
apart, so the frame holds frames, and the ambiguity is real: a
`Pane belongs_to :frame` gives `pane.frame_id` as a foreign key, which
collided with the existing `frame_id` meaning the DOM id of a pane's
turbo frame. That method is renamed `turbo_frame_id`, which is clearer
regardless. The rule: **frame unqualified means the dashboard; the DOM
element is always spelled turbo frame.**

**The code keeps the vocabulary; the data arranges it.** Measures and
dimensions stay declared in the `janela` block on the model, in git. A
`Pane` row may only name a measure and a dimension that block
declares, because `Janela.definition!` validates against the registry
and dimensions are themselves the Ransack allowlist (ADR 002, ADR
003). A row therefore cannot invent a query, reach a model nobody
exposed, or widen what is filterable. This property is worth stating
plainly, because it is precisely what is usually wrong with database
backed dashboards, and here it falls out of what is already built.

The division of labour is then: **developers define what can be asked;
analysts arrange what is shown.**

**The runtime object is `Janela::Query`.** Today's `Janela::Pane`
conflates the thing displayed with the query it runs. With `Pane`
taken by the persisted record, the runtime object, a definition plus a
measure, a dimension, filters and a renderer that resolves to a
result, becomes `Janela::Query`. A `Pane` row builds one to do its
work.

**Three editing surfaces, in this order.** All three are wanted; they
are not alternatives.

1. **Rows.** The models are the foundation, so a host, a script or an
   agent composes a frame with ordinary ActiveRecord. This is the
   whole of the first increment.
2. **Forms in the engine.** Plain Rails CRUD, no canvas: add a pane by
   choosing from the declared vocabulary, reorder, set a span, set a
   granularity. This is the analyst's minimum and the point at which
   the change delivers what it is for.
3. **A visual editor.** Accepted as the direction and deferred to its
   own ADR, because it is mostly a JavaScript design problem and
   should not be settled in the same breath as a schema.

**Authorisation is the host's, as always.** Reading and editing go
through Pundit policies on `Janela::Frame` and `Janela::Pane` in the
host application, the same hook every other part of the gem uses.
Janela ships no roles.

## What this supersedes in ADR 001

ADR 001 listed a drag and drop report designer under what Janela would
deliberately not build, reasoning that dashboards defined in code stay
small, reviewable and forkable. That reasoning holds for the
*vocabulary*, which is why measures and dimensions stay in code. It
does not hold for *composition*, because it assumed the developer was
the author. Everything else in ADR 001 stands: ship the load bearing
core, prefer one obvious way, stay decoupled from any host, keep the
codebase small enough to fork.

## Consequences

- A dashboard is no longer in git. It cannot be code reviewed,
  diffed, or guaranteed identical between environments, and a
  production frame will drift from anything staging has. This is the
  price of the decision and it is paid knowingly: the owner of a
  dashboard is not a person who works in git.
- Export and import of a frame will be wanted, to move one between
  environments and to put one under review when it matters. Not built
  now; noted so it is not a surprise.
- Rendering a frame is a new surface: a helper, a grid, and a
  stylesheet, because a grid with no CSS means nothing. The missing
  default stylesheet (#15) and inter pane layout (#29) become part of
  this work rather than neighbours to it.
- Snapshots (ADR 009) name their panes explicitly today. A frame gives
  a snapshot an obvious subject: freeze a frame, not a list. A later
  ADR, but the shape is now clear.
- Renaming the runtime object touches the helper, both controllers,
  the snapshot model, a view and the tests. Mechanical, pre 1.0, and
  invisible to hosts: `janela_pane` keeps its name, so neither
  existing installation changes.
- Every dashboard built so far, including the demo and both hosts, is
  ERB calling `janela_pane`. That helper keeps working. A frame is an
  addition, not a replacement, and nothing has to move.
