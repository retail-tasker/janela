---
name: jan-adr
description: Draft an architecture decision record for Janela in the project's own format, numbered and indexed. Use when a design choice needs recording before code, when an issue is labelled needs-adr, or when an accepted decision has to be superseded. Pass the decision to record as the argument.
---

# Draft a Janela ADR

An ADR here records **why**, so a forker can see why a piece exists before
changing it (ADR 001). It is written before the code it governs, not
after.

## 1. Read before writing

- `docs/decisions/INDEX.md`, and every ADR listed under the topics the new
  decision touches.
- The two most recent ADRs, for tone and length.
- Any issue the decision answers, in full.

If an accepted ADR already decides this, stop. The work is either
following it or superseding it, and superseding needs a reason stronger
than preference.

## 2. Establish the facts first

A decision built on an assumption about how Rails, Turbo, Stimulus or
Ransack behaves has to verify that assumption before the ADR is written.
Run it against the demo in `test/dummy` or in a browser, and put what was
measured in the Context. ADR 024 is the worked example: it measured three
behaviours, including one that returned zero rows silently, before
deciding anything.

**A measurement already on the issue is a previous session's, so run it
again.** #47 carried numbers taken against a demo that does not have the
shape the issue assumed, and the correction changed what the ADR had to
argue rather than only how it was phrased. Re-running costs a minute and
is the difference between citing evidence and repeating it.

## 3. Write it

Take the next number from the bottom of `INDEX.md`. The file is
`docs/decisions/NNN-short-title-in-kebab-case.md`.

```markdown
---
Date: YYYY-MM-DD
Status: Proposed
Related: ADR 00X, ADR 00Y
Triggers:
  - a situation that should make someone read this ADR
  - another, phrased as what they would be doing at the time
Topics: comma, separated, topics
---

# ADR NNN: A Title That States the Decision

## Context

What forced the decision. The real reports, the measured behaviour, the
options that were seriously considered and why each one fell short.

## Decision

**The decision in one bold sentence.** Then the reasoning, and a code
sample only where the shape of the API is the decision.

## Consequences

- What becomes true, including what gets worse.
- What a host has to do, if anything, and where that is written down.
- What would change this decision.
```

**Status** starts as `Proposed`. It becomes `Accepted` only when the
maintainer accepts it. A superseding ADR sets the old one's status to
`Superseded by ADR NNN` and changes nothing else in it.

**Triggers** are what make an ADR findable. Write them as the activity a
future contributor would be doing, so `grep -l "Triggers:.*<activity>"`
finds it.

## 4. The rules this project holds

- A title states the decision, not the topic: "Formatting Belongs to the
  Measure", not "Number Formatting".
- Rejected options go in Context with the reason, because the reason is
  what stops them being proposed again.
- Read the rejected options again against the decision as it finally
  stands. Another part of the same ADR can remove the reason one was
  rejected for: ADR 034 turned down an overridable `scope_for` as the
  hook ADR 032 had just removed, then adopted it, because folding the
  required argument into that same method changed its unanswered case
  from the widest scope to a refusal. A rejected option left in the list
  after the decision moved is either still rejected for a stated reason
  or is the decision.
- Settings have to earn themselves. If the decision adds configuration,
  say why a setting and not a convention, the way ADR 021 and ADR 023 do.
- A breaking change names its entry in `UPGRADING.md` (ADR 015).
- Australian English. No double hyphen as punctuation. No host
  application named anywhere.

## 5. Index it

In `docs/decisions/INDEX.md`:

1. Add a row to the **Chronological** table with the title, date and
   status.
2. Add the number to every **Topics** row it belongs to, and add a new
   topic row if none fits.
3. Increment **Next number**.

Both tables matter. The topic table is how a contributor finds the
decision without knowing its number.

## 6. Report

Give the path, the one sentence decision, and anything that needs the
maintainer's answer before it can be accepted. Do not commit it unless
asked.
