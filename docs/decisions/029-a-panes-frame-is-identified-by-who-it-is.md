---
Date: 2026-09-18
Status: Accepted
Related: ADR 003, ADR 005, ADR 012, ADR 014, ADR 024
Superseded in part by: ADR 030
Triggers:
  - changing how a pane's turbo frame is identified
  - adding a parameter to a pane URL
  - a host wanting a control over a pane's own settings
  - a frame that does not update when it should
Topics: cross-filtering, panes, urls, host-integration
---

# ADR 029: A Pane's Frame Is Identified by Who It Is, Not by What It Shows

## Context

Issue #42 found that pointing a pane's turbo frame at a URL differing only
in `limit`, `granularity` or `as` makes Turbo fetch the response and then
silently do nothing: no render, no `frame-missing`, no console error, the
frame left showing the old numbers forever. Measured in a browser, not
inferred.

The cause is that `Query.turbo_frame_id` builds the id out of the query
itself, renderer, granularity and limit included, so the response comes
back wearing a different id from the frame that asked for it. Turbo has
nothing to reconcile and gives up quietly.

**The project has already solved this once, in the half that does not have
the bug.** A pane that is a record uses `Pane#turbo_frame_id`, which is
`janela_pane_#{id}`, and the comment on it says exactly why:

> The DOM id is the row, not the query it runs: two rows in one frame may
> show the same measure by the same dimension, and a fingerprint of the
> query would give them the same turbo frame for Turbo to replace.

That is ADR 014's reasoning, and it is right. A record-backed pane can
change its renderer, its granularity and its limit all day and its frame
id never moves, because the id says who the pane is rather than what it
is currently showing.

The helper path has no row to point at, so it fingerprints the query
instead. The fingerprint is not arbitrary: without it, two `janela_pane`
calls for the same measure by the same dimension would collide, and one
would replace the other. So the fingerprint solves a real problem and
creates this one.

The reason this has not bitten the library itself is worth stating: a
click changes filters, and filters are deliberately not in the id, so
every navigation Janela performs keeps the id stable. It is only a host
reaching for the URL's other documented parameters that falls in, and
what it gets is stale numbers with no error, which is the worst failure
this library has (ADR 003).

## Decision

**`janela_pane` accepts an `id:`, and a pane given one is identified by
it rather than by a fingerprint of its query.**

1. The fingerprint stays the default. It is correct for the common case,
   a page of unlike panes with no controls over them, and it is what
   keeps two alike panes apart.
2. A host that wants to change a pane's settings in place names that
   frame itself. The id is then stable by construction, because it comes
   from the host rather than from the query, and Turbo reconciles
   normally. This is the same move ADR 012 made for a record-backed pane,
   made available to a pane that is not a record.
3. The response wears the id the frame asked for rather than one derived
   again from the query. This needs no new surface at all: Turbo already
   sends the requesting frame's id in the `Turbo-Frame` header, and
   turbo-rails exposes it as `turbo_frame_request_id`. So a pane rendered
   into a frame request answers to the frame that asked, and a pane
   rendered any other way keeps deriving its own id as it does now. The
   pane URL does not grow a parameter, which was the first thing this
   decision reached for and did not need.
4. The failure is documented rather than left to be discovered. A host
   that changes a pane's URL without naming its frame gets the silent
   staleness described above, and the README says so where it describes
   the pane URL's parameters.

## What this turns down

**Taking renderer, granularity and limit out of the fingerprint.** It
would fix #42 and reintroduce the collision ADR 014 avoided: the gallery
renders the same measure by the same dimension as a bar and as a line on
one page, and those two must not share a frame. The fingerprint is doing
real work.

**Leaving it to every host to fetch and swap the frame themselves**, which
is what the demo's gallery does today and what proved the diagnosis. It
works, and it asks each host to write the same Stimulus controller and to
know a thing about Turbo's id matching that nothing told them. ADR 001
says ship the load-bearing 5%: a frame that updates when its URL changes
is inside that, and a host reimplementing frame reconciliation is not.
(Superseded in part by ADR 030: a frame does not update when its URL
changes, because `src` is not a channel a host can speak through. What is
inside the 5% is a pane that goes where it is asked to, which is the same
thing said correctly.)

## Consequences

`janela_pane` grows one optional keyword argument, and a host that never
passes it sees no change at all. The demo's gallery control becomes
smaller, since the frame can be navigated rather than swapped by hand,
and that is the check on whether this decision is right: if the control
does not get simpler, the decision was wrong.

Two alike panes given the same `id` by a host would collide, which the
fingerprint prevented automatically. That is the cost of letting a host
name things, it is the same cost a host already carries for every DOM id
it writes, and the doctor is the place to notice it if it turns out to
happen.
