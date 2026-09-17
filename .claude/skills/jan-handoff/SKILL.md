---
name: jan-handoff
description: Write a self contained handoff prompt for Janela work so a fresh session can pick up where this one stopped. Records any unwritten decisions first. Use before clearing a long session or handing work to another agent.
---

# Janela handoff

Produce one prompt a cold session with no history can read and be
oriented by. The receiving session orients and waits; it does not carry
on by itself.

## 1. Do not hand off stranded decisions

Scan the session for choices that shaped the work but are not yet in an
accepted ADR, the changelog, an issue or the known traps in `/jan-orient`.
Record each now, briefly if need be. A handoff that carries a decision
only in the prompt loses it the moment the prompt is gone.

If something cannot be recorded without an answer from the maintainer,
say so in the prompt under what is waiting.

## 2. Survey

```bash
git log --oneline -6
git status --short
gh run list --branch main --limit 2
```

Note what was being worked on, what landed, what is uncommitted and
whether that is deliberate, and the single next action if there is one.

## 3. Write the prompt

Use XML tags rather than markdown: the reader is another session reading
raw text, and tags keep the sections unambiguous.

```
<handoff>
<resuming>One line naming the work.</resuming>

<done>
- Two to four bullets: what landed, with commit hashes, and the decisions made, with ADR numbers.
</done>

<state>
- The branch, whether it is pushed, and what is uncommitted.
- CI on main, and the released version against main.
- Files at the centre of the work, by path.
</state>

<waiting>What needs an answer or a decision, or "nothing".</waiting>

<next>The single next action, or "none, awaiting direction".</next>

<orient>Run /jan-orient, confirm you have read this, and wait for direction. Do not start work.</orient>
</handoff>
```

Rules:

- Under 300 words. This is orientation, not a history.
- Every claim is checkable: a hash, a path, an issue number.
- If the work has landed cleanly, say "none, awaiting direction" rather
  than inventing a next step.
- Nothing in the prompt names a host application.

## 4. Deliver

Print the prompt in a fenced block so it copies cleanly. Do not commit
anything that was not already agreed.
