---
Date: 2026-09-22
Status: Accepted
Related: ADR 011, ADR 015, ADR 016, ADR 021, ADR 023
Triggers:
  - adding a class, a custom property or a rule to either stylesheet
  - deciding whether a piece of look belongs to the gem or to a theme
  - writing a theme, or reading one somebody else wrote
  - renaming anything a stylesheet targets
  - adding a helper that renders markup a host will style
Topics: styling, theming, host-integration, naming, public-api, releases
---

# ADR 036: Janela Publishes What a Theme May Target, and Vitral Is Only One

## Context

ADR 023 split the styling in two: `janela.css` is structure, frozen and
boring, and `vitral.css` is taste, free to move. That was the right cut
and it has held for the theme. It no longer describes the other file.

### What `janela.css` actually contains

Counted by where each name is used, in the engine's own views and in the
demo standing in for a host:

| Group | Names | Where they appear |
| --- | --- | --- |
| The grid scale | `janela-cols-1..12`, `janela-gap-0..8`, `janela-span-1..12` | chosen by a frame's own integers (ADR 016) |
| Pane primitives | `janela-frame`, `janela-pane`, `janela-value`, `janela-value-label`, `janela-value-number`, `janela-chart`, `janela-empty`, `janela-error` | in a host's own pages, wherever a pane is rendered |
| The engine's own chrome | `janela-card`, `janela-button`, `janela-crumb`, `janela-flash`, `janela-page`, `janela-form`, `janela-field`, `janela-heading`, `janela-subheading`, `janela-list`, `janela-list-row`, `janela-list-name`, `janela-actions`, `janela-exit`, `janela-hint`, `janela-muted`, `janela-danger`, `janela-errors` | only Janela's own pages: 2 to 6 engine views each, and none in the demo but `janela-form`, twice |

The third group is a small UI kit for pages a host may never visit. ADR
016 said "the class names are public API", meaning renaming one is
breaking and belongs in `UPGRADING.md`. Applied to the third group that
is a promise made to nobody, about markup only the engine renders, which
makes the engine's own pages harder to change than the thing the gem is
for.

### A theme other than vitral already works

`Janela.theme` is one line in the engine's layout,
`stylesheet_link_tag Janela.theme if Janela.theme.present?`, so it
resolves any stylesheet name against the host's own asset paths. Measured
against Janela's own layout:

```
"vitral"         -> janela.css + vitral.css
"application"    -> janela.css + the host's own application.css
"no_such_theme"  -> raises, "The asset 'no_such_theme.css' was not found in the load path"
nil              -> janela.css alone
```

So somebody else's skin needs nothing built. What it needs is to know
what it may target, and today nothing says. A theme author reads
`vitral.css` to find out, which makes every name vitral happens to use
into an accidental interface, and makes the three groups above
indistinguishable.

### Four open issues are the same question

`#26` a caption that cannot be hidden without losing it for screen
readers, `#29` inter-pane layout being entirely the host's problem, `#30`
a categorical palette, `#31` a single value pane with no typography and
no way to say how prominent it is. Each one asks where a piece of look
belongs, and each has been answered one at a time so far, which is how a
split stops meaning anything: `janela.css` grew a UI kit that way,
without anyone deciding it should.

### Options considered

**Leave it, and decide each issue as it comes.** What has been happening.
It produced the drift above and gives a theme author nothing to read.

**A third stylesheet**, splitting the engine's own chrome out of
`janela.css`. Tempting and rejected on ADR 023's own consequence: a third
file is a third thing every Sprockets host has to declare for
precompilation, and #14 says the second one is already a rough edge. The
problem is a missing promise, not a missing file.

**Rename the chrome to mark it private**, `janela-internal-card` or
similar. Rejected: the rename is itself the breaking change it is trying
to make unnecessary, paid now for a benefit that is only cosmetic. Saying
which names are the contract costs nothing and is just as clear.

**Move the pane primitives into the theme**, so a host with no theme gets
unstyled panes. Rejected: a pane has to be legible on install, which is
ADR 016's founding reason, and #26 is the sharp case, since hiding a
caption accessibly is correctness rather than taste and a host that never
opts into a theme still needs it.

## Decision

**Janela publishes the hooks; a theme supplies the taste. What a theme
may target is written down, and what is not written down is Janela's own
chrome.**

**Three layers, named, in two files.** No new stylesheet.

- **The grid scale and the pane primitives are the contract.** These are
  what a host's own pages contain and what a theme targets. Renaming one
  is breaking and goes in `UPGRADING.md` with the doctor taught to find
  the old name (ADR 015).
- **The engine's own chrome is not the contract.** The classes only
  Janela's own views render may change in any release. A host restyling
  Janela's own pages is welcome to target them and should expect to
  revisit it, which is the honest version of what was already true.
- ADR 016's "the class names are public API" is **narrowed, not
  superseded**: it is true of everything a host's markup contains, and
  was never meant as a promise about the engine's breadcrumbs.

**`docs/theming.md` carries the contract**, because a theme author is not
going to read an ADR to find a class list. It names the two layers, every
class in them, every custom property, and what a theme is expected to
leave alone. Shipped in the gem beside the other docs.

**A theme is any stylesheet the host names, and vitral is one of them.**
Nothing more is built for this: `Janela.theme = "midnight"` already
resolves against the host's asset paths, and a name that does not resolve
already raises rather than failing quietly. What changes is that this is
documented and supported rather than merely true, so a third party can
publish a theme against a contract instead of against whatever vitral
happens to do this month.

**Where a new piece of look goes.** The rule that answers the four open
issues without arguing each one separately:

- Something a pane needs in order to be correct or legible on install is
  a **hook**, and belongs in `janela.css` on the contract. A caption that
  is announced but not seen is this (#26).
- Something that is a choice about appearance is **taste**, and belongs
  in a theme. A categorical palette is this (#30).
- Something a host arranges is **layout**, and belongs in the grid scale
  as an integer that selects a rule, never as a value interpolated into a
  style attribute (ADR 016). Prominence for a single value pane is this
  (#31), and so is inter-pane layout (#29).

Where a feature has both halves, the hook ships in `janela.css` and the
taste in the theme. A palette is the clean example: the class that marks
which series a mark belongs to is a hook, and the colours it resolves to
are a theme's.

**Vitral stays in this repository**, and stays one theme among any
others. It is the reference implementation of the contract, which is a
reason to keep it here rather than to privilege it: if a rule cannot be
written against the published names, the contract is wrong.

## Consequences

- A theme author has something to read, and a theme written against
  `docs/theming.md` keeps working across releases in a way one written
  against `vitral.css` never could.
- The engine's own pages get easier to change, because their markup stops
  being an interface. That is a real loosening: a host that today targets
  `janela-card` will find it moves one day, and the doc says so rather
  than leaving them to discover it.
- Writing the contract down means reading every class in both files once
  and deciding which side it is on. That is the work, and it is the point.
- **Not decided here: whether Vitral grows to answer #29, #30 and #31.**
  This says where each half of each of those belongs; it does not commit
  to building them, and a component library large enough to lay out a
  host's page is its own decision against ADR 001's preference for
  staying small enough to fork.
- A theme is still linked only into Janela's own layout. A host wanting
  the look on its own pages links the stylesheet itself and uses the
  theme's public classes, exactly as ADR 023 decided. The contract does
  not change that asymmetry, it explains it.
- What would change this decision: the engine's own chrome turning out to
  be something hosts genuinely restyle, in reports rather than in
  anticipation, at which point it has earned the promise this declines to
  make and should be moved onto the contract deliberately.
