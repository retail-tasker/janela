---
Date: 2026-10-02
Status: Accepted
Related: ADR 001, ADR 010, ADR 012, ADR 014, ADR 017, ADR 019, ADR 025, ADR 032, ADR 033, ADR 034, ADR 037, ADR 041
Triggers:
  - proposing an MCP server, an agent tool or any machine facing surface for Janela
  - an agent needs to read or arrange a frame without a browser
  - adding a dependency on an MCP library
  - deciding whether Janela should detect, register or install anything in a host's own tooling
  - running a Janela query outside a controller, from a tool, a job or a console
  - changing what an agent may do to a pane
Topics: ai, agents, mcp, tools, authorisation, scope, host-integration, frames, dependencies, 1.0
---

# ADR 053: An Agent Reaches Janela Through Tools the Host Scopes, and Janela Registers None

## Context

Janela dashboards are meant to be composed by agents, and an agent in a
host application has no way in. Frames and panes are rows (ADR 012), so
the only route is `Janela::Frame` and `Janela::Pane` written from a
console. A host that already runs an MCP server writes its own wrappers
by hand, and a host without one gets nothing. #73 asks for an MCP
surface, and ADR 010 named it as "one ADR away" and as one of the two
conditions for shipping Jan.

The issue proposed that Janela detect a host's MCP server and offer to
install tools into it. Four facts, measured on the demo before this was
written, change what that should mean.

**Reading a pane outside a controller reads everything.** The refusal in
ADR 032 lives in `Janela::ApplicationController`, where `policy_scope`
is asked. `Query#result` underneath takes an optional `on:` relation,
and without it reads the model's default scope. With two orders in the
demo, `pane.query.result` returned both statuses, and
`pane.query.result(on: Order.where(status: "paid"))` returned one. A tool
that called the first form would show an agent, and so a person, rows
the host never scoped, with no error. This is the same shape as ADR 034:
a thing that runs outside a request and has to be told what may be read.

**The host's scope is an answer given at the point of asking.** ADR 019
found that a decision needing the current user and tenant belongs inside
a request rather than in a setting, and ADR 032 rejected a global
`Janela.scope = ->(model, controller)` for it. An MCP call is not a
request to Janela's controllers. Who is asking arrives through whatever
authentication the host's own MCP server has, which Janela does not own
and cannot see.

**A pane row already refuses what it should.** A pane naming a measure or
model that is not declared is invalid, and says so in words an agent can
act on: `Measure "nonsense" is not a measure of Order` and `Model
"no_such_model" is not a janela model`. The tools do not need a
validation layer of their own.

**Tools can be built from data.** The official Ruby SDK, `mcp` 1.6.1,
builds a tool from a name, a description, a JSON schema and a block
(`MCP::Tool.define`), and hands the caller's context to the block as
`server_context`. Other libraries take the same four things. A tool
definition is therefore plain data plus a call, and none of it needs to
live in an MCP library to be written once.

One more fact corrects the issue. #73 describes the install task as "in
the same spirit as `rails janela:install:skill`". That task does not
exist. ADR 010 records the skill, the install task and the agent
definition as not implemented, and `docs/skills/` is absent. This would
be the first install task Janela has, not the second.

### What was considered

**Janela serves MCP itself**, as an engine endpoint. Rejected. A served
endpoint needs authentication, a notion of who is calling and a way to
answer ADR 032's question for them, and Janela has none of the three: its
controllers are exactly as authenticated as the host's (ADR 010). Adding
them is the subsystem ADR 001 refused, and getting scope wrong shows one
tenant's numbers to another.

**Detect the host's MCP server and install into it**, as #73 proposed.
Rejected for the reason ADR 034 rejected detecting the kind of host: the
signal does not distinguish anything. A host's MCP setup is a gem, an
endpoint or a hand-written server, and the one thing Janela can reliably
know is none of those. It would also be Janela editing a host's tooling,
which ADR 010 says it never does.

**A `janela:install:mcp` task that writes tool files into the host.**
Rejected. Once copied the files are the host's, they drift from the
gem's public API, and the doctor would have to grow a check for each
release to say so. A host that wants the shape reads it in the guide and
owns the ten lines.

**A global scope setting**, so the tools need no argument. Rejected on
ADR 019 and ADR 032, above.

