---
Date: 2026-09-21
Status: Accepted
Related: ADR 001, ADR 002, ADR 009, ADR 014, ADR 019, ADR 021, ADR 032, ADR 033
Triggers:
  - scheduling a snapshot, or changing what Janela::SnapshotJob takes
  - choosing a default for anything that decides what may be read outside a request
  - a snapshot whose numbers disagree with the page it was published from
  - adding a setting so a host can replace something the gem ships
  - wondering whether the shipped snapshot job should exist at all
Topics: snapshots, tenancy, authorisation, activejob, host-integration, security, releases
---

# ADR 034: Janela Will Not Freeze a Scope the Host Has Not Named

## Context

`Janela::SnapshotJob` calls `Snapshot.take` with no `on:`, so every pane
it freezes reads the model's default scope. ADR 009 decided that
deliberately and documented it: a relation cannot be serialised into a
job, so "a tenanted host writes its own job around `Snapshot.take` and
passes `on:`".

Whether that is wrong depends on something Janela cannot see.

**Tenancy at the model layer**, through acts_as_tenant, a `default_scope`,
a per tenant connection or a schema. `model.all` is already the tenant's
rows. The shipped job is correct and nothing here applies. This is what
the multi tenancy guide's own example means when it writes
`else model.all # acts_as_tenant has already scoped your own models`.

**Tenancy at the policy layer**, through Pundit or CanCanCan. `model.all`
is every row, and the scope the host wrote never runs.

So this is not the flat bug the issue title says. It is a default that is
right for one common architecture and silently wrong for another, chosen
by the library where ADR 032 would have it stated by the host.

### Measured

The demo does not scope `Order` by tenant: its `policy_scope` filters
Janela's own owned records and answers `model.all` for everything else,
which makes it a model layer host for its own data. The measurement below
was taken with that one method narrowed to what a policy layer host
writes, `when "Order" then model.where(customer: Current.tenant)`, and
nothing else changed.

```
live pane, signed in as one tenant:          $150.00
snapshot the shipped job froze for them:      375.0
that snapshot's owner column:                 that tenant
what they are then served from the snapshot: $375.00, answered 200
```

The same application, at the same instant, shows one number on the page
and publishes another from the row it labelled as theirs. Nothing errors
and nothing in the log says so. ADR 032 called a pane that lies the worst
thing this library can do, and this is that pane with a URL and a
lifetime.

### Why it is worth a decision rather than a patch

**It persists, and it publishes.** A live unscoped read is wrong once, on
a screen, to somebody already authenticated. A snapshot freezes the
number into a row and serves it at an address. ADR 009 names the
motivating case as "an external audience with no accounts", so the
failure mode is frozen cross tenant data published to people outside the
application altogether.

**ADR 033 made the promise louder.** Giving `janela_snapshots` an owner
invites a host to read the row as "this snapshot belongs to this tenant".
The row now says so. Its contents do not have to agree, and ADR 033 said
in as many words that adding the column sharpens this rather than
softening it.

### What a fix has to get past

A relation cannot be serialised into a job. That constraint produced the
current behaviour and has not moved.

**Require `on:` on `Taking#pane`.** Makes the guess impossible, and
supersedes ADR 009's default for every caller, including the console and
rake callers for whom it was always right. ADR 032 explicitly left `on:`
alone on the grounds that it is a call a maintainer writes in their own
Ruby, where nothing is being decided on their behalf.

**A serialisable way to name a scope**, such as
`{ model: "orders", scope: "for_tenant" }`. Rejected twice over: it is a
query language in miniature, which ADR 001 and ADR 002 both push against,
and it is arbitrary class method invocation from queue arguments, so
whoever can enqueue a job can call anything.

**Derive the scope from the owner ADR 033 added.** Janela would have to
know how a host's models relate to a tenant, which means interpreting the
owner, which ADR 014 and ADR 033 both forbid.

**Detect which kind of host this is.** The obvious idea, and ADR 032 is
what kills it. After ADR 032 every host defines `policy_scope`, and a
model layer host and a single tenant host both define it as `model.all`,
so responding to it distinguishes nothing. There is no controller
instance in a job to ask in any case, and no current tenant for it to
answer about.

**A setting naming the host's own job**, `Janela.snapshot_job =
"TenantSnapshotJob"`. Rejected because it has nothing to indirect.
Verified by reading the engine: nothing in `app/` or `lib/` enqueues
`SnapshotJob`, there is no publish action and no create route, and ADR
009 decided there would not be. The host's own scheduler is the only
caller and it already names a class, so the setting would be read by
nobody. It is the shape to reach for on the day Janela becomes the
caller, which ADR 033 already named as the thing that would reopen all of
this, and until then it fails the test ADR 021 and ADR 023 set for
whether a setting has earned itself.

**Remove `SnapshotJob`.** Not a straw man. ADR 009's own consequences say
"the shipped job is deliberately naive. If most hosts turn out to write
their own, the job should be removed rather than grown", and the
documentation has been sending tenanted hosts to write their own since
the day it shipped. It loses to two things. The evidence ADR 009 asked
for does not exist: there is one demo, not a population of hosts. And
removal costs model layer and single tenant hosts a real convenience to
solve a problem neither of them has.

**A doctor check alone.** Rejected for ADR 032's reason and one of its
own. It is advisory, so it speaks at setup time and cannot stop a job.
And it cannot tell the two architectures apart any better than the
library can, so it would either stay silent or cry wolf at every host,
which is the false alarm ADR 021 exists to prevent.

## Decision

**The snapshot job asks one question, `scope_for(model)`, and refuses to
answer it on the host's behalf.**

Everything above is one question wearing two costumes: what rows does
this pane freeze? It becomes one method on the job, and the two
architectures answer it in the two ways each can answer honestly.

**A model layer or single tenant host answers in a symbol.** The shipped
`scope_for` reads a `scope:` argument and has no default:

```ruby
Janela::SnapshotJob.perform_later(name: "September 2026", owner: account,
                                  scope: :model_default,
                                  panes: [ { "model" => "orders", "measure" => "revenue" } ])
