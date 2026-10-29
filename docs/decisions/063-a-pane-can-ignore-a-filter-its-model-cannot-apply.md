---
Date: 2026-10-29
Status: Proposed
Related: ADR 003, ADR 005, ADR 008, ADR 012, ADR 025, ADR 035, ADR 037, ADR 040, ADR 043, ADR 053
Triggers:
  - a frame holding panes over more than one model
  - a pane showing "That request is not allowed on this pane" after a click on another pane
  - deciding what a pane does with a filter key its model does not declare
  - adding a boolean to a pane, a column to janela_panes, or a parameter to the pane URL
  - a setting that could live on the frame or on the pane
Topics: cross-filtering, ransack, panes, frames, urls, public-api, security
---

# ADR 063: A Pane Can Ignore a Filter Its Model Cannot Apply

## Context

#92, found trialling a frame that holds panes over two models: the demo's
orders, with a status, a region and a date, and the demo's page views,
with a page and a date. Clicking `paid` on an orders pane writes
`q[status_in][]=paid` to the frame (ADR 003, ADR 008), the frame hands
it to every pane, and the page views pane answers with "That request is
not allowed on this pane" where its number was.

Measured against the demo before deciding. `Query#applicable_filters`
drops only the pane's own dimension, which is the cross-filtering rule:
the pane you clicked shows the alternatives to what you picked. Every
other key goes to `Definition#filter`, where `reject_dropped_filters!`
compares what Ransack applied with what was asked and raises
`BadRequest` for the difference: `PageView does not allow filtering on
status_in`. Ransack itself, asked for `status_in` and `viewed_on_gteq`
on page views, applied `viewed_on` and dropped `status` without a word.

That refusal is deliberate and right (ADR 025). Ransack discards a
condition its allowlist does not permit, so a typo in a hand written
`q[...]` would quietly show an unfiltered number, which is the worst
thing this library can do. Nothing about that changes here. What is
wrong is only its reach: a key another pane's model declares is not a
mistake, it is a click the reader made on a pane beside this one, and
the honest answer is for this pane to stay as it is.

A key both models declare under the same name, such as a date, or one
reached through an association, already works, because it matches a
declared dimension on the second model too.

### What was considered

**Drop undeclared keys on every pane.** The smallest change and the
wrong one: it removes the loud failure ADR 025 chose, for every host,
to suit the one frame that mixes models.

**A setting on the frame.** A frame is where the mixing happens, so a
frame that says "my panes ignore what they cannot apply" reads well.
Rejected, for how a pane is drawn. A pane is fetched on its own URL in
its own request (ADR 005), lazily and again on every cross-filter, and
a hand written `janela_frame do` block has no record at all, so the
setting would have to travel on each pane's URL anyway to reach the
request that draws it. A frame column would then be a fourth place to
say a per-pane thing, beside the row, the helper and the URL that every
other option already uses, and it could not reach a hand written frame.

**Derive it: drop a key that another pane in the same frame declares.**
The most precise rule, since a key no pane can apply is still a typo.
Rejected, because only a stored pane fetched through its frame knows
what the other panes are; a `janela_pane` on its own URL does not, and
the two shapes would behave differently for the same click.

**Have the frame controller send each pane only the keys its model
declares.** The browser does not know the models' dimensions, and
teaching it would put the allowlist in the page (ADR 025 keeps it on
the server).

## Decision

**A pane may carry `ignore_unknown_filters`, a yes or a no. When set,
the reader's filters whose keys Ransack would not apply to the pane's
model are dropped before the query, and the pane draws as if they were
never written. Unset is exactly what a pane is today: a key the model
does not declare is refused with its reason.**

```erb
<%= janela_frame do %>
  <%= janela_pane Order, :revenue, by: :status, as: :bar %>
  <%= janela_pane PageView, :views, by: :page, ignore_unknown_filters: true %>
<% end %>
```

**Only the reader's filters are dropped.** A host's fixed `where:`
(ADR 040) and a frame's `default_where` (ADR 043) are the host's and the
analyst's own words about this pane and stay refused when wrong, as they
are validated today. A key the model does declare but with a predicate
its dimension does not allow, such as `status_matches`, is still refused:
that is a misuse of a real key, not another model's key.

**What is dropped is what Ransack would drop,** read the same way
`reject_dropped_filters!` reads it, so the two cannot disagree about
which keys belong to the model. A key that survives is applied exactly
as it would be on any pane.

**It is opt in, per pane, because the pane is what knows.** A pane is
the unit that is fetched, refused and drawn, and the analyst placing a
page views pane on an orders frame is the one who knows it will be
clicked past. A pane that never meets another model keeps the loud
failure, and a typo on it is still a typo.

**One vocabulary in three places,** as `value_labels` is (ADR 054):

- `Janela::Pane#ignore_unknown_filters`, a nullable boolean offered on
  the pane form as a checkbox.
- `janela_pane` takes `ignore_unknown_filters:`.
- The pane URL carries `?ignore_unknown_filters=1`, because the server
  draws the pane again from that URL on every cross-filter.

`janela_snapshot_pane` does not take it: a snapshot's filters were
fixed when it was taken and the request's are ignored (ADR 009).

**It is not part of the pane's identity** (ADR 029). What a pane does
with a stray key does not say which query it is.

## Consequences

- A frame can hold panes over two models and a click on either side
  leaves the other side standing. That is the first thing a host
  building a page over events and the records they belong to tries.
- **A migration for stored frames.** `janela_panes` gains a nullable
  boolean, additive, so every existing pane is unset and refused as
  before. A host using stored frames runs `bin/rails
  janela:install:migrations` and `db:migrate`, in `UPGRADING.md`. The
  doctor's `unmigrated-columns` check is taught the column.
- **`Janela::Tools` learns the attribute** in the same change (ADR 053).
- **The pane URL grammar grows by one optional parameter,** which ADR
  037 counts as public surface.
- A pane that ignores a key is silently unfiltered by it, which is the
  very thing ADR 025 refuses by default. It is accepted here because the
  analyst asked for it on that pane, and because the alternative is a
  pane that cannot share a frame with another model at all. The log
  says nothing when a key is dropped: a dropped key is the normal case
  on such a pane, not a finding.
- A dimension reached through an association is addressed by the host
  as `<association>_<column>`, so two models can share a click only when
  they spell the key the same. A way for a host to alias that name is a
  separate question, not decided here.
- What would change this decision: a frame that needs the derived rule,
  a key dropped only when another pane in the frame declares it, which
  would need the pane URL to carry the frame's vocabulary and is an
  argument about what a pane URL says; or a host that wants the drop
  logged, which is a setting that would have to earn itself.