**`mcp` as a dependency of the gem.** Rejected. It is the right library
today and is not the only one a host may use, so a hard dependency would
make Janela's choice the host's. It stays out of the gemspec, the way the
demo's markdown renderer does, and the adapter below is optional.

**Writing and reading in one step.** Rejected as the shipped shape, not
as an idea. The write tools change records a person arranged, so they are
off until asked for.

## Decision

**Janela ships its agent tools as plain Ruby that the host builds with a
scope and registers wherever it likes. Janela registers nothing,
detects nothing and serves nothing.**

```ruby
tools = Janela::Tools.new(scope: ->(model) { policy_scope(model) }, write: true)

tools.all                                   # name, description, input_schema, read_only
tools.call("add_pane", frame_id: 3, model: "orders", measure: "revenue")
```

**`scope:` is required and has no default.** It is a callable that takes
a model class and returns a relation: the same answer `policy_scope`
gives. Leaving it out raises `Janela::Unscoped` when the tools are built,
not when one is called, which is ADR 032's refusal moved to the place
this surface begins. Every read the tools make passes the relation it
returns as `on:`, and frames and panes are read through the same callable
(`scope.call(Janela::Frame)`). It is an argument and not a setting,
because it is built where the host knows who is asking, as ADR 034's
`scope_for` is.

**Read tools first, and writes only when asked for.** The 1.0 set:

| Tool | Does |
| --- | --- |
| `describe_vocabulary` | The models, measures, dimensions, renderers and granularities `Janela.definitions` declares, so an agent offers only what can be asked |
| `list_frames` | Id, name, owner and pane count of the frames the scope returns |
| `get_frame` | One frame with its panes in position order |
| `read_pane` | A pane's values, through the host's scope, with `q[...]` filters bounded as ADR 025 bounds them |
| `add_pane`, `update_pane`, `remove_pane`, `move_pane` | Only with `write: true` |

Inputs are the pane's own attributes and the README's own names. There is
no agent only vocabulary (ADR 010). A rejected row returns the pane's
validation messages unchanged. A frame is found or made by the host with
`Frame.for` (ADR 041) or by an analyst on the engine's pages, so there is
no `create_frame` in 1.0.

**A tool definition is data, and an adapter is a few lines the host
owns.** `Janela::Tools#all` carries what any library needs. The guide
shows the mapping for the official `mcp` SDK, and a host using another
writes the same few lines. Janela adds no MCP library to its gemspec.

**Snapshots are not in 1.0.** A snapshot persists and publishes, so it
needs an owner (ADR 033) and a scope the caller has named (ADR 034). That
is two more decisions an agent should not be making by default, and it
waits for a host that wants it.

**Jan still does not ship.** ADR 010's second condition, that an MCP
surface exists, is met by this. Its first reason, that a skill loaded
agent already does the work, has not been tested, because the skill was
never built. The skill ships first and teaches these tools. An agent
definition is revisited after a host has used both, and ADR 010 is not
superseded here.

## Consequences

- **It ships as 0.13.0, with its own short soak.** This adds public
  surface, and ADR 037 says anything that changes the surface resets the
  soak clock in #71. The earliest 1.0 tag moves by the length of that
  soak. The rule for what 1.0 then contains is set now, before anyone has
  seen the result: if a real host has exercised the write tools and found
  nothing wrong, 1.0 ships with them. If no host has used them by the end
  of the soak, 1.0 ships read only and the write tools wait for 1.1.
  Freezing four schemas that nobody has tried is what a soak is for
  avoiding.
- **The tool names and input schemas join the contract at 1.0**, so the
  set is small on purpose and every name is a verb and a README noun. A
  tool added after 1.0 is a minor release. A tool changed is a major one.
- **A host does the registering.** That is a few lines in the place its
  MCP server already lives, and the guide says where. A host with no MCP
  server gets nothing from this, which is the honest answer: Janela does
  not run servers.
- **The first test is the measured failure.** A tool built with a scope
  that returns `Order.none` reads no values, and tools built without a
  scope raise. Both belong in the suite before the code.
- **No doctor check.** Construction raises, so there is nothing for the
  doctor to see that the raise does not say (ADR 035).
- **The pane `order` option (#75) reaches agents for free**, since the
  write tools take a pane's attributes. It does not change this ADR.
- **What would change this decision:** two hosts writing the same
  adapter by hand, which would earn a shipped one for that library; or a
  host with no MCP server that needs one, which would be the day Janela
  is asked to run something and has to answer ADR 032's question for
  itself.
