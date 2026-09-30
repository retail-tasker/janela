---
Date: 2026-09-30
Status: Accepted
Related: ADR 016, ADR 029, ADR 036, ADR 037, ADR 047
Triggers:
  - a pane that should be a hero number, or a footnote
  - changing the size or weight of a single value pane
  - adding a column to janela_panes, or a class to the scale in janela.css
  - deciding what a setting does on a renderer it is not meant for
  - a host writing CSS against janela-value-number to make one count bigger
Topics: css, layout, styling, public-api, panes, frames, urls
---

# ADR 050: A Single Value's Prominence Is One of Three Steps, and Unset Changes Nothing

## Context

#31, raised from a real install, said a single value pane has no typography
and no way to say how prominent it is. Investigated against the current code,
two of its three parts were already answered and the issue predates them.

**Default typography exists.** #15 shipped it: `.janela-value-number` is
`2rem`, weight 600, with tabular numerals, and the label is `0.85rem` at 70%
opacity (`janela.css`, documented in `docs/theming.md`). On the demo the
headline number is twice body size. Vitral adds tightened letter spacing on
top.

**The duplicated label has an answer.** #26 shipped `.janela-own-headings`,
which hides the value's label, a table's caption and a chart's title from
sight while keeping them in the accessibility tree, on any ancestor.

**What is left is the middle part, and it is real.** Every single value is
`2rem`. A hero count and a footnote count sit at the same weight, and a host
that wants otherwise writes CSS against `janela-value-number` once per pane,
which is the trade #15 set out to end. A stored pane cannot say it at all,
and stored panes are where an analyst who owns a dashboard would say it
(#28, now closed, made the structure data).

ADR 016 already says how a size is spoken in this library: a small integer
that selects a class already written, never a length, so that nothing an
analyst types reaches CSS. `span`, `gap`, and since ADR 047 `height` all do it.

### What was considered

**A length, `size: "3rem"`.** Rejected for ADR 016's reason. A pane row taking
a length would be the first place an analyst's text reaches a style.

**A boolean, `hero: true`.** Rejected. It has two states and the need has
three: a footnote is as real as a hero, and the issue names both.

**Scaling the number to its container.** Rejected. It puts a layout behaviour
inside a decision about emphasis, it is what a `clamp()` in a host's own CSS
does better, and it would make the same pane a different size in two columns.

**A frame-level density.** Rejected as ADR 047 rejected a frame-level height:
a second way to say what a per pane step already says, and it cannot make one
count larger than its neighbours.

**Making the label scale with the number.** Rejected. The label is the small
words that say what the number is, and a hero number wants a label that stays
out of its way. It stays at `0.85rem` at every step.

## Decision

**A single value pane may carry a `prominence` of 1, 2 or 3. Unset is exactly
what it is today, and today is step 2.**

| prominence | number | reads as |
| --- | --- | --- |
| 1 | `1.25rem` | a footnote |
| 2 | `2rem` | what every value is now |
| 3 | `3.5rem` | the hero number |

The class follows ADR 016's `janela-{property}-{scale}`: `janela-prominence-1`
to `janela-prominence-3`, on the pane's `p.janela-value`. With none set there is
no class, and the `2rem` the number has today comes from the rule it already
has, so nothing that renders now renders differently. A step 2 is therefore
the same as unset, which is stated in the documentation rather than avoided:
a stored pane can be set back to the default explicitly, and the scale has a
middle. Line height is not changed at any step, because changing it for the
default would break "unset changes nothing".

**One vocabulary in three places,** as height does:

```erb
<%= janela_pane Order, :orders, prominence: 3 %>
```

- `Janela::Pane#prominence`, a nullable integer validated to `1..3`, offered
  on the pane form (blank is "Automatic").
- `janela_pane` and `janela_snapshot_pane` take `prominence:`.
- The pane URL carries it as `?prominence=3`, because the server draws the
  pane again from that URL on every cross-filter.

**It is not part of the pane's identity.** ADR 029 identifies a frame by who
it is, and how prominent a pane is does not say which query it is. It stays out
of `Query.turbo_frame_id`.

**On anything that is not a single value it is ignored, not an error.** A
table, a chart and a ring have no headline number, and a pane switched between
renderers keeps what it had, which is what height does on a ring (ADR 047).

## Consequences

- An analyst can make one count the hero of a dashboard and another a footnote
  without CSS, and a host does it from the same word.
- **A migration for stored frames.** `janela_panes` gains a nullable
  `prominence`, additive, so every existing pane is unset and unchanged. A host
  using stored frames runs `bin/rails janela:install:migrations` and
  `db:migrate`, as it did for `height`; the two land in the same release so the
  host takes both at once. A host that does not use stored frames has nothing to
  do.
- **The pane URL grammar grows by one optional parameter and the theming
  contract by three classes.** ADR 037 counts both as public surface, which is
  why this belongs before 1.0.
- The steps are `rem`, not multiples of `--janela-space`: a font size follows
  the reader's type scale and not the spacing unit, so a theme that moves the
  spacing does not shrink the numbers. A theme that wants different sizes
  overrides the three classes, which are published.
- The number's size is the only thing that moves. A wider hero number can
  overflow a narrow column, and the answer is `span`, not a smaller step.
- What would change this decision: a need for a fourth step, which is an
  argument for a host's own class and not for a length; or a need for the label
  to move with the number, which is a separate step of its own.