```

`:model_default` says each pane is taken over its model's default scope,
and that this is the host's claim rather than Janela's guess. It is the
same move as `private def policy_scope(model) = model.all`: not
ceremony, a sentence somebody should have to write rather than inherit.
Absent, `scope_for` raises `Janela::Unscoped`, the same class and the
same word as ADR 032, because it is the same refusal in the other half
of the library. A value Janela does not know raises `ArgumentError`,
plainly, because a job's `perform` is a method call and not a request.

**A policy layer host answers in Ruby, by subclassing.** A relation
cannot cross the queue, but a class name can, and the host's scheduler
already names one:

```ruby
class TenantSnapshotJob < Janela::SnapshotJob
  private def scope_for(model) = model.where(account: owner)
end
```

They schedule that instead, and pass no `scope:`, because the method that
reads it is the one they replaced. `Janela::SnapshotJob` is a documented
base class rather than a leaf, and the serialisable `panes:` list, which
is the only genuinely reusable part of it and the part a host would
otherwise copy, keeps working. `perform` records what it was told and
exposes `owner`, `name` and `filters` as private readers, so a subclass
never has to override `perform` or reach into ActiveJob's `arguments`.

**This is a hook, and ADR 032 is why it is allowed to be one.** A
`scope_for` whose unanswered case returns `model.all` is exactly the
shape ADR 032 removed, and was rejected on that ground while the keyword
was a separate idea. Folding the two together inverts it: the default is
not the widest scope, it is a refusal. A host who has never heard of
`scope_for` does not get somebody else's numbers, they get an exception
naming both ways to answer.

**One question, so one place to answer it.** A symbol and a subclass are
not two competing APIs in ADR 001's sense. They are the same method,
answered by a caller who has nothing to add and by a caller who does.

**`Snapshot.take` and `Taking#pane` are untouched.** `on:` keeps
defaulting to `model.all`. ADR 032 drew that seam and it holds: the line
is between what Janela chooses inside its own code and what a host asks
for directly, and `take` is the host's own Ruby.

**No new doctor check.** A check earns itself by catching something quiet
(ADR 021), and after this there is nothing quiet left to catch: the job
either was answered or it raises. That is the opposite of the
`snapshots-nobody-will-see` case, where the failure was a row that simply
sat there.

**ADR 009 is narrowed, not superseded.** Everything it decided about what
a snapshot stores, how a stored pane is addressed and what static mode is
stands. Two sentences change. "The shipped job uses each model's default
scope" becomes "when told to", and "removed rather than grown" is
answered: it grows by one overridable method, which is how Rails ships a
default a host can replace.

## Consequences

- A policy layer host's instruction stops being "write your own job" and
  becomes "override one method", which is a sentence the multi tenancy
  guide can end its rough edge section with instead of a link to an
  issue.
- **Breaking, by one keyword**, so it goes in a minor release with an
  `UPGRADING.md` section and a `post_install_message` (ADR 015).
- **A job already on the queue at upgrade time was serialised without
  `scope:` and will raise when it performs.** A deployment hazard rather
  than a code change, invisible from the diff, and it belongs in the
  upgrade note beside the keyword: drain or re-enqueue before deploying,
  or expect the retries.
- **`SnapshotJob`'s insides become public surface.** `scope_for` and the
  readers beside it are a host's to override, so changing the shape of
  the `panes:` loop is a breaking change from here on, where today it is
  an internal detail. That is the real price of a base class over a leaf,
  and it is paid knowingly: the surface is one method and three readers,
  which is small enough to keep legible and small enough to fork past.
- The job stays naive on purpose. It does not become the place where
  scoping is solved. It becomes the place where the host says who is
  solving it.
- The guide's "what is still rough" section and the README's paragraph on
  the job both change in the same commit that lands the code.
- A host who writes `scope: :model_default` without reading what it means
  is no better off than before. True of ADR 032's one line too. The claim
  is not that a keyword teaches, it is that a library should not make
  this particular claim on a host's behalf.
- What would change this decision: Janela growing a caller of its own, a
  publish button or a scheduled frame, at which point the class to
  enqueue is Janela's question rather than the scheduler's and a setting
  earns itself for the first time. ADR 033 named that same event as the
  one that would reopen how a snapshot learns its owner, so the two
  should be read together when it happens.
