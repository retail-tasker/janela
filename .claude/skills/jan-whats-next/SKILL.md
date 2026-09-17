---
name: jan-whats-next
description: Recommend what to work on next in Janela, from the open GitHub issues, the decisions, CI, and any gap between main and the released gem. Use when deciding the next piece of Janela work. Accepts an optional constraint such as "something small" or "no new ADRs".
---

# What's next for Janela

Produce one clear recommendation and a short ordered list, grounded in the
repository rather than in memory.

If an argument was given, such as "something small", "docs only" or
"before the next release", apply it as a filter throughout.

## 1. Gather

Run these together:

```bash
git log --oneline -10
git status --short
gh issue list --state open --limit 50 --json number,title,labels --jq '.[] | "#\(.number) \(.title) [\(.labels | map(.name) | join(","))]"'
gh issue list --state closed --limit 10 --json number,title --jq '.[] | "#\(.number) \(.title)"'
gh run list --branch main --limit 3
```

Read `CHANGELOG.md` down to the first released version, and
`docs/decisions/INDEX.md`. List `docs/decisions/` and read the three most
recent ADRs, because they show where the project is heading.

## 2. Check for drift before anything else

Two kinds of drift outrank ordinary work, because they mislead people:

- **Released drift.** An `[Unreleased]` changelog section with anything a
  host would notice means the README describes a gem nobody can install
  yet. Recommend a release.
- **Red CI on `main`.** Recommend fixing it first, whatever it is.

## 3. Rank the rest

- **A bug that shows a wrong number** comes before any feature. A
  dashboard that is silently wrong is the worst failure this library has.
- **Anything security shaped** comes next: scoping, filters that widen
  what can be read, unbounded queries.
- **Issues labelled `needs-adr`** cannot be built yet. The next step for
  one of those is a draft ADR (see `/jan-adr`), not code.
- **Everything else**, by how much it unblocks, then by what a host
  would feel.

Check each candidate against the ADRs its topic touches. If the work
would contradict an accepted decision, say so: it needs a superseding ADR
first.

Watch for issues that are already done. Work often lands without its
issue being closed. If an open issue describes something the code already
does, recommend closing it with a pointer to what settled it.

## 4. Report

```
## Recently shipped
2 or 3 bullets

## In progress
anything uncommitted or unreleased

## Recommended next: <item>
Why this one, in two or three sentences, naming the ADRs it touches.

## Then
1. <item>: one line on why
2. <item>: one line on why
3. <item>: one line on why

## Blocked or needs a decision
Anything that needs an ADR or an answer from the maintainer first.

## Stale
Open issues that look already done, if any.
```

Be direct. One recommendation, not a menu.
