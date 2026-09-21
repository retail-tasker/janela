---
Date: 2026-09-22
Status: Accepted
Related: ADR 002, ADR 019, ADR 021, ADR 025, ADR 031, ADR 032, ADR 033
Triggers:
  - adding a check to janela:doctor, or changing what one reads
  - a check that reports nothing for a host that has a real problem
  - a check that reports something about code a host did not write
  - rescuing an exception raised by a host's own code
  - reading Janela.parent_controller anywhere
  - assigning Janela.parent_controller outside an initializer
Topics: tooling, configuration, authorisation, host-integration, security, releases
---

# ADR 035: A Check Does What Janela Does, or It Says What It Saw

## Context

Three reports arrived within a day of 0.7.0, two of them from a real host
integration rather than from this repository (#51, #38). They read as
three unrelated bugs in `janela:doctor` and they are one.

Every failing check reads a **proxy** for the thing it reports on, and
then words the finding as though it had checked the thing.

| Check | Reads | Asserts |
| --- | --- | --- |
| every controller check | `Janela.parent_controller`, the setting | "Janela's controllers inherit X" |
| `unscoped_reads` | whether a method is defined | "defines no policy_scope, so every pane will raise" |
| `disallowed_uses` | a string anywhere under `app`, `config`, `lib` | "this file filters this model on this key" |
| `scope_filters_by_owner?` | an exception, swallowed | "does not filter by owner" |

### Measured

All against the demo, plus Pundit 2.5.2 installed outside the bundle so
it could be run rather than read. ADR 032 verified Pundit by reading, and
that is the half of it that turned out wrong.

**A Pundit host with no policy for Janela's own models.** This is the
configuration the README treats as the common case, minus one file.

```
policy_scope defined on the host?  true
a request (Janela.scope, the real path):
  Pundit::NotDefinedError: unable to find scope `Janela::FramePolicy::Scope`
the doctor's entire output:
  WARNING (unauthenticated-endpoints): no authentication filter found
```

Every dashboard raises. The doctor says nothing about it.

**A host that names its parent controller too late.** Measured at
development boot, `config/initializers/*.rb` is safe because `to_prepare`
runs after all of them, `config.after_initialize` is already too late,
and within `to_prepare` it depends on registration order against anything
else that touches the controller. The README's own layout recipe is such
a block.

```
host named:            SecureHost (authenticated, policy_scope -> none)
Janela actually uses:  ApplicationController
doctor says:           WARNING ... no authentication filter found on SecureHost
                       "Janela's controllers inherit SecureHost, so they are as public as it is"
a pane served:         $375.00 (200)
```

That quoted sentence is false at the moment it is printed.

**A predicate the host never wrote.** One planted file that does not
mention `Order`:

```
ERROR (hardcoded-disallowed-predicates): Order does not allow status_cont
  app/models/shipment.rb filters Order on status_cont
ERROR (hardcoded-disallowed-predicates): WholesaleOrder does not allow status_cont
```

Twice, because #44 repeats a finding per STI class. What trips it, one
case at a time:

| Planted | Result |
| --- | --- |
| a ransack call on an unrelated model | 2 errors |
| `def status_changed? = true` | nothing |
| `def status_count = 0` | nothing |
| `# never filter on status_cont, it is not allowed` | 2 errors |
| `status_matches:` as a key in `config/locales/en.yml` | 2 errors |

Ordinary identifiers are safe, so the predicate detection is doing real
work and this is not a bare grep. A comment warning against the predicate
still reports that you use it, at `error`, the loudest thing the doctor
can say.

**The worst of it, which nobody had reported.** The two owner checks call
a host's `policy_scope` on `parent.allocate`, an instance with no
request, and rescue everything:

```
RealisticOwnerHost     scope_filters_by_owner? -> false   raised: NameError
SessionlessOwnerHost   scope_filters_by_owner? -> true    raised: no

does frames-nobody-will-own fire?
RealisticOwnerHost     no finding
SessionlessOwnerHost   ... scopes frames by owner but defines no janela_frame_owner
```

`RealisticOwnerHost` differs from the other by one line: its
`policy_scope` reaches for the signed in user through the session, which
is what every authentication library does. On an allocated controller
`session` is nil, the call raises `NameError`, the blanket rescue turns
that into "does not filter by owner", and the check goes quiet.

So `frames-nobody-will-own` and `snapshots-nobody-will-see` do not fire
for any host with real authentication. The second of those shipped in
0.7.0 yesterday, written because the case bit five times in one
afternoon. It cannot fire for the hosts that need it.

**Why this repository did not catch it.** The demo's `policy_scope` reads
`Current.tenant`, a thread local, where a host reads the session. It is
the #46 lesson a third time: a stand in wired differently to the
documentation cannot catch a bug in the documentation's wiring. That is
already a hard constraint in `/jan-orient`, and it did not extend to
"wired differently to how hosts actually work".

### The thing that makes this fixable

An allocated controller can be given a request:

```
allocate, no request:                  NameError: undefined method 'session' for nil
allocate + ActionDispatch::TestRequest, policy present:  ok, SELECT "janela_frames".*
allocate + ActionDispatch::TestRequest, policy absent:   Pundit::NotDefinedError
```

A correctly wired host succeeds. A host missing a policy raises the same
error its visitors get. The check can tell them apart without knowing
that Pundit exists, which ADR 002 requires.

### Options considered

**Keep reading, and hedge in the prose.** Cheap, and leaves both owner
checks dead and the Pundit gap unreported. A check that cannot fire is
not improved by better wording.

**Depend on Pundit so a check can name `Pundit::NotDefinedError`.**
Rejected on ADR 002: authorisation here is a hook, not a dependency, and
a doctor that knows one library's exception classes is a doctor that is
wrong about every other library.

**Build a real request through the integration stack.** Heavier than
`ActionDispatch::TestRequest` and no more faithful. The controller never
processes an action here; it is asked one question.

**Statically resolve the receiver of a `ransack` call** so
`disallowed_uses` can attribute a match honestly. That is a parser, for
one advisory check, and it would still miss a call through a variable.

**Remove `disallowed_uses`.** Seriously considered. It was written for
the 0.5.0 upgrade (ADR 025) to help hosts find filters the predicate
narrowing broke, two releases ago, and its noise is now measured. Kept,
because a host upgrading from 0.4.x still exists and the check is
salvageable as an observation.

**Make `Janela.parent_controller=` raise when the assignment cannot take
effect.** Chosen, below, after being weighed against a doctor check that
names the disagreement instead.

## Decision

**A check does what Janela does, or it says what it saw.** Where Janela
calls a method, the check calls the same method. Where Janela resolves a
constant, the check resolves the same constant. Where a check cannot do
what Janela does, it reports its observation and not a conclusion it did
not earn.

That is the rule the rest of this follows from.

**A check that calls host code calls it the way a request does.** The
controller is given an `ActionDispatch::TestRequest`, so a host's
`policy_scope` can reach `session`, `params` and `current_user` and find
them empty rather than absent. Empty is the honest condition: it is an
unauthenticated visitor, which is exactly who a doctor should be asking
about. Measured above to separate a wired host from an unwired one with
no knowledge of the host's library.

**An exception from host code is reported, never swallowed.**
`scope_filters_by_owner?` collapses "raised" and "returned something
unfiltered" into `false`, and both owner checks are silent as a result.
The question becomes three-valued: filtered, not filtered, or raised. A
raise is a finding in its own right, quoting the exception class and
message, because Janela is about to do the same call on every request.

**`unscoped_reads` calls `policy_scope` against `Janela::Frame` and
`Janela::Snapshot`.** Those two are always present and are what the
engine's own pages read first, so a host that cannot be asked about them
has a broken dashboard whatever else is true. It stops testing for the
method. **ADR 032's claim that this check is "exact: the method is
defined or it is not, and that is the whole contract" is wrong and this
supersedes it.** The contract is that calling it returns a relation.
ADR 032's other claim, that a Pundit host missing a policy is not
exposed, stands: Pundit raises rather than leaking, so no data is at
risk and this is a diagnosis failure rather than a safety one.

**Every check reads `Janela::ApplicationController.superclass`, not
`Janela.parent_controller`.** The superclass is what Janela uses; the
setting is what a host asked for, and the two can differ (#38). One line,
four checks, and it removes the possibility of printing "Janela's
controllers inherit X" about a class that is not in the chain.

**`Janela.parent_controller=` raises when the assignment cannot take
effect and names a different class.** Assigning before the controller
loads is fine, and reassigning the value already resolved is fine, so the
raise fires only for the case that is silently broken today. `Janela` can
tell without forcing the autoload it is asking about, through
`autoload?` and `const_defined?`. This is ADR 032's trade again, loud once
at the exact wrong line rather than quiet forever, and it is why no new
doctor check is added for #38: preventing the state is better than
reporting it, and two mechanisms for one problem is what ADR 001 declines.
It does not contradict ADR 032's refusal to raise at boot, which was
about raising for a host that had done nothing wrong.

**`disallowed_uses` says what it saw.** Janela never reads a host's
source, so this check cannot do what Janela does and falls to the other
half of the rule. It reports that a file *mentions* a key the model does
not allow, rather than that the file *filters* that model, drops from
error to warning, and reports once per declaration rather than once per
inheriting class. It stays a hint to grep rather than a claim about the
host's code.

## Consequences

- Two checks that could not fire for a host with real authentication
  begin firing. Expect the first hosts to run this to see findings that
  were always true and never printed.
- A check now runs a host's own `policy_scope` during `janela:doctor`.
  That is host code executing in a rake task, which it was already, but
  deliberately rather than by accident. The contract for `policy_scope`
  is that it returns a relation, so it reads; a host whose implementation
  writes something has a larger problem than this check.
- **A host assigning `Janela.parent_controller` too late goes from
  silently ignored to an exception at boot.** Breaking, so it goes in
  `UPGRADING.md` with the three places that are too late and the one that
  is not (ADR 015). Most hosts assign in an initializer and see nothing.
- `with_parent_controller` in this repository's own doctor tests works by
  assigning after load, which is the very thing the setter now refuses.
  Those tests have to set up their scenarios by another route, and they
  were relying on the bug: they only worked because the checks read the
  setting rather than the chain.
- `disallowed_uses` dropping to warning means a host who genuinely broke
  a filter is told less loudly. Accepted: it was error severity on
  evidence it did not have, and a warning that is usually right beats an
  error that is sometimes about a comment.
- #44 is narrowed rather than closed. Reporting once per declaration
  fixes the duplication in this one check; the rest of the model checks
  still repeat per STI subclass.
- The demo has to gain a host whose `policy_scope` reaches through the
  session, because nothing else in this repository would have caught the
  dead owner checks. That is the #46 lesson applied rather than restated.
- What would change this decision: a host reporting that
  `ActionDispatch::TestRequest` is not enough for their authorisation to
  run, at which point the question is whether a check should be asking at
  all rather than how hard it should try.
