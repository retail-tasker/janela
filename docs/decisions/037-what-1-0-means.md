---
Date: 2026-09-23
Status: Accepted
Related: ADR 001, ADR 010, ADR 015, ADR 021
Triggers:
  - deciding whether an open issue belongs in the next release
  - proposing a feature, or arguing that one is out of scope
  - cutting a release and choosing the version number
  - deciding whether a breaking change is still affordable
  - wondering whether the project is drifting
Topics: vision, scope, forkability, releases, roadmap, planning
---

# ADR 037: 1.0 Means the Surface Stops Moving, Not That Janela Is Finished

## Context

Janela has a vision and a backlog and nothing in between. ADR 001 says
what the project is, the load-bearing 5% of a BI tool, and the README's
Design section lists what it will never be: natural-language query, a
warehouse, a row-level-security subsystem, a scheduling UI, an embedding
SDK, a mobile app, paginated reports. That is a stronger statement of
scope than most libraries manage. What neither says is what order things
happen in, or what has to be true before a host can build on this
without expecting the ground to move.

The gap shows up in three measurements taken today.

**The surface moves every release.** Counting entries marked breaking in
`CHANGELOG.md`: 0.5.0 carried one, 0.7.0 carried two, and the unreleased
section carries two more. Five breaking changes across four releases in
five days, every one of them correct and every one of them announced the
way ADR 015 requires. This is what alpha is for and there is nothing to
apologise for in it. It also means nobody outside this repository can
build anything on Janela yet, because the DSL, the helpers, the pane
URLs and the class names a theme targets have all changed underneath a
host at least once.

**The declared horizon ran out.** The `Before public release` milestone
stands at ten closed and one open. It worked, it is nearly spent, and
nothing replaced it. Thirteen of the fourteen open issues carry no
milestone at all.

**The issue list cannot rank itself.** Eight of those issues are
enhancements, four of them raised from a real install, and none has been
picked up while the last four releases went to hardening. That looked
like drift and is worth being precise about, because it was not. ADRs
025, 032, 034 and 035 are one argument made four times: Janela refuses
rather than guesses about scope. Bounded predicates, a refused unscoped
read, a refused unnamed snapshot scope, and a doctor that reports what it
actually saw. That is the most coherent stretch of work in the project.
The problem is that the theme was never declared, so it was invisible
while it was happening, and now that it is finished there is nothing
declared to follow it. A flat list of fourteen issues is what a project
looks like between themes when it has no way of saying so.

Three options were considered.

**A roadmap with dates or quarters** was rejected. This project's
throughput is not predictable enough to commit to a calendar, and a
published roadmap that slips teaches people to stop reading it. The cost
is ongoing and lands every release; the benefit is mostly the appearance
of planning.

**Leaving it to the issue list** was rejected because that is the current
state, and the current state is what prompted the question. Labels
describe what an issue is. Nothing describes what it is for.

**Declaring 1.0 feature-complete** against what a commercial BI tool ships
was rejected for contradicting ADR 001 outright. Janela is not trying to
reach parity with anything. A 1.0 defined as "the features are all there"
has no end, because the list it is measured against is somebody else's.

## Decision

**1.0 means the public surface stops moving, the 5% can be read, and the
doctor can be trusted. It does not mean Janela is finished, and it is not
a feature count.**

Three claims, each of which can be checked rather than argued about.

**The public surface stops moving.** After 1.0, everything
`docs/theming.md` lists as the contract, the measures and dimensions DSL,
`janela_pane` and `janela_frame`, the pane URL shape and the dashboard
filter parameters change only on a major version. Before 1.0 they may
change in any release, with the upgrade note ADR 015 requires. This is
the load-bearing claim and the other two exist to serve it: a surface is
only worth freezing once it is the right shape, which is why the feature
work below sits inside 1.0 rather than after it. Freezing an API that is
missing a limb only guarantees the limb arrives as a breaking change
later.

