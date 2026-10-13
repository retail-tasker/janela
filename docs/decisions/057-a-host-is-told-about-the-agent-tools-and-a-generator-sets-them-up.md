---
Date: 2026-10-14
Status: Accepted
Related: ADR 010, ADR 015, ADR 032, ADR 035, ADR 053, ADR 056
Triggers:
  - adding an install step, a generator or a rake task that writes into a host
  - changing what janela:doctor prints when nothing is wrong
  - deciding how a host learns that a feature exists
  - registering Janela::Tools with an MCP library
  - an agent needs to change a frame's columns or gap
  - an agent needs to reach a dashboard on a deployed host
Topics: ai, agents, mcp, install, dx, generators, doctor, host-integration, discoverability
---

# ADR 057: A Host Is Told About the Agent Tools, and a Generator Sets Them Up

## Context

ADR 053 gave Janela agent tools and deliberately stopped short of helping a
host use them. It rejected a `janela:install:mcp` task because copied files
drift, rejected detecting a host's MCP setup because the signal does not
distinguish anything, and added no doctor check because construction already
raises. A host that wants the tools reads `docs/agents.md` and writes about
ten lines.

That left one thing unconsidered: **how a host learns the tools exist.** The
guide is a document the host has to go looking for, so a host that does not
know to look never finds out. The demo showed it. Its `/visits` dashboard was
arranged through `Janela::Tools` by an agent over stdio, using
`test/dummy/bin/janela-mcp`, and the maintainer's reaction to being told how it
was done was that he had assumed a setup tool already existed, and that anyone
using the library should not have to ask for one. Nothing in the install path,
the doctor's output or the README's install section mentions the tools at all.
The feature is real and, to a new host, invisible.

### Measured

Against the demo, 2026-10-14.

**A generator in the gem is found and ships.** A file at
`lib/generators/janela/mcp/mcp_generator.rb` is listed by
`bin/rails generate --help` under `Janela:` and runs as
`bin/rails generate janela:mcp`. The gemspec's `lib/**/*` glob already packages
it. Janela has no generators today, so this would be the first.

**A server file cannot borrow the host's `policy_scope`.** It is a controller
method, and a stdio server has no request. Called on a bare controller it does
not raise, which would be a safe failure. It answers a different question:

```
policy_scope(Janela::Frame) from inside a request:  owner is the first customer
policy_scope(Janela::Frame) with no request:        WHERE owner_id IS NULL
```

ADR 035 found the same shape for the doctor, where a real host's
`policy_scope` reaches for the session, which is nil outside a request. So the
scope has to be written into the server file by the host, who knows who an
agent acts for. `Janela::Tools.new` with no scope still raises `Janela::Unscoped`
(ADR 053), so a generated file that leaves the scope unwritten fails loudly
and does not read the wrong rows.

**The demo's server file is the first copy of the thing.** It is 25 lines, of
which three are the host's: who is asking, what the scope is, and which
environment it may run in. The rest is `docs/agents.md`'s adapter, unchanged.

### What was considered

**Keep ADR 053 as it is and improve the guide.** Rejected. The guide is not
the problem, finding it is. A better page nobody opens is the same failure.

**A doctor finding.** Rejected as a finding. ADR 035 says a check reads what
Janela does or says what it saw, and the doctor's contract is "what to fix".
The tools are optional, so their absence is not something to fix, and a
warning would be wrong for the host that has deliberately chosen not to use
them. It also could not be silenced without teaching hosts to silence the
doctor. See the decision for what the doctor says instead.

**A `post_install_message` for the tools.** Rejected as the main route. ADR 015
sets it only on a release a host must act on and removes it in the next, so it
reaches a host once, at the moment it is least interested. It is used for the
release that ships the generator and no other.

**Detect the host's MCP server and register into it.** Still rejected, for
ADR 053's reason: it edits a host's tooling on a signal that distinguishes
nothing.

**A generator that borrows the host's scope by calling `policy_scope`.**
Rejected on the measurement above. It would silently read the wrong rows.

**`mcp` as a dependency, added to the host's Gemfile by the generator.**
Rejected. The generator prints the line to add and never edits the Gemfile,
which keeps ADR 053's "Janela depends on no MCP library" and ADR 010's rule that
Janela edits nothing it did not create.

## Decision

**A host is told the agent tools exist in the places it already looks, and a
generator writes the server file the host then owns.**

```
bin/rails generate janela:mcp
```

It writes two things and edits nothing else:

