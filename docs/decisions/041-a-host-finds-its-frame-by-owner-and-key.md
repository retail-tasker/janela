---
Date: 2026-09-24
Status: Accepted
Related: ADR 012, ADR 013, ADR 014, ADR 019, ADR 040
Triggers:
  - giving a record of the host's its own frame
  - finding a frame from code without storing its id
  - an owner that has more than one frame
  - adding a slug, a handle or any second identifier to a frame
Topics: frames, persistence, naming, host-integration
---

# ADR 041: A Host Finds Its Frame by Owner and Key

## Context

A host that shows a frame on one of its own pages has to find that
frame from code. ADR 012 made frames rows an analyst edits, and ADR 040
made one frame usable across many records, so the host needs a way to
say "the frame for this" without a deploy creating it and without
remembering an id.

The owner looked like the answer. It is a nullable polymorphic
reference that Janela never reads (ADR 014, ADR 019), so a host can
point it at the record the frame is for, and
`Janela::Frame.find_or_create_by!(owner: queue)` is a frame's `dom_id`:
two columns, nothing added to the host's schema.

It holds for exactly one frame per owner, and owners rarely have one. A
tenant owns every frame an analyst makes from the engine's New button,
through `janela_frame_owner`, and a host wants frames of its own for
particular pages on top of those. `find_by(owner: account)` then returns
whichever row the database gives first. On a real installation it
returned the wrong frame: the first the tenant had ever made, not the
one the page was for (#59).

### What was considered

**`name` as the key** was rejected. It is the analyst's to rename, so a
host looking a frame up by name loses it the day someone edits the
title.

**A column in the host's table** pointing at the frame was rejected as
the answer the owner was meant to save a host from. It needs a
migration on every table whose records want a frame, and a second one
for each extra frame per record.

**A slug**, which ADR 013 turned down, is not what is being asked for,
and the difference is the reason this is allowed. ADR 013 rejected a
slug as a way to *address* a frame: in a URL a person reads, derived
from the name, needing uniqueness rules, reserved words and regeneration
on rename, and a second lookup path to keep working. What a host needs
is none of those. It is an identifier the host writes in its own code,
never in a URL, never derived from the name, never shown to an analyst,
and never changed once set.

**Janela choosing the frame for a record**, a registry mapping host
classes to frames, was rejected as configuration for something one line
of the host's code already says.

## Decision

**A frame may carry a `key` the host sets. A frame is found by its
owner and its key together, and each owner has at most one frame per
key.**

```ruby
Janela::Frame.for(account, :overview)         # the tenant's overview
Janela::Frame.for(queue, :analytics)          # this queue's frame
Janela::Frame.for(queue, :analytics) { |frame| frame.name = "#{queue.name} analytics" }
```

`for` finds the frame with that owner and key, or creates it. The block
runs only when it creates one, to set what the host wants a new frame to
start as; a new frame is named after its key unless the block says
otherwise. The owner may be `nil` for a host with one tenant.

**The key is the host's and nobody else's.** Janela reads it only in
`for`. It is not in any route and not in the engine's forms, so an
analyst can rename, regrid and recompose a keyed frame without being
able to detach it from the page that finds it. A frame without a key,
which is every frame an analyst makes, is unchanged.

**Uniqueness is per owner, in the database.** A unique index on owner
and key, so two requests creating the same frame at once end with one
row, and `for` retries the find when the insert loses that race. Frames
with no key are not constrained by it.

`key` is a short lowercase string matching `/\A[a-z0-9_]+\z/`, the
shape of the symbols a host will pass, so `:analytics` and `"analytics"`
are the same key and nothing that looks like a URL or a name gets in.

## Consequences

- A host gives any record any number of frames with no column of its
  own: owner and key are the `dom_id`, and the key is the suffix
  `dom_id(queue, :analytics)` would carry.
- `janela_frames` gains `key` and a unique index, so a migration and an
  `UPGRADING.md` entry (ADR 015). Existing frames keep a nil key.
- The owner now does two jobs for a host that uses `for`: tenancy for
  the policy scope, and which record a frame belongs to. ADR 019 said
  Janela never reads the owner; `for` queries by it, and only there. A
  host whose owner is a record rather than its tenant has to make its
  policy scope see frames owned by its own records, which the
  multi-tenancy guide shows.
- A frame deleted from the engine's pages is created again, empty, the
  next time its page is visited. That is the right answer for a frame a
  page depends on, and it is worth a line in the README so it is not a
  surprise.
- What would change this decision: a host needing to find a frame by
  something that is not stable in its own code. That is the addressing
  problem ADR 013 decided, and it would be decided there again.
