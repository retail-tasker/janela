---
name: jan-retro
description: Run a retrospective on a stretch of Janela work, such as a session, a release or a hard bug. Finds what went wrong, what was learned and what was decided without being written down, then records each in the right place: an ADR, an issue, the changelog or the known traps in /jan-orient. Use after a release, after a bug that took more than one attempt, or before closing a long session.
---

# Janela retrospective

A retro is worth running only if it changes something on disk. The output
is not a summary of what happened; it is decisions recorded, issues filed
and traps written down, so the next session does not repeat this one.

An argument may name the scope: a version such as `0.4.0`, an issue such
as `#33`, or `session` for the current conversation. With no argument, use
everything since the most recent tag.

## 1. Establish what happened

```bash
git describe --tags --abbrev=0
git log --oneline <that tag>..HEAD
gh issue list --state closed --limit 20 --json number,title,closedAt
gh run list --branch main --limit 10
```

Read the commit messages in full for the range, not just their titles.
This project writes the reasoning into its commits, so they are the
primary record. If the scope is the current session, the conversation is
the record as well.

## 2. Look for four things

Work through each. Name concrete evidence for every finding: a commit, a
failing test, an error, a number.

**What broke, and how it was found.** A test that went red, a bug a
person reported, something wrong only in production. For each: was it
caught by a test, or by luck? If by luck, what test would have caught it?

**What took more than one attempt.** A fix that had to be redone is the
most valuable thing a retro finds, because the first attempt reveals a
wrong belief about how something works. Write the wrong belief down in a
sentence.

**What was decided but not recorded.** Scan for choices that shaped the
code: a rule about naming, a setting added or refused, a trade off
accepted. If an accepted ADR does not already hold it, it is stranded.

**What was measured.** Failure rates, contrast ratios, timings, run
counts. Numbers that justified a decision belong next to that decision.

## 3. Record each finding where it belongs

Every finding goes to exactly one home. Do not leave any in the reply
alone.

| Finding | Home |
| --- | --- |
| A design decision | A new ADR, via `/jan-adr`, or a superseding one |
| A trap that cost time and will cost it again | The known traps list in `.claude/skills/jan-orient/SKILL.md` |
| Work not done, a gap named but not closed | A GitHub issue, with the evidence in its body |
| Something a host can see that changed | `CHANGELOG.md`, and `UPGRADING.md` if they must act |
| A wrong belief about how Turbo, Stimulus, Rails or Ransack behave | The known traps list, stated as the true behaviour |

Rules while recording:

- Never edit the Decision or Context of an accepted ADR. Supersede it.
- A trap is written as the true behaviour and what to do about it, not as
  a story about the session.
- An issue body carries the reproduction and the evidence, so it can be
  picked up cold.
- Keep the host constraint from `CLAUDE.md`: nothing recorded names a
  host application.

## 4. Report

Short, and lead with what changed on disk:

- **Recorded:** each file written or issue filed, with its path or number
- **The wrong beliefs:** one line each, true behaviour first
- **Still open:** anything found but not recorded, and why

Nothing is committed without being asked.
