---
name: jan-orient
description: Orient on the Janela repository at the start of a session. Reads the intent, the decisions, recent work and open issues, loads the hard constraints and the known traps, then reports where things stand and waits. Use at the start of any Janela development session, or after a handoff.
---

# Orient on Janela

Get a cold session up to speed on this repository, then stop. Orientation
is reading, not doing: do not start work, suggest a plan or run anything
that changes state.

## 1. Read the intent

Read these in full, in this order. They are short on purpose.

1. `CLAUDE.md` for the hard constraint and the vision.
2. `docs/decisions/INDEX.md` for which decisions already exist.
3. `docs/naming.md` for why the vocabulary is what it is.

## 2. Survey the state

Run these together:

```bash
git log --oneline -12
git status --short
ruby -e 'require "./lib/janela/version"; puts Janela::VERSION'
gh issue list --state open --limit 50
gh run list --branch main --limit 4
```

Then look at `CHANGELOG.md`. If it has an `[Unreleased]` section, `main`
has moved past the published gem, and the README may already describe
things a host installing from RubyGems cannot use yet.

## 3. Load the hard constraints

Hold these for the whole session. They are not preferences.

- **No host application in this repository.** No host's name, models,
  tables, domain or business logic, in code, prose, ADRs, commit
  messages or tests. The demo in `test/dummy` stands in for every host.
- **The demo is wired the way the docs teach, or it proves nothing.** A
  stand in wired differently to the documentation cannot catch a bug in
  the documentation's wiring. #46 survived a full test suite because the
  demo published `policy_scope` to the view with `helper_method`, which
  `docs/multi-tenancy.md` never asks a host to do; the shape the guide
  actually teaches was the one shape nothing covered. When a guide and
  the demo disagree, that gap is where the next bug is.
- **Built to be forked (ADR 001).** Prefer one obvious way over
  configuration. Every setting has to earn itself (ADR 021, ADR 023).
- **Decisions are ADRs.** Read the relevant ones before building
  anything adjacent. An accepted ADR is never rewritten; a later one
  supersedes it and says so.
- **Breaking change is communicated (ADR 015).** Any rename or changed
  behaviour a host can see goes in `UPGRADING.md`, and the doctor is
  taught to find the old form where it can be found.
- **House style.** Australian English. No double hyphen used as
  punctuation anywhere. Comments say why, not what. No obviously
  generated prose in anything published.
- **Commit only when asked.** Stage explicit paths, never `git add -A`.

## 4. Load the known traps

Each of these cost real time once. Do not rediscover them.

- **Gem assets need a server restart in development.** Propshaft only
  rescans when the Rails reloader fires, and editing a file under
  `app/assets` in the gem does not fire it. A change that seems to do
  nothing usually has not been served yet.
- **A turbo frame's `src` does not describe what it shows.** Turbo can
  render a response that was already in flight and label the frame with
  a newer `src`. Janela keeps its own record of what it asked a pane for
  and cancels any other request (#33). Never reason from `src`.
- **Stimulus value callbacks run on connect.** On a page opened from a
  filtered link, the previous value handed to `filtersValueChanged` is
  the default empty object, not nothing. Track what was applied rather
  than trusting that argument.
- **A CSS transform replaces an SVG `transform` attribute.** It does not
  compose with it. Put a fixed transform on a wrapping group and animate
  the inner one.
- **Browser tests must wait for the dashboard, not its numbers.** Numbers
  are rendered on the server before any JavaScript runs. The system test
  base class waits for the frame controller and for every pane's first
  load; a new test that visits a page gets that for free.
- **The SQLite test database is shared.** Two test processes at once
  produce dozens of unrelated failures. Check nothing else is running
  before believing a sudden wall of red. To run the suite many times,
  copy the whole tree once per worker rather than sharing one.
- **A seed does not reproduce an order under `rake`.** The task shuffles
  the file require order before minitest reads the seed, so the same seed
  gives a different order every run (#37). Reproduce an ordering by
  requiring the files yourself in one `ruby -Ilib:test:.` process.
- **A setting read at class definition time cannot be swapped back.**
  `Janela::ApplicationController` resolves `Janela.parent_controller`
  when it is autoloaded, so anything that changes that setting and then
  causes a load has changed it permanently, whatever its `ensure` block
  restores. The same is true of a host that assigns it after boot: it
  works or does nothing depending on what has been loaded (#37).
- **An engine migration is installed from the root and run from the
  dummy.** `bin/rails app:db:migrate` at the repository root resolves the
  relative `db/migrate` against the working directory, so it reads the
  engine's own migrations beside the dummy's copies of them and aborts on
  a duplicate migration name. Install with
  `bin/rails app:janela:install:migrations` from the root, then run
  `bin/rails db:migrate` from `test/dummy`.
- **A wall of fixture errors is usually a stale bundle, not a broken
  suite.** `Gemfile.lock` is not checked in, so a tree that has not run
  `bundle install` since an older version fails every test at fixture
  load. It reads like a catastrophe and is one command.
- **The demo scopes only Janela's own records.** `test/dummy`'s
  `policy_scope` filters `Janela::Frame` and `Janela::Snapshot` by owner
  and answers `model.all` for everything else, so for its own models the
  demo is a model layer host rather than a policy scoped one. Anything
  that needs a host whose policy narrows its own data has to narrow that
  one method for the duration. #47 was filed with a measurement that
  assumed otherwise, and the numbers in it only appear once `Order` is
  scoped too.
- **The demo image is built from `.dockerignore`.** Anything the running
  demo reads from disk has to be allowed in, or it works locally and in
  CI and fails only in production. Check `/version` and the new pages
  after a deploy.

## 5. Report and wait

Reply in a few short lines:

- the released version, and whether `main` is ahead of it
- what landed most recently
- anything uncommitted, and whether it looks deliberate
- CI on `main`, green or not
- the open issues that look most pressing, by number

Then stop, and wait for direction.
