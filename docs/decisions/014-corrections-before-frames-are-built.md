---
Date: 2026-09-15
Status: Accepted
Related: ADR 001, ADR 002, ADR 005, ADR 008, ADR 009, ADR 010, ADR 011, ADR 012, ADR 013
Supersedes: part of ADR 012, part of ADR 013
Triggers:
  - building frames or panes as records
  - naming anything in the gem's public vocabulary
  - adding a route, a layout or an index to the engine
  - scoping or authorising a frame
  - rendering a pane from a row rather than from URL parameters
Topics: frames, panes, naming, routes, layouts, authorisation, tenancy, sequencing
---

# ADR 014: Corrections Before Frames Are Built

## Context

ADR 012 made frames and panes data and ADR 013 decided how a frame is
named and addressed. Both were accepted within an hour of each other
at the end of a long session. An independent review before any code
was written found three decisions that are wrong rather than
incomplete, and several claims that are overstated. This ADR corrects
them, records the naming rule that was implicit, and sequences the
build. It is the document to read before writing any of it.

## Decision

### A frame page renders its panes, not empty frames

ADR 013 has the engine serve an index and a show page for frames. ADR
011 has anything the engine serves render in Janela's own minimal
layout, which deliberately loads no assets. A frame page is a grid of
lazily loaded `turbo-frame` elements, so with no Turbo on the page
they never fetch and **the page renders blank**. The two ADRs conflict
and neither noticed.

A frame page therefore renders each pane's content inline, inside its
`turbo-frame`, on the first response. Cross-filtering still replaces
frames afterwards when Turbo is present, and without Turbo the page is
a correct static dashboard.

This is better than either ADR intended, for reasons beyond the
conflict: it removes a fan out of one request per pane on every load,
and it is what ADR 008 already required of a dashboard, that a shared
link be correct before any JavaScript runs. The host composed
dashboard should do the same, which makes `loading: :lazy` on a pane an
option rather than the default.

### A frame carries an opaque owner, and is always read through a scope

ADR 012 said authorisation is the host's Pundit policy on
`Janela::Frame`. A frame has no ownership column, so a multi tenant
host cannot write a `Scope` over it at all, and the shipped index
would list every tenant's frames with enumerable integer ids. One of
the two real hosts is multi tenant.

`Janela::Frame belongs_to :owner, polymorphic: true, optional: true`.
Janela never interprets the owner: it sets nothing, reads nothing from
it, and offers no roles. It exists so a host's policy `Scope` has
something to filter on. A single user host leaves it null.

Every controller lookup goes through the host's scope rather than
`find` on the class, so a frame belonging to another tenant is a 404
and ids stay unguessable in effect if not in form. The same correction
applies to the existing snapshot pane controller, which looks a
snapshot up unscoped today.

### A pane row is addressed as a row

ADR 012 assumed a persisted pane could be rendered through the
existing pane URL. It cannot, for two reasons found in the code. The
`turbo-frame` id is derived from the query, so two rows in one frame
with the same measure, dimension and renderer produce duplicate DOM
ids and Turbo replaces the wrong one. And a row's own title cannot
reach the response, because the controller builds everything from URL
parameters.

A pane row gets its own nested route, `frames/:frame_id/panes/:id`,
identified in the DOM as `janela_pane_<id>`, built from the row. The
ADR 005 pane grammar stays exactly as published and keeps its purpose:
an ad hoc pane, addressable and shareable without a row existing.

This also resolves a collision ADR 012 missed. The controller that
renders a query is already `PanesController`, and the forms surface
needs that name for CRUD. The query renderer keeps the ADR 005 URL and
is renamed with it.

### Frames sit at the mount root, and the path configuration is dropped

ADR 013 gave frames their own path segment, configurable, defaulting
to `dashboards`, and claimed this removed the collision with the pane
grammar entirely. That claim is false. `/dashboards/3` matches the
pane route as model `dashboards` and measure `3`, and worse, a host
model whose route key equals the chosen segment, `Report`, `Dashboard`
or `Insight`, has its panes shadowed by it. Those are precisely the
words the option exists to allow.

Frames live at the mount root with a numeric id constraint:

```
/insights                  every frame
/insights/3                one frame
/insights/orders/revenue   an ad hoc pane, grammar unchanged
```

No model route key is all digits, so nothing collides, and the mount
path is already the host's noun by ADR 005. The configuration value
ADR 013 added is deleted before it ships. ADR 001 prefers this.

### The security claim, stated accurately

ADR 012 claimed a persisted pane adds no query surface because
dimensions are the Ransack allowlist. The registry and the fetch or
raise lookups do hold, and a row genuinely cannot invent a query,
reach an unexposed model or widen what is filterable. Two corrections
to how it was stated:

