---
Date: 2026-09-11
Status: Accepted
Triggers:
  - adding a feature or configuration option to Janela
  - a design decision that touches a specific host application's domain or business logic
  - reviewing a contribution (human or agent-authored)
  - deciding how much flexibility/configurability a new API surface should expose
Topics: vision, scope, forkability, open-source, host-decoupling
---

# ADR 001: Built to Be Forked

## Context

Janela is a standalone open-source Rails gem: business-intelligence-
style dashboards and cross-filtering on ActiveRecord models. It is
being built and open-sourced deliberately, with the aspiration of
presenting it to the wider Rails community.

Commercial BI dashboard tools' actual surface area is mostly enterprise
packaging. The load-bearing 5%, declarative measures and dimensions
over a data model plus cross-filtering, is the real gap in the Rails BI
ecosystem. Every other feature a BI tool "should" have (drag-drop
designer, NL query, RLS subsystem, embedding SDK, etc.) is either
bloat or something Rails/Pundit/ActiveJob already own better.

Separately, DHH's framing in his September 2026 Lex Fridman interview
(#501, "Future of Programming, AI, Agentic Engineering, Vibe Coding &
Linux", https://lexfridman.com/dhh-2-transcript/) gave language to an
approach already implicit in the scope decision: agents make it
economically viable for a consumer to fork a small tool and keep only
the 5% they need, rather than adopt a large configurable one wholesale.
He also argued that overly prescriptive project instructions actively
damage agent output. Describe the problem, not the solution.

## Decision

Janela is designed to be forked, not just configured.

1. **Ship only the load-bearing 5%.** Measures/dimensions as a thin
   Ruby DSL over Ransack (not a new query language), cross-filtering
   via a Stimulus controller + Turbo Frames (not a JS framework).
   Everything else stays out of scope.
2. **Prefer one obvious way to do a thing over configurable
   flexibility.** Every added config flag is a fork someone didn't
   need to make. Default to fewer knobs, not more.
3. **Stay fully decoupled from any host application.** No
   application-specific code, model names, table shapes, or business
   logic in this repo, ever. Host applications depend on Janela;
   Janela never depends on a host application.
4. **Document decisions as ADRs in this repo**, so a forker
   understands *why* a piece exists before they rip it out or
   replace it, not just what it does.
5. **Treat agent-authored contributions the same as human ones.**
   Reviewed on the merits of the diff, not the source.
6. **Keep project instructions (CLAUDE.md) minimal and intent-focused**
   rather than prescriptive, consistent with the reasoning above.

## Consequences

- Feature requests that only make sense as a config flag for one
  user's edge case should default to "fork it" rather than "add a
  flag." This will read as less accommodating than a typical OSS
  project and is intentional.
- The codebase must stay small and legible enough that forking a
  chunk is realistic. This is a constant pressure against adding
  abstractions, even useful-seeming ones.
- Any specific host application's needs get solved in that
  application's own codebase against Janela's public API, never by
  special-casing Janela itself.
- Future scope decisions (what's in the 5%, what isn't) should cite
  this ADR rather than re-litigate the philosophy each time.
- The exclusion of a report designer was partly superseded by ADR 012:
  composition became data, because this ADR assumed the developer
  authored dashboards and the author is the analyst. The reasoning
  still holds for the query vocabulary, which stays in code.
