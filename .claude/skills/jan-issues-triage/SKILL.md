---
name: jan-issues-triage
description: Triage every open Janela issue and assess what to do with each. Reads each issue in full, checks it against the decisions, the 1.0 plan and the code, says whether it is done, a bug to fix before a release, ready to build, waiting on an ADR, waiting on the maintainer, or for later, and judges whether to release now or keep iterating. Read only until told to apply anything. Use when issues have piled up, before choosing a release, or when asked what to do with the backlog.
argument-hint: [optional focus, such as "bugs only" or "since 0.13.0"]
---

# Triage the open issues

`/jan-whats-next` picks the next piece of work. This reviews all of them and
gives each a disposition, so the backlog stops being a flat list. It changes
nothing on GitHub until the maintainer says so.

If an argument was given, use it as a filter throughout.

## 1. Read every issue in full

A title is a hunch, and so is a label. Read the body and the comments of every
open issue, because an earlier investigation may already be on the thread and
a body often says things the title does not (a bug filed as a feature, a
feature that is really two).

```bash
gh issue list --state open --limit 100 --json number,title,labels,createdAt,updatedAt,author,comments,body \
  --jq '.[] | "### #\(.number) \(.title) [\(.labels|map(.name)|join(","))] \(.createdAt[0:10])\n\(.body)\n\(.comments|map("-- \(.author.login): \(.body)")|join("\n"))\n"'
```

`gh issue view <n> --comments` fails on this repository because of a deprecated
projects field, so ask for JSON as above.

For a long list, read in batches and keep a one line note per issue as you go.
Do not triage from the list view alone.

## 2. Load what the answers depend on

- `docs/decisions/INDEX.md`, then every ADR the issue's topic lists. An issue
  that contradicts an accepted ADR is a decision, not a task.
- ADR 037 and `docs/roadmap.md`: what 1.0 means and what is in or after it.
- The soak issue (`gh issue list --label documentation`, the one titled soak):
  its exit rule decides what a new public surface costs. Anything that changes
  the public surface resets the clock.
- `CHANGELOG.md` down to the last release, `git log --oneline` since that tag,
  `gh run list --branch main --limit 4`.

## 3. Assess each issue on the same questions

Answer these in this order and stop at the first that decides it.

1. **Already done?** Work lands without its issue being closed. Search the
   code and the log for what the issue asks (`git log --oneline --grep`,
   `grep`). If it is done, say what settled it. Closing is the maintainer's
   call.
2. **What does it claim, and is it checked?** Say whether you reproduced it,
   read the code that shows it, or are only repeating the issue. Never
   upgrade a claim you have not checked. A cheap check (one command or one
   grep) is worth doing here; a real reproduction is `/jan-issue-investigate`'s
   job, so mark the issue as needing one.
3. **Is it a bug, and what does it do to a reader?** A silently wrong number
   comes first. A failure that takes a whole page down for one bad row comes
   next. Cosmetic and demo only come last.
4. **Does it change the public surface?** A pane option, a URL parameter, a
   DSL word, a helper argument, a published class, a public method, a column.
   If yes it needs an ADR (ADR 015, ADR 037), it resets the 1.0 soak, and it
   belongs in a batch rather than alone. If no, it can ship in a patch.
5. **Does the decision already exist?** Name the ADR. If one covers it, the
   work is to follow it. If none does and the choice is real, it needs
   `/jan-adr`. If it contradicts one, it needs a superseding ADR.
6. **Where did it come from?** Raised by someone using the gem outranks one
   from reading the source (ADR 037's test for "the 5% not finished"). Say
   which, without naming a host application in anything posted to GitHub.
7. **Does it overlap another issue?** Group issues that share a cause, a
   design or an ADR. One ADR often settles several, and building one of them
   alone can make a second one's shape wrong.
8. **Is it in scope?** Check it against ADR 001 and the README's list of what
   Janela will not be. An issue for something a host's own code should do is
   a candidate to close into the out of scope list, which is the maintainer's
   decision to make.

## 4. Give each issue one disposition

- **Fix before the next release.** A bug that is wrong, breaks a page, or
  weakens scoping. Bounded and decided.
- **Ready to build.** Bounded, decisions made, no surface change or the ADR is
  accepted.
- **Investigate.** Not reproduced, or the issue and the code disagree.
  `/jan-issue-investigate`.
- **Needs an ADR.** A real design choice or a surface change with none
  recorded. `/jan-adr`.
- **Needs the maintainer.** A choice or an answer only they can give. Say what
  the choice is and give a recommendation.
- **Later (Horizonte).** Wanted, not blocking, not a refusal.
- **Close.** Done, a duplicate, or out of scope. Say what to point at.
- **Needs information.** The issue cannot be assessed as written. Say what is
  missing.

## 5. Judge the release

State plainly whether to release now or keep iterating, with the reason:

- Anything under "Fix before the next release" argues for finishing it first.
- An `[Unreleased]` section a host would notice argues for a release, since the
  README then describes a gem nobody can install.
- Each surface changing issue added before a release restarts the soak. One
  batch and one soak is usually better than a sequence of small ones; a stream
  of additions with no release is how 1.0 keeps sliding.
- Red CI on `main` outranks all of it.

Say what the soak clock does under each option.

## 6. Report

Short, in this order. Lead with the verdict.

```
## Verdict
Release now, or finish X first, in one or two sentences.

## Fix before release
#n title: why, and what a fix changes

## Ready to build
#n title: one line, in the order to do them

## Needs an ADR, grouped
#a, #b, #c: the one decision that settles them

## Needs you
#n: the choice, and my recommendation

## Later, close, or needs information
#n: one line each, with the pointer

## Checked and not checked
What was read, reproduced or only taken from the issue
```

If an issue is too uncertain to place, say so and put it under "Investigate"
rather than guessing.

## 7. Apply only when asked

When the maintainer agrees, apply exactly what was agreed and nothing else:
labels with `gh issue edit`, a comment saying what was found. Comments are
public and the repository is open source, so no host application's name,
models or domain in them, and house style applies: Australian English, no
double hyphen as punctuation. Never close an issue without being told to.
Offer `/jan-issue-investigate` for the ones marked Investigate.