**The 5% can be read.** Janela draws three renderers, `table`, `bar` and
`line`. A part-to-whole split has to be drawn as two bars. A table pane
carries exactly two cells per row, so a label that needs context to be
understood cannot have any. A chart takes Chart.js's 2:1 default and a
host cannot correct it from outside. None of these is a feature beyond
the 5%; each is the 5% not finished, and the distinguishing test is that
four of them were raised by someone trying to use the gem rather than by
someone reading its source. The theme that follows "Janela refuses rather
than guesses" is legibility: a pane a person can actually read.

**The doctor can be trusted.** ADR 021 holds that a check people stop
trusting has stopped working. Every check in `CHECKS` bar two now has a
test that makes it fire and one that leaves it quiet.

The open issues sort as follows, and this sort is the substance of the
decision rather than an illustration of it.

In 1.0: #14 (a Sprockets host serves the engine's JavaScript or is told
it cannot), #53 (the last two untested checks), #27 (a ratio measure, so
the refusal in #20 offers somewhere to go), #30 (doughnut and pie, and
the categorical palette that makes them readable), #31 (a pane says how
prominent it is), #34 (a table carries an attribute column beside its
label), #24 (a chart's height is the host's to set), and #6 (how
contributions are accepted, who cuts a release, where to report a
vulnerability privately).

After 1.0: #18 (drill-down on time panes, which ADR 006 excluded
deliberately and which needs an ADR of its own before any code), #41 (a
command palette, which the issue itself argues belongs to the demo and
not the gem), and #45 (a cosmetic scroll drift on one demo page, where
the issue already allows that deciding not to fix it is a legitimate
answer).

Neither, and tracked as itself: #5 is an upstream pin on ActiveSupport
and is removed when ActiveSupport is fixed. #56 is a one-in-160 test
flake deliberately recorded rather than chased, and is evidence, not
work.

Needing a decision rather than a place: #29 asks Janela to help arrange
panes on a page. ADR 011 has panes not rendering in the host's layout and
ADR 001 prefers a fork to a configuration surface, so the default answer
is that arrangement belongs to the host and the issue closes into the
README's out-of-scope list. That is a scope decision and gets argued on
its own rather than settled here by omission.

**The roadmap is published rather than kept in the issue tracker.**
`docs/roadmap.md` ships in the gem and renders on the demo at
`/docs/roadmap`, because the demo reads the gem's own markdown rather
than restating it (ADR 010). One file is therefore the public statement,
the page a visitor reads and the copy in the installed gem at once. The
GitHub milestone remains the working tracker and the progress bar; it
says which issues, while the document says what the release is for. A
reader who has to open an issue tracker to find out where a library is
going has been told to do the maintainer's filing.

## Consequences

- A breaking change is cheap now and expensive after 1.0. Anything that
  wants to change the DSL, the helpers or the published class names
  should be argued for before 1.0 rather than after, and the sort above
  is deliberately biased that way.
- An issue outside 1.0 is not rejected. It is not blocking a release,
  which is a different and weaker statement, and the roadmap says so in
  those words so that nobody reads the list as a refusal.
- The eight issues in 1.0 are a commitment made in public. That is the
  point of publishing it and also its only real cost: a roadmap on the
  website can be held against the project in a way a milestone cannot.
- The current release is 0.8.0 and not 1.0, which this ADR answers
  without further argument, because it carries two breaking changes.
- `docs/roadmap.md` has to be updated when a release lands, or it becomes
  the stale artifact this ADR rejected dated roadmaps for being. It is
  named in `/jan-release` for that reason.
- The README's Design section currently says snapshots are "not built
  yet" and they shipped in 0.7.0. Publishing a roadmap beside a stale
  status line makes the staleness worse, so that sentence is corrected in
  the same change.
- What would change this decision: a real install blocked by something in
  the after-1.0 list. The sort is a judgement about what a host needs to
  read a dashboard, and a host saying otherwise is better evidence than
  the judgement.
