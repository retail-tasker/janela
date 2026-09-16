---
Date: 2026-09-16
Status: Accepted
Related: ADR 003, ADR 005, ADR 008, ADR 009, ADR 018
Triggers:
  - changing what a click on a value does
  - adding a filter predicate or changing the URL grammar
  - adding a keyboard shortcut
  - anything a mouse can do that a keyboard cannot
Topics: cross-filtering, urls, accessibility, ransack
---

# ADR 024: Selecting More Than One Value

## Context

A click on a value writes one Ransack condition, `q[status_eq]=paid`,
and clicking the same value again removes it. One value per dimension.
Every real dashboard eventually needs two: paid and pending, APAC and
EU. A commercial tool does this with a modifier click, and everyone
already knows the gesture.

The gesture is the easy part. `toggle(event)` already receives the
event, so `ctrlKey || metaKey` is there for a table button, and
Chart.js hands its own click handler the native event. What needs
deciding is what the URL says, what happens to the null group, and
what someone without a mouse does instead, because a modifier click is
invisible, absent on touch and unreachable from a keyboard. Deciding
the gesture without deciding that last part would build a feature only
some people can use (#35, #36).

Three things were measured against the dummy before writing this,
rather than assumed:

- `status_in: [paid, pending]` passes Janela's allowlist guard and
  returns the sum of both. A dimension's allowlist is per attribute, so
  the predicate needs nothing added.
- `status_eq: paid` still works, so an existing link keeps working
  whatever a new click writes.
- `channel_null: 1` together with `channel_in: [web]` **returns zero**.
  Ransack ANDs its conditions, so that combination asks for rows whose
  channel is both null and web.

That last one is the whole difficulty. It does not raise. It renders
an empty dashboard, which reads as a bug in Janela rather than as an
impossible question.

## Decision

**A click selects, a modifier click adds, and the selection is a set.**

Following the convention every list in every operating system already
uses, so that nothing has to be learned:

| Gesture | Result |
| --- | --- |
| Click an unselected value | That value alone is selected |
| Click the only selected value | The dimension is cleared |
| Click a value while others are selected | That value replaces them |
| Ctrl or Cmd click | That value is added or removed, the rest stay |

**Janela writes `_in`, and keeps reading `_eq`.** A click always
produces `q[status_in][]=paid`, one value or five, so there is one
shape in the controller, one in the view and one in a stored snapshot.
A hand written or previously shared `_eq` link keeps working, because
Ransack accepts it and because a URL somebody already sent should not
stop working to suit us (ADR 005).

**The null group is exclusive within its dimension.** Selecting
`(none)` clears the other values of that dimension, and selecting a
value clears `(none)`. The combination is unanswerable, and the honest
options are to refuse it or to render nothing and let it look broken.

Ransack can express the OR through its `g[]` grouping, and that is
rejected. It would make the URL unreadable, and ADR 005's grammar is
built on a URL a person can read and edit. It would also have to be
understood by every stored snapshot and every hand written link
forever, to serve a question almost nobody asks.

**The keyboard gets the same two gestures, not a different feature.**
A value is already a real `<button>` (ADR 018), so Enter is a click
and **Ctrl or Cmd with Enter is a modifier click**, using the same
flags on the same event. Nothing new is invented, and nothing has to
be learned twice.

**Janela binds exactly two keys, and only inside the frame.**

- `Escape` clears the frame's filters.
- `Enter` and `Space` act on the focused value, as they already do.

No single letter keys. A single letter belongs to the host
application, to its own shortcuts, and to any text field on the page.
Janela is a guest in someone else's application and will not take a
key that could mean something there. A host that wants `c` for clear
binds its own control to `janela--frame#clear`, which is how the clear
button already works.

**A chart stays a mouse surface, and the table is the accessible one.**
A bar is painted pixels with nothing focusable behind it. Rather than
build a parallel focus model inside a canvas, Janela says plainly that
the table renders the same data and is operable by keyboard, which is
what ADR 018 made a table the universal renderer for. A chart
highlights every selected value rather than one.

## Consequences

- A dashboard can answer "paid and pending", which is the ordinary
  question this could not previously express.
- `Query#selected_value` becomes `selected_values` and returns an
  array. A host that overrode a pane view touches it, so this is a
  breaking change, and it goes in UPGRADING.md with the version that
  carries it (ADR 015).
- A shared link's shape changes from `q[status_eq]=paid` to
  `q[status_in][]=paid`. Older links keep working, so nothing that was
  sent stops working.
- The page URL and every pane `src` now carry repeated parameters. The
  controller sorts filters so an unchanged `src` is never reloaded, and
  it must sort the values inside a dimension too or a set will
  serialise two ways and refetch every pane for nothing.
- Touch has no modifier key, so a touch user gets replace-only
  selection. That is a real gap and this ADR does not close it. The
  answer, when someone needs it, is a control the host can render that
  makes the next clicks additive, with the modifier as its accelerator
  rather than the only path. Not built, because the simple thing has
  not yet failed.
- Snapshots store filters as JSON, so an array needs nothing new, and
  a snapshot taken under `_eq` still reads.
