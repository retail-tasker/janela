---
Date: 2026-09-16
Status: Accepted
Related: ADR 010, ADR 015, ADR 019
Triggers:
  - adding a check to janela:doctor
  - adding a setting to Janela
  - a warning that is a false alarm for some applications
  - running the doctor in CI
Topics: configuration, tooling, upgrades, agent-guidance
---

# ADR 021: A Check Has a Name, and a Host Can Silence It

## Context

`janela:doctor` reports what a host still has to do, and one of its
checks cannot be certain. Authentication is whatever the host does, so
the check reads the controller's filters and says what it sees. For an
application that authenticates another way, that warning is wrong
every single run.

A warning that is always wrong is worse than no warning. People learn
to skip the output, and the next finding, the true one, goes unread
with it. In CI it is worse again, because the only way to keep a green
build is to stop running the task.

The pattern here is settled elsewhere. Django's system check framework
gives every check an identifier and lets a project list the ones to
silence. Homebrew, Flutter, npm, Bundler and RubyGems all ship a
doctor of some shape, and the mature ones can be told to be quiet
about a thing the maintainer has already judged.

Janela had neither half: findings were prose with no stable handle, so
there was nothing to name in a conversation, a commit message or a
setting.

## Decision

**Every finding carries the name of the check that produced it**, in
the output and on the finding itself:

```
WARNING (unauthenticated-endpoints): no authentication filter found on ApplicationController
```

The name is the check's own method name, dasherised by the runner
rather than written out per check, so a code and the thing it names
cannot drift apart. Words rather than numbers: there are seven checks,
not seven hundred, and `unmigrated-tables` needs no lookup table the
way `janela.E004` would.

**A host silences a check by that name**:

```ruby
# config/initializers/janela.rb
Janela.silenced_checks = %w[unauthenticated-endpoints]
```

**A silenced check is named every run**, in one line at the end, even
when there is nothing else to report. A silence nobody remembers is
how a real finding goes unread, which is the problem this is meant to
solve rather than reproduce.

This is Janela's second setting, and deliberately so. ADR 019 turned
down configuration for what owns a frame because ownership is
per-request state that a setting cannot hold. Silencing is the
opposite: a judgement made once, about the application as a whole,
that does not change between requests. That is what configuration is
for, and the distinction is the rule to apply next time rather than a
preference about this one.

## Consequences

- The doctor can run in CI on an application it cannot fully
  understand, which is the only way it gets run at all.
- Silencing an error passes the task. That is the point and it is a
  loaded gun, which is why the silence is printed every run.
- A check's name is now public. Renaming a check method renames what a
  host silences, so a rename is a breaking change and goes in
  UPGRADING.md like any other (ADR 015).
- Agents get a stable handle too. "Silence unmigrated-tables" is an
  instruction that can be given and followed without quoting a
  sentence of prose (ADR 010).
