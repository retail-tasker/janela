---
Date: 2026-09-15
Status: Accepted
Related: ADR 005, ADR 011, ADR 012
Triggers:
  - changing how a frame is addressed, or what a frame is called in a host's interface
  - adding a slug, a friendly URL or a lookup other than the primary key
  - adding or replacing the index of frames
  - a frame slug or path segment colliding with the pane grammar
Topics: routes, urls, naming, i18n, frames, defaults
---

# ADR 013: Naming and Addressing Frames

## Context

ADR 012 made a frame a database record. Three questions follow from
that and none were settled there: what a host calls a frame in its own
interface, how a frame is addressed, and how a person finds one.

The first is the same question ADR 005 answered for the mount path.
"Frame" is the code's word, taken from window anatomy; it is not a
word an analyst would use. One host calls these insights, another
reports, another dashboards, and the difference is business language
rather than preference.

The second has a trap. ADR 005 published the pane grammar as
`/<mount>/:model/:measure(/:dimension)`. A frame addressed directly
under the mount, `/insights/vamos-review`, cannot be distinguished
from the start of a pane URL: Rails cannot tell a frame slug from a
model route key, and the frame route would shadow every pane.

## Decision

**What a frame is called comes from i18n, not from configuration.**
The class stays `Janela::Frame`, and every label the engine renders
uses `Frame.model_name.human`, so a host renames it in its own locale
file:

```yaml
en:
  activerecord:
    models:
      janela/frame:
        one: "Dashboard"
        other: "Dashboards"
```

This adds no setting, uses the mechanism Rails already has, and
composes with real translation rather than only relabelling. Janela
ships English defaults.

**Frames live under their own path segment, and that segment is the
host's.** A single configurable value, defaulting to `dashboards`
because that is the word most hosts want and no one should have to
read the gem to like the default:

```
/insights/dashboards            every frame
/insights/dashboards/3          one frame
/insights/orders/revenue/status a pane, grammar unchanged
```

The segment removes the collision entirely, so the pane grammar from
ADR 005 needs no constraints or disambiguation and stays exactly as
published.

**A frame is addressed by its primary key, the Rails way.**
`resources :frames` inside the engine, looked up with
`find(params[:id])`. No slug column, therefore no uniqueness rules, no
reserved word list, no regeneration on rename, and no second lookup
path to keep working.

If readable URLs are wanted later, the Rails answer is to override
`to_param` to return `"3-quarterly-review"`. Rails resolves that back
through `to_i`, so lookups do not change and nothing has to be
unique. That is an option for a host or a later decision here, not a
schema.

**Using `resources` is also the editing surface.** ADR 012's second
editing surface, plain forms in the engine, is `index`, `new`, `edit`,
`update` and `destroy` on that resource. Choosing the conventional
route shape means the forms are the framework's defaults rather than
something invented.

**Janela ships an index, and a host may ignore it.** The mount's frame
segment renders a grid of cards, one per frame, with its name, how
many panes it has and when it changed. That is enough for a host to
install the gem and navigate on the same day, which is the point.

A host that wants something else writes its own page over
`Janela::Frame.all` and never routes to ours. This is the pattern from
ADR 011: ship a default that works, let the host replace it, add no
configuration for the choice.

**A richer browse is not this decision.** Rows grouped by category,
horizontal scrolling and hover previews are a different size of
feature, and a preview in particular is expensive because a thumbnail
means rendering panes. The card grid is the default; anything more
earns its own ADR once a host has enough frames to justify browsing
rather than listing.

## Consequences

- Nothing in a host's interface says "frame" unless the host wants it
  to, and the word in the URL is the host's too. The code keeps one
  vocabulary and the reader keeps theirs.
- One configuration value is added, for the path segment. It is
  justified on the same grounds as ADR 005's mount path: it appears in
  a URL a person reads. The noun in labels deliberately is not
  configuration, because i18n already does it.
- Integer ids mean a frame URL is not self describing. `to_param` is
  the escape hatch and costs nothing to adopt later.
- The index is a new view in the engine, so it is more surface to
  style, which reinforces that the default stylesheet (#15) is part of
  this body of work and not adjacent to it.
- Frames being a conventional Rails resource means the forms surface
  arrives largely for free, which moves ADR 012's second editing stage
  closer than it looked.
