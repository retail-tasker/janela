---
Date: 2026-09-16
Status: Accepted
Related: ADR 001, ADR 010, ADR 014
Triggers:
  - making any change a host must act on
  - cutting a release whose version's middle number changes
  - adding a deprecation, an alias or a compatibility shim
  - adding or changing what janela:doctor checks
  - writing anything an agent is expected to follow
Topics: releases, upgrades, documentation, ai, dx, deprecation
---

# ADR 015: How Breaking Change Is Communicated

## Context

Build 1 of ADR 014 renamed a helper, a Stimulus controller, a helper
module, two controllers and a class. Every host has to act on it, and
the only record is `CHANGELOG.md`, which a reader has to know to look
for. The failures a host meets first are uninformative:
`undefined method 'janela_dashboard'` and `uninitialized constant
Janela::Pane` say nothing about what replaced them.

The people and agents upgrading this gem are the same ones ADR 010 was
written for. That ADR decided guidance ships inside the gem so nobody
has to rediscover what the gem already knows. An upgrade path is
guidance, and none has shipped. This is the first case where the
principle has something concrete to do.

A changelog is also the wrong document for the job. It records what
changed, for a reader deciding whether to upgrade. It does not tell
someone mid-upgrade what to do, in order, with exact before and after.
Those are different readers and mixing them serves neither.

## Decision

**`UPGRADING.md` ships inside the gem.** One section per version that
requires action, newest first, written as imperative steps with the
exact old and new text. Not prose: something a person or an agent can
work through and tick off. It is listed in the gemspec's files, so it
travels with an installed gem and is readable without network access.

The division of labour: `CHANGELOG.md` says what changed and why,
`UPGRADING.md` says what to do about it, `docs/decisions/` says why
the change was decided at all.

**A breaking release sets `post_install_message`.** One or two lines
naming the version and pointing at `UPGRADING.md`. Bundler prints it
when the gem is updated, which makes it the only mechanism that
reaches whoever, or whatever, ran the command at the moment they
needed it.

Used only for releases that require host action, and removed in the
release after. A post install message on every version is noise that
teaches people to skip it.

**`rails janela:doctor` reports what a host needs to fix.** One
command, a list of findings, exit status zero when clean. It checks
what experience says actually breaks a host:

- Stale identifiers from any previous version, for example
  `janela--dashboard` or `janela_dashboard` in the host's markup and
  JavaScript, or `Janela::Pane` in its Ruby.
- Whether Janela's Stimulus controllers are registered at all, which
  is the failure that looks like nothing happening.
- A `through:` dimension whose associated model does not allowlist the
  attribute, which Ransack refuses per class.
- Whether Janela's endpoints are reachable without authentication,
  which depends entirely on what the host's `ApplicationController`
  does.
- Whether the engine is mounted, and where.

This is the most agent shaped surface the gem can offer: one command
whose output is a list of actions rather than a paragraph to
interpret. It covers install as well as upgrade, so the traps ADR 010
listed become something a machine finds rather than something a person
remembers.

**No deprecation aliases and no compatibility shims.** A renamed
helper is not kept alive with a warning. The codebase's posture is
that a thing has one name, and a shim is a second name that lives
forever because nobody dares delete it. A loud failure plus a
findable, executable guide is better than a quiet alias, particularly
before 1.0 where the version number already says what to expect.

The exception, if one is ever wanted, is a constant that raises with a
message naming its replacement, because that is an error rather than a
second way to write working code. Not adopted now.

**ADR 010's skill will point at all three.** When the skill ships it
tells an agent to read `UPGRADING.md` before changing a version
constraint and to run `janela:doctor` after, which is the loop this
ADR exists to make possible.

## Consequences

- Three documents now have to stay in step on a breaking release:
  changelog entry, upgrade section, and the doctor check that catches
  the thing being renamed. The doctor is what keeps the other two
  honest, because a check either finds the stale identifier or it does
  not.
- `janela:doctor` reads the host's source, which is the first time the
  gem inspects an application rather than serving it. It only reads,
  reports, and changes nothing.
- A doctor check for authentication has to guess, since whether an
  endpoint is public depends on the host's controller. It reports what
  it observes and says plainly that it cannot be certain, rather than
  asserting a system is safe.
- Refusing aliases means an upgrade cannot be gradual within one
  version. That is the intended cost: the guide is short because there
  is exactly one way the code can be.
- This ADR is itself the thing that makes 0.3.0 shippable to anyone
  other than the author.
