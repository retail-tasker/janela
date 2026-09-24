---
Date: 2026-09-24
Status: Accepted
Related: ADR 003, ADR 008, ADR 012, ADR 024, ADR 025, ADR 030, ADR 032, ADR 034
Triggers:
  - showing a frame on a record's own page, filtered to that record
  - reusing one frame across many records
  - carrying a host's filter in q[...] and finding it cleared
  - deciding whether a filter is a view choice or an authorisation boundary
  - changing how a pane URL is built, or what clear() and toggle() touch
Topics: frames, filters, cross-filtering, urls, authorisation
---

# ADR 040: A Host Can Fix a Frame's Filter, and No Click Removes It

## Context

A host wants the same dashboard on every record's page, narrowed to
that record: a frame of the work in a queue, shown at the top of each
queue's page. Since ADR 012 a frame is a row an analyst edits, so the
panes are the same everywhere and only the record changes. Janela has
no way to say "this frame, for this record" (#57).

The only filter Janela knows is the one in the page URL, `q[...]`
(ADR 008). So a host redirects the record's page to carry one,
`/queues/42?q[queue_id_eq]=42`, and the panes read it. Measured on the
demo with `q[status_eq]=paid` standing in for the host's filter, it
does not hold:

- Opened with the filter, the revenue pane read $469,097.85 and every
  pane's `src` carried `q[status_eq]=paid`.
- **Clear filters**, the button a dashboard shows, took it off. Revenue
  read $664,639.01, the whole table, and the page URL lost the
  parameter.
- **Escape**, with focus inside the frame, did the same.
- A click on a `status` value would replace it, because `toggle()`
  clears every predicate on the dimension it is changing (ADR 024).

None of this is a bug in the frame controller. `q[...]` is Janela's by
design: `stripFilters` removes every `q[` key before writing the
current selection, and `clear()` empties the frame's filters, because
the selection is the reader's to change. A host's filter placed there
becomes the reader's to change too. On a record's page the reader then
sees every record their scope allows under that record's heading.
Nothing leaks, since `policy_scope` still bounds every pane (ADR 032).
The numbers are wrong, and they look right.

### What was considered

**Making `clear()` leave the host's keys alone** was rejected. The
controller cannot tell a host's `q[queue_id_eq]` from a reader's link
that carries the same key, and ADR 008 means a shared link carries
exactly that. Any rule for telling them apart would be a second
convention inside one parameter.

**The host's `policy_scope`** was rejected. It answers who may see
which rows, and it runs in the engine's pane requests, which know
nothing about the page that holds the frame. Putting a page's record
into it would make authorisation depend on which page a pane was
loaded from, and ADR 032's checks would be reasoning about a scope that
changes per page.

**Storing the filter on the frame**, a `filters` column on
`janela_frames`, was rejected as the answer to this case. The case is
one frame reused across many records, so the filter belongs to the
render, not to the row. A frame that should always be narrowed the
same way is a smaller, different case, and it can be built on this
later.

**Signing the filter**, carrying it as a `MessageVerifier` token so a
reader cannot edit it, was rejected. It would imply a security
guarantee this is not. A reader who edits the fixed filter out of a
pane URL sees rows `policy_scope` already lets them see, which they
could see on any other dashboard. Signing adds a key to rotate and a
failure mode to explain, to protect nothing that authorisation does
not already protect.

## Decision

**A host passes a filter when it renders a frame, and Janela applies it
to every pane beneath the reader's selection, where no click, clear or
link can remove it.**

```erb
<%= janela_frame @frame, where: { queue_id_eq: @queue.id } %>

<%= janela_frame where: { queue_id_eq: @queue.id } do %>
  <%= janela_pane Card, :count, by: :status %>
<% end %>
```

`where:` is the name `Definition#query` already uses for the same
thing, Ransack conditions narrowing a relation, so a host learns one
word for it.

**It travels in the pane's base URL under its own key, `where[...]`.**
The helper writes it into each pane's `data-janela-src`, the base the
frame controller builds every request from, and into the first
render's `src`. The controller never reads or writes `where[...]`:
`stripFilters` removes only `q[` keys, `clear()` empties only the
frame's filters, and `toggle()` changes only `q[`. So the fixed filter
survives every click without the controller learning anything about
it. It is not written into the page URL, which already says what the
record is.

**The server applies it first and separately.** The pane endpoints
read `params[:where]` and `params[:q]` and narrow the relation twice,
fixed filter first, so the reader's selection can only narrow further.
The same key in both is two conditions ANDed, never one replacing the
other. The fixed filter goes through `Definition#filter`, so it is
bounded exactly as `q[...]` is: only declared dimensions, only the
predicates ADR 025 allows for each kind, and no more than 1000 values.
A host cannot fix a filter on a column it has not declared, which is
the same rule a reader already meets.

**It is a view filter, not an authorisation boundary, and the
documentation says so in those words.** It is visible in every pane's
URL, and a reader can remove it by editing one. What they reach by
doing that is what `policy_scope` already allows. A host that needs a
reader not to see other records writes that in its scope, where it
applies to every pane on every page.

## Consequences

- One frame serves every record's page. An analyst edits it once, and
  the host needs no column pointing at a frame per record.
- A host that carries its filter in `q[...]` today, by redirect, moves
  it to `where:` and drops the redirect. Nothing breaks if it does not
  move; the old way keeps its old weakness. The guide for this goes in
  docs/composing.md.
- The pane URL shape gains `where[...]`. ADR 037 names the pane URL as
  part of the surface that stops moving at 1.0, so this is better
  decided before 1.0 than after, and it is additive: every existing URL
  means what it meant.
- A snapshot is taken with the filters its caller passes (ADR 009,
  ADR 034), not from a rendered page. A host snapshotting a record's
  frame passes the fixed filter in `filters:`, and nothing does that
  for it. Worth a line in the snapshot documentation, not a mechanism.
- The dimension the host fixes should not also be offered as a
  clickable pane. Clicking it would AND a second condition on the same
  column, and any value but the fixed one returns nothing. That is
  correct and confusing, so the guide says not to.
- What would change this decision: a host that needs the fixed filter
  hidden from the reader for a reason `policy_scope` cannot express.
  That would reopen signing, and this record says why it was left out.
