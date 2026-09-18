---
Date: 2026-09-18
Status: Accepted
Related: ADR 003, ADR 005, ADR 024, ADR 029
Supersedes: part of ADR 029
Triggers:
  - a host changing what a pane shows from JavaScript
  - writing to a turbo frame's src from anything but Turbo
  - adding a data attribute the frame controller reads
  - anything that would reintroduce reading intent out of the DOM
Topics: cross-filtering, panes, host-integration, javascript
---

# ADR 030: A Pane's src Belongs to Turbo, So a Host Talks to the Frame

## Context

ADR 029 gave a host a way to name a pane's frame so it could be
reconfigured in place, and said that "a frame that updates when its URL
changes is inside" the load-bearing core. Building it showed that is not
true, and the reason is a decision this project already made.

#33 established that a frame's `src` does not describe what that frame
is showing. Turbo writes `src` back onto a frame when a response lands,
including a late one for a request that has since been superseded. So
`janela--frame` keeps its own record of what was asked for and reverts
anything that does not match it:

> The request for what Janela last asked for wins, and any other is
> reverted. What was asked for is the only honest rule (#33).

That rule is right, and its consequence was not drawn at the time: if
the controller's own record is the only trustworthy statement of intent,
then `src` is no longer a channel a host can speak through. A host that
follows ADR 029, names a pane and writes `frame.src`, has its request
aborted and the frame put back, with no error and the old numbers still
on screen. That is the failure #42 was about, reached by following the
instructions written to fix #42.

There is no way to tell a host's `src` write from Turbo's. Any attempt,
a mutation observer, a flag, a heuristic on the attribute, re-infers
intent from the DOM, which is exactly what #33 removed because it
produced wrong numbers.

And the record is not one attribute. A pane also carries the base URL
the controller rebuilds from on the next click, so a host writing the
record by hand has to write two attributes in the right order, and
reapply the frame's current filters itself. Only the frame controller
knows those filters. The demo's own gallery control got that wrong:
reconfigure a pane while a filter is active and it refetches unfiltered
while every pane beside it stays filtered (#43).

## Decision

**A host changes what a pane shows by asking `janela--frame`, and never
by writing `src` or a data attribute.**

The controller already does this for itself when the frame's filters
change. Making that reachable is extraction rather than new surface: one
way to ask a pane to go to a different query, which records what was
asked, reapplies the frame's filters and sets `src` in the order the
guard expects.

Three things follow.

1. **The data attributes are private.** `janelaAsked` and `janelaSrc` are
   how the controller remembers, not an interface. A host that writes
   them is relying on something that may change.
2. **A reconfigured pane stays cross-filtered.** Reapplying the frame's
   current filters is part of repointing, not something a caller
   remembers, because forgetting it shows numbers for the wrong filter
   state and says nothing (ADR 003).
3. **`id:` is still necessary.** ADR 029 stands: without a stable frame
   id there is nothing to repoint. It is necessary and it was not
   sufficient, which is what this records.

## Consequences

ADR 029's claim that a frame updates when its URL changes is untrue as
written, and this supersedes that sentence rather than the decision. The
`id:` keyword and answering a frame request with the id Turbo sent are
both correct and stay.

A host reconfiguring a pane writes one call instead of three writes it
was never told about, and gets the filter behaviour right by default
rather than by knowing to. The demo's gallery control is the check, the
same way it was for ADR 029: it should get smaller again, and its filter
bug should disappear rather than be fixed separately.

The cost is one public method on a Stimulus controller, which is a
surface this project did not have before. It earns itself by removing a
class of silent wrongness rather than by adding capability, which is the
kind of addition ADR 001 leaves room for.
