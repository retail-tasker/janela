---
Date: 2026-09-30
Status: Proposed
Related: ADR 003, ADR 009, ADR 025, ADR 029, ADR 030, ADR 032, ADR 034, ADR 037, ADR 039
Triggers:
  - a dashboard that should update on a timer, on a push, or when a record changes
  - a host reaching for Turbo Streams, ActionCable or a broadcast to update a pane
  - adding an action or an event to the frame controller
  - a request for a refresh interval, a polling option or a stream_from helper
  - reloading a pane's turbo frame from a host's own JavaScript
Topics: cross-filtering, frames, javascript, hotwire, performance, authorisation, public-api
---

# ADR 048: A Frame Can Be Told to Refresh, and Janela Never Decides When

## Context

The question: should a frame be able to refresh itself every few seconds,
or stream from something, so a dashboard on a wall stays current? Janela
has nothing for it. ADR 003 chose Turbo Frames for cross-filtering on the
ground that a dashboard needs no streams, sockets or client state, and the
roadmap lists a refresh-scheduling interface among the things that are not
coming, on the reasoning that a host already has a scheduler and snapshots
are an ActiveJob. That reasoning was about *snapshots*. Refreshing what a
reader is looking at, in their browser, is a different request and is not
answered by it.

Three things were established before deciding.

**Pushing rendered content cannot work, and would leak if it did.** A
pane's numbers depend on who is asking. `QueriesController#show` renders
through `janela_scope`, which calls the *request's own controller* for
`policy_scope` (ADR 032), and the reader's filters live in their browser as
`q[...]` (ADR 008). A Turbo Stream broadcast renders once, outside any
request, with no reader whose scope or filters exist, and sends the same
HTML to every subscriber. Where it rendered at all it would show one
person's scope to everyone else, which is the failure ADR 032 and ADR 034
exist to prevent. So the server can never usefully push a pane's content.

**What can be pushed is a nudge, and the refetch belongs to each browser.**
"Something changed" carries no data. Each browser then re-fetches its own
panes with its own filters, through the same scoped request it always made,
so a viewer only ever gets numbers they were entitled to.

**A host can already do the refetch, and it already behaves.** Measured in
a browser against the demo, with all nine panes of the orders dashboard
loaded and one value selected:

- Calling `reload()` on every pane, as a timer would, refetched each at the
  address Janela last asked for, with the filters. None of it was
  unfiltered.
- With a click and a timer tick landing in the same instant, so that every
  pane was reloaded while the click's own refetch was in flight, all seven
  text panes ended on the filtered numbers, matching the server's answer for
  each. The supersede rule in the frame controller (#33) already drops a
  request for an address that is no longer what was asked, so a tick cannot
  put stale numbers back. One run, not a proof, but the mechanism is the one
  #33 built for exactly this.
- Before the panes had scrolled into view, a reload of all nine made seven
  requests, consistent with a lazy pane that has not loaded not being
  fetched by a reload.

So the mechanism is not missing. What is missing is a name for it that a
host can rely on. ADR 030 says a host talks to the frame and does not write
a pane's `src`, and `reload()` on each frame is the host reaching past the
frame controller into Turbo, with no promise about what it does for a
pane that holds words and has no `src` (ADR 039), for a pane whose request
is already in flight, or for a snapshot pane that is never live (ADR 009).

### What was considered

**A `refresh_every:` option on a frame or a pane.** Rejected. Every tick is
one query per pane per viewer, so an interval is a decision about load, and
ADR 025 bounds what one query may ask for and says nothing about how often
a page asks. Somebody has to own that number, and it is the host, who knows
its database, its audience and whether the wall display is one browser or
two hundred. A setting would also put a polling interval where an analyst
can edit it, which ADR 016 keeps numbers out of. If the numbers are
expensive, snapshots are the answer, not a faster poll.

**A `stream_from` helper, or broadcasting the rendered pane.** Rejected for
the scope reason above. A helper that only sent the nudge would be a thin
wrapper over `turbo_stream_from` and a custom action, which the host writes
in a line, and Janela would then own a transport it has no view of.

**Doing nothing, and telling hosts to call `reload()`.** Rejected, because
the unsupported parts above are exactly where it goes wrong quietly: a
content pane, a snapshot pane, a lazy pane forced to load early, or a pane
restarted for no reason while it is already fetching the newest thing.

## Decision

**The frame controller gains one action, `refresh`, which re-fetches the
panes that are live and loaded at what was last asked, and Janela provides
no timer, interval, transport or stream.**

```html
<button data-action="janela--frame#refresh">Refresh</button>
```

```js
// a timer the host owns, paused while the tab is hidden
setInterval(() => { if (!document.hidden) frame.dispatchEvent(new CustomEvent("janela--frame:refresh")) }, 3000)

// or a nudge from ActionCable, a Turbo Stream custom action, anything
```

It is also an event the frame listens for, `janela--frame:refresh`, wired
the way `repoint` is (ADR 030), so code outside the frame can ask without
holding a reference to the controller.

**What refresh does.** For each pane the frame controller manages, it
re-fetches the address last asked for, with the reader's filters and any
host-fixed `where` (ADR 040), through the same supersede rules a click uses.
It leaves alone:

- a pane with no live address: a pane that holds words or a host partial
  (ADR 039), and a snapshot pane (ADR 009);
- a pane that has not loaded yet, so a lazy pane still loads when it scrolls
  into view and a refresh does not pull the whole page forward;
- a pane whose request for the current address is already in flight, since
  it is about to show the newest thing.

**It is a nudge in the other direction too.** Refresh reads no data and
sends none, so it cannot show anyone anything they could not already see:
every fetch it causes is the ordinary scoped request (ADR 032).

**Where the timer and the transport live.** In the host's code, documented
as recipes with the cost stated: a tick is one query per pane per viewer,
so pause it while the tab is hidden and choose an interval the database can
carry. The README gains a short section, and `docs/composing.md` may carry
the longer recipes.

## Consequences

- A wall dashboard is a `setInterval` and one line, a "refresh" button is
  one attribute, and a push from a background job is an ActionCable channel
  and one line of JavaScript. Janela owns none of the three, and none of
  them can leak across readers.
- **Additive, so it does not need to land before 1.0.** A new action and a
  new event are additions to the frame controller's surface, which ADR 037
  freezes for changes and not for additions. That is why this is filed for
  after 1.0. The name is worth choosing well (`refresh` and
  `janela--frame:refresh` sit beside `clear` and `repoint`).
- The supersede rule (#33) becomes load bearing for something new: a tick
  arriving during a click's fetch. Build must test that deliberately, by
  holding a response in flight, rather than rely on the single run above.
- A host that polls carries the load of it. This ADR states that; it does
  not bound it.
- Nothing changes for a host that does not use it.
- What would change this decision: a measured case where a host cannot
  reasonably own the timer, which would be an argument for a helper that
  only wires a host-supplied interval, never one that chooses it; or a
  way to broadcast that renders per reader, which Turbo does not offer.
