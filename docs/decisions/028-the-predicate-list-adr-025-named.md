---
Date: 2026-09-18
Status: Accepted
Related: ADR 006, ADR 007, ADR 009, ADR 024, ADR 025
Supersedes: ADR 025, in the predicate list and in what it says about snapshots
Triggers:
  - changing which predicates a dimension allows
  - adding a predicate a click can produce
  - reasoning about what a stored snapshot validates when it is read
Topics: security, scope, urls, snapshots
---

# ADR 028: The Predicate List ADR 025 Named Was Not Quite Right

## Context

ADR 025 decided that Janela bounds what a filter can ask for, and it was
right about the problem: every one of Ransack's 62 predicates was
reachable on any attribute a dimension declared, a grouped query carried
no `LIMIT`, and one filter accepted 5001 values. Building it (#8) proved
all three still true and closed them.

Two things the ADR said turned out not to survive contact with the code.
An accepted ADR is not rewritten, so this records what is true instead.

**The list it named would have broken behaviour the project already
documents.** ADR 025 gave a categorical dimension `eq`, `in` and `null`,
on the grounds that those are what a click produces (ADR 024). But
`not_null` is already used, already tested in `definition_query_test.rb`,
and has nothing to do with the hole being closed. Shipping the list as
written would have refused a filter a host is entitled to use, loudly, in
the name of security it does not buy.

**The snapshot risk it described does not exist.** ADR 025 warned that a
stored snapshot taken under a predicate later disallowed "would raise
when read". It cannot. `Snapshot#stored_result` looks a pane up by key
and returns the stored JSON; it never re-runs the query and never touches
Ransack again. A snapshot's `filters` are metadata `Snapshot.take` built
with, not something a read validates against. The fear was reasonable and
the code does not have it.

## Decision

**A categorical dimension allows `eq`, `in`, `null` and `not_null`. A
time dimension allows those plus `gteq`, `gt`, `lteq` and `lt`. Reading a
stored snapshot validates no predicates, because it runs no query.**

Everything else ADR 025 decided stands: predicates are allowed by the
kind of dimension rather than globally, anything outside the list raises
`Janela::BadRequest` naming the attribute and what is allowed, and one
ceiling of 1000 bounds both an unlimited grouped query and the number of
values a single filter may carry (ADR 007).

The rule for adding to the list, so this does not become a place things
accumulate: a predicate belongs there if a dashboard produces it, or if
it is a boolean test of presence rather than a way to phrase a match.
`not_null` qualifies on the second. `cont`, `matches` and `start` do not
qualify on either, which is the whole point of the bound.

## Consequences

The built list is one predicate wider than the decided one, and a host
using `not_null` keeps working rather than being broken by a security
fix. That is the right trade, and it is worth naming why it was close: a
list written from first principles in an ADR, without running it against
the tests, refused something real.

A regression test in `snapshot_test.rb` now pins the snapshot behaviour,
so the failure mode ADR 025 imagined cannot appear later without a test
noticing.

The general lesson, which is why this is an ADR rather than a commit
message: an ADR that names a specific list is making a claim about the
code, not only about the design, and that claim needs checking against
the code before the ADR is accepted rather than while it is built.
