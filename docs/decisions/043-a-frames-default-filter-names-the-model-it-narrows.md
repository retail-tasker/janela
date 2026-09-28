---
Date: 2026-09-28
Status: Accepted
Related: ADR 012, ADR 014, ADR 020, ADR 025, ADR 040
Triggers:
  - a frame that should always exclude some rows, regardless of who renders it
  - adding a column to Janela::Frame or Janela::Pane
  - a host copying the same where: condition into every view that renders one frame
  - validating a stored Ransack condition at save time rather than at render
Topics: frames, filters, cross-filtering, persistence, ransack
---

# ADR 043: A Frame's Default Filter Names the Model It Narrows

## Context

#63, found while dogfooding: ADR 040 gives a host a way to narrow a
frame to the current record, `where: { project_id_eq: @project.id }`,
code, per request, correctly not data because the value is inherently
per-record. It does not give a frame a way to say something that is
true on every render, forever: "this queue never counts an archived
row." That is not per-record narrowing, it is a permanent property of
what the dashboard means, and today it can only be expressed by typing
the same Ransack condition into every view that renders the frame.

ADR 012's own argument is that composition moved out of ERB because
the analyst, not the developer, owns a dashboard, and a decision typed
into a view is "a file held by the wrong owner." A permanent filter is
exactly that file, with nowhere on the data side to move to: `Frame`
and `Pane` have no column that could hold one.

### What breaks the obvious shape

The obvious answer, a `default_where` column on `Frame` applied to
every pane in it, runs into a fact ADR 020 already used to reject the
frame as the layer for a different per-pane setting: a frame can hold
panes from more than one model. Measured against the demo, reusing the
existing bound check rather than assuming it:

```ruby
Order.janela.narrow(Order.all, "expedited_eq" => "false")
# => Janela::BadRequest: Order does not allow filtering on expedited_eq.
#    Declare a janela dimension, or add it to ransackable_attributes.
```

`expedited` is a real column on `Order`, not a declared dimension. A
condition applied uniformly to every pane in a frame raises for any
pane whose model, or whose declared dimension set, does not carry the
attribute the condition names. ADR 020's own case was a format string
being "right for the currency and wrong for the count sitting next to
it"; a stored Ransack condition is at least as specific to one model.

### What was considered for where the mismatch goes

**Raise for every pane whose model does not match.** Rejected: the
frame breaks the moment an analyst adds a pane over a second model, or
the moment a declared dimension is removed from the first, and the
failure is frame-wide rather than local to the pane that changed.

**Skip the condition quietly for a pane it does not apply to.** Rejected
outright. ADR 024, ADR 032 and ADR 034 all refuse the same shape of
quiet: a filter that means one thing for one pane and nothing for
another, on the same frame, with nothing on the page saying so.

**Restrict a frame with a default to panes over one model.** Considered
and rejected as an unnecessary restriction on `Pane`, which already
allows any model with a `janela` block. The mismatch is the default's
problem to solve, not a new constraint on what a frame may hold.

## Decision

**A frame's default filter names the one model it narrows, and only a
pane over that model takes it.** `Janela::Frame` gains two columns,
`default_model` and `default_where`, both nullable and present or
absent together:

```ruby
frame.update!(default_model: "orders", default_where: { "status_not_eq" => "archived" })
```

**`default_model` is validated the same way `Pane#model` already is**:
blank, or a route key naming a model with a `janela` block, checked
through `Janela.definition!` and rescued the same way
`declared_by_a_janela_block` does. It does not have to match any pane
the frame currently holds. A frame can carry a default before its first
matching pane exists, and a pane over a different model is simply never
narrowed by it, no error, because the condition was never claimed to be
about it.

**`default_where` is validated against that one model's `Definition` at
save time**, not only discovered wrong at render. `Definition#narrow`
already runs `Ransack#ransack` and the three checks ADR 025 built
(dropped filters, disallowed predicates, oversized value lists); a new
validation calls it against `default_model`'s definition and turns a
raised `Janela::BadRequest` into a validation error on `default_where`,
the same sentence a request would have raised, read at the point an
analyst can still fix it. This is new ground: nothing today validates a
persisted, arbitrary Ransack condition at save time, only `fixed` and
the reader's `q[...]`, which are validated fresh on every render because
neither is ever stored.

**It composes as a third layer, ahead of the two ADR 040 already
built.** `Pane#query` asks its frame for the default that applies to its
own model and passes it to `Query`, which narrows with it before `fixed`
narrows again, before the reader's own filters:

```ruby
# Janela::Frame
def default_for(model)
  default_model == model.model_name.route_key ? default_where.to_h : {}
end

# Janela::Query#result
on = definition.narrow(on || model.all, default) if default.present?  # frame, permanent
on = definition.narrow(on, fixed) if fixed.present?                   # host, per-record (ADR 040)
definition.query(measure, by: dimension, where: applicable_filters, on: on, ...) # reader
```

Applied even on a pane's own dimension, the same as `fixed`: the point
of "this queue never counts an archived row" is that no pane on it ever
shows archived as one of its own bars either. Nothing the reader does
in `q[...]` can remove it, for the same reason nothing the reader does
can remove a host's fixed filter.

**Only a stored frame can have one.** A hand composed `janela_frame do
... end` block has no `Frame` row for a default to live on; a host
composing a page in ERB already writes its own permanent conditions in
its own code, in one place, which is what ADR 012 left unchanged for
that path. This is additive to the data-driven half only.

**Vocabulary, so the three layers stay distinct.** *Default* is the
frame's own, permanent, data. *Fixed* stays ADR 040's word for the
host's own, per-record, code. *Filters*, or `q[...]`, stays the
reader's. Three words, three owners, and none of them is allowed to
mean another.

## Consequences

- An analyst declares "this queue never counts an archived row" once,
  as a row, and it holds across every page that ever renders the frame,
  including one that does not exist yet.
- **A stale default is a frame-wide failure, not a pane-wide one.**
  If `default_model`'s `janela` block later drops the dimension
  `default_where` names, every pane over that model in the frame raises
  at render, the same "missing pane" treatment `declared_by_a_janela_block`
  already gives a stale measure or dimension, just wider: one condition
  now speaks for every pane that shares its model rather than for one
  row. Worth a line in the engine's own edit form once built.
- `janela_frames` gains `default_model` and `default_where`, both
  nullable. Existing frames are unaffected either way; needs a migration
  and an `UPGRADING.md` entry (ADR 015).
- **Not decided here: a frame with panes over two models, each wanting
  its own permanent default.** One `(model, where)` pair per frame is
  what is built. A second model needing one of its own is the trigger to
  revisit this as a has-many rather than a second pair of columns, the
  same way ADR 040 left a signed filter for the day a host's need for
  one is real rather than guessed at.
- The engine's own frame form needs a way to set both columns together,
  and to clear both together; not built here.
- What would change this decision: a host needing a permanent filter
  that is not one model's own condition, such as one spanning an
  association two different pane models both reach through. Nothing
  proposes that today.
