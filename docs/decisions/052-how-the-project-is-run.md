---
Date: 2026-09-30
Status: Accepted
Related: ADR 001, ADR 010, ADR 015, ADR 025, ADR 032, ADR 037
Triggers:
  - deciding who may cut a release, or how a release is approved
  - a vulnerability report, or where one should go
  - what a contributor may expect in reply to an issue or a pull request
  - changing the release workflow, its environment, or how the gem is published
  - adding a process file to the repository root
Topics: vision, releases, security, open-source, planning
---

# ADR 052: Two People Cut Releases, Reports Go Private, and Support Is Best Effort

## Context

#6: the repository had a licence and a code of conduct and nothing else about how
it is run. A project meant to be used and forked by other people needs four things
written down before it is announced: how contributions are accepted, who can cut a
release, where a vulnerability is reported privately, and what support to expect.
It is also the last item on the 1.0 list that is a decision and not code
(ADR 037).

Three facts were established from the repository before deciding.

**A tag push publishes.** `release.yml` runs on any `v*` tag and publishes to
RubyGems through trusted publishing, and a published version can never be reused.
Four accounts have admin on the repository, so any of the four could publish a
release by pushing a tag. There was no branch or tag protection.

**A vulnerability had nowhere private to go.** GitHub private vulnerability
reporting was disabled, so the only route was a public issue. The doctor exists to
catch a host showing numbers nobody should see (ADR 035), and a project that asks
hosts to take that seriously has to take a report of its own seriously.

**A tag ruleset cannot name a person.** GitHub rulesets accept a role, a team or an
app as an exception, not a user. Restricting `v*` tags would have meant either
giving up on naming Jay and Vanessa or creating a team for two people. An
environment with required reviewers can name individuals, and a workflow job
attached to it waits for one of them.

## Decision

**Jay Killeen and Vanessa Soares cut releases, and the workflow enforces it.**
`release.yml` runs its publish job in a protected `release` environment whose
required reviewers are those two and which accepts runs only from a `v*` tag.
Anyone with repository access can push a tag, and nothing publishes until one of
the two approves. Self approval is allowed, because a maintainer releasing alone is
the ordinary case and two-person sign off is not the aim: the aim is that a
publish is a deliberate act by a named person.

**A vulnerability is reported through GitHub's private advisory form.** It is
enabled, `SECURITY.md` points at it, and it says what counts: reads outside the
host's scope, filters that widen or burden, markup or SQL from typed text, and a
doctor that says safe when it is not. It says plainly that authentication belongs
to the host (ADR 032). No email address is published, so there is no inbox to
watch, and the maintainers are notified by GitHub.

**Support is best effort, with no promised response time.** Issues and pull
requests are read when the maintainers can. There is no support contract, and
before 1.0 the surface may move with an upgrade note each time. This is written in
`CONTRIBUTING.md` and the README rather than left to be inferred, because a promise
that cannot be kept (a triage cadence) is worse than a limit that is stated.

**Contributions follow what ADR 001 and ADR 015 already say,** written down in one
place. A pull request is reviewed on the merits of the diff whoever wrote it; a
change that touches the public surface starts as an issue and, if it is a design
choice, an ADR; a change a host can see updates the changelog and, if they must act,
the upgrade steps. The steps for a release are in `RELEASING.md`, and the same
steps stay in the agent skill that carries them out.

## Consequences

- A report of a vulnerability is private by default, and a release cannot be
  published by an accident or by a person who is not named.
- **Every release now needs an approval click** in the Actions tab after the tag is
  pushed. A workflow started by hand has to be started from the tag, since the
  environment refuses a branch.
- **The RubyGems trusted publisher is not restricted to the environment.** Its
  configuration on rubygems.org names the repository and workflow, and can name an
  environment as well. Doing so would make the gate binding on RubyGems' side and
  not only on GitHub's. That is a setting only an owner of the gem can change, and
  it is left as a follow-up for one of the two maintainers.
- **Branch protection is not added.** The issue did not ask for it, `main` has one
  author of nearly every commit, and requiring reviews would stop the maintainers
  merging their own work. It can be added if the number of contributors grows.
- The four admin accounts are not changed. Who has repository access is a matter
  for the owners, and the release gate holds regardless.
- What would change this decision: a third maintainer, which is a change to the
  reviewers list and a line in `RELEASING.md`; or an incident that shows the gate
  is friction without benefit, which is an argument to remove the environment and
  keep the named-releasers convention.
