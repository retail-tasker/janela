---
Topics: agents, mcp, tools, authorisation, host-integration
---

# Giving an Agent Access to Janela

Frames and panes are rows (ADR 012), so an agent could always arrange a
dashboard by writing them from a console. This page is for giving it tools
instead: read a frame, read a pane's values, and, if you choose, add, change,
remove and move panes. The reasoning is in ADR 053.

The short version: Janela gives you the tool definitions as plain Ruby. You
build them with the answer to "what may this caller read", and you register
them with whatever MCP library your application already runs. Janela
registers nothing, detects nothing and serves nothing, because it cannot
know who is asking and your application can.

## Building the tools

```ruby
tools = Janela::Tools.new(scope: ->(model) { policy_scope(model) })
```

`scope:` is required. It takes a model class and returns a relation: the same
answer your `policy_scope` gives a Janela controller (ADR 032). Leave it out
and `Janela::Unscoped` is raised when the tools are built, because a tool with
no scope would read every row of every model. Every read the tools make passes
that relation, and frames and panes are found through it too, so a caller can
change only what it can see.

Build the tools where you know who is asking, which for an MCP server is when a
tool is called. They are cheap to construct.

## What they do

| Tool | Does | Needs `write: true` |
| --- | --- | --- |
| `describe_vocabulary` | The models, measures, dimensions, renderers and granularities the `janela` blocks declare. An agent should offer nothing else. | no |
| `list_frames` | The frames the scope returns: id, name, owner, pane count. | no |
| `get_frame` | One frame with its panes in position order. | no |
| `read_pane` | A pane's values, through the scope. Filters are Ransack predicates on declared dimensions, bounded as a reader's are (ADR 025). | no |
| `add_pane` | Add a pane to the end of a frame. | yes |
| `update_pane` | Change a pane. An invalid change leaves it as it was. | yes |
| `remove_pane` | Remove a pane and close the gap. | yes |
| `move_pane` | Move a pane one place up or down. | yes |

The write tools are off unless you build the tools with `write: true`. Their
inputs are the pane's own attributes, the ones the README
names, and nothing else: an attribute that is not a pane's is refused rather
than dropped. A pane Janela would refuse is refused with its own reason, for
example `Measure "nonsense" is not a measure of Order`.

There is no tool to create a frame or take a snapshot. Your code finds or makes
a frame with `Janela::Frame.for` (ADR 041), and a snapshot needs an owner and a
scope you have named (ADR 033, ADR 034).

## Registering them

`Janela::Tools.all` is the list of definitions, and needs no scope: each has a
`name`, a `description`, an `input_schema` (JSON Schema) and `read_only`.
`tools.call(name, arguments)` runs one and returns a Hash, or raises a
`Janela::Error` (`NotFound`, `BadRequest` or `Unscoped`) that an adapter reports
to the agent as the tool's own error.

For the official Ruby SDK, the `mcp` gem, an adapter looks like this. It is run
by Janela's own tests, so it cannot drift from the code. `server_context` is
whatever your server was built with, and is where you keep the caller; the
scope is built from it at the moment of the call.

```ruby
def janela_server(write: false)
  tools = Janela::Tools.all(write: write).map do |tool|
    MCP::Tool.define(name: tool.name, description: tool.description, input_schema: tool.input_schema,
                     annotations: { read_only_hint: tool.read_only }) do |server_context:, **arguments|
      # The scope is built per call, because who is asking is known only now.
      scope = ->(model) { server_context[:scope].call(model) }
      result = Janela::Tools.new(scope: scope, write: write).call(tool.name, arguments)
      MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
    rescue Janela::Error => error
      MCP::Tool::Response.new([ { type: "text", text: error.message } ], error: true)
    end
  end

  MCP::Server.new(name: "janela", tools: tools, server_context: { scope: yield })
end
```

`mcp` is not a dependency of Janela, and a host using another library writes the
same few lines against it.

## What Janela does not do

It does not serve MCP, detect a server, edit your configuration or install
anything. It holds no credentials and has no idea who your agent is. Whether an
agent may reach your MCP server at all is your server's authentication, which
Janela never sees. Everything it adds is the question it already asks: what may
this caller read?
