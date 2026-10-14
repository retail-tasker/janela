---
Date: 2026-10-14
Status: Accepted
Related: ADR 053, ADR 056, ADR 057
Triggers:
  - an agent needs to change a dashboard on the deployed demo
  - adding an endpoint to the demo that writes
  - changing demo:reset, or what the demo keeps through it
  - changing which group the mcp gem is in
Topics: demo, agents, mcp, deployment, security, dogfooding
---

# ADR 058: The Deployed Demo Is Reached Over SSH, and Its Visits Frame Survives a Reset

## Context

ADR 057 left one gap named and unsolved: a server run from `bin/janela-mcp`
changes the database of the environment it starts in, so an agent could
arrange `/visits` locally and not on the live demo. The maintainer's reading
was that talking to an agent should change the dashboard people see.

### Measured

Against the deployed demo, 2026-10-14.

**The production image has no `mcp` gem.** It is built with
`BUNDLE_WITHOUT="development test"`, and `mcp` was in the development and
test group, so `bundle list` on the running container shows Janela and not
`mcp`. The server could not have started there.

**Production logs to stdout.** `config.logger` writes to `$stdout`, which for
this server is the protocol stream, so a single log line would corrupt it.
Run in production mode at debug level against a scratch database, with
`$stdout` pointed at stderr during boot, stdout carried only valid JSON-RPC
and every log line went to stderr.

**The hourly reset deletes every frame.** `demo:reset` runs `Frame.delete_all`
and reseeds, so a change made to "Site visits" would be gone within the hour.
Its owner is also a customer the reset deletes and recreates under a new id.

**SSH reaches the box.** `docker exec -i` into the running container is a
clean stdio pipe with no terminal allocated.

### What was considered

**An authenticated HTTP endpoint on the demo.** Rejected. It would put a write
path to a public site behind a token, which is a new surface to secure and
rotate, for a dashboard one maintainer arranges. ADR 053 says Janela serves
nothing and a host that wants an endpoint owns its authentication. The demo is
a host, and it does not need one.

**Letting the reset run over the frame.** Rejected. It makes a live change
impossible to keep.

## Decision

**The deployed demo is reached by running the same server on the box over SSH,
and the authentication is the SSH key.** `bin/janela-mcp` runs in production
only when `JANELA_MCP_PRODUCTION=1` is set, which the SSH command sets and
nothing else does. There is no endpoint, no token and no new login.

**`mcp` moves out of the development and test group** so it is in the
production bundle. It stays out of the gemspec (ADR 053).

**The server points `$stdout` at stderr while Rails boots**, and gives it back
to the transport afterwards, so production's stdout logger cannot corrupt the
stream.

**`demo:reset` keeps the visits frame.** Every other frame is still put back.
The frame is handed to the new first customer after the reseed, because its
owner was deleted. Page views were already left alone (ADR 056).

## Consequences

- **A change made through the tools reaches the live dashboard** and stays
  there. The seeds hold the first design and the live frame is the one that
  evolves, so the seeds no longer describe it once it has been changed.
- **Keeping one frame broke two assumptions the demo made, found on the live
  site an hour after the deploy.** The seeds created the original frames only
  when there were no frames at all, and the orders page linked to whichever
  frame had the lowest id. With the visits frame kept, the first never ran and
  the second picked the wrong one, so the live `/dashboards` lost two frames.
  Each frame is now guarded by its own name and the page finds its frame by
  name. The reset test now asserts every original frame comes back, since it
  had only checked one that happened to have its own guard.
- **The reach is exactly the people with SSH to the box**, which is the people
  who can already change the demo.
- **The connection is not committed.** The SSH entry goes in a developer's own
  local MCP config, because a contributor without access would see a server
  that fails.
- **The demo image carries one more gem**, with no endpoint that uses it.
- **What would change this decision:** a second person needing to arrange the
  demo without SSH, which is the day an authenticated endpoint is worth its
  cost.
