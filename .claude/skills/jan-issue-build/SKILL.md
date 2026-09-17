---
name: jan-issue-build
description: Build a Janela issue that has been investigated and decided, test first, with the changelog and upgrade notes it needs, and a commit that closes it. Use after /jan-issue-investigate has set an issue ready, or when the maintainer names work to build. Pass the issue number.
argument-hint: [issue number]
---

# Build an issue

## 1. Refuse to start on the wrong footing

```bash
gh issue view <n> --comments --json labels,title,body
```

Stop and say so if any of these is true:

- **No investigation on the thread.** Run `/jan-issue-investigate` first. Code
  written against an unreproduced issue cannot be proven to fix it.
- **Labelled `needs-adr` with no accepted ADR.** The decision comes
  first, through `/jan-adr`. Building anyway is how a library grows a
  surface nobody decided on.
- **Labelled `question`.** The maintainer owes an answer. Ask, do not
  guess.
- **The working tree has unrelated changes.** Finish or set those aside,
  so the commit is about one thing.

Then read the ADRs the issue touches, if you have not already in this
session. Building against a decision you have not read is how ADR 013's
path segment got shipped and then taken back out by ADR 014.

## 2. Write the failing test first

The test comes before the fix, and it must fail for the right reason.
Run it and read the failure: if it fails because of a typo or the wrong
fixture, it is not yet evidence.

- **Unit tests** in `test/`, against the demo's models and fixtures.
- **Browser tests** in `test/system/` for anything involving Turbo,
  Stimulus, a chart or a click. The base class already waits for the
  frame controller and every pane's first load, so a test that calls
  `visit` inherits that.
- A bug that produced a **silently wrong number** gets a test that
  asserts the number, not that the page rendered.

Name in the test, in a comment, what was believed that turned out false.
That comment is why the test exists and stops it being deleted as
redundant later.

## 3. Build the smallest thing that passes it

- **One obvious way, not a setting.** A new configuration option has to
  earn itself: ADR 019 turned one down because the state was per request,
  ADR 021 and ADR 023 allowed one because the judgement was made once at
  boot. Cite whichever applies in the commit message.
- **Stay inside the decisions.** If the work wants to go outside them,
  stop and write the superseding ADR.
- **The host constraint holds.** Nothing about a host application enters
  this repository, in code, tests, comments or prose.
- **Comments say why, not what.** The next person can read the code.
- **House style.** Australian English, and the double hyphen is never
  punctuation.

If the work turns out bigger than the issue, split it: build the part the
issue describes, and file the rest as its own issue with what you found.
Do not quietly widen the scope.

## 4. Tell hosts, if they can see it

A change a host can notice is not finished until it is written down
(ADR 015):

- **`CHANGELOG.md`** under `[Unreleased]`, saying what changed for a host
  and why, not how the code moved. Create the section if it is missing.
- **`UPGRADING.md`** if they must act, with the exact before and after.
- **`Janela::Doctor::RENAMED`** if an identifier was renamed, checking the
  new entry cannot match the new name as a substring.
- **The README** if the public API changed. ADR 010 holds that the
  guidance describes the README's API and nothing else, so the README is
  the thing that has to be right.

## 5. Verify

Run `/jan-verify`. A browser test that fails once in several runs is a
real race until measured, in the library or in the test. Do not retry it
into passing.

## 6. Commit

Stage explicit paths, never `git add -A`, because a background agent may
share this tree.

The commit message is the record of the reasoning: what was wrong, what
was believed that was false, what was chosen and what was turned down.
Close the issue from it, so the thread ends with the code:

```
Closes #<n>.
```

Push only when the maintainer asks. Committing is not permission to push.

## 7. Report

- the issue, and the commit that closes it
- the test that now fails without the fix
- the numbers from verification, not an impression
- anything split out, by new issue number
- what a host has to do, if anything