- `bin/janela-mcp`, an executable stdio server built on the official Ruby
  SDK. It is `docs/agents.md`'s adapter with the host's three decisions left
  as plain code to fill in. The scope is a lambda that **raises
  `Janela::Unscoped` until the host replaces it**, so an unedited file reads
  nothing. It refuses to run outside development, with the guard in the file
  where the host can see it, because removing it is a decision about who can
  reach real data and should be made on purpose.
- An entry in `.mcp.json`, created if it is absent and merged if it is not, so
  Claude Code and any client that reads the same file find the server.

If the `mcp` gem is not in the bundle the generator says which line to add to
the Gemfile and does not add it. If `bin/janela-mcp` already exists it is left
alone and the generator says so.

**The file is the host's from the moment it is written.** This is the case
ADR 053 rejected, and it is accepted now for a reason that did not apply then:
the file is the adapter itself and nothing else. It calls `Janela::Tools.all`
and `Janela::Tools#call`, which are the public contract from 1.0, so there is
nothing for it to drift from except a change that would already be a major
release. The doctor does not grow a check for it.

**Discovery, in the order a new host meets it:**

1. **The README's install steps** gain one line after the doctor step: that
   agents can arrange dashboards, the command, and a link to `docs/agents.md`.
   It stays in the README permanently, since a host installing next year needs
   it as much as one installing today.
2. **`janela:doctor` prints a closing line, not a finding**, when
   `bin/janela-mcp` does not exist: `Optional: let an agent arrange
   dashboards. bin/rails generate janela:mcp (docs/agents.md).` It states what
   it saw, which is the absence of the file. It does not change the exit
   status, is not counted in "things to fix" and needs no silencing. It is
   printed on a clean run too, so the host that has nothing to fix still hears
   it, and a host that has generated the file stops hearing it.
3. **The gem's `post_install_message`** carries it once, on the release that
   ships the generator, and goes in the release after (ADR 015).
4. **The generator's own output** says what to fill in and how to start the
   server, so the first run ends with a working next step.

**An agent can change a frame's columns and gap.** ADR 053 gave agents no
frame-level tool because "a frame is found or made by the host". Arranging
`/visits` showed that a layout is not finished without them: the demo's frame
went from three columns to four and could only be changed from a console. One
tool is added, and only with `write: true`:

| Tool | Does |
| --- | --- |
| `update_frame` | Change a frame's `columns` and `gap`. Found through the host's scope like every other frame, and refused with the frame's own reason (`Columns is not included in the list`) when the value is not one Janela draws |

Its inputs are the frame's own attributes and nothing else, so a `name`, an
`owner` or a `key` is refused and not dropped, as a pane's are. A frame is
still found or made by the host: there is no `create_frame`, and a frame's
owner is the host's to say (ADR 033). This is a new tool, so it is a minor
release, and its name and schema join the contract at 1.0 with the rest.

**A deployed host's dashboard stays out of an agent's reach, and that is
named, not solved.** The generated server runs in development against a local
database, so a change made through it is not a change to a live site. Reaching
a deployed host needs an authenticated path that only the host can provide
(ADR 053: Janela serves no endpoint and does not know who is calling). The
guide says so, so it is a known limit and not a surprise.

## Consequences

- **A new host hears about the tools without asking**, in its install steps,
  from the doctor it was told to run, and from the generator's output. A host
  that does not want them has nothing to silence.
- **This is the first generator Janela ships**, and ADR 010 lists generators
  as something that needs a decision. This is that decision, scoped to one
  generator that writes a file and a config entry.
- **The doctor's contract widens by one printed line.** It says something on a
  clean run for the first time. That is accepted because the line is not a
  finding and cannot change the exit status or the count.
- **ADR 053 is superseded in part**: its rejection of an install task and its
  statement that no doctor output is added. Its tool surface, its required
  scope and its rule that Janela registers nothing on a host's behalf stand.
- **A host that already wrote its own adapter loses nothing.** The generator
  leaves an existing `bin/janela-mcp` alone, and the doctor line stops once it
  exists.
- **A scope left as written raises.** The cost is that the first run needs one
  edit, which is the point.
- **The write tools are five, not four.** ADR 053's table gains `update_frame`,
  and its rule that the write tools are off until asked for applies to it.
- **Tests first:** the generator writes both files into a scratch host and
  leaves an existing one alone; the unedited server file raises
  `Janela::Unscoped` rather than reading; the doctor's closing line appears
  without the file, is absent with it, and never changes `check` or the exit
  status; and `docs/agents.md`'s adapter and the generated file are asserted to
  match so they cannot drift (ADR 010).
- **What would change this decision:** a second MCP library with enough hosts
  to want its own generator option, or the doctor line turning out to be
  noise, in which case it moves to the README alone.
