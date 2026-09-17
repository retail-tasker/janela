---
Date: 2026-09-15
Status: Accepted
Related: ADR 001, ADR 005, ADR 009, ADR 012, ADR 014
Superseded in part by: ADR 012
Not implemented: the host skill, the install task and the agent definition
Triggers:
  - writing or changing guidance for AI agents about using Janela
  - proposing that Janela ship an agent, a skill or an MCP surface to hosts
  - adding generators or introspection tasks
  - changing the public API in a way the guidance describes
  - deciding what a host application receives on install beyond the code
Topics: ai, agents, jan, skills, documentation, install, dx, scope
---

# ADR 010: Agent Guidance Ships, the Agent Waits

## Context

ADR 001 decided the reasoning behind Janela ships inside the gem, as
ADRs, so a developer or their agent understands why a piece exists
before changing it. That covers the *why*. Nothing covers the *how*,
and the first real installation showed the gap has a price: three
traps bit within an hour, each a one line fix found only by debugging.
Ransack's allowlist is per class, so a `through:` dimension needs the
associated model to allow the attribute. A host that bundles with
esbuild has no importmap, so none of Janela's JavaScript loads and
nothing cross filters while everything looks right. Janela's
controllers are exactly as authenticated as the host's
`ApplicationController`, which in a host that authenticates per
controller means not at all.

None of that is derivable from reading the code, which is precisely
the test ADR 001 sets for what belongs in the repository as prose.

A second, larger idea came up alongside it: that Janela ship an agent
of its own, named Jan, so installing the gem gives a host a briefed
colleague rather than a briefing. Open source has always shipped code
and documentation; it could now ship the person who knows how to use
them. It is a genuinely novel idea and nobody is doing it.

The two are not the same commitment, and this ADR separates them.

## Decision

**A skill ships with the gem and installs into the host.**
`docs/skills/janela/SKILL.md` lives in the gem's `docs/` tree beside
the ADRs. `rails janela:install:skill` copies it to the host's
`.claude/skills/janela/` and prints the one line to add to an
`AGENTS.md` or `CLAUDE.md` for tools that read those instead. Janela
never edits a host's instruction files itself.

The skill is knowledge, not instructions to a particular agent, which
is why it survives whatever agent formats come and go.

**What the skill covers, in this order:**

1. The dashboard shape that works, and why: a row of single value
   panes, a time series, then categorical breakdowns.
2. Choosing measures and dimensions. Name them for what they mean and
   alias through dimensions. Keep categories low cardinality or pass
   `limit`. Declare time dimensions with the granularity people
   actually ask about. A dimension declaration is a promise that
   filtering on it is allowed.
3. The naming table from ADR 005, so an analyst's sentence becomes a
   pane URL and back.
4. When to take a snapshot, and that a snapshot holds results, not
   HTML.
5. The three traps above, each with its one line fix.
6. What Janela deliberately does not do, so an agent does not build
   natural language query, row level security or a scheduler into the
   host by accident. Composition is no longer on that list: ADR 012
   made frames and panes records and ADR 014 sequenced the editing
   surfaces, so the skill points an agent at those rather than telling
   it to compose dashboards in ERB.

**The skill describes the README's API and nothing else.** One API,
one set of names. If the skill needs to say something the README does
not, the README is incomplete and gets fixed first. No agent only
vocabulary.

**The demo application is the worked example.** `test/dummy` shows
every construct on realistic data, deployed and clickable. The skill
points at specific files rather than duplicating them.

**Every code sample is executable.** Each sample in the skill and in
`docs/guides/` is lifted from a file the test suite exercises, or is
run by a test. A sample that cannot be run is written as a sentence,
not a code block. This is the mechanism that stops the guidance
drifting from the code.

**Jan is not shipped to hosts yet.** An agent definition is added to
this repository only, as the project's own collaborator, and is not
copied into host applications by any install task. Three reasons:

- Its method, read the models, declare dimensions, compose in the
  standard shape, wire the install, verify in a browser, is what a
  capable agent with the skill loaded already does. The marginal value
  over the skill is a name to invoke and a guarantee the skill is
  loaded. That is convenience, not capability, and convenience is not
  worth a public surface.
- Agent definition formats are unsettled. The skill's content is prose
  about dashboards and survives any format; an agent definition is the
  part most likely to be stale in six months.
- A gem that writes a named agent into a host arrives with opinions
  about how that team works, not only about what its code does. That
  cuts against the posture in ADR 001, where the invitation is to read
  the code and fork it.

**What would change this.** Ship Jan to hosts when either is true:

- Jan, used on this repository, demonstrably does something a skill
  loaded agent does not. Name the thing in the ADR that supersedes
  this one.
- An MCP surface exists. An agent that can query dashboards and take
  snapshots through tools has a job no skill can do, and at that point
  a named agent stops being a wrapper and becomes a user.

## Consequences

- A host that installs Janela and runs one task gets an opinionated,
  current briefing, including the three traps that cost real debugging
  time. That is the concrete value of this layer and it lands now.
- `docs/guides/` becomes a real directory shipping in the gem, so a
  forker receives reasoning, rules and how to together.
- Jan exists but only here. The agent that helps build the gem is the
  agent that would one day help hosts, so drift between what Jan says
  and what the code does surfaces in this repository first. That is
  the trial period, and it is free.
- Saying no to shipping Jan is recorded rather than remembered, with
  the conditions that would reverse it. A future proposal cites this
  ADR instead of relitigating the idea.
- Introspection (`rails janela:describe Model`), generators and MCP
  are each one ADR away. Each must be a wrapper over the existing API,
  for the same reason the skill must describe only one.
