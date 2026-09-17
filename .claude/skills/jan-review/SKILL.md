---
name: jan-review
description: Have a different model review Janela work independently. Dispatches a fresh agent on a model other than this session's, with a self contained brief and no shared context, then reports its findings ranked by severity. Use before a release, after a large or subtle change, or whenever a second opinion is worth more than another pass by the same model. Pass what to review, and optionally which model.
disable-model-invocation: true
argument-hint: [what to review] [model]
---

# Independent review by a different model

A session cannot audit itself. It shares every assumption it made while
writing the code, so it re-reads its own reasoning and finds it sound.
A different model, with no access to this conversation, does not.

## 1. Choose the model and the scope

Pick a model **other than the one this session is running on**, which is
the whole point: the argument wins if it names one, otherwise choose any
available model that is not this one. Pass it as `model` on the Agent
tool. A review by the same model that wrote the code is a second pass,
not a second opinion, so say so plainly rather than running one.

**Never use `subagent_type: "fork"`.** A fork inherits this
conversation and this model, which defeats the point twice over. Use
`general-purpose`.

Scope, from the argument or by default the uncommitted work:

```bash
git status --short
git diff --stat
git log --oneline -5
```

## 2. Write a brief that stands alone

The reviewer starts cold. Anything it is not told, it cannot use, and
anything it has to guess it will guess wrong. The brief must carry:

- **What Janela is,** in two sentences: a Rails engine for cross
  filtering dashboards declared on ActiveRecord models.
- **The scope,** as explicit paths and commit range. Never "the recent
  work".
- **Where the rules live:** `CLAUDE.md` for the hard constraint,
  `docs/decisions/INDEX.md` for the decisions, and the specific ADR
  numbers the change touches. Tell it to read them rather than assume.
- **The intent of the change,** in a few lines: what problem it solves
  and what was deliberately not done. A reviewer that does not know the
  intent reports the design as a defect.
- **What was already verified,** with the numbers, so it spends its
  effort elsewhere rather than repeating the suite.
- **Permission to run things.** It has the repository. Tell it to run
  the tests, read the code and check claims rather than reasoning from
  the diff alone.

## 3. Demand a shape of answer

Ask for findings only, ranked, each with:

- **Severity:** correctness, security, then design, then style.
- **The failure:** concrete inputs or state, and the wrong result. A
  finding with no way to be wrong is an opinion, and opinions go last
  under one heading or are left out.
- **Where:** file and line.
- **Whether it verified it,** by running something, or only read it.

And demand the two things a reviewer usually omits:

- **What it could not check,** and why.
- **What it thinks the change gets right,** briefly. This is not
  flattery; a reviewer that finds only faults has not understood the
  intent, and saying what holds shows whether it did.

Tell it plainly: do not fix anything, do not commit, do not stage. It
reviews and reports.

## 4. Dispatch

One Agent call, `general-purpose`, with the model override and the brief
as the prompt. It runs in the background; wait for it rather than
starting a second reviewer. If several independent angles are genuinely
wanted, dispatch them in one message so they run at once, with one
concern each.

## 5. Triage what comes back, do not obey it

The reviewer is cold and confident, which is the point and also its
weakness. For each finding, before acting:

- **Check it.** Reproduce the failure or find the line. A finding that
  cannot be reproduced is reported to the maintainer as unconfirmed, not
  fixed on faith.
- **Check it against the ADRs.** A reviewer with no history will
  routinely propose something an accepted decision already turned down,
  usually a setting, an abstraction or a second way to do one thing.
  That is a decision to cite, not a defect to fix.
- **Check the house style claims.** Australian English and the ban on
  the double hyphen are this project's rules; a reviewer may call them
  errors.

## 6. Report

- **Confirmed,** each with what was reproduced, most severe first.
- **Rejected,** each with the reason, naming the ADR where one applies.
- **Unconfirmed,** needing the maintainer's judgement.
- **What it could not check.**

Then ask before fixing anything, unless the maintainer has already said
to fix what comes back. A review is information, and acting on all of it
without judgement is how a second opinion becomes a worse first one.
