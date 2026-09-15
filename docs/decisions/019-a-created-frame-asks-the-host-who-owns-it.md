---
Date: 2026-09-16
Status: Accepted
Related: ADR 002, ADR 004, ADR 012, ADR 014
Triggers:
  - creating a frame or any other record on a host's behalf
  - adding a configuration setting to Janela
  - a host needing to influence what the engine writes
  - a record being invisible to the scope that was meant to find it
Topics: authorisation, tenancy, persistence, host-integration, configuration
---

# ADR 019: A Created Frame Asks the Host Who Owns It

## Context

ADR 014 gave a frame a nullable polymorphic owner purely so a host's
Pundit scope has a column to filter on, and said Janela never
interprets it. That was right while frames were only created in a
console or a seed, where whoever created one could set it.

Build 4 lets an analyst create a frame through the engine's own form,
and the gap becomes a fault: Janela writes the row, so Janela decides
the owner, and it has nothing to decide with. A frame saved with no
owner is hidden by the very scope meant to find it, so the analyst
creates a dashboard and it disappears. That failure has already
happened twice in this project by other routes, once in a test and
once on the live demo, which is how confidently it can be predicted
here.

Three ways out. A configuration setting naming the owner. The engine
not creating frames at all, leaving it to each host, which defeats the
purpose of build 4 since the analyst is the person who cannot deploy.
Or asking the host at the moment of writing.

## Decision

**If the host's controller responds to `janela_frame_owner`, the
engine assigns its return value as the owner of a frame it creates.**

```ruby
class ApplicationController < ActionController::Base
  private
    def janela_frame_owner
      Current.account
    end
end
```

A host that defines nothing gets a nil owner, which is correct for a
single tenant application and is what the demo did before it had
tenancy at all.

This is the pattern `policy_scope` already established (ADR 004):
Janela asks the host's controller a question by duck typing, and takes
silence as an answer rather than requiring configuration. It keeps
Janela's settings at one, `parent_controller`, and it puts the
decision in the only place that can make it, inside a request where
the current user and tenant exist.

**Janela still never interprets the owner.** It assigns what it is
handed and reads nothing from it. Scoping remains entirely the host's
policy, exactly as ADR 014 said.

## Consequences

- An analyst can create a dashboard and see it, which is the whole
  point of build 4 and was impossible without this.
- A multi tenant host that forgets to define the method gets frames
  nobody can see. That is a quiet failure, so it is what the doctor
  task should notice: a host with a `policy_scope` that filters frames
  by owner, but no `janela_frame_owner`, is misconfigured. Worth
  adding to ADR 015's checks.
- Duck typing means a typo in the method name fails silently, which is
  the cost of not having configuration. The doctor check above is the
  mitigation.
- The same question will arrive for any other record Janela writes on
  a host's behalf. The answer is this pattern rather than a second
  setting, and this ADR is the precedent to cite.
