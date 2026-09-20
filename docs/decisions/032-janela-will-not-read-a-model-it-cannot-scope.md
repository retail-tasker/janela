---
Date: 2026-09-20
Status: Accepted
Related: ADR 002, ADR 004, ADR 015, ADR 019, ADR 021, ADR 025
Triggers:
  - deciding what Janela should do when a host has configured nothing
  - adding a hook a host answers by defining a method
  - a dashboard showing rows the person reading it should not see
  - choosing a default for anything that decides what may be read
  - writing a doctor check about authorisation
Topics: authorisation, tenancy, host-integration, security, configuration, releases
---

# ADR 032: Janela Will Not Read a Model It Has Not Been Told How to Scope

## Context

`janela_scope` asks the host's controller for `policy_scope` and returns
`model.all` when there is none. ADR 002 called that authorisation being a
hook rather than a dependency, and ADR 004 recorded the gap in its
consequences as "tracked as a pre-public issue". The gem is public now,
so the condition that deferral was written under has passed.

What the fallback does, measured against the demo with `policy_scope`
removed from the host, which is the state an application using a
different authorisation library is already in:

```
a pane the scope hides, with policy_scope:    404
the same pane, without:                       200, showing $375.00
log lines mentioning scope, policy or janela: 0
```

The request that should be a refusal becomes a number belonging to
somebody else, with nothing on the page or in the log to say so. Janela
treats a confidently wrong number as its worst failure, and this is the
purest form of it: not a pane that errors, a pane that lies.

Two facts narrow who this actually hits, and both were wrong in the
issue as filed.

**A host using Pundit is not affected, even one missing a policy.**
Pundit's `policy_scope` resolves through `policy_scope!`, which raises
`NotDefinedError`. Verified in Pundit 2.5.2: `Authorization#policy_scope`
calls `pundit_policy_scope`, which calls `pundit.policy_scope!`. A
forgetful Pundit host gets an exception, which is the correct outcome
and needs nothing from us. The exposure is a host that defines no
`policy_scope` at all.

**The two copies of the fallback do not agree with each other.** The
controller copy asks `self`, which is the controller; the helper copy
asks the view, which cannot see a private controller method. A host
following this project's own multi-tenancy guide, which writes
`policy_scope` as a private method with no `helper_method`, is scoped on
the engine's pages and unscoped on a frame embedded in its own. That is
a bug rather than a decision and is tracked separately; this ADR assumes
it is fixed and that both paths ask the controller.

Four options were considered.

**Log loudly.** Breaks nothing, and a log line in an application that is
already noisy is close to the silence it replaces. It also leaves the
wrong number on the screen, which is the part that matters.

**A configured scope resolver**, `Janela.scope = ->(model, controller)`.
Rejected on ADR 019, which found that a decision needing the current
user and tenant belongs inside a request rather than in a setting, and
on ADR 001, because the host's controller already answers this question
and a second way to answer it is a second thing to understand.

**A doctor check alone.** Rejected as insufficient rather than wrong.
The guide currently instructs a single tenant host to define nothing, so
a check flagging that would contradict the documentation a reader just
followed, which is the false alarm ADR 021 exists to prevent. It is also
advisory: it speaks at setup time and cannot stop a request.

**Raise.** Chosen, below.

The tension is real. `model.all` is the correct relation for a single
tenant application, and most applications are single tenant, so raising
asks something of hosts that were never wrong. Two things settle it.
This project has met the same shape twice and chosen the same way both
times: ADR 002 raises where Ransack silently dropped a filter, and ADR
025 raises where any predicate silently ran. And "single tenant" is not
the same claim as "every visitor may total every row of every model on a
dashboard". Today that second claim is made by omission. It should be
made on purpose or not at all.

## Decision

**Janela raises `Janela::Unscoped` when it would otherwise read a model
the host has not told it how to scope.** The fallback to `model.all` is
removed from both the controller and the helper.

A host says what may be read by answering the question Janela already
asks, in the place it already asks it:

```ruby
class ApplicationController < ActionController::Base
  private
    def policy_scope(model) = model.all
end
```

That line is not ceremony. It is the assertion that every visitor who
can reach a dashboard may read every row behind it, which is a sentence
a maintainer should have to write rather than inherit.

No new setting. ADR 019's pattern stands: Janela asks the host's
controller by duck typing and never by configuration.

**It raises at request time, not at boot.** Resolving
`Janela.parent_controller` during initialisation is a trap this project
has already paid for, and a boot raise would break a console or a
migration for a host part way through upgrading.

**It is not rescued into a pane.** A missing scope is not a data
condition, and dressing it as the sentence a 404 shows would hide the
thing the host has to fix.

**The doctor gains `unscoped-reads`, at error severity.** Unlike the
`unauthenticated-endpoints` check, which hedges because authentication
cannot be determined by reading, this one is exact: the parent
controller either responds to `policy_scope` or it does not.

## Consequences

- A host that defines no scope stops getting numbers and starts getting
  an exception naming what to add. Loud, once, instead of quiet forever.
- Breaking, so it goes in a minor release with an `UPGRADING.md` section
  and a `post_install_message` (ADR 015). A host using Pundit, or one
  that followed the multi-tenancy guide, does nothing. A single tenant
  host writes one method.
- ADR 004's consequence recording this as a pre-public issue is
  superseded.
- **ADR 019 is narrowed rather than superseded.** It generalised taking
  silence as an answer into a precedent and cited `policy_scope` as the
  model for it. That precedent survives with a limit: silence is an
  acceptable answer when the silent default is the narrow one, as a nil
  owner is, and never when it is the widest one. A future hook that
  defaults to reading everything is this decision again, not ADR 019.
- ADR 002's `on:` parameter keeps defaulting to `model.all`. That is a
  call a maintainer writes in their own Ruby, where the scope is theirs
  to choose and nothing is being decided on their behalf. The seam is
  between what Janela chooses inside a request and what a host asks for
  directly.
- The multi-tenancy guide's "define nothing" section, its summary table
  and the README's description of the fallback all become wrong the
  moment this lands, and change in the same commit.
- Duck typing still means a typo in the method name reads as absence.
  Before this, that silently widened the scope; now it raises, so the
  doctor check is a convenience rather than the only defence.
- What would change this decision: evidence that the raise fires for
  hosts that had genuinely done nothing wrong and had no reasonable way
  to know, in numbers rather than anecdote. A permissive default is not
  coming back, but where the question is asked could.
