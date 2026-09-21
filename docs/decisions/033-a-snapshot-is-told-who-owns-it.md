---
Date: 2026-09-21
Status: Accepted
Related: ADR 002, ADR 009, ADR 014, ADR 019, ADR 032
Triggers:
  - adding an owner or a tenancy column to anything the engine stores
  - creating a record outside a request, in a job, a task or a console
  - scheduling a snapshot, or writing a job around Snapshot.take
  - a snapshot the wrong audience can read
  - extending ADR 019's controller hook to something new
Topics: snapshots, tenancy, authorisation, persistence, activejob, host-integration
---

# ADR 033: A Snapshot Is Told Who Owns It, Because There Is No Request to Ask

## Context

`janela_snapshots` holds a name, an instant, the filters it was taken
under and the results. It has no owner column, so
`policy_scope(Janela::Snapshot)` has nothing to filter on. ADR 014 gave
a frame a nullable polymorphic owner for exactly this reason and said
Janela never interprets it. A snapshot never got the same.

The guide calls this the rough edge and offers three workarounds: keep
snapshots to one tenant, add a column of your own, or encode the tenant
in the filters and scope on the name. The demo does the first, crudely
and on purpose. None of them are a column a policy can filter on.

Measured against the demo's fixtures before deciding anything:

```
every order:                       375.0
one tenant's orders:               150.0
what Janela::SnapshotJob stored:   375.0
what take with an explicit on:     150.0
owner column on janela_snapshots:  none
```

Two separate problems sit in those five lines, and only the first is
this ADR's.

**A snapshot cannot be owned.** There is nowhere to put the answer, so a
multi tenant host cannot scope reads of one.

**Janela's own job chooses a scope.** `SnapshotJob` calls `take` with no
`on:`, which ADR 009 decided deliberately, because a job cannot receive
a relation. Whether that is wrong depends on where a host keeps its
tenancy: at the model layer, through acts_as_tenant or a default scope,
`model.all` is already the tenant's rows and the job is correct, which
is what the guide's own example means by "acts_as_tenant has already
scoped your own models". At the policy layer, through Pundit or
CanCanCan, it is every row and the host's scope never runs. Janela
cannot tell which it is in, so what it has is a default chosen by the
library where ADR 032 would have it stated by the host. Not solved
here: it is a different question with a different shape, and folding it
in would make this one about two things. Filed as #47 so it cannot be
lost.

The interesting part of the first problem is where the answer comes
from. ADR 019 settled that for a frame by asking the host's controller
for `janela_frame_owner`, and generalised it into a precedent. It does
not reach here. A frame is created in a request, by an analyst using
the engine's own form, so there is a controller to ask and a
`Current.tenant` to ask it about. A snapshot is never created in a
request: there is no create route, no controller action and no form,
only `Snapshot.take` called from a job, a rake task, a console or a
host's own code. Verified rather than assumed, by reading every call
site in the repository.

So the options were not "which hook" but "what does a method called
outside a request know".

**A controller hook anyway**, with `Snapshot.take` reaching for
`Current.something`. Rejected: it would work in a console and quietly
return nil in the job that is the whole point of the feature, which is
the silent-failure shape ADR 019 was written to avoid in the first
place.

**A setting**, `Janela.snapshot_owner = -> { ... }`. Rejected on ADR
019's own reasoning, which found that a judgement needing the current
tenant cannot live in a setting, and on ADR 001, since it is a second
way to answer a question an argument already answers.

**Inferring it from the panes' relations.** Rejected as impossible
rather than unwise: a relation does not name a tenant, and reading one
to guess would be Janela interpreting an owner, which ADR 014 forbids.

## Decision

**A snapshot's owner is an argument to `Snapshot.take`, because the
caller is the only thing that knows it.**

```ruby
Janela::Snapshot.take(name: "September 2026", owner: Current.account) do |take|
  take.pane Order, :revenue, on: policy_scope(Order)
end
```

`janela_snapshots` gains nullable polymorphic `owner_type` and
`owner_id`, the same shape as a frame's, through the usual
`rails janela:install:migrations`. Janela assigns what it is handed and
reads nothing from it. Scoping stays entirely the host's policy, exactly
as ADR 014 said of a frame.

**`SnapshotJob` takes an `owner:` too.** ActiveJob serialises an
ActiveRecord object through its GlobalID, so unlike a relation an owner
crosses the queue boundary without anything new being invented.

**The owner is optional.** ADR 032 narrowed ADR 019's
silence-as-an-answer rule to permit it only where the silent default is
the narrow one, and named a nil owner as the example. A snapshot nobody
owns is invisible to a policy that filters on owner, which is the safe
direction to fail, and correct for a single tenant application where
nothing is filtering on it.

**This ADR does not extend ADR 019, it bounds it.** The rule is now
legible: the engine asks the host's controller when the engine is the
thing doing the creating inside a request, and takes an argument when
the host is. A future record written by Janela should be read against
which of those two it is, rather than reaching for the controller hook
because a frame does.

## Consequences

- A multi tenant host can scope snapshots with the same policy it
  already writes for frames, and the guide loses its rough edge.
- A migration a host must run, so it goes in `UPGRADING.md` with the
  install task and the fact that existing snapshots keep a nil owner
  (ADR 015). Nothing breaks for a host that ignores it.
- `Snapshot.take`'s signature grows one keyword with a default, so every
  existing call keeps working unchanged.
- **The shipped `SnapshotJob` still picks each model's default scope.**
  Right for a host whose tenancy is in the model layer, silently wrong
  for one whose tenancy is in its policies. Adding an owner sharpens
  that rather than softening it: the snapshot is now scopable, so its
  contents are the only unscoped thing left, and a host may reasonably
  read the new column as a promise the numbers inside do not keep. This
  wants its own decision and has one, #47; until it is settled the guide
  has to keep saying plainly that a policy scoped host writes its own
  job.
- Janela reads nothing from the owner, so a host that assigns one and
  writes no policy has changed nothing. That is the frame's trap again,
  and `frames_nobody_will_own` is the doctor check that catches the
  frame version. The snapshot version is not the same shape, because the
  caller assigns the owner in its own Ruby rather than the engine doing
  it silently, so it is a thinner case for a check. Worth revisiting if
  it bites.
- What would change this decision: a snapshot being created inside a
  request, through an engine form the way a frame is. That would put a
  controller back in the picture and make ADR 019's hook the consistent
  answer, and this ADR should be read again rather than worked around.