- Dimensions are the allowlist **only when the model has not already
  declared its own**. Janela skips generating the allowlist if the
  host defined `ransackable_attributes`, so in that case the surface
  is the host's list, not Janela's. Both real hosts define their own.
- Filter parameters are still permitted wholesale, so any Ransack
  predicate on an allowed attribute is reachable. That is issue #8 and
  is unchanged by frames.

Rows are validated against the registry on save, not only at render:
model, measure, dimension, renderer, granularity and limit. Otherwise
deleting a dimension from a `janela` block silently breaks every row
naming it, and the failure appears to a reader as a missing pane. A
pane's title is the first analyst authored text the gem renders, and
is escaped like any other string, never marked safe.

### A pane whose model has no policy fails as one pane

A frame spanning several models may include one the viewer's host has
no policy for, which raises inside a single pane request. That pane
renders a refusal in its own frame with a 403 rather than taking out
the response.

### Naming: uncommon but conceivable, so a host is not pigeonholed

The words in the gem's vocabulary, Janela, Frame, Pane, are chosen to
be uncommon and still conceivable. A class called `Dashboard` would
push every host into calling the thing a dashboard; `Frame` leaves
them free to say insight, report or scorecard through i18n while the
gem keeps one internal vocabulary. This is the same principle as the
mount path belonging to the host (ADR 005) and the noun coming from a
locale file (ADR 013), and it is a rule rather than a preference: **the
gem's own words should not become a host's product language.**

The review's argument for `Dashboard`, that it removes glue, is
therefore declined, and the glue is realigned to `Frame` instead:

- `janela_dashboard do ... end` becomes `janela_frame do ... end`, and
  gains a record form, `janela_frame @frame`. One helper, two ways to
  supply the panes.
- The Stimulus controller `janela--dashboard` becomes `janela--frame`,
  and its file follows. Hosts register it by name, so this is a
  breaking change for the two installations and belongs in the
  changelog.
- The helper module becomes `Janela::FramesHelper`.
- Today's runtime `Janela::Pane` becomes `Janela::Query`, freeing
  `Pane` for the record, as ADR 012 decided.

### Sequence: four builds, not one

1. **Rename only.** `Pane` to `Query`, `janela_dashboard` to
   `janela_frame`, the Stimulus controller, the helper module. No new
   behaviour, no records, both hosts updated for the controller name.
2. **Records and rendering.** Migrations, `Frame` and `Pane`, the
   opaque owner, row validations, the nested pane route, inline first
   render, the grid and the stylesheet. A host renders a frame in its
   own page and owns the authorisation.
3. **The engine's own pages.** Index and show at the mount root, only
   once 1 and 2 are settled and scoping is proven in a real host.
4. **Forms.** The analyst's editing surface, as conventional Rails
   CRUD on the nested resources.

The visual editor keeps its own future ADR, and ADR 012's commitment
to it is softened here to undecided: the ownership argument justifies
records and forms, and does not by itself justify a canvas.

### Documentation that is now wrong

The README still lists a report designer as out of scope and says
there is no drag and drop designer. ADR 009 states there is no
Dashboard model. ADR 010's skill instructs agents not to build a
report designer, and requires the skill to describe only the README's
API. All three must be corrected as part of build 2, not after it.

## Consequences

- Nothing in ADR 012's core is reversed: frames and panes are still
  data, created at runtime, and the HTML still derives from the rows.
  What changes is how they are addressed, scoped and first rendered.
- One configuration value is removed before shipping and none is
  added, so the gem still has exactly one, `parent_controller`.
- Inline first render means a frame page does one query per pane on
  the server. At the scale a dashboard renders that is cheaper than
  the request per pane it replaces, but it makes the ordering and
  limit decision of ADR 007 load bearing for page speed rather than
  only for legibility.
- The polymorphic owner is the first column Janela adds that it does
  not itself use. It is a hook and is documented as one.
- Build 1 is a breaking change for two known installations with no
  user visible benefit, which is the right moment to take it: the only
  installations are the author's.
- Uncommon words are collision free by construction, which is the
  point of the rule: no host names a model `Frame` or `Pane`, so the
  class, the CSS hook, the DOM id and the sentence "the pane is not
  loading" are unambiguous in any application with no coordination.
  The application this gem was extracted from already has a
  `Dashboard` model, a `DashboardPolicy` and a `dashboards` table, so
  the declined name would have collided in conversation there
  permanently. Active Storage's `Blob` and Action Text's `RichText`
  are the same choice; Blazer's `Dashboard` is the counter example.
- The cost is a permanent translation tax on documentation. Every
  README example, error message and line of ADR 010's skill has to
  decide whether to speak the gem's word or the reader's, and a gloss
  like "a frame is a dashboard" never stops being necessary. That is
  accepted as much smaller than a name that collides in every host.
