---
name: jan-issue-investigate
description: Investigate a Janela GitHub issue before any code is written. Reads the issue and the decisions it touches, reproduces the problem, measures what is actually true, then records the findings on the issue and sets the label that says what happens next. Use when picking up an issue. Pass the issue number.
argument-hint: [issue number]
---

# Investigate an issue

The point of investigating is to replace what the issue assumes with what
is true. Issues here are often written from a hunch, including by the
maintainer, and the hunch is wrong often enough to matter: #33 was filed
saying Turbo cancels an in-flight frame request, and it does not.

**Write no production code in this skill.** The output is evidence, a
decision about what happens next, and a label. Building is `/jan-issue-build`.

## 1. Read, in this order

```bash
gh issue view <n> --comments
```

Read the whole thread, including comments, because an earlier
investigation may already be recorded there.

Then find the decisions it touches. Look up the topic in
`docs/decisions/INDEX.md` and read every ADR listed, plus anything whose
`Triggers:` line matches what you are about to do:

```bash
grep -l "Triggers:.*<the activity>" docs/decisions/*.md
```

Read the code the issue names, and the tests around it. An issue that
names no code is the first thing to fix: find where it lives.

## 2. Reproduce it, or say plainly that you could not

An unreproduced issue cannot be built against, because there is nothing
to prove fixed. Use whichever of these fits:

- **A unit case.** A throwaway script through `bundle exec ruby -Ilib:test`
  against the demo's fixtures is usually enough.
- **The demo, in a browser.** `cd test/dummy && bin/rails s -p 3210`,
  then drive it. For anything involving Turbo, Stimulus or a chart, this
  is the only honest way: instrument `window.fetch`, log the events, read
  the DOM.
- **A deliberate race.** If the issue is a timing problem, make it
  deterministic by holding a response in flight rather than by running a
  test repeatedly.
- **Measurement.** If the issue is about a rate, measure the rate. Twenty
  runs and a count beats an impression.

Remember: a browser test's numbers are rendered by the server before any
JavaScript runs, so seeing the right number proves nothing about the
JavaScript.

## 3. Establish what is actually true

Write down, with evidence:

- the exact conditions that produce it, and the ones that do not
- what the failure looks like to a person using the dashboard, since a
  silently wrong number is far worse than an error
- what the issue assumed that turns out to be false
- what a fix would have to change, in one or two sentences
- what else would be affected, named by file
- whether the fix is bounded, or whether it needs a decision first

## 4. Record it on the issue

Comment on the issue, so the work survives this session:

```bash
gh issue comment <n> --body "<findings>"
```

The comment carries the reproduction, the evidence, the corrected
assumptions and the proposed shape of the fix. Write it so someone who
picks this up cold needs nothing else. If the investigation changed what
the issue is about, say so in the comment rather than quietly building
something different.

## 5. Set the label that says what happens next

Exactly one of these, and say which you chose and why:

| Finding | Label |
| --- | --- |
| Bounded, decisions already made, safe to build | `ready` |
| Needs a design decision first | `needs-adr` |
| Needs the maintainer to choose or answer | `question` |
| Waiting on a dependency | `upstream` |
| Already done by other work | close, with a pointer to what settled it |
| Not a real problem, or not wanted | leave open and say so; closing as `wontfix` or `invalid` is the maintainer's call |

```bash
gh issue edit <n> --add-label ready
gh issue edit <n> --add-label needs-adr --remove-label ready
```

An issue that contradicts an accepted ADR gets `needs-adr`, never
`ready`, however small it looks. An issue whose fix touches a public
surface, a URL shape, a return type, a class name, gets `needs-adr` too:
those are the ones that become breaking changes.

## 6. Report

Short, and lead with what is true rather than what was read:

- what you reproduced, and how
- what the issue assumed that is false
- the shape of the fix, in a sentence
- the label you set, and what happens next: `/jan-adr`, `/jan-issue-build`, or
  the maintainer's answer
