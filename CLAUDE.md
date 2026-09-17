# Janela

Business-intelligence-style dashboards and cross-filtering, built as
first-class citizens on ActiveRecord models. A Rails gem, not a
bolt-on admin panel. The README covers what it does and how to use
it; `docs/decisions/` covers why it is shaped this way.

## Hard constraint: no host application in this repo

Janela is standalone open source. Host Rails applications consume it
as a dependency, never the reverse. No host-application-specific code,
model names, table shapes, or business logic in this repo, ever. If a
design only makes sense with one particular app's domain in mind, it
is out of scope here and belongs in that app's own codebase, calling
into Janela's public API instead.

## Why this file is short

DHH, on why he cut his own CLAUDE.md and system prompt by 80%: overly
prescriptive instructions actively damage agent output. Describe the
problem rather than the solution, the same way agile discovers
requirements.
(Source: [Lex Fridman podcast #501](https://lexfridman.com/dhh-2-transcript/),
"Future of Programming, AI, Agentic Engineering, Vibe Coding & Linux".)
This file states intent and hard constraints. It does not prescribe
implementation. That is what the ADRs and the code itself are for.

## Vision: built to be forked

Same DHH interview, the governing idea for this whole project:

> "What if we all just build our own 5%? What if I just took the
> functionality that I need and just did that?"

Janela ships the load-bearing 5%: declarative measures and dimensions
plus cross-filtering. ADR 001 covers why those two and not the rest of
a commercial BI tool's surface area. Everyone else's 5% will differ.
The project should stay small and legible enough that forking it and
ripping out or replacing a chunk is a normal, expected way to use it,
not a fallback for when the gem does not fit. Fewer abstractions,
fewer configuration layers, more code a competent Rails developer (or
their agent) can read start to finish in one sitting.

Practical implications:

- Prefer one obvious way to do a thing over configurable flexibility.
- Keep the measures and dimensions DSL a thin layer over Ransack
  rather than a new query language. Easy to understand, easy to fork
  past.
- Document decisions as ADRs in `docs/decisions/` so a forker can see
  why a piece exists, not just what it does, before changing it.
- Agent-authored contributions are welcome and reviewed the same as
  human ones, on the merits of the diff rather than the source.

## Where decisions and work live

Architecture and design decisions get an ADR in `docs/decisions/`,
referenced before building anything adjacent. Outstanding work is
tracked in GitHub Issues on this repo.

The project's own development skills live in `.claude/skills/` and ship
with the repository. The usual path through a piece of work is
`/jan-orient`, `/jan-whats-next`, `/jan-issue-investigate`, then
`/jan-adr` if a decision is needed, `/jan-issue-build`, `/jan-verify`
and `/jan-review`, with `/jan-release`, `/jan-retro` and `/jan-handoff`
around them. They describe how this project is worked on. Guidance for a
host using Janela is a separate thing, decided in ADR 010 and not built
yet.
